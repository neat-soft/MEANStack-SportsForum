collections = require("../../datastore").collections
async = require("async")
util = require("../../util")
debug = require("debug")("api:social")
ContentFilter = require("../../contentfilter")
moment = require("moment")
passport = require("passport")
config = require("naboo").config
_.string = require("underscore.string")
Twit = require("twit")
TwitterStrategy = require("passport-twitter").Strategy
templates = require("../../templates")


module.exports = (app)->

  ### FACEBOOK SHARING ###

  shareFbMessage = (app_id, access_token, link, title, caption, text, callback)->
    debug("post to FB: '#{text}'")
    async.waterfall([
      (cb)->
        util.fbreq("POST", "/me/feed", {
          access_token: access_token
          app_id: app_id
          link: link
          name: title
          caption: caption
          description: text
        }, (code, headers, data)->
          debug(JSON.stringify(data))
          if code == -1
            cb({message: "Connection error"})
          else if code != 200
            if data?.error?.message
              msg = data.error.message
              if data.error.type
                msg = "#{data.error.type} - #{msg}"
            else
              msg = "Sharing failed with code #{code}"
            cb({message: msg})
          else
            cb(null, data)
        )
      (fbpost, cb)->
        debug("posted with id: #{fbpost.id}")
        debug(JSON.stringify(fbpost))
        util.fbreq("GET", "/#{fbpost.id}", {
          access_token: access_token
          app_id: app_id
        }, (code, headers, data) ->
          if code == -1
            cb({message: "Connection error"})
          else if code != 200
            if data?.error?.message
              msg = data.error.message
              if data.error.type
                msg = "#{data.error.type} - #{msg}"
            else
              msg = "Share info failed with code #{code}"
            # cb({message: msg})
            # fill fbpost with post details
            fbpost.description = text
            fbpost.caption = caption
            fbpost.title = title
            fbpost.link = link
            cb(null, fbpost)
          else
            cb(null, data)
        )
      (fbpost, cb)->
        debug("upgrading access token to long lived")
        util.fbreq("GET", "/oauth/access_token", {
          client_id: app_id
          client_secret: config.fbClientSecret
          grant_type: "fb_exchange_token"
          fb_exchange_token: access_token
        }, (code, headers, data)->
          if code == -1
            cb({message: "Connection error"})
          else if code != 200
            if data?.error?.message
              msg = data.error.message
              if data.error.type
                msg = "#{data.error.type} - #{msg}"
            else
              msg = "Access token exchange failed with code #{code}"
            err = {message: msg}
          else
            err = null
            fbpost.long_access_token = data.access_token
          cb(err, fbpost)
        )
    ], callback)

  shareFbWithPoints = (site, user, item, text, title, caption, link, app_id, access_token, callback)->
    context = item.context || item._id
    text = _.string.prune(text, 100)
    async.waterfall([
      (cb)->
        debug("share item #{item._id} on FB for #{user?.name} with token #{access_token}: #{text}")
        shareFbMessage(app_id, access_token, link, title, caption, text, (err, post)->
          if user
            cb(err, post)
          else
            # no logged in user, nothing more to do
            callback(err, post)
        )
      (fbpost, cb)->
        debug("checking share treshold for awarding points")
        collections.shares.count({user: user._id, context: context}, (err, count)->
          should_give_points = count < util.getValue("maxSharesPerConversation")
          debug("should give points: #{should_give_points}")
          cb(err, fbpost, should_give_points)
        )
      (fbpost, should_give_points, cb)->
        give_points_now = should_give_points
        # # don't check visibility, just give points for first X shares
        # if should_give_points
        #   debug("checking post privacy")
        #   if fbpost?.privacy?.value in [null, "CUSTOM", "SELF"]
        #     debug("privately shared, no points for now")
        #     give_points_now = false
        cb(null, fbpost, should_give_points, give_points_now)
      (fbpost, should_give_points, give_points_now, cb)->
        if give_points_now
          debug("awarding points for share")
          collections.comments.updatePointsShareComment(user, site, context, item, true, (err, points)->
            debug("incremented points: #{points}")
            cb(err, fbpost, should_give_points, points)
          )
        else
          debug("share doesn't receive points now")
          cb(null, fbpost, should_give_points, 0)
      (fbpost, should_give_points, points, cb)->
        collections.shares.insert({
          share_id: fbpost.id
          network: 'facebook'
          siteName: site.name
          user: user._id
          context: context
          item: item._id
          access_token: fbpost.long_access_token
          when: moment.utc().toDate()
          points: points
        }, (err, share)->
          cb(err, fbpost, should_give_points, points, share)
        )
      # don't check later, points are not retracted
      # (fbpost, should_give_points, points, share, cb)->
      #   if should_give_points
      #     debug("adding job for point checking")
      #     collections.jobs.add({
      #       type: "CHECK_SHARED_ITEM"
      #       network: "facebook"
      #       siteName: site.name
      #       context: context
      #       item: item
      #       user: user
      #       access_token: fbpost.long_access_token
      #       app_id: app_id
      #       share_id: fbpost.id
      #       points: points
      #       uid: "CHECK_SHARED_ITEM_#{user._id}_#{item._id}"
      #       start_after: moment.utc().add(1, "day").toDate()
      #     }, (err)->
      #       cb(err, fbpost)
      #     )
      #   else
      #     debug("not qualified for points, no job added")
      #     cb(null, fbpost)
    ], callback)


  app.post("/api/sites/:site/activities/:activity/share/fb", (req, res, next)->
    activity = req.params['activity']
    data = req.body

    async.waterfall([
      (cb)->
        collections.comments.findActivityById(req.site, activity, false, cb)
      (comment, cb)->
        text = if comment.challenger then comment.challenger.text else comment.text
        cf = new ContentFilter()
        cf.formatPlain(text, (err, text)->
          cb(err, comment, text)
        )
      (comment, text, cb)->
        shareFbWithPoints(req.site, req.user, comment, text, data.name, data.caption, data.link, data.app_id, data.token, cb)
    ], (err, result)->
      debug(JSON.stringify(result, null, 2))
      if err
        debug("failed: #{err?.message || err}")
        res.send(400, {error: err?.message || err})
      else
        res.send(200, {text: "#{result.description} (#{result.caption})"})
    )
  )

  app.post("/api/sites/:site/contexts/:context/share/fb", (req, res)->
    context = req.params['context']
    data = req.body

    async.waterfall([
      (cb)->
        collections.conversations.findById(context, cb)
      (conv, cb)->
        shareFbWithPoints(req.site, req.user, conv, data.link, data.name, data.caption, data.link, data.app_id, data.token, cb)
    ], (err, result)->
      debug(JSON.stringify(result, null, 2))
      if err
        debug("failed: #{err?.message || err}")
        res.send(400, {error: err?.message || err})
      else
        res.send(200, {text: "#{result.description} (#{result.caption})"})
    )
  )

  ### TWITTER SHARING ###

  passport.use("twitter-authz", new TwitterStrategy({
    consumerKey: config.twKey
    consumerSecret: config.twSecret
  }, (token, tokenSecret, profile, done)->
    debug("tw - token: #{token}")
    debug("tw - tokenSecret: #{tokenSecret}")
    debug("tw - profile: #{JSON.stringify(profile, null, 4)}")
    account = {token: token, tokenSecret: tokenSecret}
    done(null, account)
  ))

  app.get("/api/sites/:site/activities/:activity/share/tw",
    (req, res, next)->
      act = req.params['activity']
      type = req.query.type
      debug("tw - request for activity sharing")
      passport.authorize('twitter-authz', {callbackURL: "/api/sites/#{req.siteName}/activities/#{act}/share/tw/callback?type=#{type}"})(req, res, next)
    (req, res)->
      # pass
  )

  shareTwWithPoints = (site, user, item, text, token, secret, callback)->
    debug("tw - sharing and updateing points")
    context = item.context || item._id
    t = new Twit({
      consumer_key: config.twKey
      consumer_secret: config.twSecret
      access_token: token
      access_token_secret: secret
    })

    async.waterfall([
      (cb)->
        debug("tw - share item #{item._id} on TW for #{user?.name} with token #{token}: #{text}")
        t.post("statuses/update", {status: text}, (err, data, res)->
          if user
            cb(err, data)
          else
            # nothing left to do
            callback(err, data)
        )
      (fbpost, cb)->
        debug("tw - checking share treshold for awarding points")
        collections.shares.count({user: user._id, context: context}, (err, count)->
          should_give_points = count < util.getValue("maxSharesPerConversation")
          debug("tw - should give points: #{should_give_points}")
          cb(err, fbpost, should_give_points)
        )
      (fbpost, should_give_points, cb)->
        if should_give_points
          debug("tw - awarding points for share")
          collections.comments.updatePointsShareComment(user, site, context, item, true, (err, points)->
            debug("tw - incremented points: #{points}")
            cb(err, fbpost, should_give_points, points)
          )
        else
          debug("tw - share doesn't receive points now")
          cb(null, fbpost, should_give_points, 0)
      (fbpost, should_give_points, points, cb)->
        collections.shares.insert({
          share_id: fbpost.id
          network: 'twitter'
          siteName: site.name
          user: user._id
          context: context
          item: item._id
          when: moment.utc().toDate()
          points: points
        }, (err, share)->
          cb(err, fbpost, should_give_points, points, share)
        )
    ], callback)

  app.get("/api/sites/:site/activities/:activity/share/tw/callback", passport.authorize('twitter-authz'), (req, res, next)->
    activity = req.params['activity']
    type = req.query.type
    debug("tw - activity callback")
    async.waterfall([
      (cb)->
        collections.comments.findActivityById(req.site, activity, false, cb)
      (comment, cb)->
        debug("tw - sharing comment #{comment?._id}")
        if comment.author
          collections.users.findById(comment.author, (err, user)->
            cb(err, comment, user)
          )
        else if comment.challenger
          collections.users.findById(comment.challenger.author, (err, user)->
            cb(err, comment, user)
          )
        else
          cb(null, comment, comment.guest)
      (comment, user, cb)->
        debug("tw - author #{JSON.stringify(user, null, 4)}")
        text = if comment.challenger then comment.challenger.text else comment.text
        cf = new ContentFilter()
        cf.formatPlain(text, {noPlainAt: true}, (err, text)->
          cb(err, comment, user, text)
        )
      (comment, user, text, cb)->
        user ?= {name: "???"}
        text = if type == "challenge" then _.string.prune(text, 70) else _.string.prune(text, 80)
        switch type
          when "comment"
            text = "#{text} - #{user.name}"
          when "answer"
            text = "#{text} - responded #{user.name}"
          when "question"
            text = "#{text} - asked #{user.name}"
          when "challenge"
            text = "#{text} - challenged #{user.name}"
        url = "#{config.serverHost}/go/#{comment._id.toHexString()}"
        text = "#{text} - #{url}"
        debug("tw - text: #{text}")
        cb(null, comment, text)
      (comment, text, cb)->
        shareTwWithPoints(req.site, req.user, comment, text, req.account.token, req.account.tokenSecret, cb)
    ], (err, result)->
      debug(JSON.stringify(result, null, 2))
      if err
        debug("failed: #{err?.message || err}")
      if err
        debug("failed: #{err?.message || err}")
        templates.render(res, "marketing/popup_close", {social: 'tw', error: (err.message || err)})
      else
        templates.render(res, "marketing/popup_close", {social: 'tw', text: result.text})
    )
  )

  app.get("/api/sites/:site/contexts/:context/share/tw",
    (req, res, next)->
      context = req.params['context']
      debug("tw - request for conversation sharing")
      passport.authorize('twitter-authz', {callbackURL: "/api/sites/#{req.siteName}/contexts/#{context}/share/tw/callback"})(req, res, next)
    (req, res)->
      # pass
  )

  app.get("/api/sites/:site/contexts/:context/share/tw/callback", passport.authorize('twitter-authz'), (req, res, next)->
    debug("tw - conversation callback")
    context = req.params['context']
    async.waterfall([
      (cb)->
        collections.conversations.findById(context, cb)
      (conv, cb)->
        text = "#{_.string.prune(conv.text || "Conversation at", 40)} #{config.serverHost}/go/#{conv._id.toHexString()}"
        shareTwWithPoints(req.siteName, req.user, conv, text, req.account.token, req.account.tokenSecret, cb)
    ], (err, result)->
      debug(JSON.stringify(result, null, 2))
      if err
        debug("failed: #{err?.message || err}")
        templates.render(res, "marketing/popup_close", {social: 'fb', error: (err.message || err)})
      else
        templates.render(res, "marketing/popup_close", {social: 'fb', text: result.text})
    )
  )

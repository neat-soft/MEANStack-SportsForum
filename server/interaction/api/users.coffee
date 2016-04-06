collections = require("../../datastore").collections
response = require("./response")
async = require("async")
util = require("../../util")
dbutil = require("../../datastore/util")
handlers = require("../handlers")
logger = require("../../logging").logger
sharedUtil = require("../../shared/util")
debug = require("debug")("api:users")
moment = require("moment")
config = require("naboo").config
stripe = require("stripe")(config.stripe.secret)

thisuser = (req, res, next)->
  user = req.params["user"]
  if !req.user || req.user._id.toHexString() != user
    return next({notexists: true})
  next()

module.exports = (app)->

  app.post("/api/users", (req, res, next)->
    async.waterfall([
      (cb)->
        if req.user
          req.logOut()
        email = req.body.email?.toLowerCase?() || ""
        name = req.body.name
        if !sharedUtil.removeWhite(name) || !sharedUtil.validateEmail(email)
          return cb({email_incorrect: true})
        pass = sharedUtil.removeWhite(req.body.pass) || null
        # if !sharedUtil.removeWhite(req.body.pass)
        #   return cb({invalid_password: true})
        collections.users.createOwnAccount(name, email, pass, false, cb)
      (user, cb)->
        if req.site
          collections.profiles.create(user, req.site, false, (err, profile)->
            req.profile = profile
            cb(err, user)
          )
        else
          cb(null, user)
      (user, cb)->
        req.login(user, (err)->
          cb(err, user)
        )
    ], response.sendObj(res, collections.users.toClient))
  )

  app.get("/api/users/me", (req, res)->
    response.sendObj(res, _.partialEnd(collections.users.toClient, req.user))(null, req.user)
  )

  app.get("/api/users/:user", (req, res)->
    user = req.params["user"]
    collections.users.findById(user, response.sendObj(res, _.partialEnd(collections.users.toClient, req.user)))
  )

  app.get("/api/users/:user/notifications", (req, res)->
    user = req.params["user"]
    from = req.query.from
    if req.user?._id.toHexString() == user
      collections.notifications.getOlder(req.user, from, response.sendPagedArray(res))
    else
      res.send(404)
  )

  app.get("/api/sites/:site/history/:user", handlers.paging('profiles'), (req, res)->
    user = req.params["user"]
    debug("requested user '#{user}' history on site '#{req.site.name}'")
    user = dbutil.idFrom(user)
    collections.comments.history(req.site, user, req.paging, response.sendPagedCursor(res, collections.comments.toClient))
  )

  # app.delete("/api/users/:user/notifications", (req, res)->
  #   user = req.params["user"]
  #   if req.user?._id.toHexString() == user
  #     collections.notifications.deleteAll(req.user, response.sendObj(res))
  #   else
  #     res.send(404)
  # )

  # app.delete("/api/users/:user/notifications/:notification", (req, res)->
  #   user = req.params["user"]
  #   notification = req.params["notification"]
  #   if req.user?._id.toHexString() == user
  #     collections.notifications.delete(notification, req.user, response.sendObj(res))
  #   else
  #     res.send(404)
  # )

  app.get("/api/users/:user/formerge", thisuser, handlers.userType("own"), (req, res, next)->
    if !req.user.verified
      return next({not_verified: true})
    collections.users.forMerge(req.user, response.sendPagedArray(res))
  )

  app.post("/api/users/:user/merge", thisuser, handlers.userType("own"), (req, res, next)->
    if !req.user.verified
      return next({not_verified: true})
    if !req.body._id
      if !sharedUtil.removeWhite(req.body.type)
        return next({notsupported: true})
      req.body.type = req.body.type.toLowerCase()
      if !req.body.type in ['imported', 'guest']
        return next({notsupported: true})
      if req.body.type in ['imported'] && (!sharedUtil.removeWhite(req.body.email) || !sharedUtil.validateEmail(req.body.email))
        return next({email_incorrect: true})
    collections.users.queueMerge(req.body, req.user, (err, result)->
      response.sendValue(res)(err, if err then null else true)
    )
  )

  app.put("/api/users/:user/notifications/read", thisuser, (req, res)->
    user = req.params["user"]
    if req.user?._id.toHexString() == user
      collections.users.update({_id: req.user._id}, {$set: {notif_read_at: new Date().getTime()}}, (err, no_updated)->
        res.send(200, {result: 0})
      )
    else
      res.send(403)
  )

  app.put("/api/users/:user/notifications/:notification", thisuser, (req, res)->
    user = req.params["user"]
    notification = req.params["notification"]
    if req.user?._id.toHexString() == user
      collections.notifications.markRead(notification, req.user, response.sendObj(res))
    else
      res.send(404)
  )

  app.get("/api/users/:user/notifications/countunread", (req, res)->
    user = req.params["user"]
    if req.user?._id.toHexString() == user
      collections.notifications.countUnread(req.user, response.sendObj(res))
    else
      res.send(404)
  )

  app.get("/api/users/:user/notifications/countnew", (req, res)->
    user = req.params["user"]
    if req.user?._id.toHexString() == user
      since = req.user.notif_read_at
      if since
        since = dbutil.idFromTime(since)
        filter = {
          _id:
            $gt:
              since
        }
      else
        filter = {}
      collections.notifications.countUnread(req.user, filter, response.sendObj(res))
    else
      res.send(404)
  )

  app.put("/api/users/:user", thisuser, (req, res)->
    user = req.params["user"]
    if req.user?._id.toHexString() != user
      res.send(403)
      return
    collections.users.modify(user, req.body, response.sendObj(res, _.partialEnd(collections.users.toClient, req.user)))
  )

  app.put("/api/users/:user/rmlogin", thisuser, (req, res)->
    user = req.params["user"]
    if req.user?._id.toHexString() != user
      return res.send(403)
    collections.users.remove3rdPartyLogin(req.user, req.body.p, response.sendObj(res, _.partialEnd(collections.users.toClient, req.user)))
  )

  str_to_regex = (str, full_str) ->
    if !full_str
      words = (s.replace(/^\s+|\s+$/gi, "") for s in str.split(" "))
    else
      words = [str.replace(/^\s+|\s+$/gi, "")]
    words = (s for s in words when s.length > 0)
    # sanitize, don't allow special chars
    words = (s.replace(/[#-.]|[[-^]|[?|{}]/g, '\\$&') for s in words)

    return words.join("|")

  app.get('/api/sites/:site/profiles/count', handlers.requireModerator, (req, res)->
    collections.profiles.countForSite(req.site, response.sendValue(res))
  )

  app.get('/api/sites/:site/profiles/export', handlers.requireModerator, handlers.requirePremium, (req, res)->
    format = req.query.format
    if format != "csv"
      return response.handleError({notsupported: true}, res)
    res.setHeader("Content-Type", "text/csv")
    res.setHeader("Content-Disposition", "attachment;filename=#{req.site.name}_users.csv")
    fields = _.flatten(["email", "name", "verified", "trusted", _.map(req.site.badges || [], (b)-> "badge #{b.title}")])
    format = response.csv(fields)
    collections.profiles.export(req.site, response.streamItem(res, null, format), response.streamStartEnd(res, null, format))
  )

  app.get("/api/sites/:site/profiles/:user?", handlers.paging('profiles'), (req, res)->
    user = req.params["user"]
    reqByMod = req.profile?.permissions?.moderator
    filter = if req.query.s then {userName: {$regex: str_to_regex(req.query.s, !!req.query.full), $options: 'i'}, merged_into: {$exists: false}} else {merged_into: {$exists: false}}
    if user
      collections.profiles.forSite(user, req.site, response.sendObj(res, _.partialEnd(collections.profiles.toClient, req.user, reqByMod)))
    else
      if req.paging
        collections.profiles.getPaged(req.site, req.paging.field, req.paging.dir, req.paging.from, filter, response.sendPagedArray(res, _.partialEnd(collections.profiles.toClient, req.user, reqByMod)))
      else
        collections.profiles.get(req.site, filter, response.sendPagedCursor(res, _.partialEnd(collections.profiles.toClient, req.user, reqByMod)))
  )

  app.get("/api/sites/:site/profiles/:user/badges", (req, res)->
    user = req.params["user"]
    collections.badges.allForSite(user, req.site, response.sendPagedArray(res, _.partialEnd(collections.badges.toClient, req.user)))
  )

  app.put("/api/sites/:site/profiles/:user", handlers.requireModerator, (req, res)->
    target_user = req.params["user"]
    reqByMod = req.profile?.permissions?.moderator
    attrs = {}
    attrs.approval = parseInt(util.jsparse(req.body.approval)) || 0
    perms = req.body.permissions
    attrs.permissions = {}
    attrs.permissions.moderator = !!util.jsparse(req.body.permissions?.moderator)
    attrs.permissions.private = !!util.jsparse(req.body.permissions?.private)
    collections.profiles.modify(req.site, target_user, attrs, req.user, req.profile, response.sendObj(res, _.partialEnd(collections.profiles.toClient, req.user, reqByMod)))
  )

  handle_payment = (req, fromUser, toUser, tokenId, cb)->
    debug("payment of gold badge from #{fromUser.email} to #{toUser.email}")
    stripe.charges.create({
      card: tokenId
      currency: "usd"
      amount: 100000
      description: "Gold Badge for #{toUser.email}"
    }, (err, charge)->
      if err
        debug("payment failed")
        logger.error(err)
        cb(err)
      else
        debug("payment ok, adding gold transaction to #{toUser.email}")
        collections.users.addGold(req, toUser, {id: charge.id, from_user: fromUser._id, date: moment.utc().toDate()}, cb)
    )

  # give gold to :user; this can be called by any logged in user that wishes to
  # award a gold badge to someone
  app.put("/api/sites/:site/profiles/:user/gold", handlers.requireAuth, (req, res, next)->
    collections.users.findOne({_id: dbutil.idFrom(req.params["user"])}, (err, recipient)->
      if recipient
        handle_payment(req, req.user, recipient, req.body.id, (err)->
          if err
            debug("error adding gold")
            res.send(503)
          else
            debug("gold added")
            collections.users.findOne({_id: recipient._id}, (err, u)->
              if u
                res.send(200, collections.users.toClient(u, req.user))
              else
                res.send(503)
            )
        )
      else
        debug("gold badge recipient not found")
        res.send(404)
    )
  )

  app.post("/api/sites/:site/loginsso", (req, res, next)->
    message = req.body.sso
    if req.user && req.user.type != 'sso'
      return next({conflict: true})
    if !message
      res.send(403)
    else
      async.waterfall([
        (cb)->
          collections.users.loginSSO(req.site, message, cb)
        (user, cb)->
          req.login(user, (err)->
            cb(err, user)
          )
      ], (err, user)->
        if err
          if err.nouser
            if req.user?.type == "sso"
              req.logOut()
            res.send(200, "null")
          else
            if err.notenabled || err.invalid
              res.send(403, err)
            else
              logger.error(err)
              res.send(403)
        else
          res.send(200, collections.users.toClient(user))
      )
  )

  app.post("/api/sites/:site/resetpoints", handlers.requireModerator, (req, res)->
    collections.profiles.resetPoints(req.site, response.sendObj(res))
  )

  app.get("/api/sites/:site/leaders", (req, res)->
    reqByMod = req.profile?.permissions?.moderator
    collections.profiles.leaders(req.site, response.sendPagedArray(res, _.partialEnd(collections.profiles.toClient, req.user, reqByMod)))
  )

  app.get("/api/sites/:site/contexts/:context/leaders", (req, res)->
    collections.convprofiles.leaders(req.params["context"], req.site, response.sendPagedArray(res, _.partialEnd(collections.convprofiles.toClient)))
  )

  app.get("/api/sites/:site/badges/:badge/leaders", (req, res)->
    collections.badges.leaders(req.params["badge"], null, req.site, req.user, req.profile, req.query.min_rank, response.sendPagedArray(res))
  )

  app.get('/api/users/:user/bets/:site/count', handlers.requireSite, (req, res)->
    user = req.params["user"]
    bet_status = req.query.status
    if !(bet_status? && bet_status != 'all')
      bet_status = null
    collections.comments.countUserActivities(user, req.site, 'BET', {bet_status: bet_status, omit_rolledback: true}, response.sendValue(res))
  )

  app.get('/api/users/:user/bets/:site', handlers.requireSite, handlers.paging('bets'), (req, res)->
    user = req.params["user"]
    bet_status = req.query.status
    if !(bet_status? && bet_status != 'all')
      bet_status = null
    if req.paging
      collections.comments.getUserActivitiesPaged(
        user,
        req.site,
        'BET',
        req.paging.field,
        req.paging.dir,
        req.paging.from,
        {bet_status: bet_status, omit_rolledback: true},
        response.sendPagedArray(res, _.partialEnd(collections.comments.toClient, false, req.user))
      )
    else
      response.handleError({notsupported: true}, res)
  )

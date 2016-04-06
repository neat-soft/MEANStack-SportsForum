async = require("async")
elasticsearch = require("es")
dbutil = require("../../datastore/util")
datastore = require("../../datastore")
collections = datastore.collections
helenus = require("helenus")
debug = require("debug")("worker:jobs")
moment = require("moment")
logger = require("../../logging").logger
pubsub = require("../../pubsub")
util = require("../../util")
ContentFilter = require("../../contentfilter")
config = require("naboo").config
build_reply_to = require("../../email").build_reply_to
urls = require("../../interaction/urls")
mongo = require("mongodb")

addNotification = collections.notifications.addNotification

newCommentForMod = (job, callback)->
  async.waterfall([
    (cb)->
      collections.subscriptions.find({siteName: job.siteName, context: "*", active: true}, cb)
    (cursor, cb)->
      iter = (err, subscription)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !subscription
          return cb()
        if subscription.user && job.comment.author?._id.equals(subscription.user)
          return cursor.nextObject(iter)
        async.waterfall([
          (cbi)->
            if subscription.user
              return collections.users.findOne({_id: subscription.user}, cbi)
            cbi(null, null)
          (user, cbi)->
            if user?.subscribe.own_activity && job.parent?.author?._id?.equals(subscription.user)
              return cbi()
            collections.jobs.add({
              type: "EMAIL"
              emailType: "NEW_COMMENT_MOD"
              to: subscription.email
              siteName: job.siteName
              text: job.comment.text
              comment: job.comment
              conversationTitle: job.conversationTitle
              token: subscription.token
              url: job.url
              uid: "EMAIL_#{job.uid}_MOD_to_#{subscription.email}"
              email_reply_to: if user then "#{build_reply_to('reply', job.siteName, job.comment._id, user._id, config.emailSubjectKey)}" else null
              email_from: "#{job.comment.author?.name || job.comment.guest?.name}"
              can_reply: !!user
            }, cbi)
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

newChallengeForMod = (job, callback)->
  async.waterfall([
    (cb)->
      collections.subscriptions.find({siteName: job.siteName, context: "*", active: true}, cb)
    (cursor, cb)->
      iter = (err, subscription)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !subscription
          return cb()
        if subscription.user && job.challenge.challenger.author?._id.equals(subscription.user)
          return cursor.nextObject(iter)
        async.waterfall([
          (cbi)->
            if subscription.user
              return collections.users.findOne({_id: subscription.user}, cbi)
            cbi(null, null)
          (user, cbi)->
            if user?.subscribe.own_activity && job.challenge.challenged.author._id?.equals(subscription.user)
              return cbi()
            collections.jobs.add({
              type: "EMAIL"
              emailType: "NEW_CHALLENGE_MOD"
              to: subscription.email
              siteName: job.siteName
              challenge: job.challenge
              conversationTitle: job.conversationTitle
              token: subscription.token
              url: job.url
              uid: "EMAIL_#{job.uid}_MOD_to_#{subscription.email}"
              email_reply_to: if user then "#{build_reply_to('reply', job.siteName, job.challenge._id, user._id, config.emailSubjectKey)}" else null
              email_from: "#{job.challenge.challenger.author.name}"
              can_reply: !!user
            }, cbi)
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

module.exports.markConversationActivity = (job, callback)->
  if job.since?
    sincedate = job.since
    sinceid = dbutil.idFromTime(job.since)
  else
    sincedate = moment().utc().subtract(1, 'days').valueOf()
    sinceid = dbutil.idFromTime(sincedate)
  debug("Setting activity rating for conversations since #{sincedate}")
  async.waterfall([
    (cb)->
      collections.conversations.update({latest_activity: {$lt: sincedate}}, {$set: {activity_rating: 0}}, {multi: true}, cb)
    (result, info, cb)->
      collections.conversations.find({latest_activity: {$gte: sincedate}}, cb)
    (cursor, cb)->
      iter = (err, conv)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !conv
          return cb()
        async.waterfall([
          (cb)->
            async.parallel([
              (cbp)->
                collections.comments.count({siteName: conv.siteName, context: conv._id, approved: true, _id: {$gte: sinceid}}, cbp)
              (cbp)->
                collections.likes.count({siteName: conv.siteName, context: conv._id, _id: {$gte: sinceid}}, cbp)
              (cbp)->
                collections.votes.count({siteName: conv.siteName, context: conv._id, _id: {$gte: sinceid}}, cbp)
            ], cb)
          (results, cb)->
            [comments, likes, votes] = results
            activity_rating = util.getValue("forumRatingComment") * comments + util.getValue("forumRatingLike") * likes + util.getValue("forumRatingVote") * votes
            collections.conversations.findAndModifyWTime({_id: conv._id}, [], {$set: {activity_rating: activity_rating}, $inc: {_v: 1}}, cb)
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

module.exports.activity = (job, callback)->
  untilTime = Math.floor(new Date().getTime() / 1000) * 1000
  async.waterfall([
    (cb)->
      collections.sites.findAndModify({name: job.siteName, locked_activity: false}, [], {$set: {locked_activity: true}}, {new: true}, (err, site)->
        cb(err, site)
      )
    (site, cb)->
      if !site
        cb({sitenotexists: true})
        return
      else
        collections.users.findOne({_id: site.user}, (err, user)->
          if !user
            cb({invalid_user: true})
          else if !user.verified
            cb({not_verified: true})
          else
            cb(err, site, user)
        )
    (site, user, cb)->
      collections.comments.count(
        {
          siteName: site.name,
          _id: {$gt: dbutil.idFromTime(site.notifiedOn || 0)},
          approved: false
        },
        (err, result)->
          cb(err, site, user, result)
      )
    (site, user, nocomments, cb)=>
      if nocomments > 0
        collections.jobs.add({
          type: "EMAIL"
          emailType: "ACTIVITY"
          to: user.email
          siteName: site.name
          status: {comments: nocomments}
          uid: "EMAIL_ACTIVITY_#{job._id.toHexString()}_to_#{user.email}"
          can_reply: false
        }, cb)
      else
        cb(null, site)
  ], (err, site)->
    collections.sites.findAndModify({name: job.siteName}, [], {$set: {notifiedOn: untilTime, locked_activity: false}}, (errorsite, site)->
      if err
        if err.not_verified
          callback(err)
        else
          callback(err, {keep: true})
      else
        callback(err)
    )
  )

module.exports.newConversation = (job, callback)->
  async.waterfall([
    (cb)->
      collections.subscriptions.find({siteName: job.siteName, context: null, verified: true, active: true}, cb)
    (cursor, cb)->
      iter = (err, subscription)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !subscription
          return cb()
        async.parallel([
          (cbp)->
            collections.jobs.add({
              type: "EMAIL",
              emailType: "NEW_CONVERSATION",
              to: subscription.email,
              siteName: job.siteName,
              token: subscription.token,
              conv: job.conv,
              conversationTitle: job.conv.text
              context: job.context
              url: job.url,
              uid: "EMAIL_#{job.uid}_to_#{subscription.email}"
              # email_from: "#{job.siteName} <#{config.email.notifications.fromAddress}>"
              can_reply: false
            }, (err)->
              if err
                logger.error(err)
              # We have to do something here
              cbp()
            )
          (cbp)->
            if subscription.user
              addNotification({
                type: "NEW_CONVERSATION",
                user: subscription.user,
                siteName: job.siteName,
                context: job.context,
                url: job.url
              }, (err)->
                if err
                  logger.error(err)
                cbp()
              )
            else
              cbp()
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

module.exports.endQuestion = (job, callback)->
  cf = new ContentFilter()
  context = null
  async.waterfall([
    (cb)->
      cf.formatAll(job.answer.text, {includeAt: true}, (err, text, html)->
        job.answer.text = text
        job.answer.ptext = html
        cb(err)
      )
    (cb)->
      collections.conversations.findOne({_id: job.answer.context},cb)
    (result, cb)->
      context = result
      collections.users.findOne({_id: job.answer.author, "subscribe.own_activity": true, verified: true}, cb)
    (user, cb)->
      if user
        async.parallel([
          (cbp)->
            collections.jobs.add({
              type: "EMAIL"
              emailType: "WIN_QUESTION"
              to: user.email
              siteName: job.siteName
              no_likes: job.answer.no_likes
              no_likes_down: job.answer.no_likes_down
              text: job.answer.text
              comment: job.answer
              conversationTitle: context.text
              url: job.url
              uid: "EMAIL_#{job.uid}_to_#{user.email}"
              # email_from: "#{job.siteName} <#{config.email.notifications.fromAddress}>"
              can_reply: false
            }, cbp)
          (cbp)->
            addNotification({
              type: "WIN_QUESTION",
              user: user._id,
              question: collections.comments.toClient(_.extend({}, job.question, {author: job.question.author._id})),
              siteName: job.siteName,
              no_likes: job.answer.no_likes,
              no_likes_down: job.answer.no_likes_down,
              answer: collections.comments.toClient(_.extend({}, job.answer, {author: job.answer.author._id})),
              context: job.context,
              url: job.url
            }, cbp)
        ], cb)
      else
        cb()
  ], callback)

newCommentForAll = (job, callback)->
  if job.comment.type == 'BET'
    targeted = {}
    for tuser_id in job.comment.bet_targeted
      targeted[tuser_id.toHexString()] = true
  notif_type = if job.comment.type == 'BET' then 'NEW_BET' else "NEW_COMMENT"
  collections.subscriptions.findIter({siteName: job.siteName, context: (if job.comment.forum then null else job.context), verified: true, active: true}, (subscription, done)->
    async.waterfall([
      (cb)->
        if !subscription.user
          return done()
        if job.comment.author?._id.equals(subscription.user)
          return done()
        collections.users.findOne({_id: subscription.user}, cb)
      (user, cb)->
        if !user
          return done()
        if job.parent?.author?._id?.equals(subscription.user) && user.subscribe.own_activity
          # this user is the author of the parent comment and will get the notification about the reply
          return done()
        if job.comment.type == 'BET' && targeted[user._id.toHexString()] && user.subscribe.own_activity
          # this user is targeted and will get the targeted notification
          return done()
        async.parallel([
          (cbp)->
            collections.jobs.add({
              type: "EMAIL"
              emailType: notif_type
              to: subscription.email
              siteName: job.siteName
              text: job.comment.text
              comment: job.comment
              conversationTitle: job.conversationTitle
              token: subscription.token
              url: job.url
              uid: "EMAIL_#{job.uid}_to_#{subscription.email}"
              email_reply_to: if user then "#{build_reply_to('reply', job.siteName, job.comment._id, user._id, config.emailSubjectKey)}" else null
              email_from: "#{job.comment.author?.name || job.comment.guest?.name}"
              can_reply: !!user
            }, cbp)
          (cbp)->
            addNotification({
              type: notif_type
              comment: _.extend({}, job.comment, {author: job.comment.author?._id})
              siteName: job.siteName
              context: job.context
              url: job.url
              user: subscription.user
            }, cbp)
        ], cb)
    ], (err)->
      if err
        logger.error(err)
      done()
    )
  , callback)

newCommentForInterested = (job, callback)->
  debug("Sending email to author of parent %j", job.parent.author)
  async.parallel([
    (cbp)->
      collections.jobs.add({
        type: "EMAIL"
        emailType: if job.comment.cat == "QUESTION" && job.comment.level == 2 then "ANSWER" else "REPLY"
        to: job.parent.author.email
        text: job.comment.text
        comment: job.comment
        conversationTitle: job.conversationTitle
        siteName: job.siteName
        url: job.url
        uid: "EMAIL_REPLY_#{job.uid}_to_#{job.parent.author.email}"
        email_reply_to: "#{build_reply_to('reply', job.siteName, job.comment._id, job.parent.author._id, config.emailSubjectKey)}"
        email_from: "#{job.comment.author?.name || job.comment.guest?.name}"
        can_reply: true
      }, cbp)
    (cbp)->
      addNotification({
        type: if job.comment.cat == "QUESTION" && job.comment.level == 2 then "ANSWER" else "REPLY"
        user: job.parent.author._id
        parent: collections.comments.toClient(_.extend({}, job.parent, {author: job.parent.author._id}))
        comment: collections.comments.toClient(_.extend({}, job.comment, {author: job.comment.author._id}))
        sourceUser: job.comment.author._id
        siteName: job.siteName
        context: job.context
        url: job.url
      }, cbp)
  ], callback)

newCommentForOneMentioned = (job, mentionId, callback)->
  debug("Sending email to mentioned user: #{mentionId}")
  collections.users.findOne({_id: dbutil.idFrom(mentionId)}, (err, mention)->
    if !mention
      debug("no such user: #{mentionId}")
      return callback(err)

    async.parallel([
      (cbp)->
        if !mention.subscribe?.name_references
          debug("user #{mentionId} doesn't want email notifications")
          return cbp(null)

        debug("add mention email job")
        collections.jobs.add({
          type: "EMAIL"
          emailType: "MENTION"
          to: mention.email
          comment: job.comment
          conversationTitle: job.conversationTitle
          siteName: job.siteName
          url: job.url
          uid: "EMAIL_MENTION_#{job.uid}_to_#{mention.email}"
          email_reply_to: "#{build_reply_to('reply', job.siteName, job.comment._id, mention._id, config.emailSubjectKey)}"
          email_from: "#{job.comment.author?.name || job.comment.guest?.name}"
          can_reply: true
        }, cbp)
      (cbp)->
        debug("add mention notification: #{job.url}")
        addNotification({
          type: "MENTION"
          user: mention._id
          comment: collections.comments.toClient(_.extend({}, job.comment, {author: job.comment.author._id}))
          sourceUser: job.comment.author._id
          siteName: job.siteName
          context: job.context
          url: job.url
        }, cbp)
    ], callback)
  )

newCommentForMentioned = (job, callback)->
  cf = new ContentFilter()
  refs = cf.extractUserRefs(job.original_comment_text)
  debug("got #{refs.length} in #{job.comment.text}")
  async.map(refs, (item, cb)->
    newCommentForOneMentioned(job, item[1], cb)
  , (err)->
    callback(err)
  )

newBetForTargeted = (job, callback)->
  collections.users.findIter({_id: {$in: job.comment.bet_targeted}}, (user, done)->
    if !user.subscribe.own_activity
      return done()
    async.parallel([
      (cbp)->
        collections.jobs.add({
          type: "EMAIL"
          emailType: 'BET_TARGETED'
          to: user.email
          text: job.comment.text
          comment: job.comment
          user: user
          conversationTitle: job.conversationTitle
          siteName: job.siteName
          url: job.url
          uid: "EMAIL_BET_TARGETED_#{job.uid}_to_#{user.email}"
          email_reply_to: "#{build_reply_to('reply', job.siteName, job.comment._id, user._id, config.emailSubjectKey)}"
          email_from: "#{job.comment.author?.name || job.comment.guest?.name}"
          can_reply: true
        }, cbp)
      (cbp)->
        addNotification({
          type: 'BET_TARGETED'
          user: user._id
          by: job.comment.author._id
          comment: collections.comments.toClient(_.extend({}, job.comment, {author: job.comment.author._id}))
          sourceUser: job.comment.author._id
          siteName: job.siteName
          context: job.context
          url: job.url
        }, cbp)
    ], (err)->
      if err
        logger.error(err)
      done()
    )
  , (err)->
    if err
      logger.error(err)
    callback(err)
  )

module.exports.newComment = (job, callback)->
  cf = new ContentFilter()
  async.series([
    (cb)->
      job.original_comment_text = job.comment.text
      cf.formatAll(job.original_comment_text, {includeAt: true}, (err, text, html)->
        job.comment.text = text
        job.comment.ptext = html
        cb(err)
      )
    (cb)->
      if job.parent._id
        cb(null, job.parent)
      else if job.comment.level > 1
        collections.comments.findOne({_id: job.parent}, (err, result)->
          if !err
            job.parent = result
          cb(err)
        )
      else
        cb()
    (cb)->
      async.parallel([
        (cbp)->
          collections.users.findOne({_id: job.comment.author}, cbp)
        (cbp)->
          if job.parent?.author
            collections.users.findOne({_id: job.parent.author, verified: true}, cbp)
          else
            cbp()
        (cbp)->
          collections.conversations.findOne({_id: job.context},cbp)
      ], (err, results)->
        job.comment.author = results[0]
        if results[1]
          job.parent.author = results[1]
        job.conversationTitle = results[2]?.text || results[2]?.initialUrl || "???"
        cb(err)
      )
    (cb)->
      async.parallel([
        (cbp)->
          newCommentForAll(job, cbp)
        (cbp)->
          newCommentForMentioned(job, cbp)
        (cbp)->
          if job.comment.level > 1 && job.parent.author?.subscribe?.own_activity && !job.parent.author._id?.equals(job.comment.author._id)
            newCommentForInterested(job, cbp)
          else
            cbp()
        (cbp)->
          if job.comment.type == 'BET' && job.comment.bet_targeted.length > 0
            newBetForTargeted(job, cb)
          else
            cbp()
        (cbp)->
          if !job.approvedLater
            newCommentForMod(job, cbp)
          else
            cbp()
      ], cb)
  ], callback)

module.exports.newPendingConversation = (job, callback)->
  async.waterfall([
    (cb)->
      collections.users.findOne({_id: job.conv.author}, cb)
    (author, cb)->
      job.conv.author = author
      collections.subscriptions.find({siteName: job.siteName, context: "*", active: true}, cb)
    (cursor, cb)->
      iter = (err, subscription)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !subscription
          return cb()
        async.waterfall([
          (cbi)->
            if subscription.user
              return collections.users.findOne({_id: subscription.user}, cbi)
            cbi(null, null)
          (user, cbi)->
            if !user?.verified
              return cbi()
            collections.jobs.add({
              type: "EMAIL"
              emailType: "NEW_PENDING_CONVERSATION_MOD"
              to: subscription.email
              siteName: job.siteName
              text: job.conv.text
              conv: job.conv
              conversationTitle: job.conv.text
              url: job.url
              uid: "EMAIL_#{job.uid}_to_#{subscription.email}"
              token: subscription.token
              email_reply_to: "#{build_reply_to('moderate', job.siteName, job.conv._id, user._id, config.emailSubjectKey)}"
              email_from: "#{job.conv.author.name || job.conv.guest?.name}"
              can_reply: false
              can_moderate: true
            }, cbi)
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

module.exports.newPendingComment = (job, callback)->
  cf = new ContentFilter()
  async.waterfall([
    (cb)->
      cf.formatAll(job.comment.text, {includeAt: true}, (err, text, html)->
        job.comment.text = text
        job.comment.ptext = html
        cb(err)
      )
    (cb)->
      collections.users.findOne({_id: job.comment.author}, cb)
    (author, cb)->
      job.comment.author = author
      collections.conversations.findOne({_id: job.context},cb)
    (context, cb)->
      job.conversationTitle = context.text
      collections.subscriptions.find({siteName: job.siteName, context: "*", active: true}, cb)
    (cursor, cb)->
      iter = (err, subscription)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !subscription
          return cb()
        async.waterfall([
          (cbi)->
            if subscription.user
              return collections.users.findOne({_id: subscription.user}, cbi)
            cbi(null, null)
          (user, cbi)->
            if !user?.verified
              return cbi()
            collections.jobs.add({
              type: "EMAIL"
              emailType: "NEW_PENDING_COMMENT_MOD"
              to: subscription.email
              siteName: job.siteName
              text: job.comment.text
              comment: job.comment
              conversationTitle: job.conversationTitle
              url: job.url
              uid: "EMAIL_#{job.uid}_to_#{subscription.email}"
              token: subscription.token
              email_reply_to: "#{build_reply_to('moderate', job.siteName, job.comment._id, user._id, config.emailSubjectKey)}"
              email_from: "#{job.comment.author?.name || job.comment.guest?.name}"
              can_reply: false
              can_moderate: true
            }, cbi)
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

module.exports.newPendingChallenge = (job, callback)->
  cf = new ContentFilter()
  async.waterfall([
    (cb)->
      cf.formatAll(job.challenge.challenger.text, {includeAt: true}, (err, text, html)->
        job.challenge.challenger.text = text
        job.challenge.challenger.ptext = html
        cb(err)
      )
    (cb)->
      cf.formatAll(job.challenge.challenged.text, {includeAt: true}, (err, text, html)->
        job.challenge.challenged.text = text
        job.challenge.challenged.ptext = html
        cb(err)
      )
    (cb)->
      collections.users.findOne({_id: job.challenge.challenger.author}, cb)
    (author, cb)->
      job.challenge.challenger.author = author
      collections.conversations.findOne({_id: job.challenge.context},cb)
    (context, cb)->
      job.conversationTitle = context.text
      collections.subscriptions.find({siteName: job.siteName, context: "*", active: true}, cb)
    (cursor, cb)->
      iter = (err, subscription)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !subscription
          return cb()
        async.waterfall([
          (cbi)->
            if subscription.user
              return collections.users.findOne({_id: subscription.user}, cbi)
            cbi(null, null)
          (user, cbi)->
            if !user?.verified
              return cbi()
            collections.jobs.add({
              type: "EMAIL"
              emailType: "NEW_PENDING_CHALLENGE_MOD"
              to: user.email
              siteName: job.siteName
              text: job.challenge.challenger.text
              challenge: job.challenge
              conversationTitle: job.conversationTitle
              url: job.url
              uid: "EMAIL_#{job.uid}_to_#{user.email}"
              token: subscription.token
              email_reply_to: "#{build_reply_to('moderate', job.siteName, job.challenge._id, user._id, config.emailSubjectKey)}"
              email_from: "#{job.challenge.challenger.author?.name || job.challenge.challenger.guest?.name}"
              can_reply: false
              can_moderate: true
            }, cbi)
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

newChallengeForAll = (job, callback)->
  async.waterfall([
    (cb)->
      collections.subscriptions.find({siteName: job.siteName, context: job.context, verified: true, active: true}, cb)
    (cursor, cb)->
      iter = (err, subscription)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !subscription
          return cb()
        if job.challenge.challenged.author?.subscribe.own_activity && subscription.user?.equals(job.challenge.challenged.author._id) || subscription.user?.equals(job.challenge.challenger.author._id)
          return cursor.nextObject(iter)
        async.parallel([
          (cbp)->
            async.waterfall([
              (cbi)->
                if subscription.user
                  return collections.users.findOne({_id: subscription.user}, cbi)
                cbi(null, null)
              (user, cbi)->
                collections.jobs.add({
                  type: "EMAIL"
                  emailType: "NEW_CHALLENGE"
                  to: subscription.email
                  siteName: job.siteName
                  challenge: job.challenge
                  conversationTitle: job.conversationTitle
                  token: subscription.token
                  url: job.url
                  uid: "EMAIL_#{job.uid}_to_#{subscription.email}"
                  email_reply_to: if user then "#{build_reply_to('reply', job.siteName, job.challenge._id, user._id, config.emailSubjectKey)}" else null
                  email_from: "#{job.challenge.challenger.author?.name|| job.challenge.challenger.guest?.name}"
                  can_reply: !!user
                }, cbi)
            ], (err)->
              if err
                logger.error(err)
              # We have to do something here
              cbp()
            )
          (cbp)->
            if subscription.user
              addNotification({
                type: "NEW_CHALLENGE"
                user: subscription.user
                siteName: job.siteName
                challenge: collections.comments.toClient(_.extend({}, job.challenge,
                  {
                    challenged: _.extend({}, job.challenge.challenged, {author: job.challenge.challenged.author?._id}),
                    challenger: _.extend({}, job.challenge.challenger, {author: job.challenge.challenger.author?._id})
                  }))
                context: job.context
                url: job.url
              }, (err)->
                if err
                  logger.error(err)
                # We have to do something here
                cbp()
              )
            else
              cbp()
        ], (err)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

newChallengeForInterested = (job, callback)->
  async.parallel([
    (cbp)->
      collections.jobs.add({
        type: "EMAIL"
        emailType: "CHALLENGED"
        to: job.challenge.challenged.author.email
        challenge: job.challenge
        conversationTitle: job.conversationTitle
        siteName: job.siteName
        url: job.url
        uid: "EMAIL_CHALLENGED_#{job.uid}_to_#{job.challenge.challenged.author.email}"
        email_reply_to: "#{build_reply_to('reply', job.siteName, job.challenge._id, job.challenge.challenged.author._id, config.emailSubjectKey)}"
        email_from: "#{job.challenge.challenger.author.name}"
        can_reply: true
      }, cbp)
    (cbp)->
      addNotification({
        type: "CHALLENGED"
        user: job.challenge.challenged.author._id
        sourceUser: job.challenge.challenger.author._id
        challenge: collections.comments.toClient(_.extend({}, job.challenge,
          {
            challenged: _.extend({}, job.challenge.challenged, {author: job.challenge.challenged.author._id}),
            challenger: _.extend({}, job.challenge.challenger, {author: job.challenge.challenger.author?._id})
          }))
        siteName: job.siteName
        context: job.context
        url: job.url
      }, cbp)
  ], callback)

module.exports.newChallenge = (job, callback)->
  cf = new ContentFilter()
  async.series([
    (cb)->
      job.original_challenger_text = job.challenge.challenger.text
      cf.formatAll(job.challenge.challenger.text, {includeAt: true}, (err, text, html)->
        job.challenge.challenger.text = text
        job.challenge.challenger.ptext = html
        cb(err)
      )
    (cb)->
      cf.formatAll(job.challenge.challenged.text, {includeAt: true}, (err, text, html)->
        job.challenge.challenged.text = text
        job.challenge.challenged.ptext = html
        cb(err)
      )
    (cb)->
      async.parallel([
        (cbp)->
          collections.users.findOne({_id: job.challenge.challenged.author}, cbp)
        (cbp)->
          collections.users.findOne({_id: job.challenge.challenger.author}, cbp)
        (cbp)->
          collections.conversations.findOne({_id: job.challenge.context},(err, context)->
            cbp(err, context.text)
            )
      ], (err, results)->
        [job.challenge.challenged.author, job.challenge.challenger.author, job.conversationTitle] = results
        cb()
      )
    (cb)->
      async.parallel([
        (cbp)->
          if job.challenge.challenged.author?.subscribe.own_activity && job.challenge.challenged.author?.verified
            newChallengeForInterested(job, cbp)
          else
            cbp()
        (cbp)->
          newChallengeForAll(job, cbp)
        # FIXME: buggy
        # (cbp)->
        #   newCommentForMentioned(job, cbp)
        (cbp)->
          if !job.approvedLater
            newChallengeForMod(job, cbp)
          else
            cbp()
      ], cb)
  ], callback)

module.exports.endChallenge = (job, callback)->
  cf = new ContentFilter()
  async.series([
    (cb)->
      cf.formatAll(job.challenge.challenger.text, {includeAt: true}, (err, text, html)->
        job.challenge.challenger.text = text
        job.challenge.challenger.ptext = html
        cb(err)
      )
    (cb)->
      cf.formatAll(job.challenge.challenged.text, {includeAt: true}, (err, text, html)->
        job.challenge.challenged.text = text
        job.challenge.challenged.ptext = html
        cb(err)
      )
    (cb)->
      async.parallel([
        (cbp)->
          collections.users.findOne({_id: job.winner.author}, cbp)
        (cbp)->
          collections.users.findOne({_id: job.loser.author}, cbp)
        (cbp)->
          collections.conversations.findOne({_id: job.challenge.context}, (err, context)->
            cbp(err, context.text)
            )
      ], (err, results)->
        [job.winner.author, job.loser.author, job.conversationTitle] = results
        cb()
      )
    (cb)->
      async.parallel([
        (cbp)->
          if job.winner.author?.subscribe.own_activity && job.winner.author.verified
            collections.jobs.add({
              type: "EMAIL"
              emailType: "WIN_CHALLENGE"
              to: job.winner.author.email
              no_votesWinner: job.winner.no_votes
              no_votes_downWinner: job.winner.no_votes_down
              no_votesLoser: job.loser.no_votes
              no_votes_downLoser: job.loser.no_votes_down
              nameWinner: job.winner.author.name
              nameLoser: job.loser.author.name
              challenge: job.challenge
              conversationTitle: job.conversationTitle
              siteName: job.siteName
              url: job.url
              uid: "EMAIL_WIN_CHALLENGE_#{job.challenge._id.toHexString()}_to_#{job.winner.author.email}"
              # email_from: "#{job.siteName} <#{config.email.notifications.fromAddress}>"
              email_reply_to: "#{build_reply_to('reply', job.siteName, job.challenge._id, job.winner.author._id, config.emailSubjectKey)}"
              can_reply: true
            }, cbp)
          else
            cbp()
        (cbp)->
          if job.winner.author?.subscribe.own_activity
            addNotification({
              type: "WIN_CHALLENGE"
              user: job.winner.author._id
              no_votesWinner: job.winner.no_votes
              no_votes_downWinner: job.winner.no_votes_down
              no_votesLoser: job.loser.no_votes
              no_votes_downLoser: job.loser.no_votes_down
              challenge: collections.comments.toClient(job.challenge)
              siteName: job.siteName
              context: job.context
              url: job.url
            }, cbp)
          else
            cbp()
        (cbp)->
          if job.loser.author?.subscribe.own_activity && job.loser.author.verified
            collections.jobs.add({
              type: "EMAIL"
              emailType: "LOSE_CHALLENGE"
              to: job.loser.author.email
              no_votesWinner: job.winner.no_votes
              no_votes_downWinner: job.winner.no_votes_down
              no_votesLoser: job.loser.no_votes
              no_votes_downLoser: job.loser.no_votes_down
              nameWinner: job.winner.author.name
              nameLoser: job.loser.author.name
              challenge: job.challenge
              conversationTitle: job.conversationTitle
              siteName: job.siteName
              url: job.url
              uid: "EMAIL_LOSE_CHALLENGE_#{job.challenge._id.toHexString()}_to_#{job.loser.author.email}"
              # email_from: "#{job.siteName} <#{config.email.notifications.fromAddress}>"
              email_reply_to: "#{build_reply_to('reply', job.siteName, job.challenge._id, job.loser.author._id, config.emailSubjectKey)}"
              can_reply: true
            }, cbp)
          else
            cbp()
        (cbp)->
          if job.loser.author?.subscribe.own_activity
            addNotification({
              type: "LOSE_CHALLENGE"
              user: job.loser.author._id
              no_votesWinner: job.winner.no_votes
              no_votes_downWinner: job.winner.no_votes_down
              no_votesLoser: job.loser.no_votes
              no_votes_downLoser: job.loser.no_votes_down
              challenge: collections.comments.toClient(job.challenge)
              siteName: job.siteName
              context: job.context
              url: job.url
            }, cbp)
          else
            cbp()
      ], cb)
  ], callback)

module.exports.vote = (job, callback)->
  async.series([
    (cb)->
      collections.users.findOne({_id: job.challenge[job.side].author}, (err, result)->
        if !err
          job.challenge[job.side].author = result
        cb(err)
      )
    (cb)->
      if job.challenge[job.side].author
        async.parallel([
          # (cbp)->
          #   if job.challenge[job.side].author.subscribe.own_activity && job.challenge[job.side].author.verified
          #     collections.jobs.add({
          #       type: "EMAIL"
          #       emailType: "VOTE"
          #       to: job.challenge[job.side].author.email
          #       no_votes: job.challenge[job.side].no_votes
          #       challenge: job.challenge
          #       siteName: job.siteName
          #       up: job.up
          #       url: job.url
          #     }, cbp)
          #   else
          #     process.nextTick(cbp)
          (cbp)->
            addNotification({
              type: "VOTE"
              user: job.challenge[job.side].author._id
              no_votes: job.challenge[job.side].no_votes
              challenge: collections.comments.toClient(_.extend({}, job.challenge,
                {
                  challenged: _.extend({}, job.challenge.challenged, {author: job.challenge.challenged.author?._id}),
                  challenger: _.extend({}, job.challenge.challenger, {author: job.challenge.challenger.author?._id})
                }))
              siteName: job.siteName
              up: job.up
              context: job.context
              url: job.url
              by: if job.up then job.by?._id else null
            }, cbp)
        ], cb)
      else
        cb()
  ], callback)

module.exports.voteUpDown = (job, callback)->
  async.series([
    (cb)->
      collections.users.findOne({_id: job.challenge[job.side].author}, (err, result)->
        if !err
          job.challenge[job.side].author = result
        cb(err)
      )
    (cb)->
      if job.challenge[job.side].author
        async.parallel([
          # (cbp)->
          #   if job.challenge[job.side].author.subscribe.own_activity && job.challenge[job.side].author.verified
          #     collections.jobs.add({
          #       type: "EMAIL"
          #       emailType: "VOTE_UPDOWN"
          #       to: job.challenge[job.side].author.email
          #       no_votes: job.challenge[job.side].no_votes
          #       no_votes_down: job.challenge[job.side].no_votes_down
          #       challenge: job.challenge
          #       siteName: job.siteName
          #       up: job.up
          #       url: job.url
          #     }, cbp)
          #   else
          #     process.nextTick(cbp)
          (cbp)->
            addNotification({
              type: "VOTE_UPDOWN"
              user: job.challenge[job.side].author._id
              no_votes: job.challenge[job.side].no_votes
              no_votes_down: job.challenge[job.side].no_votes_down
              challenge: collections.comments.toClient(_.extend({}, job.challenge,
                {
                  challenged: _.extend({}, job.challenge.challenged, {author: job.challenge.challenged.author?._id}),
                  challenger: _.extend({}, job.challenge.challenger, {author: job.challenge.challenger.author?._id})
                }))
              siteName: job.siteName
              up: job.up
              context: job.context
              url: job.url
              by: if job.voteChanges.down <= 0 && job.voteChanges.up > 0 then job.by?._id else null
            }, cbp)
        ], cb)
      else
        cb()
  ], callback)

module.exports.likeComment = (job, callback)->
  if job.comment.type == "QUESTION"
    process.nextTick(callback)
  else
    async.series([
      (cb)->
        collections.users.findOne({_id: job.comment.author}, (err, result)->
          if !err
            job.comment.author = result
          cb(err)
        )
      (cb)->
        if job.comment.author
          async.parallel([
            # (cbp)->
            #   if job.comment.author.subscribe.own_activity && job.comment.author.verified
            #     collections.jobs.add({
            #       type: "EMAIL"
            #       emailType: if job.comment.cat == "QUESTION" && job.comment.level == 2 then "LIKE_ANSWER" else "LIKE_COMMENT"
            #       to: job.comment.author.email
            #       no_likes: job.comment.no_likes
            #       text: job.comment.text
            #       siteName: job.siteName
            #       up: job.up
            #       url: job.url
            #     }, cb)
            #   else
            #     process.nextTick(cbp)
            (cbp)->
              addNotification({
                type: if job.comment.cat == "QUESTION" && job.comment.level == 2 then "LIKE_ANSWER" else "LIKE_COMMENT"
                user: job.comment.author._id
                no_likes: job.comment.no_likes
                comment: collections.comments.toClient(_.extend({}, job.comment, {author: job.comment.author?._id}))
                siteName: job.siteName
                up: job.up
                context: job.context
                url: job.url
                by: if job.up then jobs.by?._id else null
              }, cbp)
          ], cb)
        else
          cb()
    ], callback)

module.exports.betClosed = (job, callback)->
  notifyBetClosed(job.comment, (err)->
    if err
      logger.error(err)
    callback(err)
  )

module.exports.betForfClosed = (job, callback)->
  notifyBetForfClosed(job.comment, callback)

notifyBetForfClosed = (comment, callback)->
  # send notifications to all users involved in the bet (author + accepted)
  notif = {
    comment: comment
    url: urls.for_model("comment", comment)
    uid: "BET_FORF_CLOSED_#{comment._id}"
    siteName: comment.siteName
    type: 'BET_FORF_CLOSED'
  }
  async.waterfall([
    (cb)->
      util.load_field(comment, 'context', collections.conversations, cb)
    (comment, cb)->
      notif.conversationTitle = comment.context.text
      notif.context = comment.context
      async.parallel([
        (cbp)->
          async.waterfall([
            (cbi)->
              collections.users.findOne({_id: comment.author}, cbi)
            (user, cbi)->
              collections.notifications.send(user, user.email, notif, cbi)
          ], cbp)
        (cbp)->
          collections.users.findIter({_id: {$in: comment.bet_accepted}}, (user, done)->
            collections.notifications.send(user, user.email, notif, done)
          , cbp)
      ], cb)
  ], (err)->
    if err
      logger.error(err)
    callback(err)
  )

module.exports.betForfStarted = (job, callback)->
  notifyBetForfStarted(job.comment, (err)->
    if err
      logger.error(err)
    callback(err)
  )

notifyBetForfStarted = (comment, callback)->
  # send notifications to all users involved in the bet (author + accepted)
  notif = {
    comment: comment
    url: urls.for_model("comment", comment)
    uid: "BET_FORF_STARTED_#{comment._id}"
    siteName: comment.siteName
    type: 'BET_FORF_STARTED'
  }
  async.waterfall([
    (cb)->
      util.load_field(comment, 'context', collections.conversations, cb)
    (comment, cb)->
      notif.conversationTitle = comment.context.text
      notif.context = comment.context
      async.parallel([
        (cbp)->
          async.waterfall([
            (cbi)->
              collections.users.findOne({_id: comment.author}, cbi)
            (user, cbi)->
              collections.notifications.send(user, user.email, notif, cbi)
          ], cbp)
        (cbp)->
          collections.users.findIter({_id: {$in: comment.bet_accepted}}, (user, done)->
            collections.notifications.send(user, user.email, notif, done)
          , cbp)
      ], cb)
  ], (err)->
    if err
      logger.error(err)
    callback(err)
  )

notifyBetClosed = (comment, callback)->
  # send notifications to all users involved in the bet (author + accepted + pending)
  targeted_str = _.map(comment.bet_targeted, (id)-> id.toHexString())
  declined_str = _.map(comment.bet_declined, (id)-> id.toHexString())
  accepted_str = _.map(comment.bet_accepted, (id)-> id.toHexString())
  pending = _.difference(targeted_str, accepted_str, declined_str)
  pending_ids = _.map(pending, (idstr)-> dbutil.idFrom(idstr))
  notif = {
    comment: comment
    url: urls.for_model("comment", comment)
    uid: "BET_CLOSED_#{comment._id}"
    siteName: comment.siteName
    type: 'BET_CLOSED'
  }
  async.waterfall([
    (cb)->
      util.load_field(comment, 'context', collections.conversations, cb)
    (comment, cb)->
      notif.context = comment.context
      notif.conversationTitle = comment.context.text
      async.parallel([
        (cbp)->
          async.waterfall([
            (cbi)->
              collections.users.findOne({_id: comment.author}, cbi)
            (user, cbi)->
              collections.notifications.send(user, user.email, notif, cbi)
          ], cbp)
        (cbp)->
          collections.users.findIter({_id: {$in: comment.bet_accepted}}, (user, done)->
            collections.notifications.send(user, user.email, notif, done)
          , cbp)
        (cbp)->
          collections.users.findIter({_id: {$in: pending_ids}}, (user, done)->
            collections.notifications.send(user, user.email, notif, done)
          , cbp)
      ], cb)
  ], (err)->
    if err
      logger.error(err)
    callback(err)
  )

notifyFundedComment = (job, userId, comment, byUser, callback)->
  debug("Sending email to funded user: #{userId}")
  debug(JSON.stringify(comment, null, 2))
  collections.users.findOne({_id: dbutil.idFrom(userId), verified: true}, (err, user)->
    if !user
      debug("no such user: #{userId}")
      return callback(err)

    async.parallel([
      (cbp)->
        if !user.subscribe?.ignited
          debug("user #{userId} doesn't want email notifications")
          return cbp(null)

        debug("add funded email job")
        collections.jobs.add({
          type: "EMAIL"
          emailType: "IGNITE"
          to: user.email
          comment: job.comment
          conversationTitle: job.conversationTitle || ""
          siteName: job.siteName
          url: job.url
          host: config.serverHost
          by: byUser
          uid: "EMAIL_IGNITE_#{job.uid}_to_#{user.email}"
          can_reply: false
        }, cbp)
      (cbp)->
        debug("add funded notification: #{job.url}")
        addNotification({
          type: "IGNITE_COMMENT"
          user: user._id
          comment: collections.comments.toClient(_.extend({}, job.comment))
          by: byUser._id
          siteName: job.siteName
          context: job.context
          url: job.url
        }, cbp)
    ], callback)
  )

module.exports.fundComment = (job, callback)->
  notifyFundedComment(job, job.comment.author, job.comment, job.by, callback)

module.exports.likeCommentUpDown = (job, callback)->
  if job.comment.type == "QUESTION"
    process.nextTick(callback)
  else
    async.series([
      (cb)->
        collections.users.findOne({_id: job.comment.author}, (err, result)->
          if !err
            job.comment.author = result
          cb(err)
        )
      (cb)->
        if job.comment.author
          async.parallel([
            # (cbp)->
            #   if job.comment.author.subscribe.own_activity && job.comment.author.verified
            #     collections.jobs.add({
            #       type: "EMAIL"
            #       emailType: if job.comment.cat == "QUESTION" && job.comment.level == 2 then "LIKE_ANSWER_UPDOWN" else "LIKE_COMMENT_UPDOWN"
            #       to: job.comment.author.email
            #       no_likes: job.comment.no_likes
            #       no_likes_down: job.comment.no_likes_down
            #       text: job.comment.text
            #       siteName: job.siteName
            #       up: job.up
            #       url: job.url
            #       likeChanges: job.likeChanges
            #     }, cb)
            #   else
            #     process.nextTick(cbp)
            (cbp)->
              addNotification({
                type: if job.comment.cat == "QUESTION" && job.comment.level == 2 then "LIKE_ANSWER_UPDOWN" else "LIKE_COMMENT_UPDOWN"
                user: job.comment.author._id
                no_likes: job.comment.no_likes
                comment: collections.comments.toClient(_.extend({}, job.comment, {author: job.comment.author?._id}))
                siteName: job.siteName
                up: job.up
                context: job.context
                url: job.url
                likeChanges: job.likeChanges
                by: if job.likeChanges.down <= 0 && job.likeChanges.up > 0 then job.by?._id else null
              }, cbp)
          ], cb)
        else
          cb()
    ], callback)

module.exports.likeStatus = (job, callback)->

  map = ->
    if @dir == 1 && @cauthor
      emit(@cauthor, {up: 1, down: 0})
    else if @dir == -1
      emit(@cauthor, {up: 0, down: 1})

  reduce = (key, values)->
    result = {up: 0, down: 0}
    for value in values
      result.up += value.up
      result.down += value.down
    return result

  async.waterfall([
    (cb)->
      try
        collections.likes.mapReduce(map, reduce, {query: {_id: {$gte: dbutil.idFromTime(job.start.getTime()), $lt: dbutil.idFromTime(job.end.getTime())}}, out: {replace: job.uid}, readPreference: "primary"}, cb)
      catch e
        cb(e, {retry: true})
    (col, cb)->
      col.find({}, cb)
    (cursor, cb)->
      iter = (err, item)->
        if err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        if !item
          return cb()
        async.waterfall([
          (cbi)->
            collections.users.findOne({_id: item._id, "subscribe.own_activity": true, verified: true}, cbi)
          (user, cbi)->
            if user
              return collections.jobs.add({
                type: "EMAIL",
                emailType: "LIKE_STATUS",
                to: user.email,
                user: user,
                status: item.value,
                uid: "EMAIL_#{job.uid}_#{user._id.toHexString()}"
                can_reply: false
              }, cbi)
            cbi()
        ], (err, result)->
          if err
            cursor.close()
            return cb(err)
          cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

module.exports.notifyEndChallenge = (job, callback)->
  async.waterfall([
    (cb)->
      async.parallel([
        (cbp)->
          collections.users.findOne({_id: job.challenge.challenged.author, "subscribe.own_activity": true, verified: true}, cbp)
        (cbp)->
          collections.users.findOne({_id: job.challenge.challenger.author, "subscribe.own_activity": true, verified: true}, cbp)
        (cbp)->
          collections.conversations.findOne({_id: job.challenge.context},cbp)
      ], cb)
    (result, cb)->
      [challenged, challenger, context] = result
      timeFromNow = moment(job.challenge.ends_on).fromNow()
      async.parallel([
        (cbp)->
          if challenged
            return collections.jobs.add({
              type: "EMAIL",
              emailType: "NOTIFY_END_CHALLENGE",
              to: challenged.email,
              siteName: job.challenge.siteName
              challenge: job.challenge,
              conversationTitle: context.text
              url: job.url
              uid: "EMAIL_#{job.uid}_to_#{challenged.email}"
              timeFromNow: timeFromNow
              # email_from: "#{job.challenge.siteName} <#{config.email.notifications.fromAddress}>"
              email_reply_to: "#{build_reply_to('reply', job.challenge.siteName, job.challenge._id, challenged._id, config.emailSubjectKey)}"
              can_reply: true
            }, cbp)
          cbp()
        (cbp)->
          if challenger
            return collections.jobs.add({
              type: "EMAIL",
              emailType: "NOTIFY_END_CHALLENGE",
              to: challenger.email,
              siteName: job.challenge.siteName
              challenge: job.challenge,
              conversationTitle: context.text
              url: job.url
              uid: "EMAIL_#{job.uid}_to_#{challenger.email}"
              timeFromNow: timeFromNow
              # email_from: "#{job.challenge.siteName} <#{config.email.notifications.fromAddress}>"
              email_reply_to: "#{build_reply_to('reply', job.challenge.siteName, job.challenge._id, challenger._id, config.emailSubjectKey)}"
              can_reply: true
            }, cbp)
          cbp()
      ], cb)
  ], callback)

module.exports.mergeUsers = (job, callback)->
  options = {force_unverified: !!job.force_unverified}
  if job.from._id
    collections.users.merge(job.from._id, job.into._id, options, callback)
  else if job.from.type == "guest"
    collections.users.mergeGuests(job.into._id, callback)
  else if job.from.type in ['imported']
    query = {type: job.from.type, email: job.from.email}
    if job.from.site
      query.site = job.from.site
    collections.users.findIter(query
    , (user, cb)->
      collections.jobs.add({type: "MERGE_USERS", from: user, into: job.into, force_unverified: job.force_unverified}, cb)
    , (err)->
      if err
        logger.error(err)
      callback(err)
    )
  else
    return callback()

module.exports.mergeSites = (job, callback)->
  collections.sites.merge(job.from.name, job.into.name, callback)

module.exports.updateTrustedBadge = (job, callback)=>
  async.waterfall([
    (cb)=>
      # NOTE(msb): we use a batch size of 5 items in order to keep the cursor
      # busy with frequent fetch requests; otherwise, if our item processing
      # takes too long, the cursor might timeout.
      # TODO(msb): disable timeout (using {timeout: false}) if the batchSize
      # doesn't solve the problem
      collections.profiles.find({}, {batchSize: 5}, cb)
    (cursor, cb)=>
      iter = (err, prof)=>
        if !prof or err
          if !cursor.isClosed()
            cursor.close()
          return cb(err)
        async.waterfall([
          (cbw)=>
            checkTrusted(prof, cbw)
          (trusted, cbw)=>
            trusted ?= false
            collections.profiles.findAndModify({_id: prof._id}, [], {$set: {trusted: trusted}}, cbw)
          ], ()=>
            cursor.nextObject(iter)
        )
      cursor.nextObject(iter)
  ], callback)

make_debug = (prefix)->
  return _.partial(debug, prefix)

checkTrusted = (prof, callback)->
  dbg = make_debug("checkTrusted(#{prof._id}/#{prof.userName}): ")
  now = new Date().getTime()
  upcount = downcount = null
  social_verified = []
  comment_count = null
  challenge_count = null
  question_count = null
  async.waterfall([
    (cb)->
      collections.users.findOne({_id: prof.user}, cb)
    (user, cb)->
      for social in ["facebook", "twitter", "google"]
        if user?.logins_profiles?[social]?._json?.verified
          dbg("has #{social}")
          social_verified.push(social)
        else if social == "twitter"
          json = user?.logins_profiles?[social]?._json || {}
          if json.followers_count >= 20
            if moment(new Date(json.created_at)).add(30, "days").utc() < moment.utc()
              dbg("has more than 30 days #{social} with more than 20 followers")
              social_verified.push(social)
        else if social == "google"
          if user?.logins_profiles?[social]?._json?.verified_email
            dbg("has #{social}")
            social_verified.push(social)
      collections.comments.count({author: prof.user, siteName: prof.siteName, deleted: {$ne: true}, approved: true}, cb)
    (count, cb)->
      dbg("comments: #{count}")
      comment_count = count
      collections.comments.count({"challenger.author": prof.user, siteName: prof.siteName, deleted: {$ne: true}, approved: true}, cb)
    (count, cb)->
      dbg("challenges: #{count}")
      challenge_count = count
      collections.comments.count({author: prof.user, siteName: prof.siteName, deleted: {$ne: true}, approved: true, type: "QUESTION"}, cb)
    (count, cb)->
      dbg("questions: #{count}")
      question_count = count
      collections.likes.count({dir: 1, siteName: prof.siteName, cauthor: prof.user}, cb)
    (count, cb)->
      upcount = count
      collections.likes.count({dir: util.getValue("trustedLikePoints"), siteName: prof.siteName, cauthor: prof.user}, cb)
    (count, cb)->
      upcount += util.getValue("trustedLikePoints") * count
      dbg("upvotes: #{upcount}")
      collections.likes.count({dir: -1, siteName: prof.siteName, cauthor: prof.user}, cb)
    (count, cb)->
      downcount = count
      collections.likes.count({dir: -util.getValue("trustedLikePoints"), siteName: prof.siteName, cauthor: prof.user}, cb)
    (count, cb)->
      downcount += util.getValue("trustedLikePoints") * count
      dbg("downvotes: #{downcount}")
      collections.profiles.update({_id: prof._id}, {
        $set: {
          "stats.no_comments": comment_count
          "stats.no_questions": question_count
          "stats.no_challenges": challenge_count
          "stats.trusted.upvotes": upcount,
          "stats.trusted.downvotes": downcount,
          "stats.trusted.social_verified": social_verified,
          "stats.trusted.required_comments_count": util.getValue("trustedCommentCount")
          "stats.trusted.required_ratio": util.getValue("trustedLikeRatio")
          "stats.trusted.required_social_count": 1
          "stats.trusted.required_age": util.getValue("trustedTime")
        }
      }, ()->
        cb(null)
      )
    (cb)->
      if prof.permissions?.moderator
        dbg("is moderator, return true")
        callback(null, true)
        return
      if prof.created > (now - util.getValue("trustedTime"))
        dbg("profile too new")
        callback(null, false) # user is too new)
        return
      if social_verified.length < 1
        dbg("no social verification")
        callback(null, false) # unverified
        return
      if comment_count < util.getValue("trustedCommentCount")
        dbg("not enough comments")
        callback(null, false) # not enough comments
        return
      ratio = upcount/Math.max(1, downcount) # +1 to avoid divide by 0
      if ratio < util.getValue("trustedLikeRatio")
        dbg("low vote ratio")
        callback(null, false) # like ratio below threshhold
        return
      else
        dbg("all ok")
        cb(null)
    ], (err)->
      if err
        dbg("error, not trusted")
        callback(err, false)
      else
        callback(null, true)
      )

notifyCompetitionAll = (site, notif, callback)->
  async.waterfall([
    (cb)->
      collections.profiles.find({siteName: site}, cb)
    (cursor, cb)->
      iter = (err, prof)->
        if !prof
          if !cursor.isClosed()
            cursor.close()
          return cb(err)

        addNotification(_.extend({}, {user: prof.user}, notif), (err)->
          debug("notified #{prof.user} about #{notif.title}")
          if err
            logger.error(err)
          cursor.nextObject(iter)
        )

      cursor.nextObject(iter)
  ], callback)

module.exports.notifyStartCompetition = (job, callback)->
  debug("NOTIFY COMPETITION START: #{job.competition.title}")
  debug(JSON.stringify(job.competition, null, 2))
  in_days = Math.ceil(moment.utc(job.competition.start).diff(moment.utc(), "days", true))

  notif = {
    type: if in_days < 1 then "COMPETITION_START" else "COMPETITION_STARTING"
    comp_id: job.competition._id
    title: job.competition.title
    rules_url: job.competition.rules_url
    days: in_days
  }
  notifyCompetitionAll(job.competition.site, notif, callback)

module.exports.notifyEndCompetition = (job, callback)->
  debug("NOTIFY COMPETITION END: #{job.competition.title}")
  debug(JSON.stringify(job.competition, null, 2))
  in_days = Math.ceil(moment.utc(job.competition.end).diff(moment.utc(), "days", true))

  notif = {
    type: if in_days < 1 then "COMPETITION_END" else "COMPETITION_ENDING"
    comp_id: job.competition._id
    title: job.competition.title
    rules_url: job.competition.rules_url
    days: in_days
  }
  notifyCompetitionAll(job.competition.site, notif, callback)

module.exports.notifyPromotedComment = (job, callback)->
  async.parallel([
    (cb)->
      if job.promoter._id?.toHexString() and job.user.toHexString() != job.promoter._id.toHexString()
        addNotification({
          type: "PROMOTED_COMMENT",
          user: job.user,
          siteName: job.siteName,
          context: job.context,
          comment: job.comment
          url: job.url
          uid: job.uid
        }, cb)
      else
        cb(null)
    (cb)->
      async.waterfall([
        (cbw)->
          collections.comments.find(
            {
              context: job.context
              promote: true
              deleted: {$ne: true}
              spam: false
            },
            {sort: [['promotePoints', -1]], limit: util.getValue("promotedLimit") + 1},
            cbw
          )
        (cursor, cbw)->
          cursor.toArray(cbw)
        (array, cbw)->
          if array.length > util.getValue("promotedLimit")
            demoted = array[util.getValue("promotedLimit")]
            addNotification({
              type: "OUTBID_COMMENT",
              user: demoted.author
              siteName: job.siteName,
              context: job.context,
              comment: demoted,
              url: urls.for_model("comment", demoted),
              uid: "OUTBID_COMMENT_#{demoted._id.toHexString()}"
            }, cbw)
          else
            cbw(null)
        ], cb)
    ], (err)->
      if err
        logger.error(err)
      callback(err)
    )

TABLE_FORMAT = "MM_DD_HH_mm"
BATCH_SIZE = 500
ELASTIC_SERVER = {
  hosts: [process.env.DB_ELASTIC || "localhost"]
  port: 9200
}

insert_batch_to_es = (es, batch, cb)->
  debug("inserting batch of #{batch.length}")
  return es.bulkIndex(batch, (err, data)->
    cb(err)
  )

full_stream_cassandra = (table, time, cas, es, last_site, last_conv, cb)->
  if last_site
    if last_conv
      debug("continuing to next conversation after '#{last_site}.#{last_conv}'")
      query = "SELECT site, conv, err, ok FROM #{table} WHERE site = ? AND conv > ? LIMIT #{BATCH_SIZE}"
      args = [last_site, last_conv]
    else
      debug("continuing to next site after '#{last_site}'")
      query = "SELECT site, conv, err, ok FROM #{table} WHERE token(site) > token(?) LIMIT #{BATCH_SIZE}"
      args = [last_site]
  else
    debug("beginning table #{table}")
    query = "SELECT site, conv, err, ok FROM #{table} LIMIT #{BATCH_SIZE}"
    args = []

  debug("streaming results of '#{query}' #{args}")
  cas.cql(query, args, (err, result)->
    debug("got cassandra results")
    if err
      debug("AND ERROR: #{err.name} - #{err.message}")
      cb(err)
    batch = []
    result?.forEach((row)->
      obj = {
        site: row.get("site").value
        conv: row.get("conv").value
        time: time.format("YYYY-MM-DDTHH:mm:ss")
        errors: row.get("err")?.value
        count: row.get("ok")?.value
      }
      batch.push(obj)
    )
    if batch.length > 0
      return insert_batch_to_es(es, batch, (err)->
        if err
          return cb(err)
        last_site = batch[batch.length - 1].site
        last_conv = batch[batch.length - 1].conv
        return full_stream_cassandra(table, time, cas, es, last_site, last_conv, cb)
      )
    else
      # no more results
      if last_conv
        # we had a conversation specified, time to move to next site
        return full_stream_cassandra(table, time, cas, es, last_site, null, cb)

    debug("no more results, finished streaming")
    return cb(err)
  )

process_all_rows = (cas, es, start, end, cb)->
  table_time = moment(start).startOf("day")
  table_name = "embed_count_#{table_time.format(TABLE_FORMAT)}"
  debug("streaming ALL from: #{table_name}")
  full_stream_cassandra(table_name, table_time, cas, es, null, null, (err)->
    if err
      cb(err)
    start = moment(start).add("days", 1) # moments are mutable, don't modify passed parameter
    if start < end
      debug("moving to next table (%j < %j)", start, end)
      return process_all_rows(cas, es, start, end, cb)
    debug("no more tables")
    return cb(err)
  )

cassandra_to_elastic = (job, callback)->
  esconf = {
    _index: "page_views"
    _type: "daily"
    server: ELASTIC_SERVER
  }

  casconf = {
    hosts: [process.env.DB_CASSANDRA || "localhost:9160"]
    keyspace: "burnzone"
    user: ""
    password: ""
  }

  debug("cassandra to elastic - started")
  debug("esconf: #{JSON.stringify(esconf, null, 2)}")
  debug("casconf: #{JSON.stringify(casconf, null, 2)}")

  es = elasticsearch(esconf)
  cas = new helenus.ConnectionPool(casconf)
  cas.connect((err, ks)->
    debug("CONNECTION", err, ks)
    if err
      return callback(err)

    start = moment(job.start_time).utc().startOf("day")
    end = moment(job.end_time).utc()

    debug("deleting duplicates from elasticsearch")
    es.deleteByQuery({}, {range: { time: { gte: start.format("YYYY-MM-DD"), lt: end.format("YYYY-MM-DD") }}}, (err, data)->
      if err
        debug("error deleting from elasticsearch")
        return callback(err)
      debug("deleted from elasticsearch")

      debug("moving data from cassandra to elasticsearch for dates [#{start.format("YYYY-MM-DD")}; #{end.format("YYYY-MM-DD")})")
      process_all_rows(cas, es, start, end, (err)->
        if err
          debug("FINISHING because of #{err.name} - #{err.message}")
        else
          debug("FINISHED successfully")
        return callback(err)
      )
    )
  )

dbg = require("debug")("worker:rollup")

module.exports.roll_up_page_views = (job, callback)->
  return cassandra_to_elastic(job, callback)

# Transfer data from a MongoDB cursor to an ElasticSearch index
# cursor: the MongoDB cursor
# es: the ElasticSearch connection, must be already configured with _type & _index
# callback: called when the transfer is finished OR an error was encountered
pipe_cursor_to_es = (cursor, es, keys, timestamp, callback)->
  batch = []

  batch_item = (err, item)->
    # if the item is null we either encountered an error or exhausted the cursor;
    # insert whatever we have in 'batch' and norify the callback
    if not item
      if not cursor.isClosed()
        cursor.close()
      if batch.length > 0
        return insert_batch_to_es(es, batch, (err_es)->
          callback(err or err_es)
        )
      return callback(err)

    doc = _.extend(_.pick(item.value, keys), {time: timestamp})

    batch.push(doc)

    # if we reached the batch maximum size we insert it to ES, reset it
    # and continue to next item
    if batch.length == BATCH_SIZE
      return insert_batch_to_es(es, batch, (err_es)->
        if err
          if not cursor.isClosed()
            cursor.close()
          return callback(err_es)
        batch = []
        cursor.nextObject(batch_item)
      )

    # batch not full, process next
    cursor.nextObject(batch_item)

  # start batching
  cursor.nextObject(batch_item)

module.exports.roll_up_comments = (job, callback)->
  esconf = {
    _index: "comments"
    _type: "daily"
    server: ELASTIC_SERVER
  }

  es = elasticsearch(esconf)
  dbg("comments esconf: #{JSON.stringify(esconf, null, 2)}")
  start = moment(job.start_time)
  end = moment(job.end_time)

  es.deleteByQuery({}, {range: { time: { gte: start.format("YYYY-MM-DD"), lt: end.format("YYYY-MM-DDTHH:mm:ss") }}}, (err, data)->
    if err
      return callback(err)

    dbg("DELETE #{start.format("YYYY-MM-DD")} - #{end.format("YYYY-MM-DD")}")
    dbg(JSON.stringify(data))

    map = ->
      emit(@context, {site: @siteName, conv: @uri, count: 1})
    reduce = (key, values)->
      total = 0
      for obj in values
        total += obj.count
      return {site: values[0].site, conv: values[0].conv, count: total}

    async.waterfall([
      (cb)->
        collections.comments.mapReduce(map, reduce, {query: {_id: {$gte: dbutil.idFromTime(job.start_time), $lt: dbutil.idFromTime(job.end_time)}}, out: {replace: "rollup_comments"}, readPreference: "primary"}, cb)
      (col, cb)->
        dbg("comments: query from #{job.start_time} to #{job.end_time} - #{dbutil.idFromTime(job.start_time)} to #{dbutil.idFromTime(job.end_time)}")
        col.find({}, cb)
      (cursor, cb)->
        dbg("comments: piping to ES")
        pipe_cursor_to_es(cursor, es, ["site", "conv", "count"], moment(job.start_time).startOf("day").format("YYYY-MM-DDTHH:mm:ss"), cb)
    ], callback)
  )

module.exports.roll_up_conversations = (job, callback)->
  esconf = {
    _index: "conversations"
    _type: "daily"
    server: ELASTIC_SERVER
  }

  es = elasticsearch(esconf)
  dbg("esconf: #{JSON.stringify(esconf, null, 2)}")
  start = moment(job.start_time)
  end = moment(job.end_time)

  es.deleteByQuery({}, {range: { time: { gte: start.format("YYYY-MM-DD"), lt: end.format("YYYY-MM-DDTHH:mm:ss") }}}, (err, data)->
    if err
      return callback(err)

    map = ->
      emit(@siteName, {site: @siteName, count: 1})
    reduce = (key, values)->
      total = 0
      for obj in values
        total += obj.count
      return {site: values[0].site, count: total}

    async.waterfall([
      (cb)->
        collections.conversations.mapReduce(map, reduce, {query: {_id: {$gte: dbutil.idFromTime(job.start_time), $lt: dbutil.idFromTime(job.end_time)}}, out: {replace: "rollup_conversations"}, readPreference: "primary"}, cb)
      (col, cb)->
        dbg("done reducing conversations")
        col.find({}, cb)
      (cursor, cb)->
        dbg("piping conversations")
        pipe_cursor_to_es(cursor, es, ["site", "conv", "count"], moment(job.start_time).startOf("day").format("YYYY-MM-DDTHH:mm:ss"), cb)
    ], callback)
  )

module.exports.roll_up_profiles = (job, callback)->
  esconf = {
    _index: "profiles"
    _type: "daily"
    server: ELASTIC_SERVER
  }

  es = elasticsearch(esconf)
  dbg("esconf: #{JSON.stringify(esconf, null, 2)}")
  start = moment(job.start_time)
  end = moment(job.end_time)

  es.deleteByQuery({}, {range: { time: { gte: start.format("YYYY-MM-DD"), lt: end.format("YYYY-MM-DDTHH:mm:ss") }}}, (err, data)->
    if err
      return callback(err)

    map = ->
      emit(@siteName, {site: @siteName, count: 1})

    reduce = (key, values)->
      total = 0
      for obj in values
        total += obj.count
      return {site: values[0].site, count: total}

    async.waterfall([
      (cb)->
        collections.profiles.mapReduce(map, reduce, {query: {_id: {$gte: dbutil.idFromTime(job.start_time), $lt: dbutil.idFromTime(job.end_time)}}, out: {replace: "rollup_profiles"}, readPreference: "primary"}, cb)
      (col, cb)->
        col.find({}, cb)
      (cursor, cb)->
        pipe_cursor_to_es(cursor, es, ["site", "count"], moment(job.start_time).startOf("day").format("YYYY-MM-DDTHH:mm:ss"), cb)
    ], callback)
  )

datastore = require("../../datastore")
BaseCol = require("../../datastore/base")

module.exports.roll_up_verified = (job, callback)->
  esconf = {
    _index: "verified"
    _type: "daily"
    server: ELASTIC_SERVER
  }

  es = elasticsearch(esconf)
  dbg("esconf: #{JSON.stringify(esconf, null, 2)}")
  start = moment(job.start_time)
  end = moment(job.end_time)

  es.deleteByQuery({}, {range: { time: { gte: start.format("YYYY-MM-DD"), lt: end.format("YYYY-MM-DDTHH:mm:ss") }}}, (err, data)->
    if err
      return callback(err)

    map = ->
      emit(@siteName, {site: @siteName, count: 1})

    reduce = (key, values)->
      total = 0
      for obj in values
        total += obj.count
      return {site: values[0].site, count: total}

    temp_col = new BaseCol({db: datastore.db, name: "rollup_userprofile"})

    async.waterfall([
      (cb)->
        dbg("finding verified users")
        collections.users.find({verified_time: {$gte: job.start_time, $lt: job.end_time}}, cb)
      (cursor, cb)->
        dbg("extracting profiles")
        iter = (err, item)->
          if not item
            dbg("no more users: #{JSON.stringify(err)}")
            return cb(err)
          dbg("got user #{item.name}")
          collections.profiles.findOne({user: item._id}, (err, prof)->
            if err
              dbg("failed to find profiles")
              return cb(err)
            if not prof
              dbg("no such profile")
              return cursor.nextObject(iter)
            temp_col.insert(prof, (err)->
              if err
                dbg("failed to insert to temp")
                return cb(err)
              dbg("INSERTED!")
              return cursor.nextObject(iter)
            )
          )
        cursor.nextObject(iter)
      (cb)->
        dbg("reducing profiles")
        temp_col.mapReduce(map, reduce, {query: {}, out: {replace: "rollup_verified"}, readPreference: "primary"}, cb)
      (col, cb)->
        col.find({}, cb)
      (cursor, cb)->
        dbg("piping profiles")
        pipe_cursor_to_es(cursor, es, ["site", "count"], moment(job.start_time).startOf("day").format("YYYY-MM-DDTHH:mm:ss"), cb)
    ], (err)->
      if err
        dbg("ERROR #{err.name} - #{err.message}")
      dbg("dropping temporary collection")
      temp_col.remove((err)->
        dbg("droped (err: #{JSON.stringify(err)})")
        callback(err)
      )
    )
  )

module.exports.roll_up_subscriptions = (job, callback)->
  esconf = {
    _index: "subscriptions"
    _type: "daily"
    server: ELASTIC_SERVER
  }

  es = elasticsearch(esconf)
  dbg("esconf: #{JSON.stringify(esconf, null, 2)}")
  start = moment(job.start_time)
  end = moment(job.end_time)

  es.deleteByQuery({}, {range: { time: { gte: start.format("YYYY-MM-DD"), lt: end.format("YYYY-MM-DDTHH:mm:ss") }}}, (err, data)->
    if err
      return callback(err)

    map = ->
      emit(@siteName, {site: @siteName, count: 1})

    reduce = (key, values)->
      total = 0
      for obj in values
        total += obj.count
      return {site: values[0].site, count: total}

    async.waterfall([
      (cb)->
        collections.subscriptions.mapReduce(map, reduce, {query: {_id: {$gte: dbutil.idFromTime(job.start_time), $lt: dbutil.idFromTime(job.end_time)}, context: null}, out: {replace: "rollup_subscriptions"}, readPreference: "primary"}, cb)
      (col, cb)->
        col.find({}, cb)
      (cursor, cb)->
        pipe_cursor_to_es(cursor, es, ["site", "count"], moment(job.start_time).startOf("day").format("YYYY-MM-DDTHH:mm:ss"), cb)
    ], callback)
  )

module.exports.roll_up_notifications = (job, callback)->
  esconf = {
    _index: "notifications"
    _type: "daily"
    server: ELASTIC_SERVER
  }

  es = elasticsearch(esconf)
  dbg("esconf: #{JSON.stringify(esconf, null, 2)}")
  start = moment(job.start_time)
  end = moment(job.end_time)

  es.deleteByQuery({}, {range: { time: { gte: start.format("YYYY-MM-DD"), lt: end.format("YYYY-MM-DDTHH:mm:ss") }}}, (err, data)->
    if err
      return callback(err)

    map = ->
      emit(@siteName, {site: @siteName, count: 1})

    reduce = (key, values)->
      total = 0
      for obj in values
        total += obj.count
      return {site: values[0].site, count: total}

    async.waterfall([
      (cb)->
        collections.notifications.mapReduce(map, reduce, {query: {_id: {$gte: dbutil.idFromTime(job.start_time), $lt: dbutil.idFromTime(job.end_time)}}, out: {replace: "rollup_notifications"}, readPreference: "primary"}, cb)
      (col, cb)->
        col.find({}, cb)
      (cursor, cb)->
        pipe_cursor_to_es(cursor, es, ["site", "count"], moment(job.start_time).startOf("day").format("YYYY-MM-DDTHH:mm:ss"), cb)
    ], callback)
  )

module.exports.updateUserProfiles = (job, callback)->
  collections.users.findOne({_id: job.userId}, (err, user)->
    if err
      debug("updateUserProfiles: userId not found: #{job.userId}")
      return callback(err)
    debug("updateUserProfiles: searching profiles for user '#{user.name}'")
    collections.profiles.update({user: job.userId}, {$set: {userName: user.name}}, {multi: true}, (err, count)->
      debug("updateUserProfiles: updated profiles #{count} for user '#{user.name}' <#{user.email}>")
      callback(err)
    )
  )

getFacebookPost = (job, callback)->
  debug("check FB post: #{job.share_id}")
  util.fbreq("GET", "/#{job.share_id}", {
    access_token: job.access_token
    app_id: job.app_id
  }, (code, headers, data) ->
    if code != 200
      callback(code, data)
    else
      callback(null, data)
  )

module.exports.checkSharedItem = (job, callback)->
  if job.network == "facebook"
    getFacebookPost(job, (err, fbpost)->
      if err || fbpost?.privacy?.value in [null, "CUSTOM", "SELF"]
        # take away the points if we awarded any
        debug("shared item #{job.share_id} no longer shared: #{err}/#{fbpost?.privacy?.value}")
        if job.points > 0
          debug("take away the points!")
          collections.sites.findOne({name: job.siteName}, (err, site)->
            if err
              return callback(err)
            collections.comments.updatePointsShareComment(job.user, site, job.context, job.item, false, (err, points)->
              if err
                return callback(err, {retry: true})
              debug("awarded negative points: #{points}")
              callback(null)
            )
          )
        else
          debug("no points to take away")
          callback(null)
      else
        debug("shared item has now visibility: #{fbpost.privacy.value}")
        if job.points == 0
          collections.sites.findOne({name: job.siteName}, (err, site)->
            if err
              return callback(err)
            collections.comments.updatePointsShareComment(job.user, site, job.context, job.item, true, (err, points)->
              if err
                return callback(err, {retry: true})
              debug("awarded points: #{points}")
              callback(null)
            )
          )
        else
          debug("the user keeps the points")
          callback(null)
    )
  else
    debug("unknown share type: #{job.network}")
    callback({error: "unknown share type", job: job})

module.exports.update_badges = (job, callback)->
  collections.sites.findIter({}, (site, cb)->
    badges = site.badges || (b for k, b of collections.profiles.badges)
    for b, index in badges
      b.id = index
    dbg = make_debug("update_badges(#{site.name})")
    dbg("removing old badges")
    # collections.profiles.update({siteName: site.name}, {$set: {badges: {}}}, {multi: true}, (err)->
    collections.badges.remove({siteName: site.name, manually_assigned: false}, (err)->
      dbg("updating badges")
      async.eachSeries(badges, (badge, cb)->
        if badge.manually_assigned
          dbg("badge #{badge.name} is a manually assigned badge")
          cb(null)
        match = {siteName: site.name}
        if badge.rule.type
          match.type = badge.rule.type
        if badge.registered_last_days
          match.profile_created = {$gte: moment.utc().subtract(badge.registered_last_days, "days").toDate()}
        if badge.verified
          match.user_verified = true
        if badge.since?.last_30_days
          match._id = {$gte: dbutil.idFromTime(moment.utc().subtract(30, "days").toDate().getTime())}
        if badge.since?.current_month
          match._id = {$gte: dbutil.idFromTime(moment.utc().startOf("month").toDate().getTime())}
        # TODO: more 'since' variations
        timestamp = moment.utc().format("YYYY_MM_DD")
        col_name = "_tmp_aggregation_transaction_#{timestamp}_#{mongo.ObjectID().toHexString()}"
        collections.transactions.aggregate([
          {$match: match},
          {$group: {
            _id: {user: "$user"}
            type: {$last: "$type"}
            site: {$last: "$siteName"}
            value: {$sum: if badge.points then "$value" else 1}
          }},
          {$sort: {value: -1}},
          {$out: col_name}
        ], (err)->
          if err
            cb(err)
            return
          tmp = new BaseCol({db: datastore.db, name: col_name})
          tmp.count({}, (err, count)->
            dbg("count is: #{count}")
            if badge.limit_percent
              limit = Math.round(badge.limit_percent * count / 100) || 1
            else
              limit = badge.limit || 0
            dbg("find in collection: #{col_name}: #{limit}")
            # tmp.find({value: {$gt: 0}}, {limit: limit}, (err, cursor)->
            tmp.find({}, (err, cursor)->
              dbg("---badge '#{badge.title}' for site #{site.name}: #{JSON.stringify(badge, null, 2)}")
              rank = 1
              util.iter_cursor(cursor, (item, next)->
                dbg("B: #{JSON.stringify(badge, null, 2)}")
                dbg("I: #{JSON.stringify(item, null, 2)}")
                collections.badges.findAndModify({siteName: item.site, user: item._id.user, badge_id: badge.id},
                  {},
                  {
                    siteName: item.site,
                    user: item._id.user,
                    badge_id: badge.id,
                    rank: rank,
                    value: item.value,
                    rank_cutoff: limit,
                    rank_last: count,
                    manually_assigned: false
                  },
                  {upsert: true}
                  (err)->
                    rank += 1
                    next(err)
                )
              , (err)->
                tmp.drop()
                cb(err)
              )
            )
          )
        )
      , cb)
    )
  , callback)

with_profiles_count_and_cursor = (siteName, cb)->
  async.parallel({
    count: (cb)->
      collections.profiles.count({siteName: siteName}, cb)
    cursor: (cb)->
      collections.profiles.find({siteName: siteName}, cb)
  }, (err, res)->
    if err
      cb(err)
    else
      cb(null, res.count, res.cursor)
  )

with_transactions_points_for_badge = (profile, comp, badge, cb)->
  match = {siteName: profile.siteName, user: profile.user}
  if badge.rule.type
    match.type = badge.rule.type
  if badge.registered_last_days
    match.profile_created = {$gte: moment.utc().subtract(badge.registered_last_days, "days").valueOf()}
  if badge.verified
    match.user_verified = true
  start = null
  end = null
  if badge.since?.last_30_days
    start = moment.utc().subtract(30, "days").toDate()
  if badge.since?.current_month
    start = moment.utc().startOf("month").toDate()
  if comp
    # only count transactions that fit the competition time
    if !start || start < comp.start
      start = comp.start
    if !end || end > comp.end
      end = comp.end
  if start
    match._id = {$gte: dbutil.idFromTime(start.getTime())}
  if end
    match._id = {$lte: dbutil.idFromTime(end.getTime())}
  # TODO: more 'since' variations
  timestamp = moment.utc().format("YYYY_MM_DD")
  collections.transactions.aggregate([
    {$match: match},
    {$group: {
      _id: {user: "$user"}
      value: {$sum: if badge.points then "$value" else 1}
    }},
  ], (err, agg)->
    if err
      cb(err)
    else
      cb(null, agg[0]?.value || 0)
  )

with_competitions_for_badge = (dbg, site, badge, cb)->
  now = moment().utc().toDate()
  dbg("searching for active competitions on #{site.name} for badge #{badge.id}")
  collections.competitions.find({site: site.name, start: {$lt: now}, notified_end: null, badge_id: badge.id}, (err, cursor)->
    if !cursor
      return cb(err, [])
    cursor.toArray((err, array)->
      cursor.close()
      dbg("found #{array.length} competitions on #{site.name}")
      cb(err, array)
    )
  )

update_badge = (dbg, site, profile, profiles_count, badge, points, comp, done)->
  dbg("#{profile.userName} has #{points} points for #{badge.id} and comp #{comp?._id} on site #{site.name}")
  query = {siteName: site.name, user: profile.user, badge_id: badge.id}
  to_set = {siteName: site.name, user: profile.user, badge_id: badge.id, value: points, rank_last: profiles_count}
  if comp
    query["competition"] = comp._id
    to_set["competition"] = comp._id
  else
    query["competition"] = {$exists: false}
  collections.badges.findAndModify(query,
    {},
    to_set,
    {upsert: true}
    (err)->
      dbg("updated badge for #{profile.userName}")
      done(err)
  )

update_badge_rank = (dbg, site, badge, comp, done)->
  dbg("updating rank for badge #{badge.id} and comp #{comp?._id} on site #{site.name}")
  query = {siteName: site.name, badge_id: badge.id, value: {$gt: 0}}
  query["competition"] = comp?._id
  collections.badges.count(query, (err, positive_badge_count)->
    if badge.limit_percent
      if positive_badge_count > 0
        limit = Math.round(badge.limit_percent * positive_badge_count / 100) || 1
      else
        limit = 0
    else
      limit = badge.limit || positive_badge_count
    query = {siteName: site.name, badge_id: badge.id}
    query["competition"] = comp?._id
    collections.badges.update(query, {$set: {rank_cutoff: limit}}, {multi: true, upsert: true}, (err)->
      dbg("UPDATED CUTOFF to #{limit} for #{badge.id}")
      rank = 1
      collections.badges.findIter(query, {sort: {value: -1}}, (badge, next)->
        dbg("updating badge")
        q = {_id: badge._id}
        q["competition"] = comp?._id
        collections.badges.update(q, {$set: {rank: rank}}, (err)->
          rank += 1
          next(err)
        )
      , (err)->
        dbg("updated all ranks")
        done(err)
      )
    )
  )

module.exports.update_badges_all = (job, job_done)->
  collections.sites.findIter({}, (site, next_site)->
    badges = site.badges || collections.profiles.getAllBadges()
    for b, index in badges
      b.id = index
      b.rank = 1
    dbg = make_debug("update_badges(#{site.name})")
    dbg("removing old badges for #{site.name}")
    collections.badges.remove({siteName: site.name, manually_assigned: {$ne: true}}, (err)->
      dbg("removed old badges for #{site.name}")
      with_profiles_count_and_cursor(site.name, (err, profiles_count, profiles_cursor)->
        dbg("updating badges for #{profiles_count} profiles")
        util.iter_cursor(profiles_cursor, (profile, next_profile)->
          if profile.permissions?.admin || profile.permissions?.moderator
            dbg("user #{profile.userName} is MOD on site #{profile.siteName}")
            return next_profile(null)
          dbg("updating profile for #{profile.userName} on #{site.name}")
          async.eachSeries(badges, (badge, done_badge)->
            if badge.manually_assigned
              dbg("badge #{badge.id} is manually assigned")
              return done_badge(null)
            dbg("updating badge #{badge.id} for #{profile.userName} on #{site.name}")
            with_competitions_for_badge(dbg, site, badge, (err, competitions)->
              competitions.push(null)
              async.eachSeries(competitions, (comp, next_comp)->
                dbg("update for competition #{comp?._id}")
                with_transactions_points_for_badge(profile, comp, badge, (err, points)->
                  if err
                    next_comp(err)
                    return
                  update_badge(dbg, site, profile, profiles_count, badge, points, comp, (err)->
                    next_comp(err)
                  )
                )
              , (err)->
                done_badge(err)
              )
            )
          , (err)->
            if err
              dbg("error iterating badges: #{err}")
            next_profile(err)
          )
        , (err)->
          if err
            dbg("error iterating profiles: #{err}")
          profiles_cursor.close()
          async.eachSeries(badges, (badge, done_badge_rank)->
            if badge.manually_assigned
              return done_badge_rank(null)
            with_competitions_for_badge(dbg, site, badge, (err, competitions)->
              competitions.push(null)
              async.eachSeries(competitions, (comp, done_comp)->
                update_badge_rank(dbg, site, badge, comp, done_comp)
              , (err)->
                done_badge_rank(err)
              )
            )
          , (err)->
            if err
              dbg("error updating all badges: #{err}")
            # ignore error
            next_site()
          )
        )
      )
    )
  , (err)->
    if err
      dbg("error iterating sites: #{err}")
    job_done(err)
  )

module.exports.endBets = (job, callback)->
  now = moment().valueOf()
  collections.comments.findIter({type: 'BET', bet_end_date: {$lte: now}, bet_status: 'open'}, (bet, done_bet)->
    collections.comments.endBet(bet, (err)->
      if err
        logger.error(err)
      done_bet()
    )
  , callback)

module.exports.endForfBets = (job, callback)->
  now = moment().valueOf()
  collections.comments.findIter({type: 'BET', bet_close_forf_date: {$lte: now}, bet_status: 'forf'}, (bet, done_bet)->
    collections.comments.endForfBet(bet, (err)->
      if err
        logger.error(err)
      done_bet()
    )
  , callback)

module.exports.startForfBets = (job, callback)->
  now = moment().valueOf()
  collections.comments.findIter({type: 'BET', bet_start_forf_date: {$lte: now}, bet_status: 'closed'}, (bet, done_bet)->
    collections.comments.startForfBet(bet, (err)->
      if err
        logger.error(err)
      done_bet()
    )
  , callback)

module.exports.betResolved = (job, callback)->
  async.waterfall([
    (cb)->
      collections.comments.resolveBetPoints(job.comment, cb)
  ], (err)->
    if err
      logger.error(err)
    callback()
  )

# this works for accept/decline/forfeit/claim
notifyBetAction = (job, to_user, notif_type, side, options, callback)->
  if _.isFunction(options)
    callback = options
    options = {}
  options ?= {}
  async.parallel([
    (cbp)->
      if !to_user.subscribe.own_activity
        return cbp()
      collections.jobs.add(_.extend({}, options, {
        type: "EMAIL",
        emailType: notif_type,
        to: to_user.email,
        siteName: job.comment.siteName,
        points: job.points,
        conversationTitle: job.conversationTitle,
        comment: job.comment,
        context: job.comment.context,
        url: job.url,
        uid: "EMAIL_#{notif_type}_#{job.comment._id}_#{job.by._id}_to_#{to_user.email}"
        by: job.by
        can_reply: false
      }), (err)->
        if err
          logger.error(err)
        cbp()
      )
    (cbp)->
      addNotification(_.extend({}, options, {
        type: notif_type
        comment: collections.comments.toClient(job.comment)
        user: to_user._id,
        siteName: job.comment.siteName,
        context: collections.conversations.toClient(job.context),
        url: job.url,
        by: collections.users.toClient(job.by)
      }), (err)->
        if err
          logger.error(err)
        cbp()
      )
  ], callback)

module.exports.betAccepted = (job, callback)->
  # notify the author and the rest of the participants (pending + currently accepted)
  targeted_str = _.map(job.comment.bet_targeted, (id)-> id.toHexString())
  accepted_woby = _.filter(job.comment.bet_accepted, (id)-> !id.equals(job.by._id))
  accepted_str = _.map(job.comment.bet_accepted, (id)-> id.toHexString())
  declined_str = _.map(job.comment.bet_declined, (id)-> id.toHexString())
  pending = _.difference(targeted_str, accepted_str, declined_str)
  pending_ids = _.map(pending, (idstr)-> dbutil.idFrom(idstr))
  bet = job.comment
  async.parallel([
    (cb)->
      async.waterfall([
        (cbi)->
          collections.users.findOne({_id: job.comment.author}, cbi)
        (user, cbi)->
          notifyBetAction(job, user, 'BET_ACCEPTED', 'joined', cbi)
      ], cb)
    (cb)->
      collections.users.findIter({_id: {$in: accepted_woby}}, (user, done)->
        notifyBetAction(job, user, 'BET_ACCEPTED', 'accepted', done)
      , cb)
    (cb)->
      collections.users.findIter({_id: {$in: pending_ids}}, (user, done)->
        notifyBetAction(job, user, 'BET_ACCEPTED', 'pending', done)
      , cb)
  ], (err)->
    if err
      logger.error(err)
    callback(err)
  )

module.exports.betDeclined = (job, callback)->
  # notify the author and the rest of the participants (pending + currently accepted)
  targeted_str = _.map(job.comment.bet_targeted, (id)-> id.toHexString())
  accepted_str = _.map(job.comment.bet_accepted, (id)-> id.toHexString())
  declined_str = _.map(job.comment.bet_declined, (id)-> id.toHexString())
  pending = _.difference(targeted_str, accepted_str, declined_str)
  pending_ids = _.map(pending, (idstr)-> dbutil.idFrom(idstr))
  async.parallel([
    (cb)->
      async.waterfall([
        (cbi)->
          collections.users.findOne({_id: job.comment.author}, cbi)
        (user, cbi)->
          notifyBetAction(job, user, 'BET_DECLINED', 'joined', cbi)
      ], cb)
    (cb)->
      collections.users.findIter({_id: {$in: job.comment.bet_accepted}}, (user, done)->
        notifyBetAction(job, user, 'BET_DECLINED', 'accepted', done)
      , cb)
    (cb)->
      collections.users.findIter({_id: {$in: pending_ids}}, (user, done)->
        notifyBetAction(job, user, 'BET_DECLINED', 'pending', done)
      , cb)
  ], (err)->
    if err
      logger.error(err)
    callback(err)
  )

module.exports.betForfeited = (job, callback)->
  # notify the author and accepted
  async.parallel([
    (cb)->
      if job.comment.author.equals(job.by._id)
        return cb()
      async.waterfall([
        (cbi)->
          collections.users.findOne({_id: job.comment.author}, cbi)
        (user, cbi)->
          notifyBetAction(job, user, 'BET_FORFEITED', 'joined', cbi)
      ], cb)
    (cb)->
      collections.users.findIter({_id: {$in: _.filter(job.comment.bet_accepted, (id)-> !id.equals(job.by._id))}}, (user, done)->
        notifyBetAction(job, user, 'BET_FORFEITED', 'accepted', done)
      , cb)
  ], (err)->
    if err
      logger.error(err)
    callback(err)
  )

module.exports.betClaimed = (job, callback)->
  # notify the author and accepted
  forfeited_str = {}
  for user_id in job.comment.bet_forfeited
    forfeited_str[user_id.toHexString()] = true
  claimed_str = {}
  for user_id in job.comment.bet_claimed
    claimed_str[user_id.toHexString()] = true
  source_side = collections.comments.getSideInBet(job.comment, job.by._id)
  async.parallel([
    (cb)->
      if job.comment.author.equals(job.by._id)
        return cb()
      async.waterfall([
        (cbi)->
          collections.users.findOne({_id: job.comment.author}, cbi)
        (user, cbi)->
          notifyBetAction(job, user, 'BET_CLAIMED', 'joined', {by_user_side: source_side, show_action_msg: !forfeited_str[user._id.toHexString()] && !claimed_str[user._id.toHexString()]}, cbi)
      ], cb)
    (cb)->
      collections.users.findIter({_id: {$in: _.filter(job.comment.bet_accepted, (id)-> !id.equals(job.by._id))}}, (user, done)->
        notifyBetAction(job, user, 'BET_CLAIMED', 'accepted', {by_user_side: source_side, show_action_msg: !forfeited_str[user._id.toHexString()] && !claimed_str[user._id.toHexString()]}, done)
      , cb)
  ], (err)->
    if err
      logger.error(err)
    callback(err)
  )

module.exports.betRemindForfeit = (job, callback)->
  notif_date = moment().valueOf() - util.getValue('notifForfBet')
  collections.comments.findIter({type: 'BET', bet_status: 'forf', bet_forf_started_at: {$lte: notif_date}, bet_notif_remind_forf: false, deleted: {$ne: true}, approved: true}, (comment, done)->
    collections.comments.notifyRemindForfeit(comment, (err)->
      if err
        logger.error(err)
      done()
    )
  , callback)

module.exports.betUnresolved = (job, callback)->
  notif_date = moment().valueOf() - util.getValue('betForfPeriod')
  collections.comments.findIter({type: 'BET', bet_status: 'forf', $or: [{bet_forf_started_at: {$lte: notif_date}}, {bet_requires_mod: true}], bet_notif_unresolved: false, deleted: {$ne: true}, approved: true}, (comment, done)->
    notifyBetUnresolved(comment, (err)->
      if err
        logger.error(err)
      done()
    )
  , callback)

notifyBetUnresolved = (comment, callback)->
  collections.comments.findAndModify({_id: comment._id, bet_notif_unresolved: false}, [], {$set: {bet_notif_unresolved: true, bet_requires_mod: true}, $inc: {_v: 1}}, {new: true}, (err, result)->
    if !comment
      return callback()
    debug('notifying moderator about bet unresolved', comment._id)
    async.waterfall([
      (cb)->
        util.load_field(comment, 'context', collections.conversations, cb)
      (result, cb)->
        comment = result
        collections.profiles.getModerators(comment.siteName, cb)
      (mods, cb)=>
        collections.comments.notifyModBets(comment, mods, {
          type: 'BET_UNRESOLVED',
          comment: comment,
          siteName: comment.siteName,
          context: comment.context,
          conversationTitle: comment.context.text,
          can_reply: false,
          url: urls.for_model("comment", comment),
          uid: "UNDECIDED_BET_#{comment._id}"
        }, {notif_type: 'mod'}, cb)
      (cb)->
        collections.users.findIter({_id: {$in: _.map(_.union(comment.bet_joined, comment.bet_accepted), (id)-> dbutil.idFrom(id))}}, (user, done)->
          collections.notifications.send(
            user,
            user.email,
            {
              comment: comment
              context: comment.context
              conversationTitle: comment.context.text
              url: urls.for_model("comment", comment)
              uid: "BET_SENT_TO_MOD_#{comment._id}"
              siteName: comment.siteName
              type: 'BET_SENT_TO_MOD'
            },
            (err)->
              if err
                logger.error(err)
              done()
          )
        , cb)
      (cb)->
        pubsub.contentUpdate(comment.siteName, comment.context._id || comment.context, collections.comments.toClient(comment))
        cb()
    ], (err)->
      callback(err, comment)
    )
  )

notifyBetResolvedPts = (bet, callback)->
  # notify users who have joined/accepted the bet
  collections.users.findIter({_id: {$in: _.map(_.union(bet.bet_joined, bet.bet_accepted), (id)-> dbutil.idFrom(id))}}, (user, done)->
    status_in_bet = collections.comments.getWinStatusInBet(bet, user._id)
    points = bet.bet_accepted_points[user._id.toHexString()]
    # notify win/loss
    async.parallel([
      (cbp)->
        collections.jobs.add({
          type: "EMAIL",
          emailType: if status_in_bet == 'winner' then 'WIN_BET' else 'LOSE_BET',
          to: user.email,
          siteName: bet.siteName,
          token: subscription.token,
          conv: bet.context,
          points: points,
          # conversationTitle: job.context.text,
          comment: bet,
          context: bet.context,
          url: bet.initialUrl,
          uid: "EMAIL_RESOLVE_#{bet._id}_to_#{user.email}"
          can_reply: false
        }, (err)->
          if err
            logger.error(err)
          # We have to do something here
          cbp()
        )
      (cbp)->
        addNotification({
          type: if status_in_bet == 'winner' then 'WIN_BET' else 'LOSE_BET',
          comment: bet,
          user: user,
          siteName: bet.siteName,
          context: bet.context,
          url: bet.initialUrl,
          points: points
        }, (err)->
          if err
            logger.error(err)
          cbp()
        )
    ], (err)->
      done()
    )
  , callback)

module.exports.update_premium_subscription = (job, job_done)->
  collections.sites.findIter({"premium.subscription.id": {$ne: null}}, (site, next_site)->
    collections.sites.validateSubscription(site, (err)->
      next_site(err)
    )
  , job_done)

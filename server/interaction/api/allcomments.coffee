collections = require("../../datastore").collections
response = require("./response")
async = require("async")
util = require("../../util")
debug = require("debug")("api:comments")
sharedUtil = require("../../shared/util")
handlers = require("../handlers")
sso = require("../../sso")
logger = require("../../logging").logger
moment = require("moment")

accept_bet = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    if !sharedUtil.isNonNegativeInt(req.body.points)
      response.sendObj(res)({invalid_points_value: true})
    req.body.points = parseInt(req.body.points)
    collections.comments.acceptBet(req.site, req.context, req.user, req.activity, req.body, response.sendObj(res, collections.comments.toClient))

decline_bet = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.declineBet(req.site, req.context, req.user, req.activity, response.sendObj(res, collections.comments.toClient))

end_bet = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.requestEndBet(req.site, req.context, req.user, req.activity, response.sendObj(res, collections.comments.toClient))

start_forf_bet = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.requestStartForfBet(req.site, req.context, req.user, req.activity, response.sendObj(res, collections.comments.toClient))

forfeit_bet = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.forfeitBet(req.site, req.context, req.user, req.activity, response.sendObj(res, collections.comments.toClient))

claim_bet = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.claimBet(req.site, req.context, req.user, req.activity, response.sendObj(res, collections.comments.toClient))

resolve_bet = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.resolveBet(req.site, req.context, req.user, req.activity, req.body, response.sendObj(res, collections.comments.toClient))

spam = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.setSpam(req.site, id, response.sendObj(res, collections.comments.toClient))

notspam = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.notSpam(req.site, id, response.sendObj(res, collections.comments.toClient))

approve = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.approve(req.site, id, req.user, response.sendObj(res, collections.comments.toClient))

clearFlags = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.clearFlags(req.site, id, req.user, response.sendObj(res, collections.comments.toClient))

flag = (idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections.comments.flag(req.site, id, req.user, req.profile, response.sendObj(res, collections.comments.toClient))

like = (idparam)->
  return (req, res, next)->
    id = req.params[idparam]
    up = util.jsparse(req.body.up) ? true
    if !(up?)
      res.send(400)
      return

    afterHandlers = (err)->
      if err
        return next(err)
      session = req.ip
      collections.comments.likeUpDown(req.site, id, req.user, req.profile, session, up, response.sendObj(res, collections.comments.toClient))

    if up
      afterHandlers()
    else
      async.series([
        (cb)->
          handlers.requireAuth(req, res, cb)
        (cb)->
          handlers.notBanned(req, res, cb)
      ], afterHandlers)

vote = (idparam)->
  return (req, res)->
    challenge = req.params[idparam]
    up = util.jsparse(req.body.up) ? true
    if !(up?)
      res.send(400)
      return
    side = req.body.side
    if !(side in ["challenged", "challenger"])
      res.send(400)
      return
    session = req.ip
    collections.comments.vote(req.site, challenge, req.user, req.profile, session, side, up, response.sendObj(res, collections.comments.toClient))

deletec = (idparam)->
  return (req, res)->
    keep_points = req.body.keep_points == "true"
    collections.comments.delete(req.site, req.params[idparam], keep_points, response.sendObj(res, collections.comments.toClient))

promotec = (idparam)->
  return (req, res)->
    collections.comments.promote(req.site, req.params[idparam], util.getValue("modPromotePoints"), req.user, response.sendObj(res, collections.comments.toClient))

selfpromotec = (req, res, next)->
  if sharedUtil.isNonNegativeInt(req.body.points)
    req.body.points = parseInt(req.body.points) || 0
  else
    return next({invalid_points_value: true})
  collections.comments.selfPromote(req.site, req.body.activity, req.body.points, req.user, response.sendObj(res, collections.comments.toClient))

demotec = (idparam)->
  return (req, res)->
    collections.comments.demote(req.site, req.params[idparam], response.sendObj(res, collections.comments.toClient))

destroy = (idparam)->
  return (req, res)->
    keep_points = req.body.keep_points == "true"
    collections.comments.destroy(req.site, req.params[idparam], keep_points, response.sendObj(res, collections.comments.toClient))

addComment = (req, res, next)->
  parentId = req.body.parent
  req.body.question = util.jsparse(req.body.question) || false
  if req.body.options
    req.body.options.promote = util.jsparse(req.body.options.promote) || false
    if req.body.promotePoints
      if sharedUtil.isNonNegativeInt(req.body.promotePoints)
        req.body.promotePoints = parseInt(req.body.promotePoints) || 0
      else
        return next({invalid_points_value: true})
  else
    req.body.options = {}
  if req.body.questionPointsOffered
    if sharedUtil.isNonNegativeInt(req.body.questionPointsOffered)
      req.body.questionPointsOffered = parseInt(req.body.questionPointsOffered)
    else
      return next({invalid_points_value: true})
  if !parentId && !req.body.forum
    return next({notsupported: true})
  if !sharedUtil.removeWhite(req.body.text)
    return next({invalid_text: true})
  if req.body.bet
    req.body.points = parseInt(req.body.points)
    req.body.ratio_joined = parseInt(req.body.ratio_joined)
    req.body.ratio_accepted = parseInt(req.body.ratio_accepted)
    req.body.end_date = parseInt(req.body.end_date)
    req.body.start_forf_date = parseInt(req.body.start_forf_date)
    req.body.max_points_user = parseInt(req.body.max_points_user)
  delete req.body.force_approved
  delete req.body._id
  delete req.body.forum
  collections.comments.addComment(req.site, req.user, req.profile, req.body, {ip: req.ip, user_agent: req.headers['user-agent']}, response.sendObj(res, collections.comments.toClient))

module.exports = (app)->

  app.get("/api/sites/:site/activities/:activity?", handlers.pagingModerator, handlers.decideModeratorForComments, handlers.fetchActivity, handlers.fetchContext, handlers.requireContextPermission, (req, res)->
    activity = req.params["activity"]
    isModerator = collections.profiles.isModerator(req.profile, req.site)
    if activity
      collections.comments.findActivityById(req.site, activity, req.wantsModerator, response.sendObj(res, _.partialEnd(collections.comments.toClient, req.wantsModerator, req.user)))
    else
      if !isModerator && !req.user?.zeus
        return response.handleError({needs_moderator: true}, res)
      if req.paging
        collections.comments.getSiteActivitiesPaged(req.site, null, true, req.paging.field, req.paging.dir, req.paging.from, req.profile || {user: req.user}, req.wantsPending, response.sendPagedArray(res, _.partialEnd(collections.comments.toClient, req.wantsModerator, req.user)))
      else
        response.handleError({notsupported: true}, res)
  )

  app.get('/api/sites/:site/bets/count', handlers.requirePremium, (req, res)->
    bet_status = req.query.status
    if !(bet_status? && bet_status != 'all')
      bet_status = null
    collections.comments.countSiteActivities(req.site, 'BET', {bet_status: bet_status, omit_rolledback: true}, response.sendValue(res))
  )

  app.get('/api/sites/:site/bets', handlers.requirePremium, handlers.paging('bets'), (req, res)->
    bet_status = req.query.status
    if !(bet_status? && bet_status != 'all')
      bet_status = null
    if req.paging
      collections.comments.getSiteActivitiesPaged(
        req.site,
        'BET',
        false,
        req.paging.field,
        req.paging.dir,
        req.paging.from,
        req.profile || {user: req.user},
        false,
        {bet_status: bet_status, omit_rolledback: true},
        response.sendPagedArray(res, _.partialEnd(collections.comments.toClient, req.wantsModerator, req.user))
      )
    else
      response.handleError({notsupported: true}, res)
  )

  app.get('/api/sites/:site/unresolved_bets', handlers.requirePremium, handlers.requireModerator, handlers.pagingModerator, handlers.decideModeratorForComments, (req, res)->
    if req.paging
      collections.comments.getUnresolvedBets(req.site, req.paging.field, req.paging.dir, req.paging.from, req.profile || {user: req.user}, response.sendPagedArray(res, _.partialEnd(collections.comments.toClient, req.wantsModerator, req.user)))
    else
      response.handleError({notsupported: true}, res)
  )

  app.get("/api/sites/:site/funded_activities", handlers.paging('funded_activities'), (req, res)->
    siteName = req.params["site"]
    if req.paging
      collections.comments.getSiteFundedActivitiesPaged(req.site, req.paging.field, req.paging.dir, req.paging.from, req.paging.limit, response.sendPagedArray(res, _.partialEnd(collections.comments.toClient, false, req.user)))
    else
      response.handleError({notsupported: true}, res)
  )

  app.put("/api/sites/:site/activities/:activity?", handlers.requireAuth, (req, res, next)->
    activity = req.params['activity']
    if req.body.text
      if !sharedUtil.removeWhite(req.body.text)
        return next({invalid_text: true})
    else if req.body.challenger?.text
      if !sharedUtil.removeWhite(req.body.challenger.text)
        return next({invalid_text: true})
    else
      return next({notsupported: true})
    collections.comments.modify(req.site, activity, req.user, req.profile, req.body, response.sendObj(res, collections.comments.toClient))
  )

  app.put("/api/sites/:site/activities/:activity/fund", handlers.requireAuth, (req, res, next)->
    activity = req.params["activity"]
    token = req.body?.token
    value = req.body?.value
    collections.comments.fund(req.site, activity, req.body?.side, req.user, token, value, response.sendObj(res, collections.comments.toClient))
  )

  app.get("/api/sites/:site/contexts/:context/allactivities", handlers.paging('activities'), handlers.fetchContext, handlers.requireContextPermission, (req, res)->
    siteName = req.params["site"]
    context = req.params["context"]
    if req.paging
      collections.comments.getAllActivitiesPaged(req.site, context, req.paging.field, req.paging.dir, req.paging.from, req.paging.limit, false,
        response.sendPagedArrayAsyncFilter(res, _.partialEnd(collections.comments.toClientWithVote, null, req.user), {async_filter: true}))
    else
      response.handleError({notsupported: true}, res)
      # collections.comments.getAllActivities(req.site, context, false, response.sendPagedCursor(res, collections.comments.toClient))
  )

  app.get("/api/sites/:site/contexts/:context/funded_activities", handlers.paging('funded_activities'), handlers.fetchContext, handlers.requireContextPermission, (req, res)->
    siteName = req.params["site"]
    context = req.params["context"]
    if req.paging
      collections.comments.getFundedActivitiesPaged(req.site, context, req.paging.field, req.paging.dir, req.paging.from, req.paging.limit, response.sendPagedArray(res, _.partialEnd(collections.comments.toClient, false, req.user)))
    else
      response.handleError({notsupported: true}, res)
  )

  app.get("/api/sites/:site/contexts/:context/promoted", handlers.paging('activities'), handlers.fetchContext, handlers.requireContextPermission, (req, res)->
    siteName = req.params["site"]
    context = req.params["context"]
    if req.paging
      collections.comments.getPromoted(req.site, context, req.paging.field, req.paging.dir, req.paging.from, false, response.sendPagedArray(res, _.partialEnd(collections.comments.toClient, null, req.user)))
    else
      response.handleError({notsupported: true}, res)
      # collections.comments.getAllActivities(req.site, context, false, response.sendPagedCursor(res, collections.comments.toClient))
  )

  app.post("/api/sites/:site/contexts/:context/comments", handlers.createUserWithContent, handlers.requireAuth, handlers.fetchContext, handlers.requireContextPermission, handlers.notBanned, (req, res, next)->
    req.body.parent = req.params["context"]
    req.body.top = true
    addComment(req, res, next)
  )

  app.post("/api/sites/:site/import", (req, res)->
    debug("body = #{JSON.stringify(req.body, null, 2)}")
    debug("got import request for: #{req.body?.auth}")
    hash = sso.verifyCredentials(req.body?.auth, req.site)
    debug("got signature: #{JSON.stringify(hash)}")
    if hash && hash.sha1 == sso.sha1(req.body?.data)
      debug("verification OK, continuing with import")
    else
      debug("verification FAILED, aborting import")
      res.send({status: "fail", message: "Not Authorized"})
      return

    post = JSON.parse(req.body.data)

    debug("importing conversation #{post.id} from #{req.site.name} - #{post.uri}")
    debug("post: #{JSON.stringify(post, null, 2)}")
    collections.conversations.enter(req.site, post.title, post.id, post.uri, {silent: true, imported: true}, (err, conv)->
      if err
        debug("import failed: #{JSON.stringify(err)}")
        logger.error(err)
        return res.send({status: "fail", message: "Invalid conversation"})
      async.forEachSeries(
        post?.comments || [],
        (c, cb)->
          debug("importing comment: #{JSON.stringify(c, null, 2)}")
          if c.parent_id == '0'
            c.parent_id = null
          if c.user_id == '0'
            c.user_id = null
          collections.comments.importComment(
            "wordpress", # imported from
            c.id, # import id
            c.parent_id, # import parent
            req.site, # site
            conv, # conversation
            {id: c.user_id, name: c.author, email: c.email}, # author info
            c.content, # comment text
            moment.utc(c.date_gmt, "YYYY-MM-DD HH:mm:ss").unix(), # comment timestamp
            c.approved != '0', # approved?
            {ip: req.ip, user_agent: req.headers['user-agent']}, # reqested from
            (err, cmt)->
              if err
                if err.code == 11000
                  err = null
                  debug("already in DB, skip: #{req.site.name} - #{conv.initialUrl} - #{c.id}")
                else
                  debug("error importing comment #{req.site.name} - #{conv.initialUrl} - #{c.id}")
              else
                debug("imported comment #{req.site.name} - #{conv.initialUrl} - #{c.id}")
              return cb(err)
          )
        ,
        (err)->
          debug("import finished with error: #{JSON.stringify(err)}")
          if err
            logger.error(err)
            status = {
              status: 'fail'
              message: err
            }
            return res.send(status)
          collections.sites.modify(req.site.name, {imported_comments: true}, (err, site)->
            status = {
              status: 'success'
            }
            res.send(status)
          )
      )
    )
  )

  app.post("/api/sites/:site/activities/:activity/comments", handlers.createUserWithContent, handlers.requireAuth, handlers.notBanned, (req, res, next)->
    req.body.parent = req.params["activity"]
    req.body.top = false
    addComment(req, res, next)
  )

  app.post("/api/sites/:site/activities/:activity/bets", handlers.requirePremium, handlers.createUserWithContent, handlers.requireAuth, handlers.notBanned, (req, res, next)->
    req.body.parent = req.params["activity"]
    req.body.top = false
    req.body.bet = true
    addComment(req, res, next)
  )

  app.post("/api/sites/:site/contexts/:context/bets", handlers.requirePremium, handlers.createUserWithContent, handlers.requireAuth, handlers.fetchContext, handlers.requireContextPermission, handlers.notBanned, (req, res, next)->
    req.body.parent = req.params["context"]
    req.body.bet = true
    req.body.top = true
    addComment(req, res, next)
  )

  app.post("/api/sites/:site/contexts/:context/challenges", handlers.createUserWithContent, handlers.requireAuth, handlers.fetchContext, handlers.requireContextPermission, handlers.notBanned, (req, res)->
    req.body.parent = req.params["context"]
    if !req.body.challenged
      res.send(403)
      return
    if !req.body.challenger?.text.replace(/\s/g, "")
      res.send(403)
      return
    collections.comments.addChallenge(req.site, req.user, req.profile, req.body, {ip: req.ip, user_agent: req.headers['user-agent']}, response.sendObj(res, collections.comments.toClient))
  )

  app.post("/api/sites/:site/activities/:activity/selfpromote", handlers.requireAuth, (req, res, next)->
    req.body.activity = req.params["activity"]
    selfpromotec(req, res, next)
  )

  app.put("/api/sites/:site/activities/:activity/approve", handlers.requireAuth, handlers.requireModerator, approve("activity"))
  app.put("/api/sites/:site/activities/:activity/clearflags", handlers.requireAuth, handlers.requireModerator, clearFlags("activity"))
  app.put("/api/sites/:site/activities/:activity/flag", handlers.requireAuth, handlers.notBanned, flag("activity"))
  app.put("/api/sites/:site/activities/:activity/likes", handlers.notBanned, like("activity"))
  app.put("/api/sites/:site/activities/:activity/delete", handlers.requireAuth, handlers.requireModerator, deletec("activity"))
  app.put("/api/sites/:site/activities/:activity/promote", handlers.requireAuth, handlers.requireModerator, promotec("activity"))
  app.put("/api/sites/:site/activities/:activity/demote", handlers.requireAuth, handlers.requireModerator, demotec("activity"))
  app.delete("/api/sites/:site/activities/:activity", handlers.requireAuth, handlers.requireModerator, destroy("activity"))
  app.put("/api/sites/:site/activities/:activity/votes", handlers.notBanned, vote("activity"))
  app.put("/api/sites/:site/activities/:activity/spam", handlers.requireAuth, handlers.requireModerator, spam("activity"))
  app.put("/api/sites/:site/activities/:activity/notspam", handlers.requireAuth, handlers.requireModerator, notspam("activity"))
  app.put("/api/sites/:site/activities/:activity/accept_bet", handlers.requirePremium, handlers.fetchActivity, handlers.requireActivity, handlers.fetchContext, handlers.requireContextPermission, handlers.requireAuth, accept_bet("activity"))
  app.put("/api/sites/:site/activities/:activity/decline_bet", handlers.requirePremium, handlers.fetchActivity, handlers.requireActivity, handlers.fetchContext, handlers.requireContextPermission, handlers.requireAuth, decline_bet("activity"))
  app.put("/api/sites/:site/activities/:activity/forfeit_bet", handlers.requirePremium, handlers.fetchActivity, handlers.requireActivity, handlers.fetchContext, handlers.requireContextPermission, handlers.requireAuth, forfeit_bet("activity"))
  app.put("/api/sites/:site/activities/:activity/claim_bet", handlers.requirePremium, handlers.fetchActivity, handlers.requireActivity, handlers.fetchContext, handlers.requireContextPermission, handlers.requireAuth, claim_bet("activity"))
  app.put("/api/sites/:site/activities/:activity/resolve_bet", handlers.requirePremium, handlers.fetchActivity, handlers.requireActivity, handlers.fetchContext, handlers.requireContextPermission, handlers.requireAuth, resolve_bet("activity"))
  app.put("/api/sites/:site/activities/:activity/end_bet", handlers.requirePremium, handlers.fetchActivity, handlers.requireActivity, handlers.fetchContext, handlers.requireContextPermission, handlers.requireAuth, end_bet("activity"))
  app.put("/api/sites/:site/activities/:activity/start_forf_bet", handlers.requirePremium, handlers.fetchActivity, handlers.requireActivity, handlers.fetchContext, handlers.requireContextPermission, handlers.requireAuth, start_forf_bet("activity"))

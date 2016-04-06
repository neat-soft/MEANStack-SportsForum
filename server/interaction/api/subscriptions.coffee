module.exports = (app)->

  collections = require("../../datastore").collections
  response = require("./response")
  sharedUtil = require("../../shared/util")
  util = require("../../util")
  handlers = require("../handlers")

  app.get("/api/sites/:site/modsubscription", handlers.requireRealModerator, (req, res)->
    collections.subscriptions.modSubscription(req.site, req.user, response.sendObj(res, collections.subscriptions.toClient))
  )

  app.post("/api/sites/:site/modsubscription", handlers.requireRealModerator, (req, res)->
    collections.subscriptions.addModSubscription(req.site, req.user, response.sendObj(res, collections.subscriptions.toClient))
  )

  app.delete("/api/sites/:site/modsubscription", handlers.requireRealModerator, (req, res)->
    collections.subscriptions.deleteModSubscription(req.site, req.user, response.sendObj(res, collections.subscriptions.toClient))
  )

  app.get("/api/sites/:site/subscriptions", (req, res)->
    context = req.query.context
    if req.user
      if context
        collections.subscriptions.forConversation(req.site, req.user.email, context, response.sendObj(res, collections.subscriptions.toClient))
      else
        collections.subscriptions.forSite(req.site, req.user.email, response.sendObj(res, collections.subscriptions.toClient))
    else
      res.send({active: false})
  )

  app.post("/api/sites/:site/subscriptions", (req, res)->
    active = util.jsparse(req.body.active)
    context = req.body.context
    if req.user
      if active
        if context
          collections.subscriptions.userSubscribeForContent(req.user, req.site, context, response.sendObj(res, collections.subscriptions.toClient))
        else
          collections.subscriptions.userSubscribeForConv(req.user, req.site, response.sendObj(res, collections.subscriptions.toClient))
      else
        if context
          collections.subscriptions.userUnsubscribeForContent(req.user, req.site, context, response.sendObj(res, collections.subscriptions.toClient))
        else
          collections.subscriptions.userUnsubscribeForConv(req.user, req.site, response.sendObj(res, collections.subscriptions.toClient))
    else
      email = req.body.email
      if sharedUtil.validateEmail(email)
        if context
          collections.subscriptions.emailSubscribeForContent(email, req.site, context, response.sendObj(res, collections.subscriptions.toClient))
        else
          collections.subscriptions.emailSubscribeForConv(email, req.site, response.sendObj(res, collections.subscriptions.toClient))
      else
        response.handleError({email_incorrect: true}, res)
  )

  app.get("/api/sites/:site/subscriptions/count", handlers.requireModerator, (req, res)->
    verified = req.query.verified == "1"
    active = req.query.active == "1"
    if verified
      if active
        collections.subscriptions.countVerifiedActive(req.site, response.sendObj(res))
      else
        collections.subscriptions.countVerified(req.site, response.sendObj(res))
    else
      collections.subscriptions.countAll(req.site, response.sendObj(res))
  )

  app.get("/api/sites/:site/subscriptions/export", handlers.requireModerator, (req, res)->
    format = req.query.format
    if format != "csv"
      return response.handleError({notsupported: true}, res)
    res.setHeader("Content-Type", "text/csv")
    res.setHeader("Content-Disposition", "attachment;filename=#{req.site.name}_subscribers.csv")
    collections.subscriptions.getVerified(req.site, response.sendFormatCursor(res, null, response.csv(["email"])))
  )

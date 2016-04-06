handlers = require("../handlers")
response = require("./response")

module.exports = (app)->

  app.param("site", (req, res, next, site)->
    if req.originalUrl.indexOf("/api") == 0
      if req.site && req.site.name != req.params.site
        return next({notsupported: true})
      req.siteName = site
      handlers.siteAndProfile(req, res, next)
    else
      next()
  )

  require("./conversations")(app)
  require("./allcomments")(app)
  require("./users")(app)
  require("./updates")(app)
  require("./subscriptions")(app)
  require("./analytics")(app)
  require("./competitions")(app)
  require("./social")(app)
  
  app.all("/api/*", (err, req, res, next)->
    response.handleError(err, res)
  )

  app.all("/api/*", (req, res)->
    res.send(404)
  )

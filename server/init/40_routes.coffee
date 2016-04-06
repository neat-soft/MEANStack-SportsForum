templates = require("../templates")
response = require("../interaction/api/response")
logger = require("../logging").logger

module.exports = (done)->

  require("../interaction/auth/auth")(@app)
  require("../interaction/embed")(@app)
  require("../interaction/marketing")(@app)
  require("../interaction/api")(@app)
  require("../interaction/resolver")(@app)
  require("../interaction/loaders")(@app)
  require("../interaction/zeus")(@app)
  require("../interaction/email")(@app)

  require("../templates").partials('./render/marketing', './render/')
  require("../templates").partials('./render/zeus', './render/')

  @app.all("*", (req, res)->
    templates.render(res.status(404), "marketing/404_not_found")
  )

  # hack for express 3
  # router was automatically added, remove it and add it again at the end
  for index, middleware of @app.stack
    if middleware.handle == @app.router
      routerAt = index
      break
  if routerAt
    @app.stack.splice(routerAt, 1)
    @app.use(@app.router)

  # error middleware
  @app.use((err, req, res, next)->
    if err.sitenotexists || err.notfound
      templates.render(res.status(404), "marketing/404_not_found")
    else if err.needs_moderator || err.needs_admin
      templates.render(res.status(403), "marketing/notallowed")
    else if err.timeout?
      res.statusCode = err.status
      templates.render(res, "marketing/error", {error: "The operation timed out.", user: req.user})
    else
      logger.error(err)
      templates.render(res.status(500), "marketing/error", {error: "There was an error while handling your request", user: req.user})
  )

  process.nextTick(done)

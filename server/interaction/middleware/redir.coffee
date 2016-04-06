debug = require("debug")("middleware:redir")
util = require("../../util")
config = require("naboo").config
helpers = require("../helpers")

module.exports = (req, res, next)->
  # the start page of the subdomain is the moderator page
  debug("CHECK REDIRECT")
  embed = req.query.embed == "true"
  if req.siteDomain
    debug("siteDomain")
    if req.path == "/"
      canonUrl = "/admin/moderator"
      debug("redirect to admin of site '#{req.siteName}': #{canonUrl}")
      return res.redirect(canonUrl)
    if /^\/admin/.test(req.path) && !req.profile?.permissions.moderator && !req.user?.zeus
      debug("GO TO LOGIN")
      return helpers.redirectToLogin(req, res)
    if !/^(\/api|\/auth|\/admin|\/signin)/.test(req.path)
      debug("GO TO CANON URL")
      if req.method == "GET"
        return res.redirect("#{config.serverHost}#{req.originalUrl}")
      else
        return next({notfound: true})
  else
    debug("no siteDomain")
  next()

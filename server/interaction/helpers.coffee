config = require("naboo").config

module.exports.full_url = (req)->
  return req.protocol + '://' + req.host + (if config.port == 80 || config.port == 443 then "" else ":#{config.port}") + req.originalUrl

module.exports.redirectToLogin = (req, res)->
  redirect_to = if new RegExp("/auth/signin").test(req.path) then "" else req.originalUrl
  return res.redirect("/auth/signin?redirect=#{encodeURIComponent(redirect_to)}")

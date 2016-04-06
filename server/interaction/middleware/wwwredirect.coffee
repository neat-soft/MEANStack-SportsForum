config = require("naboo").config

module.exports = (req, res, next)->
  if process.env.NODE_ENV == "production" && req.headers.host == "burnzone.herokuapp.com"
    res.redirect(config.serverHost + req.url)
  else
    next()
    
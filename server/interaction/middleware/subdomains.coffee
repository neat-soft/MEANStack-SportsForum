config = require("naboo").config
handlers = require("../handlers")
collections = require("../../datastore").collections
debug = require("debug")("middleware:subdomains")

# TODO: use req.subdomains with app level property 'subdomain offset' 
module.exports = (req, res, next)->
  if req.get("Host")
    host = req.host
    subdomains = req.subdomains
  else # workaround express bug
    host = ""
    subdomains = []
  debug("request for host=#{host} url=#{req.originalUrl} subdomains=[#{subdomains}]")
  if host.slice(-config.domain.length) == config.domain
    prefix = host.slice(0, -config.domain.length - 1)
    if !prefix
      debug("no prefix")
      return next()
    if !config.useSubdomains
      debug("useSubdomains = false")
      return res.redirect("#{config.serverHost}#{req.originalUrl}")
    if config.special[prefix]
      debug("reserved subdomain")
      return next()
    if prefix.indexOf(".") >= 0
      debug("too many subdomains")
      return next({sitenotexists: true})
    req.siteDomain = true
    req.siteName = prefix.toLowerCase()
    debug("site from subdomain: #{req.siteName}")
  else
    debug("no subdomain")
  next()

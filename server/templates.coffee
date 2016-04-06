fs = require('fs')
handlebars = require('handlebars')
util = require('./util')
require('./shared/templates')
config = require("naboo").config
path = require("path")

# helper from http://stackoverflow.com/questions/8059914/express-js-hbs-module-register-partials-from-hbs-file

module.exports.partials = (partialsDir, nameFrom)->

  filenames = fs.readdirSync(partialsDir)

  filenames.forEach((filename)->
    matches = /^([^.]+).hbs$/.exec(filename)
    if (!matches)
      return
    name = matches[1]
    template = fs.readFileSync(partialsDir + '/' + filename, 'utf8')
    handlebars.registerPartial(_.str.strRight(partialsDir, nameFrom) + '/' + name, template)
  )

handlebars.registerHelper("link", (to, options)->
  query = []
  for name, value of options.hash
    if value?
      query.push("#{name}=#{encodeURIComponent(value.toString())}")
  if query.length > 0
    return to + "?" + query.join("&")
  else
    return to
)

handlebars.registerHelper("query", (qmark)->
  options = _.toArray(arguments)
  if _.isString(qmark)
    qmark = true
  else
    options = options.slice(1)
  query = []
  for name in options
    value = this[name]
    if value?
      query.push("#{name}=#{encodeURIComponent(value.toString())}")
  if query.length > 0
    return (if qmark then "?" else "") + query.join("&")
  else
    return ""
)

handlebars.registerHelper("post", (field, type, refValue)->
  value = @req.body[field]
  if value
    if type == "text" || type == "hidden" || type == "password"
      return "value=#{value}"
    else if type == "checkbox" || type == "radio"
      if value == refValue
        return "checked=\"true\""
      return ""
    else if type == "option"
      if value == refValue
        return "selected"
      return ""
  else
    return ""
)

handlebars.registerHelper("adminSectionUrl", (url, opts)->
  req = @req || opts.hash.req
  if !opts.hash.name
    name = req.site?.name
  else
    name = opts.hash.name
  if config.useSubdomains
    return "#{req.protocol}://#{name}.#{config.domainAndPort}#{url}"
  else
    return "#{url}?site=#{name}"
)

handlebars.registerHelper("ifnotconf", (name, options)->
  if name == "settings"
    if @req.query.frame
      if @req.site.imported_comments
        return options.inverse(this)
      else
        return options.fn(this)
    else
      return options.inverse(this)
  else if name == "appearance"
    if @req.site.avatars?.length > 0
      return options.inverse(this)
    else
      return options.fn(this)
  else if name == "forum"
    if @req.site.forum?.enabled && @req.site.forum?.url
      return options.inverse(this)
    else
      return options.fn(this)
  else if name == "sso"
    if @req.site.sso?.enabled
      return options.inverse(this)
    else
      return options.fn(this)
  else if name == "badges"
    if @req.site.badges?.length > 0
      return options.inverse(this)
    else
      return options.fn(this)
  return "**invalid**"
)

handlebars.registerHelper("global", (context)->
  return util.objNavigate(global, context)
)

renderMessageList = (type, list)->
  map = {
    warn: 'warning'
    error: 'danger'
    info: 'info'
    success: 'success'
  }
  return ([
    "<div class='alert alert-#{map[type]}'>",
    '<button type="button" class="close" data-dismiss="alert">&times;</button>',
    "#{handlebars.Utils.escapeExpression(message)}",
    '</div>'
  ].join("\n") for message in list).join("")

handlebars.registerHelper("messages_boots", (type)->
  _.extend(@messages || (@messages = {}), @req.flash(if arguments.length > 1 then type else null))
  if _.size(@messages) == 0
    return ""
  if type && @messages[type]
    return new handlebars.SafeString(renderMessageList(type, @messages[type]))
  known_types = ["error", "info", "warn", "success"]
  return new handlebars.SafeString((renderMessageList(type, @messages[type]) for type in known_types when @messages[type]).join(""))
)

module.exports.render = (res, name, options)->
  handlebars.partials["app_init"] = null
  req = res.locals.req = res.req
  res.locals.template = name
  res.locals.user_id = req.user?._id.toHexString() || ""
  res.locals.config = config
  res.locals.user = req.user
  res.locals.loginUrl = config.loginRoot
  res.locals.baseUrl = config.serverHost
  res.locals.baseUrlNotifications = config.serverHost
  res.locals.baseUrlResources = config.resourcePath
  res.render(name, options)

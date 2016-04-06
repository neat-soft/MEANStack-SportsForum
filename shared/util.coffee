murmur = require("./murmur")

module.exports.formatString = (str, params)->
  if not params?
    return str
  for own key, val of params
    if _.isString(val) || _.isNumber(val)
      regex = new RegExp("{#{key}}", "g")
      str = str.replace(regex, val)
  return str

module.exports.hashString = (s)->
  return murmur(s || "no-such-email-address@mailinator.com", 0)

module.exports.validateEmail = (email)->
  if !email
    return false
  return /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$/.test(email)

module.exports.validateTag = (tag)->
  if !tag
    return false
  return removeWhite(tag) && !/[.:#]/g.test(tag)

module.exports.removeWhite = removeWhite = (text)->
  return text?.replace(/\s/g, "") || ""

module.exports.resource = (name)->
  if typeof window != 'undefined'
    resPath = window.conversaitData.baseUrlResources || "/web"
    application = window.app
    statics = window.conversaitData.statics
  else
    resPath = require("naboo").config.resourcePath || "/web"
    application = require("naboo").config.app
    statics = application.statics || {}
  return resPath + name + "?v=" + (statics[name] || "")

module.exports.cmp = (a, b)->
  if a < b
    return -1
  else if a > b
    return 1
  return 0

module.exports.isNonNegativeInt = (value)->
  return value.match(/^[0-9]+$/)

util = require("lib/shared/util")

Handlebars.registerHelper('translate', (item, obj)->
  object = obj?.hash
  return new Handlebars.SafeString(module.exports.translate(item, object))
)

rivets.formatters.translate = (value)->
  return translate(value)

module.exports.load = (lang)->
  loadTerms(lang.terms)
  moment.locale(lang.code)

module.exports.loadTerms = loadTerms = (newTerms)->
  module.exports.terms = newTerms
  buildLocalizationHelpers()

module.exports.translate = translate = (term, options)->
  tr = module.exports.terms[term]
  if not tr?
    tr = "*#{term}"
  return util.formatString(tr, options)

module.exports.buildLocalizationHelpers = buildLocalizationHelpers = ->
  for own name, func of rivets.formatters
    if name.indexOf("t_") == 0
      rivets.formatters[name] = null
  for own term, value of module.exports.terms
    do (term) ->
      rivets.formatters["t_" + term] = (value)->
        return translate(term, {value: value})

module.exports.hasTerm = (term)->
  return !!module.exports.terms[term]

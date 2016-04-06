if typeof window != 'undefined'
  Handlebars = window.Handlebars
else
  Handlebars = require("handlebars")
util = require("./util")

Handlebars.registerHelper("resource", (name)->
  return util.resource(name)
)

# http://thejohnfreeman.com/blog/2012/03/23/template-inheritance-for-handlebars.html

Handlebars.loadPartial = (name)->
  partial = Handlebars.partials[name]
  if (typeof partial == "string")
    partial = Handlebars.compile(partial)
    Handlebars.partials[name] = partial
  return partial

Handlebars.registerHelper("block", (name, options)->
  #/* Look for partial by name. */
  partial = Handlebars.loadPartial(name) || options.fn
  return partial(this, { data : options.hash })
)

Handlebars.registerHelper("partial", (name, options)->
  Handlebars.registerPartial(name, options.fn)
)

Handlebars.registerHelper('ifnot', (conditional, options)->
  if !conditional
    return options.fn(this)
  else
    return options.inverse(this)
)

Handlebars.registerHelper('ifeq', (v1, v2, options)->
  if v1 == v2
    return options.fn(this)
  else
    return options.inverse(this)
)

Handlebars.registerHelper('ifneq', (v1, v2, options)->
  if v1 == v2
    return options.inverse(this)
  else
    return options.fn(this)
)

Handlebars.registerHelper('ifin', ->
  args = _.toArray(arguments)
  array = args.slice(0, arguments.length - 1)
  obj = array.shift()
  options = args[args.length - 1]
  if obj in array
    return options.fn(this)
  else
    return options.inverse(this)
)

Handlebars.registerHelper('each', (context, options)->
  fn = options.fn
  inverse = options.inverse
  ret = []
  if _.isArray(context)
    if(context.length > 0)
      for elem in context
        ret.push(fn(elem))
  else if _.isObject(context)
    for own key, elem of context
      ret.push(fn({key: key, elem: elem}))
  return ret.join('')
)

Handlebars.registerHelper('each_with_id', (context, options)->
  fn = options.fn
  inverse = options.inverse
  ret = ""
  id = 0
  if _.isArray(context)
    if(context.length > 0)
      for elem in context
        ret = ret + fn({id: id, elem: elem})
        id = id + 1
  else if _.isObject(context)
    for own key, elem of context
      ret = ret + fn({id: id, key: key, elem: elem})
      id = id + 1
  return ret
)

Handlebars.registerHelper('ifand', ->
  args = _.toArray(arguments)
  options = args.pop()
  if _.all(args, _.identity)
    return options.fn(this)
  else
    return options.inverse(this)
)

Handlebars.registerHelper('ifor', ->
  args = _.toArray(arguments)
  options = args.pop()
  if _.any(args, _.identity)
    return options.fn(this)
  else
    return options.inverse(this)
)

Handlebars.registerHelper('string', (context)->
  return Handlebars.Utils.escapeExpression(context)
)

Handlebars.registerHelper("selected", (value, inArray)->
  if !inArray?
    return ""
  if !_.isArray(inArray)
    inArray = [inArray]
  if value in inArray
    return 'selected="true"'
  return ""
)

Handlebars.registerHelper("checked", (value)->
  return if value then "checked=\"checked\"" else ""
)

Handlebars.registerHelper("disabled", (value)->
  return if value then "disabled=\"disabled\"" else ""
)

Handlebars.registerHelper("enabled", (value)->
  return if value then "" else "disabled=\"disabled\""
)

Handlebars.registerHelper("json", (value)->
  return JSON.stringify(value, null, 2)
)

Handlebars.registerHelper("capitalize", (value)->
  return _.str.capitalize(value)
)

Handlebars.registerHelper("ifprop", (obj, prop, options)->
  if obj?[prop]
    return options.fn(this)
  else
    return options.inverse(this)
)

Handlebars.registerHelper("each_in_array", ->
  args = _.toArray(arguments)
  array = args.slice(0, arguments.length - 1)
  options = args[args.length - 1]
  result = []
  for elem in array
    result.push(options.fn(elem))
  return result.join('')
)

defaultType = "INFO"

module.exports = class Logger

  constructor: (configuration)->
    @appenders = configuration?.appenders || {}
    @attrs = configuration.attrs || null

  append: (item, appenders)->
    for appender in appenders
      appender.write(item)

  log: (type, item)->
    if !item
      item = type
    if !item
      return
    if item instanceof Error
      item = @prepareError(item)
    if !_.isObject(item)
      item = {_raw: item}
    if !item._time
      item._time = new Date()
    if !item._type
      item._type = type || defaultType
    @attrs && _.extend(item, @attrs)
    if @appenders[item._type]?.length > 0
      @append(item, @appenders[item._type])
    else if @appenders["*"]
      @append(item, @appenders["*"])

  prepareError: (item)->
    return {error: {message: item.message, stack: item.stack, type: item.constructor.name}}

  error: (item)->
    item = @prepareError(item)
    @log('error', item)

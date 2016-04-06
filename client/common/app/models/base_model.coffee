module.exports = class Model extends Backbone.Model

  _disposed: false

  constructor: (attributes, options)->
    if options
      options = _.omit(options, 'url')
    super(attributes, options)

  initialize: ->
    super
    @on("destroy", ->
      @_destroyed = true
      # make sure the handler runs at the end
      setTimeout(=>
        if !@_disposed
          @dispose()
      1)
    , this)

  dispose: ->
    if @_disposed
      return
    @trigger("dispose", this)
    if !@_destroyed
      @trigger("destroy", this)
    @off()
    @stopListening()
    for prop in ['collection', 'attributes', 'changed',
                  '_escapedAttributes', '_previousAttributes',
                  '_silent', '_pending', '_callbacks', 'options']
      @[prop] = null
    @_disposed = true

  inc: (key, value = 1)->
    @set(key, (@get(key) || 0) + value)

  parse: (attributes, options)->
    if !attributes
      return attributes
    if attributes == @attributes
      return null
    if options?.map
      for own key, val of options.map
        attributes[val] = attributes[key]
    if attributes._v?
      if @attributes._v? && @attributes._v >= attributes._v
        return null
    if attributes.$inc
      for own attr, value of attributes.$inc
        attributes.$inc[attr] = (@attributes[attr] || 0) + value
      _.extend(attributes, attributes.$inc)
      delete attributes.$inc
    return super(attributes, options)

  fetch: (options = {})->
    options.one ?= true
    if options.first && @sync_status
      return
    if options.one && @sync_status == 'fetching'
      return
    @sync_status = 'fetching'
    success = options.success
    error = options.error
    options.success = =>
      @sync_status = 'synced'
      success?.apply(null, _.toArray(arguments))
    options.error = =>
      @sync_status = 'error'
      error?.apply(null, _.toArray(arguments))
    super(options)

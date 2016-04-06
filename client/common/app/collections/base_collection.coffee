module.exports = class BaseCollection extends Backbone.Collection

  getId: (model)->
    id = ""
    if model instanceof @model
      id = model.id
    else
      id = model[@model.prototype.idAttribute]
    return id

  update: (models, options)->
    options ?= {}
    toAdd = []
    byId = {}
    for model in models || []
      id = @getId(model)
      byId[id] = true
      existing = @get(id)
      if not existing
        toAdd.push(model)
      else if options.update
        existing.set(model)
    for model in _.toArray(@models)
      if not byId[model.id]
        @remove(model, options)
    if toAdd.length > 0
      @add(toAdd, options)

  destroyAll: (options)->
    options = if options then _.clone(options) else {}
    success = options.success
    options.success = (resp, status, xhr)=>
      @reset()
      success && success(collection, resp)
    options.error = Backbone.wrapError(options.error, this, options)
    return (this.sync || Backbone.sync).call(this, 'delete', this, options)

  fetchModel: (type, attrs, options)->
    fakeModel = new Backbone.Model(attrs, {urlRoot: type.prototype.urlRoot})
    success = options.success
    error = options.error
    options.success = (resp)->
      fakeModel.dispose()
      success && success(resp)
    options.error = (model, resp, options)->
      fakeModel.dispose()
      error && error(model, resp, options)
    @fetch(_.extend({}, options, {parse: false, remove: false, url: type.prototype.url.call(fakeModel)}))

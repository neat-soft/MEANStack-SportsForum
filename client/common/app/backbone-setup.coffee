BaseCollection = require("collections/base_collection")
BaseModel = require("models/base_model")

Backbone.Collection = BaseCollection
Backbone.Model = BaseModel
Backbone.Model.prototype.idAttribute = "_id"

# We don't want to cache async requests.
sync = Backbone.sync
Backbone.sync = (method, model, options)->
  options ?= {}
  if !options.cache
    options.cache = false
  sync.call(this, method, model, options)

require("lib/backbone-graph")

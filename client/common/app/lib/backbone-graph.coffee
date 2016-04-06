# Lightweight Backbone library for model relations
# Supports One-to-One, One-to-Many and Many-to-Many relations

if Backbone.Graph
  return

getValue = (key, context)->
  if !key
    return null
  if _.isFunction(key)
    return key.call(context)
  return key

modelOptions = (options)->
  return options && _.omit(options, "add", "remove", "url", "urlRoot", "collection")

addOptions = (options)->
  return options && _.extend(_.omit(options, "url", "urlRoot", "collection"), {remove: false, parse: false})

Backbone.Graph = class Graph

  constructor: ->
    @collections = []
    @models = new ModelCollection()
    @models.model = GraphModel
    @models.on("add", (model, col, options)=>
      @getCollection(model.constructor, true).add(model, options)
    , this)

  getCollection: (type, create)->
    if (type == GraphModel or type.prototype instanceof GraphModel)
      col = _.chain(@collections).filter((c)->
        return c.model == type
      ).first().value()
      if !col and create
        col = new ClassCollection()
        col.model = type
        @collections.push(col)
        col.on("remove", (model)=>
          @removeModel(model)
        , this)
      return col
    return null

  addModel: (model, options = {})->
    model._store = this
    @models.add(model, _.extend({}, addOptions(options)))

  removeModel: (model)->
    @models.remove(model)

Backbone.GraphModel = class GraphModel extends Backbone.Model

  _getRelationType: (relation)->
    if !relation.type
      return null
    if relation.type.ctor
      return relation.type.ctor
    if relation.type.provider
      return relation.type.provider.call(this)
    return null

  _onModelEvent: (attr, parent)->
    return (event, model)->
      if (event == 'destroy' || event == 'dispose') && parent.attributes?[attr] == model
        delete parent.attributes?[attr]
      else if event.indexOf("change:") == 0
        attrs = event.substring(7)
        pevent = "change:" + attr + "." + attrs
        if parent.lastEvent?.model == model && new RegExp("^[^.]+\\.#{parent.lastEvent.attrs.replace('.', '\\.')}$").test(attrs)
          return
        args = [pevent, parent].concat(_.toArray(arguments).slice(2))
        parent.lastEvent =
          model: model
          event: event
          attrs: attr + '.' + attrs
        parent.trigger.apply(parent, args)
        parent.lastEvent = null

  _changeRel: (model, attr, value, options)->
    rel = @_findRelation(model, attr)
    prevReverseKey = getValue(rel.reverseKey, new Backbone.Model(model.previousAttributes()))
    prevModel = model.previous(attr)
    currentReverseKey = getValue(rel.reverseKey, model)

    # Cleanup the old relation
    if prevModel instanceof GraphModel and prevReverseKey
      # if prevModel._relChanging or prevModel._changing
      #   return
      if prevModel.get(prevReverseKey) instanceof Backbone.Collection
        prevModel.get(prevReverseKey).remove(model, options)
      else
        prevModel.set(prevReverseKey, null, options)
      prevModel.off("all", null, this)

    # Handle the new relation
    relModel = value
    if !relModel
      return
    if (relModel instanceof GraphModel)
      # if (relModel._relChanging or relModel._changing)
      #   return
    else
      only_id = false
      if _.isString(relModel)
        only_id = true
        id = relModel
        relModel = {}
        relModel[Backbone.Model.prototype.idAttribute] = id
      else
        id = relModel?[Backbone.Model.prototype.idAttribute]
      modelInStore = Backbone.graphStore.models.get(id)
      if modelInStore
        if options.merge && !only_id
          modelInStore.set(relModel, options)
        relModel = modelInStore
      else
        if rel.autoCreate
          relType = @_getRelationType(rel)
          if !relType
            return
          attrs = relModel
          relModel = new relType(attrs, _.extend(modelOptions(options), {relation: {model: @id, modelCid: @cid, key: attr, reverse: currentReverseKey}}))
        else
          return
    @attributes[attr] = relModel
    if currentReverseKey
      if relModel.get(currentReverseKey) instanceof Backbone.Collection
        relModel.get(currentReverseKey).add(model, addOptions(options))
      else
        relModel.set(currentReverseKey, model, modelOptions(options))
    if rel.events
      relModel.on("all", @_onModelEvent(attr, this), this)

  _addToColRel: (relModel, col, options)->
    rel = @_findRelation(relModel, getValue(col.reverseKey, this))
    if rel
      if relModel.get(rel.key) instanceof Backbone.Collection
        relModel.get(rel.key).add(this, addOptions(options))
      else
        relModel.set(rel.key, this, modelOptions(options))

  _removeFromColRel: (relModel, col, options)->
    rel = @_findRelation(relModel, getValue(col.reverseKey, this))
    if rel
      if relModel.get(rel.key) instanceof Backbone.Collection
        relModel.get(rel.key).remove(this, options)
      else
        relModel.set(rel.key, null, modelOptions(options))

  _findRelation: (model, key)->
    if _.isArray(model.relations)
      return _(model.relations || []).find((r)-> r.key == key)
    else
      return model.relations[key]

  _setupCollectionAttributes: ->
    _.each(@relations || [], (rel)=>
      relType = @_getRelationType(rel)
      if (relType?.prototype instanceof Backbone.Collection)
        if !(@attributes[rel.key] instanceof Backbone.Collection)
          attrs = @attributes[rel.key]
          if !(attrs and _.size(attrs) > 0)
            attrs = null
          col = new relType(attrs)
          col.key = rel.key
          col.reverseKey = rel.reverseKey
          col.container = this
          col.on("rel_add add", @_addToColRel, this)
          col.on("rel_remove remove", @_removeFromColRel, this)
          @attributes[rel.key] = col
      else
        do (rel)=>
          @on("rel_change:#{rel.key} change:#{rel.key}", (model, value, opts)=>
            @_changeRel(model, rel.key, value, opts)
          , this)
    )
    @_relAttrsSetup = true

  constructor: (attributes, options = {})->
    if !@relations
      @relations = []
    super(attributes, options)

  initialize: (attributes, options)->
    super
    if !@_relAttrsSetup
      @_setupCollectionAttributes()
    @trigger('initialize', this)

  toJSON: (options)->
    json = {}
    for own attr of @attributes
      rel = @_findRelation(this, attr)
      if rel
        if rel.serialize
          if @_getRelationType(rel).prototype instanceof Backbone.Collection
            json[attr] = @attributes[attr].toJSON(options)
          else if @attributes[attr]?.id
            json[attr] = @attributes[attr]?.id
      else
        json[attr] = @attributes[attr]
    return json

  prepareSetParams: (key, value, options)->
    if _.isObject(key) || key == null
      attrs = key
      options = value
    else
      attrs = {}
      attrs[key] = value
    return [attrs, options]

  set: (key, value, options)->
    if !@_relAttrsSetup
      @_setupCollectionAttributes()
    [attrs, options] = @prepareSetParams(key, value, options)
    options ?= {}
    if !@_store
      # the model has just been created
      # the attributes have already been parsed in the constructor, so there's
      # no need to parse here, parsing is done in the else block
      if attrs[@idAttribute]?
        @id = attrs[@idAttribute]
      Backbone.graphStore.addModel(this, options)
    else
      if options.parse
        attrs = @parse(attrs, options)
    if !attrs
      return this
    if attrs == @attributes
      return this
    for rel in @relations
      if rel.key of attrs
        # Collection relations can't be changed. But we're resetting the collection with the values provided
        if @_getRelationType(rel)?.prototype instanceof Backbone.Collection
          @attributes[rel.key].reset(attrs[rel.key], _.extend(modelOptions(options), {silent: options.silent? && options.silent || false}))
          delete attrs[rel.key]
        else
          # If it's about the same model then omit it from set and merge if needed
          current = @attributes[rel.key]
          toSet = attrs[rel.key]
          if current && toSet
            # Checking if the objects are the same so that we don't trigger the change event for this attribute
            # - if the current value does not have an id and ignoreId is set then the models are considered the same
            # - if they have the same id then they are the same
            if (!toSet.id && rel.ignoreId) || (current.id && current.id == (toSet?[@idAttribute] || toSet))
              attrs[rel.key] = current
              if options.merge && _.isObject(toSet)
                current.set(toSet, modelOptions(options))
    return super(attrs, options)

  dispose: ->
    _.each(@relations || [], (rel)=>
      model = @attributes[rel.key]
      if !model
        return
      if rel.autoDelete
        if model instanceof Backbone.Model
          model.dispose?()
        else if model instanceof Backbone.Collection
          for item in model.models.slice()
            item.dispose?()
      if model instanceof Backbone.Collection
        model.container = null
      model.off(null, null, this)
      model.off(null, null, @_store)
    )
    super

Backbone.GraphCollection = class GraphCollection extends Backbone.Collection

  reset: (models, options)->
    if options?.silent
      return super
    # @container?._relChanging = true
    for modelIn in _.clone(@models)
      @trigger("rel_remove", modelIn, this, options)
    result = super
    # @container?._relChanging = false
    return result

  _prepareModel: (attrs, options)->
    if (attrs instanceof GraphModel)
      return super
    if (id = attrs[Backbone.Model.prototype.idAttribute]) && (model = Backbone.graphStore.models.get(id))
      if options.merge
        model.set(attrs, options)
      return model
    return super

  toJSON: (options)=>
    if options?.flat
      return _.map(@models, (m)-> m.toJSON(options))
    return _.pluck(@models, 'id')

# We don't want models to be bound to the store collection or the class specific collections so
# we override their _prepareModel.
class ModelCollection extends GraphCollection
  _prepareModel: (attrs, options)->
    model = super
    if model?.collection == this
      model.collection = null
    return model

class ClassCollection extends GraphCollection
  _prepareModel: (attrs, options)->
    model = super
    if model?.collection == this
      model.collection = null
    return model

Backbone.graphStore = new Graph()

BaseCollection = require("collections/base_collection")
View = require('views/base_view')

# Options:
# copy: copy the model values to an internal collection. Default: true
# filter: function(c)
#        - only render the values that pass the filter
#        - only works with "copy" or with an array of models instead of @collection
#        - Default: undefined
# top: only show the top 'top' elements. If top == 0 then show all elements. Default: 0
# elementView: the view to render for each element
# elementViewOptions: an options object to pass to each elementView
# reconsiderOn: an avent name, reconsider this element for rendering (pass it through filter)
#   when this event is fired
#        - only works with "copy" and "filter"
# emptyView: a view (prototype) that will be rendered when there are no elements in the collection to show
# emptyText: a simple text that will be rendered when there are no elements in the collection to show
module.exports = class CollectionView extends View

  constructor: ->
    @_viewsByModel = {}
    @_viewsByModelCid = {}
    @_elementViewOptions = {}
    super

  initialize: ->
    super

    @options.copy ?= true
    @options.top ?= 0

    if @options.copy
      @internalCollection = new BaseCollection([], {comparator: @options.comparator})
      @bindTo(@internalCollection, "add", @onAdd)
      @bindTo(@internalCollection, "reset", @render)
      @bindTo(@internalCollection, "sort", (col, options)=>
        if options?.add || options?.remove
          return
        @render()
      )
      @bindTo(@internalCollection, "remove", @onRemove)

    @_elementView = @options.elementView ? View
    @_elementViewOptions = @options.elementViewOptions ? @_elementViewOptions
    @_childrenAttribute = @options.childrenAttribute ? "children"

    addToInternal = (model, col, options)=>
      if @options.filter && !@options.filter.call(null, model)
        return
      optionsToAdd = {parse: false, remove: false}
      @internalCollection.add(model, _.extend({}, options, optionsToAdd))

    if @collection
      if @options.copy
        @bindTo(@collection, "add", addToInternal)
        @bindTo(@collection, "reset", =>
          if @options.filter
            models = _.filter(@collection.models, @options.filter)
          else
            models = @collection.models
          @internalCollection.reset(models)
        )
        @bindTo(@collection, "remove", (model)=>
          @internalCollection.remove(model)
        )
        if @options.reconsiderOn && @options.filter
          @bindTo(@collection, @options.reconsiderOn, (model, col, options)=>
            if @internalCollection.get(model.id)
              if @options.filter && !@options.filter.call(null, model)
                @internalCollection.remove(model)
            else
              addToInternal(model, col, options)
          )
      else
        @bindTo(@collection, "add", @onAdd)
        @bindTo(@collection, "reset", @render)
        @bindTo(@collection, "remove", @onRemove)
    else if @model && @_childrenAttribute
      if @options.copy
        @bindTo(@model, "change:" + @_childrenAttribute, =>
          if @options.filter
            @internalCollection.update(_.filter(@model.get(@_childrenAttribute), @options.filter))
          else
            @internalCollection.update(@model.get(@_childrenAttribute))
        )
      else
        @bindTo(@model, "change:" + @_childrenAttribute, @render)
    if @options.copy
      @refreshInternalCollection()

  refreshInternalCollection: ->
    if @collection
      if @options.filter
        @internalCollection.reset(_.filter(@collection.models, @options.filter), {silent: true})
      else
        @internalCollection.reset(@collection.models, {silent: true})
    else if @model && @_childrenAttribute
      if @options.filter
        @internalCollection.reset(_.filter(@model.get(@_childrenAttribute), @options.filter), {silent: true})
      else
        @internalCollection.reset(@model.get(@_childrenAttribute), {silent: true})

  children: ->
    if @internalCollection
      return @internalCollection.models
    if @collection
      return @collection.models
    if @model && @_childrenAttribute
      return @model.get(@_childrenAttribute)
    return []

  viewByModel: (modelOrId)->
    id = modelOrId?.id || modelOrId
    return @_viewsByModel[id]

  viewByModelCid: (modelOrCid)->
    cid = modelOrCid.cid || modelOrCid
    return @_viewsByModelCid[cid]

  removeChild: (model)->
    childView = (@viewByModel(model.id) || @viewByModelCid(model.cid))
    childView?.remove()
    delete @_viewsByModel[model.id]
    delete @_viewsByModelCid[model.cid]
    @trigger("remove_child", this)

  onRemove: (model, col, options = {})->
    if !@_rendered
      return
    if !options.index
      options.index = col.indexOf(model)
    @removeChild(model)
    if @options.top > 0 && options.index >= 0 && options.index < @options.top - 1 && _.size(@_viewsByModelCid) < @options.top
      newModel = col.models[@options.top - 1]
      if newModel
        @renderChild(newModel, col.models[@options.top - 2])
    if !options.forsort
      @tryRenderEmpty()

  onAdd: (model, col, options = {})->
    if !@_rendered
      return
    if !(options.at?)
      options.at = col.indexOf(model)
    if @options.top > 0 && options.at >= @options.top
      return
    @renderChild(model, col.models[options.at - 1])
    if @options.top > 0 && options.at >= 0 && options.at < @options.top && _.size(@_viewsByModelCid) > @options.top
      toRemove = col.models[@options.top]
      if toRemove
        @removeChild(toRemove)
    if !options.forsort
      @tryRenderEmpty()

  onModelChange: (model)->
    if @options.filter && !@options.filter.call(null, model)
      @internalCollection?.remove(model)
      return
    if @options.copy
      if @internalCollection.comparator
        @internalCollection.remove(model, {forsort: true})
        options = {forsort: true}
        @internalCollection.add(model, options)
    else if @collection.comparator
      @render()
    @tryRenderEmpty()

  # This works only with @collection or the "copy" option.
  # Keep in mind that when using without "copy", the comparator is set on @collection and @collection.sort() is called
  # If you want to use sort with an array of models pass {copy: true} as an option when creating the view.
  sort: (comparator, options)->
    options ?= {}
    collection = @internalCollection || @collection
    collection.comparator = comparator
    if @internalCollection
      if @updateOn
        @unbindFrom(@collection, @updateOn, @onModelChange)
      if options.updateOn
        @updateOn = options.updateOn
        @bindTo(@collection, @updateOn, @onModelChange)
    collection.sort()

  render: (forceDataRefresh = false)->
    super
    if forceDataRefresh && @options.copy
      @refreshInternalCollection()
    @renderChildren()
    return @

  renderChildren: ->
    if !@_rendered && !@_rendering
      return
    @_viewsByModel = {}
    @_viewsByModelCid = {}
    children = @children()
    if !@internalCollection && @options.filter
      children = _.filter(children, @options.filter)
    for own index, elem of children
      if @options.top > 0 && index >= @options.top
        break
      @renderChild(elem, children[index - 1])
    @tryRenderEmpty()

  addChildViewToDOM: (child, after_el)->
    # pass
    if after_el
      after_el.after(child)
    else
      @$el.prepend(child)

  renderChild: (child, after)->
    if !(@viewByModel(child.id)? || @viewByModelCid(child.cid)?)
      options = _.extend({}, @_elementViewOptions, {model: child})
      childView = @addView(new @_elementView(options))
      if after
        afterView = (@viewByModel(after.id) || @viewByModelCid(after.cid))
        @addChildViewToDOM(childView.el, afterView.$el)
      else
        @addChildViewToDOM(childView.el, null)
      if child.id?
        @_viewsByModel[child.id] = childView
      @_viewsByModelCid[child.cid] = childView
      @trigger("render_child", childView, afterView)
      setTimeout(=>
        if !@_disposed && !childView._disposed && !childView._rendered && !childView._rendering
          childView.render()
      , 10)

  addEmptyViewToDom: (el)->
    @$el.append(el)

  tryRenderEmpty: ->
    if _.size(@_viewsByModelCid) == 0
      if !@view('empty')
        if @options.emptyView
          emptyView = new @options.emptyView()
        else if @options.emptyText
          emptyView = new View(template: @options.emptyText, templateIsModule: false, className: 'empty_view')
        else
          return
        @addEmptyViewToDom(@addView('empty', emptyView).render().el)
    else
      @view('empty')?.remove()

  scrollToModel: (id)->
    @viewByModel(id)?.$el.scrollIntoView(true)

  dispose: ->
    if @_disposed
      return
    if @internalCollection
      @unbindFrom(@internalCollection)
      @internalCollection.reset()
      delete @internalCollection
    super

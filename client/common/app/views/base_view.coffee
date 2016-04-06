# Base view. Inspired from Chaplin

module.exports = class View extends Backbone.View

  _disposed: false
  _autoRemove: true
  _rendered: false
  _rendering: false
  _willRender: false
  _templateIsModule: true
  _templatePath: 'views/templates/'
  _renderWrapped: false

  constructor: ->
    @_views = {}
    @_viewsByCid = {}
    super

  initialize: ->
    @$el.attr('data-view-cid', @cid)
    # to access the app object from templates
    @app = @options.app || window.app

    @_autoRemove = @options.autoRemove ? @_autoRemove
    @_templateIsModule = @options.templateIsModule ? @templateIsModule ? @_templateIsModule
    @template = @options.template ? @template

    if @_templateIsModule && typeof(@template) == 'string'
      @template = require(@_templatePath + @template)
    if @_autoRemove && @model
      @bindTo(@model, "destroy", @remove)
    @wrapRender()

  willRender: ->
    args = _.toArray(arguments)
    if !@_willRender
      @_willRender = true
      setTimeout(=>
        @_willRender = false
        @render.apply(this, args)
      , 1)

  wrapRender: ->
    doRender = (wrapped)=>
      return =>
        if @_disposed
          return @
        @_rendering = true
        if @_rendered
          @cleanup(false)
        @beforeRender?()
        @renderTemplate()
        wrapped?.apply(this, _.toArray(arguments))
        @app.trigger("render", this)
        @_rendered = true
        @_rendering = false
        @trigger("render", this)
        return @
    @render = doRender(@render)
    @_renderWrapped = true

  render: ->
    return @

  cleanElements: ->
    @$el.empty()

  templateContent: ->
    if _.isFunction(@template)
      return @template(this)
    else
      return @template

  renderTemplate: ->
    template = @templateContent()
    if template?
      if _.isString(template)
        @$el.html(template)
      else
        if template.clone?
          @$el.append(template.clone())
        else
          @$el.append(template)
      @delegateEvents()
      @bindElements?()

  cleanup: (dispose)->
    @unbindElements?()
    @undelegateEvents()
    @removeAllViews()
    @cleanElements()

  bindTo: (obj, ev, handler)->
    @unbindFrom(obj, ev, handler)
    obj.on(ev, handler, this)
    return obj

  bindOnceTo: (obj, ev, handler)->
    @unbindFrom(obj, ev, handler)
    obj.once(ev, handler, this)
    return obj

  unbindFrom: (obj, ev, handler)->
    obj.off(ev, handler, this)
    return obj

  countViews: ->
    return _.size(@_viewsByCid)

  views: ->
    return @_views

  view: (name)->
    return @_views[name]

  addView: (view, name)->
    if view && name
      [name, view] = [view, name]
    name ?= view.cid
    existing = @_views[name] || @_viewsByCid[view.cid]
    if existing
      return existing
    @_views[name] = @_viewsByCid[view.cid] = view
    @bindTo(view, "dispose", @removeView)
    view._parent = this
    return view

  removeView: (view)->
    name = null
    if _.isString(view)
      name = view
    if name && !@_views[name]
      return
    if !@_viewsByCid[view.cid]
      return
    if name
      view = @_views[name]
    @unbindFrom(view)
    view.remove()
    if name
      delete @_views[name]
    else
      for exName in _.keys(@_views)
        if @_views[exName].cid == view.cid
          delete @_views[exName]
    delete @_viewsByCid[view.cid]

  removeAllViews: ->
    for name in _.keys(@_views)
      @removeView(@_views[name])
    return null

  dispose: ->
    if @_disposed
      return
    @cleanup(true)
    @model && (@model instanceof Backbone.Model) && @unbindFrom(@model)
    @collection && (@collection instanceof Backbone.Collection) && @unbindFrom(@collection)
    @removeAllViews()
    @_disposed = true
    @trigger("dispose", this)
    @unbind()
    for prop in ['collection', 'model', 'options', '_parent']
      @[prop] = null

  remove: ->
    @dispose()
    if !@$el
      return
    super
    @$el = @el = null

  bindElements: ->
    @unbindElements()
    @rivets = rivets.bind(@$el, this)

  unbindElements: ->
    @rivets?.unbind()
    @rivets = null

  activate: ->


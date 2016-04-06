View = require("views/base_view")
template = require("views/templates/scrolltop")
analytics = require("lib/analytics")

module.exports = class ScrollTop extends View
  class_name: "scrolltop_view"
  template: template
  initialize: ->
    super
    @getTarget = @options?.getTarget
    @bindTo(@app, 'change:scroll_offset', @updatePosition)
    @bindTo(@app, 'user_is_typing', @updateOutsideWidget)

  events:
    "click .goup": "scrollTopComment"

  scrollTopComment: ->
    @app.scrollIntoVisibleView(@getTarget())
    analytics.scrollTop()

  render: ->
    super
    @$el.attr("data-is-visible", false) # hidden by default
    @$el.addClass("bz-scroll-to-top")
    _.defer(=>
      if @_disposed
        return
      @setComputedStyles()
      @updateOutsideWidget()
    )

  updatePosition: (offset = @app.parentPageOffset)->
    if offset.top < $(@getTarget()).offset().top + 20
      if @$el.attr("data-is-visible") == "true"
        @$el.attr("data-is-visible", false)
        @updateOutsideWidget()
    else
      if !(@$el.attr("data-is-visible") == "true")
        @$el.attr("data-is-visible", true)
        @updateOutsideWidget()

  updateOutsideWidget: ->
    @$el.attr("data-widget-id", "scroll-to-top")
    @app.trigger("add_widget", this, {visible: @$el.attr("data-is-visible") == "true", anchor: "bottom", right: @$el.css("right")})

  setComputedStyles: ->
    propsToCopy = [
      'color'
      'backgroundColor'
      'textAlign'
      'float'
      'fontSize'
      'fontWeight'
      'fontFamily'
      'lineHeight'
      'paddingBottom'
      'paddingTop'
      'paddingLeft'
      'paddingRight'
      'cursor'
      'display'
      'position'
      'top'
      'right'
      'bottom'
      'border'
      'textShadow'
      'opacity'
      'overflow'
      'width'
      'height'
      'borderBottomLeftRadius'
      'borderBottomRightRadius'
      'borderTopLeftRadius'
      'borderTopRightRadius'
    ]
    allElems = @$el.find('*')
    allElems.push(@$el)
    for e in allElems
      e = $(e)
      styles = e.getStyleObject()
      for p in propsToCopy
        if styles[p]
          e.css(p, styles[p])
    @$el.hide()

  dispose: ->
    @unbindFrom(@app)
    super

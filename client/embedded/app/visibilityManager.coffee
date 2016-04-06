util = require('lib/util')

# The first implementation is just a proof of concept.
# Data structures are VERY inefficient.
module.exports = class VisibilityManager

  constructor: (options = {})->
    options.extra ?= {}
    @extra = _.defaults(options.extra, {left: 0, top: 0, right: 0, bottom: 0})
    @registry = {}
    @top = null
    # This is the current viewport, relative to the current window (if the
    # current window is an iframe, the viewport is the visible part of the
    # iframe)
    @vp = {left: 0, top: 0, right: 0, bottom: 0}
    @vp_cached = {left: 0, top: 0, right: 0, bottom: 0}
    # cache of visible views
    @visible = {}

  # View must be added to dom before calling this
  # This check is NOT done, so if things don't work, make sure the view is
  # added to the DOM first.
  # `prev` must already be in the registry
  # If `prev` is null, then the view is the first added
  add: (view, prev)->
    if @registry[view.cid]
      return
    view.prev = prev
    if view.prev
      # console.log("Add view #{view.cid} below top")
      view.next = view.prev.next
      view.prev.next = view
      view.next?.prev = view
    else
      # console.log("Add view #{view.cid} above top, rewrite top")
      view.next = @top
      @top?.prev = view
      @top = view
    @registry[view.cid] = view
    view.$el.attr('data-view-cid', view.cid)
    @visible[view.cid] = view
    view.on('dispose', =>
      @remove(view)
    , this)
    @check_view(view)
    view.orig_render = view.render
    view.orig_templateContent = view.templateContent
    view.templateContent = ->
      content = view.orig_templateContent.call(view)
      if content
        $content = $(content)
        util.replaceImg($content)
        return $content
      return content
    view.render = ->
      if view.hidden
        view.renderWhenVisible = true
        return
      view.orig_render.apply(view, _.toArray(arguments))
    check_visibility = =>
      clearTimeout(view.tr_check_visible)
      view.tr_check_visible = setTimeout(=>
        @check_view(view)
        clearTimeout(view.timer_visibility)
        view.timer_visibility = setTimeout(=>
          clearTimeout(view.timer_visibility)
          @check_view(view)
        , 3000)
      , 100)
    view.on('render content_update', check_visibility, this)
    if view._rendered
      check_visibility()

  remove: (view)->
    view.prev?.next = view.next
    if @top == view
      @top = view.next
    if @cview_check == view
      @cview_check = view.next
    view.templateContent = view.orig_templateContent
    view.render = view.orig_render
    view.off(null, null, this)
    clearTimeout(view.timer_visibility)
    clearTimeout(view.tr_check_visible)
    delete @registry[view.cid]
    delete @visible[view.cid]
    view.after = null
    view.before = null
    view.hidden = null
    # check neighbors

  # Return
  #   true if visible, otherwise false
  check_view: (view)->
    bounds = view.measure()
    # console.log("Checking view ", view.cid, bounds)
    if util.rectIntersect(@vp_cached, bounds)
      # console.log("View #{view.cid} is visible")
      view.hidden = false
      @visible[view.cid] = view
      if view.renderWhenVisible
        view.render()
      else
        view.activate?()
      view.renderWhenVisible = null
      return true
    else
      # console.log("View #{view.cid} invisible")
      view.hidden = true
      delete @visible[view.cid]
      view.deactivate?()
      return false

  check_debounce = _.debounce(->
    clearTimeout(@timer_check_views)
    @cview_check = @top
    had_visible = false
    check_views = =>
      clearTimeout(@timer_check_views)
      while @cview_check && @registry[@cview_check.cid]
        if @check_view(@cview_check)
          had_visible = true
          break
        else
          @cview_check = @cview_check.next
      if had_visible
        had_visible = false
        @cview_check = @cview_check.next
        if @cview_check
          @timer_check_views = setTimeout(check_views, 1000)
    check_views()
  , 1000)

  # Sets the new viewport
  viewport: (rect)->
    # rect = {left, top, right, bottom} represents the viewport.
    # If we're running in an iframe, the coordinates must correctly describe
    # the viewport relative to the iframe.
    # console.log("Viewport: ", rect)
    rect.bottom ?= rect.top + rect.height
    rect.right ?= rect.left + rect.width
    @vp = rect
    @vp_cached =
      top: (rect.top || 0) + @extra.top
      right: (rect.right || 0) + @extra.right
      bottom: (rect.bottom || 0) + @extra.bottom
      left: (rect.left || 0) + @extra.left
    check_debounce.call(this)

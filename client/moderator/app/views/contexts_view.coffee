View = require("views/base_view")
CollectionView = require("views/collection_view")
ContextView = require("views/context_view")
template = require("views/templates/contexts")

module.exports = class Contexts extends View

  className: "contexts_view"

  template: template

  initialize: ->
    super
    @prev = 0

  events:
    # "scroll .comments": "scroll"
    "click .refresh": "refresh"

  scroll: =>
    area = @view("contexts").$el
    if area.scrollTop() > @prev
      if area.prop("scrollHeight") - area.scrollTop() - area.height() < 50 && !@disabled
        @fetchNext()
    @prev = area.scrollTop()

  render: ->
    @$(".contexts").replaceWith(@addView("contexts", new CollectionView(className: "contexts", collection: @collection, elementView: ContextView)).render().el)
    @view("contexts").$el.scroll(@scroll)

  refresh: ->
    @disabled = false
    @view("contexts").$el.scrollTop(0)
    @fetchNext({reset: true, silent: false, restart: true})
    return false

  activate: ->
    if !@_rendered
      @render()
      @refresh()

  fetchNext: (options)->
    @disabled = true
    @$el.addClass("disabled")
    done = =>
      @disabled = false
      @$el.removeClass("disabled")
    _.extend(options ?= {}, {
      data: _.extend({
        moderator: true
        sort: "time"
        dir: -1
      }, @options.filter)
      resetSession: false
      success: done
      error: done
      add: true
      merge: true
      remove: false
    })
    @collection.fetchNext(options)

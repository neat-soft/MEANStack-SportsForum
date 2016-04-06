View = require("views/base_view")
UserNotificationView = require("views/userNotification_view")
CollectionView = require("views/collection_view")
template = require("views/templates/userNotifications")

module.exports = class UserNotifications extends View

  className: "userNotifications_view"

  template: template

  initialize: ->
    super
    @$el.addClass("HAS_MORE")
    @bindTo(@app, "change:currentContext", @render)

  cleanup: ->
    super
    @view("collection") && @unbindFrom(@view("collection"))

  dispose: ->
    @unbindFrom(@app)
    super

  render: ->
    @$(".collection_view").replaceWith(@addView("collection", new CollectionView({
      collection: @model.get("notifications")
      className: "collection_view"
      elementView: UserNotificationView
      copy: false
      tagName: "table"
    })).render().el)

  events:
    "click button.more": "fetchNext"
    "click button.delete": "delete"

  delete: ->
    @model.get("notifications").destroyAll()

  fetchNext: ->
    @model.get("notifications").fetchNext({
      data: {site: @app.api.site.get("name")},
      add: true
      remove: false
      success: (resp)=>
        @$el.removeClass("LOADING_MORE LOADING")
        if !@model.get("notifications").from
          @$el.removeClass("HAS_MORE")
      error: =>
        @$el.removeClass("LOADING_MORE LOADING")
    })
    if @_rendered
      @$el.addClass("LOADING_MORE")
    else
      @$el.addClass("LOADING")
    return false

  activate: ->
    if !@fetched
      @fetchNext()
    @fetched = true


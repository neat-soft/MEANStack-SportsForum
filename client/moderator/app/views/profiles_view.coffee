View = require("views/base_view")
template = require("views/templates/profiles")
CollectionView = require("views/collection_view")
ProfileView = require("views/profile_view")

module.exports = class Profiles extends View

  className: "profiles_view"

  initialize: ->
    super
    @prev = 0
    @name_filter = ""

  beforeRender: ->
    @siteUrl = @model.url()

  render: ->
    @$(".profiles").replaceWith(@addView("profiles", new CollectionView(className: "profiles", collection: @collection, elementView: ProfileView)).render().el)
    @view("profiles").$el.scroll(@scroll)

  template: template

  events:
    "click .reset-profiles": "askResetConfirmation"
    "click .refresh": "refresh_click"
    "submit .search-profiles": "search"

  scroll: =>
    area = @view("profiles").$el
    if area.scrollTop() > @prev
      if area.prop("scrollHeight") - area.scrollTop() - area.height() < 50 && !@disabled
        @fetchNext()
    @prev = area.scrollTop()

  askResetConfirmation: ->
    if(confirm("Are you sure you want to reset the leaderboard?"))
      @reset()

  reset: ->
    @app.api.clearPoints((err, resp)=>
      if !err
        @refresh()
    )
    return false

  refresh_click: ->
    @name_filter = ""
    $('input[type="text"]').val(@name_filter)
    @refresh()

  refresh: ->
    @disabled = false
    @view("profiles").$el.scrollTop(0)
    @fetchNext({reset: true, silent: false, restart: true})
    @model.fetchProfileCount()
    return false

  search: (ev)->
    ev.preventDefault()
    @name_filter = $('input[type="text"]').val()
    @refresh()

  activate: ->
    @refresh()

  fetchNext: (options, extraQuery)->
    extraQuery ?= {}
    @disabled = true
    @$el.addClass("disabled")
    done = =>
      @disabled = false
      @$el.removeClass("disabled")
    _.extend(options ?= {}, {
      data: _.extend(extraQuery, {
        moderator: true
        sort: "time"
        dir: 1
        s: @name_filter
      })
      resetSession: false
      success: done
      error: done
      add: true
      merge: true
      remove: false
    })
    @collection.fetchNext(options)

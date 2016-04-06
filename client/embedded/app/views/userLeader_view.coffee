View = require('views/base_view')
template = require("views/templates/userLeader")
UserBadgeView = require("views/userBadge_view")
CollectionView = require('views/collection_view')
analytics = require("lib/analytics")

module.exports = class UserLeader extends View

  className: "userLeader_view"

  initialize: ->
    super
    @bindTo(@model, "change:user change:user.name change:user.imageType", @render)
    if @options.badge
      @badge_icon = @options.badge.icon
      @current_badge = @select_badge()
      if !@current_badge
        @model.get("badges")?.on("add", @new_badge)

  template: template

  new_badge: ()=>
    @current_badge = @select_badge()
    if @current_badge
      @unbindFrom(@model.get("badges"))
      @willRender()

  select_badge: =>
    for b in @model?.get("badges")?.models || []
      if b.get("badge_id") == @options.badge.badge_id
        return b
    return null

  events:
    "click a": "clickUser"

  clickUser: ->
    analytics.userClick()
    return true

  render: ->
    if !@model.get("user")?.id
      return
    if @model.get("user") == @app.api.user
      @$el.addClass("this_is_you")
    if @model.get("user").get("imageType") == "facebook"
      @$el.addClass("fb_avatar")
    else
      @$el.removeClass("fb_avatar")

    badges = @addView("badges", new CollectionView({
      collection: @model.get("user").get("profile").get("badges")
      elementView: UserBadgeView
      top: 4
      filter: (badge)->
        return badge.get("rank") <= badge.get("rank_cutoff")
      reconsiderOn: "change:rank"
    }))
    @$(".badges_view").replaceWith(badges.render().el)

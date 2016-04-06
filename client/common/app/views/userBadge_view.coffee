View = require('views/base_view')
template = require('views/templates/userBadge')

module.exports = class UserBadge extends View

  className: 'userBadge_view'

  initialize: ->
    super
    @reconsider()
    @bindTo(@model, "change", @reconsider)

  reconsider: ->
    if @model.get("manually_assigned") || (@model.get("rank_cutoff") >= @model.get("rank"))
      @template = template
    else
      @template = null

  beforeRender: ->
    badge = @app.api.site.get("badges")?[@model.get("badge_id")]
    @title = badge?.title || "?"
    @icon = badge?.icon || "error"
    @color_bg = badge?.color_bg || "gray"

  render: ->
    @$("[data-toggle=tooltip]").tooltip({animation: "true"})
    if @color_bg
      @$(".badge_marker").css("background-color", @color_bg)

  template: template

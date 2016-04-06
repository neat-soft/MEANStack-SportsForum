View = require("views/base_view")
template = require("views/templates/user")

module.exports = class User extends View

  className: "user_view"

  template: template

  initialize: ->
    super
    @bindTo(@model, "change", @render)

  render: ->
    if !@model.get("verified")
      @$el.addClass("NOT_VERIFIED")
    else
      @$el.removeClass("NOT_VERIFIED")

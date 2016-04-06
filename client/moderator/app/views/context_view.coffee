ItemView = require("views/item_view")
template = require("views/templates/context")
UserView = require("views/user_view")

module.exports = class Context extends ItemView

  className: "context_view"

  template: template

  initialize: ->
    super
    @bindTo(@model, "change:text change:ptext", @updateText)
    @bindTo(@model, "change", @render)
    @events = _.extend({}, Context.__super__.events, @events || {})

  events:
    "click .approve-autoapproval": "approveAutoApproval"

  updateText: ->
    $text = @$(".text")
    if @model.get("ptext")
      $text.html(@model.get("ptext"))
    else
      $text.text(@model.get("text"))
    @$(".text a").attr("target", "_blank")
    $text.expandByHeight("destroy")
    $text.expandByHeight({
      expandText: @app.translate("read_more")
      collapseText: @app.translate("read_less")
      maxHeight: 500
    })

  render: ->
    if @model.get("deleted")
      @$el.addClass("DELETED")
    else
      @$el.removeClass("DELETED")
    if !@model.get("author")?.get
      return
    @$(".user_view").replaceWith(@addView("user", new UserView({
      model: @model.get("author")
    })).render().el)
    @$('.dropdown-toggle').dropdown()
    @updateText()

  approveAutoApproval: ->
    @app.api.approveItem(@model)
    @app.api.saveProfile(@model.get("author").get("profile"), {approval: 0})
    return false

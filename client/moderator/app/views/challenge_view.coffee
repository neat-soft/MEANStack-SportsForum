ItemView = require("views/item_view")
template = require("views/templates/challenge")
UserView = require("views/user_view")
Formatter = require("lib/format_comment")

module.exports = class Challenge extends ItemView

  className: "challenge_view"

  template: template

  initialize: ->
    super
    @events = _.extend({}, Challenge.__super__.events, @events || {})
    @bindTo(@model, "change:deleted", @render)
    @bindTo(@model, "change:approved", @render)
    @bindTo(@model, "change:no_flags", @render)
    @bindTo(@model, "change:spam", @render)

  events:
    "click .approve-autoapproval": "approveAutoApproval"

  render: ->
    if @model.get("deleted")
      @$el.addClass("DELETED")
    else
      @$el.removeClass("DELETED")
    @$(".challenger_view").replaceWith(@addView("challenger", new UserView({
      model: @model.get("challenger").get("author")
      className: "challenger_view"
    })).render().el)
    @$(".challenged_view").replaceWith(@addView("challenged", new UserView({
      model: @model.get("challenged").get("author")
      className: "challenged_view"
    })).render().el)
    @$('.dropdown-toggle').dropdown()
    @updateText()

  updateText: ->
    $text = @$(".challenger")
    if @model.get("challenger").get("ptext")
      $text.html(@model.get("challenger").get("ptext"))
    else
      $text.text(@model.get("challenger").get("text"))
    @$(".challenger a").attr("target", "_blank")
    Formatter.applyOembed($text, ()=>
      @app.trigger("change:layout")
      )
    $text.expandByHeight("destroy")
    $text.expandByHeight({
      expandText: @app.translate("read_more")
      collapseText: @app.translate("read_less")
      maxHeight: 500
    })

  approveAutoApproval: ->
    @app.api.approveItem(@model)
    @app.api.saveProfile(@model.get("challenger").get("author").get("profile"), {approval: 0})
    return false

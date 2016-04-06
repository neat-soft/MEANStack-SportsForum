ItemView = require("views/item_view")
template = require("views/templates/comment")
UserView = require("views/user_view")
Formatter = require("lib/format_comment")

module.exports = class Comment extends ItemView

  className: "comment_view"

  template: template

  initialize: ->
    super
    @bindTo(@model, "change:text change:ptext", @updateText)
    @bindTo(@model, "change:author", @render)
    @bindTo(@model, "change:deleted", @render)
    @bindTo(@model, "change:approved", @render)
    @bindTo(@model, "change:no_flags", @render)
    @bindTo(@model, "change:spam", @render)
    @events = _.extend({}, Comment.__super__.events, @events || {})

  events:
    "click .approve-autoapproval": "approveAutoApproval"

  updateText: ->
    $text = @$(".text")
    if @model.get("ptext")
      $text.html(@model.get("ptext"))
    else
      $text.text(@model.get("text"))
    if @model.get("forum")
      @$(".forum_text").text(@model.get("forum").text)
    @$(".text a").attr("target", "_blank")
    Formatter.applyOembed($text, ()=>
      @app.trigger("change:layout")
      )
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

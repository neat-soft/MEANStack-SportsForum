View = require("views/base_view")
template = require("views/templates/contentSubscription")

module.exports = class ContentSubscription extends View

  className: "contentSubscription_view"

  template: template

  initialize: ->
    super
    @bindTo(@model, "change:subscribeContent", @updateSubscr)
    @context = @options.context

  events:
    "change .subscribe_content": "subscribeContent"
    "submit form": "subscribe"

  render: ->
    @updateSubscr()

  updateSubscr: ->
    @$(".subscribe_content").prop("checked", !!@model.get("subscribeContent"))

  subscribeContent: ->
    if @app.api.loggedIn()
      @app.api.subscribeContent(null, @$(".subscribe_content").prop("checked"), @context)
      return false
    else
      @updateSubscrForm()

  subscribe: ->
    email = @$(".subscribe_email_content").val()
    subscribe_content = @$(".subscribe_content").prop("checked")
    if @app.api.loggedIn() || subscribe_content
      @app.api.subscribeContent(email, subscribe_content, @context)
    @$(".subscribe_content").prop("checked", false)
    @$(".subscribe_email_content").val("")
    @$el.removeClass("SHOW_SUBSCR_EMAIL")
    return false

  updateSubscrForm: ->
    if !@app.api.loggedIn()
      if @$(".subscribe_content").prop("checked")
        @$el.addClass("SHOW_SUBSCR_EMAIL")
      else
        @$el.removeClass("SHOW_SUBSCR_EMAIL")

  dispose: ->
    @context = null
    super


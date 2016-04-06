View = require("views/base_view")
template = require("views/templates/convSubscription")

module.exports = class ConvSubscription extends View

  className: "convSubscription_view"

  template: template

  initialize: ->
    super
    @appIsForum = @app.isForum()
    @bindTo(@model, "change:subscribeConv", @updateSubscr)

  events:
    "change .subscribe_conv": "subscribeConv"
    "submit form": "subscribe"

  render: ->
    # @abTestingScript()
    @updateSubscr()

  # abTestingScript: ->
  #   mboxDefine('unregSubscriptionMbox','unreg_subscription_mbox')
  #   mboxUpdate('unreg_subscription_mbox')

  updateSubscr: ->
    @$(".subscribe_conv").prop("checked", !!@model.get("subscribeConv"))

  subscribeConv: ->
    if @app.api.loggedIn()
      @app.api.subscribeConversation(null, @$(".subscribe_conv").prop("checked"))
      return false
    else
      @updateSubscrForm()

  subscribe: ->
    email = @$(".subscribe_email_conv").val()
    subscribe_conv = @$(".subscribe_conv").prop("checked")
    if @app.api.loggedIn() || subscribe_conv
      @app.api.subscribeConversation(email, subscribe_conv)
    @$(".subscribe_conv").prop("checked", false)
    @$(".subscribe_email_conv").val("")
    @$el.removeClass("SHOW_SUBSCR_EMAIL")
    return false

  updateSubscrForm: ->
    if !@app.api.loggedIn()
      if @$(".subscribe_conv").prop("checked")
        @$el.addClass("SHOW_SUBSCR_EMAIL")
      else
        @$el.removeClass("SHOW_SUBSCR_EMAIL")

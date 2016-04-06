View = require('views/base_view')
NotificationsView = require("views/notifications_view")
ConvSubscriptionView = require("views/convSubscription_view")

module.exports = class SubscriptionWidget extends View
  className: 'subscriptionWidget_view'

  template: 'subscriptionWidget'

  initialize: ->
    super
    @app.api.initRtSite()

  render: ->
    @$(".notifications_view").replaceWith(@addView("notifications", new NotificationsView()).render().el)
    @$(".convSubscription_view").replaceWith(@addView("convSubscription", new ConvSubscriptionView(model: @app.api.user)).render().el)

  dispose: ->
    @app.api.disposeRtSite()
    super

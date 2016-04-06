template = require('views/templates/currentUser')
UserImageView = require("views/userImage_view")
View = require('views/base_view')
UserNotificationsView = require("views/userNotifications_view")

module.exports = class CurrentUser extends View
  className: "currentUser_view"

  template: template

  initialize: ->
    super
    @bindTo(@model, "change:name change:image", @render)
    if @model.get("type") == "sso"
      @ssologin = true
    @bindTo(@model, "change:no_notif_new", @updateUnread)

  events:
    "click .logout": "logout"
    "click .user_notif": "expandNotifications"
    "clickout .user_notif": "hideNotifications"

  updateUnread: ->
    @$(".no_notif_unread").text(@app.translate("new_notifications", {value: @model.get("no_notif_new")}))
    if @model.get("no_notif_unread") > 0
      @$el.addClass("HAS_UNREAD_NOTIFICATIONS")
    else
      @$el.removeClass("HAS_UNREAD_NOTIFICATIONS")

  render: ->
    @$(".notifications-list").append(@addView("user_notifications", new UserNotificationsView({model: @model})).render().el)
    @$(".author_image_container").append(@addView(new UserImageView(model: @model)).render().el)
    @updateUnread()

  logout: ->
    if @app.logout
      @app.logout()
      return false
    return true

  hideNotifications: ->
    @$el.removeClass("SHOW_UNREAD_NOTIFICATIONS")

  expandNotifications: ->
    if !@$el.hasClass("SHOW_UNREAD_NOTIFICATIONS")
      @$el.addClass("SHOW_UNREAD_NOTIFICATIONS")
      @view("user_notifications").activate()
      @model.seenNotif()
    else
      @$el.removeClass("SHOW_UNREAD_NOTIFICATIONS")

View = require("views/base_view")
DebugView = require('views/debug_view')
notification = require("views/templates/notification")
analytics = require("lib/analytics")

module.exports = class Notifications extends View
  initialize: ->
    super
    @lazyUpdateVisibility = _.debounce(=>
      if @_disposed
        return
      @updateVisibility.apply(this, arguments)
    , 250)
    @bindTo(@app, 'all', @notify)
    @bindTo(@app.api, 'all', @notify)
    @bindTo(@app.api.user, 'change:no_notif_new', @updateCommentCount)
    # @bindTo(@app, 'change:scroll_offset', @notificationPos)
    @bindTo(@app, 'refresh:unseen_comments change:currentContext', @updateCommentCount)
    @active_notifs = {}
    @active_notifs_count = 0
    @rt_comment_count = 0

  template: require("views/templates/notifications")

  events:
    'click .instant-show-new input[type="checkbox"]': 'markInstantShowNew'
    'click .have-new-comments': 'goToComments'
    'click .go-to-bubble': 'goToBubble'

  markInstantShowNew: (ev)->
    ev.stopPropagation()
    # checked = $(ev.currentTarget).find("input[type='checkbox']").is(":checked")
    checked = @app.has_comment_autoload()
    checked = !checked
    @app.save_comment_autoload(checked)

  goToComments: ()->
    # make all comments visible
    $(".invisible-comment").removeClass("invisible-comment")

    # mark already seen comments as normal
    unseen = $(".realtime-comment").not(".unseen-comment")
    cmts = $(".unseen-comment.highlight-comment")
    if cmts.length > 0
      first = cmts.filter(":first")
      @app.scrollIntoVisibleView(first, {extraOffset: 44})
    analytics.commentNotifClick()

  goToBubble: ()->
    bubble = $(".user_notif")
    @app.scrollIntoVisibleView(bubble)
    bubble.click()

  toggleDisplay: (elem, show)->
    if show
      elem.show()
    else
      elem.hide()

  toggleBubbleAlert: (show)->
    @toggleDisplay(@$(".go-to-bubble"), show)

  toggleCommentsAlert: (show)->
    @toggleDisplay(@$(".more-new-comments"), show)

  showNewCommentText: ()->
    @toggleCommentsAlert(true)
    @toggleBubbleAlert(false)

  updateCommentCount: ()->
    checked = @app.has_comment_autoload()
    @$(".instant-show-new").find("input[type='checkbox']").prop("checked", checked)
    @$(".instant-show-new").find("input[type='checkbox']").attr("data-checked", checked)
    new_comments_count = $(".unseen-comment.highlight-comment").length || 0
    @rt_comment_count = new_comments_count
    @bubble_notif_count = @app.api.user.get("no_notif_new")
    @$(".go-to-bubble").html(@app.translate("more_bubble_notif", {count: @bubble_notif_count, plural: (if @bubble_notif_count > 1 then "s" else "")}))
    if checked
      invisble_comments_count = 0
    else
      invisble_comments_count = $(".invisible-comment").length || 0
      new_comments_count -= invisble_comments_count
    if new_comments_count > 0 && invisble_comments_count > 0
      @$(".more-new-comments strong").html(@app.translate("more_new_inv_comments", {count: new_comments_count, inv_count: invisble_comments_count, plural: (if new_comments_count > 1 then "s" else "")}))
      @showNewCommentText()
    else if new_comments_count > 0
      @$(".more-new-comments strong").html(@app.translate("more_new_comments", {count: new_comments_count, inv_count: invisble_comments_count, plural: (if new_comments_count > 1 then "s" else "")}))
      @showNewCommentText()
    else if invisble_comments_count > 0
      @$(".more-new-comments strong").html(@app.translate("more_inv_comments", {count: new_comments_count, inv_count: invisble_comments_count, plural: (if invisble_comments_count > 1 then "s" else "")}))
      @showNewCommentText()
    else
      @toggleCommentsAlert(false)
      if @bubble_notif_count > 0
        @toggleBubbleAlert(true)

    @updateVisibility()

  hasContent: ->
    return @active_notifs_count > 0 || @rt_comment_count > 0 || @bubble_notif_count > 0

  updateVisibility: (offset = @app.parentPageOffset)->
    if !@hasContent()
      # @notifications.removeClass("FLOATING")
      @updateOutsideWidget()
      return @$el.hide()
    # if offset.top > 0
    #   @notifications.addClass("FLOATING")
    # else
    #   @notifications.removeClass("FLOATING")
    @notifications.addClass("show")
    @notifications.css({top: offset.top + "px"})
    $('<div></div>').appendTo($('body')).remove()
    if @rt_comment_count == 0
      @toggleCommentsAlert(false)
      @toggleBubbleAlert(@bubble_notif_count > 0)
    else
      @toggleCommentsAlert(true)
      @toggleBubbleAlert(false)
    @$el.show()
    @updateOutsideWidget()

  render: ->
    @notifications = @$(".notifications")
    @notifications_list = @$(".notifications-list")
    @updateCommentCount()
    if @app.debug
      @$('.debug_view').replaceWith(@addView('debug', new DebugView()).render().el)
    @updateOutsideWidget()

  setComputedStyles: ->
    if !@$el.is(':visible')
      return
    @$el.css("top", "0px")
    propsToCopy = [
      'color'
      'backgroundColor'
      'textAlign'
      'float'
      'fontSize'
      'fontWeight'
      'fontFamily'
      'lineHeight'
      'paddingBottom'
      'paddingTop'
      'paddingLeft'
      'paddingRight'
      'marginBottom'
      'cursor'
      'display'
      'position'
      'top'
      'right'
      'border'
      'textShadow'
      'textAlign'
      'verticalAlign'
      'opacity'
      'borderTopColor'
      'borderTopStyle'
      'borderTopWidth'
      'borderBottomColor'
      'borderBottomStyle'
      'borderBottomWidth'
      'borderLeftColor'
      'borderLeftStyle'
      'borderLeftWidth'
      'borderRightColor'
      'borderRightStyle'
      'borderRightWidth'
      'borderTopLeftRadius'
      'borderTopRightRadius'
      'borderBottomLeftRadius'
      'borderBottomRightRadius'
    ]
    allElems = @$el.find('*')
    allElems.push(@$el)
    for e in allElems
      e = $(e)
      styles = e.getStyleObject()
      for p in propsToCopy
        if styles[p]
          e.css(p, styles[p])
    @$el.hide()

  updateOutsideWidget: ->
    @setComputedStyles()
    @$el.attr("data-widget-id", "notifications")
    @app.trigger("add_widget", this, {visible: @hasContent(), anchor: "top"})

  notify: (e, data = {})=>
    data.translate ?= true
    data.translate_options ?= {}
    [type, message] = e.split(':')
    if !(type in ['error', 'info', 'warn', 'success'])
      return
    message = data.message || message
    if (data.maxTimesUser && @app.api.loggedIn() || data.maxTimes)
      if data.maxTimesUser
        key = "user_notif_#{@app.api.user.id}_#{message}"
        maxTimes = data.maxTimesUser
      else
        key = "user_notif_#{message}"
        maxTimes = data.maxTimes
      try
        localData = @JSON.parse(app.get_local_storage(key))
      catch e
        #
      if !localData
        localData = {maxTimes: maxTimes, message: message, times: 0, translate: data.translate}
      if localData.times >= maxTimes
        return
      localData.times++
      @app.set_local_storage(key, JSON.stringify(localData))
    if type == 'error' && data.translate && data.api && !@app.localization.hasTerm(message)
      message = "error_access_api"
    text = if data.translate then @app.translate(message, data.translate_options) else message
    exists = _.findWhere(@active_notifs, {message: text})
    if exists
      clearTimeout(exists.timer)
      exists.notif_elem.remove()
      notif_uid = exists.uid
      exists = null
    else
      notif_uid = _.uniqueId('notif_')
    new_notif = $(notification({type:type, heading: data.heading, text: text}))
    @active_notifs[notif_uid] = {
      message: text
      timer: setTimeout(=>
        new_notif.remove()
        delete @active_notifs[notif_uid]
        @active_notifs_count--
        @updateVisibility()
      , 10000)
      notif_elem: new_notif
      uid: notif_uid
    }
    @active_notifs_count++
    @notifications_list.append(new_notif)
    @updateVisibility()

  hideNotifications: ->
    @notifications.removeClass("show")

  notificationPos: (offset)->
    @hideNotifications()
    @lazyUpdateVisibility(offset)

  cleanup: ->
    for own uid, notif of @active_notifs
      clearTimeout(notif.timer)
    @active_notifs = {}
    @notifications = null
    super

  dispose: ->
    @unbindFrom(@app.api)
    @unbindFrom(@app)
    super

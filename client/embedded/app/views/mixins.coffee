sharedUtil = require("lib/shared/util")
util = require('lib/util')

module.exports.login =
  alreadySignedUp: (e)->
    @$el.find('.login-link.own').click()
    return false

module.exports.comments =

  updateEditControls: (time)->
    diff = time - @model.get("created")
    seconds = diff / 1000
    if seconds < (@app.options.editCommentPeriod / 1000) && (@model.get("author") || @model.get("challenger")?.get?("author")) == @app.api.user
      @$el.addClass("CAN_EDIT")
    else
      @$el.removeClass("CAN_EDIT")

  updateTimeStamp: (time)->
    edited = (@model.get("modified_by_user") && "edited_") || ""
    diff = time - (@model.get("edited_at") || @model.get("created"))
    seconds = diff / 1000
    if seconds < 60
      @$time?.text(@app.translate("#{edited}just_now_short"))
    else if seconds < 3600
      @$time?.text(@app.translate("#{edited}minutes_short", {value: Math.floor(seconds/60)}))
    else if seconds < 86400 # a day
      @$time?.text(@app.translate("#{edited}hours_short", {value: Math.floor(seconds/3600)}))
    else
      @$time?.text(@app.translate("#{edited}days_short", {value: Math.floor(seconds/86400)}))

  edit_cancel: ->
    @$el.removeClass('EDIT')
    e?.stopPropagation()

  edit_save: (e)->
    text = @$edit.html()
    if sharedUtil.removeWhite(text)
      @app.api.editComment(@model, text, (err)=>
        if !err
          @edit_cancel()
      )
    e?.stopPropagation()

  hideImages: ->
    # console.log("Hiding images for #{@cid}")
    util.replaceImg(@$el.children().first(), true)

  showImages: ->
    # console.log("Showing images for #{@cid}")
    util.restoreImg(@$el.children().first(), true)

  measure: ->
    @$el.children().first()[0]?.getBoundingClientRect() || {top: 0, bottom: 0, left: 0, right: 0}

  isRealtime: ->
    return !!@model.get("_is_realtime")

  updateRealtimeComment: ->
    if @app.api.user.id && (@model.get("author")?.id == @app.api.user.id || @model.get("challenger")?.get("author")?.id == @app.api.user.id)
      # comments by current user are not highlighted
      return

    is_rt = !!@model.get("_is_realtime")
    old_rt = !!@$el.hasClass("realtime-comment")

    if is_rt != old_rt
      if is_rt
        @$el.addClass("realtime-comment unseen-comment")
        if !@app.has_comment_autoload() && (@$el.offset().top < @app.parentPageOffset.top + @app.parentPageOffset.height)
          # in viewport (or above), user doesn't want autoload, make it invisible
          @$el.addClass("invisible-comment")
        else
          @$el.show()
        # listen for visibility change
        @unbindFrom(@app, "change:scroll_offset")
        @bindTo(@app, "change:scroll_offset change:height", @checkVisibility, this)
      else
        # mark as regular comment
        @$el.removeClass("realtime-comment unseen-comment invisible-comment")

    is_new = !!@model.get("_is_new_comment")
    old_new = !!@$el.hasClass("highlight-comment")

    if is_new != old_new
      if is_new
        @$el.addClass("highlight-comment cfgstyle")
      else
        @$el.removeClass("highlight-comment cfgstyle")

      _.defer(=>
        # update notification about new comments
        @app.trigger("refresh:unseen_comments")
      )

  getVisibleHeight: ->
    rect = @el.getBoundingClientRect()
    maxTop = Math.max(rect.top, @app.parentPageOffset.top)
    minBot = Math.min(rect.bottom, @app.parentPageOffset.top + @app.parentPageOffset.height)
    return minBot - maxTop

  getHeight: ->
    rect = @el.getBoundingClientRect()
    return rect.bottom - rect.top

  isVisibleTop: ->
    rect = @el.getBoundingClientRect()
    return @app.parentPageOffset.top <= rect.top && rect.top <= @app.parentPageOffset.top + @app.parentPageOffset.height

  isVisible: ->
    return @getVisibleHeight() >= Math.min(100, @getHeight() / 2)

  scheduleFading: ->
    setTimeout(=>
      @$el?.addClass("fade-highlight")
    , 10000)

  checkVisibility: ->
    if !@$el.hasClass("unseen-comment")
      return

    instant_new = @app.has_comment_autoload()

    if !instant_new && @$el.hasClass("invisible-comment")
      return

    if @isVisible() || (instant_new && @isVisibleTop())
      @unbindFrom(@app, "change:scroll_offset change:height", this)
      # the comment is into view
      @$el.removeClass("unseen-comment")
      if @$el.hasClass("invisible-comment")
        @$el.hide()
        @$el.removeClass("invisible-comment")
        @$el.slideDown(@$el.height() * 7)
      @model.unset("_is_realtime")
      @model.unset("_is_new_comment")
      @scheduleFading()
      @app.trigger("refresh:unseen_comments")

module.exports.app_popups =

  showUser: (id)->
    UserView = require('views/user_view')
    User = require('models/user')
    model = @app.api.store.models.get(id)
    @closePopups()
    doShow = (model)=>
      @$('#user-profile').append(@addView("user", new UserView(model: @app.api.store.models.get(id))).render().el)
      current_hash = @app.urlHistory[@app.urlHistory.length - 2]
      @view('user').from_url = current_hash
      @$('.user_view').css('top', @app.parentPageOffset.top)
    if model
      doShow(model)
    else
      @app.api.store.getCollection(User, true).fetchModel(User, {_id: id}, {success: => doShow(@app.api.store.models.get(id))})

  openUserProfile: (e)->
    e.preventDefault()
    e.stopPropagation()
    uid = $(e.currentTarget).attr("data-uid")
    @showUser(uid)

  closeUserProfile: (change_url = false)->
    view = @view('user')
    if !view
      return
    view.remove()
    if view == @activeView
      @activeView = null
    if change_url
      @app.backToViewUrl(view)

  showBadge: (id)->
    @closePopups()
    BadgeLeaderboardView = require('views/badge_leaderboard_view')
    @$('#badge-details').append(@addView("badge", new BadgeLeaderboardView(id: id)).render().el)
    current_hash = @app.urlHistory[@app.urlHistory.length - 2]
    @view('badge').from_url = current_hash
    @$('#badge-details .badge_view').css('top', @app.parentPageOffset.top)
    if @activeView?.model
      @activeView.activate?()

  openBadgeDetails: (e)->
    e.preventDefault()
    e.stopPropagation()
    @closePopups()
    id = $(e.currentTarget).find(".badge-title").attr("data-badge-id")
    @showBadge(id)
    return false

  closeBadgeDetails: (change_url = false)->
    view = @view('badge')
    if !view
      return
    view.remove()
    if view == @activeView
      @activeView = null
    if change_url
      @app.backToViewUrl(view)

  closePopups: ->
    @closeUserProfile?()
    @closeFundedComments?()
    @closeBadgeDetails?()

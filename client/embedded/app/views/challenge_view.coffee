MajorCommentView = require('views/majorCommentInChallenge_view')
CommentView = require('views/comment_view')
CollectionView = require("views/collection_view")
NewCommentView = require('views/newComment_view')
Formatter = require("lib/format_comment")
template = require('views/templates/challenge')
View = require('views/base_view')
sharing = require("../sharing")
analytics = require('lib/analytics')
util = require('lib/util')

module.exports = class Challenge extends View
  className: "challenge_view"

  initialize: ->
    super
    @options.mode ||= 'full'
    @$el.addClass('comment-level-1')
    @$el.attr("id", "comment-#{@model.id}")
    if @options.mode == 'full'
      @bindTo(@model, "change:no_flags change:flagged", @updateFlagged)
      @bindTo(@model, "change:replying", =>
        if @_rendered
          @updateReplies()
      )
    @bindTo(@model, "change:_is_realtime", @updateRealtimeComment)
    @bindTo(@model, "change:challenged change:challenger", @render)
    @bindTo(@model, "change:deleted", @render)
    @bindTo(@model, "change:context", @render)
    @bindTo(@model, "change:finished", ->
      if @_rendered
        @updateEndTime(@app.serverTimeCorrected())
    )
    @bindTo(@model, "change:ends_on", ->
      if @_rendered
        @updateEndTime(@app.serverTimeCorrected())
    )
    @bindTo(@app, "server_time_passes", (app, serverTime)=>
      if !@_rendered
        return
      if @model.get("deleted")
        @updateTimeStamp(serverTime)
      else if !@model.get("finished")
        @updateEndTime(serverTime)
        @updateEditControls(serverTime)
    )
    @$el.hide()

  beforeRender: ->
    @linkBase = if @app.isArticle() then "#brzn/comments" else "#brzn/contexts/#{@model.get('context')?.id}/comments"
    @emailLink = "#{@app.integration.baseUrl}/go/#{@model.id}"
    @commentLink = "#{@linkBase}/#{@model.id}"
    @betting_enabled = @app.api.site.get('premium')

  cleanup: ->
    @$container = null
    @$time = null
    @$endstime = null
    @$edit = null
    super

  beforeRender: ->
    perm = @app.api.user.get("profile")?.get("permissions") || {}
    mod = perm.moderator || perm.admin
    @deleted = @model.get("deleted") && (!@model.get("deleted_data") || mod)
    @text_reply = @app.translate("reply")
    @text_title_reply = @app.translate("title_reply_challenge")
    @type_challenge = 1
    @can_challenge = 0

  render: ->
    if @isRealtime()
      @updateRealtimeComment()
    @$el.show()
    @$container = $(@$el.children().first())
    if @deleted
      @$time = @$container.find(".time")
      @updateTimeStamp(@app.serverTimeCorrected())
      @$el.addClass("DELETED")
    else
      if !(@model.get("challenged") instanceof Backbone.Model) || !(@model.get("challenger") instanceof Backbone.Model)
        return
      @$endstime = @$container.find(".ends_time")
      @$el.children(".single-item-wrapper").find(".mobile_options_menu > .dropdown-menu").addClass('CHECK-HEIGHT')
      @updateEndTime(@app.serverTimeCorrected())
      if @options.mode == 'full'
        @setupNewComment()
        @$el.children(".newComment_view").replaceWith(@view("newComment").render().el)
        @bindTo(@view("newComment"), "ok", @hideReply)
        @bindTo(@view("newComment"), "cancel", @hideReply)
        @updateFlagged()
      @$container.find(".challenged").append(@addView("challenged", new MajorCommentView(model: @model.get("challenged"), challenged: true, manage_visibility: @options.manage_visibility)).render().el)
      @$container.find(".challenger").append(@addView("challenger", new MajorCommentView(model: @model.get("challenger"), challenger: true, manage_visibility: @options.manage_visibility)).render().el)
    if @options.mode == 'full'
      @$el.children(".comments_view").replaceWith(@addView("comments", new CollectionView(
        collection: @model.get("comments"),
        elementView: CommentView,
        elementViewOptions: {manage_visibility: @options.manage_visibility},
        className: "comments_view"
      )).render().el)
      @bindTo(@view('comments'), 'render_child', (child, after)=>
        after ?= this
        @app.visManager?.add(child, after)
      )
      @updateEditControls(@app.serverTimeCorrected())
      @$edit = @$el.children('.edit_comment').find('.xtextarea.edit_comment_text')
    return @

  setupNewComment: ->
    @addView("newComment", new NewCommentView(model: @model, allowQuestion: false))

  updateEndTime: (time)=>
    if @model.get("deleted")
      return
    if @model.get("finished")
      @$endstime.text(@app.translate("challenge_ended"))
      return
    intime = util.intime(@model.get("ends_on"), time)
    if intime.term == 'now'
      term = "ends_#{intime.term}"
    else
      term = "ends_in_#{intime.term}"
    @$endstime.text(@app.translate(term, intime.options))

  template: template

  events:
    "click .share-fb": "shareFb"
    "click .share-tw": "shareTw"
    "click .flag": "flag"
    # "touchstart .flag": "flag"
    "click .delete": "askDeleteConfirmation"
    "click .delete-points": "askDeletePointsConfirmation"
    # "touchstart .delete": "delete"
    "click .reply": "reply"
    "click .reply-with-bet": "replyWithBet"
    # "touchstart .reply": "reply"
    "click .mobile_options_menu ul a": "closeMobileMenu"
    "click .edit_comment_save": "edit_save"
    "click .edit_comment_cancel": "edit_cancel"
    "click .edit": "edit"
    # "touchstart .edit": "edit"

  edit: (e)->
    @$el.addClass('EDIT')
    @$edit.html(@app.api.textToHtml(@model.get("challenger").get("text"), "span"))
    Formatter.startCompletion(@$edit, @app)
    _.defer(=>
      if !@autosize && !@_disposed
        @$edit.placeholder()
        @$edit.autosize()
        @$edit.trigger('autosize')
        @autosize = true
        @$edit.focus()
    )
    e?.stopPropagation()

  activate: ->
    if !@_rendered
      @render()

  updateReplies: ->
    count = @model.get("replying")
    if @$el.hasClass("REPLYING")
      count -= 1
    if count > 0
      @$container.find(".active-replies").html(@app.translate("comment_active_replies", {value: count}))
    else
      @$container.find(".active-replies").html("")

  reply: (e)->
    if @$el.hasClass("REPLYING")
      return false
    @view("newComment").activate()
    @$el.addClass("REPLYING")
    if(@$el.children(".challenge_container").width() <= 400)
      width = ((@$el.children(".challenge_container").width() || 0) - 5) + "px"
    else
      width = ((@$el.children(".challenge_container").width() || 0) - 5) + "px"
    @view("newComment").$el.css("width", width)
    @view("newComment").focus()
    @app.api.notifyStartReply(@model)
    analytics.clickReply()
    return false

  replyWithBet: (e)->
    @reply(e)
    ncv = @view('newComment')
    ncv.mode = 'bet'
    ncv.render()
    e.stopPropagation()
    e.preventDefault()
    analytics.yoloClick()

  hideReply: =>
    @$el.removeClass("REPLYING")
    @app.api.notifyStopReply(@model)

  shareFb: (e)->
    e.stopPropagation()
    sharing.fbshareChallenge(@model, @app.options.fbAppId, @app.api)
    return false

  shareTw: (e)->
    e.stopPropagation()
    sharing.tweetChallenge(@model, @app.api)
    return false

  flag: ->
    @app.api.flag(@model)
    return false

  getChallengerName: ->
    return @model.get("challenger").get("author")?.get?("name") || @model.get("challenger").get("guest").get("name")

  askDeleteConfirmation: (e)->
    if(confirm(@app.translate("confirm_delete_challenge")))
      @delete(true)
    e.stopPropagation()
    e.preventDefault()

  askDeletePointsConfirmation: (e)->
    if(confirm(@app.translate("confirm_delete_challenge_wpts", {username: @getChallengerName()})))
      @delete(false)
    e.stopPropagation()
    e.preventDefault()

  delete: (keepPoints)->
    @app.api.deleteComment(@model, {keep_points: keepPoints})
    return false

  closeMobileMenu: ->
    $('[data-toggle="dropdown"]').parent().removeClass('open')

  updateFlagged: =>
    if @model.get("flagged")
      @$el.addClass("USER_FLAGGED")
    else
      @$el.removeClass("USER_FLAGGED")
    if @model.get("no_flags") >= @app.options.flagsForApproval
      @$el.addClass("FLAGGED")
    else
      @$el.removeClass("FLAGGED")

  dispose: ->
    @unbindFrom(@app)
    super

  activate: ->
    # console.log("Activate view ", @cid)
    @showImages()
    # @$el.children().first().css('visibility', 'visible')

  deactivate: ->
    # console.log("Deactivate view ", @cid)
    @hideImages()
    # @$el.children().first().css('visibility', 'hidden')

_.extend(Challenge.prototype, require("views/mixins").comments)

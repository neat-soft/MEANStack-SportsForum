NewCommentView = require('views/newComment_view')
CommentProto = require('views/commentProto_view')
NewChallengeView = require('views/newChallenge_view')
repliedToInfo = require('views/templates/repliedToInfo')
Formatter = require("lib/format_comment")
sharing = require("../sharing")
analytics = require("lib/analytics")

module.exports = class BaseComment extends CommentProto

  initialize: ->
    @events = _.extend({}, BaseComment.__super__.events, @events || {})
    super
    @options.mode ||= 'full'
    setLevelClass = =>
      if @model.get("level")
        @$el.addClass("comment-level-#{@model.get('level')}")
    setLevelClass()
    @bindTo(@model, 'change:level', setLevelClass)
    @bindTo(@app, "server_time_passes", (app, serverTime)=>
      if @_rendered
        @updateTimeStamp(serverTime)
        @updateEditControls(serverTime)
    )
    if @options.mode == 'full'
      @bindTo(@model, "change:no_flags change:flagged", @updateFlagged)
      @bindTo(@model, "change:challengedIn", @updateChallengeStatus)
      @bindTo(@model, "change:promotePoints", @promotePointsChanged)
      @bindTo(@model, "change:replying", =>
        if @_rendered
          @updateReplies()
      )
    @bindTo(@model, "change:level change:parent change:parent.author change:parent.author.name", @updateInReplyTo)
    @bindTo(@model, "change:_is_realtime", @updateRealtimeComment)
    @bindTo(@model, "change:author", @updateAuthor)
    @bindTo(@model, "change:author.verified", @updateAuthor)
    @bindTo(@model, "change:deleted", @render)
    @bindTo(@model, "change:context", @render)
    @bindTo(@model, "change:edited_at", ->
      @updateTimeStamp(@app.serverTimeCorrected())
    )
    @comp = false
    @$el.hide()

  beforeRender: ->
    @linkBase = if @app.isArticle() then "#brzn/comments" else "#brzn/contexts/#{@model.get('context')?.id}/comments"
    @emailLink = "#{@app.integration.baseUrl}/go/#{@model.id}"
    @commentLink = "#{@linkBase}/#{@model.id}"
    perm = @app.api.user.get("profile")?.get("permissions") || {}
    mod = perm.moderator || perm.admin
    @deleted = @model.get("deleted") && (!@model.get("deleted_data") || mod)
    @setCommentType()
    @betting_enabled = @app.api.site.get('premium')

  cleanup: ->
    @$edit = null
    @$in_reply_to?.popover('destroy')
    @$in_reply_to = null
    super

  render: ->
    if @isRealtime()
      @updateRealtimeComment()
    @$el.show()
    super
    if !@model.get("context").id
      return
    if @options.mode == 'full'
      @$in_reply_to = @$el.children('.single-item-wrapper').find('.top_note_bar .in-reply-to a')
      @$in_reply_to.popover(
        trigger: 'hover'
        html: true
        placement: 'top'
        container: 'body'
        title: =>
          @app.translate('replied_to', {value: @model.get("parent")?.get?("author")?.get?("name")})
        content: =>
          repliedToInfo({
            content: @_parent._parent.$el.children('.single-item-wrapper').html()
          })
      )
    if @deleted
      @$el.addClass("DELETED")
    else
      if @options.mode == 'full'
        @setupNewComment()
        if !@model.get("challengedIn") && @model.get('type') != 'BET'
          @$el.children(".newChallenge_view").replaceWith(@addView("newChallenge", new NewChallengeView(model: @model)).render().el)
          @bindTo(@view("newChallenge"), "ok", @hideChallenge)
          @bindTo(@view("newChallenge"), "cancel", @hideChallenge)
        @$el.children(".newComment_view").replaceWith(@view("newComment").render().el)
        @bindTo(@view("newComment"), "ok", @hideReply)
        @bindTo(@view("newComment"), "cancel", @hideReply)
        @bindTo(@view("newComment"), "want_reply", @reply)
        @updateFlagged()
        @updateChallengeStatus()
        @updateEditControls(@app.serverTimeCorrected())
        @updateInReplyTo()
      @updateAuthor()
      @$el.children(".single-item-wrapper").find(".mobile_options_menu > .dropdown-menu").addClass('CHECK-HEIGHT')
    @updateTimeStamp(@app.serverTimeCorrected())
    if @options.mode == 'full'
      @$edit = @$el.children('.edit_comment').find('.xtextarea.edit_comment_text')
    return @

  setCommentType: ->
    if @options.mode == 'full'
      @can_challenge = 1
    else
      @can_challenge = 0
    if @model.get("type") == "QUESTION"
      @type_question = 1
    else if @model.get("cat") == "QUESTION" && @model.get("level") == 2
      @type_answer = 1
    else
      if @model.get('type') == 'BET'
        @type_bet = 1
        @can_challenge = 0
      else
        @type_comment = 1

  promotePointsChanged: ->
    @app.currentContext.get("promoted").sort()

  updateInReplyTo: ->
    if !@_rendered && !@_rendering
      return
    if @model.get('level') > 1
      if @model.get("cat") == "CHALLENGE" && @model.get('level') == 2
        in_reply_to = @app.translate("replied_to_challenge")
      else
        in_reply_to = @model.get("parent")?.get?("author")?.get?("name")
      @$in_reply_to.text(in_reply_to)

  updateAuthor: ->
    if @model.get("author") == @app.api.user
      @$el.addClass("AUTHOR")
    if !@model.get("author").get
      return
    if @model.get("author").get("verified") == false
      @$el.addClass("AUTHOR_NOT_VERIFIED")
    else
      @$el.removeClass("AUTHOR_NOT_VERIFIED")

  updateChallengeStatus: =>
    if !@_rendered && !@_rendering
      return
    if @model.get("challengedIn")
      @$container.find("a.challenge_link").attr("href", "#{@linkBase}/#{@model.get("challengedIn").id}")
      @$container.find("a.reply_in_challenge").attr("href", "#{@linkBase}/#{@model.get("challengedIn").id}/reply")
      @$el.addClass("IN_CHALLENGE")
    else
      @$el.removeClass("IN_CHALLENGE")

  setupNewComment: ->
    @addView("newComment", new NewCommentView(model: @model, allowQuestion: false))

  hideChallenge: ->
    @$el.removeClass("CHALLENGING")
    @app.api.notifyStopReply(@model)

  events:
    "click .like_up": "like"
    "click .like_down": "notlike"
    "click .reply": "reply"
    "click .reply-with-bet": "replyWithBet"
    "click .flag": "flag"
    "click .share-fb": "shareFb"
    "click .share-tw": "shareTw"
    "click .delete": "askDeleteConfirmation"
    "click .delete-points": "askDeletePointsConfirmation"
    "click .promote": "promote"
    "click .demote": "demote"
    "click .self_promote": "selfPromoteClicked"
    "click .self_promote_cancel_button": "selfPromoteCancelClicked"
    "click .self_promote_button": "selfPromote"
    "click .challenge": "challenge"
    "click a.challenge_link": "goToChallenge"
    "click a.reply_in_challenge": "replyInChallenge"
    "click .view_original": "viewOriginal"
    "click .mobile_options_menu_toggle": "showMobileOptionsMenu"
    "touchstart .mobile_options_menu_toggle": "showMobileOptionsMenu"
    "click .mod-menu-toggle": "showModMenu"
    "touchstart .mod-menu-toggle": "showModMenu"
    # "hover .not_verified_marker": "showNotVerified"
    "click .edit_comment_save": "edit_save"
    "click .edit_comment_cancel": "edit_cancel"
    "click .edit": "edit"
    "click .mobile_options_menu ul a": "closeMobileMenu"
    "click .trusted_marker": "openTrustedHelp"
    "click .badge_marker": "openBadgesHelp"

  # The following 2 functions are a hack to correctly display dropdown menus on
  # top of everything by setting fixed positions. Otherwise, they cannot go
  # further parents' borders (parents have hidden overflow).

  showMobileOptionsMenu: (e)->
    @tgt = $(e.currentTarget)
    @menuPosition = @$(@tgt).offset()
    @menuPositionLeft = @menuPosition.left - 120
    @menuPositionTop = @menuPosition.top + 35
    @$(".mobile_options_menu > .dropdown-menu").css({position: 'fixed', right:'auto', top:@menuPositionTop, left:@menuPositionLeft})

  showModMenu : (e)->
    @tgt = $(e.currentTarget)
    @menuPosition = @$(@tgt).offset()
    @menuPositionLeft = @menuPosition.left - 120
    @menuPositionTop = @menuPosition.top + 15
    @$(".mod-menu > .dropdown-menu").css({position: 'fixed', right:'auto', top:@menuPositionTop, left:@menuPositionLeft})

  goToChallenge: (e)->
    link = "#{@linkBase}/#{@model.get("challengedIn").id || @model.get("challengedIn")}"
    @app.goUrl(link)
    e.stopPropagation()

  replyInChallenge: (e)->
    link = "#{@linkBase}/#{@model.get("challengedIn").id || @model.get("challengedIn")}/reply"
    @app.goUrl(link)
    e.stopPropagation()

  viewOriginal: (e)->
    link = @commentLink
    @app.goUrl(link)
    e.stopPropagation()
    return false

  like: (e)->
    @app.api.likeComment(@model, 1)
    return false

  notlike: (e)->
    @app.api.likeComment(@model, -1)
    return false

  updateReplies: ->
    count = @model.get("replying")
    if @$el.hasClass("REPLYING")
      count -= 1
    if @$el.hasClass("CHALLENGING")
      count -= 1
    if count > 0
      @$container.find(".active-replies").html(@app.translate("comment_active_replies", {value: count})).show()
    else
      @$container.find(".active-replies").html("")

  reply: (e)->
    e.stopPropagation()
    if @$el.hasClass("REPLYING")
      return false
    @view("newComment").activate()
    @$el.addClass("REPLYING")
    comments_root = @$container.closest('.context_view').find('#comments > .comments_view')
    lvl = @model.get('level')
    root_width = comments_root.width()
    ldb_width = comments_root.children('.leaderboard').first().width()
    cont_width = @$container.width()
    if cont_width <= root_width - (lvl - 1) * 25 - ldb_width && ldb_width > 0
      near_ldb = true
    if @$el.hasClass("question_view")
      if(@$container.width() <= 400)
        width = ((near_ldb && cont_width || root_width || 0) - 5) + "px"
      else
        width = ((cont_width || 0) - 5) + "px"
    else
      if(@$container.width() <= 400)
        width = ((near_ldb && cont_width || root_width || 0) - 15) + "px"
      else
        width = ((cont_width || 0) - 5) + "px"
    @view("newComment").$el.css("width", width)
    if !@app.is_ios
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

  edit: (e)->
    @$el.addClass('EDIT')
    @$edit.css("width", @$container.width())
    @$edit.html(@app.api.textToHtml(@model.get("text"), "span"))
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
    return false

  challenge: (e)->
    e.stopPropagation()
    if @$el.hasClass("CHALLENGING")
      return false
    if(@$container.first().width() <= 400)
      width = @$container.first().width() + "px"
    else
      width = ((@$container.first().width() || 0) - 110) + "px"
    @view("newChallenge").$el.css("width", width)
    @$el.addClass("CHALLENGING")
    @view("newChallenge").focus()
    @view("newChallenge").activate()
    @app.api.notifyStartReply(@model)
    analytics.clickChallenge()
    return false

  hideReply: =>
    @$el.removeClass("REPLYING")
    @app.api.notifyStopReply(@model)

  updateFlagged: =>
    if @model.get("author") == @app.api.user._id
      return

    if @model.get("flagged")
      @$el.addClass("USER_FLAGGED")
    else
      @$el.removeClass("USER_FLAGGED")
    if @model.get("no_flags") >= @app.options.flagsForApproval
      @$el.addClass("FLAGGED")
    else
      @$el.removeClass("FLAGGED")

  flag: ->
    @app.api.flag(@model)
    return false

  openTrustedHelp: (e)->
    e.stopPropagation()
    window.open("http://help.theburn-zone.com/customer/portal/articles/1654374-what-is-the-trusted-badge-")

  openBadgesHelp: (e)->
    e.stopPropagation()
    window.open("http://help.theburn-zone.com/customer/portal/articles/1954792-all-badges-links")

  shareFb: (e)->
    e.stopPropagation()
    sharing.fbshareComment(@model, @app.options.fbAppId, @app.api)
    return false

  shareTw: (e)->
    e.stopPropagation()
    sharing.tweetComment(@model, @app.api)
    return false

  getAuthorName: ->
    return @model.get("author")?.get?("name") || @model.get("guest").get("name")

  askDeleteConfirmation: (e)->
    if(confirm(@app.translate("confirm_delete_comment")))
      @delete(true)
    e.stopPropagation()
    e.preventDefault()

  askDeletePointsConfirmation: (e)->
    if(confirm(@app.translate("confirm_delete_comment_wpts", {username: @getAuthorName()})))
      @delete(false)
    e.stopPropagation()
    e.preventDefault()

  delete: (keepPoints)->
    @app.api.deleteComment(@model, {keep_points: keepPoints})
    return false

  promote: ->
    @app.api.promoteComment(@model)
    analytics.promoteClick()
    return false

  demote: ->
    @app.api.demoteComment(@model)
    analytics.promoteDemote()
    return false

  selfPromoteClicked: ->
    minimumPoints = @model.get('context').get('minPromotePoints')
    if @model.get("promotePoints")
      @$el.children().first().find(".current_promote_points").text(@app.translate("current_promote_points", {value: @model.get("promotePoints")}))
    currentPoints = @model.get("promotePoints") ? 0
    pointsNeeded = minimumPoints - currentPoints
    if !@model.get("promoted_visible")
      @$el.children().first().find(".promote_points_needed").text(@app.translate("promote_points_needed", {value: pointsNeeded}))
      @$el.children().first().find(".promote_points_number").val(pointsNeeded)
    else
      @$el.children().first().find(".promote_points_needed").text("")
      @$el.children().first().find(".promote_points_number").val("")
    @$el.children().first().addClass("PROMOTE_POPUP_VISIBLE")
    @app.trigger("change:layout")
    analytics.promoteClick()
    return false

  selfPromoteCancelClicked: ->
    @$el.children().first().removeClass("PROMOTE_POPUP_VISIBLE")
    @app.trigger("change:layout")

  selfPromote: ->
    points = @$('.promote_points_number').val() || 0
    @app.api.selfPromoteComment(@model, points)
    @$el.children().first().removeClass("PROMOTE_POPUP_VISIBLE")
    return false

  dispose: ->
    @unbindFrom(@app)
    super

  # showNotVerified: ->
  #   $(".not_verified_marker > span").slideDown()
  #   $( ".not_verified_marker > span" ).show( "slide" );
  #   $(".not_verified_marker > span").show("slide", { direction: "right" }, "slow");

  closeMobileMenu: ->
    $('[data-toggle="dropdown"]').parent().removeClass('open')

  activate: ->
    # console.log("Activate view ", @cid)
    @showImages()
    # @$el.children().first().css('visibility', 'visible')

  deactivate: ->
    # console.log("Deactivate view ", @cid)
    @hideImages()
    # @$el.children().first().css('visibility', 'hidden')

_.extend(BaseComment.prototype, require("views/mixins").comments)

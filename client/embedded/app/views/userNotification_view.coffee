View = require("views/base_view")
Comment = require("models/comment")
template = require("views/templates/userNotification")
UserImageView = require("views/userImage_view")

module.exports = class UserNotification extends View

  className: "userNotification_view"

  template: template

  tagName: "tr"

  events:
    # "click .btn-link": "navigateNotif"
    "click": "navigateNotif"

  navigateNotif: (e)->
    if !@model.get("read")
      @app.api.user.readNotif(@model)
    if @localLink
      if !@link
        return false
      @app.goUrl(@link)
    else
      if @link
        window.open(@link)
    return false

  iconMap:
    "WIN_QUESTION": "icon-trophy"
    "ANSWER": "icon-reply"
    "REPLY": "icon-comment"
    "NEW_COMMENT": "icon-comment"
    "MENTION": "icon-comment"
    "CHALLENGED": "icon-fire"
    "NEW_CHALLENGE": "icon-fire"
    "WIN_CHALLENGE": "icon-trophy"
    "PROMOTED_COMMENT": "icon-plus"
    "OUTBID_COMMENT": "icon-minus"
    "LOSE_CHALLENGE": "icon-minus"
    "NEW_CONVERSATION": "icon-comments"
    "LIKE_ANSWER_UP": "icon-thumbs-up"
    "LIKE_ANSWER_DOWN": "icon-thumbs-down"
    "LIKE_COMMENT_UP": "icon-thumbs-up"
    "LIKE_COMMENT_DOWN": "icon-thumbs-down"
    "LIKE_ANSWER_UPDOWN_UP": "icon-thumbs-up"
    "LIKE_ANSWER_UPDOWN_DOWN": "icon-thumbs-down"
    "LIKE_COMMENT_UPDOWN_UP": "icon-thumbs-up"
    "LIKE_COMMENT_UPDOWN_DOWN": "icon-thumbs-down"
    "VOTE_UP": "icon-thumbs-up"
    "VOTE_DOWN": "icon-thumbs-down"
    "BET_UNRESOLVED": "icon-money"
    "BET_CLOSED": "icon-money"
    "BET_FORF_CLOSED": "icon-money"
    "BET_FORF_STARTED": "icon-money"
    "BET_REMIND_FORF": "icon-money"
    "BET_WIN": "icon-money"
    "BET_LOSE": "icon-money"
    "BET_TIE": "icon-money"
    "BET_FORFEITED": "icon-money"
    "BET_ACCEPTED": "icon-money"
    "BET_DECLINED": "icon-money"
    "BET_CLAIMED": "icon-money"

  initialize: ->
    super
    @bindTo(@model, "change:read", @updateRead)
    @bindTo(@model, "change", =>
      if @model.get("context")?.id || _.str.startsWith(@model.get("type"), "COMPETITION_")
        @render()
    )

  beforeRender: ->
    if !@model.get("context")?.id && !_.str.startsWith(@model.get("type"), "COMPETITION_")
      return
    @thisContext = (@model.get("context")?.id == @app.currentContext?.id)
    @thisSite = @app.api.site.get("name") == @model.get("siteName")
    if /competition/i.test(@model.get("type"))
      @link = @model.get("rules_url")
      @localLink = false
    switch @model.get("type")
      when "WIN_QUESTION"
        id = @model.get("question").id
      when "ANSWER", "REPLY", "MENTION"
        id = @model.get("comment").id
        @byUser = @model.get("comment").get("author")
      when "NEW_COMMENT", "NEW_BET", "PROMOTED_COMMENT", "OUTBID_COMMENT"
        id = @model.get("comment").id
      when "BET_TARGETED", "BET_ACCEPTED", "BET_DECLINED", "BET_FORFEITED", "BET_CLAIMED"
        id = @model.get("comment").id
        @byUser = @model.get("by")
      when "BET_UNRESOLVED", "BET_CLOSED", "BET_FORF_CLOSED", "BET_FORF_STARTED", "BET_WIN", "BET_LOSE", "BET_TIE", "BET_REMIND_FORF", "BET_SENT_TO_MOD"
        id = @model.get('comment').id
        if @model.get('type') == 'BET_WIN' || @model.get('type') == 'BET_LOSE'
          @points = @model.get('points')
      when "LIKE_ANSWER_UPDOWN", "LIKE_COMMENT_UPDOWN", "LIKE_ANSWER", "LIKE_COMMENT"
        id = @model.get("comment").id
        @byUser = @model.get("by") || new Backbone.Model(name: @app.translate("like_author_unknown"))
      when "IGNITE_COMMENT"
        id = @model.get("comment").id
        @byUser = @model.get("by") || new Backbone.Model(name: @app.translate("ignite_author_unknown"))
      when "CHALLENGED"
        id = @model.get("challenge").id
        @byUser = @model.get("challenge").get("challenger").get("author")
      when "NEW_CHALLENGE", "WIN_CHALLENGE", "LOSE_CHALLENGE"
        id = @model.get("challenge").id
      when "VOTE"
        id = @model.get("challenge").id
        @byUser = @model.get("by") || new Backbone.Model(name: @app.translate("like_author_unknown"))
      when "NEW_CONVERSATION"
        id = @model.get("context").id
      when "COMPETITION_END"
        if @thisSite
          @link = "#brzn/competitions/#{@model.get("comp_id")}"
          @localLink = true
        else
          @link = null
          @localLink = false

    if !/competition/i.test(@model.get("type")) && id
      id._id && id = id._id
      if @thisContext
        if @model.get("type") == "NEW_CONVERSATION"
          @link = ""
        else if @app.isArticle()
          @link = "#brzn/comments/#{id}"
        else
          @link = "#brzn/contexts/#{@model.get("context")?.id}/comments/#{id}"
        @localLink = true
      else if @app.isForum() && @thisSite
        if @model.get("type") == "NEW_CONVERSATION"
          @link = "#brzn/contexts/#{id}"
        else
          @link = "#brzn/contexts/#{@model.get("context")?.id}/comments/#{id}"
        @localLink = true
      else
        @link ||= "#{@app.integration.baseUrl}/go/#{id}"
        @localLink = false
    if @localLink
      @target = "_self"
    else
      @target = "_blank"

    switch @model.get("type")
      when "NEW_CONVERSATION"
        @textKey = "user_notif_NEW_CONVERSATION"
      when "LIKE_ANSWER", "LIKE_COMMENT", "VOTE"
        if @model.get("up")
          @textKey = "user_notif_" + @model.get("type")
        else
          @textKey = "user_notif_" + @model.get("type") + "_down"
      when "LIKE_ANSWER_UPDOWN", "LIKE_COMMENT_UPDOWN", "VOTE"
        likeChanges = @model.get("likeChanges")
        if likeChanges.up <= 0 && likeChanges.down != 0
          if likeChanges.down > 0
            #downlike
            @textKey = "user_notif_" + @model.get("type") + "_down"
          else
            #retracted down
            @textKey = "user_notif_" + @model.get("type") + "_down_retract"
        else
          if likeChanges.up > 0
            #up-like
            @textKey = "user_notif_" + @model.get("type")
          else
            #retracted up
            @textKey = "user_notif_" + @model.get("type") + "_retract"
      else
        @textKey = "user_notif_" + @model.get("type")

    iconType = @model.get("type")
    if likeChanges
      if likeChanges.up > 0 || likeChanges.down < 0
        iconType += "_UP"
      else
        iconType += "_DOWN"
    else
      if @model.get("up") == true
        iconType += "_UP"
      else if @model.get("up") == false
        iconType += "_DOWN"
    @icon = @iconMap[iconType]

  updateRead: =>
    if @model.get("read")
      @$el.addClass("READ")
    else
      @$el.removeClass("READ")

  render: ->
    if @byUser
      if !@byUser.get("name")
        @byUser.fetch()
      @bindTo(@byUser, "change:name", (user, name)=>
        @$(".notif-text").text(@app.translate(@textKey, {username: name, sitename: @model.get("siteName")}))
      )
      @$(".notif-text").text(@app.translate(@textKey, {username: @byUser.get("name") || "", sitename: @model.get("siteName")}))
      @$(".author_image_container").append(@addView("by", new UserImageView(model: @byUser)).render().el)
    else if /competition/i.test(@model.get("type"))
      @$(".notif-text").text(@app.translate(@textKey, {title: @model.get("title"), days: @model.get("days")}))
    else
      @$(".notif-text").text(@app.translate(@textKey, {sitename: @model.get("siteName"), points: @points}))
    @updateRead()

  cleanup: ->
    if @byUser
      @unbindFrom(@byUser)
    super

  dispose: ->
    if @byUser
      @unbindFrom(@byUser)
    super

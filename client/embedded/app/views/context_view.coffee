View = require("views/base_view")
template = require("views/templates/context")
CurrentUserView = require("views/currentUser_view")
HeaderLoginView = require("views/headerLogin_view")
UserView = require("views/user_view")
CompetitionDetailsView = require("views/competition_details_view")
CompetitionsView = require("views/competitions_view")
sharing = require("../sharing")
notification = require("views/templates/notification")
analytics = require("lib/analytics")
AllCommentsWLeaderboardView = require("views/allCommentsWLeaderboard_view")
# ConvSubscriptionView = require("views/convSubscription_view")
# ContentSubscriptionView = require("views/contentSubscription_view")
Comment = require("models/comment")
Competition = require("models/competition")
Challenge = require("models/challenge")
NotificationsView = require("views/notifications_view")
LanguageSelectView = require("views/languageSelect_view")
ArticleModeratorView = require('views/articleModerator_view')
ScrollTopView = require('views/scrolltop_view')
BadgeLeaderboardView = require('views/badge_leaderboard_view')
FundedCommentsView = require('views/fundedComments_view')
NewCommentView = require("views/newComment_view")

module.exports = class Context extends View

  className: "context_view"

  template: template

  initialize: ->
    super
    @appIsArticle = @app.isArticle()
    @commentsFetched = false
    @lazyButtonUpdate = _.debounce(@lazyButtonUpdate, 500)
    @bindTo(@model.get("allactivities"), "sync", (source)=>
      if source instanceof Backbone.Collection
        @commentsFetched = true
    )
    @bindTo(@model.get("promoted"), "sync", (source)=>
      if source instanceof Backbone.Collection
        @promotedFetched = true
    )
    if @model.get("site").get("use_conv_leaderboard")
      @model.fetchLeaders()
    @app.api.fetchContextSubscription(@model)
    @app.api.initRtContext(@model)
    @bindTo(@model, "change:initialUrl change:text change:deleted", @updateText)
    @bindTo(@model, "change:type", @render)
    @bindTo(@model, "change:private", @render)
    # @bindTo(@app, 'change:scroll_offset', @updateScrollTop)
    @bindTo(@app.api, "login", =>
      if !@_disposed
        @app.api.fetchContextSubscription(@model)
    )

  cleanup: (dispose)->
    if dispose
      @unbindFrom(@model.get("allactivities"))
      @unbindFrom(@model.get("promoted"))
    @$funded?.popover('destroy')
    @$funded = null
    super

  dispose: ->
    @app.api.disposeRtContext(@model)
    @unbindFrom(@app.api)
    super

  events:
    "click .create-comment": "showNewComment"
    "click .fundedComments_view .close": "closeFundedComments"
    # "click .user-profile-link": "openUserProfile"
    # "click .badges-container .badge_marker": "openBadgeDetails"
    "click .show-funded-comments": "showFundedComments"
    "click .user_view .close": "closeUser"
    # "click .badge_view .close": "closeBadge"

  showNewComment: (e)->
    e.stopPropagation()
    $(e.target).hide()
    @view('newComment').$el.slideDown()

  closeUser: (e)->
    if @app.isArticle()
      e.stopPropagation()
      @closeUserProfile(true)

  closeBadge: (e)->
    if @app.isArticle()
      e.stopPropagation()
      @closeBadgeDetails(true)

  updateText: ->
    if @model.get("deleted")
      @$el.children(".text").text(@app.translate("context_deleted"))
    else if @model.get("type") == "FORUM"
      @$el.children(".text").text(@model.get("text") || @model.get("initialUrl"))

  beforeRender: ->
    @loggedIn = @app.api.loggedIn()
    if @loggedIn
      perm = @app.api.user.get("profile").get("permissions")
      @hasPrivatePermission = perm.admin || perm.moderator || perm.private
    if @model.get("private") && !@hasPrivatePermission
      @accessDenied = true

  render: ->
    if @accessDenied
      return
    @$(".languageSelect_view").replaceWith(@addView("languageSelect", new LanguageSelectView()).render().el)
    @app.views.comments = @addView("comments", new AllCommentsWLeaderboardView(model: @model))
    @$(".content_context > #comments > .comments_view").replaceWith(@app.views.comments.el)
    if @appIsArticle
      if !@app.api.loggedIn()
        @app.views.login = new HeaderLoginView()
        @$(".headerLogin_view").replaceWith(@addView("headerlogin", @app.views.login).render().el)
      else
        @$(".currentUser_view").replaceWith(@addView("currentuser", new CurrentUserView(model: @app.api.user)).render().el)
      # @$(".convSubscription_view").replaceWith(@addView("convSubscription", new ConvSubscriptionView(model: @app.api.user)).render().el)
      @app.views.notifications = @addView("notifications", new NotificationsView())
      @$(".notifications_view").replaceWith(@app.views.notifications.render().el)
      @app.views.competitions = @addView("competitions", new CompetitionsView(collection: @app.api.site.get("competitions")))
      @$(".content_context > #competitions").append(@app.views.competitions.el)
      @$(".scrolltop_view").replaceWith(@addView("scrolltop", new ScrollTopView(getTarget: =>
        return @app.views.main.el
      )).render().el)
    else
      @updateText()
    @$(".content_context > #comments > .newComment_view").replaceWith(@addView("newComment", new NewCommentView(model: @model, allowQuestion: true)).render().el)

    if @app.api.site.get('forum').enabled && @model.get('type') == 'ARTICLE'
      @$('.articleModerator_view').replaceWith(@addView("articlemoderator", new ArticleModeratorView(model: @model)).render().el)
    # @$(".contentSubscription_view").replaceWith(@addView("contentSubscription", new ContentSubscriptionView(model: @app.api.user, context: @model)).render().el)
    # @abTestingScript()
    @showComments()
    @$funded = @$('.show-funded-comments')
    @$funded.popover({
      trigger: 'hover'
      html: true
      placement: 'top'
      container: 'body'
      content: => @app.translate('help_burning')
      delay: {
        hide: 1000
      }
    })

    return this

  # abTestingScript: ->
  #   mboxDefine('shareMbox','test_share_mbox')
  #   mboxUpdate('test_share_mbox')
  #   mboxDefine('subscriptionMbox','test_subscription_mbox')
  #   mboxUpdate('test_subscription_mbox')

  preparePlaceholders: (navName)->
    @$("#navigation > li").removeClass("active")
    if navName
      @$("#navigation > li.nav-#{navName}").addClass("active")
    @$(".content_context > .tab-pane").removeClass("active")

  displayView: (viewName)->
    @$(".content_context > ##{viewName}").addClass("active")
    @activeView = @view(viewName)
    @activeView.activate?()
    @trigger("change:view", this, @activeView)

  itemView: (viewType, viewName, modelId, navName)->
    @preparePlaceholders(navName)
    view = @view(viewName)
    if view
      if view.model.id != modelId
        view.remove()
        view = null
    if !view
      model = @app.api.store.models.get(modelId)
      if model
        @$(".content_context > ##{viewName}").append(@addView(viewName, view = new viewType(model: model)).render().el)
    view && @displayView(viewName)

  catView: (navName)->
    if @activeView == @app.views[navName]
      return
    @preparePlaceholders(navName)
    @$("#navigation a[href='#brzn/#{navName}']").tab("show")
    if !@app.views[navName]._rendered
      @app.views[navName].render()
    @displayView(navName)

  showFundedComments: (e)->
    e.preventDefault()
    e.stopPropagation()
    @closePopups()
    if @activeView == @view("funded_comments")
      return
    @$(".funded_comments_container").append(@addView("funded_comments", new FundedCommentsView(model: @model)).render().el)
    @view('funded_comments').$el.css('top', @app.parentPageOffset.top)
    @displayView('funded_comments')

  showComments: ->
    if @activeView == @view("comments")
      return
    @catView("comments")
    @view('newComment').activate()
    analytics.toComments()

  closeFundedComments: ->
    view = @view('funded_comments')
    if !view
      return
    view.remove()
    if view == @activeView
      @activeView = null

  showCompetitionDetails: (id)->
    if !@app.api.store.models.get(id)
      new Competition({_id: id})
    @itemView(CompetitionDetailsView, "competition_details", id)

  showCompetitions: ->
    if @activeView == @view("competitions")
      return
    @catView("competitions")

  lazyButtonUpdate: ->
    if !@activeView
      return
    button = @$(".bz-scroll-to-top")
    firstComment = @activeView.$el.find(".comment_wrapper.single-item-wrapper:first")
    control = @activeView.$el.find(".control_bar:first")
    bottomOfPage = Math.min(control.offset().top, @app.parentPageOffset.top + @app.parentPageOffset.height)
    button.css({top: "#{bottomOfPage - button.height() - 30}px"})
    if firstComment.length && @app.parentPageOffset.top > firstComment.offset().top + firstComment.height()
      button.addClass("show")

  updateScrollTop: ->
    button = @$(".bz-scroll-to-top")
    button.removeClass("show")
    @lazyButtonUpdate()

  scrollToComment: (id, callback)->
    callback ?= (->)
    doScrollToComment = =>
      if @scrollToCommentNow(id)
        return callback()
      comment = @app.api.store.models.get(id)
      if callback
        error = (model, resp)->
          callback(resp)
      if comment && !(comment instanceof Challenge || comment instanceof Comment)
        return _.defer(-> callback({invalid: true}))
      if comment
        # The comment might not be linked to its parent and thus not displayed
        # (not loaded yet as part of the comment tree)
        unlinked = comment.firstUnlinked()
        if !comment.get("type") || !(unlinked instanceof require('models/context'))
          unlinked.set("siteName": @model.get("siteName"))
          unlinked.fetch({forNavigation: true, error: error, callback: callback})
      else
        @model.fetchComment(id, {forNavigation: true, error: error, resetSession: false, callback: callback})
    if @commentsFetched && @promotedFetched
      _.delay((-> doScrollToComment()), 100)
    else
      @bindOnceTo(@model.get("allactivities"), "sync", =>
        if @commentsFetched && @promotedFetched
          _.delay((-> doScrollToComment()), 100)
        else
      )
      @bindOnceTo(@model.get("promoted"), "sync", =>
        if @commentsFetched && @promotedFetched
          _.delay((-> doScrollToComment()), 100)
        else
      )

  scrollToCommentNow: (id)->
    element = @activeView.$el.find("#comment-#{id}")[0]
    if element
      _.delay(=>
        @app.scrollIntoVisibleView(element)
      , 1000)
      return true
    return false

  historyBack: (e)->
    e.preventDefault()
    e.stopPropagation()
    @app.goBack()

  replyToComment: (id)->
    @scrollToComment(id, (err)=>
      if !err
        comment = @app.api.store.models.get(id)
        parents = comment.parentList()
        parents.pop()
        parents.reverse()
        view = @view("comments")
        for parent in parents.reverse()
          view = view.view("comments").viewByModel(parent)
        view.view("comments").viewByModel(id).reply()
    )

  scrollToView: ->
    _.defer(=>
      @activeView.el.scrollIntoView(true)
    )

_.extend(Context.prototype, require('views/mixins').app_popups)

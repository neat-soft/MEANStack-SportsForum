FakeRouter = require('fakerouter')
qs = require('lib/qs')

module.exports = class AppRouter extends FakeRouter

  routes:
    "brzn/comments": "comments"
    "brzn/comments/:id": "commentInComments"
    "brzn/comments/:id/reply": "replyToComment"
    "brzn/users/:id": "user"
    "brzn/competitions": "competitions"
    "brzn/competitions/:id": "competitionDetails"
    "brzn/profile": "profile"
    "brzn/contexts(?:filter)": "contextsWithFilter"
    "brzn/contexts/:id": "contextInContexts"
    "brzn/contexts/:idctx/comments/:idco": "commentInContext"
    "brzn/yolo(/:filter)": "betsInForum"
    "brzn": "default"
    "*anything": "default"

  default: ->
    app.views.main.closePopups?()
    if app.options.appType == 'ARTICLE'
      @comments()
    else if app.options.appType == 'FORUM'
      @contextsWithFilter()

  betsInForum: (filter)->
    if filter
      filter = {status: filter}
    app.views.main.closePopups?()
    app.views.main.showContexts?()
    if !app.views.bets
      return
    app.views.main.showBets?()
    app.views.bets.filter(filter)

  contextsWithFilter: (filter)->
    filter ?= {}
    app.views.main.closePopups?()
    app.views.main.showContexts?()
    filter = qs.parse(filter)
    app.views.main.filter?(filter)

  contextInContexts: (id)->
    app.views.main.closePopups?()
    if app.views.main.view('current_context')?.model.id != id
      app.views.main.showContexts?()
    app.views.main.showContext?(id)

  commentInContext: (idctx, idco)->
    app.views.main.closePopups?()
    if app.views.main.view('current_context')?.model.id != idctx
      app.views.main.showContexts?()
    app.views.main.showCommentInContext?(idctx, idco)

  comments: ->
    app.views.main.closePopups?()
    app.views.main.showComments?()

  commentInComments: (id)->
    @comments()
    app.views.main.scrollToComment?(id)

  replyToComment: (id)->
    @comments()
    app.views.main.replyToComment?(id)

  user: (id)->
    app.views.main.closePopups?()
    app.views.main.showUser?(id)

  competitionDetails: (id)->
    app.views.main.closePopups?()
    app.views.main.showCompetitionDetails?(id)

  competitions: ->
    app.views.main.closePopups?()
    app.views.main.showCompetitions?()

  profile: ->
    if app.api.loggedIn()
      app.views.main.showUser?(app.user.id)

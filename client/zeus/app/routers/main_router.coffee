module.exports = class MainRouter extends Backbone.Router

  routes:
    "": "default"
    "comments": "comments"
    "comments/:id": "commentInComments"
    "comments/:id/reply": "replyToComment"
    "questions": "comments"
    "questions/:id": "question"
    "questions/:idq/comments/:idco": "commentInQuestion"
    "challenges": "comments"
    "challenges/:id": "challenge"
    "challenges/:idch/comments/:idco": "commentInChallenge"
    "users/:id": "user"
    "profile": "profile"
    "mynotifications": "mynotifications"
    "*anything": "default"

  default: ->
    @comments()

  comments: ->
    app.views.context.showComments()

  commentInComments: (id)->
    @comments()
    app.views.context.scrollToComment(id)

  replyToComment: (id)->
    @comments()
    app.views.context.replyToComment(id)

  question: (id)->
    @comments()
    app.views.context.scrollToComment(id)

  commentInQuestion: (idq, idco)->
    @comments()
    app.views.context.scrollToComment(idco)

  challenge: (id)->
    @comments()
    app.views.context.scrollToComment(id)

  commentInChallenge: (idch, idco)->
    @comments()
    app.views.context.scrollToComment(idco)

  user: (id)->
    app.views.context.showUser(id)

  profile: ->
    if app.user?
      app.views.context.showUser(app.user.id)

  mynotifications: ->
    if app.user?
      app.views.context.showUserNotifications()

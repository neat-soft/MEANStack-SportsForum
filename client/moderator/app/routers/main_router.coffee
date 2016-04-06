module.exports = class MainRouter extends Backbone.Router

  routes:
    "": "default"
    "comments": "comments"
    "contexts": "contexts"
    "profiles": "profiles"
    "subscribers": "subscribers"
    "allcomments": "allcomments"
    "unresolved_bets": "unresolvedBets"
    "competitions": "competitions"
    "*anything": "default"

  default: ->
    @comments()

  comments: ->
    app.views.main.showComments()

  contexts: ->
    app.views.main.showContexts()

  profiles: ->
    app.views.main.showProfiles()

  subscribers: ->
    app.views.main.showSubscribers()

  allcomments: ->
    app.views.main.showAllComments()

  unresolvedBets: ->
    app.views.main.showUnresolvedBets()

  competitions: ->
    app.views.main.showCompetitions()

  allcontexts: ->
    app.views.main.showAllContexts()

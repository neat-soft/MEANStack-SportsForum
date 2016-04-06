View = require("views/base_view")
CommentsView = require("views/comments_view")
ContextsView = require("views/contexts_view")
ChallengesView = require("views/challenges_view")
ProfilesView = require("views/profiles_view")
template = require("views/templates/main")
SubscribersView = require("views/subscribers_view")
ModSubscriptionView = require("views/modSubscription_view")
CompetitionsView = require("views/competitions_view")

module.exports = class Main extends View

  template: template

  render: ->
    @app.views.comments = @addView("comments", new CommentsView(model: @model, collection: @model.get("activities"), filter: {pending: true}))
    @$("#comments").append(@view("comments").el)
    if @model.get('premium')
      @app.views.unresolved_bets = @addView("unresolved_bets", new CommentsView(model: @model, collection: @model.get("unresolved_bets")))
      @$("#unresolved_bets").append(@view("unresolved_bets").el)
    @app.views.profiles = @addView("profiles", new ProfilesView(model: @model, collection: @model.get("profiles")))
    @$("#profiles").append(@view("profiles").el)
    @app.views.subscribers = @addView("subscribers", new SubscribersView(model: @model))
    @$("#subscribers").append(@view("subscribers").el)
    @app.views.allcomments = @addView("allcomments", new CommentsView(model: @model, collection: @model.get("allactivities"), className: "allComments_view"))
    @$("#allcomments").append(@view("allcomments").el)
    @app.views.competitions = @addView("competitions", new CompetitionsView(model: @model, collection: @model.get("competitions")))
    @$("#competitions").append(@view("competitions").el)
    @$("#subscription_view").replaceWith(@addView("modsubscription", new ModSubscriptionView(model: @app.api.user)).render().el)

  showMajorView: (viewName)->
    @$(".tab-pane").removeClass("active")
    @$("#navigation a[href=##{viewName}]").tab("show")
    if !@app.views[viewName]._rendered
      @app.views[viewName].render()
    @activeView = @app.views[viewName]
    @activeView.activate?()
    @trigger("change:view", this, @activeView)

  showComments: ->
    @showMajorView("comments")

  showContexts: ->
    @showMajorView("contexts")

  showProfiles: ->
    @showMajorView("profiles")

  showSubscribers: ->
    @showMajorView("subscribers")

  showAllComments: ->
    @showMajorView("allcomments")

  showUnresolvedBets: ->
    if @model.get('premium')
      @showMajorView("unresolved_bets")

  showAllContexts: ->
    @showMajorView("allcontexts")

  showCompetitions: ->
    @showMajorView("competitions")

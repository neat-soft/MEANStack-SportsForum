AllCommentsView = require("views/allComments_view")
LeaderboardView = require("views/leaderboard_view")
User = require("models/user")
Competition = require("models/competition")
CompetitionAnnounceView = require("views/competitionAnnounce_view")

module.exports = class AllCommentsWLeaderboard extends AllCommentsView

  events:
    "click .ldb-show": "showLeaderboard"

  initialize: ->
    @events = _.extend({}, AllCommentsWLeaderboard.__super__.events, @events || {})
    super

  showLeaderboard: (e)->
    @view('leaderboard').show()
    @$('.ldb-show').hide()

  showLdbMarker: (e)->
    @$('.ldb-show').show()

  render: ->
    super
    # comp = @app.api.site.get("active_competition")
    @$(".competitionAnnounce_view").replaceWith(@addView("competition_announce", new CompetitionAnnounceView()).render().el)
    # if comp and moment.utc(comp.get("end"), "DD/MM/YYYY HH:mm") > moment.utc()
    @$(".leaderboard").append(@addView("leaderboard", new LeaderboardView()).render().el)
    @bindTo(@view('leaderboard'), 'hide', @showLdbMarker)
    # else if @app.api.site.get("use_conv_leaderboard")
    #   @$(".leaderboard").append(@addView("leaderboard", new LeaderboardView(collection: @model.get("convprofiles"), type: "conversation")).render().el)
    # else
    #   @$(".leaderboard").append(@addView("leaderboard", new LeaderboardView(collection: @model.get("site").get("profiles"), type: "site")).render().el)

  dispose: ->
    @unbindFrom(@app)
    super

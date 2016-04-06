View = require("views/base_view")
LeaderboardView = require("views/leaderboard_view")
User = require("models/user")
Competition = require("models/competition")

module.exports = class CompetitionAnnounce extends View

  className: 'competitionAnnounce_view'
  template: 'competitionAnnounce'

  initialize: ->
    super
    @FORMAT = "DD/MM/YYYY HH:mm"
    @bindTo(@app.api.site, "change:active_competition change:active_competition.end", @render)
    @bindTo(@app, "server_time_passes", (app, serverTime)=>
      if @_rendered
        @updateTheTime(serverTime)
    )

  updateTheTime: (time)->
    comp = @app.api.site.get("active_competition")
    if !comp
      return

    end = moment.utc(comp.get("end"), @FORMAT)
    remaining = moment.utc().diff(end)

    if remaining > 0
      @$(".competition-announce").remove()
      return

    countdown = moment.duration(-remaining).humanize()
    @$(".countdown").html(countdown)

  render: ->
    super
    comp = @app.api.site.get("active_competition")
    @$el.addClass("display_none")
    if comp and moment.utc(comp.get("end"), @FORMAT) > moment.utc()
      start = moment.utc(comp.get("start"), @FORMAT)
      end = moment.utc(comp.get("end"), @FORMAT)

      start_text = start.local().format("MMMM Do YYYY")
      end_text = end.local().format("MMMM Do YYYY")

      remaining = moment.utc().diff(end)
      countdown = moment.duration(-remaining).humanize()

      banner = @app.translate("competition_banner", {title: comp.get("title"), start: start_text, end: end_text, rules: comp.get("rules_url")})
      header = @app.translate("competition_header", {prize_url: comp.get("prize_url"), prize: comp.get("prize"), start: start_text, end: end_text, community: comp.get("community"), rules: comp.get("rules_url"), countdown: countdown})
      header_sharing = if comp.get("social_share") then @app.translate("competition_header_share") else ""
      if !@app.notifiedCompetition
        @app.notifiedCompetition = true
        @app.trigger("info", {message: banner, translate: false})
      @$el.removeClass("display_none")
      @$(".competition-announce .comp-header").html(header)
      @$(".competition-announce .comp-sharing").html(header_sharing)

  dispose: ->
    @unbindFrom(@app)
    super

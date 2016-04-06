template = require('views/templates/competition_details')
View = require('views/base_view')
CompetitionRankingView = require('views/competition_ranking_view')
SimpleUserView = require('views/simple_user_view')

module.exports = class CompetitionDetails extends View
  className: "competition_details_view"

  template: template

  initialize: ->
    super
    @winner = {first: true}
    @bindTo(@model, "change", @render)
    @bindTo(@model, "error", @render)
    @FORMAT = "DD/MM/YYYY HH:mm"

  beforeRender: ->
    @start_text = moment.utc(@model.get("start"), @FORMAT).local().format(@FORMAT)
    @end_text = moment.utc(@model.get("end"), @FORMAT).local().format(@FORMAT)

    @ended = @model.get("end") < moment.utc().format(@FORMAT)
    if @winner.first && @ended
      @winner.first = false
      if @model.get("profiles").length < 1
        @model.fetchLeaders({
          success: =>
            winner = @model.get("profiles").models[0]
            if winner
              winner.get("user").fetch({
                success: =>
                  @winner = winner
                  @render()
              })
        })
      else
        @winner = @model.get("profiles").models[0]

  render: ->
    if @winner.get
      @$(".competition_winner .winner").replaceWith(@addView("winner", new SimpleUserView(model: @winner.get("user"), points: @winner.get("points"))).render().el)
    @$(".competition_ranking_view").append(@addView("competition_ranking", new CompetitionRankingView(collection: @model.get("profiles"))).render().el)

  activate: ->
    @model.fetch()


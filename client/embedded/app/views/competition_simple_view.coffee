View = require('views/base_view')
SimpleUserView = require('views/simple_user_view')
template = require('views/templates/competition_simple')

module.exports = class CompetitionSimple extends View
  className: "competition_simple_view"

  initialize: ->
    super
    @winner = { first: true }
    @$el.attr("id", "competition-#{@model.id}")
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
              winner.fetch({
                success: =>
                  @winner = winner
                  @render()
              })
        })
      else
        @winner = @model.get("profiles").models[0]

  render: ->
    super
    if @winner.get
      @$(".competition_winner .winner").replaceWith(@addView("winner", new SimpleUserView(model: @winner.get("user"), points: @winner.get("points"))).render().el)
    return @

  template: template


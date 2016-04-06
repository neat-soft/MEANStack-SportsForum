template = require('views/templates/competitions')
View = require('views/base_view')
CollectionView = require("views/collection_view")
CompetitionSimpleView = require("views/competition_simple_view")

module.exports = class Competitions extends View
  className: "competitions_view"

  template: template

  initialize: ->
    super

  render: ->
    @$(".competitions_view").replaceWith(@addView("competitions", new CollectionView(collection: @collection, elementView: CompetitionSimpleView, className: "competitions_view")).render().el)

  events:
    "submit form": "change"

  change: =>
    return false

  activate: ->
    if !@_rendered
      @render()
    @collection.fetch()

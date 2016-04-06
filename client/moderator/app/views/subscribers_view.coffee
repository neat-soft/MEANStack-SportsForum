View = require("views/base_view")
template = require("views/templates/subscribers")
CollectionView = require("views/collection_view")

module.exports = class Subscribers extends View

  className: "subscribers_view"

  initialize: ->
    @bindTo(@model, "change:no_subscribers", (model, count)->
      @$(".no-subscribers").text(count || 0)
    )
    @bindTo(@model, "change:no_subscribers_v", (model, count)->
      @$(".no-subscribers-v").text(count || 0)
    )
    @bindTo(@model, "change:no_subscribers_va", (model, count)->
      @$(".no-subscribers-va").text(count || 0)
    )
    super

  beforeRender: ->
    @siteUrl = @model.url()

  template: template

  activate: ->
    @app.api.fetchSubscrCount()
    @app.api.fetchSubscrCountV()
    @app.api.fetchSubscrCountVA()

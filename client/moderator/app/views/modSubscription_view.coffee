View = require("views/base_view")
template = require("views/templates/modSubscription")

module.exports = class ModSubscription extends View

  template: template

  initialize: ->
    super
    @bindTo(@model, "change:subscribe_comments", @render)

  updateSubscribe: ->
    if @_rendered
      @$("input").prop("checked", @model.get("subscribe_comments"))

  render: ->
    @updateSubscribe()

  events:
    "change input": "subscribe"

  subscribe: ->
    $input = @$("input")
    @app.api.modSubscribe($input.prop("checked"))

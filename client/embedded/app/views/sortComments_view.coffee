template = require('views/templates/sortComments')
View = require('views/base_view')

module.exports = class SortCommentsView extends View
  className: "sortComments_view"
  tagName: "span"

  initialize: ->
    super
    @render()

  render: ->
    if @options.initialValue
      @$("select").val(@options.initialValue)
    @$("select").customSelect(@options.customSelect)

  events:
    "change.customSelect .sort_by": "triggerSort"

  triggerSort: (e)->
    selMethod = $(e.target).children().filter(":selected")
    # $(e.target).trigger('render.customSelect')
    @trigger("sort", selMethod.val())

  setSort: (method)->
    @$("select").val(method)

  template: template

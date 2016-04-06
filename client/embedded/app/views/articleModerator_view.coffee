View = require('views/base_view')

module.exports = class ArticleModerator extends View

  className: 'articleModerator_view moderator-control'
  template: 'articleModerator'
  events:
    'click input.show_in_forum': 'show_in_forum'
    'click input.private': 'private'

  initialize: ->
    super
    @bindTo(@model, 'change:show_in_forum', @render)
    @bindTo(@model, 'change:private', @render)

  beforeRender: ->
    @option_show_in_forum = @app.api.site.get('forum').enabled && @model.get('type') == 'ARTICLE'
    @option_show_private = !!@app.api.site.get('premium')

  render: ->
    @$('.show_in_forum').prop('checked', !!@model.get('show_in_forum'))
    @$('.private').prop('checked', !!@model.get('private'))

  show_in_forum: (e)->
    e.stopPropagation()
    e.preventDefault()
    @model.save(null, {attrs: {show_in_forum: @$('.show_in_forum').prop('checked')}, wait: true, manual: true})

  private: (e)->
    e.stopPropagation()
    e.preventDefault()
    @model.save(null, {attrs: {private: @$('.private').prop('checked')}, wait: true, manual: true})

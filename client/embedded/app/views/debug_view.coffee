View = require('views/base_view')

module.exports = class Debug extends View
  template: 'debug'
  className: 'debug_view'

  events:
    'click #debug_report_height': 'reportHeight'
    'click #debug_render_simple_view': 'renderSimple'
    'click #debug_refresh': 'render'
    "click #debug_render_context": 'renderContext'

  beforeRender: ->
    @visible_views = _.size(@app.visManager?.visible) || 0

  render: ->
    @$el.append(@addView('simple', new View(
      template: '<div class="inside_simple_view">This is just a text</div>'
      templateIsModule: false
    )).render().el)

  reportHeight: ->
    @app.trigger('report_height')

  renderSimple: ->
    @view('simple').render()
    return false

  renderContext: ->
    @app.views.main.render()
    if @app.isArticle()
      @app.views.main.showComments()
    else if @app.isForum()
      @app.views.main.showContexts()

template = require('views/templates/languageSelect')
View = require('views/base_view')

module.exports = class LanguageSelect extends View
  className: "languageSelect_view"

  template: template

  initialize: ->
    super

  beforeRender: ->
    @current_language = @app.current_language
    @languages = (for lid of @app.languages then @app.languages[lid])

  events:
    "click .drop-language-name": "selectLanguage"

  selectLanguage: (e)->
    lid = @$(e.currentTarget).attr("data-language-id")
    @app.set_language_by_id(lid)

    if lid == @app.current_language.id
      @app.save_language(lid)

    @app.views.main.render()
    @app.goUrl()
    return false

  render: ->
    super

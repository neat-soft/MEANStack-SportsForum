View = require('views/base_view')
template = require('views/templates/userImage')

module.exports = class UserImage extends View

  initialize: ->
    super
    @bindTo(@model, "change", @render)

  template: template

View = require('views/base_view')

module.exports = class Attribute extends View

  tagName: "span"
  className: "attribute_view"

  initialize: ->
    if @options.attribute
      @bindTo(@model, "change:" + @options.attribute, @update)
    @update()

  update: (model, value)=>
    @$el.html(@model.get(@options.attribute))

View = require('views/base_view')
CollectionView = require('views/collection_view')

module.exports = class Tag extends View

  className: 'tag_view'
  template: 'tag'

  initialize: ->
    super
    @bindTo(@model, 'change:displayName', (model, name)=>
      if model.isValid()
        @$el.children('.tagname-holder').removeClass('has-error has-feedback')
      else
        @$el.children('.tagname-holder').addClass('has-error has-feedback')
    )

  events: ->
    'click .delete': 'delete'
    'click .add_subtag': 'add_subtag'

  beforeRender: ->
    @canHaveSubTags = @options.level <= 1

  delete: (e)->
    @model.dispose()
    return false

  add_subtag: (e)->
    if @options.level <= 2
      @model.get('subtags').add({})
    return false

  render: ->
    @$el.children('.tagname-holder').find('a').tooltip()
    if @canHaveSubTags
      @$el.children('.subtags').replaceWith(
        @addView('subtags', new CollectionView(
          collection: @model.get('subtags'),
          className: 'subtags',
          elementView: Tag,
          elementViewOptions: {level: @options.level + 1})
        ).render().el
      )

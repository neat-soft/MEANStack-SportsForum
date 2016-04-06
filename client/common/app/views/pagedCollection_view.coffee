CollectionView = require('views/collection_view')
View = require('views/base_view')

module.exports = class PagedCollection extends View

  template: 'pagedCollection'

  initialize: ->
    super
    @options ?= {}
    @options.collection_view_options ?= {}
    @options.collection_view_options.collection ?= @options.collection
    @$el.addClass("HAS_MORE")

  events:
    "click .more": "fetchNextOnMore"

  render: ->
    @$('.collection_view').replaceWith(@addView('collection', new (@options.collection_view || CollectionView)(@options.collection_view_options)).render().el)
    if !@_rendered && @collection.length == 0
      @fetchNextOnMore()

  fetchNextOnMore: ->
    @fetchNext(@options.fetch_options)

  fetchNext: (options)->
    options ?= {}
    _.extend(options, {
      remove: false
      parse: true
      success: (resp)=>
        if @_disposed
          return
        if !@collection.hasMore()
          @$el.removeClass("HAS_MORE")
        @$el.removeClass("LOADING_MORE LOADING")
      error: =>
        if @_disposed
          return
        @$el.removeClass("LOADING_MORE LOADING")
    })
    @collection.fetchNext(options)
    if @_rendered
      @$el.addClass("LOADING_MORE")
    else
      @$el.addClass("LOADING")

  activate: ->
    if !@_rendered
      @render()

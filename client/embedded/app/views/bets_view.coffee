CollectionView = require('views/collection_view')
View = require('views/base_view')
BetView = require('views/bet_view')
analytics = require("lib/analytics")

module.exports = class Bets extends View

  className: 'bets_view'

  initialize: ->
    super
    @appIsArticle = @app.isArticle()
    @$el.addClass("HAS_MORE")
    @bindTo(@app, "change:scroll_offset", @scroll)
    @bindTo(@model, 'change:no_bets_filtered', @update_load_more)
    @moreLimit = 20

  template: 'bets'

  events:
    "click .more": "fetchNextOnMore"
    "click .comments_per_page": "fetchNextOnMore"

  update_load_more: ->
    if @_disposed
      return
    if @model.hasMoreBets()
      @$el.addClass("HAS_MORE")
    else
      @$el.removeClass("HAS_MORE")

  fetchNext: (options)->
    if @moreLimit == "0"
      @autoMore = true
      @moreLimit = 20
    options ?= {}
    _.extend(options, {
      ghost: true
      add: true
      merge: true
      remove: false
      success: (resp)=>
        if @_disposed
          return
        if !@model.hasMoreBets()
          @$el.removeClass("HAS_MORE")
        @$el.removeClass("LOADING_MORE LOADING")
      error: =>
        if @_disposed
          return
        @$el.removeClass("LOADING_MORE LOADING")
    })
    @$el.addClass("HAS_MORE")
    @model.get("bets").fetchNext(options)
    if @_rendered
      @$el.addClass("LOADING_MORE")
    else
      @$el.addClass("LOADING")

  fetchNextOnMore: (e)->
    e.preventDefault()
    @moreLimit = $(e.target).attr("data-value")
    @fetchNext()

  fetchNextOnScroll: (offset)->
    if @$el.hasClass("LOADING_MORE")
      # already fetching
      return
    bottom = offset.top + offset.height
    # TODO: replace hardcoded minimum height of comment: 106
    controls = @$(".control_bar").offset().top - 5 * 106
    if bottom >= controls
      @fetchNext()

  scroll: (offset)->
    if @autoMore && @model.hasMoreBets()
      @fetchNextOnScroll(offset)

  render: ->
    @$('.comments').replaceWith(
      @addView(
        'comments',
        new CollectionView(
          empty: @options.empty || class NoYolosView extends View
            template: 'noYolos'
            className: 'empty_view'
          collection: @model.get('bets'),
          className: 'comments collection_view',
          elementView: BetView,
          elementViewOptions: {mode: 'short', linktofull: true}
        )
      ).render().el
    )

  default_filter: {dir: -1, sort: 'time', status: 'all'}

  filter: (filter)->
    # set default values for the filter
    if _.isEmpty(filter)
      filter = @default_filter
    if filter.dir
      filter.dir = parseInt(filter.dir) || 0
    if !(filter.status in ['all', 'open', 'closed', 'pending', 'resolved'])
      filter.status = 'all'
    prev_filter = @filter_options
    @filter_options = _.extend({}, @default_filter, filter)
    if _.isEqual(@filter_options, prev_filter)
      return
    @update_comments(@filter_options)
    @$('.btn-filter.active').not(".btn-filter.#{filter.status}").removeClass('active')
    @$(".btn-filter.#{filter.status}").addClass('active')
    @$(".btn-bet-filter").text(@app.translate('bet_filter_by', {filter: filter.status}))
    analytics.yoloFilter(filter.status)

  update_comments: (filter)->
    @model.fetchBetCountByFilter(filter)
    @model.get('bets').reset()
    @fetchNext({data: filter, restart: true})

  activate: ->
    if !@_rendered
      @render()

  dispose: ->
    @unbindFrom(@app)
    super

View = require("views/base_view")
template = require("views/templates/allComments")
SortCommentsView = require('views/sortComments_view')
CollectionView = require("views/collection_view")
PromotedView = require("views/promoted_view")
comparators = require('comparators')
analytics = require("lib/analytics")

ConvSubscriptionView = require("views/convSubscription_view")
ContentSubscriptionView = require("views/contentSubscription_view")
sharing = require("../sharing")
comparators = require("comparators")
elementView = require('views/util').userCommentView

promotedView = (options)->
  return new PromotedView(options)

sort_map = {
  timeAsc: "oldest"
  timeDesc: "newest"
  likesDesc: "points"
}

module.exports = class AllComments extends View

  className: "comments_view"

  template: template

  events:
    "click .comments_per_page": "fetchNextOnMore"
    "click .share-fb": "shareFb"
    "click .share-tw": "shareTw"
    "click .dropdown-menu label": "stopPropagation"
    "click .dropdown-menu input": "stopPropagation"

  initialize: ->
    super
    @appIsArticle = @app.isArticle()
    @$el.addClass("HAS_MORE")
    @bindTo(@app, "change:scroll_offset", @scroll)
    @moreLimit = 20

  render: ->
    sorting_method = @model.get("site").get("defCommentSort") || "timeAsc"
    sortComments = @addView("sort", new SortCommentsView(initialValue: sorting_method))
    @bindTo(sortComments, "sort", @sortCommentsChange)
    @$(".sortComments_view").replaceWith(sortComments.render().el)

    # test for demo is temporary.
    # We should not remove all activities, but clear the "activities" collection instead and add a handler
    # to copy elements from "allactivities" to "activities" instead of relying on the graph library
    # if !@_rendered && @app.options.appType != "ARTICLE_DEMO"
    #   @model.removeAllActivities()
      # @fetchNext({data: {sort: "time", dir: 1}, restart: true})
    @$el.children(".promoted_comments_view").replaceWith(@addView("promoted", new CollectionView(collection: @model.get("promoted"), elementView: promotedView, className: "promoted_comments_view", top: @app.options.promotedLimit)).render().el)
    @$el.children(".comments_view").replaceWith(@addView("comments", new CollectionView(
      collection: @model.get("activities"),
      elementView: elementView,
      elementViewOptions: {manage_visibility: @app.visManager?},
      className: "comments_view"
    )).render().el)
    @view("promoted").sort(comparators.promoted, {updateOn: 'change:promotePoints'})
    @bindTo(@view('comments'), 'render_child', (child, after)=>
      @app.visManager?.add(child, after)
    )
    if !@_rendered
      @sortComments(sorting_method)
    if @model.hasMoreActivities()
      @$el.addClass("HAS_MORE")
    else
      @$el.removeClass("HAS_MORE")
    @$(".convSubscription_view").replaceWith(@addView("convSubscription", new ConvSubscriptionView(model: @app.api.user)).render().el)
    @$(".contentSubscription_view").replaceWith(@addView("contentSubscription", new ContentSubscriptionView(model: @app.api.user, context: @model)).render().el)
    @model.get('promoted').fetch({ghost: true})

  stopPropagation: (e) ->
    e.stopPropagation()

  sortCommentsChange: (method)->
    @sortComments(method)
    interaction = sort_map[method]
    if interaction?
      analytics.commentsSort(interaction)

  sortComments: (method)->
    params = {}
    switch method
      when "timeAsc"
        params.sort = "time"
        params.dir = 1
      when "timeDesc"
        params.sort = "time"
        params.dir = -1
      when "likesDesc"
        params.sort = "rating"
        params.dir = -1
      when "commentsDesc"
        params.sort = "comments"
        params.dir = -1
    params.limit = @moreLimit
    if @model.hasMoreActivities()
      @model.removeAllActivities()
      @view("comments").render()
      @fetchNext({data: params, restart: true})

    @view("comments").sort(comparators[method])

  fetchNextOnMore: (e)->
    e.preventDefault()
    @moreLimit = $(e.target).attr("data-value")
    if @moreLimit
      analytics.loadCommentsMore()
    else
      analytics.loadCommentsAll()
    @fetchNext()

  fetchNextOnScroll: (offset)->
    if @$el.hasClass("LOADING_MORE")
      # already fetching
      return
    bottom = offset.top + offset.height
    # TODO: replace hardcoded minimum height of comment: 106
    controls = @$(".control_bar").offset().top - 5 * 106
    if bottom >= controls
      analytics.loadCommentsAuto()
      @fetchNext()

  scroll: (offset)->
    if @autoMore && @model.hasMoreActivities()
      @fetchNextOnScroll(offset)

  fetchNext: (options)->
    if @moreLimit == "0"
      @autoMore = true
      @moreLimit = 20
    options ?= {}
    _.extend(options, {
      remove: false
      merge: true
      success: (resp)=>
        if @_disposed
          return
        for unseen in @model.get('newcomments').toArray()
          @model.get('allactivities').add(unseen)
          parent = unseen.get('_parent')
          if parent
            unseen.set('parent': parent)
        if !@model.hasMoreActivities()
          @$el.removeClass("HAS_MORE")
        @$el.removeClass("LOADING_MORE LOADING")
      error: =>
        if @_disposed
          return
        @$el.removeClass("LOADING_MORE LOADING")
    })
    @model.get("allactivities").fetchNext(options)
    if @_rendered
      @$el.addClass("LOADING_MORE")
    else
      @$el.addClass("LOADING")

  shareFb: (e)->
    e.stopPropagation()
    sharing.fbshareConversation(@model, @app.options.fbAppId, @app.api)
    return false

  shareTw: (e)->
    e.stopPropagation()
    sharing.tweetConversation(@model, @app.api)
    return false

  activate: ->
    if !@_rendered
      @render()
    super

  dispose: ->
    @unbindFrom(@app)
    super

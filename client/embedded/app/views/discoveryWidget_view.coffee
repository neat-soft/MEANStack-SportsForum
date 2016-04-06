View = require('views/base_view')
CollectionView = require("views/collection_view")
ContextPreviewView = require("views/discoveryContextPreview_view")
comparators = require("comparators")

module.exports = class DiscoveryWidget extends View
  className: 'discoveryWidget_view'

  template: 'discoveryWidget'

  initialize: ->
    super
    @app.api.initRtSite()
    @max_topics_count = parseInt(@app.integration.inline_options["forum-entries"] || 3, 10)
    @max_articles_count = parseInt(@app.integration.inline_options["article-entries"] || 3, 10)
    @model.get("contexts").fetch({remove: false, data: {sort: "latest_activity", dir: -1, limit: @max_articles_count, articles_only: true}})
    @model.get("contexts").fetch({remove: false, data: {sort: "latest_activity", dir: -1, limit: @max_topics_count, forums_only: true}})
    @no_threads = 0
    @no_articles = 0

  updateCounts: ->
    @no_threads = @app.views.forum_contexts?.countViews()
    @no_articles = @app.views.article_contexts?.countViews()
    @$(".topics .no_contexts").text(@no_threads)
    @$(".articles .no_contexts").text(@no_articles)
    if @no_articles == 0
      @$el.removeClass("HAS_ARTICLE_DISCOVERY")
    else
      @$el.addClass("HAS_ARTICLE_DISCOVERY")
    if @no_threads == 0
      @$el.removeClass("HAS_FORUM_DISCOVERY")
    else
      @$el.addClass("HAS_FORUM_DISCOVERY")

  beforeRender: ->
    if @app.api.site.get('forum')?.enabled
      @forum_url = @app.api.site.get('forum')?.url
      @show_start_thread = !('FORUM' in @app.integration.widgets_embedded) && @forum_url && (@max_topics_count || @max_articles_count)
      if @forum_url
        @yolos_in_threads = @max_topics_count > 0
        @yolos_in_articles = !@yolos_in_threads && @max_articles_count > 0
        @yolos_separate = !@yolos_in_threads && !@yolos_in_articles
        @yolos_url = @forum_url + '#brzn/yolo/all'
    else
      @max_topics_count = 0
    @unbindEvents()

  render: ->
    if @max_topics_count
      @app.views.forum_contexts = @addView("forum_contexts", new CollectionView(
        collection: @model.get("contexts")
        elementView: ContextPreviewView
        tagName:'div'
        className: 'topics_view'
        top: @max_topics_count
        filter: (context)->
          return context.get("type") == "FORUM"
      ))
      @$(".topics_view").replaceWith(@app.views.forum_contexts.render().el)
      @app.views.forum_contexts.sort(comparators.latestActivityDesc)
      @bindTo(@app.views.forum_contexts, "render_child remove_child", ()=>
        @updateCounts()
      )

    if @max_articles_count
      @app.views.article_contexts = @addView("article_contexts", new CollectionView(
        collection: @model.get("contexts")
        elementView: ContextPreviewView
        tagName:'div'
        className: 'articles_view'
        top: @max_articles_count
        filter: (context)->
          return context.get("type") == "ARTICLE"
      ))
      @$(".articles_view").replaceWith(@app.views.article_contexts.render().el)
      @app.views.article_contexts.sort(comparators.latestActivityDesc)
      @bindTo(@app.views.article_contexts, "render_child remove_child", ()=>
        @updateCounts()
      )

  unbindEvents: ->
    if @app.views.forum_contexts
      @unbindFrom(@app.views.forum_contexts)
    if @app.views.article_contexts
      @unbindFrom(@app.views.article_contexts)

  dispose: ->
    @unbindEvents()
    @app.api.disposeRtSite()
    super

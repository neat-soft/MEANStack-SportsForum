View = require('views/base_view')
ArticleModeratorView = require('views/articleModerator_view')
UserImageView = require('views/userImage_view')
CollectionView = require('views/collection_view')

module.exports = class ContextSummary extends View

  className: 'contextSummary_view'
  template: 'contextSummary'
  tagName: 'tr'

  initialize: ->
    super
    @bindTo(@app, "server_time_passes", (app, serverTime)=>
      if @_rendered
        @updateTimeStamp(serverTime)
    )
    @bindTo(@model, "change:deleted change:initialUrl change:type change:tags", @willRender)
    @bindTo(@model, "change:no_flags change:flagged", @updateFlagged)
    @bindTo(@model, "change:comment change:comment.type", @render)
    @bindTo(@model, "change:no_new_activities", @updateNewActivities)
    @$el.attr("id", "context-#{@model.id}")
    @$el.addClass("cfgstyle")

  events: ->
    "click .flag": "flag"
    "click .share-fb": "shareFb"
    "click .share-tw": "shareTw"
    "click .delete": "delete"
    "click a.thread-link": "go_to_thread"

  go_to_thread: (e)->
    # href is set to the full url of the embedding site + the hash because
    # we want to support right click -> open in new tab
    # As this url would force the browser to reload the page when clicking the anchor,
    # we use only the hash to perform the navigation and prevent the default behavior
    # of using the href.
    e.preventDefault()
    e.stopPropagation()
    href = $(e.target).attr('href')
    @app.goUrl(href.substring(href.indexOf('#')))

  updateNewActivities: =>
    if @model.get("no_new_activities")
      @$el.addClass('HAS_NEW_COMMENTS')
    else
      @$el.removeClass('HAS_NEW_COMMENTS')

  updateFlagged: =>
    if @model.get("flagged")
      @$el.addClass("USER_FLAGGED")
    else
      @$el.removeClass("USER_FLAGGED")
    if @model.get("no_flags") >= @app.options.flagsForApproval
      @$el.addClass("FLAGGED")
    else
      @$el.removeClass("FLAGGED")

  updateTimeStamp: (time)=>
    diff = time - @model.get("latest_activity")
    seconds = diff / 1000
    if seconds < 60
      @$time.text(@app.translate("just_now_short"))
    else if seconds < 3600
      @$time.text(@app.translate("minutes_short", {value: Math.floor(seconds/60)}))
    else if seconds < 86400 # a day
      @$time.text(@app.translate("hours_short", {value: Math.floor(seconds/3600)}))
    else
      @$time.text(@app.translate("days_short", {value: Math.floor(seconds/86400)}))

  beforeRender: ->
    site_tags = @app.api.site.get('forum').tags || []
    tag_with_image = _.find(@model.get('tags'), (t)-> site_tags.set[t]?.imageUrl)
    @image_url = if tag_with_image then site_tags.set[tag_with_image].imageUrl else null
    @question = @model.get('comment')?.get('type') == 'QUESTION'

  render: ->
    @$time = @$(".time")
    if @model.get("deleted")
      @$el.addClass("DELETED")
    @updateTimeStamp(@app.serverTimeCorrected())
    @$('.articleModerator_view').replaceWith(@addView("articlemoderator", new ArticleModeratorView(model: @model)).render().el)
    @$(".commenters").append(
      @addView("commenters", new CollectionView(
        collection: @model.get("topcommenters"),
        classView: "top_commenters",
        elementView: UserImageView,
        elementViewOptions: {tagName: "span"},
        tagName: "span")
      ).render().el
    )
    @model.get("topcommenters").fetch({limit: 3})
    @updateNewActivities()

  flag: ->
    @app.api.flag(@model)
    return false

  shareFb: (e)->
    e.stopPropagation()
    sharing.fbshareConversation(@model, @app.options.fbAppId)
    return false

  shareTw: (e)->
    e.stopPropagation()
    sharing.tweetConversation(@model)
    return false

  delete: ->
    @app.api.deleteContext(@model)
    return false

  dispose: ->
    @unbindFrom(@app)
    super

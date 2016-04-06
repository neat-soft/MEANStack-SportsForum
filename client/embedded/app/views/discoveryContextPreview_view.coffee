View = require('views/base_view')
ArticleModeratorView = require('views/articleModerator_view')
UserImageView = require('views/userImage_view')
CollectionView = require('views/collection_view')
UserImageView = require("views/userImage_view")

module.exports = class ContextPreview extends View

  className: 'discoveryContextPreview_view'
  template: 'discoveryContextPreview'
  tagName: 'div'

  initialize: ->
    super
    @bindTo(@app, "server_time_passes", (app, serverTime)=>
      if @_rendered
        @updateTimeStamp(serverTime)
    )
    @bindTo(@model, "change:deleted change:initialUrl", @willRender)
    @bindTo(@model, "change:comment change:comment.author", @render)
    @bindTo(@model.get("allactivities"), "add", @render)
    @$el.addClass("cfgstyle")
    @model.get("allactivities").fetch({data: {limit: 1}})
    @model.get("comment")?.fetch()

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
    if @model.get("type") == "ARTICLE"
      @absolute_link = @model.get("initialUrl")
    else
      @absolute_link = "#{@app.api.site.get("forum").url}#brzn/contexts/#{@model.id}"

  render: ->
    @$time = @$(".time")
    @updateTimeStamp(@app.serverTimeCorrected())
    if @model.get("comment")
      comment = @model.get("comment")
    else
      comment = @model.get("activities").models[0]
    if comment
      comment.fetch()
      author = comment.get("author")
      if comment.get("ptext")
        # transform user refs
        summary = @app.api.textToHtml(comment.get("ptext"))
        summary = $("<div>#{summary}</div>").text()
      else
        summary = comment.get("text")
      if !summary?
        summary = "..."
      @$(".comment-summary").text("\"#{summary}\"")
      if author?.get?
        author.fetch()
        @$(".topic-author").append(@addView(new UserImageView(model: author)).render().el)

  dispose: ->
    @unbindFrom(@app)
    @unbindFrom(@model)
    @unbindFrom(@model.get("allactivities"))
    super


NewCommentView = require('views/newComment_view')
CollectionView = require("views/collection_view")
AttributeView = require("views/attribute_view")
template = require('views/templates/answer')
BaseCommentView = require('views/baseComment_view')
CommentView = require('views/comment_view')
sharing = require("../sharing")

module.exports = class Answer extends BaseCommentView
  className: "answer_view"

  initialize: ->
    super
    @$el.attr("id", "comment-#{@model.id}")

  beforeRender: ->
    @text_reply = @app.translate("reply")
    @text_title_reply = @app.translate("title_reply_answer")
    @text_comment_in_challenge = @app.translate("comment_in_challenge")
    super

  render: ->
    super
    if @options.mode == 'full'
      BetView = require('views/bet_view')
      @$el.children(".comments_view").replaceWith(@addView("comments", new CollectionView(
        collection: @model.get("comments"),
        elementView: (options)->
          if options.model.get('type') == 'BET'
            return new BetView(options)
          return new CommentView(options)
        elementViewOptions: {manage_visibility: @options.manage_visibility},
        className: "comments_view"
      )).render().el)
      @bindTo(@view('comments'), 'render_child', (child, after)=>
        after ?= this
        @app.visManager?.add(child, after)
      )
    return @

  updateBest: ->
    if @model.get("best")
      @$el.addClass("BEST")
      points = @model.get('parent').get('questionPointsOffered') ? 0
      if points
        @$el.find('.best_marker_text').text(@app.translate('best_answer_with_points', {value: points}))
      else
        @$el.find('.best_marker_text').text(@app.translate('best_answer'))
    else
      @$el.removeClass("BEST")

  template: template

  shareFb: (e)->
    e.stopPropagation()
    sharing.fbshareAnswer(@model, @app.options.fbAppId, @app.api)
    return false

  shareTw: (e)->
    e.stopPropagation()
    sharing.tweetAnswer(@model, @app.api)
    return false

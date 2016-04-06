NewCommentView = require('views/newComment_view')
NewChallengeView = require('views/newChallenge_view')
CollectionView = require("views/collection_view")
AttributeView = require("views/attribute_view")
template = require('views/templates/comment')
BaseCommentView = require('views/baseComment_view')
analytics = require('lib/analytics')

module.exports = class Comment extends BaseCommentView
  className: "comment_view"

  initialize: ->
    super
    @$el.attr("id", "comment-#{@model.id}")

  beforeRender: ->
    @text_reply = @app.translate("reply")
    @text_title_reply = @app.translate("title_reply_comment")
    @text_comment_in_challenge = @app.translate("reply_in_challenge")
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
          return new Comment(options)
        elementViewOptions: {manage_visibility: @options.manage_visibility}
        className: "comments_view"
      )).render().el)
      @bindTo(@view('comments'), 'render_child', (child, after)=>
        after ?= this
        @app.visManager?.add(child, after)
      )
    return @

  template: template

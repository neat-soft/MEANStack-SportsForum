template = require('views/templates/question')
BaseCommentView = require('views/baseComment_view')
CollectionView = require("views/collection_view")
AnswerView = require('views/answer_view')
Comment = require('models/comment')
comparators = require("comparators")
NewCommentView = require('views/newComment_view')
sharing = require("../sharing")

module.exports = class Question extends BaseCommentView
  className: "question_view"

  template: template

  initialize: ->
    super
    @$el.attr("id", "comment-#{@model.id}")
    @bindTo(@model, "change:finished", @updatePointsNote)

  beforeRender: ->
    @text_reply = @app.translate("answer")
    @text_title_reply = @app.translate("title_question_answer")
    @text_comment_in_challenge = @app.translate("comment_in_challenge")
    super

  render: ->
    super
    if @options.mode == 'full'
      @$el.children(".answers_view").replaceWith(@addView("comments", new CollectionView(
        collection: @model.get("comments"),
        elementView: AnswerView,
        elementViewOptions: {manage_visibility: @options.manage_visibility},
        className: "answers_view comments_view"
      )).render().el)
      @bindTo(@view('comments'), 'render_child', (child, after)=>
        after ?= this
        @app.visManager?.add(child, after)
      )
    @updatePointsNote()

  updatePointsNote: ->
    @$pointsNote = @$container.find(".question_points_offered_note")
    if !@model.get("finished") and @model.get("questionPointsOffered")
      @$pointsNote.text(@app.translate("question_view_points_offered", {value: @model.get("questionPointsOffered")}))
    else
      @$pointsNote.text("")


  setupNewComment: ->
    @addView("newComment", new NewCommentView(model: @model, allowQuestion: false, template: require("views/templates/newComment")))

  shareFb: (e)->
    e.stopPropagation()
    sharing.fbshareQuestion(@model, @app.options.fbAppId, @app.api)
    return false

  shareTw: (e)->
    e.stopPropagation()
    sharing.tweetQuestion(@model, @app.api)
    return false

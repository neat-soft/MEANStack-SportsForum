SimpleMajorCommentView = require('views/simpleMajorCommentInChallenge_view')
CommentView = require('views/comment_view')
CollectionView = require("views/collection_view")
NewCommentView = require('views/newComment_view')
Formatter = require("lib/format_comment")
ChallengeView = require('views/challenge_view')
sharing = require("../sharing")
analytics = require('lib/analytics')

module.exports = class SimpleChallenge extends ChallengeView
  className: "challenge_view"

  template: 'simpleChallenge'

  initialize: ->
    super
    @$el.show()

  beforeRender: ->
    super
    @commentLink = "#{@app.options.baseUrl}/go/#{@model.id}"

  render: ->
    @$container = $(@$el.children().first())
    if @deleted
      @$time = @$container.find(".time")
      @updateTimeStamp(@app.serverTimeCorrected())
      @$el.addClass("DELETED")
    else
      if !(@model.get("challenged") instanceof Backbone.Model) || !(@model.get("challenger") instanceof Backbone.Model)
        return
      @$endstime = @$container.find(".ends_time")
      @updateEndTime(@app.serverTimeCorrected())
      @$container.find(".challenged").append(@addView("challenged", new SimpleMajorCommentView(model: @model.get("challenged"), challenged: true, manage_visibility: @options.manage_visibility)).render().el)
      @$container.find(".challenger").append(@addView("challenger", new SimpleMajorCommentView(model: @model.get("challenger"), challenger: true, manage_visibility: @options.manage_visibility)).render().el)
      @updateFlagged()

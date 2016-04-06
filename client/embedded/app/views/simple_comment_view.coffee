NewCommentView = require('views/newComment_view')
NewChallengeView = require('views/newChallenge_view')
CollectionView = require("views/collection_view")
AttributeView = require("views/attribute_view")
template = require('views/templates/comment_simple')
BaseCommentView = require('views/baseComment_view')
analytics = require('lib/analytics')

module.exports = class SimpleComment extends BaseCommentView
  className: "simple_comment_view"

  initialize: ->
    super
    @$el.show()

  beforeRender: ->
    super
    @commentLink = "#{@app.options.baseUrl}/go/#{@model.id}"

  template: template

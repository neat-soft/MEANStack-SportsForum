NewCommentView = require('views/newComment_view')
NewChallengeView = require('views/newChallenge_view')
CollectionView = require("views/collection_view")
AttributeView = require("views/attribute_view")
template = require('views/templates/promoted')
BaseCommentView = require('views/baseComment_view')

module.exports = class Promoted extends BaseCommentView
  className: "promoted_view"

  initialize: ->
    super
    @$el.attr("id", "promoted-#{@model.id}")
    @bindTo(@model, "change:deleted", @deleted)
    @bindTo(@model, "change:promotePoints change:promote change:promoter change:promoter.name", @willRender)

  deleted: ->
    if @model.get('deleted')
      @remove()

  render: ->
    super
    note = @$('.promoted_points_note')
    if @model.get('promotePoints') < @app.options.modPromotePoints
      note.text(@app.translate("promoted_points_note", {value: @model.get('promotePoints')}))
    else
      note.text(@app.translate("promoted_by_moderator_note"))
    promoter_name = @model.get('promoter')?.get?('name')
    if promoter_name
      note.attr('title', @app.translate("title_promoted_points_note_user", {user: promoter_name}))
    else
      note.attr('title', @app.translate("title_promoted_points_note"))
    return @

  setCommentType: ->
    super
    if @model.get("promote")
      @type_promoted = 1

  template: template

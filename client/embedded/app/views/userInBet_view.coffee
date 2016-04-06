View = require('views/base_view')
AttributeView = require('views/attribute_view')
UserImageView = require('views/userImage_view')

module.exports = class UserInBet extends View

  className: 'userInBet_view'
  template: 'userInBet'

  initialize: ->
    super
    @bindTo(@model, 'change', @render)

  render: ->
    @$el.removeClass('STATUS_ACCEPTED STATUS_DECLINED STATUS_PENDING FORFEITED')
    if @model.get('status')
      @$el.addClass(@model.get('status').toUpperCase())
    if @model.get('forfeited')
      @$el.addClass('FORFEITED')
    if @model.get('won')
      @$el.addClass('WON')
    if @model.get("user") instanceof Backbone.Model
      @$(".user_name").append(@addView(new AttributeView(model: @model.get("user"), attribute: "name")).render().el)
      @$(".user_image_container").append(@addView(new UserImageView(model: @model.get("user"), tagName: 'span')).render().el)

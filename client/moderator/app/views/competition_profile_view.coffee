View = require('views/base_view')
template = require("views/templates/competition_profile")
AttributeView = require("views/attribute_view")
UserImageView = require("views/userImage_view")

module.exports = class CompetitionProfile extends View

  className: "competition_profile_view"

  initialize: ->
    super
    @bindTo(@model, "change:user.name", @render)
    @bindTo(@model, "change:user.imageType", @render)

  template: template

  beforeRender: ->
    @user = @model.get("user")

  render: ->
    @$(".author_image_container").append(@addView(new UserImageView(model: @user)).render().el)
    if @model.get("user").get("imageType") == "facebook"
      @$el.addClass("fb_avatar")
    else
      return

  activate: ->
    @model.get("user").fetch()


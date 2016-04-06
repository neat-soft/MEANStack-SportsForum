View = require("views/base_view")
template = require("views/templates/profile")
UserView = require("views/user_view")

module.exports = class Profile extends View

  className: "profile_view"

  initialize: ->
    super
    @bindTo(@model, "change", @render)
    # we presume operations succeed and only re-render on errors
    # this avoids any flickering effects
    @bindTo(@model, "error", @render)

  beforeRender: ->
    @option_private = !!@app.api.site.get('premium')

  render: ->
    @$("select").val(@model.get("approval") ? 0)
    @$(".make_mod").prop("checked", @model.get("permissions").moderator ? false)
    @$(".private_access").prop("checked", @model.get("permissions").private ? false)
    @$(".user_view").replaceWith(@addView("user", new UserView({
      model: @model.get("user")
    })).render().el)
  template: template

  events:
    "change .make_mod": "save"
    "change select": "save"
    "change .private_access": "save"

  save: (e)->
    e.stopPropagation()
    @app.api.saveProfile(@model, {
      approval: @$("select").val()
      permissions: _.extend({}, @model.get("permissions"), {
        moderator: @$(".make_mod").prop("checked"),
        private: @$(".private_access").prop("checked")
      })
    })

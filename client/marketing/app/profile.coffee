module.exports = ()->
  $(->
    require("backbone-setup")
    require("rivets-setup")
    require("template-setup")
    require("lib/shared/underscore_mixin")

    LoginServicesView = require('views/loginServices_view')
    UsersToMergeView = require('views/usersToMerge_view')
    View = require('views/base_view')
    User = require('models/user')
    HttpRequest = require('lib/httprequest')

    class ProfileApp extends View
      initialize: (options)->
        @options = options
        server = new HttpRequest()
        @api = {
          store: Backbone.graphStore
          server: server
          user: new User(Burnzone.user)
        }
      render: ->
        $('#logins').append(@addView(new LoginServicesView(model: @api.user)).render().el)
        $('#merge').append(@addView(new UsersToMergeView(collection: @api.user.get("formerge"))).render().el)

    app = window.app = Burnzone.profileApp = new ProfileApp(_.extend({}, {el: $('body')}, Burnzone.conversaitData))
    app.render()
  )

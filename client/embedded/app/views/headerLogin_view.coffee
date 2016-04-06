template = require('views/templates/headerLogin')
View = require('views/base_view')
LoginsView = require("views/logins_view")
util = require("lib/util")

module.exports = class HeaderLogin extends View
  className: 'headerLogin_view'
  template: template

  render: ->
    @$(".login-overlay").hide()
    @$("[rel=tooltip]").tooltip({trigger: "hover"})
    @$("[data-toggle=popover]").popover({trigger: "focus"})
    @$(".logins_view").replaceWith(@addView("logins", new LoginsView()).render().el)
    return this

  events: ->
    "click .submit": "createUser"
    "click #header-login-link": "showOverlay"
    "click .close-login-overlay": "hideOverlay"
    "clickout .login-overlay": "hideOverlay"
    "click .already_signedup a": "alreadySignedUp"

  showOverlay: (e)->
    overlay = @$(".login-overlay")
    offset = @app.parentPageOffset
    width = $(window).width()
    height = offset.height
    [top, left] = util.centerPosition(overlay.width(), overlay.height(), width, height)
    top += offset.top
    overlay.show()
    overlay.offset({top: top, left: left})
    e?.stopPropagation()
    e?.preventDefault()

  hideOverlay: ->
    @$(".login-overlay").hide()

  createUser: ->
    name = (@$(".anon_name").val() || "").replace(/\s/g, "")
    email = (@$(".anon_email").val() || "").replace(/\s/g, "")
    pass = (@$(".anon_pass").val() || "").replace(/\s/g, "")
    if !@app.api.loggedIn()
      @app.api.createUser({name: name, email: email, pass: pass})

_.extend(HeaderLogin.prototype, require('views/mixins').login)

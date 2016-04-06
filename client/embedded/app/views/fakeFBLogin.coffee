View = require('views/base_view')
template = require("views/templates/fakeFBLogin")

module.exports = class FakeFBLogin extends View

  template: template

  events:
    "submit form": "login"

  login: (e)->
    if @app.login
      text = @$("input").val()
      if text.replace(/\s/g, "")
        attrs = {fbuid: text}
        @app.login(attrs, true)
      return false
    return true
    
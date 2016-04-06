View = require("views/base_view")
template = require("views/templates/logins")
analytics = require("lib/analytics")
util = require("lib/util")

module.exports = class Logins extends View
  className: "logins_view"
  template: template

  events:
    "click a.login-link": "openLogin"

  cleanup: ->
    @popup = null
    clearInterval(@timerVerifier)
    super

  popupVerifier: =>
    if @popup
      if @popup.closed
        @popup = null
        clearInterval(@timerVerifier)
        @app.api.fetchCurrentUser()
    else
      clearInterval(@timerVerifier)

  openLogin: (e)->
    if @popup
      return false
    @trigger('open_login')
    provider = $(e.currentTarget).attr("data-login-provider")
    analytics.chooseLogin(provider)
    @timerVerifier = setInterval(@popupVerifier, 500)
    if provider == 'twitter'
      width = 640
      height = 700
    else if provider == 'facebook'
      width = 550
      height = 300
    else if provider == 'google'
      width = 450
      height = 500
    else if provider == 'own'
      width = 440
      height = 480
    else
      width = 450
      height = 450
    [top, left] = util.centerPosition(width, height)
    windowOptions = 'scrollbars=yes,resizable=yes,toolbar=no,location=yes'
    windowOptions += ',width=' + width + ',height=' + height + ',left=' + left + ',top=' + top
    @popup = window.open($(e.currentTarget).attr("href"), "Conversait_login_popup", windowOptions)
    return false

View = require("views/base_view")
util = require("lib/util")

module.exports = class LoginServices extends View

  template: 'loginServices'

  events:
    'click .connect_account': 'checkLogin'

  initialize: ->
    super
    @bindTo(@model, 'change', @render)

  cleanup: ->
    @popup = null
    clearInterval(@timerVerifier)
    super

  selectImageType: ->
    $('.imagetypeoption').prop('disabled', true)
    $('.imagetypeoption[value=gravatar]').prop('disabled', false)
    for own type, id of @model.get("logins")
      $imgtype = $(".imagetypeoption[value=#{type}]")
      $imgtype.prop('disabled', false)
      if @model.get('imageType') == type
        $imgtype.prop('checked', true)
    if @model.get('imageType') == 'gravatar'
      $('.imagetypeoption[value=gravatar]').prop('checked', true)

  render: ->
    @selectImageType()

  popupVerifier: =>
    if @popup
      if @popup.closed
        @popup = null
        clearInterval(@timerVerifier)
        @model.fetch()
    else
      clearInterval(@timerVerifier)

  checkLogin: (e)->
    provider = $(e.currentTarget).attr("data-login-provider")
    if @model.get("logins")?[provider]
      success = (user)=>
        @selectImageType()
      @model.removeLogin(provider, {success: success})
      return false
    else
      return @openLogin(e)

  openLogin: (e)->
    if @popup
      return false
    @trigger('open_login')
    provider = $(e.currentTarget).attr("data-login-provider")
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
    else
      width = 450
      height = 450
    [top, left] = util.centerPosition(width, height)
    windowOptions = 'scrollbars=yes,resizable=yes,toolbar=no,location=yes'
    windowOptions += ',width=' + width + ',height=' + height + ',left=' + left + ',top=' + top
    @popup = window.open(@app.options.loginUrl + "/#{provider}", "Conversait_login_popup", windowOptions)
    return false

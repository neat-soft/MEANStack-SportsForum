template = require('views/templates/newChallenge')
View = require('views/base_view')
Formatter = require("lib/format_comment")

module.exports = class NewChallenge extends View
  className: "newChallenge_view"

  initialize: ->
    super
    @bindTo(@app.api.user.get("profile"), "change:freeChallengeUsed", @updateChallengeCost)

  cleanup: (dispose)->
    @text = null
    super

  dispose: ->
    @unbindFrom(@app.api.user.get("profile"))
    super

  beforeRender: ->
    @loggedIn = @app.api.loggedIn()

  render: ->
    @text = @$(".opposing_comment")
    @$("[rel=tooltip]").tooltip({trigger: "hover"})
    @$("[data-toggle=popover]").popover({trigger: "focus"})
    Formatter.startCompletion(@$('.xtextarea'), @app)
    @updateChallengeCost()
    @$("[rel=tooltip]").tooltip({trigger: "hover"})
    return @

  updateChallengeCost: ->
    if @app.api.loggedIn() && @app.api.user.get('profile')?.get('freeChallengeUsed')
      @$('.challenge_cost_note').html(@app.translate("challenge_cost_note",{value: @app.options.challengeCost}))
    else
      @$('.challenge_cost_note').html(@app.translate("challenge_free_note"))

  events: ->
    "click .submit": "createChallenge"
    "click .cancel": "cancel"
    "click .login_to_comment": "showLogin"
    "focus .xtextarea.opposing_comment": "focusSubmitControls"
    "blur .xtextarea.opposing_comment": "blurSubmitControls"
    "click .already_signedup a": "alreadySignedUp"

  createChallenge: ->
    @$el.addClass("LOADING")
    @$('.opposing_comment').prop('disabled', true)
    textString = @text.html()
    @app.api.createChallenge(@model, "", textString, null, (err, result)=>
      @$('.opposing_comment').prop('disabled', false)
      @$el.removeClass("LOADING")
      if err
        if err.invalid_text
          @$(".opposing_comment_container").addClass("error")
        else
          @$(".opposing_comment_container").removeClass("error")
      else
        @clear()
        @trigger("ok", this)
    )

  focus: ->
    @text.focus()

  showLogin: (e)->
    @app.views.login.showOverlay()
    e.stopPropagation()

  focusSubmitControls: ->
    @app.trigger("user_is_typing", true)
    @$(".submit_controls").addClass("focused")

  blurSubmitControls: ->
    @app.trigger("user_is_typing", false)
    @$(".submit_controls").removeClass("focused")

  activate: ->
    @$('textarea').placeholder()

  clear: ->
    @text.html('')

  cancel: ->
    @clear()
    @trigger("cancel", this)

  template: template

_.extend(NewChallenge.prototype, require('views/mixins').login)

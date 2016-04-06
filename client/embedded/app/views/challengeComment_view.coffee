template = require('views/templates/challengeComment')
View = require('views/base_view')

module.exports = class ChallengeComment extends View
  className: "challengeComment_view"

  template: template

  initialize: ->
    super
    @hide()

  setModel: (model)->
    @model && @unbindFrom(@model)
    @model = model

  cleanup: ->
    @title = null
    @text = null
    @hide()
    @dialog = null
    super

  render: ->
    @title = @$(".challenge_title")
    @text = @$(".opposing_comment")
    return @

  events:
    "submit": "challenge"
    "click .close": "hide"
    "click .submit": "challenge"

  show: ->
    @render()
    @title.val("")
    @text.val("")
    @dialog = @$(".modal")
    @dialog.modal()
    @$el.show()

  hide: =>
    @dialog?.modal("hide")
    @$el.hide()

  challenge: =>    
    valid = true
    if !@title.val().replace(/\s/g, "")
      @$(".challenge_title_container").addClass("error")
      valid = false
    else
      @$(".challenge_title_container").removeClass("error")
    if !@text.val().replace()
      @$(".opposing_comment_container").addClass("error")
      valid = false
    else
      @$(".opposing_comment_container").removeClass("error")
    if valid
      @app.api.createChallenge(@model, @title.val(), @text.val())
      @hide()

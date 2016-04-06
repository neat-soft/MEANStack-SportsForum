NewCommentView = require('views/newComment_view')
Formatter = require("lib/format_comment")
tagSelectOptionTemplate = require('views/templates/tagSelectOption')

maxForumTitleChars = 100

module.exports = class NewContext extends NewCommentView
  className: "newContext_view"
  template: "newContext"

  initialize: ->
    @events = _.extend({}, NewContext.__super__.events, @events || {})
    @appIsForum = true
    super

  cleanup: (dispose)->
    @$input = null
    @isQuestion = null
    @questionNote = null
    @$tags?[0].selectize.destroy()
    super

  beforeRender: ->
    super
    if @loggedIn
      perm = @app.api.user.get("profile").get("permissions") || {}
      @hasPrivatePermission = perm.admin || perm.moderator || perm.private
    @autoPrivate = @app.api.site.get("forum").auto_private

  render: ->
    @renderControls()
    @$forum_title = @$(".input_forum_title")
    @$tags = @$(".forum_tags_user")
    @$private = @$(".mark_private_checkbox")
    @renderTags()
    @restoreProgress()

  restoreProgress: ->
    in_prog = @app.commentInProgress
    if in_prog && !in_prog.context
      @activate()
      @$forum_title.val(in_prog.title)
      @$input.html(in_prog.text)
      for sel_tag in in_prog.tags
        @$tags[0].selectize.addItem(sel_tag)
      @app.commentInProgress = null
      @focused()
      @focusedTitle()

  renderTags: ->
    @$tags.selectize({
      create: false
      openOnFocus: true
      maxItems: 3
      hideSelected: false
      delimiter: ","
      labelField: "displayName"
      valueField: "displayName"
      plugins: ['remove_button']
      options: @app.api.site.inlineTags()
      sortField: [{field: 'initial_order', direction: 'asc'}]
      searchField: ['search']
      render:
        option: (data, escape)->
          return tagSelectOptionTemplate(data)
    })
    $(@$tags[0].selectize.$dropdown).addClass('CHECK-HEIGHT')

  events:
    "keyup input": "preserveComment"
    "keypress .input_forum_title": "limitTitleLength"
    "focus .input_forum_title": "focusedTitle"

  preserveComment: =>
    @app.commentInProgress = {
      text: @$input.html()
      title: @$forum_title.val()
      tags: @$tags[0].selectize.items
    }

  limitTitleLength: (e)->
    if e.which != 13 && e.which != 8 && @$forum_title.val().length > maxForumTitleChars
      e.preventDefault()
      return false
    @$title_remaining_chars = maxForumTitleChars - @$forum_title.val().length
    @$(".input_forum_title_counter").text(@$title_remaining_chars)
    if @$title_remaining_chars <= 15
      @$(".input_forum_title_counter").addClass("danger")
    else
      @$(".input_forum_title_counter").removeClass("danger")

  createComment: ->
    text = @$input.html() || ""
    forum_title = @$forum_title.val() || ""
    forum_tags = @$tags.val().split(",")
    forum_private = @$private.prop("checked") || false
    question = @options.allowQuestion && @isQuestion.prop("checked")
    @$el.addClass("LOADING")
    @$('.submit').prop('disabled', true)
    @app.api.createContext(text, question, {text: forum_title, tags: forum_tags, private: forum_private}, null, (err, result)=>
      @$el.removeClass("LOADING")
      @$('.submit').prop('disabled', false)
      if !err && !@_disposed
        @clear()
        @trigger("ok", this)
        @app.commentInProgress = null
    )
    return false

  focused: ->
    super
    @$el.hide()
    @$(".newcomment_textarea_container").hide()
    @$el.slideDown(200)

  focusedTitle: ->
    @$('.newcomment_textarea_container').slideDown()

  clear: ->
    super
    @$forum_title.val('')
    @$tags[0].selectize.clear()
    @$tags[0].selectize.refreshOptions(false)
    @$tags[0].selectize.refreshItems()
    @$title_remaining_chars = maxForumTitleChars
    @$(".input_forum_title_counter").text(@$title_remaining_chars)

  cancel: ->
    in_prog = @app.commentInProgress
    if in_prog && !in_prog.context
      @app.commentInProgress = null
    @clear()
    @trigger("cancel", this)
    @$el.slideUp()

  activate: ->
    # pass
    # override activate from base

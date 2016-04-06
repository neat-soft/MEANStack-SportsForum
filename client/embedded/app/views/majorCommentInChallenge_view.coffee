template = require('views/templates/majorCommentInChallenge')
AttributeView = require("views/attribute_view")
CommentProto = require('views/commentProto_view')
Formatter = require("lib/format_comment")
util = require('lib/util')

module.exports = class MajorCommentInChallenge extends CommentProto
  className: "majorCommentInChallenge_view"

  initialize: ->
    @events = _.extend({}, MajorCommentInChallenge.__super__.events, @events || {})
    super
    @bindTo(@model, "change:challenge", @render)

  events:
    "click .vote_up": "voteUp"
    "click .vote_down": "voteDown"
    "click .trusted_marker": "openTrustedHelp"
    "click .badge_marker": "openBadgesHelp"

  template: template

  openTrustedHelp: (e)->
    e.stopPropagation()
    window.open("http://help.theburn-zone.com/customer/portal/articles/1654374-what-is-the-trusted-badge-")

  openBadgesHelp: (e)->
    e.stopPropagation()
    window.open("http://help.theburn-zone.com/customer/portal/articles/1954792-all-badges-links")

  voteUp: (e)->
    @app.api.voteComment(@model, 1)
    return false

  voteDown: (e)->
    @app.api.voteComment(@model, -1)
    return false

  cleanup: ->
    @$el.children().first().expandByHeight("destroy")
    super

  # updateText: ()->
  #   if !@$text
  #     return
  #   if @options.manage_visibility
  #     util.replaceImg(@$text, true)
  #   if @model.get("ptext")
  #     text_str = @app.api.textToHtml(@model.get("ptext"))
  #     if @options.manage_visibility
  #       text_str = util.textReplaceImg(text_str)
  #     @$text.html(text_str)
  #   else
  #     @$text.text(@model.get("text"))
  #   @$text.find("a").attr("target", "_blank")
  #   # replace user mentions with views for user name
  #   Formatter.formatMentionsForDisplay(this, @$text)
  #   Formatter.applyOembed(@$text)
  #   expander = @$el.children().first()
  #   expander.expandByHeight('destroy')
  #   expander.expandByHeight({
  #     expandText: @app.translate("read_more")
  #     collapseText: @app.translate("read_less")
  #     maxHeight: 250
  #   })
  #   @trigger('content_update')

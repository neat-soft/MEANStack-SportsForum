AttributeView = require("views/attribute_view")
CommentProtoView = require('views/commentProto_view')
Formatter = require("lib/format_comment")
util = require('lib/util')

module.exports = class SimpleMajorCommentInChallenge extends CommentProtoView
  className: "simpleMajorCommentInChallenge_view"

  template: 'simpleMajorCommentInChallenge'

  initialize: ->
    @events = _.extend({}, SimpleMajorCommentInChallenge.__super__.events, @events || {})
    super
    @bindTo(@model, "change:challenge", @render)

  events:
    "click .trusted_marker": "openTrustedHelp"
    "click .badge_marker": "openBadgesHelp"

  openTrustedHelp: (e)->
    e.stopPropagation()
    window.open("http://help.theburn-zone.com/customer/portal/articles/1654374-what-is-the-trusted-badge-")

  openBadgesHelp: (e)->
    e.stopPropagation()
    window.open("http://help.theburn-zone.com/customer/portal/articles/1954792-all-badges-links")

  cleanup: ->
    @$el.children().first().expandByHeight("destroy")
    super

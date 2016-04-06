ItemView = require("views/item_view")
template = require("views/templates/bet")
UserView = require("views/user_view")
Formatter = require("lib/format_comment")
CommentView = require('views/comment_view')

module.exports = class Bet extends CommentView

  className: "comment_view"

  template: template

  initialize: ->
    @events = _.extend({}, Bet.__super__.events, @events || {})
    super
    @bindTo(@model, 'change', @render)

  events:
    "click .resolve-joined": "resolveJoined"
    "click .resolve-accepted": "resolveAccepted"
    "click .resolve-tie": "resolveTie"

  resolveJoined: (e)->
    e.preventDefault()
    @app.api.resolveBet(@model, 'joined')

  resolveAccepted: (e)->
    e.preventDefault()
    @app.api.resolveBet(@model, 'accepted')

  resolveTie: (e)->
    e.preventDefault()
    @app.api.resolveBet(@model, 'tie')

  beforeRender: ->
    super
    winning_side = @model.get('bet_winning_side')
    @resolved = winning_side && winning_side != 'undecided'

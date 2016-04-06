View = require("views/base_view")
CollectionView = require("views/collection_view")
CommentView = require("views/comment_view")
ChallengeView = require("views/challenge_view")
BetView = require("views/bet_view")
template = require("views/templates/comments")

elementView = (options)->
  if options.model.get("type") in ["COMMENT", "QUESTION"]
    return new CommentView(options)
  else if options.model.get("type") == 'BET'
    return new BetView(options)
  return new ChallengeView(options)

module.exports = class Comments extends View

  className: "comments_view"

  template: template

  initialize: ->
    super
    @prev = 0

  events:
    # "scroll .comments": "scroll"
    "click .refresh": "refresh"

  scroll: =>
    area = @view("comments").$el
    if area.scrollTop() > @prev
      if area.prop("scrollHeight") - area.scrollTop() - area.height() < 50 && !@disabled
        @fetchNext()
    @prev = area.scrollTop()

  render: ->
    @$(".comments").replaceWith(@addView("comments", new CollectionView(className: "comments", collection: @collection, elementView: elementView)).render().el)
    @view("comments").$el.scroll(@scroll)

  refresh: ->
    @disabled = false
    @view("comments").$el.scrollTop(0)
    @fetchNext({reset: true, silent: false, restart: true})
    return false

  activate: ->
    @refresh()

  fetchNext: (options)->
    @disabled = true
    @$el.addClass("disabled")
    done = =>
      @disabled = false
      @$el.removeClass("disabled")
    _.extend(options ?= {}, {
      data: _.extend({
        moderator: true
        sort: "time"
        dir: -1
      }, @options.filter)
      resetSession: false
      success: done
      error: done
      add: true
      merge: true
      remove: false
    })
    @collection.fetchNext(options)

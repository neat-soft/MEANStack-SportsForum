View = require("views/base_view")
CollectionView = require("views/collection_view")
ChallengeView = require("views/challenge_view")

module.exports = class Challenges extends View

  className: "challenges_view"

  initialize: ->
    super
    @bindTo(@collection, "destroy change:approved", =>
      @update()
    )

  render: ->
    @$el.append(@addView("challenges", new CollectionView(collection: @collection, elementView: ChallengeView)).render().el)

  activate: ->
    @update()
    
  update: ->
    @disabled = true
    @$el.addClass("disabled")
    success = =>
      @disabled = false
      @$el.removeClass("disabled")
    @collection.fetch({data: {moderator: true}, success: success, remove: true, merge: true}, (err)=>
      @disabled = false
      @$el.removeClass("disabled")
    )

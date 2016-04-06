View = require('views/base_view')
CollectionView = require('views/collection_view')
UserLeaderView = require('views/userLeader_view')
PagedCollection = require("collections/paged_collection")
template = require("views/templates/badge_leaderboard")

module.exports = class BadgeLeaderboard extends View

  className: 'badgeLeaderboard_view'

  template: template

  initialize: (options)->
    super
    @badge = @app.api.site.get("badges")[options.id]
    @setupCollection()

  setupCollection: ->
    @collection = new PagedCollection()
    @collection.fetch({url: "/api/sites/#{@app.api.site.get("name")}/badges/#{@badge.badge_id}/leaders"})

  cleanup: ->
    super

  render: ->
    if !@collection
      return
    badge = @addView("badge", new CollectionView({
      collection: @collection,
      elementView: UserLeaderView,
      elementViewOptions:
        badge: @badge
      copy: true,
      top: 10,
      filter: (profile)=>
        return true
      reconsiderOn: "change:user.verified"
    }))
    @$(".users_view").replaceWith(badge.render().el)
    @$("h5").html(@title)

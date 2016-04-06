View = require('views/base_view')
CollectionView = require('views/collection_view')
CompetitionProfileView = require('views/competition_profile_view')
template = require("views/templates/competition_ranking")
comparators = require("comparators")

module.exports = class CompetitionRanking extends View

  template: template

  initialize: ->
    super

  render: ->
    users = @addView("users", new CollectionView({
      collection: @collection,
      elementView: CompetitionProfileView,
      copy: true,
      top: 10,
      filter: (profile)->
        profile.get("user").fetch()
        perms = profile.get("permissions")
        points = profile.get("points")
        if !perms || !points || points <= 0
          return false
        return !(perms.admin || perms.moderator)
    }))
    users.sort(comparators.pointsDesc, {updateOn: "change:points"})
    @$(".competition_profiles_view").replaceWith(users.render().el)

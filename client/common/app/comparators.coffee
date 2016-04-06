cmp = require('lib/shared/util').cmp

module.exports =

  timeAsc: (model)->
    return model.get("order_time")

  timeDesc: (model)->
    return _.map(model.get("order_time").split(""), (c)->
      return 9 - parseInt(c)
    ).join("")

  timeCreatedAsc: (model)->
    return model.get("created")

  timeCreatedDesc: (model)->
    return -module.exports.timeCreatedAsc(model)

  likesAsc: (model)->
    return model.get("rating") || 0

  likesDesc: (model)->
    return -module.exports.likesAsc(model)

  votesDesc: (model)->
    return -model.get("rating") || 0

  commentsDesc: (model)->
    return -model.get("no_comments")

  activitiesDesc: (model)->
    return -model.get("no_all_activities")

  activitiesAsc: (model)->
    return -module.exports.activitiesDesc(model)

  usersCollection: (model)->
    return -model.get("profile")?.get("points")

  profilePointsDesc: (model)->
    return -model.get("profile")?.get("points") || 0

  pointsDesc: (model)->
    return -model.get("points") || 0

  rankAsc: (model)->
    return model?.get("rank") || 1000

  latestActivityDesc: (model)->
    return -model.get("latest_activity") || 0

  latestActivityAsc: (model)->
    return -module.exports.latestActivityDesc(model)

  activityRatingDesc: (a, b)->
    return module.exports.activityRatingAsc(b, a)

  activityRatingAsc: (a, b)->
    return cmp(a.get('activity_rating'), b.get('activity_rating')) || cmp(a.get('latest_activity'), b.get('latest_activity')) || cmp(a.id, b.id)

  objectidAsc: (a, b)->
    if a.id < b.id
      return -1
    if a.id > b.id
      return 1
    return 0

  objectidDesc: (a, b)->
    return -module.exports.objectidAsc(a, b)

  promoted: (model)->
    return -model.get('promotePoints')

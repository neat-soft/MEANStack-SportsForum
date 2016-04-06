PagedCollection = require("collections/paged_collection")
UserNotification = require("models/userNotification")

module.exports = class CompetitionProfile extends Backbone.GraphModel

  defaults:
    points: 0

  initialize: ->
    super

  relations: [
    {
      key: "user"
      type: {provider: -> require("models/user")}
      autoCreate: true
      events: true
    },
    {
      key: "competition"
      type: {provider: -> require("models/competition")}
      autoCreate: true
      reverseKey: "profiles"
    }
  ]

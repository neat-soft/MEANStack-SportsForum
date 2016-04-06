PagedCollection = require("collections/paged_collection")
UserNotification = require("models/userNotification")

module.exports = class ConvProfile extends Backbone.GraphModel

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
      key: "context"
      type: {provider: -> require("models/context")}
      autoCreate: true
      reverseKey: "convprofiles"
    }
  ]

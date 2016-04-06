PagedCollection = require("collections/paged_collection")

module.exports = class BadgeProfile extends Backbone.GraphModel

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
    }
  ]


comparators = require("comparators")
User = require("models/user")

module.exports = class Users extends Backbone.GraphCollection

  comparator: comparators.profilePointsDesc

  model: User
  
  initialize: ->
    @on('change:profile change:profile.points', =>
      @sort()
    , this)
    
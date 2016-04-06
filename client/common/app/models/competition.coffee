PagedCollection = require("collections/paged_collection")

module.exports = class Competition extends Backbone.GraphModel

  initialize: ->
    super

  urlRoot: ->
    return "/api/sites/#{@get("siteName")}/competitions"

  relations: [
    {
      key: "profiles"
      type: {ctor: class CompetitionProfiles extends PagedCollection
        model: require("models/competition_profile")
        url: ->
          @container.url() + "/profiles"
      }
      reverseKey: "competition"
    }
  ]

  fetchLeaders: (options)->
    options ?= {}
    @get("profiles").fetch(_.extend({}, options, {url: @url() + "/leaders"}))


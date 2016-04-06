PagedCollection = require("collections/paged_collection")
UserNotification = require("models/userNotification")

module.exports = class Profile extends Backbone.GraphModel

  defaults:
    siteName: ""
    points: 0

  initialize: ->
    super
    if @get("user")?.id? and @get("siteName")?
      @get("badges").fetch()
    @on("change:siteName", ->
      @set(site: @get("siteName"))
    , this)

  url: ->
    return "/api/sites/#{@get("siteName")}/profiles/#{@get("user").id}"

  isNew: ->
    return super && !@get("user").id

  relations: [
    {
      key: "user"
      type: {provider: -> require("models/user")}
      autoCreate: true
      reverseKey: "profile"
      events: true
      serialize: true
    },
    {
      key: "site"
      type: {provider: -> require("models/site")}
      autoCreate: true
      reverseKey: "profiles"
    },
    {
      key: "badges"
      type: {ctor: class Badges extends PagedCollection
        model: require("models/badge")
        url: ->
          @container.url() + "/badges"
      }
    }
  ]

  buyGold: (token)->
    @save(null, {
      wait: true,
      url: @url() + "/gold"
      data: token
      processData: true
    })

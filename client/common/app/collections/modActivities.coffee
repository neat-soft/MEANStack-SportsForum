Comment = require("models/comment")
Challenge = require("models/challenge")
PagedCollection = require("collections/paged_collection")

module.exports = class Activites extends PagedCollection
  model: (attrs, options)->
    if attrs.type == "CHALLENGE"
      return new Challenge(attrs, options)
    else
      return new Comment(attrs, options)
  url: ->
    @container.url() + "/activities"

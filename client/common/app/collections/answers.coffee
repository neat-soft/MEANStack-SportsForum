comparators = require("comparators")
PagedCollection = require("collections/paged_collection")

module.exports = class Answers extends PagedCollection

  comparator: comparators.likesDesc

  model: require("models/comment")

  url: ->
    "/api/sites/#{@container.get("siteName")}/activities/#{@container.id}/comments"

  initialize: ->
    @on('change:no_likes', @sort, this)

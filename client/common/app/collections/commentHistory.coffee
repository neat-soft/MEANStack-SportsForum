PagedCollection = require("collections/paged_collection")
comparators = require("comparators")

module.exports = class CommentHistory extends PagedCollection
  model: require("models/comment")

  url: ->
    return "/api/sites/#{@container.get("profile").get("siteName")}/history/#{@container.id}"

  comparator: comparators.objectidDesc

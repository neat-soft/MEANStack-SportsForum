PagedCollection = require("collections/paged_collection")
UserNotification = require("models/userNotification")
comparators = require("comparators")

module.exports = class UserNotifications extends PagedCollection

  model: UserNotification

  url: ->
    return "/api/users/#{@container.id}/notifications"

  comparator: comparators.objectidDesc

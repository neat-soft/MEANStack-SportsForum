collections = require("../../datastore").collections

module.exports = class ScheduleBadges

  run: (done)->
    collections.jobs.add({type: "UPDATE_BADGES"}, (err)->
      done?(err)
    )

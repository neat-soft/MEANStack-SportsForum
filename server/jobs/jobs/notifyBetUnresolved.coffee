collections = require("../../datastore").collections

module.exports = class NotifyBetUnresolved

  run: (done)->
    collections.jobs.add({type: "NOTIFY_BET_UNRESOLVED"}, (err)->
      done?(err)
    )

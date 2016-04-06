collections = require("../../datastore").collections

module.exports = class BetRemindForfeit

  run: (done)->
    collections.jobs.add({type: "BET_REMIND_FORFEIT"}, (err)->
      done?(err)
    )

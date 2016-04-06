collections = require("../../datastore").collections

module.exports = class StartForfBets

  run: (done)->
    collections.jobs.add({type: "START_FORF_BETS"}, (err)->
      done?(err)
    )

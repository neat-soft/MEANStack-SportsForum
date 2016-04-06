collections = require("../../datastore").collections

module.exports = class EndForfBets

  run: (done)->
    collections.jobs.add({type: "END_FORF_BETS"}, (err)->
      done?(err)
    )

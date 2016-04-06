collections = require("../../datastore").collections

module.exports = class EndBets

  run: (done)->
    collections.jobs.add({type: "END_BETS"}, (err)->
      done?(err)
    )

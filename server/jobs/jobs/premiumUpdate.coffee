collections = require("../../datastore").collections

module.exports = class PremiumUpdate

  run: (done)->
    collections.jobs.add({type: "UPDATE_PREMIUM_SUBSCRIPTION"}, (err)->
      done?(err)
    )


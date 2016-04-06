collections = require("../../datastore").collections

module.exports = class TrustedBadge

  run: (done)->
    collections.jobs.add({type: "UPDATE_TRUSTED_BADGE"}, (err)->
      done?(err)
    )

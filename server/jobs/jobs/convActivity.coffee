collections = require("../../datastore").collections

module.exports = class ConvActivity

  run: (done)->
    collections.jobs.add({type: "MARK_CONV_ACTIVITY"}, (err)->
      done?(err)
    )

collections = require("../../datastore").collections
db = require("../../datastore").db
async = require("async")
debug = require("debug")("worker:like_status")
dbutil = require("../../datastore/util")
util = require("../../util")
moment = require("moment")

module.exports = class LikeStatus

  constructor: (options)->
    @options = options
    @ctlHandle = options.ctlHandle

  run: (done)=>
    if @running
      debug("Already started")
      return
    @running = true
    debug("START")
    today = moment().startOf("day")
    yesterday = moment(today).subtract("days", 1).toDate()
    colname = "like_status_" + today.format("YYYY_MM_DD")
    dbname = null
    today = today.toDate()
    collections.jobs.add(
      {type: "LIKE_STATUS", uid: colname, start: yesterday, end: today},
      (err)=>
        @running = false
        debug("STOP")
        done?(err)
    )

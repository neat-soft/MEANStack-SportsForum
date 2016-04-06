collections = require("../../datastore").collections
debug = require("debug")("worker:rollup")
moment = require("moment")
async = require("async")

TIME_FORMAT = "YYYY-MM-DD HH:mm:ss ZZ"

get_prev_time = ()->
  return moment().utc().startOf("day").subtract("days", 1)

get_this_time = ()->
  return moment.utc().startOf("day")

module.exports = class Rollups

  constructor: (options)->
    @options = options
    @ctlHandle = options.ctlHandle

  run: (done)=>
    if @running
      debug("Already started")
      return
    @running = true
    debug("START")

    prev_time = get_prev_time()
    this_time = get_this_time()

    async.parallel([
      (cb)->
        collections.jobs.add({
          type: "ROLLUP_PAGE_VIEWS",
          start_time: prev_time.toDate(),
          end_time: this_time.toDate()
        }, cb)
      (cb)->
        collections.jobs.add({
          type: "ROLLUP_COMMENTS",
          start_time: prev_time.toDate(),
          end_time: this_time.toDate()
        }, cb)
      (cb)->
        collections.jobs.add({
          type: "ROLLUP_CONVERSATIONS",
          start_time: prev_time.toDate(),
          end_time: this_time.toDate()
        }, cb)
      (cb)->
        collections.jobs.add({
          type: "ROLLUP_PROFILES",
          start_time: prev_time.toDate(),
          end_time: this_time.toDate()
        }, cb)
      (cb)->
        collections.jobs.add({
          type: "ROLLUP_VERIFIED",
          start_time: prev_time.toDate(),
          end_time: this_time.toDate()
        }, cb)
      (cb)->
        collections.jobs.add({
          type: "ROLLUP_SUBSCRIPTIONS",
          start_time: prev_time.toDate(),
          end_time: this_time.toDate()
        }, cb)
      (cb)->
        collections.jobs.add({
          type: "ROLLUP_NOTIFICATIONS",
          start_time: prev_time.toDate(),
          end_time: this_time.toDate()
        }, cb)
    ], (err)=>
      @running = false
      debug("STOP")
      done?(err)
    )


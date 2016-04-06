collections = require("../../datastore").collections
async = require("async")
moment = require("moment")
debug = require("debug")("worker:notif_competitions")
logger = require("../../logging").logger

module.exports = class NotifyCompetitions

  constructor: (options)->
    @options = options
    @ctlHandle = options.ctlHandle

  notify_competition: (c, for_start, cb)=>
    if !c
      return cb(null, null)

    type = "NOTIFY_#{if for_start then "START" else "END"}_COMPETITION"
    debug("adding job #{type} for #{JSON.stringify(c)}")
    collections.jobs.add({type: type, competition: c, uid: "#{type}_#{c._id.toHexString()}_#{@now.format("YYYY-MM-DD-HH-mm")}"}, (err, job)=>
      cb(err, c)
    )

  find_competition: (q, set, cb)=>
    for_start = q.start != null
    debug("find by query #{JSON.stringify(q)} and set #{JSON.stringify(set)}")
    collections.competitions.findAndModify(q, [], {$set: set}, {new: true}, cb)

  do_competition_start: (cb)=>
    debug("check for STARTED competitions")
    q = {start: {$lte: @now.toDate()}, notified_start: null}
    set = {notified_start: @now.toDate()}
    @find_competition(q, set, (err, c)=>
      if err
        cb(err, null)
        return
      @notify_competition(c, true, cb)
    )

  do_competition_start_pending: (cb)=>
    debug("check for PENDING START competitions")
    nextPending = moment(@now).add("days", 1)
    lookAhead = moment(@now).add("days", @options.config.competitions_notif_start_in_days)
    q = {start: {$gt: @now.toDate(), $lte: lookAhead.toDate()}, $or: [{notified_pending_start: null}, {notified_pending_start: {$lt: @now.toDate()}}] }
    set = {notified_pending_start: nextPending.toDate()}
    @find_competition(q, set, (err, c)=>
      if err
        cb(err, null)
        return
      @notify_competition(c, true, cb)
    )

  do_competition_end: (cb)=>
    debug("check for ENDED competitions")
    q = {end: {$lt: @now.toDate()}, notified_end: null}
    set = {notified_end: @now.toDate()}
    @find_competition(q, set, (err, c)=>
      if err
        cb(err, null)
        return
      @notify_competition(c, false, cb)
    )

  do_competition_end_pending: (cb)=>
    debug("check for PENDING END end competitions")
    nextPending = moment(@now).add("days", 1)
    lookAhead = moment(@now).add("days", @options.config.competitions_notif_end_in_days)
    q = {end: {$gt: @now.toDate(), $lte: lookAhead.toDate()}, $or: [{notified_pending_end: null}, {notified_pending_end: {$lt: @now.toDate()}}] }
    set = {notified_pending_end: nextPending.toDate()}
    @find_competition(q, set, (err, c)=>
      if err
        cb(err, null)
        return
      @notify_competition(c, false, cb)
    )

  run: (done)=>
    if @running
      debug("Already started")
      return
    @running = true
    debug("START")
    tasks = [
      @do_competition_start,
      @do_competition_start_pending,
      @do_competition_end,
      @do_competition_end_pending
    ]

    check_competititon = =>
      if tasks.length == 0 || @ctlHandle.stop
        @running = false
        debug("STOP")
        if !@ctlHandle.stop
          done?()
        return

      @now = moment.utc()
      tasks[0]((err, item)=>
        if err
          logger.error(err)
        if !item
          tasks.shift()
        process.nextTick(check_competititon)
      )

    check_competititon()


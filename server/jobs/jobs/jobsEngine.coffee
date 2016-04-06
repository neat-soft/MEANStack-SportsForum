mongo = require("mongodb")
dbutil = require("../../datastore/util")
collections = require("../../datastore").collections
debug = require("debug")("worker:jobs_engine")
util = require("util")
moment = require("moment")
EventEmitter = require("events").EventEmitter

initialId = new mongo.ObjectID("000000000000000000000000")

module.exports = class JobsEngine extends EventEmitter

  constructor: (options) ->
    @options = options
    @maxJobs = options.maxJobs || 2
    @jobs = 0
    @subscribers = {}
    @stopping = false

  stop: ->
    if !@stopping
      @stopping = true
      debug("#jobs = %d", @jobs)
      if @jobs == 0
        @emit("stop")

  cleanup: (job, callback)->
    collections.jobs.update({_id: job._id}, {$set: {finished: true, locked: false, time: new Date()}}, (err, result)->
      if err
        @emit("error", err)
      callback()
    )

  unlock: (job, status, callback)->
    if _.isFunction(status)
      callback = status
      status = {}
    status ?= {}
    status = _.extend({}, status, {locked: false, time: new Date()})
    collections.jobs.findAndModify({_id: job._id, locked: true}, [], {$set: status}, (err, job)->
      # it will just remain in the db if there is an error
      if err
        @emit("error", err)
      callback()
    )

  update: (job, status, callback)->
    if _.isFunction(status)
      callback = status
      status = {}
    status ?= {}
    status = _.extend({}, status, {time: new Date()})
    collections.jobs.update({_id: job._id}, {$set: status}, (err, job)=>
      if err
        @emit("error", err)
      callback()
    )

  run: =>

    afterJob = =>
      @jobs--
      debug("#jobs = %d", @jobs)
      if @stopping && @jobs == 0
        return @emit("stop")
      if !@stopping
        check()
        if @jobs < @maxJobs
          check()

    check = =>
      if @stopping
        debug("Canceling check -> received STOP")
        return
      # Consider that we work on a job as soon as we fetch it. Will decrement this number immediately
      # if there was no job
      @jobs++
      debug("#jobs = %d", @jobs)
      collections.jobs.findAndModify({locked: false, finished: false, _id: {$gt: from}, $or: [{start_after: {$exists: false}}, {start_after: {$lt: moment.utc().toDate()}}]}, [], {$set: {locked: true}}, {new: true}, (err, job)=>
        if err
          @emit("error", err)
          @jobs--
          if @stopping && @jobs == 0
            @emit("stop")
          return
        if job
          from = job._id
          if @stopping
            return @unlock(job, afterJob)
          debug("Found job %j, #jobs = %d", util.inspect(job), @jobs)
          @process(job, (err, result)=>
            if err
              @emit("error", err)
              error =
                message: err.message || err
                stack: err.stack || ""
              if result?.retry
                debug("Unlocking %j", util.inspect(job))
                @unlock(job, {error: error}, afterJob)
              else
                @update(job, {error: error}, afterJob)
            else if !(result?.keep)
              debug("Cleaning up %j", util.inspect(job))
              @cleanup(job, afterJob)
            else
              afterJob()
          )
        else
          debug("No jobs found")
          @jobs--
          debug("#jobs = %d", @jobs)
          if @stopping && @jobs == 0
            return @emit("stop")
      )

    if @jobs >= @maxJobs
      debug("Canceling start -> already full")
      return
    debug("Starting")
    from = initialId
    check()

  process: (job, callback)->
    if @subscribers[job.type]
      debug("Forwarding %s to subscriber", job.type)
      @subscribers[job.type](job, callback)
    else
      process.nextTick(-> callback({no_subscriber: true}, {keep: true}))

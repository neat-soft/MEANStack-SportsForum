collections = require("../../datastore").collections
async = require("async")
debug = require("debug")("worker:end_challenges")
dbutil = require("../../datastore/util")
logger = require("../../logging").logger

module.exports = class EndChallenges

  constructor: (options)->
    @options = options
    @ctlHandle = options.ctlHandle

  run: (done)=>
    if @running
      debug("Already started")
      return
    @running = true
    debug("START")
    check = =>
      if @ctlHandle.stop
        @running = false
        debug("STOP")
        return
      async.waterfall([
        (cb)=>
          timeForEnding = new Date().getTime()
          collections.comments.findAndModify({type: "CHALLENGE", ends_on: {$lte: timeForEnding}, approved: true, deleted: {$ne: true}, locked_finish: false, finished: false}, [], {$set: {locked_finish: true}}, {new: true}, cb)
        (challenge, info, cb)=>
          if !challenge
            debug("No challenge to end found")
            @running = false
            debug("STOP")
            done?()
            return
          if @ctlHandle.stop
            @running = false
            debug("STOP")
            return
          debug("Found challenge to end")
          collections.comments.endChallenge(challenge, cb)
      ], (err, challenge)->
        if err
          logger.error(err)
        debug("Ended challenge")
        collections.comments.update({_id: challenge._id}, {$set: {locked_finish: false, finished: true, ended_on: new Date().getTime()}}, (error)->
          process.nextTick(check)
        )
      )
    check()

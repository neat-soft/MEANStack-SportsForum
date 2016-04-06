collections = require("../../datastore").collections
async = require("async")
debug = require("debug")("worker:notif_end_challenge")
dbutil = require("../../datastore/util")
logger = require("../../logging").logger
urls = require("../../interaction/urls")

module.exports = class NotifyEndChallenges

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
          timeForEnding = new Date().getTime() + @options.config.challenge_notif_end_before
          collections.comments.findAndModify({type: "CHALLENGE", ends_on: {$lte: timeForEnding}, approved: true, deleted: {$ne: true}, locked_finish: false, finished: false, locked_nfinish: false, notified_end: false}, [], {$set: {locked_nfinish: true}}, {new: true}, cb)
        (challenge, info, cb)=>
          if !challenge
            debug("No challenge to notify end found")
            @running = false
            debug("STOP")
            done?()
            return
          if @ctlHandle.stop
            @running = false
            debug("STOP")
            return
          debug("Found challenge to notify end")
          collections.jobs.add({
            type: "NOTIFY_END_CHALLENGE",
            challenge: challenge,
            url: urls.for_model("comment", challenge),
            uid: "NOTIFY_END_CHALLENGE_#{challenge._id.toHexString()}"
          }, cb)
      ], (err, challenge)->
        if err
          logger.error(err)
        debug("Will send notification to participants")
        collections.comments.update({_id: challenge._id}, {$set: {locked_nfinish: false, notified_end: true}}, (error)->
          process.nextTick(check)
        )
      )
    check()

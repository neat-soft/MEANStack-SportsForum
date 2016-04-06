collections = require("../../datastore").collections
async = require("async")
debug = require("debug")("worker:end_questions")
dbutil = require("../../datastore/util")
logger = require("../../logging").logger

module.exports = class EndQuestions

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
          collections.comments.findAndModify({type: "QUESTION", ends_on: {$lte: timeForEnding}, type: "QUESTION", approved: true, deleted: {$ne: true}, locked_finish: false, finished: false}, [], {$set: {locked_finish: true}}, {new: true}, cb)
        (question, info, cb)=>
          if !question
            debug("No question to end found")
            @running = false
            debug("STOP")
            done?()
            return
          if @ctlHandle.stop
            @running = false
            debug("STOP")
            return
          debug("Found question to end")
          collections.comments.endQuestion(question, cb)
      ], (err, answer, question)->
        if err
          logger.error(err)
        debug("Ended question")
        collections.comments.update({_id: question._id}, {$set: {locked_finish: false, finished: true}}, (error)->
          process.nextTick(check)
        )
      )
    check()

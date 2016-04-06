nodemailer = require("nodemailer")
fs = require("fs")
jlog = require("./jlog").log

module.exports.Console = ->
  return {
    write: (item, callback)->
      console.log(JSON.stringify(item))
      callback && process.nextTick(callback)
  }

module.exports.ConsoleMarker = ->
  return {
    write: (item, callback)->
      jlog(item)
      callback && process.nextTick(callback)
  }

module.exports.Mongo = (options)->
  options ?= {}
  db = options.db
  collection = options.collection
  return {
    write: (item, callback)->
      try
        if callback
          db.collection(collection, {safe: false, w: -1}).insert(item, {w: 1}, callback)
        else
          db.collection(collection, {safe: false, w: -1}).insert(item, {w: -1})
      catch error
        # This means we can't log
        console.error("Could not write log to database ", error)
  }

module.exports.Smtp = (options)->
  options ?= {}
  if !options.to
    throw new Error("Missing destination address")
  if options.transport instanceof nodemailer.Transport
    transport = @options.transport
  else
    transport = nodemailer.createTransport(options.transport.type, options.transport.options)  
  return {
    write: (item, callback)->
      try
        transport.sendMail(_.extend({}, to: options.to, subject: options.subject, {text: JSON.stringify(item, null, 2)}), (err, response)->
          if err
            console.error(err)
          callback && callback(err)
        )
      catch error
        # This means we can't log
        console.error(error)

    close: ->
      transport?.close()
  }

module.exports.JobMail = (options)->
  jobs = options.jobs
  return {
    write: (item, callback)->
      jobs.add(item, callback)
  }

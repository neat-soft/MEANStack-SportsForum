async = require("async")
util = require("../util")
dbutil = require("./util")

collections = require("./index").collections

module.exports.fetchAll = fetchAll = (conv, sinceComments, sinceChallenges, sinceContext, stream)->
  
  async.series([
    (cb)->
      collections.comments.changes(conv, sinceComments, util.wrapError(cb, (cursor)->
        stream.write("{\"comments\":")
        dbutil.streamResults(cursor, stream, collections.comments.toClient, cb)
      ))
    ,
    (cb)->
      collections.conversations.changes(conv, sinceContext, util.wrapError(cb, (cursor)->
        stream.write(",\"contexts\":")
        dbutil.streamResults(cursor, stream, collections.conversations.toClient, cb)
      ))
  ], (err, results)->
    if err
      stream.write(",error: true")
    stream.end(",\"time\": #{new Date().getTime()}}")
  )
  
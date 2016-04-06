BaseCol = require("./base")
collections = require("./index").collections
dbutil = require("./util")
logger = require("../logging").logger

resultcb = (callback)->
  return (err, result)->
    if err
      if dbutil.errDuplicateKey(err)
        return callback()
      else
        logger.error(err)
        return callback(err)
    callback(err, result)

module.exports = class Jobs extends BaseCol

  name: "jobs"

  addEmail: (data, callback)->
    data.type = "EMAIL"
    _.defaults(data, {can_reply: false, can_moderate: false})
    @add(data, callback)

  add: (data, callback)->
    if data.type == "EMAIL"
      _.defaults(data, {can_reply: false, can_moderate: false})
    collections.jobs.insert(_.extend({locked: false, finished: false}, data), resultcb(callback))

  addUnique: (query, toSet, callback)->
    if toSet.type == "EMAIL"
      _.defaults(toSet, {can_reply: false, can_moderate: false})
    collections.jobs.findAndModify(_.extend({locked: false, finished: false}, query),
      [],
      {$set: _.extend({}, toSet, {locked: false})},
      {upsert: true, new: true},
      resultcb(callback)
    )

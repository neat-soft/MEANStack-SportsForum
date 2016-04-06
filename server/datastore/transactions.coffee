BaseCol = require("./base")
util = require("../util")
mongo = require("mongodb")
async = require("async")
dbutil = require("./util")
debug = require("debug")("data:profiles")

collections = require("./index").collections

module.exports = class Transactions extends BaseCol

  name: "transactions"

  # A transaction has the following fields
  # - type: string specifying the transaction kind: LIKE, COMMENT, VOTE, SHARE,
  # etc.
  # - siteName
  # - conversation: where the transaction occured
  # - user: the user ID affected by the transaction
  # - value: number of points
  # - source: the user ID that triggered this transaction, or null if triggered
  # by a job/admin
  # - ref: the item ID on which the transation was performed (comment id,
  # challenge id, conversation id, etc)

  record: (data, cb)->
    if data.user?._id
      data.user = data.user._id
    if data.source?._id
      data.source = data.source._id
    if data.ref?._id
      data.ref = data.ref._id
    async.waterfall([
      (cb)->
        if data.user
          async.parallel({
            user: (cb)->
              collections.users.findOne({_id: data.user}, cb)
            profile: (cb)->
              collections.profiles.findOne({user: data.user, siteName: data.siteName}, cb)
          }, cb)
        else
          cb(null, {user: null, profile: null})
      (info, cb)->
        data.user_verified = info.user?.verified || false
        data.profile_created = info.profile?.created || false
        data.profile_trusted = info.profile?.trusted || false
        collections.transactions.insert(data, cb)
    ], cb)

_.extend(Transactions.prototype, require("./mixins").sorting)

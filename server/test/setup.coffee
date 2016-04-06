require("coffee-script")
global._ = require("underscore")
global._.str = require('underscore.string')
chai = require("chai")
sinonChai = require("sinon-chai")
chai.use(sinonChai)
global.expect = chai.expect
global.sinon = require("sinon")

async = require("async")
MongoClient = require("mongodb").MongoClient
datastore = require("../datastore")
path = require("path")
indexesText = require("fs").readFileSync(path.join(__dirname, "../../scripts/mongo/indexes.js"))
indexesFunc = "function() {#{indexesText}}"
db = null

before((done)->
  naboo = require("naboo")
  naboo({
    configPath: "../../../server/config"
    initPath: "../../../server/init"
  }, ->
    module.exports.app = naboo.config.app
    module.exports.config = naboo.config
    db = datastore.db
    async.series([
      (cb)->
        dropCollections(cb)
      (cb)->
        db.eval(indexesFunc, cb)
    ], done)
  )
)

clearCollections = (done)->
  ignoreNoNs = (cb)->
    return (err)->
      if err?.toString() == "MongoError: ns not found"
        cb()
      else
        cb(err)

  async.parallel([
    (cb)->
      datastore.collections.sites.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.conversations.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.users.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.profiles.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.convprofiles.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.competition_profiles.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.comments.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.likes.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.votes.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.notifications.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.subscriptions.remove({}, ignoreNoNs(cb))
    (cb)->
      datastore.collections.jobs.remove({}, ignoreNoNs(cb))
    ], (err, results)->
      done(err)
    )

dropCollections = (done)->
  ignoreNoNs = (cb)->
    return (err)->
      if err?.toString() == "MongoError: ns not found"
        cb()
      else
        cb(err)

  async.parallel([
    (cb)->
      db.dropCollection("sites", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("conversations", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("users", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("profiles", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("convprofiles", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("competition_profiles", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("comments", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("likes", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("votes", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("notifications", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("subscriptions", ignoreNoNs(cb))
    (cb)->
      db.dropCollection("jobs", ignoreNoNs(cb))
    ], (err, results)->
      done(err)
    )

module.exports.clear = clear = (done)->
  dropCollections(done)

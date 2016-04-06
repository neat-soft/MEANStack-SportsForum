MongoClient = require("mongodb").MongoClient
async = require("async")

module.exports = (done)->
  async.waterfall([
    (cb)=>
      MongoClient.connect(this["db.app"].uri, this["db.app"].options, cb)
    (dbapp, cb)=>
      if !dbapp
        cb({nodb: true})
        return
      if this["db.session"].uri == this["db.app"].uri
        cb(null, dbapp, dbapp)
      else
        MongoClient.connect(this["db.session"].uri, this["db.session"].options, (err, db)->
          cb(null, dbapp, db)
        )
    (dbapp, dbsession, cb)=>
      MongoClient.connect(this["db.log"].uri, this["db.log"].options, (err, db)->
        cb(null, dbapp, dbsession, db)
      )
  ], (err, dbapp, dbsession, dblog)=>
    if err
      done(err)
    else if !dbsession
      done({nodb: true})
    else if !dblog
      done({nodb: true})
    else
      @DB ?= {}
      @DB.app = dbapp
      @DB.session = dbsession
      @DB.log = dblog
      require("../datastore").init(@DB, done)
  )

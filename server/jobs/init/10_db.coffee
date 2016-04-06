MongoClient = require("mongodb").MongoClient

module.exports = (callback)->

  MongoClient.connect(this["db.app"].uri, this["db.app"].options, (err, db)=>
    if !db
      callback({nodb: true})
      return
    @DB ?= {}
    @DB.app = db
    require("../../datastore").init(@DB, callback)
  )

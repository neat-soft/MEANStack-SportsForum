module.exports = (app)->

  dbutil = require("../../datastore/util")
  datastore = require("../../datastore")
  collections = datastore.collections
  db = datastore.db
  templates = require("../../templates")
  async = require("async")
  config = require("naboo").config
  handlers = require("../handlers")
  moment = require("moment")
  debug = require("debug")("zeus:logs")

  app.get("/zeus/logs", (req, res)->
    res.redirect("/zeus/logs/fatal")
  )

  app.get("/zeus/logs/fatal", (req, res)->
    perpage = 500
    lastfirst = if req.query.f then dbutil.idFrom(req.query.f) || dbutil.idFromTime(0) else ""
    lastlast = if req.query.l then dbutil.idFrom(req.query.l) || dbutil.idFromTime(0) else ""
    collections.logs.pageById(_.extend({}, req.query, {_type: "fatal"}), lastfirst, lastlast, perpage, req.query.prev, (err, result)->
      if err
        return templates.render(res, "zeus/error", {error: err})
      templates.render(res, "zeus/logsgeneric", result)
    )
  )

  app.get("/zeus/logs/all", (req, res)->
    perpage = 500
    lastfirst = if req.query.f then dbutil.idFrom(req.query.f) || dbutil.idFromTime(0) else ""
    lastlast = if req.query.l then dbutil.idFrom(req.query.l) || dbutil.idFromTime(0) else ""
    collections.logs.pageById(_.extend({}, req.query), lastfirst, lastlast, perpage, req.query.prev, (err, result)->
      if err
        return templates.render(res, "zeus/error", {error: err})
      templates.render(res, "zeus/logsgeneric", result)
    )
  )

  app.get("/zeus/logs/embederror", (req, res)->
    perpage = 500
    lastfirst = if req.query.f then dbutil.idFrom(req.query.f) || dbutil.idFromTime(0) else ""
    lastlast = if req.query.l then dbutil.idFrom(req.query.l) || dbutil.idFromTime(0) else ""
    collections.logs.pageById(_.extend({}, req.query, {_type: "embed", error: {$exists: true}}), lastfirst, lastlast, perpage, req.query.prev, (err, result)->
      if err
        return templates.render(res, "zeus/error", {error: err})
      templates.render(res, "zeus/logsgeneric", result)
    )
  )

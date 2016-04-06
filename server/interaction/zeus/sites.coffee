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
  debug = require("debug")("zeus:sites")
  elasticsearch = require("es")

  debug("using #{process.env.DB_ELASTIC} for ES")
  es = elasticsearch({
    _index: "page_views"
    _type: "daily"
    server: {
      hosts: [process.env.DB_ELASTIC || "localhost"]
      port: 9200
    }
  })

  TIME_FORMAT = "YYYY-MM-DDTHH:mm:ss"

  mapActive = ->
    if @approved
      emit(@context, 1)

  reduceActive = (key, values)->
    result = 0
    for value in values
      result += value
    return result

  topActiveConversations = (site, since, to, callback)->
    colname = "_tmp_#{site.name}_top_active_conv_#{since}_#{to}"
    lock = "#{site.name}_active_conv_#{since}_#{to}"
    async.waterfall([
      (cb)->
        collections.locks.findAndModify({_id: lock}, [], {$setOnInsert: {locked: false}}, {new: true, upsert: true}, cb)
      (lock, info, cb)->
        if info.lastErrorObject.updatedExisting
          if lock.locked
            debug('compute top conversations, pending', site.name, since, to)
            return cb({locked: true})
          debug('compute top conversations, statistics already available for site %s, period %s to %s', site.name, since, to)
          return db.collection(colname, cb)
        else
          debug('compute top conversations, performing map reduce for site %s, period %s to %s', site.name, since, to)
          collections.comments.mapReduce(mapActive, reduceActive, {query: {siteName: site.name, _id: {$gte: dbutil.idFromTime(since), $lt: dbutil.idFromTime(to)}}, out: {replace: colname}, readPreference: "primary"}, (err, col)->
            if err
              return cb(err)
            collections.locks.update({_id: lock}, {$set: {locked: false}}, (err)->
              cb(err, col)
            )
          )
      (col, cb)->
        col.find({}, {sort: [["value", -1]], limit: 10}, cb)
      (cursor, cb)->
        cursor.toArray(cb)
      (list, cb)->
        async.map(list, (item, cbp)->
          collections.conversations.findOne({_id: item._id}, cbp)
        , (err, results)->
          debug("fetched conversations for map reduce results", results)
          if err
            return cb(err)
          for index in [0...list.length]
            list[index].conv = results[index]
            list[index].newcomments = list[index].value
          cb(null, list)
        )
    ], callback)

  topConversations = (site, since, to, callback)->
    async.waterfall([
      (cb)->
        collections.conversations.find({siteName: site.name, _id: {$gte: dbutil.idFromTime(since), $lt: dbutil.idFromTime(to)}}, {limit: 10, sort: [["no_all_activities", -1]]}, cb)
      (cursor, cb)->
        cursor.toArray(cb)
    ], callback)

  top_page_views = (siteName, start, end, callback)->
    es.search({search_type: "count"}, {
      query:
        bool:
          must: [
            {
              range:
                time:
                  gte: start.format(TIME_FORMAT)
                  lt: end.format(TIME_FORMAT)
            },
            {
              text:
                site: siteName
            }
          ]
      facets :
        conv_count_stats:
          terms_stats:
            key_field : "conv"
            value_field : "count"
            order: "total"
            size: 10
    }, (err, docs)->
      debug("query #{siteName} from #{start.format(TIME_FORMAT)} to #{end.format(TIME_FORMAT)}")
      if err
        debug("failed to query #{err.name} - #{err.message}")
        return callback(err)
      docs = docs.facets.conv_count_stats.terms.slice()
      async.map(docs, (doc, next)->
        collections.conversations.findOne({siteName: siteName, uri: doc.term}, (err, conv)->
          if err
            return next(err)
          obj = {
            site: siteName
            url: conv?.initialUrl || doc.term || "INVALID"
            count: doc.total
            errors: 0 #doc.errors - we'd have to query again and aggregate on error; ES doesn't support sorting by only 1 facet on a multi facet query
          }
          next(err, obj)
        )
      , callback)
    )

  top_sites_page_views = (start, end, callback)->
    es.search({search_type: "count"}, {
      query:
        bool:
          must: [
            {
              range:
                time:
                  gte: start.format(TIME_FORMAT)
                  lt: end.format(TIME_FORMAT)
            },
          ]
      facets :
        site_count_stats:
          terms_stats:
            key_field : "site"
            value_field : "count"
            order: "total"
            size: 10
    }, (err, docs)->
      debug("query all from #{start.format(TIME_FORMAT)} to #{end.format(TIME_FORMAT)}")
      if err
        debug("failed to query #{err.name} - #{err.message}")
        return callback(err)
      docs = docs.facets.site_count_stats.terms.slice()
      async.map(docs, (doc, next)->
        collections.sites.findOne({siteName: doc.term}, (err, site)->
          if err
            return next(err)
          obj = {
            name: doc.term
            site: site
            count: doc.total
            errors: 0 #doc.errors - we'd have to query again and aggregate on error; ES doesn't support sorting by only 1 facet on a multi facet query
          }
          next(err, obj)
        )
      , callback)
    )

  app.post("/zeus/sites/:site/revokepremium", handlers.site, (req, res)->
    async.waterfall([
      (cb)->
        collections.sites.findAndModify({_id: req.site._id}, [], {$set: {'premium.subscription.forever': false}}, {new: true}, cb)
      (site, info, cb)->
        if !site
          return cb("could not find this site")
        cb(null, site)
    ], (err)->
      if err
        return templates.render(res, "zeus/error", {error: err})
      res.redirect("/zeus/sites/#{req.site.name}#premium")
    )
  )

  app.post("/zeus/sites/:site/grantpremium", handlers.site, (req, res)->
    async.waterfall([
      (cb)->
        collections.sites.findAndModify({_id: req.site._id}, [], {$set: {'premium.subscription.forever': true}}, {new: true}, cb)
      (site, info, cb)->
        if !site
          return cb("could not find this site")
        cb(null, site)
    ], (err)->
      if err
        return templates.render(res, "zeus/error", {error: err})
      res.redirect("/zeus/sites/#{req.site.name}#premium")
    )
  )

  app.get("/zeus/sites/:site", handlers.site, (req, res)->
    today = moment().startOf('hour')
    thisweek = moment().startOf('week')
    lastweek = moment(thisweek).subtract('days', 7)
    nextweek = moment(thisweek).add('days', 7)
    profiles = {thisweek: {}, lastweek: {}}
    comments = {thisweek: {}, lastweek: {}}
    conv = {}
    convactive = {thisweek: {list: {}}, lastweek: {list: {}}}
    convcreated = {thisweek: {list: {}}, lastweek: {list: {}}}
    page_views = {top_day: {}, top_day_prev: {}, top_week: {}, top_week_prev: {}, top_month: {}, top_month_prev: {}, top_year: {}}
    this_day = moment().startOf("day")
    prev_day = moment(this_day).subtract("days", 1)
    two_days_ago = moment(prev_day).subtract("days", 1)
    this_month = moment().startOf("month")
    prev_month = moment(this_month).subtract("months", 1)
    this_year = moment().startOf("year")

    owner = null
    async.parallel([
      (cb)->
        collections.users.findOne({_id: req.site.user}, (err, result)->
          owner = result
          cb(err)
        )
      (cb)->
        collections.comments.count({siteName: req.site.name, approved: true}, (err, result)->
          comments.count_approved = result
          cb(err)
        )
      (cb)->
        collections.comments.count({siteName: req.site.name, approved: true, _id: {$gte: dbutil.idFromTime(thisweek.valueOf()), $lt: dbutil.idFromTime(nextweek.valueOf())}}, (err, result)->
          comments.thisweek.count_approved = result
          cb(err)
        )
      (cb)->
        collections.comments.count({siteName: req.site.name, approved: true, _id: {$gte: dbutil.idFromTime(lastweek.valueOf()), $lt: dbutil.idFromTime(thisweek.valueOf())}}, (err, result)->
          comments.lastweek.count_approved = result
          cb(err)
        )
      (cb)->
        collections.conversations.count({siteName: req.site.name}, (err, result)->
          conv.count = result
          cb(err)
        )
      (cb)->
        collections.conversations.count({siteName: req.site.name, _id: {$gte: dbutil.idFromTime(thisweek.valueOf()), $lt: dbutil.idFromTime(nextweek.valueOf())}}, (err, result)->
          convcreated.thisweek.count = result
          cb(err)
        )
      (cb)->
        collections.conversations.count({siteName: req.site.name, _id: {$gte: dbutil.idFromTime(lastweek.valueOf()), $lt: dbutil.idFromTime(thisweek.valueOf())}}, (err, result)->
          convcreated.lastweek.count = result
          cb(err)
        )
      (cb)->
        collections.profiles.count({siteName: req.site.name}, (err, result)->
          profiles.count = result
          cb(err)
        )
      (cb)->
        collections.profiles.count({siteName: req.site.name, _id: {$gte: dbutil.idFromTime(lastweek.valueOf()), $lt: dbutil.idFromTime(thisweek.valueOf())}}, (err, result)->
          profiles.lastweek.count = result
          cb(err)
        )
      (cb)->
        collections.profiles.count({siteName: req.site.name, _id: {$gte: dbutil.idFromTime(thisweek.valueOf()), $lt: dbutil.idFromTime(nextweek.valueOf())}}, (err, result)->
          profiles.thisweek.count = result
          cb(err)
        )
      (cb)->
        topConversations(req.site, thisweek.valueOf(), nextweek.valueOf(), (err, list)->
          convcreated.thisweek.list = list
          cb(err)
        )
      (cb)->
        topConversations(req.site, lastweek.valueOf(), thisweek.valueOf(), (err, list)->
          convcreated.lastweek.list = list
          cb(err)
        )
      (cb)->
        topActiveConversations(req.site, thisweek.valueOf(), today.valueOf(), (err, results)->
          debug("fetched active conversations %s, from %s, to %s - err: %j, result: %j", req.site.name, thisweek.format(), today.format(), err, results)
          if err
            if err.locked
              convactive.thisweek.pending = true
              convactive.thisweek.list = []
              return cb()
          else
            convactive.thisweek.list = results
          cb(err)
        )
      (cb)->
        topActiveConversations(req.site, lastweek.valueOf(), thisweek.valueOf(), (err, results)->
          debug("fetched active conversations %s, from %s, to %s - err: %j, result: %j", req.site.name, lastweek.format(), thisweek.format(), err, results)
          if err
            if err.locked
              convactive.lastweek.pending = true
              convactive.lastweek.list = []
              return cb()
          else
            convactive.lastweek.list = results
          cb(err)
        )
      # (cb)->
      #   top_page_views(req.query.osite || req.site.name, prev_day, this_day, (err, results)->
      #     page_views.top_day.list = results
      #     cb(err)
      #   )
      # (cb)->
      #   top_page_views(req.query.osite || req.site.name, two_days_ago, prev_day, (err, results)->
      #     page_views.top_day_prev.list = results
      #     cb(err)
      #   )
      # (cb)->
      #   top_page_views(req.query.osite || req.site.name, thisweek, this_day, (err, results)->
      #     page_views.top_week.list = results
      #     cb(err)
      #   )
      # (cb)->
      #   top_page_views(req.query.osite || req.site.name, lastweek, thisweek, (err, results)->
      #     page_views.top_week_prev.list = results
      #     cb(err)
      #   )
      # (cb)->
      #   top_page_views(req.query.osite || req.site.name, this_month, this_day, (err, results)->
      #     page_views.top_month.list = results
      #     cb(err)
      #   )
      # (cb)->
      #   top_page_views(req.query.osite || req.site.name, prev_month, this_month, (err, results)->
      #     page_views.top_month_prev.list = results
      #     cb(err)
      #   )
      # (cb)->
      #   top_page_views(req.query.osite || req.site.name, this_year, this_day, (err, results)->
      #     page_views.top_year.list = results
      #     cb(err)
      #   )
    ], (err, result)->
      if err
        return templates.render(res, "zeus/error", {error: err})
      templates.render(res, "zeus/site", {
        site: req.site,
        comments: comments,
        conv: conv,
        convactive: convactive,
        convcreated: convcreated,
        profiles: profiles,
        page_views: page_views,
        owner: owner
      })
    )
  )

  app.get("/zeus/sites", (req, res)->
    if req.query.name
      return res.redirect("/zeus/sites/#{req.query.name}")
    perpage = 500
    lastfirst = if req.query.f then dbutil.idFrom(req.query.f) || dbutil.idFromTime(0) else ""
    lastlast = if req.query.l then dbutil.idFrom(req.query.l) || dbutil.idFromTime(0) else ""
    collections.sites.pageById({}, lastfirst, lastlast, perpage, req.query.prev, (err, result)->
      if err
        return templates.render(res, "zeus/error", {error: err})

      templates.render(res, "zeus/sites", {sites: result, views: 0})
      # top_sites_page_views(moment().startOf("day").subtract("days", 1), moment().startOf("day"), (err, page_views)->
      #   debug("got the views")
      #   if err
      #     return templates.render(res, "zeus/error", {error: err})
      #   templates.render(res, "zeus/sites", {sites: result, views: page_views})
      # )
    )
  )

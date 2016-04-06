response = require("./response")
debug = require("debug")("analytics")
elasticsearch = require("es")
moment = require("moment")
async = require("async")

module.exports = (app)->
  es = elasticsearch({
    _index: "page_views"
    _type: "daily"
    server: {
      hosts: [process.env.DB_ELASTIC || "localhost"]
      port: 9200
    }
  })

  TIME_FORMAT = "YYYY-MM-DDTHH:mm:ss"

  count_from_es = (siteName, index, start, end, callback)->
    options = {
      search_type: "count"
      _index: index
    }

    # debug("searching with options #{JSON.stringify(options)}")
    query = {
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
            key_field : "time"
            value_field : "count"
            order: "term"
            size: 365
    }

    # debug("query is #{JSON.stringify(query, null, 2)}")

    es.search(options, query, (err, docs)->
      debug("query #{index} for site #{siteName} from #{start.format(TIME_FORMAT)} to #{end.format(TIME_FORMAT)}")
      if err
        debug("failed to query #{index}: #{err.name} - #{err.message}")
        return callback(err)
      # debug("docs are #{JSON.stringify(docs, null, 2)}")
      docs = docs.facets.conv_count_stats.terms.slice()
      callback(err, docs)
    )

  collect_stats = (siteName, index, start, end, cb)->
    count_from_es(siteName, index, start, end, (err, results)->
      counts = []
      maxes = []
      totals = []

      if err
        debug("#{err.name} - #{err.message}")
      else
        for r in results
          counts.push([r.term, r.count])
          maxes.push([r.term, r.max])
          totals.push([r.term, r.total])
      d = {}
      if index == "page_views"
        # XXX HACK the proper name for the statistic is "conversation loads", too late to rename the index now
        index = "loads"
      d[index] = {
        counts: counts
        maxes: maxes
        totals: totals
      }
      cb(err, d)
    )

  app.get("/api/sites/:site/analytics", (req, res)->
    debug(JSON.stringify(req.query))
    siteName = req.params["site"]
    start = moment(req.query.start, "YYYY-MM-DD-HH-mm").startOf("day")
    end = moment(req.query.end, "YYYY-MM-DD-HH-mm").startOf("day")
    async.parallel([
      (cb)->
        collect_stats(siteName, "page_views", start, end, (err, res)->
          if err
            return cb(err, res)

          # insert "computed" stats for 31 december 2013
          date_of_unfortunate_event = moment.utc("2013-12-31")
          if start <= date_of_unfortunate_event and date_of_unfortunate_event < end
            ins_pos = 0
            prev_value = 0
            next_value = 0
            v = res["loads"]["totals"]
            for x, i in v
              if x[0] > date_of_unfortunate_event.valueOf()
                ins_pos = i
                next_value = x[1]
                break
              prev_value = x[1]
            bogus = [date_of_unfortunate_event.valueOf(), Math.floor((prev_value + next_value) / 2)]
            v.splice(ins_pos, 0, [date_of_unfortunate_event.valueOf(), Math.floor((prev_value + next_value) / 2)])
            res["loads"]["totals"] = v
          cb(err, res)
        )
      (cb)->
        collect_stats(siteName, "comments", start, end, cb)
      (cb)->
        collect_stats(siteName, "conversations", start, end, cb)
      (cb)->
        collect_stats(siteName, "notifications", start, end, cb)
      (cb)->
        collect_stats(siteName, "profiles", start, end, cb)
      (cb)->
        collect_stats(siteName, "subscriptions", start, end, cb)
      (cb)->
        collect_stats(siteName, "verified", start, end, cb)
    ], (err, results)->
      stats = {}
      if not err
        for r in results
          for k of r
            stats[k] = r[k]["totals"]
      response.sendObj(res)(err, stats)
    )
  )


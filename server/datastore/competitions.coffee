BaseCol = require("./base")
collections = require("./index").collections
dbutil = require("./util")
util = require("../util")
debug = require("debug")("data:competitions")
moment = require("moment")

module.exports = class Competitions extends BaseCol

  name: "competitions"

  add: (attrs, callback)->
    collections.competitions.insert(attrs, (err, result)->
      callback(err, result?[0])
    )

  get: (id, callback)->
    collections.competitions.findOne({_id: dbutil.idFrom(id)}, callback)

  getForSite: (site, query, callback)->
    if !callback
      callback = query
      query = {}
    debug("GET ALL COMPETITIONS for site %j with query %j", site.name, query)
    collections.competitions.find(_.extend({site: site.name}, query), {sort: {end: -1}}, callback)

  getActiveForSite: (site, callback)->
    now = moment().utc().toDate()
    debug("GET ACTIVE COMPETITIONS for site %j", site.name)
    collections.competitions.getForSite(site, {start: {$lte: now}, end: {$gt: now}}, callback)

  toClient: (comp, site)->
    now = moment().utc().toDate()
    comp.active = comp.start <=  now && now < comp.end
    comp.siteName = comp.site
    comp.start = moment.utc(comp.start).format("DD/MM/YYYY HH:mm")
    comp.end = moment.utc(comp.end).format("DD/MM/YYYY HH:mm")
    return _.pick(comp, [
      "_id",
      "title",
      "community",
      "start",
      "siteName",
      "verified",
      "end",
      "prize",
      "prize_url",
      "rules_url",
      "social_share",
      "active"
      "badge_id"
    ])

BaseCol = require("./base")
util = require("../util")
mongo = require("mongodb")
async = require("async")
moment = require("moment")
dbutil = require("./util")
debug = require("debug")("data:badges")

collections = require("./index").collections

module.exports = class Badges extends BaseCol

  name: "badges"

  allForSite: (userId, site, callback)->
    debug("finding all badges for user #{userId} on site #{site.name}")
    async.parallel([
      (cb)->
        collections.users.findById(dbutil.idFrom(userId), cb)
      (cb)=>
        collections.badges.find({user: dbutil.idFrom(userId), $or: [{siteName: site.name}, {global: true}], competition: null}, cb)
    ], (err, results)=>
      [user, cursor] = results
      if !user
        callback({notexists: true})
      else if !cursor
        callback(err)
      else
        cursor.toArray((err, badges)->
          allSiteBadges = site.badges || collections.profiles.getAllBadges()
          badges = _.filter(badges, (b)->
            nowMillis = moment.utc().valueOf()
            return allSiteBadges[b.badge_id]?.enabled && (
              (!b.expiration?) || (b.expiration > nowMillis)
            )
          )
          cursor.close()
          callback(err, badges)
        )
    )

  toClient: (badge, toUser)->
    return _.pick(badge, ["badge_id", "rank", "value", "rank_cutoff", "rank_last", "manually_assigned"])

  leaders: (badge_id, comp_id, site, toUser, toProf, start, callback)->
    badge_id = parseInt(badge_id, 10)
    debug("fetching badge leaders for '#{badge_id}' and comp #{comp_id} and deliver to #{toUser}")
    query = {
      siteName: site.name
    }
    collections.badges.findOne({siteName: site.name, user: toUser?._id, badge_id: badge_id, competition: comp_id}, (err, my_badge)->
      query = {siteName: site.name, badge_id: badge_id, competition: comp_id, value: {$gt: 0}}
      if toProf?.permissions?.admin || toProf?.permissions?.moderator
        # admins see the leaderboard TOP, they don't have a rank to center on them
        debug("admin, showing from rank 1")
        opts = {sort: {rank: 1}, limit: 10}
      else if !toUser || my_badge?.value > 0 || start
        debug("showing custom range")
        min = Math.max(1, start || ((my_badge?.rank || 0) - 2))
        max = min + 10
        _.extend(query, {rank: {$gte: min, $lt: max}})
        opts = {sort: {rank: 1}, limit: 10}
      else
        opts = {sort: {rank: -1}, limit: 2}
        debug("showing last 2")

      collections.badges.find(query, opts, (err, cursor)->
        if err
          debug(err)
          callback(err, [])
          return
        all_profiles = []
        util.iter_cursor(cursor,
          (badge, next)->
            # console.log(badge)
            collections.profiles.findOne({user: badge.user, siteName: site.name}, (err, prof)->
              if !err
                prof = collections.profiles.toClient(prof)
                prof.rank = badge.rank
                prof.rank_cutoff = badge.rank_cutoff
                prof.rank_last = badge.rank_last
                prof.points = badge.value
                prof._id = "#{prof._id}_#{badge._id}"
                all_profiles.push(prof)
              next(err)
            )
          (err)->
            # console.log(all_profiles)
            if my_badge?.value <= 0
              my_prof = _.extend({}, collections.profiles.toClient(toProf), {
                fake: true
                rank: my_badge?.rank,
                rank_cutoff: my_badge?.rank_cutoff,
                rank_last: my_badge?.rank_last
                points: my_badge?.value
              })
              my_prof._id = "#{my_prof._id}_#{my_badge._id}"
              all_profiles.push(my_prof)
            callback(err, all_profiles)
        )
      )
    )

_.extend(Badges.prototype, require("./mixins").sorting)

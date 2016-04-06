BaseCol = require("./base")
util = require("../util")
async = require("async")
dbutil = require("./util")
debug = require("debug")("data:competition_profiles")

collections = require("./index").collections

module.exports = class CompetitonProfile extends BaseCol

  name: "competition_profiles"

  get: (compId, callback)->
    collections.competition_profiles.find({context: dbutil.idFrom(compId)}, callback)

  # this method will return the default competition profile even if there is no real profile in the database
  forCompetition: (userId, compId, callback)->
    async.parallel([
      (cb)->
        collections.users.findById(dbutil.idFrom(userId), cb)
      (cb)=>
        collections.competition_profiles.findOne({user: dbutil.idFrom(userId), competition: dbutil.idFrom(compId)}, cb)
    ], (err, results)=>
      [user, cprofile] = results
      if !user
        callback({notexists: true})
      else
        if !cprofile
          cprofile = @default
        callback(null, cprofile)
    )

  updateOrCreate: (query, attr, cb)->
    #console.log("update or create q: #{JSON.stringify(query)} a: #{JSON.stringify(attr)}")
    set = _.extend({}, {$set: query}, attr)
    #console.log("\tfindAndModify(#{JSON.stringify(query)}, #{JSON.stringify(set)}, {upsert:true}, cb)")
    collections.competition_profiles.findAndModify(query, [], set, {upsert: true, new: true}, (err, res)->
      #console.log("\t\tin callback: err=#{err} res=#{JSON.stringify(res)}");
      cb(err, res)
    )

  insertProfile: (user, comp, cb)->
    cdate = new Date().getTime()
    attrs = _.extend({}, @default, {
      user: user._id
      competition: comp._id
    })
    collections.competition_profiles.findOrCreate({user: user._id, competition: comp._id}, attrs, (err, result)->
      cb(err, result)
    )

  create: (user, comp, cb)->
    #console.log("conv-create(#{JSON.stringify(user)}, #{JSON.stringify(conv)})")
    if comp._id
      #console.log("IS OBJECT!")
      @insertProfile(user, comp, cb)
    else
      collections.competitions.findOne({_id: comp}, (err, result)=>
        #console.log("conv.find() => #{JSON.stringify(err)}, #{JSON.stringify(result)}")
        if err
          cb(err)
        else if !result
          cb({competition_not_exists: true})
        else
          @insertProfile(user, result, cb)
      )

  toClient: (cprofile, toUser)->
    if cprofile.user && toUser?._id.equals(cprofile.user)
      return cprofile
    return _.pick(cprofile, [
      "_id",
      "points",
      "user",
      "competition",
      "permissions"
    ])

  resetPoints: (comp, callback)->
    debug("resetting all points for competition %j", comp._id)
    collections.competition_profiles.update({competition: comp._id}, {$set: {"points": 0}}, {multi: true}, (err)=>
      callback(err, {})
    )

  leaders: (compId, callback)->
    debug("COMPETITION-LEADERS")
    compId = dbutil.idFrom(compId)
    async.waterfall([
      (cb)->
        debug("find competition %j", compId)
        collections.competitions.findOne({_id: compId}, (err, comp)->
          debug("found competition: #{JSON.stringify(comp)}")
          cb(err, comp)
        )
      (comp, cb)->
        debug("finding leaders for competition %j from site %j", compId, comp.site)
        collections.competition_profiles.find({competition: compId, merged_into: {$exists: false}, points: {$gt: 0}}, {sort: [["points", -1]]}, (err, cursor)->
          cb(err, comp, cursor)
        )
      (comp, cursor, cb)->
        prof_list = []
        collectProfiles = (err, cprof)->
          if err
            debug("error iterating competition_profiles cursor")
            cb(err, prof_list)
            return

          if !cprof
            debug("no more competition profiles")
            cb(null, cursor, prof_list)
            return

          debug("found competition profile: #{JSON.stringify(cprof)}")

          async.parallel({
            user: (cb)->
              collections.users.findOne({_id: cprof.user}, cb)
            site_prof: (cb)->
              debug("search site profile: #{JSON.stringify({user: cprof.user, siteName: comp.site})}")
              collections.profiles.findOne({user: cprof.user, siteName: comp.site}, cb)
          }, (err, res)->
            user = res.user
            site_prof = res.site_prof

            if err
              debug("error retrieving site profile for user %j on site %j", cprof.user, comp.site)
              return cursor.nextObject(collectProfiles)

            debug("site profile: #{JSON.stringify(site_prof)}, user: #{JSON.stringify(user)}")

            if !site_prof || site_prof.permissions?.admin || site_prof.permissions?.moderator
              debug("site profile not good: #{JSON.stringify(site_prof)}")
              return cursor.nextObject(collectProfiles)

            if comp.verified && !user?.verified
              debug("user not verified #{JSON.stringify(user)}")
              return cursor.nextObject(collectProfiles)

            debug("user %j is not admin, %j points", cprof.user, cprof.points)
            cprof.permissions = site_prof.permissions # client expects permissions
            prof_list.push(cprof)
            if prof_list.length == 10
              debug("found 10 competition profiles, done")
              return cb(null, cursor, prof_list)
            cursor.nextObject(collectProfiles)
          )

        cursor.nextObject(collectProfiles)
      (cursor, prof_list, cb)->
        debug("result is %j", prof_list)
        cursor.close()
        cb(null, prof_list)
    ], callback)

  merge: (from_user, into_user, callback)->
    from_profile = null
    into_profile = null
    async.forever(
      (next)=>
        async.waterfall([
          (cb)=>
            @findAndModify({user: from_user._id, deleted: {$ne: true}}, [], {$set: {deleted: true}}, {new: true}, cb)
          (profile, info, cb)=>
            from_profile = profile
            if !from_profile
              return cb({notexists: true})
            @create(into_user, {_id: from_profile.competition}, cb)
          (profile, cb)=>
            into_profile = profile
            @update({_id: into_profile._id}, {$inc: {points: from_profile.points}}, cb)
          (no_updated, info, cb)=>
            @findAndModify({user: from_user._id}, [], {$set: {merged_into: into_profile._id}}, {new: true}, cb)
        ], next)
      (err)->
        if err?.notexists
          return callback()
        callback(err)
    )

  default:
    points: util.getValue("compInitialPoints")

_.extend(CompetitonProfile.prototype, require("./mixins").sorting)

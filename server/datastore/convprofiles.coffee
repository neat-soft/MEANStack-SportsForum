BaseCol = require("./base")
util = require("../util")
async = require("async")
dbutil = require("./util")
debug = require("debug")("convprofiles:data")

collections = require("./index").collections

module.exports = class ConvProfiles extends BaseCol

  name: "convprofiles"

  get: (convId, callback)->
    collections.convprofiles.find({context: dbutil.idFrom(convId)}, callback)

  # this method will return the default conversation profile even if there is no real profile in the database
  forConversation: (userId, convId, callback)->
    async.parallel([
      (cb)->
        collections.users.findById(dbutil.idFrom(userId), cb)
      (cb)=>
        collections.convprofiles.findOne({user: dbutil.idFrom(userId), context: dbutil.idFrom(convId)}, cb)
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
    collections.convprofiles.findAndModify(query, [], set, {upsert: true, new: true}, (err, res)->
      #console.log("\t\tin callback: err=#{err} res=#{JSON.stringify(res)}");
      cb(err, res)
    )

  insertConvProfile: (user, conv, cb)->
    cdate = new Date().getTime()
    attrs = _.extend({}, @default, {
      user: user._id
      context: conv._id
    })
    collections.convprofiles.findOrCreate({user: user._id, context: conv._id}, attrs, (err, result)->
      cb(err, result)
    )

  create: (user, conv, cb)->
    #console.log("conv-create(#{JSON.stringify(user)}, #{JSON.stringify(conv)})")
    if conv._id
      #console.log("IS OBJECT!")
      @insertConvProfile(user, conv, cb)
    else
      collections.conversations.findOne({_id: conv}, (err, result)=>
        #console.log("conv.find() => #{JSON.stringify(err)}, #{JSON.stringify(result)}")
        if err
          cb(err)
        else if !result
          cb({conversationnotexists: true})
        else
          @insertConvProfile(user, result, cb)
      )

  toClient: (cprofile, toUser)->
    if cprofile.user && toUser?._id.equals(cprofile.user)
      return cprofile
    return _.pick(cprofile, [
      "_id",
      "points",
      "user",
      "context",
      "permissions"
    ])

  resetPoints: (conv, callback)->
    debug("resetting all points for conversation %j", conv._id)
    collections.convprofiles.update({context: conv._id}, {$set: {"points": 0}}, {multi: true}, (err)=>
      callback(err, {})
    )

  leaders: (conv, site, callback)->
    conv = dbutil.idFrom(conv)
    async.waterfall([
      (cb)->
        debug("finding leaders for conversation %j from site %j", conv, site.name)
        collections.convprofiles.find({context: conv, merged_into: {$exists: false}, points: {$gt: 0}}, {sort: [["points", -1]]}, (err, cursor)->
          cb(err, site, cursor)
        )
      (site, cursor, cb)->
        prof_list = []
        collectProfiles = (err, cprof)->
          if err
            debug("error iterating convprofile cursor")
            cb(err, prof_list)
            return

          if !cprof
            debug("no more conversation profiles")
            cb(null, cursor, prof_list)
            return

          async.parallel({
            user: (cb)->
              collections.users.findOne({_id: cprof.user}, cb)
            site_prof: (cb)->
              debug("search site profile: #{JSON.stringify({user: cprof.user, siteName: site.name})}")
              collections.profiles.findOne({user: cprof.user, siteName: site.name}, cb)
          }, (err, res)->
            user = res.user
            site_prof = res.site_prof

            if err
              debug("error retrieving site profile for user %j on site %j", cprof.user, site.name)
              return cursor.nextObject(collectProfiles)

            debug("site profile: #{JSON.stringify(site_prof)}, user: #{JSON.stringify(user)}")

            if !site_prof || site_prof.permissions?.admin || site_prof.permissions?.moderator
              debug("site profile not good: #{JSON.stringify(site_prof)}")
              return cursor.nextObject(collectProfiles)

            if site.verified_leaderboard && !user?.verified
              debug("user not verified #{JSON.stringify(user)}")
              return cursor.nextObject(collectProfiles)

            debug("user %j is not admin, %j points", cprof.user, cprof.points)
            cprof.permissions = site_prof.permissions # client expects permissions
            prof_list.push(cprof)
            if prof_list.length == 10
              debug("found 10 conversation profiles, done")
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
            @create(into_user, from_profile.context, cb)
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
    points: util.getValue("convInitialPoints")

_.extend(ConvProfiles.prototype, require("./mixins").sorting)

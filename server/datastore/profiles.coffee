BaseCol = require("./base")
util = require("../util")
mongo = require("mongodb")
async = require("async")
dbutil = require("./util")
debug = require("debug")("data:profiles")
moment = require('moment')

collections = require("./index").collections

module.exports = class Profiles extends BaseCol
  all_benefits: [
    "signature"
    "bold_name"
    "extra_vote_points"
  ]

  badges:
    funds_receiver:
      title: "Funded"
      verified: true
      icon: "STAR"
      rule: {}
      manually_assigned: true
      color_bg: "darkkhaki"
      enabled: false
      hide_from_admin: true
      funds_receiver: true
    funds_giver:
      title: "Patron"
      verified: true
      icon: "RICH"
      rule: {}
      manually_assigned: true
      color_bg: "darkkhaki"
      enabled: true
      funds_giver: true
    most_helpful:
      title: "Most Helpful"
      since:
        current_month: true
      verified: true
      limit_percent: 10
      points: true
      rule:
        type: "QUESTION_AWARD"
      icon: "HELP"
    # curious:
    #   title: "Curious"
    #   limit: 1
    #   limit_percent: 1
    #   points: true
    #   rule:
    #     type: "QUESTION"
    # controversial:
    #   title: "Controversial"
    #   limit: 1
    #   limit_percent: 1
    #   points: true
    #   rule:
    #     type: "QUESTION"
    # interesting:
    #   title: "Most Interesting"
    #   limit: 1
    #   limit_percent: 1
    #   count: true
    #   rule:
    #     type: "GOT_REPLY"
    newcomer:
      title: "The Newcomer"
      since:
        last_30_days: true
      registered_last_days: 30
      verified: true
      limit_percent: 25
      points: true
      rule: {}
      icon: "FRESH"
    top_5:
      title: "Top 5%"
      verified: true
      limit_percent: 5
      points: true
      rule: {}
      icon: "TOP5"
    top_month:
      title: "Top This Month"
      since:
        current_month: true
      verified: true
      limit_percent: 10
      points: true
      rule: {}
      icon: "RISE"
    top_sharer:
      title: "Sharer"
      since:
        current_month: true
      verified: true
      limit_percent: 10
      count: 1
      rule:
        type: "SHARE"
      icon: "LINK"
    challenger:
      title: "BurnZone Challenger"
      since:
        current_month: true
      verified: true
      limit_percent: 10
      points: true
      rule:
        type: "WIN_CHALLENGE"
      icon: "IMHO"


  name: "profiles"

  getAllBadges: ()->
    return (_.clone(b) for k, b of collections.profiles.badges)

  get: (site, filter, callback)->
    if typeof(filter) == 'function'
      callback = filter
      filter = {}
    query = _.extend({}, {siteName: site.name}, filter)
    collections.profiles.find(query, callback)

  getPaged: (site, field, dir, from, filter, callback)->
    if typeof(filter) == 'function'
      callback = filter
      filter = {}
    query = _.extend({}, {siteName: site.name}, filter)
    @sortTopLevel(query, field, dir, from, util.getValue("profilesPerPage"), callback)

  fetchByUserIdArray: (ids, site, callback)->
    @find({user: {$in: _.map(ids, (id)-> dbutil.idFrom(id))}, siteName: site}, callback)

  # this method will return the default profile even if there is no real profile in the database
  forSite: (userId, site, callback)->
    async.parallel([
      (cb)->
        collections.users.findById(dbutil.idFrom(userId), cb)
      (cb)=>
        collections.profiles.findOne({user: dbutil.idFrom(userId), siteName: site.name}, cb)
    ], (err, results)=>
      [user, profile] = results
      if !user
        callback({notexists: true})
      else
        if !profile
          profile = @default
        callback(null, profile)
    )

  countForSite: (site, callback)->
    collections.profiles.count({siteName: site.name}, callback)

  modify: (site, targetUserId, attrs, user, profile, callback)->
    attrs = _.pick(attrs, "approval", "permissions")
    if attrs.approval > 2
      attrs.approval = 2
    if attrs.approval < 0
      attrs.approval = 0
    targetUserId = dbutil.idFrom(targetUserId)
    if !targetUserId
      return callback({notexists: true})
    targetUser = null
    async.waterfall([
      (cb)->
        collections.users.findOne({_id: targetUserId}, cb)
      (theuser, cb)=>
        targetUser = theuser
        if !targetUser
          return cb({notexists: true})
        collections.profiles.findOne({siteName: site.name, user: targetUserId}, cb)
      (target_profile, cb)->
        if !target_profile || target_profile.deleted
          return cb({notexists: true})
        # can't modify the admin's profile if not self
        if !user._id.equals(targetUserId) && target_profile.permissions.admin
          return cb({notallowed: true})
        # can't modify own's profile if not admin
        if user._id.equals(targetUserId) && !target_profile.permissions.admin
          return cb({notallowed: true})
        # if user._id.equals(targetUserId) && attrs.permissions.moderator != target_profile.permissions.moderator
        #   # not allowed to remove your own moderator status
        #   return cb({notallowed: true})
        if !targetUser.verified && attrs.permissions.moderator && !target_profile.permissions.moderator
          return cb({not_verified: true})
        # The admin permission cannot be modified
        attrs.permissions.admin = target_profile.permissions.admin # don't allow admin override
        # The moderator permission can only be modified by the admin
        if !profile.permissions.admin
          attrs.permissions.moderator = target_profile.permissions.moderator
        collections.profiles.findAndModify({_id: target_profile._id}, [], {$set: attrs}, {new: true}, cb)
    ], callback)

  insertProfile: (user, site, admin, cb)->
    cdate = new Date().getTime()
    attrs = _.extend({}, @default, {
      created: cdate
      changed: cdate
      user: user._id
      userName: user.name
      siteName: site.name
      approval: if admin then 0 else (site.approvalForNew ? 2) # 0 = auto approve, 1 = banned, 2 = manual
      permissions: {admin: admin, moderator: admin, private: admin}
      trusted: admin
      freeChallengeUsed: 0
    })
    collections.profiles.findOrCreate({user: user._id, siteName: site.name}, attrs, (err, result)->
      cb(err, result)
    )

  create: (user, site, admin, cb)->
    if _.isFunction(admin)
      cb = admin
      admin = false
    if _.isObject(site)
      @insertProfile(user, site, admin, cb)
    else
      collections.sites.findOne({name: site}, (err, result)=>
        if err
          cb(err)
        else if !result
          cb({sitenotexists: true})
        else
          @insertProfile(user, result, admin, cb)
      )

  isModerator: (profile, site)->
    return profile && (p = profile.permissions)? && (p.admin || p.moderator)

  # returns an array of moderator profiles
  getModerators: (siteName, callback)->
    collections.profiles.findToArray({siteName: siteName, 'permissions.moderator': true}, callback)

  isAdmin: (profile, site)->
    return profile && (p = profile.permissions)? && (p.admin)

  hasBenefit: (profile, benefit)->
    return profile.benefits?[benefit]?.expiration > new Date().getTime()

  toClient: (profile, toUser, requiredByMod)->
    debug("send profile #{JSON.stringify(profile, null, 2)} to #{toUser?.name} (mod: #{requiredByMod})")
    if requiredByMod || (profile.user && toUser?._id.equals(profile.user))
      return profile
    p = _.pick(profile, [
      "_id",
      "created",
      "approval",
      "points",
      "user",
      "permissions",
      "siteName",
      "userName",
      "freeChallengeUsed",
      "trusted",
      "benefits"
    ])
    p.stats = _.pick(profile?.stats || {}, [
      "no_comments",
      "no_questions",
      "no_challenges"
    ])
    nowMillis = moment.utc().valueOf()
    activeBenefits = _.filter(collections.profiles.all_benefits, (benefit)->
      return profile.benefits?[benefit]?.expiration > nowMillis
    )
    p.benefits = _.pick(profile.benefits || {}, activeBenefits)
    debug("sending #{JSON.stringify(p, null, 2)}")
    return p

  resetPoints: (site, callback)->
    debug("resetting all points for site %j", site.name)
    collections.profiles.update({siteName: site.name}, {$set: {"points": 0}}, {multi: true}, (err)=>
      callback(err, {})
    )

  leaders: (site, callback)->
    debug("fetching site leaders")
    collections.profiles.find({siteName: site.name, "permissions.admin": false, "permissions.moderator": false, merged_into: {$exists: false}, points: {$gt: 0}}, {sort: [["points", -1]]}, (err, cursor)->
      prof_list = []
      collectProfiles = (err, prof)->
        if !prof || prof_list.length == 10
          cursor.close()
          return callback(err, prof_list)

        debug("found site profile: #{JSON.stringify(prof)}")

        if site.verified_leaderboard
          collections.users.findOne({_id: prof.user}, (err, user)->
            if err
              debug("error retrieving user %j on site %j", prof.user, site.name)
              return cursor.nextObject(collectProfiles)

            if !user?.verified
              debug("user not verified #{JSON.stringify(user)}")
              return cursor.nextObject(collectProfiles)

            debug("add user %j with %j points", prof.user, prof.points)
            prof_list.push(prof)
            cursor.nextObject(collectProfiles)
          )
          return
        else
          prof_list.push(prof)
          cursor.nextObject(collectProfiles)

      cursor.nextObject(collectProfiles)
    )

  badge_leaders: (title, site, callback)->
    debug("fetching badge leaders for '#{title}'")
    query = {
      siteName: site.name
    }
    query["badges.#{title}.rank"] = {$lt: 11}
    prof_list = []
    collections.profiles.find(query, {limit: 10}, (err, cursor)->
      if err
        callback(err, [])
      else
        cursor.toArray(callback)
    )

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
            @create(into_user, from_profile.siteName, cb)
          (profile, cb)=>
            into_profile = profile
            toSet = {
              $inc: {points: from_profile.points}
              $set: {"permissions.moderator": from_profile.permissions.moderator || into_profile.permissions.moderator, "permissions.admin": from_profile.permissions.admin || into_profile.permissions.admin}
            }
            @update({_id: into_profile._id}, toSet, cb)
          (no_updated, info, cb)=>
            @findAndModify({user: from_user._id}, [], {$set: {merged_into: into_profile._id}}, {new: true}, cb)
        ], next)
      (err)->
        if err?.notexists
          return callback()
        callback(err)
    )

  findBadgeId: (site, trueField)->
    badges = site.badges || collections.profiles.getAllBadges()
    badge_id = null
    for b, index in badges
      if b[trueField]
        return index
    return null

  # extend expiration of benefits for giver of funds
  giveFunds: (fromUser, site, toUser, value, done)->
    async.parallel([
      (cb)->
        badge_id = collections.profiles.findBadgeId(site, "funds_giver")
        if badge_id == null
          next(null)
        else
          collections.badges.update({user: fromUser._id, siteName: site.name, funds_giver: true}, {$set: {
            user: fromUser._id
            siteName: site.name
            funds_giver: true
            badge_id: badge_id
            manually_assigned: true
          }}, {upsert: true}, (err)->
            if err
              return cb(err)
            dbutil.extendExpiration(collections.badges, {user: fromUser._id, siteName: site.name, funds_giver: true}, "expiration", util.getValue("expirationDays").funderBadge || 30, "days", cb)
          )
      (cb)->
        async.each(collections.profiles.all_benefits, (benefitName, next)->
          dbutil.extendExpiration(collections.profiles, {siteName: site.name, user: fromUser._id}, "benefits.#{benefitName}.expiration", util.getValue("expirationDays").funderBenefits || 30, "days", next)
        , cb)
    ], done)

  # extend expiration of benefits for receiver of funds
  # TODO: remove code duplication
  receiveFunds: (toUser, site, context, fromUser, value, done)->
    async.parallel([
      (cb)->
        badge_id = collections.profiles.findBadgeId(site, "funds_receiver")
        if badge_id == null
          next(null)
        else
          collections.badges.update({user: toUser._id, siteName: site.name, funds_receiver: true}, {$set: {
            user: toUser._id
            siteName: site.name
            funds_receiver: true
            badge_id: badge_id
            manually_assigned: true
          }}, {upsert: true}, (err)->
            if err
              return cb(err)
            dbutil.extendExpiration(collections.badges, {user: toUser._id, siteName: site.name, funds_receiver: true}, "expiration", util.getValue("expirationDays").fundedBadge || 0, "days", cb)
          )
      (cb)->
        async.each(collections.profiles.all_benefits, (benefitName, next)->
          dbutil.extendExpiration(collections.profiles, {siteName: site.name, user: toUser._id}, "benefits.#{benefitName}.expiration", util.getValue("expirationDays").fundedBenefits || 30, "days", next)
        , cb)
      (cb)->
        collections.comments.incrementPoints({source: toUser._id, type: "RECEIVE_FUNDS"}, toUser, site.name, context, util.getValue("fundedUserPoints"), cb)
    ], done)

  export: (site, iter, callback)->
    user = null
    badges = null
    # We want only profiles that were not deleted but we avoid creating a new
    # index and we filter them here
    collections.profiles.findIter({siteName: site.name}, {sort: [['_id', -1]]},
      (profile, next)->
        if profile.deleted || profile.merged_into
          return next()
        async.waterfall([
          (cb)->
            collections.users.findOne({_id: profile.user, deleted: {$ne: true}, merged_into: {$exists: false}}, cb)
          (result, cb)->
            if !result
              return next()
            user = result
            cb(null)
          (cb)->
            collections.badges.allForSite(user._id, site, cb)
          (result, cb)->
            badges = result
            export_item = {
              email: user.email
              name: user.name
              verified: user.verified && 1 || null
              trusted: user.trusted && 1 || null
            }
            for badge, index in (site.badges || [])
              profile_badge = _.find(badges, (b)-> b.badge_id == index)
              if profile_badge
                export_item["badge #{badge.title}"] = 1
              else
                export_item["badge #{badge.title}"] = null
            iter(export_item, next)
        ], next)
      , (err)->
        callback(err)
    )

  hasStatus: (profile, status, callback)->
    if isNaN(status)
      status = collections.profiles.STATUS[status]
    if !status?
      return callback(null, false)
    collections.profiles.maxStatus(profile, (err, max)->
      callback(err, max >= status)
    )

  maxStatus: (profile, callback)->
    if !profile?
      return callback(null, collections.profiles.STATUS.anonymous)
    collections.badges.findOne({user: profile.user, siteName: profile.siteName, $or: [{funds_receiver: true}, {funds_giver: true}], expiration: {$gt: moment.utc().valueOf()}}, (err, badge)->
      if err || badge
        return callback(err, if err then null else collections.profiles.STATUS.ignited)
      collections.users.findOne({_id: profile.user}, (err, user)->
        if err || user?.trusted
          return callback(err, if err then null else collections.profiles.STATUS.trusted)
        if user.verified
          if profile.points >= 0
            return callback(null, collections.profiles.STATUS.verified_positive)
          return callback(null, collections.profiles.STATUS.verified)
        callback(null, collections.profiles.STATUS.unverified)
      )
    )

  STATUS:
    anonymous: 1
    unverified: 2
    verified: 3
    verified_positive: 4
    trusted: 5
    ignited: 6

  default:
    points: util.getValue("initialPoints")
    benefits: {}
    trusted: false
    permissions: {admin: false, moderator: false, private: false}

_.extend(Profiles.prototype, require("./mixins").sorting)

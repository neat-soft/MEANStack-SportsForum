collections = require("../datastore").collections
dbutil = require("../datastore/util")
async = require("async")
config = require("naboo").config
response = require("./api/response")
util = require("../util")
debug = require("debug")("handlers")
sharedUtil = require("../../shared/util")
helpers = require("./helpers")

module.exports.requireAuth = (req, res, next)->
  if !req.user
    return next({needs_login: true})
  if req.site && req.user.type == "sso" && req.user.site != req.site.name
    return next({needs_login: true})
  next()

module.exports.shouldLogin = (req, res, next)->
  if !req.user
    return helpers.redirectToLogin(req, res)
  next()

module.exports.userType = (type)->
  return (req, res, next)->
    if req.user.type != type
      return next({notexist: true})
    next()

module.exports.notBanned = (req, res, next)->
  if req.profile?.approval == 1
    return next({notallowed: true})
  next()

module.exports.verified = (req, res, next)->
  if collections.users.verifiedOrMod(req.user, req.profile)
    return next()
  return next({not_verified: true})

module.exports.checkConfig = (req, res, next)->
  req.settings_configured = if req.query.frame then req.site.imported_comments else true
  req.appearance_configured = req.site.avatars?.length > 0
  req.forum_configured = req.site.forum?.enabled && req.site.forum?.url
  req.sso_configured = req.site.sso?.enabled
  return next()

module.exports.site = (req, res, next)->
  if req.site
    return next()
  siteName = (req.siteName || req.params?.site)
  if !siteName
    return next({siterequired: true})
  collections.sites.findOne({name: siteName}, (err, site)->
    if err
      next(err)
    else if !site
      next({sitenotexists: true})
    else
      req.site = site
      if _.isArray(req.site.forum.tags)
        req.site.forum.tags = collections.sites.convertOldTags(req.site.forum.tags)
      if req.user?.type == "sso" && req.user.site != site.name
        req.user = null
      next()
  )

module.exports.profile = (req, res, next)->
  if req.profile || !req.user || !req.site
    return next()
  collections.profiles.findOne({user: req.user._id, siteName: req.site.name}, (err, profile)->
    if err
      next(err)
    else
      req.profile = profile
      next()
  )

module.exports.siteAndProfile = (req, res, next)->
  debug("siteAndProfile: #{req.site?.name}, #{req.siteName}")
  if req.site
    return next()
  siteName = (req.siteName || req.params?.site)
  if !siteName
    debug("siteAndProfile: no site")
    return next({siterequired: true})
  async.series([
    (cb)->
      collections.sites.findOne({name: siteName}, (err, site)->
        if err
          cb(err)
        else if !site
          cb({sitenotexists: true})
        else
          req.site = site
          if _.isArray(req.site.forum.tags)
            req.site.forum.tags = collections.sites.convertOldTags(req.site.forum.tags)
          req.site.tz_name ?= "Etc/UTC"
          if req.user?.type == "sso" && req.user.site != site.name
            req.user = null
          cb()
      )
    (cb)->
      collections.competitions.getActiveForSite(req.site, (err, comp_cursor)->
        process_comp = (err, comp)->
          req.site.active_competition = comp?._id
          debug("setting active competition to #{req.site.active_competition}")
          if comp_cursor
            comp_cursor.close()
          cb()
        if comp_cursor
          comp_cursor.nextObject(process_comp)
        else
          process_comp(null, null)
      )
    (cb)->
      if req.profile || !req.user || !req.site
        return cb()
      collections.profiles.create(req.user, req.site, (err, profile)->
        if err
          next(err)
        else
          req.profile = profile
          next()
      )
  ], (err)->
    next(err)
  )

module.exports.requireSite = (req, res, next)->
  if !req.site
    return next({siterequired: true})
  next()

module.exports.isModerator = isModerator = (req, res)->
  return req.site && (collections.profiles.isModerator(req.profile, req.site) || (req.user && req.site.user.equals(req.user._id)))

module.exports.isAdmin = isAdmin = (req, res)->
  return req.site && (collections.profiles.isAdmin(req.profile, req.site) || (req.user && req.site.user.equals(req.user._id)))

module.exports.requireModerator = (req, res, next)->
  if !isModerator(req, res) && !req.user?.zeus
    return next({needs_moderator: true})
  next()

module.exports.requireRealModerator = (req, res, next)->
  if !isModerator(req, res)
    return next({needs_moderator: true})
  next()

module.exports.requireAdmin = (req, res, next)->
  if !isAdmin(req, res) && !req.user?.zeus
    return next({needs_admin: true})
  next()

module.exports.requirePremium = (req, res, next)->
  if !req.site
    return next({siterequired: true})
  if !collections.sites.hasPremium(req.site)
    return next({needs_premium: true})
  next()

module.exports.nakedDomain = (req, res, next)->
  if req.method != "GET"
    return next({notsupported: true})
  if req.siteDomain
    return res.redirect("#{config.serverHost}#{req.originalUrl}")
  next()

module.exports.pagingModerator = (req, res, next)->
  paged = util.jsparse(req.query.paged) ? true
  if paged
    req.paging =
      from: req.query.from
      dir: util.jsparse(req.query.dir) || 1
    if req.paging.dir != 1 && req.paging.dir != -1
      req.paging.dir = 1
    req.paging.field = "_id"
  next()

module.exports.paging = (mode)->
  (req, res, next)->
    paged = util.jsparse(req.query.paged) ? true
    if paged
      req.paging =
        from: req.query.from
        dir: util.jsparse(req.query.dir) || 1
        limit: util.jsparse(req.query.limit) || util.getValue("commentsPerPage")
      if req.paging.dir != 1 && req.paging.dir != -1
        req.paging.dir = 1
      if mode == 'conversations'
        switch req.query.sort
          when "time"
            req.paging.field = "_id"
          when "comments"
            req.paging.field = "no_all_activities"
          when "latest_activity"
            req.paging.field = "latest_activity"
          when "activity_rating"
            req.paging.field = "activity_rating"
          else
            req.paging.field = "_id"
      else if mode == 'activities'
        switch req.query.sort
          when "time"
            req.paging.field = "order_time"
          when "comments"
            req.paging.field = "no_comments"
          when "rating"
            req.paging.field = "rating"
          else
            req.paging.field = "order_time"
      else if mode == 'bets'
        req.paging.field = '_id'
        req.paging.dir = -1
      else if mode == 'funded_activities'
        req.paging.field = '_id'
        req.paging.dir = -1
      else
        req.paging.field = "_id"
    next()

module.exports.decideModeratorForComments = (req, res, next)->
  req.wantsPending = util.jsparse(req.query.pending?.trim().toLowerCase()) ? false
  req.wantsModerator = util.jsparse(req.query.moderator?.trim().toLowerCase()) ? false
  if req.wantsPending && !req.wantsModerator
    req.wantsModerator = true
  if req.wantsModerator
    return module.exports.requireModerator(req, res, next)
  next()

module.exports.createUserWithContent = (req, res, next)->
  async.waterfall([
    (cb)->
      if req.user
        return cb(null, req.user)
      user = req.body.user
      if !user
        return cb({nouser: true})
      user.email = user.email?.toLowerCase?() || ""
      if !sharedUtil.removeWhite(user.name) || !sharedUtil.validateEmail(user.email)
        return cb({email_incorrect: true})
      user.pass = sharedUtil.removeWhite(user.pass) || null
      # if !sharedUtil.removeWhite(user.pass)
      #   return cb({invalid_password: true})
      collections.users.createOwnAccount(user.name, user.email, user.pass, false, cb)
    (user, cb)->
      collections.profiles.create(user, req.site, false, (err, profile)->
        req.profile = profile
        cb(err, user)
      )
    (user, cb)->
      req.login(user, (err)->
        cb(err, user)
      )
  ], (err)->
    next(err)
  )

module.exports.spam = (resource, idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections[resource].setSpam(req.site, id, response.sendObj(res, collections[resource].toClient))

module.exports.notspam = (resource, idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections[resource].notSpam(req.site, id, response.sendObj(res, collections[resource].toClient))

module.exports.approve = (resource, idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections[resource].approve(req.site, id, req.user, response.sendObj(res, collections[resource].toClient))

module.exports.clearFlags = (resource, idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections[resource].clearFlags(req.site, id, req.user, response.sendObj(res, collections[resource].toClient))

module.exports.flag = (resource, idparam)->
  return (req, res)->
    id = req.params[idparam]
    collections[resource].flag(req.site, id, req.user, req.profile, response.sendObj(res, collections[resource].toClient))

module.exports.deletec = (resource, idparam)->
  return (req, res)->
    collections[resource].delete(req.site, req.params[idparam], response.sendObj(res, collections[resource].toClient))

module.exports.destroy = (resource, idparam)->
  return (req, res)->
    collections[resource].destroy(req.site, req.params[idparam], response.sendObj(res, collections[resource].toClient))

module.exports.fetchActivity = (req, res, next)->
  collections.comments.findOne({_id: dbutil.idFrom(req.params["activity"]), siteName: req.site.name}, (err, act)->
    req.activity = act
    next()
  )

module.exports.requireActivity = (req, res, next)->
  if !req.activity
    return next({notexist: true})
  next()

module.exports.fetchContext = (req, res, next)->
  id = null
  if req.params["context"]
    id = dbutil.idFrom(req.params["context"])
  else if req.activity
    id = req.activity.context
  if !id
    return next()
  collections.conversations.findOne({_id: id}, (err, ctx)->
    req.context = ctx
    next()
  )

module.exports.requireContextPermission = (req, res, next)->
  perm = req.profile?.permissions || {}
  if perm.admin || perm.moderator || perm.private
    return next()
  if req.context?.private
    return next({denied: true})
  next()

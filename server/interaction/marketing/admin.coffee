collections = require("../../datastore").collections
dbutil = require("../../datastore/util")
resources = require("../../resources")
path = require("path")
templates = require("../../templates")
util = require("../../util")
sharedUtil = require("../../shared/util")
config = require("naboo").config
async = require("async")
debug = require("debug")("marketing:admin")
handlers = require("../handlers")
moment = require("moment-timezone")
qs = require("querystring")
sso = require("../../sso")
logger = require("../../logging").logger
stripe = require("stripe")(config.stripe.secret)

make_query = (params)->
  p = []
  for k, v of params
    if v
      p.push("#{k}=#{v}")
  q = p.join("&amp;")
  if q
    q = "?" + q
  return q

adminSectionUrl = (protocol, path, siteName, params)->
  if !params
    params = {}
  if config.useSubdomains
    return "#{protocol}://#{siteName}.#{config.domainAndPort}#{path}#{make_query(params)}"
  else
    return "#{config.serverHost}#{path}#{make_query(_.extend({}, params, {site: siteName}))}"

denyAccess = (req, res, next)->
  debug("in denyAccess")
  embed = req.query.embed == "true"
  framed = req.query.frame == "true"
  demo = req.query.demo || req.cookies?.demo || null
  demoSite = demo?.split(':')?[0]
  demoSign = demo?.split(':')?[1]

  async.waterfall([
    (cb)->
      if !framed
        # only in IFRAME
        return cb(null)
      debug("denyAccess - REQ: #{req.path}")
      debug("denyAccess - DEMO: '#{demo}'")
      debug("denyAccess - cookies: #{JSON.stringify(req.cookies)}")
      debug("denyAccess - decure cookies: #{JSON.stringify(req.signedCookies)}")
      debug("denyAccess - for site: #{req.query.site}")
      collections.sites.findOne({name: demoSite}, (err, site)->
        debug("denyAccess - #{site?.name}")
        if !site
          return cb(null)
        debug("denyAccess - SHA = #{sso.sha1(site.name)}")
        if !sso.verifyCredentials(demoSign, site)?.sha1
          debug("denyAccess - invalid")
          return cb(null)
        collections.users.findOne({_id: site.user}, (err, user)->
          debug(user?.email)
          if !user
            return cb(null)
          cb(null, site, user)
        )
      )
  ], (err, site, user)->
    if site && user
      req.demoSite = site
      req.demoUser = user
      req.demo = demo
      if req.user
        # already logged in
        if req.query.demo && req.query.site == req.demoSite.name
          # the query site is the demo one, but the user is logged in
          req.query.site = null
      else if req.query.site == req.demoSite.name
        req.user = user
      res.cookie('demo', demo, {path: '/admin'})

    debug("denyAccess - SITE NOW: #{req.query.site}, demo: #{req.demoSite?.name}")
    if req.user?.site != "burnzone" && !req.user?.zeus && req.path != "/admin/demosite"
      res.redirect("/auth/signin#{make_query({embed: embed, frame: framed})}")
    else
      next()
  )

site = (req, res, next)->
  debug("in site()")
  if config.useSubdomains
    handlers.siteAndProfile(req, res, next)
  else
    siteName = req.query.site?.toLowerCase()
    req.siteName = siteName
    handlers.siteAndProfile(req, res, next)

requireModerator = (req, res, next)->
  debug("in requireModerator")
  if !collections.profiles.isModerator(req.profile, req.site) && !req.user?.zeus
    return next({needs_moderator: true})
  next()

requireAdmin = (req, res, next)->
  debug("in requireAdmin: #{JSON.stringify(req.profile)}, user: #{JSON.stringify(req.user, null, 2)}")
  if !req.profile?.permissions.admin && !req.user?.zeus
    return next({needs_admin: true})
  next()

redirectForMod = (req, res, next)->
  debug("in redirectForMod")
  if !req.profile?.permissions.admin && !req.user?.zeus
    return res.redirect(adminSectionUrl(req.protocol, "/admin/moderator", req.site.name))
  next()

modSites = (req, res, next)->
  debug("in modSites")
  redirect = req.query.redirect || null
  async.series([
    (cb)->
      collections.profiles.find({"permissions.moderator": true, user: req.user._id}, (err, cursor)->
        if err
          templates.render(res, "marketing/error", {error: "There was an error accessing data"})
          return
        cursor.toArray((err, profiles)->
          if err
            cb({dberror: true}, null)
            return
          else
            cb(null, profiles)
        )
      )
    ], (err, result)->
      if err
        return next(err) # templates.render(res, "marketing/error", {error: "There was an error accessing data"})

      allProfiles = result[0]
      allSites = _.map(allProfiles, (p)-> return { name: p.siteName })
      req.userProfiles = allProfiles
      req.sites = allSites
      if allSites.length == 0
        if !/^\/admin\/addsite/i.test(req.path) && !(req.user.zeus && req.site)
          res.redirect("#{config.serverHost}/admin/addsite#{make_query({redirect: redirect, frame: req.query.frame})}")
          return
      else
        # profile = _.find(allSites, (s)-> return s.name == req.site.name)
        if !req.site
          # TODO redirect to domain
          if /^\/admin\/addsite/i.test(req.path)
            if config.useSubdomains && req.siteDomain
              res.redirect("#{config.serverHost}#{req.originalUrl}")
            else
              next()
          else
            res.redirect(adminSectionUrl(req.protocol, req.path, allSites[0].name, {frame: req.query.frame}))
          return
      next()
  )

prepareMod = (req, res, next)->
  debug("in prepareMod")
  if req.site
    async.series([
      (cb)->
        requireModerator(req, res, cb) # TODO use handlers.requireModerator
      (cb)->
        modSites(req, res, cb)
    ], next)
  else if req.query.site
    debug("prepareMod - got site: #{req.query.site}")
    async.series([
      (cb)->
        req.siteName = (sharedUtil.removeWhite(req.query.site) || "").toLowerCase()
        handlers.siteAndProfile(req, res, cb)
      (cb)->
        requireModerator(req, res, cb) # TODO use handlers.requireModerator
      (cb)->
        modSites(req, res, cb)
    ], next)
  else
    async.series([
      (cb)->
        modSites(req, res, cb)
    ], next)

downloadWpPluginLocal = (req, res)->
  download = (site)->
    if !site
      templates.render(res, "marketing/error", {error: "This site does not exist"})
    else if site.user.equals(req.user._id)
      # make an archive of the plugin
      resources.buildWpPlugin(site, (err, filePath)->
        if err
          res.send(500)
        else
          res.setHeader("Content-Type", "application/octet-stream")
          res.setHeader("Content-Disposition", "attachment; filename=" + path.basename(filePath))
          res.sendfile(path.resolve(filePath))
      )
    else
      templates.render(res, "marketing/error", {error: "Access denied"})
  download(req.site)

module.exports = (app)->
  app.get("/admin*", denyAccess)
  app.post("/admin*", denyAccess)
  app.all("/admin*", (req, res, next)->
    debug("request for ADMIN AREA")
    res.locals.admin = true
    next()
  )
  app.get("/admin/install*", prepareMod, requireAdmin)

  app.get("/admin", prepareMod, (req, res)->
    if req.profile.permissions.admin
      res.redirect(adminSectionUrl(req.protocol, "/admin/settings", req.site.name, req.query))
    else
      res.redirect(adminSectionUrl(req.protocol, "/admin/moderator", req.site.name, req.query))
  )

  app.post("/admin/demosite", (req, res)->
    # create unique, dummy site and admin user
    baseurl = req.body?.url
    password = req.body?.pass
    name = dbutil.id().toHexString()

    urls = human_to_url_list(baseurl)
    urls[0].subdomains = true

    debug("demosite - BODY: #{JSON.stringify(req.body)}")
    debug("demosite - urls: #{JSON.stringify(urls)}")
    collections.users.createOwnAccount("user-#{name}", "demo+#{name}@nomail.theburn-zone.com", password, true, (err, demoUser)->
      debug("demosite - CREATE USER: #{JSON.stringify(demoUser)}: #{JSON.stringify(err)}")
      collections.sites.add({name: "site-#{name}", urls: urls}, demoUser, (err, result)->
        res.send(200, {site: "site-#{name}", key: result.sso.secret})
      )
    )
  )

  app.get("/admin/addsite", (req, res)->
    redirect = req.query.redirect
    framed = req.query.frame
    templates.render(res, "marketing/add", {user: req.user, redirect: redirect, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site)})
  )

  app.post("/admin/addsite", (req, res)->
    redirect = req.query.redirect
    framed = req.query.frame
    name = (req.body.name || "").trim().toLowerCase()
    baseUrl = req.body.baseurl?.trim() ||""
    allSub = req.body.allsub?.trim() || ""

    urlNoSpace = sharedUtil.removeWhite(baseUrl)
    if !name || !baseUrl || urlNoSpace.length != baseUrl.length
      if req.query.async
        return res.send(400, {error: "Please enter a unique name and a valid baseurl"})
      templates.render(res, "marketing/add", {error: "Please enter a unique name and a valid baseurl", user: req.user, redirect: redirect, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site)})
      return

    if config.special[name]
      # reject site names that have a special meaning
      if req.query.async
        return res.send(409, {error: "There is already a site with this name"})
      templates.render(res, "marketing/add", {error: "There is already a site with this name", user: req.user, redirect: redirect, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site)})
      return

    baseUrl = util.ensureUrlProtocol(baseUrl.toLowerCase())

    if !collections.sites.validate({name: name})
      if req.query.async
        return res.send(400, {error: "Please enter only alphanumeric characters for the name"})
      templates.render(res, "marketing/add", {error: "Please enter only alphanumeric characters for the name", user: req.user, redirect: redirect, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site)})
      return

    [protocol, baseUrl] = baseUrl.split("://", 2)
    baseUrl = _.str.trim(baseUrl, ".")
    subdomains = !!allSub
    urls = [{protocol: protocol, base: baseUrl, subdomains: subdomains}]
    urlElems = baseUrl.split(".")
    if !subdomains
      if urlElems.length == 2
        urls.push({protocol: protocol, base: "www.#{baseUrl}", subdomains: false})
    if urlElems.length == 3 && urlElems[0] == "www"
      urls.push({protocol: protocol, base: urlElems.slice(1).join("."), subdomains: subdomains})

    # activate per-conversation leaderboards by default
    collections.sites.add({name: name, urls: urls}, req.user, (err, result)->

      if err
        if err.exists
          if req.query.async
            return res.send(409, {error: "There is already a site with this name"})
          templates.render(res, "marketing/add", {error: "There is already a site with this name", user: req.user, redirect: redirect, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site)})
        else
          if req.query.async
            return res.send(500, {error: "There was an error"})
          templates.render(res, "marketing/error", {error: "There was an error", user: req.user, redirect: redirect, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site)})
      else
        if req.query.async
          return res.send(200)
        res.redirect(redirect || adminSectionUrl(req.protocol, "/admin/settings", name, {frame: framed}))
    )
  )

  app.get("/admin/install", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/platforms", {user: req.user, site: req.site, sites: req.sites, embed: embed, admin: true, installation: true})
  )

  app.get("/admin/install/generic", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_generic", {user: req.user, site: req.site, sites: req.sites, script: resources.buildEmbedScript(req.site.name), embed: embed, admin: true, installation: true})
  )

  app.get("/admin/install/wp", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_wordpress", {user: req.user, site: req.site, sites: req.sites, embed: embed, admin: true, installation: true})
  )

  app.get("/admin/install/blogger", (req, res)->
    embed = (req.query.embed == "true")
    script = resources.buildBloggerPlugin(req.site.name)
    templates.render(res, "marketing/plugin_blogger", {user: req.user, site: req.site, sites: req.sites, embed: embed, script: script, admin: true, installation: true, serverHost: req.app.get("config.serverHost"), resourcePath: req.app.get("config.resourcePath")})
  )

  app.get("/admin/install/tumblr", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_tumblr", {user: req.user, site: req.site, sites: req.sites, script: resources.buildEmbedScript(req.site.name), embed: embed, admin: true, installation: true})
  )

  app.get("/admin/install/typepad", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_typepad", {user: req.user, site: req.site, sites: req.sites, script: resources.buildEmbedScriptTypepad(req.site.name), embed: embed, admin: true, installation: true})
  )

  app.get("/admin/install/vbulletin", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_vbulletin", {user: req.user, site: req.site, sites: req.sites, embed: embed, admin: true, installation: true})
  )

  app.get("/admin/sso", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    templates.render(res, "marketing/sso", {user: req.user, site: req.site, sites: req.sites, embed: embed, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site)})
  )

  app.post("/admin/sso", site, requireAdmin, prepareMod, (req, res, next)->
    framed = (req.query.frame == "true")
    attrs = {
      "sso.enabled": req.body["sso.enabled"] == "1",
      "sso.users_verified": req.body["sso.users_verified"] == "1"
    }
    collections.sites.modify(req.site.name, attrs, (err, site)->
      if err
        if req.query.async
          return res.send(400, {error: error})
        req.flash("error", "There was a problem updating the settings.")
      else if !site
        if req.query.async
          return res.send(400, {error: "Site does not exist."})
        return next({sitenotexists: true})
      else if req.query.async
        return res.send(200)
      res.redirect(adminSectionUrl(req.protocol, "/admin/sso", req.site.name, req.query))
    )
  )

  app.get("/admin/forum", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    templates.render(res, "marketing/site_settings_forum", {
      user: req.user,
      site: collections.sites.toClient(req.site),
      hasPremium: collections.sites.hasPremium(req.site),
      sites: req.sites,
      embed: embed,
      framed: framed,
      sub_trial_days: collections.sites.getTrialDays(req.site)
    })
  )

  available_sorts = [
    "activityRatingDesc"
    "timeCreatedDesc"
    "timeCreatedAsc"
    "latestActivityDesc"
    "activitiesDesc"
  ]

  app.post("/admin/forum", site, requireAdmin, prepareMod, (req, res, next)->
    framed = (req.query.frame == "true")
    attrs = {
      "forum.enabled": req.body["forum.enabled"] == "1"
      "forum.tags": util.jsparse(req.body['forum.tags']) || []
      "forum.show_articles": req.body["forum.show_articles"] == "1"
      "forum.mod_create": req.body["forum.mod_create"] == "1"
      "forum.auto_private": req.body["forum.auto_private"] == "1"
    }
    forumurl = sharedUtil.removeWhite(req.body["forum.url"])
    if forumurl
      attrs["forum.url"] = util.ensureUrlProtocol(forumurl)
    else
      attrs["forum.url"] = null
    if req.body["forum.defsort"] in available_sorts
      attrs["forum.defsort"] = req.body["forum.defsort"]
    else
      attrs["forum.defsort"] = "activityRatingDesc"
    collections.sites.modify(req.site.name, attrs, (err, site)->
      if err
        if err.invalid_tag
          req.flash("error", "Tag names cannot be blank or contain the following characters: .:#")
        else
          logger.error(err)
          req.flash("error", "There was a problem updating the settings.")
      else if !site
        return next({sitenotexists: true})
      else
        req.flash("success", "Settings saved.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/forum", req.site.name, req.query))
    )
  )

  app.get("/admin/moderator", prepareMod, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    templates.render(res, "marketing/moderator", {
      user: req.user,
      site: req.site,
      badges: JSON.stringify(req.site.badges || []),
      avatars: JSON.stringify(req.site.avatars || []),
      sites: req.sites,
      embed: embed,
      framed: framed,
      sub_trial_days: collections.sites.getTrialDays(req.site),
      baseUrlResources: config.resourcePath,
      statics: JSON.stringify(req.app.statics)
    })
  )

  app.get("/admin/analytics", prepareMod, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    templates.render(res, "marketing/analytics", {user: req.user, site: req.site, sites: req.sites, embed: embed, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site), baseUrlResources: config.resourcePath, statics: JSON.stringify(req.app.statics)})
  )

  human_to_url_list = (text)->
    url_list = []
    entries = text.split("\n")
    for e in entries
      e = e.replace(/^\s+|\s+$/g, "")
      if !e
        continue
      m = /(.+):\/\/(.+)/.exec(e)
      if m
        schema = m[1]
        e = m[2]
        if schema != 'http' && schema != 'https'
          schema = 'http'
      else
        schema = "http"

      if e.slice(0, 2) == "*."
        e = e.slice(2)
        subdomains = true
      else
        subdomains = false

      u = {
        protocol: schema
        subdomains: subdomains
        base: e
      }
      url_list.push(u)

    return url_list


  # pretty print an array of urls: remove http:// but keep other schemas
  url_list_to_human = (urls)->
    url_list = []
    for url in urls
      schema = if url.protocol != "http" then "#{url.protocol}://" else ""
      url_list.push("#{schema}#{if url.subdomains then '*.' else ''}#{url.base}")

    return url_list.join("\n")

  text_to_list = (text)->
    l = []
    if not text
      return l

    for s in text.split("\n")
      s = s.replace(/^\s+|\s+$/g, "")
      if !s
        continue
      l.push(s)
    return l

  list_to_text = (l)->
    return if l then l.join("\n") else ""

  pad_int_sign = (i, pad_len)->
    i = i || 0
    sign = i < 0
    if sign
      i = -i

    s = i.toString()
    while s.length < pad_len
      s = "0" + s

    return (if sign then "-" else "+") + s

  app.get("/admin/settings", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    debug("settings: demo = #{req.demoSite?._id}")
    debug("settings: site = #{req.site?._id}")
    demo = req.demoSite?._id.equals(req.site._id)
    has_imported = site.imported_comments || req.demoSite?.imported_comments

    zones = []
    for z in moment.tz.zones()
      zones.push({
        name: z.displayName
        offset: pad_int_sign(-(moment.tz(z.displayName).zone()/60), 1)
      })

    async.series({
      cmt: (cb)->
        if req.demoSite && !demo
          collections.comments.count({siteName: req.demoSite.name}, cb)
        else
          cb(null)
    }, (err, result)->
      templates.render(res, (if demo then "marketing/demo" else "marketing/site_settings"), {
        user: req.user,
        site: req.site,
        sites: req.sites,
        hasPremium: collections.sites.hasPremium(req.site)
        baseUrl: url_list_to_human(req.site.urls),
        filterWords: list_to_text(req.site.filter_words),
        siteurl: url_list_to_human([req.site.urls[0]]),
        zones: zones,
        embed: embed,
        framed: framed,
        sub_trial_days: collections.sites.getTrialDays(req.site),
        demo: req.demo,
        demo_comment_count: result.cmt,
        has_imported: has_imported
      })
    )
  )

  app.post("/admin/merge", prepareMod, requireAdmin, (req, res)->
    if req.demoSite
      debug("MERGE #{req.demoSite.name} into #{req.site.name}")
      collections.jobs.add({
        type: "MERGE_SITES"
        from: req.demoSite
        into: req.site
      }, ->
        # nothing to do
      )
    else
      debug("NO MERGE")
    res.send(200)
    # res.send(400, {error: 'failz'})
  )

  parse_multiple = (json, prefix)->
    list = []
    for k, v of json
      if k.slice(0, prefix.length) == prefix
        if v && v != ""
          list.push(v)
    return list

  parse_multiple_map = (json, prefix)->
    map = {}
    for k, v of json
      if k.slice(0, prefix.length) == prefix
        if v && v != ""
          map[k.slice(prefix.length)] = v
    return map

  str_to_int = (s, def, min, max)->
    if isNaN(s)
      return def
    n = parseInt(s, 10)
    if min?
      if n < min
        n = min
    if max?
      if n > max
        n = max
    return n

  app.post("/admin/settings", site, requireAdmin, prepareMod, (req, res, next)->
    framed = (req.query.frame == "true")
    url_list = human_to_url_list(req.body.baseurl)
    if url_list.length < 1
      # always keep at least one url
      url_list = [req.site.urls[0]]
    attrs =
      # autoApprove: (req.body.autoapprove == "1")
      auto_check_spam: (req.body.auto_check_spam == "1")
      use_conv_leaderboard: (req.body.conv_lead == "1")
      verified_leaderboard: (req.body.verify_lead == "1")
      trusted_downvotes: (req.body.trusted_downvotes == "1")
      approvalForNew: parseInt(req.body.approvalfornew)
      urls: url_list
      tz_name: req.body.timezone || "Etc/UTC"
      filter_words: text_to_list(req.body.filterwords)
      defCommentSort: req.body.defCommentSort
    if attrs.approvalForNew != 0 && attrs.approvalForNew != 2
      attrs.approvalForNew = 2
    collections.sites.modify(req.site.name, attrs, (err, site)->
      if err
        if err.exists
          req.flash("error", "There is already a site with the same name or base url registered.")
        else
          req.flash("error", "There was a problem updating the settings.")
      else if !site
        return next({sitenotexists: true})
      else
        req.flash("success", "Settings saved.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/settings", req.site.name, req.query))
    )
  )

  app.get("/admin/badges", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    badges = req.site.badges || collections.profiles.getAllBadges()
    templates.render(res, "marketing/badges", {user: req.user, site: req.site, sites: req.sites, badges: badges, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site), embed: embed, admin: true})
  )

  app.post("/admin/badges", site, requireAdmin, prepareMod, (req, res, next)->
    framed = (req.query.frame == "true")
    badge_list = req.body.badges
    attrs =
      badges: req.site.badges || collections.profiles.getAllBadges()
    for b in badge_list
      if !b
        continue
      if attrs.badges[b.id]
        attrs.badges[b.id].title = b.title
        attrs.badges[b.id].icon = b.icon?.slice(0, 5) || ""
        attrs.badges[b.id].color_bg = b.color_bg
        if !attrs.badges[b.id].manually_assigned
          attrs.badges[b.id].enabled = !!b.enabled
          attrs.badges[b.id].verified = !!b.verified
        switch b.awarded_for
          when "points_all"
            attrs.badges[b.id].points = true
            attrs.badges[b.id].rule = {}
          when "points_answer"
            attrs.badges[b.id].points = true
            attrs.badges[b.id].rule = {type: "QUESTION_AWARD"}
          when "points_challenge"
            attrs.badges[b.id].points = true
            attrs.badges[b.id].rule = {type: "WIN_CHALLENGE"}
          when "count_share"
            attrs.badges[b.id].points = false
            attrs.badges[b.id].count = 1
            attrs.badges[b.id].rule = {type: "SHARE"}
    collections.sites.modify(req.site.name, attrs, (err, site)->
      if err
        console.log(err)
        req.flash("error", "There was a problem updating the badges.")
      else if !site
        return next({sitenotexists: true})
      else
        req.flash("success", "Badges saved.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/badges", req.site.name, req.query))
    )
  )

  validate_points_settings = (settings)->
    return {
      status_comment: settings.status_comment || "unverified"
      status_auto_approve: settings.status_auto_approve || "unverified"
      status_leaderboard: settings.status_leaderboard || "verified"
      status_downvote: settings.status_downvote || "trusted"
      status_upvote: settings.status_upvote || "verified"
      status_flag: settings.status_flag || "trusted"
      for_comment: str_to_int(settings.for_comment, util.getValue("commentPointsAuthor"), 0, 5)
      free_challenge_count: str_to_int(settings.free_challenge_count, util.getValue("freeChallenges"), 0)
      for_challenge_winner: str_to_int(settings.for_challenge_winner, util.getValue("challengeWinnerPoints"), 0)
      for_share: str_to_int(settings.for_share, util.getValue("sharePoints"), 0)
      min_bet: str_to_int(settings.min_bet, util.getValue("minBetPts"), 0)
      min_bet_targeted: str_to_int(settings.min_bet_targeted, util.getValue("minBetPtsTargeted"), 0)
      disable_upvote_points: (settings.disable_upvote_points == '1' || settings.disable_upvote_points == true)
      disable_downvote_points: (settings.disable_downvote_points == '1' || settings.disable_downvote_points == true)
      ignite_create_thread: (settings.ignite_create_thread == '1' || settings.ignite_create_thread == true)
    }

  app.get("/admin/points", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    badges = req.site.badges || collections.profiles.getAllBadges()
    statusList = [
      {name: "anonymous", text: "Anonymous"},
      {name: "unverified", text: "Unverified"},
      {name: "verified", text: "Verified"},
      {name: "verified_positive", text: "Verified (positive score)"},
      {name: "trusted", text: "Trusted"},
      {name: "premium", text: "Premium (Ignited)"}
    ]
    templates.render(res, "marketing/points", {
      user: req.user,
      site: req.site,
      sites: req.sites,
      badges: badges,
      statusList: statusList
      points_settings: validate_points_settings(req.site.points_settings || {})
      framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site), embed: embed, admin: true})
  )

  app.post("/admin/points", site, requireAdmin, prepareMod, (req, res, next)->
    attrs = {
      points_settings: validate_points_settings(parse_multiple_map(req.body, "points_settings."))
    }
    collections.sites.modify(req.site.name, attrs, (err, site)->
      if err
        console.log(err)
        req.flash("error", "There was a problem updating the points settings.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/points", req.site.name, req.query))
    )
  )

  app.get("/admin/appearance", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    avatars = []
    for a in req.site.avatars || []
      avatars.push({raw: a, encoded: encodeURIComponent(a)})
    templates.render(res, "marketing/appearance", {user: req.user, site: req.site, sites: req.sites, avatars: avatars, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site), embed: embed, admin: true})
  )

  app.post("/admin/appearance", site, requireAdmin, prepareMod, (req, res, next)->
    framed = (req.query.frame == "true")
    avatars = parse_multiple(req.body, "avatar_")
    attrs =
      avatars: avatars
      theme: req.body.theme
      "color.question": req.body["color.question"] || ""
      logo: req.body.logo
      display_name: req.body.display_name
    if !(attrs.theme in ["auto", "light", "dark"])
      attrs.theme = "auto"
    if attrs["color.question"]
      attrs["color.question"] = util.color(attrs["color.question"]) || ""
    collections.sites.modify(req.site.name, attrs, (err, site)->
      if err
        req.flash("error", "There was a problem updating the settings.")
      else if !site
        return next({sitenotexists: true})
      else
        req.flash("success", "Settings saved.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/appearance", req.site.name, req.query))
    )
  )

  app.get("/admin/settingsadv", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    qsDefineNew = req.site.conv.qsDefineNew.join("\n")
    templates.render(res, "marketing/site_settings_adv", {user: req.user, site: req.site, sites: req.sites, embed: embed, framed: framed, sub_trial_days: collections.sites.getTrialDays(req.site), qsDefineNew: qsDefineNew})
  )

  app.post("/admin/settingsadv", prepareMod, requireAdmin, (req, res)->
    framed = (req.query.frame == "true")
    attrs = {
      "conv.forceId": (req.body.forceid == "1")
      "conv.useQs": (req.body.useqs == "1")
      "conv.qsDefineNew": req.body.qsdefinenew?.toString?() || ""
    }
    collections.sites.modify(req.site.name, attrs, (err, site)->
      if err
        req.flash("error", "There was a problem updating the settings.")
      else
        req.flash("success", "Settings saved.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/settingsadv", req.site.name, req.query))
    )
  )

  app.get("/admin/premium", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    collections.sites.validateSubscription(req.site, (err, site)->
      active = false
      expiration = site.premium?.subscription?.expiration
      if expiration
        sub_expires = new Date(expiration).toUTCString()
      else
        sub_expires = null
      templates.render(res, "marketing/premium", {
        site: req.site,
        sites: req.sites,
        premium: site.premium || {},
        pk: config.stripe.public,
        has_active_sub: collections.sites.hasPremium(req.site),
        sub_expiration: sub_expires,
        sub_is_trial: collections.sites.hasPremiumTrial(req.site),
        sub_trial_days: collections.sites.getTrialDays(req.site),
        email: req.user.email,
        embed: embed,
        framed: framed
      })
    )
  )

  app.post("/admin/premium", prepareMod, requireAdmin, (req, res)->
    options = req.body.premium?.options || {}
    collections.sites.modify(req.site.name, {"premium.options": options}, ()->
      res.redirect(adminSectionUrl(req.protocol, "/admin/premium", req.site.name, req.query))
    )
  )

  app.post("/admin/premium/subscribe", prepareMod, requireAdmin, (req, res)->
    token = req.body.stripeToken
    collections.sites.addSubscription(req.site, req.user.email, token, (err)->
      if err
        req.flash("error", "There was a problem subscribing you to BurnZone Premium.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/premium", req.site.name, req.query))
    )
  )

  app.get("/admin/premium/cancel", prepareMod, requireAdmin, (req, res)->
    collections.sites.cancelSubscription(req.site, (err)->
      if err
        req.flash("error", "There was a problem cancelling your subscription.")
      res.redirect(adminSectionUrl(req.protocol, "/admin/premium", req.site.name, req.query))
    )
  )

  app.get("/admin/widgets", prepareMod, requireAdmin, (req, res)->
    embed = (req.query.embed == "true")
    framed = (req.query.frame == "true")
    templates.render(res, "marketing/widgets", {
      user: req.user,
      site: collections.sites.toClient(req.site),
      sites: req.sites,
      embed: embed,
      framed: framed,
      sub_trial_days: collections.sites.getTrialDays(req.site)
    })
  )

  app.get("/admin/download/wpplugin", site, requireAdmin, (req, res)->
    download = (site)->
      if !site
          templates.render(res, "marketing/error", {error: "This site does not exist"})
      else if site.user.equals(req.user._id)
        # make an archive of the plugin
        resources.buildWpPluginS3(site, (err, s3key)->
          if err
            templates.render(res, "marketing/error", {error: "We encoutered an issue while sending you the plugin"})
          else
            res.redirect("http://s3.amazonaws.com/" + config["aws.bucket"] + "/" + s3key)
        )
      else
        templates.render(res, "marketing/error", {error: "Access denied"})

    download(req.site)
  )

  app.get("/admin/download/vbplugin", site, requireAdmin, (req, res)->
    download = (site)->
      if !site
        templates.render(res, "marketing/error", {error: "This site does not exist"})
      else if site.user.equals(req.user._id)
        # make an archive of the plugin
        resources.buildVbPlugin(site, (err, content)->
          if err
            logger.error(err)
            templates.render(res, "marketing/error", {error: "We encoutered an issue while sending you the plugin"})
          else
            util.sendAsFile(res, content, "vb_#{config["plugins.vbulletin.v"]}_#{site.name}.xml")
        )
      else
        templates.render(res, "marketing/error", {error: "Access denied"})
    download(req.site)
  )

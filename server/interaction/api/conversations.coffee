module.exports = (app)->
  collections = require("../../datastore").collections
  response = require("./response")
  sharedUtil = require("../../shared/util")
  util = require("../../util")
  handlers = require("../handlers")
  debug = require("debug")("api:conversations")

  addForumIfAllowed = (req, res, next)->
    if req.site.points_settings.ignite_create_thread && !(req.profile.permissions.moderator || req.profile.permissions.admin)
      console.log("checking status because: #{req.site.points_settings.ignite_create_thread}")
      collections.profiles.hasStatus(req.profile, collections.profiles.STATUS.ignited, (err, is_ignited)->
        if !is_ignited
          return next({low_status: true})
        addForum(req, res, next)
      )
    else
      addForum(req, res, next)

  addForum = (req, res, next)->
    if !req.site.forum.enabled
      return next({forumnotenabled: true})
    req.body.question = util.jsparse(req.body.question) || false
    if !req.body.forum
      return next({notsupported: true})
    if !sharedUtil.removeWhite(req.body.text)
      return next({invalid_text: true})
    if !sharedUtil.removeWhite(req.body.forum?.text)
      return next({invalid_text: true})
    req.body.forum.text = _.str.prune(req.body.forum.text, util.getValue("maxForumTitleLength"))
    req.body.forum.tags ||= []
    if !_.isArray(req.body.forum.tags)
      return next({invalid_tags: true})
    req.body.forum.tags = _.map(req.body.forum.tags || [], (t)-> t.toString() || "")
    # enforce TRUE or FALSE selection, otherwise default to auto_private option
    if req.body.forum.private in ["true", "false"]
      req.body.forum.private = req.body.forum.private == "true"
    else
      delete req.body.forum.private
    perm = req.profile.permissions
    if !(perm.moderator || perm.admin || perm.private)
      # non-privileged users can't create private threads
      req.body.forum.private = false
    if req.body.forum.private == null
      req.body.forum.private = req.site.forum?.auto_private || false
    delete req.body.force_approved
    delete req.body._id
    collections.conversations.addForum(req.site, req.user, req.profile, req.body, {ip: req.ip, user_agent: req.headers['user-agent']}, response.sendObj(res, collections.conversations.toClient))

  app.get("/api/sites/:site/contexts/count", (req, res)->
    tags = _.compact(_.map(_.array(req.query.tags), (e)-> sharedUtil.removeWhite(e)))
    filter = sharedUtil.removeWhite(req.query.filter)
    collections.conversations.countFilter(req.site, {tags: tags, filter: filter}, response.sendValue(res))
  )

  app.get("/api/sites/:site/contexts/:context/topcommenters", handlers.fetchContext, handlers.requireContextPermission, (req, res)->
    context = req.params["context"]
    limit = parseInt(req.query.limit) || util.getValue("topForumUsers")
    # No need to pass the result through `toClient` because the it is an aggregation result with public data.
    collections.conversations.topCommenters(req.site, context, limit, response.sendPagedArray(res))
  )

  app.get("/api/sites/:site/contexts/:context?", handlers.decideModeratorForComments, handlers.paging('conversations'), (req, res)->
    context = req.params["context"]
    isModerator = collections.profiles.isModerator(req.profile, req.site)
    if context
      collections.conversations.findContextById(req.site, context, req.wantsModerator, response.sendObj(res, _.partialEnd(collections.conversations.toClient, req.wantsModerator)))
    else
      if req.paging
        attrs =
          tags: _.compact(_.map(_.array(req.query.tags), (e)-> sharedUtil.removeWhite(e)))
          tfrom: req.query.tfrom
          tuntil: req.query.tuntil
          filter: req.query.filter
          articles_only: req.query.articles_only == "true"
          forums_only: req.query.forums_only == "true"
        collections.conversations.getSiteContextsPaged(req.site, attrs, false, req.paging.field, req.paging.dir, req.paging.from, req.paging.limit, response.sendPagedArray(res, _.partialEnd(collections.conversations.toClient, req.wantsModerator)))
      else
        next({notsupported: true})
  )

  app.post("/api/sites/:site/contexts", handlers.createUserWithContent, (req, res, next)->
    req.body.top = true
    addForumIfAllowed(req, res, next)
  )

  app.put("/api/sites/:site/contexts/:context"
    , handlers.requireModerator,
    (req, res, next)->
      context = req.params["context"]
      show_in_forum = util.jsparse(req.body.show_in_forum)
      if show_in_forum?
        return collections.conversations.showInForum(req.site, context, show_in_forum, response.sendObj(res, collections.conversations.toClient))
      return next()
    , handlers.requirePremium,
    (req, res, next)->
      context = req.params["context"]
      private_thread = util.jsparse(req.body.private)
      if private_thread?
        return collections.conversations.private(req.site, context, private_thread, response.sendObj(res, collections.conversations.toClient))
      next({notsupported: true})
  )

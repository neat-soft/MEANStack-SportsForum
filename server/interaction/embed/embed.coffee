async = require("async")
collections = require("../../datastore").collections
sharedUtil = require("../../shared/util")
util = require("../../util")
templates = require("../../templates")
config = require("naboo").config
resources = require("../../resources")
handlers = require("../handlers")
logger = require("../../logging").logger

renderOK = (req, res, conv)->
  if req.user && !(req.user.type == "sso" && req.user.site != req.site.name)
    user = collections.users.toClient(req.user, req.user)
    user.profile = collections.profiles.toClient(req.profile, req.user)
  else
    user = null
  templates.render(res, "embed/index", {
    status: '"OK"'
    data: JSON.stringify((conv && collections.conversations.toClient(conv)) || null)
    site: JSON.stringify(collections.sites.toClient(req.site))
    user: JSON.stringify(user)
    dev: JSON.stringify(config.env == "development")
    loginUrl: config.loginRoot
    baseUrl: config.serverHost
    baseUrlNotifications: config.serverHost
    baseUrlResources: config.resourcePath
    serverTime: new Date().getTime()
    domain: config.domain
    flagsForApproval: util.getValue("flagsForApproval")
    editCommentPeriod: util.getValue("editCommentPeriod")
    challengeCost: util.getValue("challengeCost")
    promoteCost: util.getValue("promoteCost")
    modPromotePoints: util.getValue("modPromotePoints")
    promotedLimit: util.getValue("promotedLimit")
    fbAppId: config.fbClientID
    statics: JSON.stringify(res.req.app.statics)
    theme: req.site.theme
    color: JSON.stringify(req.site.color || {})
    appType: req.appType
    stripePk:  config.stripe.public
    fundCommentPrice: util.getValue("fundCommentPrice")
    minBetPeriod: util.getValue('minBetPeriod')
    minBetPts: req.site.points_settings.min_bet
    minBetPtsTargeted: req.site.points_settings.min_bet_targeted
  })

renderNotAv = (req, res, err)->
  templates.render(res, "embed/index", {
    status: '"NOT_AVAILABLE"'
    message: "error_embed_#{_.keys(err)[0]}"
    data: JSON.stringify(null)
    site: JSON.stringify((req.site && collections.sites.toClient(req.site)) || null)
    user: JSON.stringify(null)
    dev: JSON.stringify(config.env == "development")
    loginUrl: config.loginRoot
    baseUrl: config.serverHost
    baseUrlNotifications: config.serverHost
    baseUrlResources: config.resourcePath
    serverTime: new Date().getTime()
    domain: config.domain
    flagsForApproval: util.getValue("flagsForApproval")
    editCommentPeriod: util.getValue("editCommentPeriod")
    challengeCost: util.getValue("challengeCost")
    promoteCost: util.getValue("promoteCost")
    modPromotePoints: util.getValue("modPromotePoints")
    promotedLimit: util.getValue("promotedLimit")
    statics: JSON.stringify(req.app.statics)
    theme: req.site?.theme || "original_white_bg"
    color: JSON.stringify(req.site?.color || {})
    appType: req.appType
    stripePk:  config.stripe.public
    fundCommentPrice: util.getValue("fundCommentPrice")
    minBetPeriod: util.getValue('minBetPeriod')
    minBetPts: (req.site && req.site.points_settings.min_bet) || util.getValue('minBetPts')
    minBetPtsTargeted: (req.site && req.site.points_settings.min_bet_targeted) || util.getValue('minBetPtsTargeted')
  })

renderCommentingDemo = (req, res)->
  templates.render(res, "embed/index_demo", {
    baseUrl: config.serverHost
    baseUrlNotifications: config.serverHost
    baseUrlResources: config.resourcePath
    serverTime: new Date().getTime()
    flagsForApproval: util.getValue("flagsForApproval")
    editCommentPeriod: util.getValue("editCommentPeriod")
    challengeCost: util.getValue("challengeCost")
    promoteCost: util.getValue("promoteCost")
    modPromotePoints: util.getValue("modPromotePoints")
    promotedLimit: util.getValue("promotedLimit")
    fbAppId: config.fbClientID
    statics: JSON.stringify(res.req.app.statics)
    theme: 'light'
    color: JSON.stringify({})
    appType: req.appType
    stripePk: config.stripe.public_test
    fundCommentPrice: util.getValue("fundCommentPrice")
    minBetPeriod: util.getValue('minBetPeriod')
    minBetPts: util.getValue('minBetPts')
    minBetPtsTargeted: util.getValue('minBetPtsTargeted')
  })

site = (req, res, next)->
  appType = req.query.a?.toUpperCase() || 'ARTICLE'
  if appType == 'ARTICLE_DEMO'
    return next()
  siteName = req.query.s?.toLowerCase()
  req.siteName = siteName
  handlers.siteAndProfile(req, res, next)

# Parameters:
# s=<site name>
# u=<complete url>
# id=<id of the conversation within the site>

module.exports = (app)->

  app.get("/embed", site, (req, res, next)->
    req.appType = req.query.a?.toUpperCase() || 'ARTICLE'
    if req.appType == 'ARTICLE'
      url = req.query.u
      id = sharedUtil.removeWhite(req.query.id)
      title = _.str.trim(req.query.t)
      if !url || !util.urlSupported(url)
        logger.embedError({nourl: true}, req, req.site.name, id, url)
        return renderNotAv(req, res, {nourl: true})
      # TODO: change for subdomains
      if url == config.serverHost + "/embed"
        logger.embedError({embedlocalhost: true}, req, req.site.name, id, url)
        return renderNotAv(req, res, {embedlocalhost: true})
      # ignore Google bot params
      urlreplaced = url.replace(/(?:utm_source=[^&]*|utm_medium=[^&]*|utm_campaign=[^&]*)&?/g, "")
      if url != urlreplaced
        url = urlreplaced.replace(/(?:&|\?)+$/g, "")
      collections.conversations.enter(req.site, title, id, url, (err, conv)->
        if err
          return next(err)
        else
          logger.embedOk(req, req.site.name, conv.uri, url)
          renderOK(req, res, conv)
      )
    else if req.appType == 'ARTICLE_DEMO'
      renderCommentingDemo(req, res)
    else if req.appType == 'FORUM'
      if req.site.forum?.enabled
        renderOK(req, res)
      else
        next({forum_not_enabled: true})
    else if req.appType == 'WIDGET:SUBSCRIBE'
      renderOK(req, res)
    else if req.appType == 'WIDGET:DISCOVERY'
      renderOK(req, res)
    else
      next({app_type_not_supported: true})
  )

  app.get("/intern", site, (req, res, next)->
    app_type = req.query.a?.toUpperCase() || 'ARTICLE'
    if app_type == 'FORUM'
      return templates.render(res, 'embed/intern', {
        app_type: app_type
        host: config.serverHost
        siteName: req.query.s
        conv_uri: req.site.forum.url
      })
    else if app_type == 'ARTICLE'
      if !req.query['conv']
        return next({notexists: true})
      collections.conversations.findContextById(req.site, req.query['conv'], false, (err, conv)->
        if !conv
          return next({notexists: true})
        templates.render(res, 'embed/intern', {
          app_type: app_type
          host: config.serverHost
          siteName: conv.siteName
          conv_uri: conv.initialUrl
          conv_id: conv.uri
          conv_title: conv.text
        })
      )
    else
      return next({notsupported: true})
  )

  embedError = (err, req, res, next)->
    # TODO set response status
    logger.embedError(err, req, req.params?.s || req.params?.site || req.query.s, req.query.id, req.query.u)
    renderNotAv(req, res, err)

  app.get("/embed", embedError)
  app.get("/intern", embedError)

  if (config.env == 'development')
    # setup a link to fetch the client-side application when running in dev mode
    app.get("/test/clientdemo", (req, res)->
      templates.render(res, "embed/index_client", {
        baseUrl: config.serverHost
        baseUrlNotifications: config.serverHost
        baseUrlResources: config.resourcePath
        serverTime: new Date().getTime()
        flagsForApproval: util.getValue("flagsForApproval")
        editCommentPeriod: util.getValue("editCommentPeriod")
        challengeCost: util.getValue("challengeCost")
        promoteCost: util.getValue("promoteCost")
        modPromotePoints: util.getValue("modPromotePoints")
        promotedLimit: util.getValue("promotedLimit")
        minBetPts: util.getValue('minBetPts')
        minBetPtsTargeted: util.getValue('minBetPtsTargeted')
      })
    )
    # setup a link to test the application embedded when running in dev mode
    app.get("/test/embedded", (req, res)->
      templates.render(res, "embed/index_embedded_test", {
        script: resources.buildEmbedScript("test")
      })
    )
    # setup a link to test the forums when running in dev mode
    app.get("/test/forum", (req, res)->
      templates.render(res, "embed/index_forum_test", {
        script: resources.buildEmbedScript("test")
      })
    )

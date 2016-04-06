templates = require("../../templates")
resources = require("../../resources")

module.exports = (app)->

  app.get("/install", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/platforms", {user: req.user, site: req.site, sites: req.sites, embed: embed})
  )

  app.get("/install/generic", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_generic", {user: req.user, site: req.site, sites: req.sites, script: resources.buildEmbedScript(req.site?.name), embed: embed})
  )

  app.get("/install/wp", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_wordpress", {user: req.user, site: req.site, sites: req.sites, embed: embed})
  )

  app.get("/install/blogger", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_blogger", {user: req.user, site: req.site, sites: req.sites, embed: embed})
  )

  app.get("/install/tumblr", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_tumblr", {user: req.user, site: req.site, sites: req.sites, script: resources.buildEmbedScript(req.site?.name), embed: embed})
  )

  app.get("/install/typepad", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_typepad", {user: req.user, site: req.site, sites: req.sites, script: resources.buildEmbedScriptTypepad(req.site?.name), embed: embed})
  )

  app.get("/install/vbulletin", (req, res)->
    embed = (req.query.embed == "true")
    templates.render(res, "marketing/plugin_vbulletin", {user: req.user, site: req.site, sites: req.sites, embed: embed})
  )

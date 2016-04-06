templates = require("../../templates")
resources = require("../../resources")

module.exports = (app)->
  # require("../auth/auth")(app)
  require("./contact")(app)
  require("./admin")(app)
  require("./profile")(app)
  require("./install_platforms")(app)
  require("./subscriptions")(app)

  app.get("/", (req, res)->
    templates.render(res, "marketing/index", {
      user: req.user
      script: resources.buildEmbedScript()
    })
  )

  app.get("/index", (req, res)->
    res.redirect("/")
  )

  app.get("/features", (req, res)->
    templates.render(res, "marketing/features", {
      user: req.user
    })
  )

  app.get("/wordpress_landing", (req, res)->
    templates.render(res, "marketing/wordpress_landing", {
      user: req.user
    })
  )

  app.get("/blogger_landing", (req, res)->
    templates.render(res, "marketing/blogger_landing", {
      user: req.user
    })
  )

  app.get("/demo/intro", (req, res)->
    templates.render(res, "marketing/intro_landing", {
      user: req.user
      script: resources.buildEmbedScriptCore("")
    })
  )

  app.get("/demo/intro-sports", (req, res)->
    templates.render(res, "marketing/intro_sports_landing", {
      user: req.user
      script: resources.buildEmbedScriptCore("")
    })
  )

  app.get("/demo/sports", (req, res)->
    templates.render(res, "marketing/sports_landing", {
      user: req.user
      script: resources.buildEmbedScriptCore("")
    })
  )

  app.get("/about", (req, res)->
    templates.render(res, "marketing/company", {
      user: req.user
    })
  )

  app.get("/pricing", (req, res)->
    templates.render(res, "marketing/pricing", {
      user: req.user
    })
  )

  app.get("/faq", (req, res)->
    templates.render(res, "marketing/faq", {
      user: req.user
    })
  )

  app.get("/privacy", (req, res)->
    templates.render(res, "marketing/privacy", {
      user: req.user
    })
  )

  app.get("/terms", (req, res)->
    templates.render(res, "marketing/terms", {
      user: req.user
    })
  )

  app.get("/demo", (req, res)->
    templates.render(res, "marketing/commenting-demo", {
      user: req.user
      script: resources.buildEmbedScriptCore("")
    })
  )

  app.get("/forums-demo", (req, res)->
    templates.render(res, "marketing/forums-demo", {
      user: req.user
      script: resources.buildEmbedScript("burnzonedemo")
    })
  )

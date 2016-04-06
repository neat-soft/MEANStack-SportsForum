module.exports = (app)->

  app.all("/zeus*", (req, res, next)->
    req.clearTimeout()
    next()
  )

  app.get("/zeus*", (req, res, next)->
    if !req.user?.zeus
      return res.send(403)
    next()
  )

  app.get("/zeus", (req, res)->
    res.redirect("/zeus/sites")
  )

  require("./sites")(app)
  require("./logs")(app)
  
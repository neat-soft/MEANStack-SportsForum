passport = require("passport")
collections = require("../../datastore").collections
util = require("../../util")

module.exports = (app)->

  app.use(passport.initialize())
  app.use(passport.session())

  passport.serializeUser((user, done)->
    done(null, user._id.toHexString())
  )

  passport.deserializeUser((id, done)->
    collections.users.findForSession(id, done)
  )

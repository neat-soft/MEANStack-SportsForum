passport = require("passport")
collections = require("../../datastore").collections
async = require("async")
sharedUtil = require("../../shared/util")
templates = require("../../templates")
Recaptcha = require('recaptcha').Recaptcha
config = require("naboo").config
logger = require("../../logging").logger

module.exports = (app)->

  require("./strategies")(app)

  app.get("/auth/logout", (req, res)->
    redirect = req.query.redirect
    req.logOut()
    delete req.session.auth
    res.redirect(redirect || "/")
  )

  make_query = (params)->
    p = []
    for k, v of params
      if v
        p.push("#{k}=#{v}")
    q = p.join("&amp;")
    if q
      q = "?" + q
    return q

  verifyCaptcha = (req, res, public_key, private_key, callback)->
    data =
      remoteip:  req.connection.remoteAddress
      challenge: req.body.recaptcha_challenge_field
      response:  req.body.recaptcha_response_field
    recaptcha = new Recaptcha(public_key, private_key, data)

    recaptcha.verify((success, error_code)->
      if success
        callback()
      else
        callback(error_code)
    )

  app.get("/auth/signin", (req, res)->
    redirect = req.query.redirect
    popup = if req.query.popup == "true" then true else null
    embed = req.query.embed == "true"
    framed = req.query.frame == "true"
    demo = req.query.demo || null
    if req.user?.site == "burnzone" && !(req.siteDomain && !req.profile.permissions.moderator)
      if popup
        res.redirect("/web/auth/popup_auth_ok.html")
      else
        res.redirect(redirect || "/")
    else
      templates.render(res, "marketing/signin", {redirect: redirect, popup: popup, embed: embed, framed: framed, demo: demo})
  )

  app.get("/auth/reset", (req, res)->
    framed = req.query.frame == "true"
    templates.render(res, "marketing/reset_password_s1", {framed: framed})
  )

  app.post("/auth/reset", (req, res, next)->
    framed = req.query.frame == "true"
    email = req.body.email?.toLowerCase()
    if !sharedUtil.validateEmail(email)
      return templates.render(res, "marketing/reset_password_s1", {error: "Invalid email", captcha_public_key: config.recaptcha_public, framed: framed})
    collections.users.markForReset(email, (err)->
      if err
        if err.notexists
          return templates.render(res, "marketing/reset_password_s1", {error: "There is no user registered with this email", captcha_public_key: config.recaptcha_public, framed: framed})
        else
          return templates.render(res, "marketing/reset_password_s1", {error: "We could not process your request, please retry", captcha_public_key: config.recaptcha_public, framed: framed})
      templates.render(res, "marketing/reset_password_s1s2", {framed: framed})
    )
  )

  app.get("/auth/reset/:token", (req, res, next)->
    token = req.params.token
    collections.users.validateResetToken(token, (err, user)->
      if err
        if err.notexists
          return templates.render(res, "marketing/error", {error: "Invalid password reset token"})
        return next(err)
      if !user
        return templates.render(res, "marketing/error", {error: "Invalid password reset token"})
      templates.render(res, "marketing/reset_password_s2", {token: token})
    )
  )

  app.post("/auth/reset/:token", (req, res, next)->
    token = req.params.token
    passwd = req.body.passwd
    passwd_confirm = req.body.passwd_confirm
    if passwd != passwd_confirm
      return templates.render(res, "marketing/reset_password_s2", {error: "Passwords must match", token: token})
    collections.users.resetPassword(token, passwd, (err, user)->
      if err
        if err.notexists
          return templates.render(res, "marketing/error", {error: "Invalid password reset token"})
        return next(err)
      if !user
        return templates.render(res, "marketing/error", {error: "Invalid password reset token"})
      req.login(user, (err)->
        req.body.email = user.email
        if err
          templates.render(res, "marketing/signin", {error: "Unable to sign you in, please retry"})
        else
          res.redirect("/profile")
      )
    )
  )

  app.get("/auth/verify/:token", (req, res, next)->
    token = req.params.token
    collections.users.verify(token, (err, user)->
      if err
        if err.notexists
          return templates.render(res, "marketing/error", {error: "Invalid verification token"})
        logger.error(err)
        return templates.render(res, "marketing/error", {error: "We encountered an error"})
      if !user
        return templates.render(res, "marketing/error", {error: "We encountered an error"})
      req.login(user, (err)->
        req.body.email = user.email
        if err
          templates.render(res, "marketing/signin", {error: "Unable to sign you in, please retry"})
        else
          res.redirect("/profile")
      )
    )
  )

  app.post('/auth/signin', (req, res, next)->
    redirect = req.query.redirect
    popup = if req.query.popup == "true" then true else null
    embed = req.query.embed == "true"
    async = req.query.async == "true"
    demo = req.query.demo || null
    framed = req.query.frame == "true"

    passport.authenticate('local', (err, user, info)->
      if err || !user
        if async
          return res.send(401, {error: "Invalid email or password"})
        templates.render(res, "marketing/signin", {error: "Invalid email or password", redirect: redirect, popup: popup, embed: embed, framed: framed})
      else
        req.login(user, (err)->
          if err
            if async
              return res.send(401, {error: "Unable to sign you in, please retry"})
            templates.render(res, "marketing/signin", {error: "Unable to sign you in, please retry", redirect: redirect, popup: popup, embed: embed, framed: framed})
          else
            if async
              return res.send(200)
            if popup
              res.redirect("/web/auth/popup_auth_ok.html")
            else
              res.redirect(redirect || "/admin" + make_query({embed: embed, frame: framed, demo: demo}))
        )
    )(req, res, next)
  )

  get_signup = (req, res)->
    popup = if req.query.popup == "true" then true else null
    framed = req.query.frame == "true"
    demo = req.query.demo || null
    redirect = req.query.redirect
    if req.user?.site == "burnzone" && !(req.siteDomain && !req.profile.permissions.moderator)
      if popup
        res.redirect("/web/auth/popup_auth_ok.html")
      else
        res.redirect(redirect || "/")
      return
    templates.render(res, "marketing/signup", {redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, framed: framed, demo: demo})

  app.get("/signup", get_signup)
  app.get("/auth/signup", get_signup)

  app.post('/signup', (req, res)->
    popup = if req.query.popup == "true" then true else null
    redirect = req.query.redirect
    framed = req.query.frame == "true"
    embed = req.query.embed == "true"
    demo = req.query.demo || null
    name = req.body.name
    if !name?.replace(/\s/g, "")
      templates.render(res, "marketing/signup", {error: "Please enter your name", redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, framed: framed, demo: demo})
      return
    email = req.body.email?.toLowerCase()
    if !sharedUtil.validateEmail(email)
      templates.render(res, "marketing/signup", {error: "Invalid email", redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, framed: framed, demo: demo})
      return
    passwd = req.body.passwd
    passwd_confirm = req.body.passwd_confirm
    if passwd != passwd_confirm
      templates.render(res, "marketing/signup", {error: "Passwords must match", redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, framed: framed, demo: demo})
      return
    if !passwd?.replace(/\s/g, "")
      templates.render(res, "marketing/signup", {error: "Invalid password", redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, framed: framed, demo: demo})
      return
    doCreate = ->
      collections.users.createOwnAccount(name, email, passwd, false, (err, user)->
        if err
          if err.exists
            templates.render(res, "marketing/signup", {error: "A user with the same email already exists. Please enter a different one.", redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, framed: framed, demo: demo})
          else
            logger.error(err)
            templates.render(res, "marketing/signup", {error: "Could not create user at the moment.", redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, framed: framed, demo: demo})
        else
          req.login(user, (err)->
            if err
              logger.error(err)
              templates.render(res, "marketing/signin", {error: "Unable to sign you in, please retry.", redirect: redirect, popup: popup, framed: framed, demo: demo})
            else
              delete req.session.auth
              if popup
                res.redirect("/web/auth/popup_auth_ok.html")
              else
                res.redirect("/admin/addsite" + make_query({embed: embed, frame: framed, demo: demo}))
          )
      )
    if config.verify_captcha
      verifyCaptcha(req, res, config.recaptcha_public, config.recaptcha_private, (err)->
        if err
          templates.render(res, "marketing/signup", {error: "Incorrect captcha", redirect: redirect, popup: popup, captcha_public_key: config.recaptcha_public, captcha_error: err, framed: framed, demo: demo})
          return
        doCreate()
      )
    else
      doCreate()
  )

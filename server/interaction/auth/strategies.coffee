passport = require("passport")
collections = require("../../datastore").collections
FacebookStrategy = require("passport-facebook").Strategy
TwitterStrategy = require("passport-twitter").Strategy
GoogleStrategy = require("passport-google-oauth").OAuth2Strategy
DisqusStrategy = require("passport-disqus").Strategy
LocalStrategy = require("passport-local").Strategy
async = require("async")
util = require("../../util")
templates = require("../../templates")
config = require("naboo").config
debug = require("debug")("auth")
logger = require("../../logging").logger

auth = (req, res)->
  return (err, user, info)->
    if err
      email = (req.login_service_profile?.emails?[0]?.value || "").toLowerCase()
      if err.alreadyexists
        req.flash('auth_email', email)
        req.session.auth = {
          login_service_profile: req.login_service_profile
        }
        req.flash('warn', "There is already an account with this email. Please login to attach this #{req.auth_service} account")
        return res.redirect('/auth/signin?popup=true')
      else if err.noemail
        req.flash('auth_name', req.login_service_profile.displayName)
        req.flash('error', "There is no email associated with your #{req.auth_service} account. Enter an email and password to create a new account")
        req.session.auth = {
          login_service_profile: req.login_service_profile
        }
        return res.redirect('/auth/signup?popup=true')
      else if err.deleted
        return templates.render(res, "marketing/error", {error: "This user has been deleted or merged into another user"})
      else if err.not_verified
        return templates.render(res, "marketing/error", {error: "Please verify your account before attaching other login services"})
      else if err.login_exists
        # This shows when trying to attach the same third-party login to more than one account
        return templates.render(res, "marketing/error", {error: "This login is already attached to another account"})
      logger.error(err)
    if !user
      templates.render(res, "marketing/error", {error: "There was an error authenticating you"})
    else
      req.login(user, (err)->
        if err
          return templates.render(res, "marketing/error", {error: "There was an error logging you in"})
        if !user.email
          return res.redirect("/profile")
        res.redirect("/web/auth/popup_auth_ok.html")
      )

module.exports = (app)->

  passport.use(new FacebookStrategy({
      clientID: config.fbClientID || "",
      clientSecret: config.fbClientSecret || "",
      callbackURL: config.serverHost + '/auth/facebook/callback',
      sessionKey: 'oauth:facebook',
      passReqToCallback: true
    },
    (req, accessToken, refreshToken, profile, done)->
      profile.access_token = accessToken
      req.login_service_profile = profile
      debug("Logging in with facebook profile %j", profile)
      if req.user
        if req.user.logins?.facebook
          return done(null, req.user)
        if !req.user.verified
          return done({not_verified: true})
        collections.users.attach3rdPartyLogin(req.user, "facebook", profile, done)
      else
        collections.users.login3rdParty("facebook", profile, done)
  ))

  passport.use(new TwitterStrategy({
      consumerKey: config.twKey,
      consumerSecret: config.twSecret,
      callbackURL: config.serverHost + "/auth/twitter/callback",
      sessionKey: 'oauth:twitter',
      passReqToCallback: true
    },
    (req, token, tokenSecret, profile, done)->
      profile.access_token = token
      profile.access_secret = tokenSecret
      req.login_service_profile = profile
      if req.get_token
        done(null, token, tokenSecret, profile)
      else if req.user
        if req.user.logins?.twitter
          return done(null, req.user)
        if !req.user.verified
          return done({not_verified: true})
        collections.users.attach3rdPartyLogin(req.user, "twitter", profile, done)
      else
        collections.users.login3rdParty("twitter", profile, done)
  ))

  passport.use(new GoogleStrategy({
      clientID: config.googleKey,
      clientSecret: config.googleSecret,
      callbackURL: config.serverHost + "/auth/google/callback",
      sessionKey: 'oauth:google',
      passReqToCallback: true
    },
    (req, accessToken, refreshToken, profile, done)->
      req.login_service_profile = profile
      debug("Logging in with google profile %j", profile)
      if req.user
        if req.user.logins?.google
          return done(null, req.user)
        if !req.user.verified
          return done({not_verified: true})
        collections.users.attach3rdPartyLogin(req.user, "google", profile, done)
      else
        collections.users.login3rdParty("google", profile, done)
  ))

  passport.use(new DisqusStrategy({
      clientID: config.disqusKey,
      clientSecret: config.disqusSecret,
      callbackURL: config.serverHost + "/auth/disqus/callback",
      sessionKey: 'oauth:disqus',
      passReqToCallback: true
    },
    (req, accessToken, refreshToken, profile, done)->
      req.login_service_profile = profile
      debug("Logging in with disqus profile %j", profile)
      if req.user
        if req.user.logins?.disqus
          return done(null, req.user)
        if !req.user.verified
          return done({not_verified: true})
        collections.users.attach3rdPartyLogin(req.user, "disqus", profile, done)
      else
        collections.users.login3rdParty("disqus", profile, done)
  ))

  passport.use(new LocalStrategy(
    {
      usernameField: 'email'
      passwordField: 'passwd'
      passReqToCallback: true
    },
    (req, email, password, done)->
      async.waterfall([
        (cb)->
          collections.users.login(email?.toLowerCase(), password, cb)
        (user, cb)->
          profile = req.session.auth?.login_service_profile
          if profile
            debug('Attaching 3rd party login profile to %j', user)
            return collections.users.attach3rdPartyLogin(user, profile.provider, profile, cb)
          cb(null, user)
      ], (err, user)->
        if (err)
          if err.notexists
            return done(null, false, {message: 'Incorrect email.'})
          else if err.invalid_password
            return done(null, false, {message: 'Incorrect password.'})
          else
            return done(err)
        delete req.session.auth
        done(null, user)
      )
    )
  )

  app.get('/auth/facebook',
    passport.authenticate('facebook', {scope: 'email,read_friendlists,publish_actions,user_about_me,user_birthday,user_friends,user_hometown,user_location,user_work_history,user_religion_politics,user_activities', display: 'popup'}),
    (req, res)->
      # The request will be redirected to Facebook for authentication, so
      # this function will not be called.
  )

  app.get('/auth/twitter',
    passport.authenticate('twitter'),
    (req, res)->

  )

  app.get('/auth/google',
    passport.authenticate('google', { scope: ['https://www.googleapis.com/auth/userinfo.profile',
                                            'https://www.googleapis.com/auth/userinfo.email'] }),
    (req, res)->

  )

  app.get('/auth/disqus',
    passport.authenticate('disqus', {scope: ['read', 'email']}),
    (req, res)->

  )

  app.get('/auth/facebook/callback', (req, res, next)->
    req.auth_service = 'Facebook'
    passport.authenticate('facebook', auth(req, res))(req, res, next)
  )

  app.get('/auth/twitter/callback', (req, res, next)->
    req.auth_service = 'Twitter'
    passport.authenticate('twitter', auth(req, res))(req, res, next)
  )

  app.get('/auth/google/callback', (req, res, next)->
    req.auth_service = 'Google'
    passport.authenticate('google', auth(req, res))(req, res, next)
  )

  app.get('/auth/disqus/callback', (req, res, next)->
    req.auth_service = 'Disqus'
    passport.authenticate('disqus', auth(req, res))(req, res, next)
  )

  # Setup a route for fake Facebook login. This is useful during development.

  if config.env == "development"
    app.get("/auth/facebook/fake", (req, res)->
      fbuid = req.query.fbuid
      attrs = {id: fbuid, _json: {name: fbuid, email: "email@email.com"}}
      async.waterfall([
        (cb)->
          collections.users.login3rdParty("facebook", attrs, cb)
        (user, cb)->
          req.login(user, cb)
      ], (err, user)->
        if err
          res.send(500)
        else
          res.redirect("/web/auth/popup_auth_ok.html")
      )
    )

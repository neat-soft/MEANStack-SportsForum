express = require("express")
MongoStore = require('connect-mongo')(express)
resources = require("../resources")
handlers = require("../interaction/handlers")
logging = require("../logging")
debug = require("debug")("middleware")
util = require("../util")
flash = require("connect-flash")()

module.exports = (done)->

  try
    @app.use(express.bodyParser())
    @app.use(express.query())
    @app.use(express.timeout(30000))
    @app.use((req, res, next)->
      req.on('timeout', ->
        logging.logger.timeout(req, res)
      )
      end = res.end
      res.end = (data, encoding)->
        res.end = end
        res.end(data, encoding)
        res.send = res.setHeader = res.writeHead = res.write = res.end = res.writeContinue = (->)
      next()
    )

    @app.use(require("../interaction/middleware/pause")(@app))
    @app.use(require("../interaction/middleware/wwwredirect"))
    @app.use(require("../interaction/middleware/p3p")(resources.compactPolicyHeader()))
    @app.use(express.cookieParser())

    # should change /web to /p but keep it for backward compatibility for now
    estatic = express.static('./static')
    @app.use('/web', (req, res, next)->
      if /font\//.test(req.path)
        res.setHeader("Access-Control-Allow-Origin", "*")
      estatic(req, res, next)
    )

    if @logRequests
      @app.use(logging.express({immediate: true}))

    @app.use('/mu-fdcd9e07-4f0257e4-618ecf70-7c531aa4', (req, res, next)->
      res.end("42")
    )

    sessionStore = new MongoStore({db: @DB.session})
    cookieOpts = {maxAge: @sessionAge}
    if (@sessionCookieDomain)
      cookieOpts.domain = @sessionCookieDomain
    cookieKey = "connect.sid"
    cookieSecret = "HURF DURF"
    @app.sessions = sessions = express.session({
      key: cookieKey,
      secret: cookieSecret,
      cookie: cookieOpts,
      store: sessionStore
    })

    # patch the session key generation logic
    connect_utils = require("../../node_modules/express/node_modules/connect/lib/utils")
    connect_utils.uid = (len)->
      return util.uid(len)

    keepSession = (s)->
      if !s
        return false
      return s.user || s['oauth:facebook'] || s['oauth:twitter'] || s['oauth:google'] || s['oauth:disqus'] || _.size(s.flash) > 0 || s.account || s.auth

    # If the user is not authenticated then destroy the session.
    # Notes:
    # - the handler for the 'header' event below is executed BEFORE a 'header' handler registered by the session middleware
    @app.use((req, res, next)=>
      res.on('header', =>
        if !req.user && !keepSession(req.session)
          debug("no user, session cookie will not be sent")
          req.bkSession ?= req.session
          req.session = null
          if req.cookies[cookieKey]
            res.clearCookie(cookieKey, {domain: cookieOpts.domain})
      )
      next()
    )
    @app.use(sessions)
    @app.use((req, res, next)->
      end = res.end
      res.end = (data, encoding)->
        res.end = end
        if req.user
          debug("user logged in")
        else if !keepSession(req.session)
          req.bkSession ?= req.session
          req.session = null
          if req.bkSession && req.cookies[cookieKey]
            debug("no user, destroying existing session")
            return req.bkSession.destroy(->
              res.end(data, encoding)
            )
        res.end(data, encoding)
      next()
    )
    @app.use((req, res, next)->
      if !/^\/api\//.test(req.path)
        return flash(req, res, next)
      next()
    )

    # save the session store for future referencing
    @app.sessionStore = sessionStore

    require("../interaction/auth/middleware")(@app)

    # check for subdomain and fwd to appropriate admin site
    @app.use(require("../interaction/middleware/subdomains"))
    @app.use((req, res, next)->
      if req.siteName
        return handlers.siteAndProfile(req, res, next)
      next()
    )
    @app.use(require("../interaction/middleware/redir"))

    @app.use(@app.router)

    process.nextTick(done)
  catch err
    process.nextTick(-> done(err))

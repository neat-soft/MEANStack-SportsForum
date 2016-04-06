https = require("https")
http = require("http")
debug = require("debug")("start")
pubsub = require("../pubsub")
proxy = require("proxywrap");

module.exports = (done)->

  port = process.env.PORT || @port || 80
  http.globalAgent.maxSockets = 1000000
  # secure = @secure;
  # if (secure)
  #   secure_port = process.env.SECURE_PORT || @secure_port || secure.port || 443
  #   debug("Starting secure server on port %s", secure_port)
  #   https.createServer(secure, @app).listen(secure_port);
  server = http.createServer(@app)

  pubsub.init({sub: true, redis: @redis, server: server})

  debug("Starting server on port %s", port)
  server = proxy.wrapServer(server, {strict:false})
  server.listen(port)

  process.on('SIGTERM', =>
    @app.pause()
    @app.once("idle", ->
      debug("app idle, exiting")
      process.exit(0)
    )
    setTimeout(->
      process.exit(0)
    , 60000)
  )

  process.nextTick(done)

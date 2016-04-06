collections = require("./datastore").collections
util = require("./util")
EventEmitter = require("events").EventEmitter
faye = require('faye')
fayeRedis = require('faye-redis')
debug = require("debug")("pubsub:faye")
logger = require("./logging").logger

# disable the logger
faye.logger = null

module.exports = class PubSubFaye extends EventEmitter

  constructor: (options)->
    @options = options
    
    if options.sub
      @bayeux = new faye.NodeAdapter(
        mount: '/rtupdates'
        timeout: 10
        ping: 20
        engine:
          type: fayeRedis
          host: options.redis.host
          port: options.redis.port
          password: options.redis.password
          namespace: "rt"
      )
      @bayeux._server._engine._engine._redis.on("error", (err)->
        logger.error(err)
      )
      @bayeux._server._engine._engine._subscriber.on("error", (err)->
        logger.error(err)
      )
      @bayeux.attach(options.server)
    else
      debug("Dispatching rt messages to %s", options.host)
      @bayeux = new faye.Client(options.host + "/rtupdates", {
        timeout: 50
      })

  publish: (channel, data)->
    debug("publish to %j : %j", channel, data)
    if @options.sub
      @bayeux.getClient().publish(channel, data)
    else
      @bayeux.publish(channel, data)

collections = require("./datastore").collections
util = require("./util")
redis = require("redis")
EventEmitter = require("events").EventEmitter
RedisStore = require('socket.io/lib/stores/redis')
redis  = require('socket.io/node_modules/redis')
socketio = require('socket.io')
logger = require("./logging").logger

module.exports = class PubSubSIO extends EventEmitter

  constructor: (options)->
    @options = options
    @pub = redis.createClient(options.redis.port, options.redis.host, options.redis.options)
    @pub.auth(options.redis.password)
    @pub.on("error", (err)->
      logger.error(err)
    )

    nodeId = ->
      util.nodeId + Math.abs(Math.random() * Math.random() * Date.now() | 0).toString()

    @nodeId = nodeId()
    @pack = JSON.stringify
    @unpack = JSON.parse

    if options.sub
      @sub = redis.createClient(options.redis.port, options.redis.host, options.redis.options)
      @sub.auth(options.redis.password)
      @sub.on("error", (err)->
        logger.error(err)
      )
      @client = redis.createClient(options.redis.port, options.redis.host, options.redis.options)
      @client.auth(options.redis.password)
      @client.on("error", (err)->
        logger.error(err)
      )
      @sio = socketio.listen(options.server)
      @sio.set("resource", "/rtupdates")
      @sio.set("transports", ["xhr-polling"])
      @sio.set("browser client", false)
      @sio.set("polling duration", 10)
      @sio.set("close timeout", 20)
      @sio.set("heartbeat timeout", 20)
      @sio.set("log level", 1)
      @sio.set("store", new RedisStore({
        redis: redis
        redisPub : @pub
        redisSub : @sub
        redisClient : @client
        nodeId: nodeId
        pack: @pack
        unpack: @unpack
      }))
      @sio.sockets.on("connection", (socket)->
        socket.on("subscribe", (data)->
          for room in data.rooms
            socket.join(room)
        )
        socket.on("unsubscribe", (data)-> 
          for room in data.rooms
            socket.leave(room)
        )
      )

  publish: (channel, data)->
    if @options.sub
      @sio.sockets.in(channel).emit("message", data)
    else
      @pub.publish(channel, @pack({nodeId: @nodeId, args: data}))

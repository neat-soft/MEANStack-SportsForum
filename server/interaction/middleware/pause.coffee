debug = require("debug")("middleware:express_will_stop")

module.exports = (app)->
  paused = false
  reqs = 0

  middleware = (req, res, next)->
    if paused
      debug("new request, refusing")
      res.setHeader("Connection", "close")
      res.send(503)
    else
      reqs++
      debug("#requests = #{reqs}")
      end = res.end
      res.end = (chunk, encoding)->
        res.end = end
        res.end(chunk, encoding)
        reqs--
        debug("#requests = #{reqs}")
        if req == 0 && paused
          app.emit("idle")
      next()

  middleware.pause = ->
    if !paused
      paused = true
      if reqs == 0
        process.nextTick(->
          app?.emit("idle")
        )

  middleware.resume = ->
    paused = false

  app.pause = ->
    middleware.pause()
  app.resume = ->
    middleware.resume()

  return middleware

pubsub = require("../../pubsub")

module.exports = (callback)->

  pubsub.init({sub: false, host: @serverHost, redis: @redis})
  process.nextTick(callback)

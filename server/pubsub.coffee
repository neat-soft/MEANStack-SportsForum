PubSubFaye = require("./pubsub_faye")
debug = require('debug')('pubsub')

module.exports.engine = engine = null
module.exports.init = (options)->
  module.exports.engine = engine = new PubSubFaye(options)

module.exports.contentUpdate = (site, contextId, object, options)->
  if not engine
    # the engine is not initialized in case of bulk import of comments
    return

  allChannelSite = "/content/#{site}"
  channelSite = "#{allChannelSite}-"
  if contextId
    allChannelContext = "/content/#{site}/contexts/#{contextId.toHexString?() || contextId}"
    channel = "#{allChannelContext}-"
  else
    channel = channelSite
  data = {update: _.extend({}, object, options?.extra_fields || {})}
  if !contextId?
    data._type ?= "context"
  if options?.type
    data._type = options.type
  if channel != channelSite
    debug(channel, data)
    engine.publish(channel, data)
  debug(channelSite, data)
  engine.publish(channelSite, data)

module.exports.userUpdate = (user)->
  data = {update: user}
  channel = "/users"
  debug(channel, data)
  engine.publish(channel, data)

module.exports.systemNotification = (site, notif)->
  data = {update: notif, type: "notification"}
  channel = "/system/#{site}"
  debug(channel, data)
  engine.publish(channel, data)

module.exports.userNotification = (notif)->
  userId = notif.user._id || notif.user
  channel = "/notifications/#{userId.toHexString?() || userId}"
  data = {update: notif, _type: "notification"}
  debug(channel, data)
  engine.publish(channel, data)

module.exports.destroyContent = (site, id)->
  channel = "/content/#{site}-"
  data = {destroy: id.toHexString?() || id}
  debug(channel, data)
  engine.publish(channel, data)

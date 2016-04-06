BaseCol = require("./base")
collections = require("./index").collections
dbutil = require("./util")
util = require("../util")
debug = require("debug")("data:notifications")
async = require("async")
logger = require("../logging").logger
pubsub = require("../pubsub")

module.exports = class Notifications extends BaseCol

  prepare_client_notif: (notif, to_user, options)->
    if notif.comment?._id
      notif.comment = collections.comments.toClient(notif.comment, options.moderator, to_user)
    if notif.context?._id
      notif.context = collections.conversations.toClient(notif.context, options.moderator, to_user)
    if notif.challenge?._id
      notif.challenge = collections.comments.toClient(notif.challenge, options.moderator, to_user)
    if notif.bet?._id
      notif.bet = collections.comments.toClient(notif.bet, options.moderator, to_user)
    if notif.email_from
      delete notif.email_from
    if notif.email_reply_to
      delete notif.email_reply_to
    if notif.can_reply
      delete notif.can_reply
    if notif.token
      delete notif.token
    return notif

  # options:
  # see variable 'defaults' inside
  send: (to_user, to_email, notification, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    defaults = {
      notification: true # send email. If false, don't send. If object, use it to extend 'notification' when sending emails.
      email: true # send notification. If false, don't send. If object, use it to extend 'notification' when sending notifications.
      moderator: false # to_user is moderator
    }
    options = _.defaults(options, defaults)
    if to_user?._id && (!to_user.subscribe.own_activity || !to_user.verified)
      options.email = false
    if !to_user
      options.notification = false

    async.parallel([
      (cbp)->
        if !options.email
          return cbp()
        to_send = _.extend({}, notification, {
          type: "EMAIL",
          to: to_email,
          uid: "EMAIL_#{notification.uid}_to_#{to_email}"
        })
        if _.isObject(options.email)
          to_send = _.extend(to_send, options.email)
        to_send.emailType = notification.type
        collections.jobs.add(to_send, (err)->
          if err
            logger.error(err)
          cbp()
        )
      (cbp)=>
        if !options.notification
          return cbp()
        to_send = _.extend({}, notification, {
          user: to_user._id || to_user,
        })
        if _.isObject(options.notification)
          to_send = _.extend(to_send, options.notification)
        @addNotification(@prepare_client_notif(to_send, to_user, options), (err)->
          if err
            logger.error(err)
          cbp()
        )
    ], callback)

  addNotification: (notif, callback)->
    async.series([
      (cb)->
        collections.notifications.add(notif, cb)
      (cb)->
        pubsub.userNotification(notif)
        cb()
    ], callback)

  name: "notifications"

  add: (attrs, callback)->
    attrs.read = false
    collections.notifications.insert(attrs, callback)

  getOlder: (user, than, callback)->
    async.waterfall([
      (cb)->
        if than
          than = dbutil.idFrom(than)
          if than
            debug("fetching older than %s", than)
            collections.notifications.find({_id: {$lt: than}, user: user._id}, {limit: util.getValue("notificationsPerPage"), sort: {_id: -1}}, cb)
          else
            cb({notsupported: true})
        else
          debug("fetching all", than)
          collections.notifications.find({user: user._id}, {limit: util.getValue("notificationsPerPage"), sort: {_id: -1}}, cb)
      (cursor, cb)->
        cursor.toArray(cb)
    ], callback)

  countUnread: (user, filters, callback)->
    if typeof(filters) == 'function'
      callback = filters
      filters = {}
    collections.notifications.count(_.extend({}, {user: user._id, read: false}, filters), (err, result)->
      callback(err, {result: result})
    )

  countAll: (user, callback)->
    collections.notifications.count({user: user._id}, (err, result)->
      callback(err, {no_notif: result})
    )

  deleteAll: (user, callback)->
    collections.notifications.remove({user: user._id}, (err)->
      callback(err, [])
    )

  delete: (id, user, callback)->
    collections.notifications.remove({_id: dbutil.idFrom(id), user: user._id}, (err, no_removed)->
      callback(err, {deleted: if no_removed > 0 then true else false})
    )

  markRead: (id, user, callback)->
    collections.notifications.update({_id: dbutil.idFrom(id), user: user._id}, {$set: {read: true}}, (err, no_updated)->
      if err
        return callback(err)
      callback(err, {read: no_updated > 0})
    )

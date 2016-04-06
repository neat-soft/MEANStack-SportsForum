BaseCol = require("./base")
collections = require("./index").collections
util = require("../util")
dbutil = require("./util")
async = require("async")
debug = require("debug")("data:subscriptions")
urls = require("../interaction/urls")
config = require("naboo").config

module.exports = class Subscriptions extends BaseCol

  toClient: (doc)->
    if doc
      return {active: doc.active}
    else
      return {active: false}

  toAdmin: (doc)->
    return _.pick(doc, "email")

  forSite: (site, email, callback)->
    collections.subscriptions.findOne({siteName: site.name, email: email, context: null, verified: true, active: true}, (err, result)->
      if !err && !result
        result = {active: false}
      callback(err, result)
    )

  countAll: (site, callback)->
    collections.subscriptions.count({siteName: site.name, context: null}, (err, result)->
      if err
        return callback(err)
      callback(err, {no_subscribers: result})
    )

  countVerified: (site, callback)->
    collections.subscriptions.count({siteName: site.name, context: null, verified: true}, (err, result)->
      if err
        return callback(err)
      callback(err, {no_subscribers_v: result})
    )

  countVerifiedActive: (site, callback)->
    collections.subscriptions.count({siteName: site.name, context: null, verified: true, active: true}, (err, result)->
      if err
        return callback(err)
      callback(err, {no_subscribers_va: result})
    )

  getVerified: (site, callback)->
    collections.subscriptions.find({siteName: site.name, context: null, verified: true, active: true}, callback)

  modSubscription: (site, user, callback)->
    collections.subscriptions.findOne({siteName: site.name, email: user.email, context: "*", active: true}, (err, subscription)->
      if err
        return callback(err)
      callback(null, {active: !!subscription})
    )

  addModSubscription: (site, user, callback)->
    token = util.token()
    collections.subscriptions.findAndModify(
      {siteName: site.name, email: user.email, context: "*"},
      [],
      {$set: {
          siteName: site.name
          user: user._id
          email: user.email
          context: "*"
          active: true
          verified: true
          token: token
        }
      },
      {new: true, upsert: true},
      (err, subscription)->
        if err
          return callback(err)
        callback(null, {active: !!subscription})
    )

  deleteModSubscription: (site, user, callback)->
    collections.subscriptions.findAndModify({siteName: site.name, email: user.email, context: "*"}, [], {$set: {active: false}}, {new: true}, (err, subscription)->
      if err
        return callback(err)
      callback(null, {active: false})
    )

  forConversation: (site, email, context, callback)->
    async.waterfall([
      (cb)->
        collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(context)}, cb)
      (conv, cb)->
        if conv
          collections.subscriptions.findOne({siteName: conv.siteName, email: email, context: conv._id, verified: true, active: true}, cb)
        else
          cb({notexists: true})
      (subscription, cb)->
        if !subscription
          subscription = {active: false}
        cb(null, subscription)
    ], callback)

  userSubscribeForConv: (user, site, callback)->
    debug("Subscribing user for conversations")
    token = util.token()
    async.waterfall([
      (cb)=>
        if site
          collections.subscriptions.findAndModify(
            {siteName: site.name, email: user.email, context: null},
            [],
            {$setOnInsert: {siteName: site.name, email: user.email, context: null, token: token, verified: user.verified}, $set: {user: user._id, active: true}},
            {new: true, upsert: true},
            (err, subscription, info)=>
              if !info.lastErrorObject.updatedExisting && !err && !subscription.verified
                @notifySubscriptionConv(user.email, site.name, token, (err)->
                  cb(err, subscription)
                )
              else
                cb(err, subscription)
          )
        else
          cb({sitenotexists: true})
      (subscription, cb)->
        cb(null, subscription)
    ], callback)

  userUnsubscribeForConv: (user, site, callback)->
    debug("Unsubscribing user for conversations")
    @emailUnsubscribeForConv(user.email, site, callback)

  userSubscribeForContent: (user, site, context, callback)->
    debug("Subscribing user for content")
    token = util.token()
    async.waterfall([
      (cb)->
        collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(context)}, cb)
      (conv, cb)=>
        if conv
          collections.subscriptions.findAndModify(
            {siteName: conv.siteName, email: user.email, context: conv._id},
            [],
            {$setOnInsert: {siteName: conv.siteName, email: user.email, context: conv._id, url: conv.initialUrl, token: token, verified: user.verified}, $set: {user: user._id, active: true}},
            {new: true, upsert: true},
            (err, subscription, info)=>
              if !info.lastErrorObject.updatedExisting && !err && !subscription.verified
                @notifySubscriptionContent(user.email, conv.siteName, conv.text, urls.for_model("conversation", conv, {site: site}), token, (err)->
                  cb(err, subscription)
                )
              else
                cb(err, subscription)
          )
        else
          cb({notexists: true})
      (subscription, cb)->
        cb(null, subscription)
    ], callback)

  userUnsubscribeForContent: (user, site, context, callback)->
    debug("Unsubscribing user for content")
    @emailUnsubscribeForContent(user.email, site, context, callback)

  emailSubscribeForConv: (email, site, callback)->
    debug("Subscribing with email for conversations")
    token = util.token()
    async.waterfall([
      (cb)=>
        if site
          collections.subscriptions.findAndModify(
            {siteName: site.name, email: email, context: null},
            [],
            {$setOnInsert: {siteName: site.name, email: email, context: null, token: token, verified: false}, $set: {active: true}},
            {new: true, upsert: true},
            (err, result, info)=>
              if !info.lastErrorObject.updatedExisting && !err
                @notifySubscriptionConv(email, site.name, token, (err)->
                  cb(err, result)
                )
              else
                cb(err, result)
          )
        else
          cb({sitenotexists: true})
      (subscr, cb)->
        cb(null, subscr)
    ], callback)

  emailUnsubscribeForConv: (email, site, callback)->
    debug("Unsubscribing with email for conversations")
    collections.subscriptions.update({siteName: site.name, email: email, context: null}, {$set: {active: false}}, (err, result)->
      callback(err, {active: false})
    )

  emailSubscribeForContent: (email, site, context, callback)->
    debug("Subscribing with email for content")
    token = util.token()
    async.waterfall([
      (cb)->
        collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(context)}, cb)
      (conv, cb)=>
        if conv
          collections.subscriptions.findAndModify(
            {siteName: conv.siteName, email: email, context: conv._id},
            [],
            {$setOnInsert: {siteName: conv.siteName, email: email, context: conv._id, url: conv.initialUrl, token: token, verified: false}, $set: {active: true}},
            {new: true, upsert: true},
            (err, result, info)=>
              if !info.lastErrorObject.updatedExisting && !err
                @notifySubscriptionContent(email, conv.siteName, conv._id, urls.for_model("conversation", conv, {site: site}), token, (err)->
                  cb(err, result)
                )
              else
                cb(err, result)
          )
        else
          cb({notexists: true})
      (subscr, cb)->
        cb(null, subscr)
    ], callback)

  emailUnsubscribeForContent: (email, site, context, callback)->
    debug("Unsubscribing with email for content")
    async.waterfall([
      (cb)->
        collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(context)}, cb)
      (conv, cb)->
        if conv
          collections.subscriptions.update({siteName: conv.siteName, email: email, context: conv._id}, {$set: {active: false}}, cb)
        else
          cb({notexists: true})
      (updates, info, cb)->
        cb(null, {active: false})
    ], callback)

  notifySubscriptionConv: (email, siteName, token, callback)->
    collections.jobs.addUnique({
      type: "EMAIL"
      emailType: "SUBSCRIBE_CONV"
      siteName: siteName
      to: email
    },
    {
      type: "EMAIL"
      emailType: "SUBSCRIBE_CONV"
      siteName: siteName
      to: email
      token: token
      can_reply: false
    },
    callback)

  notifySubscriptionContent: (email, siteName, conversationTitle, url, token, callback)->
    collections.jobs.addUnique({
      type: "EMAIL"
      emailType: "SUBSCRIBE_CONTENT"
      siteName: siteName
      to: email
    },
    {
      type: "EMAIL"
      emailType: "SUBSCRIBE_CONTENT"
      siteName: siteName
      conversationTitle: conversationTitle
      to: email
      token: token
      url: url
      can_reply: false
    },
    callback)

  sendMarketingEmail: (emailType, siteName, user, callback)->
    debug("send " + emailType.toUpperCase() + " email to: " + siteName + " " + user.email)
    emailObj = {
      type: "EMAIL"
      emailType: emailType
      to: user.email
      siteName: siteName
      userName: user.name
      uid: "EMAIL_" + emailType.toUpperCase() + "_to_#{user.email}"
      can_reply: true
    }
    if emailType == "NEW_SITE_WELCOME"
      emailObj.email_from = config.email.notifications.welcomeEmailFrom
      emailObj.email_reply_to = config.email.notifications.welcomeEmailFrom
      emailObj.email_cc = config.email.notifications.welcomeEmailCC
    collections.jobs.add(emailObj, ()->
      action = {}
      fieldToUpdate = "marketingEmails." + emailType.toLowerCase()
      action[fieldToUpdate] = 1
      collections.users.update({_id: user._id}, {$set: {'marketingEmails.lastSent': new Date().getTime()}, $inc: action}, callback)
    )

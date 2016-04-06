BaseCol = require("./base")
dbutil = require("./util")
sso = require("../sso")
async = require("async")
sharedUtil = require("../shared/util")
collections = require("./index").collections
logger = require("../logging").logger
pubsub = require("../pubsub")
util = require('../util')
debug = require('debug')('data:sites')
config = require("naboo").config
stripe = require("stripe")(config.stripe.secret)
moment = require('moment')

module.exports = class Sites extends BaseCol

  name: "sites"

  add: (attrs, user, callback)->
    cdate = new Date().getTime()
    attrs.created = attrs.changed = cdate
    attrs.sso = {enabled: false}
    attrs.sso.secret = sso.createSiteSecret()
    attrs.autoApprove ?= true
    attrs.user = user._id
    attrs.approvalForNew ?= 0 # 0 = auto approve, 1 = banned, 2 = manual
    attrs.theme = "auto"
    attrs.use_conv_leaderboard ?= false
    attrs.verified_leaderboard ?= false
    attrs.trusted_downvotes ?= false
    attrs.checkSpam = true
    attrs.auto_check_spam = false
    attrs.no_conversations = 0
    attrs.no_forum_conversations = 0
    attrs._v = 0
    attrs.trust_urls = true
    attrs.forum =
      enabled: true
      tags: {tree: [], set: {}}
      url: ""
      show_articles: false
      mod_create: false
    attrs.conv =
      forceId: false
      qsDefineNew: []
      useQs: false
    attrs.color =
      question: ""
      challenge: ""
    if attrs.name == "burnzone"
      callback({exists: true})
      return
    if !attrs.sso.secret
      callback({secreterror: true}, null)
      return
    attrs.points_settings =
      status_comment: "unverified",
      status_leaderboard: "verified",
      status_downvote: "trusted",
      status_upvote: "verified",
      status_flag: "trusted",
      for_comment: util.getValue("commentPointsAuthor"),
      free_challenge_count: util.getValue("freeChallenges"),
      for_challenge_winner: util.getValue("challengeWinnerPoints"),
      for_share: util.getValue("sharePoints"),
      min_bet: util.getValue("minBetPts"),
      min_bet_targeted: util.getValue("minBetPtsTargeted"),
      disable_upvote_points: false,
      disable_downvote_points: true
      ignite_create_thread: false
    attrs.premium =
      subscription:
        trial_until: moment.utc().add(util.getValue("premiumTrialDays"), "days").valueOf()
    async.waterfall([
      (cb)->
        collections.sites.insert(attrs, (err, result)->
          if err and dbutil.errDuplicateKey(err)
            err = {exists: true}
          cb(err, result?[0])
        )
      (site, cb)->
        collections.profiles.create(user, site, true, (err, profile)->
          if err
            logger.error(err)
            cb({could_not_create_profile: true}, site, profile)
          else
            cb(err, site, profile)
        )
      (site, profile, cb)->
        collections.subscriptions.sendMarketingEmail("NEW_SITE_WELCOME", site.name, user, (err)->
          if err
            return cb(err)
          cb(null, site)
        )
    ], (err, result)->
      callback(err, result)
    )

  validate: (options)->
    if !options.name
      return false
    if !options.name.match("^[a-zA-Z]+[a-zA-Z0-9]*$")
      return false
    return true

  merge: (from_name, into_name, callback)->
    collections.conversations.findIter({siteName: from_name}, (from_conv, next)->
      collections.conversations.findOne({siteName: into_name, uri: from_conv.uri}, (err, into_conv)->
        if into_conv
          # move all comments from old conversation to new conversation
          debug("move comments from #{from_name}/#{from_conv.uri} to #{into_name}/#{into_conv.uri}")
          async.series([
            (cb)->
              collections.comments.update({siteName: from_name, context: from_conv._id, parent: from_conv._id}, {$set: {parent: into_conv._id}}, {multi: true}, cb)
            (cb)->
              collections.comments.update({siteName: from_name, context: from_conv._id, "parents.0": from_conv._id}, {$set: {"parents.0": into_conv._id}}, {multi: true}, cb)
            (cb)->
              collections.comments.update({siteName: from_name, context: from_conv._id}, {$set: {siteName: into_name, context: into_conv._id}}, {multi: true}, cb)
            (cb)->
              async.parallel([
                (cb)->
                  collections.comments.count({siteName: into_name, context: into_conv._id}, cb)
                (cb)->
                  collections.comments.count({siteName: into_name, context: into_conv._id, parent: into_conv._id}, cb)
              ], (err, res)->
                [all_act, first_act] = res
                debug("update comment count: all=#{all_act}, direct=#{first_act}")
                collections.conversations.update({_id: into_conv._id}, {$set: {no_all_activities: all_act, no_activities: first_act}}, {}, cb)
              )
          ], (err)->
            debug("done moving comments for #{from_conv.uri}: #{JSON.stringify(err)}")
            next()
          )
        else
          # conversation does not exist in new site, just change the siteName of the old one
          debug("move conversation #{from_conv.uri} from #{from_name} to #{into_name}")
          async.series([
            (cb)->
              collections.conversations.update({_id: from_conv._id}, {$set: {siteName: into_name}}, {}, cb)
            (cb)->
              collections.comments.update({siteName: from_name, context: from_conv._id}, {$set: {siteName: into_name}}, {multi: true}, cb)
            (cb)->
              collections.sites.update({siteName: into_name}, {$inc: {no_conversations: 1}}, cb)
          ], (err)->
            debug("done moving conversation #{from_conv.uri}")
            next()
          )
      )
    , (err)->
      debug("done merging #{from_name} into #{into_name}")
      callback(err)
    )

  hasPremiumTrial: (site)->
    if site?.premium?.subscription?.trial_until > new Date().valueOf()
      return true
    return false

  getTrialDays: (site)->
    if collections.sites.hasPremiumTrial(site)
      return moment.utc(site.premium.subscription.trial_until).diff(moment().utc(), "days")
    return 0

  hasPremium: (site)->
    if site.premium?.subscription?.forever
      return true
    if collections.sites.hasPremiumTrial(site)
      return true
    if site.premium?.subscription?.id
      return !site.premium.subscription.expiration? ||
        site.premium.subscription.expiration > new Date().valueOf()
    return false

  addSubscription: (site, email, token, callback)->
    debug("ADD SUBSCRIPTION")
    stripe.customers.create({
      card: token
      plan: "bzpaid"
      email: email
      metadata: {siteName: site.name}
    }, (err, customer)->
      if customer
        debug("subscribed for premium: #{JSON.stringify(customer)}")
        collections.sites.modify(site.name, {"premium.subscription.id": customer.id}, callback)
      else
        debug("error adding subscription")
        callback(err)
    )

  validateSubscription: (site, callback)->
    debug("VALIDATE SUBSCRIPTION")
    if !site.premium?.subscription?.id || site.premium?.subscription?.forever
      debug("no subscription id")
      return callback(null, site)
    if site.premium?.subscription?.trial_until > new Date().valueOf()
      debug("in trial period")
      return callback(null, site)

    stripe.customers.listSubscriptions(site.premium?.subscription?.id, (err, subs)->
      debug(JSON.stringify(subs))
      if err
        debug("error talking to stripe, not changing anything")
        return callback(null, site)
      hasActive = null
      expiration = 0
      for s in subs?.data || []
        if s.status == 'active'
          hasActive = true
          if !s.canceled_at?
            expiration = null # never expires
          else
            if expiration? && expiration < s.current_period_end
              expiration = s.current_period_end
      if expiration == 0
        expiration = null
      if hasActive
        debug("updating expiration")
        collections.sites.modify(site.name, {"premium.subscription.expiration": expiration}, callback)
      else
        debug("no sub, update id")
        collections.sites.modify(site.name, {"premium.subscription.id": null}, callback)
    )

  cancelSubscription: (site, callback)->
    debug("CANCEL SUBSCRIPTION")
    if !site.premium?.subscription?.id || site.premium?.subscription?.forever
      debug("no subscription id")
      return callback(null, site)
    stripe.customers.listSubscriptions(site.premium?.subscription?.id, (err, subs)->
      active = []
      debug(subs)
      for s in subs?.data || []
        if s.status == 'active' && !s.canceled_at
          active.push(s)
      async.each(active, (sub, next)->
        stripe.customers.cancelSubscription(site.premium.subscription.id, sub.id, (err, confirm)->
          debug("canceled #{JSON.stringify(confirm)}")
          next(err)
        )
      , (err)->
        debug("CANCEL DONE")
        callback(err, site)
      )
    )

  modify: (name, attrs, callback)->
    attrs = _.pick(attrs,
      # "autoApprove",
      "approvalForNew",
      "imported_comments",
      "theme",
      "urls",
      "logo",
      "display_name",
      "avatars",
      "badges",
      "tz_name",
      "auto_check_spam",
      "use_conv_leaderboard",
      "verified_leaderboard",
      "trusted_downvotes",
      "filter_words",
      "sso.enabled",
      "sso.users_verified",
      "conv.forceId",
      "conv.qsDefineNew",
      "conv.useQs",
      "color.question",
      "color.challenge",
      "forum.enabled",
      "forum.tags",
      "forum.url",
      "forum.defsort",
      "forum.show_articles",
      "forum.mod_create",
      "forum.auto_private",
      "defCommentSort",
      "premium.subscription.id"
      "premium.subscription.expiration"
      "premium.options"
      "points_settings"
    )

    parseTags = (tags)->
      set = {}
      _.walkTree(tags, 'subtags', util.getValue('forumCategoryDepth'), (e, parent, level)->
        _.keep(e, 'subtags', 'displayName', 'imageUrl', 'description')
        if e.description
          e.description = _.str.prune(e.description, util.getValue('tagDescriptionLength'))
        displayName = e.displayName
        if !sharedUtil.validateTag(displayName)
          throw new Error('invalid_tag')
        displayName = _.str.trim(displayName)
        while(set[displayName])
          displayName = _.uniqueId("#{displayName} ")
        e.displayName = displayName
        set[e.displayName] = _.clone(e)
        if parent
          set[e.displayName].parent = parent.displayName
        if level + 1 > util.getValue('forumCategoryDepth')
          delete e.subtags
        delete set[e.displayName].subtags
      )
      return {tree: tags, set: set}

    if attrs['forum.tags']?
      try
        attrs['forum.tags'] = parseTags(attrs['forum.tags'])
      catch e
        if e.message == 'invalid_tag'
          return process.nextTick(-> callback({invalid_tag: true}))
        return process.nextTick(-> callback(e))

    if attrs["conv.qsDefineNew"]?
      if !_.isArray(attrs["conv.qsDefineNew"])
        attrs["conv.qsDefineNew"] = attrs["conv.qsDefineNew"].split("\n")
      attrs["conv.qsDefineNew"] = _.uniqStr(attrs["conv.qsDefineNew"], (elem)->
        return sharedUtil.removeWhite(elem) || null
      )
    collections.sites.findAndModify({name: name}, [], {$set: attrs}, {new: true}, (err, result)->
      callback(err, result)
    )

  removeConvReference: (site, conv, destroy, callback)->
    if !conv.show_in_forum && !destroy
      return callback(null, site)
    toSet = {$inc: {_v: 1}}
    if conv.show_in_forum
      toSet.$inc.no_forum_conversations = -1
    if destroy
      toSet.$inc.no_conversations = -1
    collections.sites.findAndModify({name: site.name}, [], toSet, {new: true}, (err, result)->
      if err
        return callback(err, null)
      pubsub.contentUpdate(site.name, null, collections.sites.toClient(result))
      callback(err, result)
    )

  addConvReference: (site, conv, callback)->
    toSet = {$inc: {no_conversations: 1, _v: 1}}
    if conv.show_in_forum
      toSet.$inc.no_forum_conversations = 1
    collections.sites.findAndModify({name: site.name}, [], toSet, {new: true}, (err, result)->
      if err
        return callback(err, null)
      pubsub.contentUpdate(site.name, null, collections.sites.toClient(result))
      callback(err, result)
    )

  convertOldTags: (tags = [])->
    if !_.isArray(tags)
      return tags
    new_tags = _.map(tags, (t)-> {displayName: t, subtags: [], imageUrl: ''})
    set = {}
    for tag in new_tags
      set[tag.displayName] = _.pick(tag, 'displayName', 'imageUrl')
    return {tree: new_tags, set: set}

  toClient: (doc)->
    if _.isArray(doc.forum.tags)
      new_tags = collections.sites.convertOldTags(doc.forum.tags)
    else
      new_tags = doc.forum.tags
    raw_badges = doc.badges || collections.profiles.getAllBadges()
    badges = {}
    for b, index in raw_badges
      badges[index] = _.pick(b, ["title", "enabled", "icon", "color_bg", "manually_assigned"])
      badges[index].badge_id = index
    if @hasPremium(doc)
      premium = _.pick(doc.premium.options || {}, ["color", "no_branding"])
    else
      premium = null
    return {
      _v: doc._v
      _id: doc.name
      name: doc.name
      auto_check_spam: doc.auto_check_spam
      display_name: doc.display_name
      logo: doc.logo
      badges: badges
      use_conv_leaderboard: doc.use_conv_leaderboard
      verified_leaderboard: doc.verified_leaderboard
      trusted_downvotes: doc.trusted_downvotes
      avatars: doc.avatars || []
      tz_name: doc.tz_name || "Etc/UTC"
      active_competition: doc.active_competition
      sso:
        enabled: doc.sso.enabled
      no_conversations: doc.no_conversations
      no_forum_conversations: doc.no_forum_conversations
      forum: _.extend({}, doc.forum, {tags: new_tags})
      defCommentSort: doc.defCommentSort
      premium: premium
    }

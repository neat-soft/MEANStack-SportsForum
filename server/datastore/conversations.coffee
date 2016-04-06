util = require("../util")
mongo = require("mongodb")
BaseCol = require("./base")
async = require("async")
dbutil = require("./util")
debug = require("debug")("data:conversations")
urlmod = require("url")
sharedUtil = require("../shared/util")
collections = require("./index").collections
logger = require("../logging").logger
pubsub = require("../pubsub")
config = require("naboo").config
akismet = require("akismet").client({blog: config.serverHost, apiKey: config.akismet_api_key})
urls = require("../interaction/urls")

module.exports = class Conversations extends BaseCol

  name: "conversations"

  enter: (site, title, id, url, options, callback)->
    if typeof(options) == 'function'
      callback = options
      options = {}

    debug("Entering conversation %s %s", id, url)
    async.waterfall([
      (cb)->
        try
          if site.conv.forceId && (!id || id == url)
            return process.nextTick(->cb({forceid: true}))
          if site.conv.useQs
            query = []
            parsedUrl = urlmod.parse(url, true)
            for key in site.conv.qsDefineNew
              if value = sharedUtil.removeWhite(parsedUrl.query[key])
                query.push("#{key}=#{encodeURIComponent(value)}")
              else
                return process.nextTick(->cb({useqs: true}))
            if query.length > 0
              query = query.join("&")
              parsedUrl.search = "?#{query}"
            url = urlmod.format(parsedUrl)
          foundUrl = false
          for u in site.urls
            urlCompare = new RegExp("^" + u.protocol.replace(/([()[{*+.$^\\|?])/g, '\\$1') + "://" + (if u.subdomains then "(.+?\\.)?" else "") + u.base.replace(/([()[{*+.$^\\|?])/g, '\\$1'), "i")
            if urlCompare.test(url)
              foundUrl = true
              break
          if !foundUrl
            return process.nextTick(->cb({sitenotexists: true}))
          if !id || id == url
            id = _.str.rtrim(url, "/") # the identifier is the url without trailing "/"
          collections.conversations.findOne({siteName: site.name, uri: id}, cb)
        catch e
          logger.error(e)
          cb(e)
      (conv, cb)=>
        if conv
          return callback(null, conv)
        if process.env.NODE_ENV != "development" && process.env.NODE_ENV != "test"
          if !url
            return cb({invalidurl: true})
          else if site.trust_urls
            return cb()
          else
            return util.urlExists(url, cb)
        else
          cb()
      (cb)=>
        title = _.str.prune(title, util.getValue("maxForumTitleLength"))
        @insertConversation(site, {text: title}, id, url, "ARTICLE", site.user, options, cb)
      (conv, info, cb)=>
        if info?.new && !options.silent
          @postInsertConversation(site, conv, cb)
        else
          debug("skipping notifications: silent=#{options.silent}")
          cb(null, conv)
      ], callback)

  insertConversation: (site, attrs, id, url, type, author, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    _id = dbutil.id()
    id ||= "__forum_#{_id.toHexString()}"
    cdate = new Date().getTime()
    attrsToUpdate =
      _id: _id
      _v: 0
      uri: id
      siteName: site.name
      created: cdate
      changed: cdate
      no_comments: 0
      no_challenges: 0
      no_questions: 0
      no_all_comments: 0
      no_activities: 0
      no_all_activities: 0
      latest_activity: cdate
      activity_rating: if type == "FORUM" then util.getValue("forumRatingComment") else 0
      level: 0
      initialUrl: url
      slug: "/#{_id.toHexString()}"
      text: attrs.text
      approved: if type == "ARTICLE" then true else (attrs.approved || false)
      spam: false
      type: type
      request_data: {}
      show_in_forum: !options.imported && (if type == 'ARTICLE' then !!site.forum.show_articles else true)
    if author._id || author.toHexString
      attrs.author = author._id || author
    else
      # author contains guest info
      attrs.guest = author
    if type == "FORUM"
      attrsToUpdate.tags = attrs.tags
      attrsToUpdate.private = attrs.private
    if attrs.comment
      attrsToUpdate.comment = attrs.comment
    collections.conversations.insertOrModify({siteName: site.name, uri: id}, attrsToUpdate, null, null, callback)

  postInsertConversation: (site, conv, callback)->
    async.parallel([
      (cbp)=>
        @notifyNewConversation(site, conv, cbp)
      (cbp)->
        collections.sites.addConvReference(site, conv, cbp)
    ], (err, results)->
      pubsub.contentUpdate(conv.siteName, null, collections.sites.toClient(results[1]), "site")
      callback(null, conv)
    )

  notifyNewConversation: (site, conv, callback)->
    pubsub.contentUpdate(conv.siteName, null, collections.conversations.toClient(conv), "context")
    # New forum topics are announced when the first comment in the forum is announced
    if conv.type == "ARTICLE"
      collections.jobs.add({
        type: "NEW_CONVERSATION"
        siteName: conv.siteName
        uri: conv.uri
        url: urls.for_model("conversation", conv, {site: site})
        text: conv.text
        conv: conv
        context: conv._id
        uid: "NEW_CONVERSATION_#{conv._id.toHexString()}"
      }, callback)
    else
      callback()

  changes: (contextId, since, callback)->
    query =
      _id: dbutil.idFrom(contextId)
      changed: { $gt: since }
    collections.conversations.find(query, callback)

  findContextById: (site, id, allowNotApproved, callback)->
    if allowNotApproved
      collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(id), deleted: {$ne: true}}, callback)
    else
      collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(id), deleted: {$ne: true}, approved: true}, callback)

  getSiteContextsPaged: (site, attrs, moderator, field, direction, from, limit, callback)->
    query = {siteName: site.name}
    if attrs.tags && !_.isEmpty(attrs.tags)
      query.tags = attrs.tags
    if attrs.tfrom
      query._id ?= {}
      query._id.$gt = dbutil.idFromTime(parseInt(attrs.tfrom))
    if attrs.tuntil
      query._id ?= {}
      query._id.$lt = dbutil.idFromTime(parseInt(attrs.tuntil))
    if !attrs.articles_only
      query.show_in_forum = true
      if attrs.forums_only
        query.type = "FORUM"
    else
      query.type = "ARTICLE"
    if !moderator
      query.deleted = {$ne: true}
      query.approved = true
    if field == 'activity_rating'
      # This field uses the improved sort function
      # TODO all functions that use sortTopLevel should use the new one
      sort = [['activity_rating', direction], ['latest_activity', direction], ['_id', direction]]
      @multipleSortTopLevel(query, sort, from, limit || util.getValue("commentsPerPage"), callback)
    else
      @sortTopLevel(query, field, direction, from, limit || util.getValue("commentsPerPage"), callback)

  add: (site, user, attrs, callback)->
    async.waterfall([
      (cb)=>
        @insertConversation(site, attrs, null, site.forum.url, "FORUM", user, cb)
      (conv, info, cb)=>
        if conv.approved
          @postInsertConversation(site, conv, cb)
        else
          cb(null, conv)
    ], callback)

  processForumTags: (site, incoming_tags)->
    if !_.isArray(incoming_tags)
      incoming_tags = [incoming_tags]
    else
      incoming_tags = _.uniq(incoming_tags)
    incoming_tags = _.first(_.intersection(_.keys(site.forum.tags.set), incoming_tags), util.getValue("maxConvTags"))
    new_tags = []
    if _.isArray(site.forum.tags)
      site.forum.tags = collections.sites.convertOldTags(site.forum.tags)
    for tag in incoming_tags
      # allow selection of groups but avoid adding the same tag more than once
      if tag in new_tags
        continue
      ctag = site.forum.tags.set[tag]
      # avoid adding a child if the parent has already been selected
      if _.find(new_tags, (t)-> ctag.parent == t)
        continue
      while(ctag)
        new_tags.push(ctag.displayName)
        ctag = site.forum.tags.set[ctag.parent]
    return new_tags

  addForum: (site, user, profile, attrs, request_data, callback)->
    if _.isFunction(request_data)
      callback = request_data
      request_data = {}
    if site.forum.mod_create && !collections.profiles.isModerator(profile)
      return process.nextTick(-> callback({needs_moderator: true}))
    attrs.top = true
    conversation = null
    comment_id = dbutil.id()
    async.waterfall([
      (cb)=>
        attrs.forum.tags = @processForumTags(site, attrs.forum.tags)
        conv_attrs = _.pick(attrs.forum, "text", "tags", "private")
        conv_attrs.approved = false
        conv_attrs.comment = comment_id
        collections.conversations.add(site, user, conv_attrs, cb)
      (conv, cb)=>
        conversation = conv
        attrs.parent = conv._id
        attrs._id = comment_id
        collections.comments.addComment(site, user, profile, attrs, request_data, cb)
      (comment, cb)=>
        if comment.approved
          collections.conversations.findById(conversation._id, cb)
        else
          cb(null, conversation)
    ], (err, conv)->
      if err && conversation
        return collections.conversations.remove({_id: conversation._id}, (errremove)->
          callback(err)
        )
      callback(err, conv)
    )

  approve: (site, conv_id, callback)->
    async.waterfall([
      (cb)->
        collections.conversations.findAndModify({siteName: site.name, _id: dbutil.idFrom(conv_id), approved: false}, [], {$set: {approved: true}, $inc: {_v: 1}}, {new: true}, cb)
      (conv, info, cb)=>
        if conv?
          @postInsertConversation(site, conv, cb)
        else
          cb()
    ], callback)

  markConvDeleted: (site, conv_id, callback)->
    async.waterfall([
      (cb)->
        collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(conv_id), approved: true, deleted: {$ne: true}}, cb)
      (conv, cb)->
        if !conv
          return cb({notexists: true})
        modifications =
          $set:
            deleted: true
            deleted_data: {text: conv.text, author: conv.author}
          $unset:
            text: 1
            ptext: 1
            author: 1
          $inc:
            _v: 1
        if conv.guest
          modifications.$set.deleted_data.guest = conv.guest
        collections.conversations.findAndModify({siteName: site.name, _id: conv._id, deleted: {$ne: true}}, [], modifications, {new: true}, cb)
      (conv, info, cb)=>
        if !conv
          return cb({notexists: true})
        pubsub.contentUpdate(site.name, conv._id, collections.conversations.toClient(conv))
        cb(null, conv)
    ], callback)

  delete: (site, conv_id, callback)->
    debug("Deleting conversation #{if conv_id.toHexString? then conv_id.toHexString() else conv_id}")
    async.waterfall([
      (cb)=>
        @markConvDeleted(site, conv_id, cb)
      (conv, cb)->
        collections.sites.removeConvReference(site, conv, false, (err, site)->
          cb(err, conv)
        )
    ], callback)

  # This destroys the conversation and all the comments inside.
  # Called when the initiating comment is deleted.
  destroyApproved: (site, conv_id, callback)->
    debug("Destroying approved conversation #{if conv_id.toHexString? then conv_id.toHexString() else conv_id}")
    conv_id = dbutil.idFrom(conv_id)
    async.waterfall([
      (cb)=>
        @markConvDeleted(site, conv_id, cb)
      (conv, cb)->
        collections.sites.removeConvReference(site, conv, true, (err, site)->
          cb(err, conv)
        )
      (conv, cb)->
        collections.comments.remove({context: conv._id}, cb)
      (no_removed, cb)->
        collections.convprofiles.remove({context: conv_id}, cb)
      (no_removed, cb)->
        collections.conversations.remove({_id: conv_id}, cb)
        pubsub.destroyContent(site.name, conv_id)
    ], (err)->
      callback(err)
    )

  # Can destroy only unapproved conversations. Called when the initiating comment is destroyed.
  destroy: (site, id, callback)->
    debug("Destroying conversation #{if id.toHexString? then id.toHexString() else id}")
    async.waterfall([
      (cb)=>
        collections.conversations.findAndRemove({siteName: site.name, _id: dbutil.idFrom(id), approved: false}, [], (err, result)->
          cb(err, result)
        )
      (conv, cb)=>
        if conv
          cb(null, conv)
        else
          cb({notexists: true})
      (conv, cb)->
        if !conv.show_in_forum
          return cb(null, conv)
        collections.sites.update({name: site.name}, {$inc: {no_forum_conversations: -1, _v: 1}}, (err, result)->
          if err
            return cb(err, null)
          cb(err, conv)
        )
    ], callback)

  countFilter: (site, attrs, callback)->
    query = {siteName: site.name, approved: true, deleted: {$ne: true}}
    # We support only one tag for now
    if attrs.tags
      query.tags = attrs.tags
    collections.conversations.count(query, callback)

  showInForum: (site, id, include, callback)->
    async.waterfall([
      (cb)->
        collections.conversations.findAndModify({siteName: site.name, type: "ARTICLE", _id: dbutil.idFrom(id), deleted: {$ne: true}}, [], {$set: {show_in_forum: !!include}, $inc: {_v: 1}}, {new: true}, cb)
      (conv, info, cb)->
        collections.sites.update({name: site.name}, {$inc: {no_forum_conversations: (if include then 1 else -1), _v: 1}}, (err, result)->
          if err
            return cb(err, null)
          cb(err, conv)
        )
    ], (err, result)->
      if err
        return callback(err)
      if result
        pubsub.contentUpdate(site.name, result._id, collections.conversations.toClient(result), {type: 'context'})
      callback(null, result)
    )

  private: (site, id, is_private, callback)->
    async.waterfall([
      (cb)->
        collections.conversations.findAndModify({siteName: site.name, _id: dbutil.idFrom(id), deleted: {$ne: true}}, [], {$set: {private: !!is_private}, $inc: {_v: 1}}, {new: true}, cb)
    ], (err, result)->
      if err
        return callback(err)
      if result
        pubsub.contentUpdate(site.name, result._id, collections.conversations.toClient(result), {type: 'context'})
      callback(null, result)
    )

  topCommenters: (site, id, limit, callback)->
    collections.comments.aggregate([
      {$match: {siteName: site.name, context: dbutil.idFrom(id), deleted: {$exists: false}}}
      {$group: {_id: "$author", count: {$sum: 1}}}
      {$sort: {count: -1}}
      {$project: {_id: "$_id"}}
      {$limit: Math.max(limit, util.getValue('topForumUsers'))}
    ], callback)

  toClient: (doc, moderator, client)->
    if !doc.approved && !moderator
      return {approved: false}
    if doc.deleted && !moderator
      doc = _.pick(doc, ["_id",
        "_v",
        "deleted",
        "type",
        "siteName",
        "no_all_activities",
        "created",
        "changed",
        "latest_activity",
        "initialUrl"
      ])
    else
      doc = _.pick(doc, ["_id",
        "_v",
        "deleted",
        "created",
        "changed",
        "no_comments",
        "no_challenges",
        "no_questions",
        "no_all_activities",
        "siteName",
        "uri",
        "initialUrl",
        "text",
        "spam",
        "approved",
        "type",
        "deleted_data"
        "tags",
        "private",
        "activity_rating",
        "latest_activity",
        "comment",
        "author",
        "guest",
        "show_in_forum"
      ])
    if doc.comment?._id
      doc.comment = collections.comments.toClient(doc.comment, moderator, client)
    return doc

_.extend(Conversations.prototype, require("./mixins").sorting)

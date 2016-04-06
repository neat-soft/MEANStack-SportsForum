async = require("async")
mongo = require("mongodb")
BaseCol = require("./base")
util = require("../util")
dbutil = require("./util")
sso = require("../sso")
debug = require("debug")("data:users")
sharedUtil = require("../shared/util")
config = require("naboo").config
Twit = require("twit")
moment = require("moment")

collections = require("./index").collections

third_party_images = ["facebook", "disqus"]

# Use the private token to sign email addresses and other stuff.
# Private token is not known by the user

module.exports = class Users extends BaseCol

  name: "users"

  defaultSubscription:
    own_activity: true
    auto_to_conv: false
    name_references: true
    marketing: true

  fetchByIdArray: (ids, callback)->
    collections.users.find({_id: {$in: _.map(ids, (id)-> dbutil.idFrom(id))}}, callback)

  findForSession: (id, callback)->
    collections.users.findOne({_id: dbutil.idFrom(id), deleted: {$ne: true}}, callback)

  login: (email, password, callback)->
    collections.users.findOne({email: email, type: "own", deleted: {$ne: true}}, (err, user)->
      if (err)
        return callback(err)
      if (!user)
        return callback({notexists: true})
      password = util.hashPassword(password, String(user.created))
      if (user.password != password)
        return callback({invalid_password: true})
      return callback(null, user)
    )

  extractSocialData: (type, profile, callback)->
    if type == 'facebook'
      util.fbreq("GET", "/v2.1/me/friends", {
        access_token: profile.access_token
      }, (code, headers, data)->
        profile.friends = _.omit(data, 'paging')
        callback(null)
      )
    else if type == 'twitter'
      t = new Twit({
        consumer_key: config.twKey
        consumer_secret: config.twSecret
        access_token: profile.access_token
        access_token_secret: profile.access_secret
      })
      t.get("friends/list", {}, (err, data, res)->
        friends = []
        for u in data?.users || []
          friends.push(_.omit(u, "status"))
        profile.friends = friends
        t.get("followers/list", {}, (err, data, res)->
          followers = []
          for u in data.users || []
            followers.push(_.omit(u, "status"))
          profile.followers = followers
          callback(null)
        )
      )
    else
      callback(null)

  getSocialFriends: (user, type, callback)->
    fids = []
    console.log("searching #{type} friends for #{user.email}")
    console.log("user: #{JSON.stringify(user.logins_profiles?[type], null, 4)}")
    for f in user?.logins_profiles?[type]?.friends?.data || []
      fids.push(f.id)
    if fids.length < 1
      console.log("no friends")
      return callback(null)
    console.log("searching ids: #{JSON.stringify(fids)}")
    query = {}
    query["logins.#{type}"] = {$in: fids}
    collections.users.findIter(query, (friend, next)->
      console.log("found: #{friend.email}")
      next(null)
    , (err)->
      console.log("DONE")
      callback(err)
    )

  login3rdParty: (type, profile, callback)->
    the_user = null
    async.waterfall([
      (cb)->
        collections.users.extractSocialData(type, profile, cb)
      (cb)->
        toset = {}
        toset["logins_profiles.#{type}"] = _.omit(profile, '_raw', 'access_token', 'access_secret')
        toset["logins_usernames.#{type}"] = profile.username
        collections.users.findAndModify(_.object([["logins.#{type}", profile.id]]), [], {$set: toset}, {new: true}, cb)
      (user, info, cb)=>
        if user
          if user.deleted
            return cb({deleted: true})
          return cb(null, user)
        email = (profile.emails?[0]?.value || "").toLowerCase()
        if email
          cdate = new Date().getTime()
          imageType = if type in third_party_images then type else "gravatar"
          attrs =
            site: "burnzone"
            type: "own"
            name: profile.displayName
            email: email
            emailHash: util.md5Hash(email)
            created: cdate
            changed: cdate
            imageType: imageType
            subscribe: @defaultSubscription
            verified: !!email
            customData: false
            logins: _.object([[type, profile.id]])
            vtoken: util.token()
          attrs.logins_usernames = _.object([[type, profile.username]])
          collections.users.insert(attrs, (err, inserted)->
            if dbutil.errDuplicateKey(err)
              return cb({alreadyexists: true})
            cb(err, inserted?[0])
          )
        else
          cb({noemail: true})
      (user, cb)=>
        the_user = user
        @findUsersToMerge(the_user, type, profile, cb)
    ], (err)->
      callback(err, the_user)
    )

  findUsersToMerge: (user, login_3rdp_type, login_3rdp_profile, callback)->
    async.waterfall([
      (cb)->
        # Old accounts
        collections.users.findOne({type: login_3rdp_type, serviceId: login_3rdp_profile.id, deleted: {$ne: true}, _id: {$ne: user._id}}, cb)
      (existing, cb)=>
        if existing
          @queueMerge(existing, user, cb)
        else
          cb(null, null)
      (job, cb)=>
        # New accounts that have this login attached
        query = {deleted: {$ne: true}, _id: {$ne: user._id}}
        query["logins.#{login_3rdp_type}"] = login_3rdp_profile.id
        collections.users.findIter(query, (found_user, next)=>
          @queueMerge(found_user, user, next)
        , cb)
    ], ->
      # We're hiding the error here
      callback()
    )

  attach3rdPartyLogin: (user, type, profile, callback)->
    updt_user = null
    if !user.verified
      return process.nextTick(-> callback({not_verified: true}))
    async.waterfall([
      (cb)->
        collections.users.extractSocialData(type, profile, cb)
      (cb)->
        toset = {}
        toset["logins.#{type}"] = profile.id
        toset["logins_usernames.#{type}"] = profile.username
        toset["logins_profiles.#{type}"] = _.omit(profile, '_raw', 'access_token', 'access_secret')
        collections.users.findAndModify({_id: user._id}, [], {$set: toset}, {new: true}, (err, result)->
          cb(err, result)
        )
      (result, cb)=>
        updt_user = result
        @findUsersToMerge(user, type, profile, cb)
    ], (err)->
      if err
        if dbutil.errDuplicateKey(err)
          return callback({login_exists: true})
        return callback(err)
      callback(null, updt_user)
    )

  remove3rdPartyLogin: (user, type, callback)->
    modif =
      $unset: _.object([["logins.#{type}", 1]])
    if user.imageType == type
      modif.$set = {imageType: 'gravatar'}
    collections.users.findAndModify({_id: user._id}, [], modif, {new: true}, (err, result)->
      callback(err, result)
    )

  # We are searching for:
  # old-style users (only facebook, google, twitter)
  # sso users (TODO)
  # imported users - old style guests
  # guest comments - new style guests
  forMerge: (user, callback)->
    async.parallel([
      (cb)->
        collections.users.findToArray({email: user.email, type: {$in: ["facebook", "google", "twitter"]}, merged_into: {$exists: false}, deleted: {$ne: true}}, cb)
      # TODO add sso
      # (cb)->
      #   collections.users.findToArray({email: user.email, type: "sso", merged_into: {$exists: false}, deleted: {$ne: true}}, cb)
      (cb)->
        # Merging the counts for old and new style of guest commenting
        # imported users were created for a short time form Wordpress anonymous commenters
        # guest users are inlined in guest comments
        async.parallel([
          (cbp)->
            # guest comments (old style)
            collections.users.count({email: user.email, type: "imported", merged_into: {$exists: false}, deleted: {$ne: true}}, cbp)
          (cbp)->
            # guest comments (new style)
            collections.comments.count({"guest.email": user.email}, cbp)
        ], (err, results)->
          if err
            return cb(err)
          [imported, guest] = results
          if imported + guest > 0
            return cb(null, [{type: "guest", email: user.email, count: imported + guest}])
          cb(null, [])
        )
      # (cb)->
      #   collections.users.aggregate([
      #     {$match: {email: user.email, type: "imported", merged_into: {$exists: false}, deleted: {$ne: true}}}
      #     # {$project: {email: 1, type: 1, site: 1}}
      #     {$group: {_id: {email: "$email", type: "$type", site: "$site"}, count: {$sum: 1}}}
      #     {$project: {email: "$_id.email", type: "$_id.type", site: "$_id.site", _id: 0}}
      #   ], cb)
    ], (err, results)->
      if err
        return callback(err)
      callback(null, _.flatten(results))
    )

  queueMerge: (from_desc, to, callback)->
    async.parallel([
      (cb)->
        # We're getting only one of 'imported', 'guest', but we have to handle them both
        if from_desc.type == "guest"
          return collections.jobs.add({type: "MERGE_USERS", from: _.extend(_.pick(from_desc, "type", "_id", "site", "email"), {type: "imported"}), into: to}, callback)
        cb()
      (cb)->
        collections.jobs.add({type: "MERGE_USERS", from: _.pick(from_desc, "type", "_id", "site", "email"), into: to}, callback)
    ], callback)

  ensureUser: (query, attrs, callback)->
    cdate = new Date().getTime()
    userData =
      email: attrs.email
      emailHash: attrs.emailHash
      imageType: attrs.imageType
      imageUrl: attrs.imageUrl
      name: attrs.name
    isNew = false
    async.waterfall([
      (cb)->
        collections.users.findOrCreate(query, _.extend({}, query, _.omit(attrs, _.keys(userData))), cb)
      (user, info, cb)->
        isNew = !info.lastErrorObject.updatedExisting
        if user.customData
          return cb(null, user)
        collections.users.findAndModify({_id: user._id, customData: false}, [], {$set: userData}, {new: true}, (err, modifuser)->
          cb(err, modifuser || user)
        )
      (user, cb)=>
        if isNew
          @sendVerification(user, cb)
        else
          cb(null, user)
    ], callback)

  sendVerification: (user, callback)->
    if !user.verified && user.email && !user.imported_from
      debug("queueing email verification job for #{JSON.stringify(user, null, 2)}")
      collections.jobs.add({type: "EMAIL", emailType: "VERIFICATION", to: user.email, token: user.vtoken, can_reply: false}, (err, result)->
        callback(err, user)
      )
    else
      callback(null, user)

  verify: (token, callback)->
    async.waterfall([
      (cb)->
        collections.users.findAndModify({vtoken: token, verified: false}, [], {$set: {verified: true, verified_time: new Date()}}, {new: true}, (err, user)->
          if !user
            return cb({notexists: true})
          cb(err, user)
        )
      (user, cb)->
        collections.subscriptions.update({user: user._id}, {$set: {email: user.email, verified: true}}, {multi: true}, (err)->
          cb(err, user)
        )
    ], callback)

  # Options:
  #   send_verification: send the verification email (will be sent if the user
  #                      is not verified)
  ensureUserAutoUpdate: (query, attrs, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    options.send_verification ?= true
    attrs_to_update = ['email', 'emailHash', 'imageType', 'imageUrl', 'name', 'changed', 'vtoken']
    isNew = false
    async.waterfall([
      (cb)->
        collections.users.findAndModify(query
          , []
          , {
            $setOnInsert: _.extend({}, _.omit(query, attrs_to_update), _.omit(attrs, attrs_to_update)),
            $set: _.pick(attrs, attrs_to_update)
          }
          , {new: true, upsert: true}
          , cb)
      (user, info, cb)=>
        isNew = !info.lastErrorObject.updatedExisting
        if attrs.verified && !user.verified
          return collections.users.findAndModify({_id: user._id}, [], {$set: {verified: true}}, {new: true}, (err, result)->
            cb(err, result)
          )
        cb(null, user)
      (user, cb)=>
        if isNew && options.send_verification
          @sendVerification(user, cb)
        else
          cb(null, user)
    ], callback)

  loginSSO: (site, message, callback)->
    async.waterfall([
      (cb)->
        if !site.sso.enabled
          debug('sso not enabled for site %s', site.name)
          return cb({notenabled: true})
        profile = sso.verifyCredentials(message, site)
        if profile
          debug("logged in with profile: #{JSON.stringify(profile, null, 2)}")
          cb(null, profile, site)
        else
          debug("SSO login failed for #{site.name}: '#{message}'")
          cb({invalid:true})
      (profile, site, cb)=>
        cdate = new Date().getTime()
        if !profile.id || !profile.name
          cb({nouser: true})
          return
        email = (profile.email || "").toLowerCase()
        verified = site.sso.users_verified
        if profile.email_verified?
          verified = !!profile.email_verified
        attrs =
          name: profile.name
          email: email
          emailHash: util.md5Hash(email)
          created: cdate
          changed: cdate
          serviceId: profile.id
          type: "sso"
          site: site.name
          subscribe: @defaultSubscription
          verified: verified
          customData: false
        if profile.imageUrl
          attrs.imageType = "custom"
          attrs.imageUrl = profile.imageUrl
        else
          attrs.imageType = "gravatar"
          attrs.imageUrl = null
        if !attrs.verified
          attrs.vtoken = util.token()
        @ensureUserAutoUpdate({serviceId: profile.id, type: "sso", site: site.name}, attrs, {send_verification: false}, cb)
    ], callback)

  createOwnAccount: (name, email, password, verified, callback)->
    cdate = new Date().getTime()
    email = email.toLowerCase()
    if _.isFunction(verified)
      callback = verified
      verified = false
    passhash = util.hashPassword(password, String(cdate))
    attrs =
      site: "burnzone"
      type: "own"
      name: name
      email: email
      emailHash: util.md5Hash(email)
      password: passhash
      imageType: "gravatar"
      created: cdate
      changed: cdate
      completed: if password then true else false
      subscribe: @defaultSubscription
      verified: verified
      vtoken: util.token()
      customData: false
    async.waterfall([
      (cb)->
        collections.users.insert(attrs, (err, users)->
          if err
            if dbutil.errDuplicateKey(err)
              cb({exists: true}, null)
            else
              cb(err, null)
          else
            cb(null, users?[0])
        )
      (user, cb)=>
        @sendVerification(user, cb)
    ], callback)

  markForReset: (email, callback)->
    email = email.toLowerCase()
    pwreset = util.token()
    user = null
    async.waterfall([
      (cb)->
        collections.users.findAndModify({email: email, type: "own", deleted: {$exists: false}, merged_into: {$exists: false}}, [], {$set: {pwreset: pwreset}}, {new: true}, (err, user)->
          cb(err, user)
        )
      (user, cb)->
        if !user then return cb({notexists: true})
        collections.jobs.add({
          type: "EMAIL"
          emailType: "RESET_PASSWORD"
          token: pwreset
          to: email
          can_reply: false
        }, cb)
    ], callback)

  validateResetToken: (token, callback)->
    async.waterfall([
      (cb)->
        collections.users.findOne({pwreset: token}, cb)
      (user, cb)->
        if !user then return cb({notexists: true})
        cb(null, user)
    ], callback)

  resetPassword: (token, password, callback)->
    async.waterfall([
      (cb)=>
        @validateResetToken(token, cb)
      (user, cb)->
        password = util.hashPassword(password, String(user.created))
        collections.users.findAndModify({pwreset: token}, [], {$unset: {pwreset: 1}, $set: {password: password, completed: true}}, {new: true}, cb)
      (user, info, cb)->
        cb(null, user)
    ], callback)

  modify: (userOrId, attrs, password, callback)->
    if _.isFunction(password)
      callback = password
      password = null
    attrs = _.pick(attrs, "name", "email", "imageType", "imageUrl", "subscribe", "notif_read_at", "language", "comments", "signature")
    if attrs.email
      attrs.email = attrs.email.toLowerCase()
    emailChanged = false
    nameChanged = false
    oldEmail = ""
    oldUser = null
    async.waterfall([
      (cb)=>
        if userOrId._id
          cb(null, userOrId)
        else
          collections.users.findOne({_id: dbutil.idFrom(userOrId), deleted: {$exists: false}, merged_into: {$exists: false}}, cb)
      (user, cb)=>
        if user
          oldUser = user
          if user.type == "imported"
            cb({notallowed: true})
            return
          if user.type == 'sso'
            delete attrs.name
            delete attrs.email
            delete attrs.password
          else
            if !attrs.name || !sharedUtil.removeWhite(attrs.name)
              return cb({invalid_name: true})
            if user.type == "own" && password
              attrs.password = util.hashPassword(password, String(user.created))
              attrs.completed = true
            if attrs.imageType
              attrs.imageType = @imageType(user, attrs.imageType)
            if attrs.email
              if !sharedUtil.validateEmail(attrs.email)
                return cb({email_incorrect: true})
              attrs.emailHash = util.md5Hash(attrs.email)
            attrs.customData = true
            if attrs.email && attrs.email != user.email
              emailChanged = true
              oldEmail = user.email
              attrs.verified = false
              attrs.vtoken = util.token()
            if attrs.name != user.name
              nameChanged = true
          if _.size(attrs) == 0
            cb(null, user)
            return
          cdate = new Date().getTime()
          incDate = Math.max(cdate - user.changed, 0)
          collections.users.findAndModifyWTime({_id: user._id}, [], {$set: attrs}, {new: true}, (err, user)->
            cb(err, user)
          )
        else
          cb({notexists: true}, user)
      (user, cb)->
        if emailChanged
          collections.subscriptions.update({user: user._id, email: oldEmail}, {$set: {email: user.email, verified: false}}, {multi: true}, (err)->
            cb(err, user)
          )
        else
          cb(null, user)
      (user, cb)->
        if nameChanged
          collections.jobs.add({type: "UPDATE_USER_PROFILES", userId: user._id}, (err, result)->
            cb(err, user)
          )
        else
          cb(null, user)
      (user, cb)=>
        if emailChanged
          @sendVerification(user, cb)
        else
          cb(null, user)
      (user, cb)->
        if !user.subscribe.auto_to_conv && oldUser.subscribe.auto_to_conv
          collections.subscriptions.update({user: user._id, active: true, context: {$ne: '*'}}, {$set: {active: false}}, {multi: true}, (err, no_updated)->
            cb(err, user)
          )
        else
          cb(null, user)
    ], (err, result)=>
      if err
        if dbutil.errDuplicateKey(err)
          callback({exists: true}, null)
        else
          callback(err)
      else if !result
        callback({notexists: true})
      else
        callback(null, result)
    )

  mergeGuests: (into_id, callback)->
    into_id = dbutil.idFrom(into_id)
    into_user = null
    async.waterfall([
      (cb)->
        collections.users.findById(into_id, cb)
      (user, cb)->
        if !user
          return cb({notexists: true})
        into_user = user
        collections.comments.update({"guest.email": into_user.email}, {$set: {author: into_id}, $unset: {guest: 1}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.comments.update({"challenged.guest.email": into_user.email, "challenger.author": {$ne: into_id}}, {$set: {"challenged.author": into_id}, $unset: {"challenged.guest": 1}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.comments.update({"answer.guest.email": into_user.email}, {$set: {"answer.author": into_id}, $unset: {"answer.guest": 1}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.likes.update({"cguest.email": into_user.email, user: {$ne: into_id}}, {$set: {cauthor: into_id}, $unset: {cguest: 1}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.votes.update({"challenged_guest.email": into_user.email, challenger_author: {$ne: into_id}}, {$set: {challenged_author: into_id}, $unset: {challenged_guest: 1}}, {multi: true}, cb)
      (no_updated, info, cb)->
        cb()
    ], callback)

  merge: (from_id, into_id, options, callback)->
    # Disables the user that we want to merge from so that there can be no logins with that user
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    into_id = dbutil.idFrom(into_id)
    from_id = dbutil.idFrom(from_id)
    from_user = into_user = null

    ignore_duplicates = (cb)->
      return (err, no_updated, info)->
        if err
          if dbutil.errDuplicateKey(err)
            return cb(null, no_updated, info)
          return cb(err)
        cb(err, no_updated, info)

    async.waterfall([
      (cb)->
        async.parallel([
          (cbpu)->
            collections.users.findOne({_id: into_id, deleted: {$ne: true}}, cbpu)
          (cbpu)->
            collections.users.findAndModify({_id: from_id, deleted: {$ne: true}}, [], {$set: {deleted: true, merging: true}}, {new: true}, (err, result)->
              cbpu(err, result)
            )
        ], cb)
      (users, cb)->
        [into_user, from_user] = users
        if !into_user || !from_user
          return cb({notexists: true})
        if !into_user.verified && !options.force_unverified
          return cb({not_verified: true})
        # attach login
        if from_user.type in ['facebook', 'google', 'twitter']
          collections.users.attach3rdPartyLogin(into_user, from_user.type, {id: from_user.serviceId}, cb)
        else if from_user.logins
          loginsToSet = _.extend({}, from_user.logins, into_user.logins)
          toSet = {}
          for own login_service, profile_id of loginsToSet
            toSet["logins.#{login_service}"] = profile_id
          collections.users.findAndModify({_id: into_user._id}, [], {$set: toSet}, {new: true}, (err, updt_into_user)->
            if err
              return cb(err)
            into_user = updt_into_user
            cb(null, updt_into_user)
          )
        else
          cb(null, into_user)
      (user, cb)->
        collections.comments.update({author: from_id}, {$set: {author: into_id}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.comments.update({"challenged.author": from_id, "challenger.author": {$ne: into_id}}, {$set: {"challenged.author": into_id}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.comments.update({"challenger.author": from_id, "challenged.author": {$ne: into_id}}, {$set: {"challenger.author": into_id}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.comments.update({"answer.author": from_id}, {$set: {"answer.author": into_id}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.likes.update({user: from_id, cauthor: {$ne: into_id}}, {$set: {user: into_id}}, {multi: true}, ignore_duplicates(cb))
      (no_updated, info, cb)->
        collections.likes.update({cauthor: from_id, user: {$ne: into_id}}, {$set: {cauthor: into_id}}, {multi: true}, ignore_duplicates(cb))
      (no_updated, info, cb)->
        # Should not own likes for own challenges
        collections.votes.update({user: from_id, challenged_author: {$ne: into_id}, challenger_author: {$ne: into_id}}, {$set: {user: into_id}}, {multi: true}, ignore_duplicates(cb))
      (no_updated, info, cb)->
        collections.votes.update({challenged_author: from_id, challenger_author: {$ne: into_id}, user: {$ne: into_id}}, {$set: {challenged_author: into_id}}, {multi: true}, ignore_duplicates(cb))
      (no_updated, info, cb)->
        collections.votes.update({challenger_author: from_id, challenged_author: {$ne: into_id}, user: {$ne: into_id}}, {$set: {challenger_author: into_id}}, {multi: true}, ignore_duplicates(cb))
      (no_updated, info, cb)->
        # Migrate all sites to the new user
        collections.sites.update({user: from_id}, {$set: {user: into_id}}, {multi: true}, cb)
      (no_updated, info, cb)->
        collections.profiles.merge(from_user, into_user, cb)
      (cb)->
        collections.convprofiles.merge(from_user, into_user, cb)
      (cb)->
        collections.competition_profiles.merge(from_user, into_user, cb)
      (cb)->
        collections.subscriptions.update({user: from_id}, {$set: {user: into_id}}, {multi: true}, ignore_duplicates(cb))
      (no_updated, info, cb)->
        # In order to keep the old user we're setting the email field to a random meaningless value
        collections.users.update({_id: from_id}, {$unset: {logins: 1}, $set: {old_email: from_user.email, email: "email@#{util.uid()}", merged_into: into_id}}, cb)
      (no_updated, info, cb)->
        cb()
    ], callback)

  verifiedOrMod: (user, profile)->
    return user?.verified || profile?.permissions.moderator

  imageUrl: (user)->
    if user.imageType == "facebook"
      return "https://graph.facebook.com/#{user.logins.facebook}/picture"
    else if user.imageType == "disqus"
      return "https://disqus.com/api/users/avatars/#{user.logins_usernames["disqus"]}.jpg"
    else if user.imageType == "gravatar"
      return "http://www.gravatar.com/avatar/#{user.emailHash}"
    else if user.imageType == "custom"
      return user.imageUrl
    else
      return ""

  imageType: (user, type)->
    if user.type == "sso"
      type = "custom"
    else if user.type in ["anonymous", "imported"]
      type = "gravatar"
    else if type in third_party_images && !user.logins[type]
      type = "gravatar"
    else if !(type in third_party_images) && type != "custom"
      type = "gravatar"
    return type

  toClient: (user, toUser)->
    attrs = ["_id", "name", "emailHash", "type", "imageType", "imageUrl", "completed", "logins", "notif_read_at", "verified", "language", "comments", "logins_usernames", "signature"]
    if toUser?._id.equals(user._id)
      attrs.push("email")
    else if user.type != "own"
      attrs.push("serviceId")
    result = _.pick(user, attrs)
    return result

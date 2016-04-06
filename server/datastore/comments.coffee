async = require("async")
util = require("../util")
dbutil = require("./util")
mongo = require("mongodb")
cf = require("./../contentfilter")
ContentFilter = require("./../contentfilter")
sharedUtil = require("../shared/util")
collections = require("./index").collections
pubsub = require("../pubsub")
BaseCol = require("./base")
debug = require("debug")("data:comments")
config = require("naboo").config
moment = require("moment")
akismet = require("akismet").client({blog: config.serverHost, apiKey: config.akismet_api_key})
urls = require("../interaction/urls")

logger = require("../logging").logger

module.exports = class Comments extends BaseCol

  name: "comments"

  # QUERYING BY CATEGORIES AND PARENT

  getActivitiesOfParent: (type, parent, allowNotApproved, callback)->
    query = {parent: dbutil.idFrom(parent)}
    if type
      query.type = type
    if !allowNotApproved
      query.approved = true
    collections.comments.findOne(query, callback)

  getActivitiesOfParentPaged: (type, parent, field, direction, from, allowNotApproved, callback)->
    if from
      from = dbutil.idFrom(from)
    query = {parent: dbutil.idFrom(parent)}
    if !allowNotApproved
      query.approved = true
    if type
      query.type = type
    if field == "slug" && direction == 1
      collections.comments.sortChronologically(
        query,
        from,
        util.getValue("commentsPerPage"),
        callback)
    else
      collections.comments.sortTopLevel(
        query,
        field,
        dir,
        from,
        util.getValue("commentsPerPage"),
        callback)

  getTopActivitiesPaged: (type, context, field, direction, from, allowNotApproved, callback)->
    if from
      from = dbutil.idFrom(from)
    query = {context: dbutil.idFrom(context), level: 1}
    if !allowNotApproved
      query.approved = true
    if type
      query.type = type
    if field == "slug" && direction == 1
      collections.comments.sortChronologically(
        query,
        from,
        util.getValue("commentsPerPage"),
        callback)
    else
      collections.comments.sortTopLevel(
        query,
        field,
        dir,
        from,
        util.getValue("commentsPerPage"),
        callback)

  getTopActivities: (type, context, allowNotApproved, callback)->
    query = {context: dbutil.idFrom(context), level: 1}
    if type
      query.type = type
    if !allowNotApproved
      query.approved = true
    collections.comments.find(query, callback)

  getChallengesPaged: (context, field, dir, from, allowNotApproved, callback)->
    @getTopActivitiesPaged("CHALLENGE", context, field, dir, from, allowNotApproved, callback)

  getChallenges: (context, field, dir, from, allowNotApproved, callback)->
    @getTopActivities("CHALLENGE", context, allowNotApproved, callback)

  getCommentsPaged: (context, field, dir, from, allowNotApproved, callback)->
    @getTopActivitiesPaged("COMMENT", context, field, dir, from, allowNotApproved, callback)

  getComments: (context, field, dir, from, allowNotApproved, callback)->
    @getTopActivities("COMMENT", context, allowNotApproved, callback)

  getQuestionsPaged: (context, field, dir, from, allowNotApproved, callback)->
    @getTopActivitiesPaged("QUESTION", context, field, dir, from, allowNotApproved, callback)

  getQuestions: (context, field, dir, from, allowNotApproved, callback)->
    @getTopActivities("QUESTION", context, allowNotApproved, callback)

  getCommentsOfParentPaged: (parent, field, dir, from, allowNotApproved, callback)->
    @getActivitiesOfParentPaged("COMMENT", parent, field, dir, from, allowNotApproved, callback)

  getCommentsOfParent: (parent, field, dir, from, allowNotApproved, callback)->
    @getActivitiesOfParent("COMMENT", parent, allowNotApproved, callback)

  getAllCommentsPaged: (context, field, direction, from, allowNotApproved, callback)->
    if from
      from = dbutil.idFrom(from)
    query = {}
    if !allowNotApproved
      query.approved = true
    if field == "slug" && direction == 1
      collections.comments.sortChronologically(
        _.extend(query, {
          type: "COMMENT"
          cat: "COMMENT"
          context: dbutil.idFrom(context)
        }),
        from,
        util.getValue("commentsPerPage"),
        callback)
    else
      collections.comments.sortKeepTree(
        _.extend(query, {
          type: "COMMENT"
          cat: "COMMENT"
          context: dbutil.idFrom(context)
          level: 1
        }),
        field,
        direction,
        from,
        util.getValue("commentsPerPage"),
        1,
        callback)

  getAllComments: (context, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.find({type: "COMMENT", cat: "COMMENT", context: dbutil.idFrom(context)}, callback)
    else
      collections.comments.find({type: "COMMENT", cat: "COMMENT", context: dbutil.idFrom(context), approved: true}, callback)

  getAllChallengeCommentsPaged: (challenge, field, direction, from, allowNotApproved, callback)->
    if from
      from = dbutil.idFrom(from)
    query = {}
    if !allowNotApproved
      query.approved = true
    if field == "slug" && direction == 1
      collections.comments.sortChronologically(
        _.extend(query, {
          type: "COMMENT"
          cat: "CHALLENGE"
          "parents.1": dbutil.idFrom(challenge)
        }),
        from,
        util.getValue("commentsPerPage"),
        callback)
    else
      collections.comments.sortKeepTree(
        _.extend(query, {
          type: "COMMENT"
          cat: "CHALLENGE"
          "parents.1": dbutil.idFrom(challenge)
          level: 2
        }),
        field,
        direction,
        from,
        util.getValue("commentsPerPage"),
        2,
        callback)

  getAllChallengeComments: (challenge, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.find({type: "COMMENT", cat: "CHALLENGE", "parents.1": dbutil.idFrom(challenge)}, callback)
    else
      collections.comments.find({type: "COMMENT", cat: "CHALLENGE", "parents.1": dbutil.idFrom(challenge), approved: true}, callback)

  getAllQuestionCommentsPaged: (question, field, direction, from, allowNotApproved, callback)->
    if from
      from = dbutil.idFrom(from)
    query = {}
    if !allowNotApproved
      query.approved = true
    if field == "slug" && direction == 1
      collections.comments.sortChronologically(
        _.extend(query, {
          type: "COMMENT"
          cat: "QUESTION"
          "parents.1": dbutil.idFrom(question)
        }),
        from,
        util.getValue("commentsPerPage"),
        callback)
    else
      collections.comments.sortKeepTree(
        _.extend(query, {
          type: "COMMENT"
          cat: "QUESTION"
          "parents.1": dbutil.idFrom(question)
          level: 2
        }),
        field,
        direction,
        from,
        util.getValue("commentsPerPage"),
        2,
        callback)

  getAllQuestionComments: (question, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.find({type: "COMMENT", cat: "QUESTION", "parents.1": dbutil.idFrom(question)}, callback)
    else
      collections.comments.find({type: "COMMENT", cat: "QUESTION", "parents.1": dbutil.idFrom(question), approved: true}, callback)

  # END QUERYING BY CATEGORIES AND PARENT

  sortSlugDsc: (queryTop, from, limit, callback)->
    @sortKeepTree(queryTop, "slug", -1, from, limit, 1, callback)

  sortByLikes: (queryTop, direction, from, limit, callback)->
    @sortKeepTree(queryTop, "no_likes", direction, from, limit, 1, callback)

  # returns trees of comments by sorting only the top level comments
  # used for sorting by slug, no_likes
  sortKeepTree: (queryTop, field, direction, from, limit, topParentIndex, callback)->
    topElems = []
    elements = []
    topLevelStartFrom = null

    pushElements = (cb)->
      return (err, cursor)->
        if err
          return cb(err)
        cursor.toArray((error, elems)->
          if !err
            elements = elements.concat(elems)
          cb(err)
        )

    pushTopElems = (cb)->
      return (err, cursor)->
        if cursor
          return cursor.toArray((err, elems)->
            if err
              return cb(err)
            topElems = topElems.concat(elems)
            cb()
          )
        cb()

    initialSort = (done)=>
      async.waterfall([
        (cb)=>
          if topLevelStartFrom
            if topLevelStartFrom._id
              return cb(null, topLevelStartFrom)
            return @findOne({_id: topLevelStartFrom}, cb)
          else
            return cb(null, topLevelStartFrom)
        (doc, cb)=>
          topLevelStartFrom = doc
          if topLevelStartFrom
            @prepareTopLevelQuery(queryTop, field, direction, topLevelStartFrom)
          @find(queryTop, {sort: [[field, direction], ["_id", 1]], limit: limit - elements.length}, pushTopElems(cb))
        (cb)=>
          if topLevelStartFrom && elements.length + topElems.length < limit
            @prepareTopLevelQuery(queryTop, field, direction, topLevelStartFrom, true)
            @find(queryTop, {sort: [[field, direction], ["_id", 1]], limit: limit - topElems.length - elements.length}, pushTopElems(cb))
          else
            cb()
        (cb)=>
          if topElems.length == 0
            return cb(null, topElems)
          i = 0
          async.whilst(
            ->
              # executed before each iteration, we can run some helper logic here
              if elements.length < limit && i < topElems.length
                elements.push(topElems[i++])
                while elements[elements.length - 1].no_comments == 0 && i < topElems.length
                  elements.push(topElems[i++])
                return elements.length < limit && i <= topElems.length
              return false
            (cbi)=>
              localQuery = {
                context: elements[elements.length - 1].context,
                slug: {$gt: elements[elements.length - 1].slug},
                parents: elements[elements.length - 1]._id
              }
              if queryTop.approved?
                localQuery.approved = queryTop.approved
              @find(localQuery, {sort: {slug: 1}, limit: limit - elements.length}, pushElements(cbi))
            (err)->
              cb(err)
          )
      ], done)

    sortFrom = (done)=>
      # if from is id of a comment at level > 0 then we have to fetch the remaining comments of the top level parent first
      # getting the top level parent from parents
      async.waterfall([
        (cb)=>
          @findOne({_id: dbutil.idFrom(from)}, cb)
        (doc, cb)=>
          if !doc
            topLevelStartFrom = null
            return cb()
          if doc.level == 1
            topLevelStartFrom = doc
          else
            topLevelStartFrom = doc.parents[topParentIndex]
          localQuery = {
            context: doc.context,
            slug: {$gt: doc.slug},
            parents: topLevelStartFrom._id || topLevelStartFrom
          }
          if queryTop.approved?
            localQuery.approved = queryTop.approved
          @find(localQuery, {sort: {slug: 1}, limit: limit}, pushElements(cb))
        (cb)->
          if elements.length >= limit
            cb()
          else
            initialSort(cb)
      ], done)
    if from
      sortFrom((err)->
        callback(err, elements)
      )
    else
      initialSort((err)->
        callback(err, elements)
      )

  insertComment: (site, attrs, parent, user, profile, request_data, callback)->
    text = attrs.text
    question = attrs.question
    bet = attrs.bet
    approved = attrs.approved
    options = attrs.options || {}
    spam = attrs.spam
    questionPointsOffered = attrs.questionPointsOffered
    promotePoints = attrs.promotePoints

    if question
      level = 1
    else
      level = parent.level + 1
    parentId = parent._id
    cdate = attrs.cdate || new Date().getTime()
    id = attrs._id || dbutil.id()
    cf = new ContentFilter(site.filter_words) # create content filter based on site custom words
    text = cf.filterCommentText(text)
    parents = (parent.parents || []).concat(parentId)
    old = attrs
    attrs =
      _id: id
      _v: 0
      text: text
      ptext: cf.processCommentText(text)
      approved: !!(approved && !cf.containsBadWords(text) && !spam)
      siteName: parent.siteName
      context: parent.context || parent._id
      contextType: parent.contextType || (if parent.type == "ARTICLE" then "ARTICLE" else "FORUM")
      uri: parent.uri
      initialUrl: parent.initialUrl
      parent: parentId
      level: level
      created: cdate
      changed: cdate
      no_likes: 0
      no_likes_down: 0
      no_comments: 0
      no_all_comments: 0
      rating: 0
      parentSlug: (parent.parentSlug || "/") + parentId.toHexString() + "/"
      slug: "#{parent.slug}/#{id.toHexString()}"
      parents: parents
      type: if question then "QUESTION" else if bet then "BET" else "COMMENT"
      finished: false
      locked_finish: false
      order_time: cdate.toString() + "0"
      spam: spam
      request_data: request_data
      forum: attrs.forum
    attrs.promote = options.promote ? false
    if attrs.promote
      attrs.promotePoints = promotePoints
      attrs.promoter = user._id
    if question
      attrs.questionPointsOffered = questionPointsOffered

    # set attrs for bets
    if old.bet_type == 'open'
      old.users = []
    if bet
      ratio = old.ratio_accepted / old.ratio_joined
      points = old.points
      tpts_av = Math.floor(points * ratio)
      pts_tuser = site.points_settings.min_bet_targeted
      _.extend(attrs, {
        bet_type: old.bet_type
        bet_joined_points: _.object([[user._id.toHexString(), old.points]])
        bet_accepted_points: {}
        bet_ratio_joined: old.ratio_joined
        bet_ratio_accepted: old.ratio_accepted
        bet_targeted: old.users
        bet_accepted: []
        bet_declined: []
        bet_forfeited: []
        bet_claimed: []
        bet_joined: [user._id]
        bet_end_date: old.end_date
        bet_start_forf_date: old.start_forf_date
        bet_winning_side: ''
        bet_total_points: old.points
        bet_rolledback: false
        bet_status: 'open'
          # possible values:
          #
          # open - users can accept/decline
          # closed - users cannot accept/decline anymore
          # forf - users can forfeit
          # forf_closed - forfeiting is closed and the bet must be resolved manually by a mod
          # resolved - the winning side has been decided
          # resolving_pts - the points are currently being computed and awardeed to winners
          # resolved_pts - the points has been computed and awarded to winners. This is the final state

        bet_tpts_joined: points # total points (sum) offered/risked by users who joined the bet
        bet_tpts_accepted: 0 # total points (sum) risked by users who accepted the bet (opposing the joined side)
        bet_tpts_av: tpts_av # total points available to accept: bet_tpts_joined - bet_tpts_accepted
        bet_pts_tuser: pts_tuser # reserved points per targeted user. The minimum amount of points that a targeted user can risk
        bet_tpts_av_tuser: if old.users.length == 0 then 0 else Math.floor(tpts_av - (old.users.length - 1) * pts_tuser)
                                                                                                      # This is the amount that the next targeted user can accept
        bet_tpts_av_ntusers: if old.users.length == 0 then Math.floor(points * ratio) else Math.floor(tpts_av - old.users.length * pts_tuser) # total points available for the next user who wasn't targeted
        bet_points_resolved: {}
        bet_notif_unresolved: false
        bet_notif_remind_forf: false
        bet_requires_mod: false
      })
      if old.max_points_user
        attrs.bet_pts_max_user = old.max_points_user
      if !attrs.bet_start_forf_date
        attrs.bet_start_forf_date = attrs.bet_end_date

    # pick up import info
    if old.imported_from
      _.extend(attrs, _.pick(old, "imported_from", "imported_id"))
      attrs.imported_dummy = null
    else
      # generate an unique ID to satisfy the index (imported_from, imported_id, imported_dummy)
      attrs.imported_dummy = dbutil.id()
    old = null

    if user._id
      attrs.author = user._id
    else
      # user contains guest info
      attrs.guest = user

    if question
      attrs.cat = "QUESTION"
      attrs.ends_on = cdate + util.getValue("questionTime")
    else if parent.type == "CHALLENGE"
      attrs.cat = "CHALLENGE"
    else
      attrs.cat = parent.cat || "COMMENT"
    if level == 1
      attrs.catParent == id
    else
      attrs.catParent = parent.catParent || parentId
    collections.comments.insert(attrs, (err, comments)->
      if err
        return callback(err, null, null)
      callback(err, parent, comments)
    )

  postInsertComment: (site, parent, comments, user, callback)->
    comment = comments[0]
    async.parallel([
      (cb)=>
        if comment.approved
          async.series([
            (cbs)=>
              if comment.forum
                collections.conversations.approve(site, comment.context, cbs)
              else
                cbs()
            (cbs)=>
              async.parallel([
                (cbp)=>
                  @updateParentsForNew(comment, cbp)
                (cbp)=>
                  @updatePointsNewComment(site, parent, comment, (if user._id then user else null), cbp)
                (cbp)=>
                  @notifyNewComment(comment, parent, false, cbp)
              ], cbs)
          ], (err, results)->
            cb(err, comment)
          )
        else
          collections.jobs.add({
            type: "NEW_PENDING_COMMENT"
            comment: comment
            siteName: comment.siteName
            context: comment.context
            url: urls.for_model("comment", comment, {site: site})
            uid: "NEW_PENDING_COMMENT_#{comment._id.toHexString()}"
          },
          ->
            cb(null, comment)
          )
      (cb)->
        if user._id && user.subscribe.auto_to_conv
          collections.subscriptions.userSubscribeForContent(user, site, comment.context, (err)->
            if err
              logger.error(err, {stage: 'add_comment_user_subscribe_content_no_conv', comment: comment})
            cb()
          )
        else
          cb()
    ], (err)->
      callback(err, comment)
    )

  incrementPoints: (txn_data, user, site, conversation, value, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    options.profile ?= true
    options.convprofile ?= true
    options.competition ?= true
    # normalize IDs (we might get passed full objects)
    if user._id
      user = user._id
    if txn_data.source?._id
      txn_data.source = txn_data.source._id
    async.waterfall([
      (cb)->
        if !options.profile
          return cb()
        cond = {user: user, siteName: site}
        if options.must_have_points && value < 0
          cond.points = {$gte: -value}
        collections.profiles.update(cond, {$inc: {points: value}}, (err, no_updated)->
          if no_updated == 0
            return cb({notenoughpoints: true})
          cb(err)
        )
      (cb)->
        async.parallel([
          (cbp)->
            txn = _.extend({}, txn_data, {
              user: user
              siteName: site
              conversation: conversation
              value: value
            })
            collections.transactions.record(txn, cbp)
          # (cbp)->
          #   #console.log("updating #{user} #{site} - #{value}")
          #   if !options.profile
          #     return cbp()
          #   collections.profiles.update({user: user, siteName: site}, {$inc: {points: value}}, cbp)
          (cbp)->
            if !options.convprofile
              return cbp()
            #console.log("updating #{user} #{conversation} - #{value}")
            collections.convprofiles.updateOrCreate({user: user, context: conversation}, {$inc: {points: value}}, (err, res)->
              #console.log("\terror: #{err} res: #{res}")
              #collections.convprofiles.forConversation(user, conversation, (err, p)->
              #  console.log("*** got convprof: #{JSON.stringify(p)}")
              #)
              cbp(err, res)
            )
          (cbp)->
            if !options.competition
              return cbp()
            now = moment().utc().toDate()
            collections.competitions.findIter({site: site, start: {$lte: now}, end: {$gt: now}}, (comp, cbd)->
              async.waterfall([
                (cbw)->
                  if !comp.social_share
                    # give points in competition, social sharing not required
                    return cbw(null, true)
                  debug("competition requires social share, checking")
                  collections.shares.findOne({siteName: site, user: user, when: {$gte: comp.start, $lt: comp.end}}, (err, share)->
                    if share
                      debug("found share #{share.share_id} on #{share.network}")
                    else
                      debug("no shares between: #{comp.start} and #{comp.end}")
                    cbw(null, !!share)
                  )
                (givePoints, cbw)->
                  if givePoints
                    debug("creating profile for user %j on competition %j", user, comp)
                    collections.competition_profiles.updateOrCreate({user: user, competition: comp._id}, {$inc: {points: value}}, cbw)
                  else
                    debug("no points awarded")
                    cbw(null)
              ], cbd)
            , cbp)
        ], cb)
    ], callback)

  updatePointsNewComment: (site, parent, comment, user, callback)->
    if comment.cat == "CHALLENGE"
      async.waterfall([
        (cb)->
          if parent.challenger
            cb(null, parent)
          else
            collections.comments.findOne({_id: comment.catParent}, cb)
        (challenge, cb)=>
          if !challenge || challenge.deleted
            return cb()
          async.parallel([
            (cbchallenger)=>
              if !challenge.challenger.author
                return cbchallenger()
              @incrementPoints({source: user, type: "CHALLENGE_REPLY", ref: comment._id}, challenge.challenger.author, challenge.siteName, challenge.context, util.getValue("commentInOwnChallengePoints"), cbchallenger)
            (cbchallenged)=>
              if !challenge.challenged.author
                return cbchallenged()
              @incrementPoints({source: user, type: "CHALLENGE_REPLY", ref: comment._id}, challenge.challenged.author, challenge.siteName, challenge.context, util.getValue("commentInOwnChallengePoints"), cbchallenged)
          ], cb)
      ], callback)
    else if comment.type == "QUESTION"
      if user
        # user is not guest
        @incrementPoints({source: user, type: "QUESTION", ref: comment._id}, user._id || user, comment.siteName, comment.context, util.getValue("questionPoints"), callback)
      else
        callback()
    else if comment.cat == "QUESTION" && comment.level == 2
      async.waterfall([
        (cb)->
          collections.comments.findOne({_id: comment.catParent}, cb)
        (question, cb)=>
          if !question.author
            return cb()
          if comment.author?.equals(question.author) # question author does not get points if he responds to himself
            return cb()
          @incrementPoints({source: user, type: "ANSWER", ref: comment._id}, question.author, question.siteName, question.context, util.getValue("answerPointsAsker"), cb)
      ], callback)
    else if user
      # not guest
      @incrementPoints({source: user, type: "COMMENT", ref: comment._id}, user._id || user, comment.siteName, comment.context, site.points_settings.for_comment, callback)
    else
      callback()

  # update points (award/retract) for a "share" action on a given conversation
  # return the niumber of points awarded (if negative, the points were retracted)
  updatePointsShareComment: (user, site, context, item, givePoints, callback)->
    addedPoints = site.points_settings.for_share
    if !givePoints
      addedPoints = -addedPoints
    @incrementPoints({source: user, type: "SHARE", ref: item._id || item}, user._id || user, site.name, context, addedPoints, (err)->
      callback(err, addedPoints)
    )

  validateNewBet: (site, attrs, user, callback)->
    now = moment()
    async.waterfall([
      (cb)->
        if !(attrs.bet_type in ['open', 'targeted_open', 'targeted_closed'])
          return cb({bet_invalid_type: true})
        if !(attrs.points > 0)
          return cb({bet_invalid_points_value: true})
        if !(attrs.ratio_joined > 0 && attrs.ratio_accepted > 0)
          return cb({bet_invalid_ratio: true})
        if attrs.points < site.points_settings.min_bet
          return cb({bet_invalid_points_value: true})
        if attrs.end_date < now.valueOf() + util.getValue('minBetPeriod')
          return cb({bet_invalid_date: true})
        if attrs.start_forf_date && attrs.start_forf_date < attrs.end_date
          return cb({bet_invalid_start_forf_date: true})
        if !_.isArray(attrs.users)
          return cb({bet_invalid_users: true})
        if attrs.users.length > 0
          for i in [0..attrs.users.length - 1]
            attrs.users[i] = dbutil.idFrom(attrs.users[i])
            if !attrs.users[i]
              return cb({bet_invalid_users_value: true})
            if attrs.users[i].equals(user._id)
              return cb({bet_cannot_target_self: true})
        ratio = attrs.ratio_accepted / attrs.ratio_joined
        if (attrs.bet_type == 'targeted_open' || attrs.bet_type == 'targeted_closed')
          if site.points_settings.min_bet_targeted * attrs.users.length > Math.floor(attrs.points * ratio)
            return cb({bet_invalid_points_value: true})
        if attrs.max_points_user && attrs.max_points_user < Math.min(site.points_settings.min_bet_targeted, site.points_settings.min_bet)
          return cb({bet_invalid_points_value: true})
        cb()
      (cb)=>
        # TODO something faster
        collections.profiles.count({siteName: site.name, user: {$in: attrs.users}}, cb)
      (users_count, cb)->
        if users_count != attrs.users.length
          #TODO use relevant error here
          return cb({bet_users_nonexistent: true})
        cb()
      ], callback)

  incrementBetPoints: (siteName, user, comment_id, points, context_id, callback)->
    @incrementPoints({source: user, type: 'JOIN_BET', ref: comment_id}, user, siteName, context_id, -points, {must_have_points: true, convprofile: false, competition: false}, (err)->
      callback(err)
    )

  incrementBetAcceptPoints: (siteName, user, comment_id, points, context_id, callback)->
    @incrementPoints({source: user, type: 'ACCEPT_BET', ref: comment_id}, user, siteName, context_id, -points, {must_have_points: true, convprofile: false, competition: false}, (err)->
      callback(err)
    )

  incrementPtsBetTie: (siteName, user, comment_id, points, context_id, callback)->
    @incrementPoints({source: user, type: 'ROLLBACK_BET', ref: comment_id}, user, siteName, context_id, points, {convprofile: false, competition: false}, (err)->
      callback(err)
    )

  incrementPtsBetWon: (siteName, user, comment_id, points, context_id, callback)->
    @incrementPoints({source: user, type: 'WIN_BET', ref: comment_id}, user, siteName, context_id, points, {}, (err)->
      callback(err)
    )

  incrementPtsBetBack: (siteName, user, comment_id, points, context_id, callback)->
    @incrementPoints({source: user, type: 'GIVE_BACK_REMAINING_BET', ref: comment_id}, user, siteName, context_id, points, {}, (err)->
      callback(err)
    )

  acceptBet: (site, context, user, comment_or_id, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    comment = null
    now = moment.valueOf()
    points = options.points
    targeted = null
    async.waterfall([
      (cb)->
        if comment_or_id._id
          return cb(null, comment_or_id)
        collections.comments.findOne({_id: dbutil.idFrom(comment_or_id)}, cb)
      (result, cb)->
        comment = result
        if !comment? || comment.type != 'BET' || !comment.approved || comment.deleted
          return cb({notexists: true})
        if comment.bet_status != 'open'
          return cb({denied: true})
        if comment.author.equals?(user._id)
          return cb({user_is_author:true})
        if points < site.points_settings.min_bet
          return cb({invalid_points_value: true})
        if comment.bet_tpts_av < 2 * site.points_settings.min_bet && points != comment.bet_tpts_av
          return cb({invalid_points_value: true})
        if comment.bet_pts_max_user && comment.bet_pts_max_user < points
          if !(comment.bet_tpts_av < 2 * site.points_settings.min_bet && points == comment.bet_tpts_av)
            return cb({invalid_points_value: true})
        targeted = _(comment.bet_targeted).find((t)-> t.equals(user._id))?
        if targeted
          if points > comment.bet_tpts_av_tuser
            return cb({invalid_points_value: true})
        else
          if comment.bet_type == 'targeted_closed'
            return cb({denied: true})
          if points > comment.bet_tpts_av_ntusers
            return cb({invalid_points_value: true})
        if context
          comment.context = context
          return cb(null, comment)
        util.load_field(comment, 'context', collections.conversations, {required: true}, cb)
      (comment, cb)=>
        @incrementBetAcceptPoints(site.name, user, comment._id, points, comment.context._id, (err)->
          cb(err, comment)
        )
      (comment, cb)->
        if targeted
          dec_tpts_av_tuser = dec_tpts_av_ntusers = Math.max(0, points - comment.bet_pts_tuser)
        else
          dec_tpts_av_tuser = 0
          dec_tpts_av_ntusers = points
        collections.comments.findAndModify(
          {
            _id: comment._id,
            bet_accepted: {$ne: user._id},
            bet_declined: {$ne: user._id},
            bet_status: 'open',
            bet_tpts_av: {$gte: points},
            bet_tpts_av_tuser: {$gte: dec_tpts_av_tuser},
            bet_tpts_av_ntusers: {$gte: dec_tpts_av_ntusers}
          },
          [],
          {
            $set: _.object([["bet_accepted_points.#{user._id.toHexString()}", points]]),
            $addToSet: {bet_accepted: user._id},
            $inc: {
              _v: 1,
              bet_tpts_av: -points,
              bet_tpts_accepted: points,
              bet_tpts_av_tuser: -dec_tpts_av_tuser,
              bet_tpts_av_ntusers: -dec_tpts_av_ntusers
            },
          },
          {new: true},
          (err, c)->
            if err
              return cb(err, null)
            if !c
              return cb({conflict: true}, null)
            cb(err, c)
        )
      (comment, cb)=>
        @notifyBetAccepted(comment, user, points, (err)->
          cb(null, comment)
        )
      (comment, cb)=>
        if comment.bet_tpts_av == 0
          return @endBet(comment, {force: true}, cb)
        cb(null, comment)
    ], callback)

  declineBet: (site, context, user, comment_or_id, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    comment = null
    now = moment().valueOf()
    async.waterfall([
      (cb)->
        if comment_or_id._id
          return cb(null, comment_or_id)
        collections.comments.findOne({_id: dbutil.idFrom(comment_or_id)}, cb)
      (result, cb)->
        comment = result
        if !comment? || comment.type != 'BET' || !comment.approved || comment.deleted
          return cb({notexists: true})
        if comment.bet_status != 'open'
          return cb({denied: true})
        if context
          comment.context = context
          return cb(null, comment)
        util.load_field(comment, 'context', collections.conversations, {required: true}, cb)
      (comment, cb)->
        collections.comments.findAndModify(
          {_id: comment._id, bet_declined: {$ne: user._id}, bet_accepted: {$ne: user._id}, bet_targeted: user._id, bet_status: 'open'}
          [],
          {
            $addToSet: {bet_declined: user._id},
            $inc: {
              _v: 1,
              bet_tpts_av_tuser: comment.bet_pts_tuser,
              bet_tpts_av_ntusers: comment.bet_pts_tuser
            },
          },
          {new: true},
          (err, c)->
            if err
              return cb(err, null)
            if !c
              return cb({conflict: true}, null)
            cb(err, c)
        )
      (comment, cb)=>
        @notifyBetDeclined(comment, user, (err)->
          cb(null, comment)
        )
    ], callback)

  forfeitBet: (site, context, user, comment_or_id, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    now = moment().valueOf()
    async.waterfall([
      (cb)->
        if comment_or_id._id
          return cb(null, comment_or_id)
        collections.comments.findOne({_id: dbutil.idFrom(comment_or_id)}, cb)
      (comment, cb)->
        if !comment? || comment.type != 'BET' || !comment.approved || comment.deleted
          return cb({notexists: true})
        if comment.bet_status != 'forf'
          return cb({denied: true})
        if context
          comment.context = context
          return cb(null, comment)
        util.load_field(comment, 'context', collections.conversations, {required: true}, cb)
      (comment, cb)->
        collections.comments.findAndModify(
          {_id: comment._id, bet_status: 'forf', bet_claimed: {$ne: user._id}, $or: [{bet_joined: user._id}, {bet_accepted: user._id}]}
          [],
          {$addToSet: {bet_forfeited: user._id}, $inc: {_v: 1}},
          {new: true},
          (err, comment)->
            cb(err, comment)
        )
      (comment, cb)=>
        if !comment
          return cb({conflict: true}, null)
        return cb(null, comment)
      (comment, cb)=>
        @notifyBetForfeited(comment, user, (err)->
          cb(null, comment)
        )
      (comment, cb)=>
        if !comment.bet_requires_mod
          if @betRequiresMod(comment)
            return @markRequiresMod(comment, cb)
          if @computeBetWinningSide(comment) != 'undecided'
            return @endForfBet(comment, {force: true}, cb)
        cb(null, comment)
    ], callback)

  claimBet: (site, context, user, comment_or_id, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    now = moment().valueOf()
    async.waterfall([
      (cb)->
        if comment_or_id._id
          return cb(null, comment_or_id)
        collections.comments.findOne({_id: dbutil.idFrom(comment_or_id)}, cb)
      (comment, cb)->
        if !comment? || comment.type != 'BET' || !comment.approved || comment.deleted
          return cb({notexists: true})
        if comment.bet_status != 'forf'
          return cb({denied: true})
        if context
          comment.context = context
          return cb(null, comment)
        util.load_field(comment, 'context', collections.conversations, {required: true}, cb)
      (comment, cb)->
        collections.comments.findAndModify(
          {_id: comment._id, bet_status: 'forf', bet_forfeited: {$ne: user._id}, $or: [{bet_joined: user._id}, {bet_accepted: user._id}]}
          [],
          {$addToSet: {bet_claimed: user._id}, $inc: {_v: 1}},
          {new: true},
          (err, comment)->
            cb(err, comment)
        )
      (comment, cb)=>
        if !comment
          return cb({conflict: true}, null)
        if !comment.bet_requires_mod && @betRequiresMod(comment)
          return @markRequiresMod(comment, cb)
        cb(null, comment)
      (comment, cb)=>
        @notifyBetClaimed(comment, user, (err)->
          cb(null, comment)
        )
    ], callback)

  markRequiresMod: (comment, callback)->
    debug('mark comment requires mod', comment._id)
    collections.comments.findAndModify(
      {_id: comment._id, bet_status: 'forf', bet_requires_mod: false},
      [],
      {$set: {bet_requires_mod: true, bet_notif_remind_forf: true}, $inc: {_v: 1}},
      {new: true},
      (err, result)->
        if result
          return callback(err, result)
        callback(err, comment)
    )

  addComment: (site, user, profile, attrs, request_data, callback)->
    attrs._id ?= dbutil.id()
    if _.isFunction(request_data)
      callback = request_data
      request_data = {}
    if !attrs.top && attrs.question
      return process.nextTick(-> callback({invalid: true}))
      context = null
    async.waterfall([
      (cb)=>
        # check if user is allowed to comment
        collections.profiles.hasStatus(profile, site.points_settings.status_comment, (err, can_comment)->
          if !can_comment
            return cb({low_status: true})
          cb(null)
        )
      (cb)=>
        if attrs.bet
          return @validateNewBet(site, attrs, user, cb)
        cb()
      (cb)=>
        if attrs.top
          collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(attrs.parent)}, cb)
        else
          collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(attrs.parent), approved: true}, cb)
      (parent, cb)=>
        if !parent
          return cb({invalid_parent: true})
        if parent.deleted
          return cb({invalid_parent: true})
        if !parent.approved && !(attrs.forum && attrs._id.equals(parent.comment))
          return cb({invalid_parent: true})
        if profile
          return cb(null, parent, profile)
        if parent.type == 'QUESTION' && attrs.bet
          return cb({notsupported: true})
        if !user._id
          # we don't create profiles for guest users
          return cb(null, parent, null)
        collections.profiles.create(user, site, (err, profile)->
          if !profile
            cb({invalid_profile: true})
          else
            cb(err, parent, profile)
        )
      (parent, profile, cb)=>
        if site.checkSpam && config.checkSpam && !attrs.force_approved && site.auto_check_spam
          @checkSpam((if attrs.forum then "#{attrs.forum.text} #{attrs.text}" else attrs.text), parent.initialUrl, user.name, request_data.ip, request_data.user_agent, (err, spam)->
            cb(err, parent, profile, spam)
          )
        else
          cb(null, parent, profile, false)
      (parent, profile, spam, cb)=>
        @profileApproval(site, null, user, profile, (err, approved)=>
          cb(err, parent, profile, spam, approved)
        )
      (parent, profile, spam, approved, cb)=>
        attrs.spam = spam
        if attrs.force_approved
          attrs.approved = true
        else
          attrs.approved = approved
          if !attrs.approved?
            return cb({notallowed: true})
        cb(null, parent, profile, spam)
      (parent, profile, spam, cb)=>
        if parent.context
          context = parent.context
        else
          context = parent._id
        if attrs.options?.promote
          @checkSufficientPromotePoints(context, attrs.promotePoints, (err)=>
            cb(err, parent, profile, spam)
          )
        else
          cb(null, parent, profile, spam)
      (parent, profile, spam, cb)=>
        cost = 0
        if attrs.options
          if attrs.options.promote
            cost -= attrs.promotePoints ? 0
        if attrs.question
          if !attrs.questionPointsOffered then attrs.questionPointsOffered = 0
          cost -= attrs.questionPointsOffered
        if cost != 0
          # XXX FIXME ref should point to comment not yet inserted
          @incrementPoints({source: user, type: "SELF_PROMOTE", ref: null}, user, site.name, attrs.context, cost, {must_have_points: true}, (err)->
            cb(err, parent, profile, spam)
          )
        else
          cb(null, parent, profile, spam)
      (parent, profile, spam, cb)=>
        if attrs.bet
          return @incrementBetPoints(site.name, user, attrs._id, attrs.points, parent.context || parent, (err)->
            cb(err, parent, profile, spam)
          )
        cb(null, parent, profile, spam)
      (parent, profile, spam, cb)=>
        @insertComment(site, attrs, parent, user, profile, request_data, cb)
      (parent, comments, cb)=>
        @postInsertComment(site, parent, comments, user, cb)
    ], (err, comment)->
      callback(err, if err then null else comment)
    )

  profileApproval: (site, comment, user, profile, cbapprove)->
    if !profile
      # no profile, use site approval settings
      return callback(null, !!site.autoApprove)
    collections.profiles.hasStatus(profile, site.points_settings.status_auto_approve, (err, has_auto_approve)->
      if has_auto_approve
        return cbapprove(null, true)
      result = [
        collections.profiles.isModerator(profile) || !site.autoApprove,
        null,
        false
      ]
      if profile.approval == 1
        return cbapprove(null, null)
      else if profile.approval == 2
        return cbapprove(null, false)
      else if profile.approval == 0
        return cbapprove(null, collections.profiles.isModerator(profile) || !!site.autoApprove)
      else
        return cbapprove(null, false)
    )

  modify: (site, commentOrId, user, profile, attrs, callback)=>
    cf = new ContentFilter(site.filter_words) # create content filter based on site custom words
    text = null
    the_comment = null
    async.waterfall([
      (cb)->
        if commentOrId._id
          return cb(null, commentOrId)
        collections.comments.findOne({_id: dbutil.idFrom(commentOrId)}, cb)
      (comment, cb)=>
        the_comment = comment
        if !comment
          return cb({notexists: true})
        if comment.type == "CHALLENGE" && !comment.challenger.author?.equals(user._id)
          return cb({notallowed: true})
        if comment.type != "CHALLENGE" &&  !comment.author?.equals(user._id)
          return cb({notallowed: true})
        if comment.created < new Date().getTime() - util.getValue("editCommentPeriod")
          return cb({notallowed: true})
        if comment.type == "CHALLENGE"
          if !attrs.challenger.text
            return cb({notsupported})
          text = cf.filterCommentText(attrs.challenger.text)
        else
          if !attrs.text
            return cb({notsupported})
          text = cf.filterCommentText(attrs.text)
        if site.checkSpam && config.checkSpam && site.auto_check_spam
          @checkSpam(text, comment.initialUrl, user.name, comment.request_data.ip, comment.request_data.user_agent, (err, spam)->
            cb(err, spam)
          )
        else
          cb(null, false)
      (spam, cb)=>
        @profileApproval(site, the_comment, user, profile, (err, approved)=>
          cb(err, spam, approved)
        )
      (spam, approved, cb)=>
        if !approved?
          return cb({notallowed: true})
        approved = approved && !!(the_comment.approved && !cf.containsBadWords(text) && !spam)
        cdate = new Date().getTime()
        toSet = {approved: approved, modified_by_user: true, edited_at: cdate, changed: cdate}
        if the_comment.type == "CHALLENGE"
          toSet['challenger.text'] = text
          toSet['challenger.ptext'] = cf.processCommentText(text)
        else
          toSet.text = text
          toSet.ptext = cf.processCommentText(text)
        @findAndModify({_id: the_comment._id, approved: true}, [], {$set: toSet, $inc: {_v: 1}}, {new: true}, (err, result)->
          cb(err, result)
        )
      (comment, cb)=>
        if comment
          pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
        cb(null, comment)
    ], callback)

  withImportedUser: (imported_from, imported_uid, siteName, name, email, callback)->
      cdate = new Date().getTime()
      attrs =
        serviceId: imported_uid
        site: siteName
        type: "sso"
        name: name
        email: email
        emailHash: util.md5Hash(email)
        created: cdate
        changed: cdate
        imageType: "gravatar"
        verified: true
        customData: false
        imported_from: imported_from
        subscribe:
          own_activity: false
          auto_to_conv: false

      collections.users.ensureUserAutoUpdate({serviceId: attrs.serviceId, type: attrs.type, site: attrs.site}, attrs, {send_verification: false}, callback)

  importComment: (imported_from, imported_id, parent_id, site, conv, user_data, text, timestamp, approved, req_data, callback)->
    user_data.email = user_data.email.toLowerCase()
    async.parallel({
      parent: (cb)->
        if parent_id
          collections.comments.findOne({imported_from: imported_from, imported_id: parent_id, context: conv._id}, cb)
        else
          cb(null)
      user: (cb)->
        if user_data.id
          collections.comments.withImportedUser(imported_from, user_data.id, site.name, user_data.name, user_data.email, cb)
        else
          cb(null, _.omit(user_data, "id"))
    }, (err, res)->
      attrs =
        force_approved: !!approved
        imported_from: imported_from
        imported_id: imported_id
        text: text
        parent: if res.parent then res.parent._id else conv._id
        top: !res.parent
        cdate: timestamp
      collections.comments.addComment(site, res.user, null, attrs, req_data, callback)
    )

  denyInCompetition: (site, user, cb)->
    now = moment().utc().toDate()
    collections.competitions.findIter({site: site.name, start: {$lte: now}, end: {$gt: now}}, (comp, cb)->
      debug("check competition: #{comp?.title}")
      if !comp
        debug("no comp: #{err}")
        return cb(err)
      collections.competition_profiles.count({user: user._id, competition: comp._id}, (err, count)->
        if err
          debug("error finding profile: #{err}")
          cb(err)
        else if count > 0
          debug("found active competition profile: #{count}")
          cb({active_competition: true})
        else
          cb(null)
      )
    , cb)

  # if voting one comment up again, the vote is retracted
  # if voting one comment down again, the vote is retracted
  likeUpDown: (site, id, user, profile, session, up, callback)->
    thecomment = null
    thelike = null
    thechanges = null
    initialUser = user
    initialProfile = profile
    trusted = false
    if profile?.trusted
      trusted = true
    if collections.users.verifiedOrMod(user, profile)
      session = null
    else
      user = null
      profile = null
    async.waterfall([
      (cb)=>
        if up
          collections.profiles.hasStatus(initialProfile, site.points_settings.status_upvote, cb)
        else
          collections.profiles.hasStatus(initialProfile, site.points_settings.status_downvote, cb)
      (allowed, cb)=>
        if !allowed
          return cb({low_status: true})
        if up
          # always allow upvotes
          cb(null)
        else
          @denyInCompetition(site, initialUser, cb)
      (cb)=>
        collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(id), approved: true}, cb)
      (comment, cb)=>
        thecomment = comment
        @checkExistingLikeUpDown(comment, user, session, up, cb)
      (like, cb)=>
        thelike = like
        @updateLikeUpDown(thecomment, user, session, like, up, trusted, cb)
      (changes, cb)=>
        thechanges = changes
        @postLikeCommentUpDown(site, thecomment, thelike, up, changes, user, profile, trusted, cb)
      (comment, cb)=>
        if comment
          pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
          if up
            @notifyCommentLikedUpDown(comment, thelike, up, thechanges, initialUser, (err, result)->
              cb(err, comment)
            )
          else
            cb(null, comment)
        else
          cb(null, comment)

    ], callback)

  checkExistingLikeUpDown: (comment, user, session, up, callback)->
    if comment
      if comment.deleted
        return callback({denied: true})
      if !comment.approved
        return callback({notexists: true})
      if user && comment.author?.equals(user._id)
        return callback({denied: true})
      collections.likes.findOne({comment: comment._id, user: user?._id || null, session: session}, (err, like)->
        if err
          return callback(err)
        callback(null, like)
      )
    else
      callback({notexists: true})

  updateLikeUpDown: (comment, user, session, like, up, trustedVoter, callback)->
    userId = user?._id || null
    shouldBeDir = if up then 1 else -1
    oppositeDir = -shouldBeDir
    toSet = {comment: comment._id, user: userId, session: session, dir: shouldBeDir, siteName: comment.siteName, context: comment.context}
    if comment.author
      toSet.cauthor = comment.author
    else if comment.guest
      toSet.cguest = comment.guest
    # insert
    if !like
      collections.likes.insert(toSet, (err, inserted)->
        if err
          if dbutil.errDuplicateKey(err)
            return callback({conflict: true})
          return callback(err)
        else
          callback(err, {up: up && shouldBeDir || 0, down: !up && oppositeDir || 0})
      )
    # take back
    else if like.dir == shouldBeDir
      query = {comment: comment._id, user: userId, session: session, dir: shouldBeDir}
      collections.likes.findAndRemove(query, [], (err, oldLike)->
        if !oldLike
          return callback({conflict: true})
        else
          callback(err, {up: up && oppositeDir || 0, down: !up && shouldBeDir || 0})
      )
    # replace up with down and vice versa
    else if like.dir == oppositeDir
      query = {comment: comment._id, user: userId, session: session, dir: oppositeDir}
      collections.likes.findAndModify(query, [], toSet, (err, oldLike)->
        if !oldLike
          return callback({conflict: true})
        else
          callback(err, {up: shouldBeDir, down: oppositeDir})
      )
    else
      callback({notsupported: true})

  postLikeCommentUpDown: (site, comment, like, up, changes, user, profile, trustedVoter, callback)->
    increment =
      no_likes: changes.up
      no_likes_down: changes.down
      rating: changes.up - changes.down
      _v: 1

    if comment.cat == "QUESTION" && comment.level == 2
      if trustedVoter
        points = util.getValue("trustedLikePointsAnswer")
      else
        points = util.getValue("likePointsAnswer")
    else
      if trustedVoter
        points = util.getValue("trustedLikePoints")
      else
        points = util.getValue("likePoints")
    if profile && collections.profiles.hasBenefit(profile, 'extra_vote_points')
      points += util.getValue('extraVotePoints')

    if profile && collections.profiles.hasBenefit(profile, 'extra_vote_points')
      if increment.no_likes?
        increment.no_likes = increment.no_likes * points
      if increment.no_likes_down?
        increment.no_likes_down = increment.no_likes_down * points
    cdate = new Date().getTime()
    debug('%j', changes)
    async.parallel([
      (cbinc)=>
        collections.comments.findAndModifyWTime({_id: comment._id}, [], {$inc: increment}, {new: true}, cbinc)
      (cbconvactivity)->
        collections.conversations.updateWTime({_id: comment.context}, {$set: {latest_activity: cdate}, $inc: {activity_rating: util.getValue("forumRatingLike") * (changes.up + changes.down)}}, cbconvactivity)
      (cbuserpoints)=>
        if !comment.author
          return cbuserpoints()
        trustedDown = changes.down
        if site.trusted_downvotes && !trustedVoter && trustedDown != 0
          points = 0
          debug("not allowed to down points: #{JSON.stringify(changes)}")
        if up && site.points_settings.disable_upvote_points
          return cbuserpoints(null)
        if !up && site.points_settings.disable_downvote_points
          return cbuserpoints(null)
        @incrementPoints({source: user, type: "LIKE", ref: comment._id}, comment.author, comment.siteName, comment.context, points * (changes.up - changes.down), cbuserpoints)
    ], (err, results)->
      updtComment = results[0]?[0]
      callback(err, updtComment)
    )

  endQuestion: (question, callback)->
    async.waterfall([
      (cb)=>
        @findOne({catParent: question._id, cat: "QUESTION", level: 2, approved: true, deleted: {$ne: true}}, {sort: {rating: -1}}, cb)
      (answer, cb)=>
        if !question.questionPointsOffered then question.questionPointsOffered = 0
        if answer && answer.author && !answer.author.equals(question.author)
          recipient = answer.author
        else
          recipient = question.author
        if recipient == question.author
          type = "QUESTION_REFUND"
          ref = question._id
        else
          type = "QUESTION_AWARD"
          ref = answer._id
        @incrementPoints({source: question.author, type: type, ref: ref}, recipient, question.siteName, question.context, question.questionPointsOffered, (err, updates)=>
          cb(err, answer)
        )
      (answer, cb)=>
        @findAndModifyWTime({_id: question._id}, [], {$set: {finished: true, answer: answer}, $inc: {_v: 1}}, {new: true}, (err, question)->
          cb(err, answer, question)
        )
      (answer, question, cb)=>
        if answer
          @findAndModifyWTime({_id: answer._id}, [], {$set: {best: true}, $inc: {_v: 1}}, {new: true}, (err, answer)->
            cb(err, answer, question)
          )
        else
          cb(null, answer, question)
      (answer, question, cb)=>
        @notifyQuestionEnd(answer, question, ->
          cb(null, answer, question)
        )
    ], (err, answer, question)->
      if (err)
        return callback(err)
      if answer
        pubsub.contentUpdate(answer.siteName, answer.context, collections.comments.toClient(answer))
      if question
        pubsub.contentUpdate(question.siteName, question.context, collections.comments.toClient(question))
      callback(err, answer, question)
    )

  notifyQuestionEnd: (answer, question, cb)->
    if answer
      collections.jobs.add({
        type: "END_QUESTION"
        siteName: question.siteName
        question: question
        answer: answer
        url: urls.for_model("comment", answer)
        context: answer.context
        uid: "END_QUESTION_#{question._id.toHexString()}"
      }, cb)
    else
      process.nextTick(-> cb(null, answer, question))

  notifyNewComment: (comment, parent, approvedLater, callback)->
    pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment), {extra_fields: {_is_new_comment: true}})
    if comment?.imported_from
      return process.nextTick(-> callback())
    async.parallel([
      (cb)->
        collections.jobs.add({
          type: "NEW_COMMENT",
          siteName: comment.siteName,
          comment: comment,
          parent: parent || comment.parent,
          context: comment.context,
          url: urls.for_model("comment", comment),
          uid: "NEW_COMMENT_#{comment._id.toHexString()}"
          approvedLater: approvedLater
        }, cb)
      (cb)->
        if comment.promote
          collections.jobs.add({
            type: "NOTIFY_PROMOTED_COMMENT"
            siteName: comment.siteName
            promoter: comment.author
            user: comment.author
            comment: comment
            context: comment.context
            url: urls.for_model("comment", comment),
            uid: "PROMOTED_COMMENT_#{comment._id.toHexString()}"
          }, cb)
        else
          cb()
    ], callback)

  notifyRemindForfeit: (comment, callback)->
    async.waterfall([
      (cb)->
        collections.comments.findAndModify({_id: comment._id, bet_notif_remind_forf: false}, [], {$set: {bet_notif_remind_forf: true}}, {new: true}, (err, result)->
          cb(err, result)
        )
      (comment, cb)->
        if !comment
          return cb({conflict: true})
        util.load_field(comment, 'context', collections.conversations, cb)
      (comment, cb)->
        notif = {
          type: "BET_REMIND_FORF"
          comment: comment
          context: comment.context
          conversationTitle: comment.context.text
          url: urls.for_model("comment", comment)
          uid: "BET_REMIND_FORF_#{comment._id}"
          siteName: comment.siteName
        }
        collections.users.findIter({_id: {$in: _.difference(_.union(comment.bet_accepted, comment.bet_joined), comment.bet_forfeited)}}, (user, done)->
          collections.notifications.send(user, user.email, notif, done)
        , cb)
    ], callback)

  notifyBetAccepted: (comment, user, points, callback)->
    pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
    async.waterfall([
      (cb)->
        util.load_field(comment, 'context', collections.conversations, cb)
      (comment, cb)->
        collections.jobs.add({
          type: "BET_ACCEPTED",
          points: points,
          siteName: comment.siteName,
          comment: comment,
          parent: comment.parent,
          context: comment.context,
          conversationTitle: comment.context.text,
          url: urls.for_model("comment", comment),
          by: user
        }, cb)
    ], callback)

  notifyBetDeclined: (comment, user, callback)->
    pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
    async.waterfall([
      (cb)->
        util.load_field(comment, 'context', collections.conversations, cb)
      (comment, cb)->
        collections.jobs.add({
          type: "BET_DECLINED",
          siteName: comment.siteName,
          comment: comment,
          context: comment.context,
          conversationTitle: comment.context.text,
          url: urls.for_model("comment", comment),
          by: user
        }, cb)
    ], callback)

  notifyBetForfeited: (comment, user, callback)->
    pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
    async.waterfall([
      (cb)->
        util.load_field(comment, 'context', collections.conversations, cb)
      (comment, cb)->
        collections.jobs.add({
          type: "BET_FORFEITED",
          siteName: comment.siteName,
          comment: comment,
          context: comment.context,
          conversationTitle: comment.context.text,
          url: urls.for_model("comment", comment),
          by: user
        }, cb)
    ], callback)

  notifyBetClaimed: (comment, user, callback)->
    pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
    async.waterfall([
      (cb)->
        util.load_field(comment, 'context', collections.conversations, cb)
      (comment, cb)->
        collections.jobs.add({
          type: "BET_CLAIMED",
          siteName: comment.siteName,
          comment: comment,
          context: comment.context,
          conversationTitle: comment.context.text,
          url: urls.for_model("comment", comment),
          by: user
        }, cb)
    ], callback)

  notifyBetResolvedPts: (comment, callback)->
    # send notifications to all users involved in the bet (author + accepted)
    notif = {
      comment: comment
      url: urls.for_model("comment", comment)
      uid: "BET_RESOLVED_PTS_#{comment._id}"
      siteName: comment.siteName
    }
    notif_for = (user)=>
      side = @getSideInBet(comment, user._id)
      user_id_str = user._id.toHexString()
      risked_points = (if side == 'joined' then comment.bet_joined_points[user_id_str] else comment.bet_accepted_points[user_id_str])
      if comment.bet_winning_side == 'tie'
        return _.extend({}, notif, {
          type: 'BET_TIE'
          risked_points: risked_points
          side: side
        })
      else
        win_status = @getWinStatusInBet(comment, user._id)
        win_points = comment.bet_points_resolved[user_id_str] - risked_points
        lose_points = if win_status == 'winner' then 0 else risked_points - comment.bet_points_resolved[user_id_str]
        return _.extend({}, notif, {
          win_points: win_points
          risked_points: risked_points
          lose_points: lose_points
          points: if win_status == 'winner' then win_points else lose_points
          type: if win_status == 'winner' then 'BET_WIN' else 'BET_LOSE'
          side: side
          win_status: win_status
        })
    async.waterfall([
      (cb)->
        util.load_field(comment, 'context', collections.conversations, cb)
      (comment, cb)->
        notif.context = comment.context
        notif.conversationTitle = comment.context.text
        collections.users.findIter({_id: {$in: [comment.author].concat(comment.bet_accepted)}}, (user, done)->
          collections.notifications.send(user, user.email, notif_for(user), done)
        , (err)->
          cb(err)
        )
    ], callback)

  notifyCommentLiked: (comment, like, up, user, cb)->
    collections.jobs.add({
      type: "LIKE_COMMENT",
      siteName: comment.siteName,
      comment: comment,
      parent: comment.parent,
      up: up,
      context: comment.context,
      url: urls.for_model("comment", comment),
      by: user
    }, cb)

  notifyCommentLikedUpDown: (comment, like, up, likeChanges, user, cb)->
    collections.jobs.add({
      type: "LIKE_COMMENT_UPDOWN",
      siteName: comment.siteName,
      comment: comment,
      parent: comment.parent,
      up: up,
      context: comment.context,
      url: urls.for_model("comment", comment),
      likeChanges: likeChanges,
      by: user
    }, cb)

  flag: (site, id, user, profile, callback)->
    async.waterfall([
      (cb)=>
        collections.profiles.hasStatus(profile, site.points_settings.status_flag, cb)
      (allowed, cb)=>
        if !allowed
          return cb({low_status: true})
        collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(id)}, cb)
      (comment, cb)=>
        if !comment || !comment.approved
          return cb({notexists: true})
        if comment.deleted
          return cb({denied: true})
        cdate = new Date().getTime()
        @findAndModifyWTime({_id: comment._id, flags: {$ne: user._id}, no_flags: {$not: {$gt: util.getValue("maxFlags")}}}, [], {$addToSet: {flags: user._id}, $inc: {no_flags: 1}}, {new: true}, (err, result)->
          cb(err, result)
        )
      (comment, cb)->
        if comment
          cb(null, comment)
        else
          cb({alreadyflagged: true})
    ], callback)

  clearFlags: (site, id, user, callback)->
    attrs = {no_flags: 0, flags: []}
    cdate = new Date().getTime()
    collections.comments.findAndModifyWTime({_id: dbutil.idFrom(id)}, [], {$set: attrs, $inc: {_v: 1}}, {new: true}, callback)

  approve: (site, id, user, callback)->
    attrs = {approved: true}
    async.waterfall([
      (cb)=>
        collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(id)}, cb)
      (comment, cbfunc)=>
        if !comment
          return cbfunc({notexists: true})
        cdate = new Date().getTime()
        if comment.type == "CHALLENGE"
          attrs.ends_on = cdate + util.getValue("challengeTime")
        else if comment.type == "QUESTION"
          attrs.ends_on = cdate + util.getValue("questionTime")
        collections.comments.findAndModifyWTime({_id: comment._id, approved: false}, [], {$set: attrs, $inc: {_v: 1}}, {new: true}, (err, comment)->
          cbfunc(err, comment)
        )
      (comment, cbpostapprove)=>
        if comment && comment.approved
          async.parallel([
            (cb)=>
              if !comment.modified_by_user && comment.parent.equals(comment.context) && comment.contextType == "FORUM" && !comment.modified_by_user
                debug('Comment is in forum, approving forum also')
                collections.conversations.approve(site, comment.context, cb)
              else
                cb()
            (cb)=>
              if !comment.modified_by_user
                @updateParentsForNew(comment, (err, results)->
                  cb(err, comment)
                )
              else
                cb(null, comment)
            (cb)=>
              if !comment.modified_by_user
                if comment.type != "CHALLENGE"
                  @updatePointsNewComment(site, comment.parent, comment, comment.author, cb)
                else
                  collections.comments.updateWTime({_id: comment.challenged.ref}, {$set: {challengedIn: comment._id}, $inc: {_v: 1}}, (err, result)->
                    cb(err)
                  )
              else
                cb()
            (cb)=>
              if !comment.modified_by_user
                if comment.type == "CHALLENGE"
                  @notifyNewChallenge(comment, true, cb)
                else
                  @notifyNewComment(comment, null, true, cb)
              else
                cb()
          ], (err, results)->
            cbpostapprove(err, comment)
          )
        else
          cbpostapprove(null, comment)
    ], (err, result)->
      callback(err, result)
    )

  # only for unapproved comments
  destroy: (site, id, keep_points, callback)->
    if typeof(keep_points) == 'function'
      callback = keep_points
      keep_points = false
    async.waterfall([
      (cb)=>
        collections.comments.findAndRemove({siteName: site.name, _id: dbutil.idFrom(id), approved: false, modified_by_user: {$ne: true}}, {}, (err, result)->
          cb(err, result)
        )
      (comment, cb)=>
        if comment
          if comment.type == "CHALLENGE"
            async.parallel([
              (cbp)=>
                if keep_points
                  debug("destroy: refund points for user: #{comment.challenger.author}")
                  @incrementPoints({source: null, type: "REFUND_DELETE_CHALLENGE", ref: comment._id}, comment.challenger.author, comment.siteName, comment.context, -comment.cost, cbp)
                else
                  @incrementPoints({source: null, type: "PENALTY_DELETE_CHALLENGE", ref: comment._id}, comment.challenger.author, comment.siteName, comment.context, -comment.cost + util.getValue("moderatorDeletesChallenge"), cbp)
              (cbp)->
                collections.comments.updateWTime({_id: comment.challenged.ref}, {$unset: {challengedIn: 1}, $inc: {_v: 1}}, cbp)
            ], (err, result)->
              cb(err, comment)
            )
          else
            if !comment.author
              return cb(null, comment)
            if keep_points
              debug("destroy: keep points for user: #{comment.author}")
              return cb(null, comment)
            @incrementPoints({source: null, type: "PENALTY_DELETE_COMMENT", ref: comment._id}, comment.author, comment.siteName, comment.context, util.getValue(if comment.type == "QUESTION" then "moderatorDeletesQuestion" else "moderatorDeletesComment"), (err, results)->
              cb(err, comment)
            )
        else
          cb({notexists: true})
      (comment, cb)->
        if comment.forum
          collections.conversations.destroy(site, comment.context, (err, conv)->
            cb(err, comment)
          )
        else
          cb(null, comment)
      (comment, cb)->
        # We don't want to rollback points in case the users have received their points won
        if comment.type == 'BET' && comment.bet_status != 'resolved_pts'
          @rollbackBetPoints(comment, cb)
        else
          cb(null, comment)
      (comment, cb)->
        pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
        cb(null, comment)
    ], callback)

  # This method is also used for comments that are not approved at the moment, but they had been approved in the past and
  # after users edited them the system marked them as not approved again
  delete: (site, id_or_comment, keep_points, callback)->
    if typeof(keep_points) == 'function'
      callback = keep_points
      keep_points = false
    thecomment = null
    async.waterfall([
      (cb)->
        if id_or_comment._id
          return cb(null, id_or_comment)
        collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(id_or_comment), $or: [{approved: true}, {approved: false, modified_by_user: true}], deleted: {$ne: true}}, cb)
      (comment, cb)->
        thecomment = comment
        if !comment
          return cb({notexists: true})
        if comment.type == "CHALLENGE"
          modifications =
            $set:
              deleted: true
              deleted_data: {challenger: thecomment.challenger, challenged: thecomment.challenged, summary: thecomment.summary}
            $unset:
              challenged: 1
              challenger: 1
              summary: 1
            $inc:
              _v: 1
        else
          modifications =
            $set:
              deleted: true
              deleted_data: {text: thecomment.text, ptext: thecomment.ptext, author: thecomment.author, forum: thecomment.forum}
            $unset:
              text: 1
              ptext: 1
              author: 1
              forum: 1
            $inc:
              _v: 1
          if thecomment.guest
            modifications.$set.deleted_data.guest = thecomment.guest
          # In case the comment has been marked as not approved after a user had edited it, then we need
          # to make sure that we mark it as approved to show it in the comments area
          # because it might have replies.
          modifications.$set.approved = true
        collections.comments.findAndModifyWTime({_id: thecomment._id, $or: [{approved: true}, {approved: false, modified_by_user: true}], deleted: {$ne: true}}, {}, modifications, {new: true}, (err, result)->
          cb(err, result)
        )
      (comment, cb)=>
        if !comment
          return cb({notexists: true})
        # 'thecomment' has the author field in the original place so we're using it
        if comment.type == "CHALLENGE"
          async.parallel([
            (cbp)=>
              if keep_points
                # refund challenge cost
                debug("delete: refund points for user: #{thecomment.challenger.author}")
                @incrementPoints({source: null, type: "REFUND_DELETE_CHALLENGE", ref: thecomment._id}, thecomment.challenger.author, thecomment.siteName, thecomment.context, -thecomment.cost, cbp)
              else
                # refund challenge cost and applu punishment
                @incrementPoints({source: null, type: "PENALTY_DELETE_CHALLENGE", ref: thecomment._id}, thecomment.challenger.author, thecomment.siteName, thecomment.context, -thecomment.cost + util.getValue("moderatorDeletesChallenge"), cbp)
            (cbp)->
              collections.comments.findAndModify({_id: thecomment.challenged.ref, challengedIn: thecomment._id}, [], {$unset: {challengedIn: 1}, $inc: {_v: 1}}, {new: true}, cbp)
          ], (err, results)->
            challenged = results[1][0]
            if !err && challenged
              pubsub.contentUpdate(challenged.siteName, challenged.context, collections.comments.toClient(_.extend(challenged, {challengedIn: challenged.challengedIn || null})))
            cb(err, comment)
          )
        else
          if !thecomment.author
            return cb(null, comment)
          async.parallel([
            (cbp)=>
              if keep_points
                debug("delete: keep points for user: #{thecomment.author}")
                return cbp()
              @incrementPoints({source: null, type: "PENALTY_DELETE_COMMENT", ref: thecomment._id}, thecomment.author, thecomment.siteName, thecomment.context, util.getValue(if comment.type == "QUESTION" then "moderatorDeletesQuestion" else "moderatorDeletesComment"), cbp)
            (cbp)=>
              # We don't want to rollback points in case the users have received their points won
              if comment.type == 'BET' && comment.bet_status != 'resolved_pts'
                @rollbackBetPoints(comment, cbp)
              else
                cbp(null)
          ], (err)->
            cb(err, comment)
          )
      (comment, cb)->
        if thecomment.forum
          collections.conversations.delete(site, comment.context, (err)->
            cb(err, comment)
          )
        else
          cb(null, comment)
      (comment, cb)->
        pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
        cb(null, comment)
    ], callback)

  promote: (site, commentId, points, promoter, callback)->
    if _.isFunction(promoter)
      callback = promoter
      promoter = {}
    commentId = dbutil.idFrom(commentId)
    async.waterfall([
      (cb)->
        collections.comments.findAndModify({_id: commentId, deleted: {$ne: true}, spam: false}, [], {$set: {promote: true, promoter: promoter?._id}, $inc: {_v: 1, promotePoints: points}}, {new: true}, cb)
      (doc, result, cb)->
        if !doc
          cb({no_comment_found: true})
        else
          collections.jobs.add({
            type: "NOTIFY_PROMOTED_COMMENT"
            siteName: site.name
            promoter: promoter
            user: doc.author
            comment: doc
            context: doc.context
            url: urls.for_model("comment", doc),
            uid: "PROMOTED_COMMENT_#{doc._id.toHexString()}"
            },
            (err)->
              cb(err, doc)
            )
      ],
      (err, result)->
        callback(err, result)
      )

  checkSufficientPromotePoints: (context, points, callback)->
    async.waterfall([
      (cb)->
        collections.comments.find(
          {
            context: context
            promote: true
            deleted: {$ne: true}
            spam: false
          }, {sort: [['promotePoints', -1]], limit: util.getValue("promotedLimit")}, cb)
      (cursor, cb)=>
        cursor.toArray(cb)
      ],
      (err, array)=>
        if err
          callback(err)
        else
          if array.length >= util.getValue("promotedLimit")
            minPoints = array[util.getValue("promotedLimit")-1].promotePoints + 1
          else
            minPoints = -util.getValue("promoteCost")
          if points >= minPoints
            callback(null)
          else
            callback({below_minimum_promote_points: true})
      )

  selfPromote: (site, commentId, points, user, callback)->
    commentId = dbutil.idFrom(commentId)
    comment = null
    async.waterfall([
      (cb)=>
        collections.comments.findOne({_id: commentId, deleted: {$ne: true}, spam: false, author: user._id}, cb)
      (result, cb)=>
        comment = result
        if !comment
          cb({cannot_promote: true})
        else
          currentPoints = comment.promotePoints ? 0
          totalPoints = points + currentPoints
          @checkSufficientPromotePoints(comment.context, totalPoints, cb)
      (cb)=>
        @incrementPoints({type: "SELF_PROMOTE", ref: commentId}, user, site.name, comment.context, -points, {must_have_points: true}, cb)
      (comment, cb)=>
        @promote(site, commentId, points, user, cb)
      ],
      (err, result)->
        callback(err, result)
      )

  demote: (site, commentId, callback)->
    commentId = dbutil.idFrom(commentId)
    async.waterfall([
      (cb)->
        collections.comments.findAndModify({_id: commentId, promote: true}, [], {$set: {promote: false, promotePoints: 0}, $unset: {promoter: 1}, $inc: {_v: 1}}, {new: true}, cb)
      (doc, result, cb)->
        if !doc
          cb({no_comment_found: true})
        else
          cb(null, doc)
      ],
      (err, result)->
        callback(err, result)
      )

  updateParentsForNew: (item, callback)->
    updateConv = null
    updateCat = null
    updateParent = null
    cdate = new Date().getTime()
    async.parallel([
      # context
      (cb)->
        if item.type == "CHALLENGE"
          updateConv = {$inc: {_v: 1, no_challenges: 1, no_all_activities: 1, no_activities: 1}}
        else if item.type == "QUESTION"
          updateConv = {$inc: {_v: 1, no_questions: 1, no_all_activities: 1, no_activities: 1}}
        else if item.type in ["COMMENT", "BET"]
          if item.level == 1
            updateConv = {$inc: {_v: 1, no_comments: 1, no_all_comments: 1, no_all_activities: 1, no_activities: 1}}
          else
            if item.cat == "COMMENT"
              updateConv = {$inc: {_v: 1, no_all_comments: 1, no_all_activities: 1}}
            else
              updateConv = {$inc: {_v: 1, no_all_activities: 1}}
        updateConv.$inc.activity_rating = util.getValue("forumRatingComment")
        updateConv.$set = {latest_activity: cdate}
        collections.conversations.findAndModifyWTime({_id: item.context}, [], updateConv, {new: true}, cb)
      # category if needed
      (cb)->
        if item.type == "COMMENT" && item.level > 1
          updateCat = {$inc: {_v: 1, no_all_comments: 1}}
          collections.comments.findAndModifyWTime({_id: item.catParent}, [], updateCat, {new: true}, cb)
        else
          process.nextTick(cb)
      # direct parent if needed
      (cb)->
        if item.type == "COMMENT" && item.level > 1
          updateParent = {$inc: {_v: 1, no_comments: 1}}
          async.parallel([
            (cbp)->
              collections.comments.findAndModifyWTime({_id: item.parent}, [], updateParent, {new: true}, cbp)
            (cbp)->
              collections.comments.findOne({_id: item.parent}, (err, parent)->
                if err
                  return cb(err)
                if parent.author == item.author
                  # no transaction record for self-replies
                  return cb(null)
                collections.transactions.record({
                  type: "GOT_REPLY"
                  level: item.level
                  siteName: item.siteName
                  conversation: item.context
                  user: parent.author
                  value: 0
                  source: item.author
                  ref: item._id
                }, cbp)
              )
          ], cb)
        else
          process.nextTick(cb)
    ], (err, results)->
      if !err
        if updateConv && results[0]?[0]
          pubsub.contentUpdate(item.siteName, item.context, collections.conversations.toClient(results[0][0]))
        # The following code has been temporarily commented out because
        # we don't currently need the information about the number of
        # descendants for comments
        #
        # if updateCat && results[1]?[0]
        #   pubsub.contentUpdate(item.siteName, item.context, collections.comments.toClient(results[1][0]))
        # if updateParent && results[2]?[0]?[0]
        #   pubsub.contentUpdate(item.siteName, item.context, collections.comments.toClient(results[2][0][0]))
      callback(err, results)
    )

  sortChronologically: (query, from, limit, callback)->
    async.waterfall([
      (cb)=>
        if from
          queryFrom = {_id: dbutil.idFrom(from)}
          if query.approved?
            queryFrom.approved = query.approved
          collections.comments.findOne(queryFrom, cb)
        else
          cb(null, null)
      (fromDoc, cb)=>
        if fromDoc
          query.slug = {$gt: fromDoc.slug}
        collections.comments.find(query, {sort: {slug: 1}, limit: limit}, cb)
      (cursor, cb)->
        cursor.toArray(cb)
    ], callback)

  getSiteActivities: (site, type, profile, pending, callback)->
    query = {}
    if type
      query.type = type
    if pending
      query = _.extend(query, {
        siteName: site.name
        deleted: {$ne: true}
        $or: [
          {approved: false},
          {no_flags: {$gte: util.getValue("flagsForApproval")}},
        ]
      })
    else
      query = _.extend(query, {
        siteName: siteName
        approved: true
      })
    collections.comments.find(query, callback)

  getSiteFundedActivitiesPaged: (site, field, direction, from, limit, callback)->
    query = {siteName: site.name, is_funded: true, approved: true, deleted: {$ne: true}}
    collections.comments.sortTopLevel(query, field, direction, from, Math.min(limit, util.getValue("commentsPerPage")), callback)

  bet_stat_filter = {
    open: 'open'
    closed: 'closed'
    pending: {$in: ['forf', 'forf_closed']}
    resolved: {$in: ['resolved', 'resolving_pts', 'resolved_pts']}
  }

  getSiteActivitiesPaged: (site, type, moderator, field, direction, from, profile, pending, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    query = {siteName: site.name}
    if type == 'BET'
      bet_status = options.bet_status
      if bet_status
        if !(bet_status in ['all', 'open', 'closed', 'pending', 'resolved'])
          return process.nextTick(-> callback({notsupported: true}))
        if bet_status != 'all'
          query.bet_status = bet_stat_filter[bet_status]
      if options.omit_rolledback
        query.bet_rolledback = false
      query.deleted = {$ne: true}
    if type
      query.type = type
    if pending
      query = _.extend(query, {
        deleted: {$ne: true}
        $or: [
          {approved: false},
          {no_flags: {$gte: util.getValue("flagsForApproval")}},
        ]
      })
    else
      if !moderator
        query = _.extend(query, {
          approved: true
        })
    collections.comments.sortTopLevel(query, field, direction, from, util.getValue("commentsPerPage"), callback)

  getUserActivitiesPaged: (user_or_id, site, type, field, direction, from, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    query = {siteName: site.name, deleted: {$ne: true}, approved: true}
    async.waterfall([
      (cb)->
        if user_or_id._id
          return cb(null, user)
        collections.users.findOne({_id: dbutil.idFrom(user_or_id)}, cb)
      (user, cb)->
        if !user
          return cb({notexists: true})
        if type == 'BET'
          query.$or = [{author: user._id}, {bet_accepted: user._id}]
          bet_status = options.bet_status
          if bet_status
            if !(bet_status in ['all', 'open', 'closed', 'pending', 'resolved'])
              return process.nextTick(-> cb({notsupported: true}))
            if bet_status != 'all'
              query.bet_status = bet_stat_filter[bet_status]
          if options.omit_rolledback
            query.bet_rolledback = false
        else if type == 'CHALLENGE'
          query['challenger.author'] = user._id
        else
          query.author = user._id
        if type
          query.type = type
        else
          query.$or = [{author: user._id}, {bet_accepted: user._id}, {'challenger.author': user._id}]
          delete query.author
        collections.comments.sortTopLevel(query, field, direction, from, util.getValue("commentsPerPage"), cb)
    ], callback)

  countUserActivities: (user_or_id, site, type, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    query =
      siteName: site.name
      approved: true
      deleted: {$ne: true}
    async.waterfall([
      (cb)->
        if user_or_id._id
          return cb(null, user)
        collections.users.findOne({_id: dbutil.idFrom(user_or_id)}, cb)
      (user, cb)->
        if !user
          return cb({notexists: true})
        if type == 'BET'
          query.$or = [{author: user._id}, {bet_accepted: user._id}, {bet_targeted: user._id}]
          bet_status = options.bet_status
          if bet_status
            if !(bet_status in ['all', 'open', 'closed', 'pending', 'resolved'])
              return process.nextTick(-> cb({notsupported: true}))
            if bet_status != 'all'
              query.bet_status = bet_stat_filter[bet_status]
        else if type == 'CHALLENGE'
          query['challenger.author'] = user._id
        else
          query.author = user._id
        if type
          query.type = type
        else
          query.$or = [{author: user._id}, {bet_accepted: user._id}, {'challenger.author': user._id}]
          delete query.author
        collections.comments.count(query, cb)
    ], callback)

  countSiteActivities: (site, type, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    query =
      siteName: site.name
      type: type
      approved: true
      deleted: {$ne: true}
    if type == 'BET'
      bet_status = options.bet_status
      if bet_status
        if !(bet_status in ['all', 'open', 'closed', 'pending', 'resolved'])
          return process.nextTick(-> callback({notsupported: true}))
        if bet_status != 'all'
          query.bet_status = bet_stat_filter[bet_status]
    collections.comments.count(query, callback)

  getUnresolvedBets: (site, field, direction, from, profile, callback)->
    notif_date = moment().valueOf() - util.getValue('notifForfBet')
    query = {siteName: site.name, type: 'BET', bet_status: 'forf', $or: [{bet_forf_started_at: {$lte: notif_date}}, {bet_requires_mod: true}], deleted: {$ne: true}, approved: true}
    collections.comments.sortTopLevel(query, field, direction, from, util.getValue("commentsPerPage"), callback)

  findChallengeById: (id, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.findOne({_id: dbutil.idFrom(id), type: "CHALLENGE"}, callback)
    else
      collections.comments.findOne({_id: dbutil.idFrom(id), approved: true, type: "CHALLENGE"}, callback)

  findCommentById: (id, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.findOne({_id: dbutil.idFrom(id), type: "COMMENT"}, callback)
    else
      collections.comments.findOne({_id: dbutil.idFrom(id), approved: true, type: "COMMENT"}, callback)

  findQuestionById: (id, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.findOne({_id: dbutil.idFrom(id), type: "QUESTION"}, callback)
    else
      collections.comments.findOne({_id: dbutil.idFrom(id), approved: true, type: "QUESTION"}, callback)

  findActivityById: (site, id, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(id)}, callback)
    else
      collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(id), approved: true}, callback)

  getAllActivitiesPaged: (site, context, field, direction, from, countPerPage, allowNotApproved, callback)->
    if from
      from = dbutil.idFrom(from)
    query = {}
    if !allowNotApproved
      query.approved = true
    collections.comments.sortKeepTree(
      _.extend(query, {
        context: dbutil.idFrom(context)
        level: 1
      }),
      field,
      direction,
      from,
      countPerPage || util.getValue("commentsPerPage"),
      1,
      callback)

  getFundedActivitiesPaged: (site, context, field, direction, from, limit, callback)->
    context = dbutil.idFrom(context)
    query = {siteName: site.name, context: context, is_funded: true, approved: true, deleted: {$ne: true}}
    collections.comments.sortTopLevel(query, field, direction, from, Math.min(limit, util.getValue("commentsPerPage")), callback)

  getAllActivities: (site, context, allowNotApproved, callback)->
    if allowNotApproved
      collections.comments.find({siteName: site.name, context: dbutil.idFrom(context)}, callback)
    else
      collections.comments.find({siteName: site.name, context: dbutil.idFrom(context), approved: true}, callback)

  getPromoted: (site, context, field, direction, from, allowNotApproved, callback)->
    if from
      from = dbutil.idFrom(from)
    query = {}
    async.waterfall([
      (cb)->
        collections.comments.find(
          _.extend(query, {
            context: dbutil.idFrom(context)
            promote: true
            approved: true
            deleted: {$ne: true}
          }), {sort: [['promotePoints', -1]], limit: util.getValue("promotedLimit")}, cb)
      (cursor, cb)->
        cursor.toArray(cb)
    ], callback)

  checkSpam: (text, article_url, author_name, author_ip, user_agent, callback)->
    akismet.checkSpam({
      user_ip: author_ip
      user_agent: user_agent
      permalink: article_url
      comment_author: author_name
      comment_content: text
      comment_type: 'comment'
    }, callback)

  setSpam: (site, comment_id, callback)->
    author = null
    comment = null
    if !site.checkSpam
      return process.nextTick(-> callback({notallowed: true}))
    async.waterfall([
      (cb)->
        collections.comments.findById(comment_id, cb)
      (result_comment, cb)->
        comment = result_comment
        if comment.guest
          return cb(null, comment.guest)
        collections.users.findById((if comment.type == 'CHALLENGE' then comment.challenger.author else comment.author), cb)
      (result_user, cb)->
        if site.auto_check_spam
          author = result_user
          akismet.submitSpam({
            user_ip: comment.request_data?.ip || ''
            user_agent: comment.request_data?.user_agent || ''
            permalink: comment.initialUrl
            comment_author: author.name
            comment_content: if comment.type == 'CHALLENGE' then "#{comment.summary} #{comment.challenger.text}" else comment.text
            comment_type: 'comment'
          }, cb)
        else
          cb(null)
      (cb)->
        collections.comments.findAndModify({_id: comment._id}, [], {$set: {spam: true}, $inc: {_v: 1}}, {new: true}, cb)
      (comment, info, cb)->
        cb(null, comment)
    ], callback)

  notSpam: (site, comment_id, callback)->
    author = null
    comment = null
    if !site.checkSpam
      return process.nextTick(-> callback({notallowed: true}))
    async.waterfall([
      (cb)->
        collections.comments.findById(comment_id, cb)
      (result_comment, cb)->
        comment = result_comment
        if comment.guest
          return cb(null, comment.guest)
        collections.users.findById((if comment.type == 'CHALLENGE' then comment.challenger.author else comment.author), cb)
      (result_user, cb)->
        if site.auto_check_spam
          author = result_user
          akismet.submitHam({
            user_ip: comment.request_data?.ip || ''
            user_agent: comment.request_data?.user_agent || ''
            permalink: comment.initialUrl
            comment_author: author.name
            comment_content: if comment.type == 'CHALLENGE' then "#{comment.summary} #{comment.challenger.text}" else comment.text
            comment_type: 'comment'
          }, cb)
        else
          cb(null)
      (cb)->
        collections.comments.findAndModify({_id: comment._id}, [], {$set: {spam: false}, $inc: {_v: 1}}, {new: true}, cb)
      (comment, info, cb)->
        cb(null, comment)
    ], callback)

  addChallenge: (site, user, profile, attrs, request_data, callback)->
    if _.isFunction(request_data)
      callback = request_data
      request_data = {}
    comments = require("./comments")
    cost = util.getValue("challengeCost")
    async.waterfall([
      (cb)=>
        async.parallel([
          (nestcbconv)->
            collections.conversations.findOne({siteName: site.name, _id: dbutil.idFrom(attrs.parent)}, nestcbconv)
          (nestcbcomm)->
            collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(attrs.challenged), approved: true}, nestcbcomm)
          (nestcbchall)=>
            collections.comments.findOne({siteName: site.name, "challenged.ref": dbutil.idFrom(attrs.challenged)}, nestcbchall)
        ], (err,results)->
          if err
            return cb(err)
          [parent, challenged, challenge] = results
          if !parent
            return cb({notexists: true})
          if !challenged || challenged.deleted || parent.deleted || challenge || (challenged.author && user._id.equals(challenged.author)) || user.email == challenged.guest?.email
            return cb({denied: true})
          cb(null, parent, challenged)
        )
      (parent, challenged, cb)=>
        if profile
          return cb(null, parent, challenged, profile)
        # make sure that the user has a persistent profile
        collections.profiles.create(user, site, (err, profile)->
          if !profile
            cb({invalid_profile: true})
          else
            cb(err, parent, challenged, profile)
        )
      (parent, challenged, profile, cb)=>
        if cost != 0
          @updateProfileForChallenge(user, challenged, site, parent._id, cost, (err, newcost)->
            cost = newcost
            cb(err, parent, challenged, profile)
          )
        else
          cb(null, parent, challenged, profile)
      (parent, challenged, profile, cb)=>
        if challenged.level > 1
          collections.comments.findOne({siteName: site.name, _id: challenged.catParent}, (err, catParent)->
            cb(err, parent, challenged, catParent, profile)
          )
        else
          cb(null, parent, challenged, challenged, profile)
      (parent, challenged, catParent, profile, cb)=>
        if site.checkSpam && config.checkSpam && site.auto_check_spam
          @checkSpam("#{attrs.summary} #{attrs.challenger?.text}", challenged.initialUrl, user.name, request_data.ip, request_data.user_agent, (err, spam)->
            cb(err, parent, challenged, catParent, profile, spam)
          )
        else
          cb(null, parent, challenged, catParent, profile, false)
      (parent, challenged, catParent, profile, spam, cb)=>
        @profileApproval(site, null, user, profile, (err, approved)=>
          cb(err, parent, challenged, catParent, profile, spam, approved)
        )
      (parent, challenged, catParent, profile, spam, approved, cb)=>
        attrs.spam = spam
        attrs.cost = cost
        attrs.approved = approved
        if !attrs.approved?
          return cb({notallowed: true})
        @insertChallenge(site, attrs, attrs.approved, parent, challenged, catParent, user, spam, request_data, (err, challenge)->
          if (err || !challenge) && cost != 0
            collections.profiles.update({_id: profile._id}, {$inc: {points: cost}}, (err, profile)->
              cb(err, parent, challenge)
            )
            # XXX TODO update convprofiles
          else
            cb(err, parent, challenge)
        )
      (parent, challenge, cb)=>
        @postInsertChallenge(site, parent, challenge, user, (err)->
          cb(err, challenge)
        )
    ], (err, challenge)->
      if !err && !challenge.approved
        callback(err, {approved: false})
      else
        callback(err, if err then null else challenge)
    )

  insertChallenge: (site, attrs, approved, parent, challenged, catParent, user, spam, request_data, cb)->
    cdate = new Date().getTime()
    id = dbutil.id()
    cf = new ContentFilter(site.filter_words) # create content filter based on site custom words
    text = cf.filterCommentText(attrs.challenger.text)
    challenge =
      _id: id
      _v: 0
      approved: !!(approved && !cf.containsBadWords(attrs.summary) && !cf.containsBadWords(attrs.challenger.text) && !spam)
      siteName: parent.siteName
      context: parent.context || parent._id
      contextType: parent.contextType || (if parent.type == "ARTICLE" then "ARTICLE" else "FORUM")
      uri: parent.uri
      initialUrl: parent.initialUrl
      parent: parent._id
      summary: cf.filterChallengeSummary(attrs.summary)
      challenged:
        text: challenged.text
        ptext: challenged.ptext
        author: challenged.author
        no_votes: 0
        ref: challenged._id
        created: challenged.created
      challenger:
        author: user._id
        text: text
        ptext: cf.processCommentText(text)
        no_votes: 0
        created: cdate
      rating: 0
      level: 1
      cost: attrs.cost
      created: cdate
      changed: cdate
      parentSlug: (parent.parentSlug || "/") + parent._id.toHexString() + "/"
      slug: "#{parent.slug}/#{id.toHexString()}"
      parents: [parent._id]
      cat: "CHALLENGE"
      type: "CHALLENGE"
      finished: false
      locked_finish: false
      notified_end: false
      locked_nfinish: false
      order_time: catParent.created.toString() + "1"
      ends_on: cdate + util.getValue("challengeTime")
      spam: spam
      request_data: request_data
      imported_dummy: dbutil.id()

    if challenged.guest
      challenge.challenged.guest = challenged.guest

    collections.comments.insert(challenge, (err, challenges)->
      cb(err, challenges?[0])
    )

  postInsertChallenge: (site, parent, challenge, user, callback)->
    async.parallel([
      (cb)=>
        if challenge.approved
          cdate = new Date().getTime()
          async.parallel([
            (cbp)=>
              @updateParentsForNew(challenge, (err, result)->
                cbp(err)
              )
            (cbp)->
              collections.comments.updateWTime({_id: challenge.challenged.ref}, {$set: {challengedIn: challenge._id}, $inc: {_v: 1}}, (err, result)->
                cbp(err)
              )
            (cbp)=>
              @notifyNewChallenge(challenge, false, cbp)
          ], cb)
        else
          collections.jobs.add({
            type: "NEW_PENDING_CHALLENGE"
            challenge: challenge
            siteName: challenge.siteName
            context: challenge.context
            url: urls.for_model("comment", challenge)
            uid: "NEW_PENDING_CHALLENGE_#{challenge._id.toHexString()}"
          },
            ->
              cb(null, challenge)
          )
      (cb)->
        if user.subscribe.auto_to_conv
          collections.subscriptions.userSubscribeForContent(user, site, challenge.context, cb)
        else
          process.nextTick(cb)
    ], (err)->
      callback(err, challenge)
    )

  updateProfileForChallenge: (user, comment, site, convId, cost, callback)->
    freeDoc = null
    async.waterfall([
      (cbw)->
        collections.profiles.findAndModify({
            user: user._id
            siteName: site.name
            freeChallengeUsed: {$lt: site.points_settings.free_challenge_count}
          }
          , {}
          , {$inc: {freeChallengeUsed: 1}}
          , {new: true}
          ,
          (err, doc, result)->
            if doc?
              cost = 0
              freeDoc = doc
              cbw(err)
              return
            collections.profiles.findOne({user: user._id, siteName: site.name}, (err, doc)->
              if doc?.points < -cost
                cbw({notenoughpoints: true})
              else
                cbw()
            )
        )
      (cbw)->
        async.parallel([
          (cb)->
            if !freeDoc
              transactionData = {
                type: "CHALLENGE"
                source: user._id
                user: user._id
                ref: comment._id
                conversation: convId
                siteName: site.name
                value: cost
              }
              collections.transactions.record(transactionData, cb)
            else
              cb(null, freeDoc)
          (cb)->
            if !freeDoc
              collections.profiles.findAndModify({
                  user: user._id
                  siteName: site.name
                  points: {$gte: -cost}
                }
                , {}
                , {$inc: {points: cost}}
                , {new: true}
                ,
                (err, doc, result)->
                  cb(err, doc)
              )
            else
              cb(null, freeDoc)
          (cb)->
            if !freeDoc
              collections.convprofiles.findAndModify({
                  user: user._id
                  context: convId
                  points: {$gte: -cost}
                }
                , {}
                , {$inc: {points: cost}}
                , {}
                ,
                (err, doc, result)->
                  cb(err, doc)
              )
            else
              cb(null, freeDoc)
          (cb)->
            now = moment().utc().toDate()
            collections.competitions.find({start: {$lte: now}, end: {$gt: now}}, (err, cursor)->
              update_points = (err, comp)->
                if !comp or err
                  return cb(err)
                collections.competition_profiles.findAndModify({
                  user: user._id
                  competition: comp._id
                  points: {$gte: -cost}
                }
                , {}
                , {$inc: {points: cost}}
                , {}
                ,
                (err, doc, result)->
                  if err
                    cursor.close()
                    return cb(err)
                  cursor.nextObject(update_points)
                )
              if !freeDoc
                cursor.nextObject(update_points)
              else
                cb(null)
            )
        ],
        (err, results)->
          cbw(err, results)
        )
    ],
    (err, results)->
      if err
        callback(err)
      else
        doc = results[1]
        if doc
          pubsub.contentUpdate(site.name, convId, collections.profiles.toClient(doc, user))
        callback(err, cost)
    )

  postVoteChallenge: (site, challenge, side, user, profile, vote, up, callback)->
    increment = {_v: 1}
    if up
      if vote
        increment[side + ".no_votes"] = 1
        increment.rating = 1
      else
        callback({denied: true})
        return
    else
      if vote == 1
        increment[side + ".no_votes"] = -1
        increment.rating = -1
      else
        callback({denied: true})
        return
    cdate = new Date().getTime()
    async.parallel([
      (cbinc)=>
        collections.comments.findAndModifyWTime({_id: challenge._id}, [], {$inc: increment}, {new: true}, cbinc)
      (cbconvactivity)->
        collections.conversations.updateWTime({_id: challenge.context}, {$set: {latest_activity: cdate}, $inc: {activity_rating: util.getValue("forumRatingVote") * increment[side + ".no_votes"]}}, cbconvactivity)
      (cbuserpoints)=>
        if !challenge[side].author
          return cbuserpoints()
        if up && site.points_settings.disable_upvote_points
          return cbuserpoints(null)
        if !up && site.points_settings.disable_downvote_points
          return cbuserpoints(null)
        @incrementPoints({source: user, type: "VOTED_IN_CHALLENGE", ref: challenge._id}, challenge[side].author, challenge.siteName, challenge.context, util.getValue("votePoints") * (if up then 1 else -1), cbuserpoints)
      (cbvoter)=>
        if user
          async.series([
            (cb)->
              if profile
                return cb()
              async.parallel([
                (cb)->
                  collections.profiles.create(user, challenge.siteName, cb)
                (cb)->
                  collections.convprofiles.create(user, challenge.context, cb)
              ], cb)
            (cb)=>
              if util.getValue("voterInChallenge")
                @incrementPoints({source: user, type: "VOTE_CHALLENGE", ref: challenge._id}, user._id, challenge.siteName, challenge.context, util.getValue("voterInChallenge") * (if up then 1 else -1), cb)
              else
                cb()
          ], cbvoter)
        else
          cbvoter()
    ], (err, results)->
      updtChallenge = results[0]?[0]
      callback(err, updtChallenge)
    )

  updateVote: (challenge, side, user, session, vote, up, callback)->
    if up
      toSet = {
        challenge: challenge._id
        user: user?._id || null
        session: session
        side: side
        siteName: challenge.siteName
        context: challenge.context
      }
      if challenge.challenged.author
        toSet.challenged_author = challenge.challenged.author
      else
        toSet.challenged_guest = challenge.challenged.guest
      if challenge.challenger.author
        toSet.challenger_author = challenge.challenger.author
      else
        toSet.challenger_guest = challenge.challenger.guest
      collections.votes.insert(toSet, (err, votes)->
        if err && dbutil.errDuplicateKey(err)
          err = {denied: true}
        callback(err, challenge, votes[0])
      )
    else
      collections.votes.remove({_id: vote._id, side: side}, (err, numberOfRemovedDocs)->
        callback(err, challenge, numberOfRemovedDocs)
      )

  checkExistingVote: (challenge, side, user, session, up, callback)->
    if challenge
      if challenge.deleted
        return callback({denied: true})
      if challenge.finished
        return callback({challenge_ended: true})
      if !challenge.approved
        return callback({notexists: true})
      if user && (challenge.challenged.author?.equals(user._id) || challenge.challenger.author?.equals(user._id))
        return callback({denied: true})
      collections.votes.findOne({challenge: challenge._id, user: user?._id || null, session: session}, (err, vote)->
        if err
          callback(err)
        else if (vote && !up) || (!vote && up)
          callback(null, challenge, vote)
        else
          callback({denied: true})
      )
    else
      callback({notexists: true})

  vote: (site, id, user, profile, session, side, up, callback)->
    thevote = null
    initialUser = user
    initialProfile = profile
    if collections.users.verifiedOrMod(user, profile)
      session = null
    else
      user = null
      profile = null
    cdate = new Date().getTime()
    async.waterfall([
      (cb)=>
        if up
          collections.profiles.hasStatus(initialProfile, site.points_settings.status_upvote, cb)
        else
          collections.profiles.hasStatus(initialProfile, site.points_settings.status_downvote, cb)
      (allowed, cb)=>
        if !allowed
          return cb({low_status: true})
        collections.comments.findOne({siteName: site.name, _id: dbutil.idFrom(id), approved: true}, cb)
      (challenge, cb)=>
        @checkExistingVote(challenge, side, user, session, up, cb)
      (challenge, vote, cb)=>
        thevote = vote
        @updateVote(challenge, side, user, session, vote, up, cb)
      (challenge, vote, cb)=>
        @postVoteChallenge(site, challenge, side, user, profile, vote, up, cb)
      (challenge, cb)=>
        if challenge
          pubsub.contentUpdate(challenge.siteName, challenge.context, collections.comments.toClient(challenge))
          @notifyVoteChallenge(challenge, side, thevote, up, initialUser, (err, result)->
            cb(err, challenge)
          )
        else
          cb(null, challenge)
    ], callback)

  fund: (site, id, side, fromUser, token, value, callback)->
    # there's only one package for funding comments for now
    value = util.getValue('fundCommentPrice')
    id = dbutil.idFrom(id)
    author = null
    async.waterfall([
      (cb)->
        collections.comments.findOne({_id: id}, cb)
      (comment, cb)->
        if !comment
          return cb({notexists: true})
        if comment.deleted || !comment.approved
          return cb({notexists: true})
        comment_id = comment._id
        if comment.type == "CHALLENGE"
          if side == "challenged"
            author = comment.challenged.author
            comment_id = comment.challenged.ref
          else
            author = comment.challenger.author
        else
          author = comment.author
        if comment_id == comment._id
          cb(null, comment)
        else
          collections.comments.findOne({_id: comment_id}, cb)
      (comment, cb)->
        collections.users.findOne({_id: author}, (err, toUser)->
          cb(err, comment, toUser)
        )
      (comment, toUser, cb)->
        util.make_payment(token, value, "Comment funds for #{id}", {siteName: site.name}, (err, payment_id)->
          cb(err, comment, toUser, payment_id)
        )
      (comment, toUser, payment_id, cb)->
        collections.transactions.record({
          type: "FUND_COMMENT"
          siteName: site.name
          ref: comment._id
          user: toUser?._id
          source: fromUser._id
          date: moment.utc().toDate()
          payment_id: payment_id
          amount: value
        }, (err, tx)->
          cb(err, comment, toUser)
        )
      (comment, toUser, cb)->
        collections.comments.findAndModifyWTime({_id: comment._id}, [],
        {
          $push: {
            funded: {
              _id: dbutil.id()
              from: fromUser._id
              date: moment.utc().toDate()
              value: value
            }
          },
          $inc: {_v: 1},
          $set: {is_funded: true}
        },
        {new: true},
        (err, comment)->
          cb(err, comment, toUser)
        )
      (comment, toUser, cb)->
        async.parallel({
          give: (cb)->
            collections.profiles.giveFunds(fromUser, site, toUser, value, cb)
          receive: (cb)->
            if toUser
              collections.profiles.receiveFunds(toUser, site, comment.context, fromUser, value, cb)
            else
              cb(null)
        }, (err)->
          cb(err, comment)
        )
      (comment, cb)=>
        @notifyFundComment(comment, {by: fromUser}, (err)->
          cb(err, comment)
        )
    ], (err, res)->
      callback(err, if err then null else res)
    )

  endChallenge: (challenge, callback)->
    if challenge.challenger.no_votes > challenge.challenged.no_votes
      winner = challenge.challenger
      loser = challenge.challenged
      side = "challenger"
    else if challenge.challenger.no_votes < challenge.challenged.no_votes
      winner = challenge.challenged
      loser = challenge.challenger
      side = "challenged"
    else
      collections.comments.findAndModifyWTime({_id: challenge._id}, [], {$set: {finished: true}, $inc: {_v: 1}}, {new: true}, (err, challenge)->
        callback(err, challenge)
      )
      return
    async.series([
      (cb)->
        collections.comments.findAndModifyWTime({_id: challenge._id}, [], {$set: _.object([["finished", true], [side + ".best", true]]), $inc: {_v: 1}}, {new: true}, cb)
      (cb)=>
        async.parallel([
          (cbwinner)=>
            if !winner.author
              return cbwinner()
            collections.sites.findOne({siteName: challenge.siteName}, (err, site)->
              if err
                return cbwinner(err)
              @incrementPoints({source: null, type: "WIN_CHALLENGE", ref: challenge._id}, winner.author, challenge.siteName, challenge.context, site.points_settings.for_challenge_winner, cbwinner)
            )
          (cbloser)=>
            if !loser.author
              return cbloser()
            @incrementPoints({source: null, type: "LOSE_CHALLENGE", ref: challenge._id}, loser.author, challenge.siteName, challenge.context, util.getValue("challengeLoserPoints"), cbloser)
        ], cb)
      (cb)=>
        @notifyChallengeEnd(challenge, winner, loser, cb)
    ]
    , (err, results)->
      ch = results[0]?[0]
      if !err && ch
        pubsub.contentUpdate(ch.siteName, ch.context, collections.comments.toClient(ch))
      callback(err, ch)
    )

  betRequiresMod: (comment)->
    bet_accepted_str = dbutil.ids2str(comment.bet_accepted)
    bet_joined_str = dbutil.ids2str(comment.bet_joined)
    bet_forfeited_str = dbutil.ids2str(comment.bet_forfeited)
    bet_claimed_str = dbutil.ids2str(comment.bet_claimed)
    # If one of more users claims they Won from each side
    if _.intersection(bet_accepted_str, bet_claimed_str).length > 0 && _.intersection(bet_joined_str, bet_claimed_str).length > 0
      return true
    # Either side claims both won and lost
    if _.intersection(bet_accepted_str, bet_claimed_str).length > 0 && _.intersection(bet_accepted_str, bet_forfeited_str).length > 0 ||
      _.intersection(bet_joined_str, bet_claimed_str).length > 0 && _.intersection(bet_joined_str, bet_forfeited_str).length > 0
        return true
    return false

  computeBetWinningSide: (comment)->
    forf_joined = _.intersection(dbutil.ids2str(comment.bet_joined), dbutil.ids2str(comment.bet_forfeited))
    forf_accepted = _.intersection(dbutil.ids2str(comment.bet_accepted), dbutil.ids2str(comment.bet_forfeited))
    major_acc = Math.ceil(comment.bet_accepted.length / 2)
    if forf_accepted.length >= major_acc && forf_joined.length == 0
      return 'joined'
    if forf_accepted.length == 0 && forf_joined.length == 1
      return 'accepted'
    return 'undecided'

  getWinStatusInBet: (bet, user_id)->
    user_id_str = user_id.toHexString?() || user_id
    if bet.bet_winning_side != 'joined' && bet.bet_winning_side != 'accepted'
      return ''
    if (if bet.bet_winning_side == 'joined' then bet.bet_joined_points else bet.bet_accepted_points)[user_id_str]?
      return 'winner'
    else
      return 'loser'

  getSideInBet: (bet, user_id)->
    user_id_str = user_id.toHexString?() || user_id
    if bet.bet_joined_points[user_id_str]
      return 'joined'
    else
      return 'accepted'

  rollbackBetPoints: (comment, callback)->
    async.each(_.union(_.keys(comment.bet_accepted_points), _.keys(comment.bet_joined_points)), (user_id_str, done)=>
      points = comment.bet_accepted_points[user_id_str] || comment.bet_joined_points[user_id_str]
      @incrementPtsBetTie(comment.siteName, dbutil.idFrom(user_id_str), comment._id, points, comment.context, done)
    , (err)->
      if err then return callback(err)
      callback(null, comment)
    )

  betPointsUser: (bet, user_id, side, callback)->
    # winning users gets their points back, + risked points from the other side
    #   if joined, the user gets risked points from all the other users
    #   if accepted, the user gets a part of the risked points of the initiator, depending on the risked amount (risked amount * ratio_joined/ration_accepted)
    #   users get back the remaining unspent risked points (not distributed to the winning side)
    winning_side = bet.bet_winning_side
    user_id_str = user_id.toHexString?() || user_id
    ratio_wj = bet.bet_ratio_accepted / bet.bet_ratio_joined
    ratio_wa = bet.bet_ratio_joined / bet.bet_ratio_accepted
    pts_won = 0
    pts_get_back = 0
    pts_all = 0
    if side == 'joined'
      pts_risked = bet.bet_joined_points[user_id_str]
      pts_risked_other = bet.bet_tpts_accepted
      if winning_side == side
        # winner
        # get back everything risked + everything risked by the other side
        pts_get_back = pts_risked
        pts_won = pts_risked_other * pts_risked / bet.bet_tpts_joined
      else
        # loser
        # can lose only a part of the points risked, depending on the amount risked by the other party
        # here we calculate how much the user gets back of the risked amount
        given = pts_risked_other * ratio_wa * pts_risked / bet.bet_tpts_joined
        pts_get_back = Math.floor(pts_risked - given)
        pts_won = 0
    else if side == 'accepted'
      # accepted
      pts_risked = bet.bet_accepted_points[user_id_str]
      pts_risked_other = bet.bet_tpts_joined
      if winning_side == side
        # winner
        # get back everything risked + everything risked by the other side
        pts_get_back = pts_risked
        pts_won = pts_risked * ratio_wa
      else
        # loser
        pts_won = 0
        pts_get_back = 0
    pts_all = pts_won + pts_get_back
    async.parallel([
      (cb)=>
        if pts_won == 0
          return cb()
        @incrementPtsBetWon(bet.siteName, dbutil.idFrom(user_id), bet._id, pts_won, bet.context, cb)
      (cb)=>
        if pts_get_back == 0
          return cb()
        @incrementPtsBetBack(bet.siteName, dbutil.idFrom(user_id), bet._id, pts_get_back, bet.context, cb)
    ], (err)->
      if err then return callback(err)
      callback(null, pts_all)
    )

  resolveBetPoints: (comment, callback)->
    pts_resolved = {}
    rollback = false
    async.waterfall([
      (cb)->
        collections.comments.findAndModify(
          {_id: comment._id, bet_status: 'resolved'},
          [],
          {$set: {bet_status: 'resolving_pts'}}
          {new: true}
          (err, result)->
            cb(err, result)
        )
      (comment, cb)=>
        if !comment
          return cb({notexists: true})
        winning_side = comment.bet_winning_side
        if winning_side == 'tie' || comment.bet_accepted.length == 0
          # give all points back
          rollback = true
          @rollbackBetPoints(comment, cb)
        else
          # all points from bet_accepted_points and bet_joined_points are transfered to the users
          async.each(_.union(_.keys(comment.bet_accepted_points), _.keys(comment.bet_joined_points)), (user_id, done)=>
            side = @getSideInBet(comment, user_id)
            @betPointsUser(comment, user_id, side, (err, pts)->
              if err
                return done(err)
              pts_resolved[user_id] = pts
              done()
            )
          , (err)->
              if err
                return cb(err)
              cb(null, comment)
          )
      (comment, cb)->
        collections.comments.findAndModify(
          {_id: comment._id, bet_status: 'resolving_pts'},
          [],
          {$set: {bet_status: 'resolved_pts', bet_points_resolved: pts_resolved, bet_rolledback: rollback}}
          {new: true}
          (err, comment)->
            cb(err, comment)
        )
      (comment, cb)=>
        pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
        @notifyBetResolvedPts(comment, (err)->
          cb(null, comment)
        )
    ], callback)

  startForfBet: (comment, callback)->
    now = moment().valueOf()
    async.waterfall([
      (cb)->
        if comment.bet_status != 'closed'
          return cb({invalid: true})
        collections.comments.findAndModify(
          {_id: comment._id, bet_status: 'closed'},
          [],
          {$set: {bet_status: 'forf', bet_forf_started_at: now, bet_close_forf_date: now + util.getValue('betForfPeriod')}, $inc: {_v: 1}},
          {new: true},
          (err, comment)->
            cb(err, comment)
        )
      (comment, cb)=>
        if !comment
          return cb({conflict: true}, null)
        @notifyBetForfStarted(comment, (err)->
          cb(err, comment)
        )
      (comment, cb)=>
        pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
        cb(null, comment)
    ], callback)

  endForfBet: (comment, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    now = moment().valueOf()
    async.waterfall([
      (cb)->
        query_end = {_id: comment._id, bet_status: 'forf'}
        if !options.force
          query_end.bet_close_forf_date = {$lte: now}
        collections.comments.findAndModify(
          query_end
          [],
          {$set: {bet_status: 'forf_closed', bet_forf_closed_at: now}, $inc: {_v: 1}},
          {new: true},
          (err, comment)->
            cb(err, comment)
        )
      (result, cb)=>
        if !result
          return cb({conflict: true}, null)
        # use the comment object from parameters to avoid conflicts with new
        # updates (in case other users forfeited) and that we can compute the
        # winning side. This method is called only when the winning side can be
        # computed using the data in 'comment'
        winning_side = @computeBetWinningSide(comment)
        to_set = {bet_status: 'resolved', bet_winning_side: winning_side}
        collections.comments.findAndModify({_id: comment._id, bet_status: 'forf_closed'}, [], {$set: to_set, $inc: {_v: 1}}, {new: true}, (err, comment)->
          cb(err, comment)
        )
      (comment, cb)=>
        if !comment
          return cb({conflict: true}, null)
        @notifyBetResolved(comment, (err)->
          cb(err, comment)
        )
      (comment, cb)=>
        pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
        cb(null, comment)
    ], callback)

  notifyBetUnresolved: (comment, callback)->
    collections.jobs.add({
      type: 'NOTIFY_BET_UNRESOLVED',
      comment: comment,
      uid: "NOTIFY_BET_UNRESOLVED_#{comment._id}"}
    , callback)

  notifyModBets: (comment, mod_profiles, notif, options, callback)->
    # get the subscription status of the users
    async.parallel([
      (cb)->
        collections.subscriptions.findIter({siteName: comment.siteName, user: {$in: _.pluck(mod_profiles, 'user')}, context: '*', active: true}, (subscription, done)->
          collections.jobs.add(_.extend({}, notif, {
            type: "EMAIL",
            emailType: notif.type,
            to: subscription.email,
            token: subscription.token,
            uid: "EMAIL_#{notif.uid}_to_#{subscription.email}"
          }), (err)->
            if err
              logger.error(err)
            done()
          )
        , cb)
      (cb)->
        async.each(mod_profiles, (p, done)->
          collections.notifications.addNotification(_.extend({}, notif, {
            user: p.user
          }), (err)->
            if err
              logger.error(err)
            done()
          )
        , cb)
    ], (err)->
      callback(err)
    )

  requestEndBet: (site, context, user, comment, callback)->
    if !comment.author.equals?(user._id)
      return process.nextTick(-> callback({needs_author: true}))
    @endBet(comment, {force: true}, callback)

  requestStartForfBet: (site, context, user, comment, callback)->
    if !comment.author.equals?(user._id)
      return process.nextTick(-> callback({needs_author: true}))
    @startForfBet(comment, callback)

  # options:
  #   force : ends the bet even if the open period has not expired
  endBet: (bet, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    options.force ?= false
    now = moment().valueOf()
    async.waterfall([
      (cb)->
        if bet.bet_status != 'open'
          return cb({invalid: true})
        query_end = {_id: bet._id, bet_status: 'open'}
        if !options.force
          query_end.bet_end_date = {$lte: now}
        collections.comments.findAndModify(query_end, [], {$set: {bet_status: 'closed', bet_closed_at: now}, $inc: {_v: 1}}, {new: true}, (err, bet)->
          return cb(err, bet)
        )
      (bet, cb)=>
        # close bets that have not been accepted
        if !bet
          return cb({conflict: true}, null)
        @notifyBetClosed(bet, (err)->
          cb(err, bet)
        )
      (bet, cb)=>
        if bet.bet_accepted.length == 0
          return async.waterfall([
            (cbi)->
              collections.comments.findAndModify({_id: bet._id, bet_status: 'closed'}, [], {$set: {bet_winning_side: 'tie', bet_status: 'resolved'}, $inc: {_v: 1}}, {new: true}, (err, bet)->
                cbi(err, bet)
              )
            (bet, cbi)=>
              if !bet
                return cb({conflict: true})
              @notifyBetResolved(bet, (err)->
                cbi(err, bet)
              )
          ], cb)
        if !bet.bet_start_forf_date? || bet.bet_start_forf_date <= bet.bet_end_date
          return @startForfBet(bet, cb)
        cb(null, bet)
      (bet, cb)=>
        pubsub.contentUpdate(bet.siteName, bet.context, collections.comments.toClient(bet))
        cb(null, bet)
    ], callback)

  # the moderator decides the winning side
  resolveBet: (site, context, user, comment_or_id, options, callback)->
    side = options.side
    if !(side in ['tie', 'joined', 'accepted'])
      return process.nextTick(-> callback({invalid_side: true}))
    async.waterfall([
      (cb)->
        if comment_or_id._id
          return cb(null, comment_or_id)
        collections.comments.findOne({_id: comment_id}, cb)
      (comment, cb)->
        if !comment || comment.type != 'BET' || !comment.approved || comment.deleted
          return cb({notexists: true})
        if comment.bet_status != 'forf'
          return cb({denied: true})
        collections.comments.findAndModify(
          {_id: comment._id, bet_status: 'forf'},
          [],
          {$set: {bet_winning_side: side, bet_status: 'resolved'}, $inc: {_v: 1}}
          {new: true}
          (err, comment)->
            cb(err, comment)
        )
      (comment, cb)=>
        util.load_field(comment, 'context', collections.conversations, cb)
      (comment, cb)=>
        if !comment
          return cb({conflict: true})
        @notifyBetResolved(comment, (err)->
          cb(err, comment)
        )
    ], callback)

  notifyBetClosed: (comment, callback)->
    collections.jobs.add(
      type: 'NOTIFY_BET_CLOSED'
      comment: comment
      uid: "NOTIFY_BET_CLOSED_#{comment._id}"
    , callback)

  notifyBetForfStarted: (comment, callback)->
    collections.jobs.add(
      type: 'NOTIFY_BET_FORF_STARTED'
      comment: comment
      uid: "NOTIFY_BET_FORF_STARTED_#{comment._id}"
    , callback)

  notifyBetForfClosed: (comment, callback)->
    collections.jobs.add(
      type: 'NOTIFY_BET_FORF_CLOSED'
      comment: comment
      uid: "NOTIFY_BET_FORF_CLOSED_#{comment._id}"
    , callback)

  notifyBetResolved: (comment, callback)->
    collections.jobs.add({
      type: 'NOTIFY_BET_RESOLVED',
      comment: comment,
      uid: "NOTIFY_BET_RESOLVED_#{comment._id}"
    }, callback)

  notifyFundComment: (comment, options, callback)->
    pubsub.contentUpdate(comment.siteName, comment.context, collections.comments.toClient(comment))
    collections.jobs.add({
      type: "FUND_COMMENT"
      siteName: comment.siteName
      comment: comment
      context: comment.context
      url: urls.for_model("comment", comment)
      uid: "FUND_COMMENT_#{comment._id.toHexString()}_#{util.uniquets()}"
      by: options.by
    }, callback)

  notifyNewChallenge: (challenge, approvedLater, cb)->
    pubsub.contentUpdate(challenge.siteName, challenge.context, collections.comments.toClient(challenge), {extra_fields: {_is_new_comment: true}})
    collections.jobs.add({
      type: "NEW_CHALLENGE"
      siteName: challenge.siteName
      challenge: challenge
      context: challenge.context
      url: urls.for_model("comment", challenge)
      uid: "NEW_CHALLENGE_#{challenge._id.toHexString()}"
      approvedLater: approvedLater
    }, cb)

  notifyVoteChallenge: (challenge, side, vote, up, user, cb)->
    collections.jobs.add({
      type: "VOTE"
      challenge: challenge
      siteName: challenge.siteName
      side: side
      up: up
      context: challenge.context
      url: urls.for_model("comment", challenge)
      by: user
    }, cb)

  notifyVoteChallengeUpDown: (challenge, side, vote, up, changes, user, cb)->
    collections.jobs.add({
      type: "VOTE_UPDOWN"
      challenge: challenge
      siteName: challenge.siteName
      side: side
      up: up
      context: challenge.context
      url: urls.for_model("comment", challenge)
      voteChanges: changes
      by: user
    }, cb)

  notifyChallengeEnd: (challenge, winner, loser, cb)->
    pubsub.contentUpdate(challenge.siteName, challenge.context, collections.comments.toClient(challenge))
    collections.jobs.add({
      type: "END_CHALLENGE"
      challenge: challenge
      siteName: challenge.siteName
      winner: winner
      loser: loser
      context: challenge.context
      url: urls.for_model("comment", challenge)
      uid: "END_CHALLENGE_#{challenge._id.toHexString()}"
    }, cb)

  author_is: (doc, id)->
    if not id?.toHexString
      return false
    debug("id: #{id.toHexString()}")
    debug("challanged: #{JSON.stringify(doc.deleted_data?.challenged?.author?.toHexString())}")
    debug("challanger: #{JSON.stringify(doc.deleted_data?.challenger?.author?.toHexString())}")
    debug("author: #{JSON.stringify(doc.deleted_data?.author?.toHexString())}")
    if doc.deleted_data?.challenged?.author?.toHexString && doc.deleted_data.challenged.author?.toHexString() == id.toHexString()
      return true
    else if doc.deleted_data?.challenger?.author?.toHexString && doc.deleted_data.challenger.author.toHexString() == id.toHexString()
      return true
    else if doc.deleted_data?.author?.toHexString
      return doc.deleted_data.author.toHexString() == id.toHexString()
    return false

  history: (site, user, paging, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    if paging?.from
      debug("paging: #{JSON.stringify(paging)}")
      collections.comments.find({_id: {$lt: dbutil.idFrom(paging.from)}, approved: true, deleted: {$ne: true}, author: user, siteName: site.name}, {limit: util.getValue("commentsPerPage"), sort: {_id: -1}}, callback)
    else
      debug("NO paging")
      collections.comments.find({author: user, siteName: site.name, approved: true, deleted: {$ne: true}}, {limit: util.getValue("commentsPerPage"), sort: {_id: -1}}, callback)

  toClientWithVote: (doc, callback, moderator, client)->
    debug("toClientWithVote: #{doc._id}")
    doc = collections.comments.toClient(doc, moderator, client)
    if !doc._id
      return callback(null, doc)
    doc.has_voted = 0
    if client
      collections.likes.findOne({comment: doc._id, user: client._id}, (err, like)->
        if like
          doc.has_voted = like.dir
        debug("has_voted: #{doc.has_voted}")
        callback(err, doc)
      )
    else
      callback(null, doc)

  toClient: (doc, moderator, client)->
    if doc.deleted
      debug("preparing comment for client, moderator = %j, deleted = %j, id = %j, client %j", !!moderator, doc.deleted, doc._id, client != null)
    if !doc.approved && !moderator
      return {approved: false}
    if doc.deleted && !moderator && !collections.comments.author_is(doc, client?._id)
      debug("NOT SENDING deleted_data for: #{JSON.stringify(doc, null, 2)}")
      doc = _.pick(doc, ["_id",
        "_v",
        "deleted",
        "type",
        "cat",
        "siteName",
        "level",
        "parent",
        "context",
        "no_comments",
        "rating",
        "created",
        "changed",
        "order_time",
        "url",
        "edited_at",
        "questionPointsOffered",
        "finished"
      ])
      debug("preparing deleted comment for regular client, deleted_data = %j, id = %j", doc.deleted_data, doc._id)
    else if doc.type == "CHALLENGE"
      doc = _.pick(doc, ["_id",
        "_v",
        "deleted",
        "deleted_data",
        "created",
        "changed",
        "summary",
        "challenger",
        "challenged",
        "parent",
        "no_comments",
        "approved",
        "no_flags",
        "uri",
        "initialUrl",
        "context",
        "siteName",
        "type",
        "cat",
        "rating",
        "order_time",
        "ends_on",
        "finished",
        "url",
        "spam",
        "modified_by_user",
        "edited_at",
        "has_voted",
        "funded",
        "is_funded"
      ])
      if !moderator
        if doc.deleted_data
          delete doc.deleted_data.challenged.guest?.email
          delete doc.deleted_data.challenger.guest?.email
        else
          delete doc.challenged.guest?.email
          delete doc.challenger.guest?.email
    else
      doc = _.pick(doc, ["_id",
        "_v",
        "deleted",
        "deleted_data",
        "created",
        "changed",
        "no_likes",
        "no_likes_down",
        "no_votes",
        "text",
        "author",
        "parent",
        "no_comments",
        "uri",
        "initialUrl",
        "question",
        "answer",
        "approved",
        "no_flags",
        "catParent",
        "inChallenge",
        "context",
        "contextType",
        "level",
        "siteName"
        "ptext",
        "type",
        "cat",
        "rating",
        "challengedIn",
        "order_time",
        "best",
        "ends_on",
        "url",
        "spam",
        "forum",
        "guest",
        "modified_by_user",
        "edited_at",
        "has_voted",
        "promote",
        "promoter",
        "promotePoints",
        "questionPointsOffered",
        "finished",
        "funded",
        "is_funded",
        "bet_targeted",
        "bet_joined",
        "bet_accepted",
        "bet_forfeited",
        "bet_claimed",
        "bet_joined_points",
        "bet_accepted_points",
        "bet_ratio_joined",
        "bet_ratio_accepted",
        "bet_declined",
        "bet_tpts_joined",
        "bet_tpts_accepted",
        "bet_tpts_av",
        "bet_pts_tuser",
        "bet_tpts_av_tuser",
        "bet_tpts_av_ntusers",
        "bet_pts_max_user",
        "bet_status",
        "bet_type",
        "bet_winning_side",
        "bet_points_resolved",
        "bet_end_date",
        "bet_start_forf_date",
        "bet_close_forf_date",
        "bet_requires_mod"
      ])
    if !moderator
      delete doc.guest?.email
    if doc.context?._id
      doc.context = collections.conversations.toClient(doc.context, moderator, client)
    if doc.author?._id
      doc.author = doc.author._id
    if doc.parent?._id
      if doc.level == 1
        doc.parent = collections.conversations.toClient(doc.parent, moderator, client?._id && client || null)
      else
        doc.parent = collections.comments.toClient(doc.parent, moderator, client?._id && client || null)
    if doc.challenged?._id
      doc.challenged.approved = true
      doc.challenged = collections.comments.toClient(doc.challenged, moderator, client)
    if doc.challenger
      doc.challenger.approved = true
      doc.challenger = collections.comments.toClient(doc.challenger, moderator, client)
    return doc

_.extend(Comments.prototype, require("./mixins").sorting)

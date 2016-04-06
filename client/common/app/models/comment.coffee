comparators = require('comparators')
User = require("models/user")
comparators = require('comparators')

module.exports = class Comment extends Backbone.GraphModel

  @betTypes = ['open', 'targeted_open', 'targeted_closed']
  @betStatusTypes = ['open', 'closed', 'forf', 'forf_closed', 'resolved', 'resolving_pts', 'resolved_pts']

  urlRoot: ->
    return "/api/sites/#{@get("siteName")}/activities"

  defaults:
    "no_likes": 0
    "no_likes_down": 0
    "no_votes": 0
    "no_comments": 0
    "no_flags": 0

  initialize: ->
    super
    @on('change:type', (model, type, opt)=>
      prev = @previous('type')
      comments = @get('comments')
      if type == 'QUESTION'
        if prev == 'COMMENT' || !prev?
          comments.comparator = comparators.likesDesc
          comments.on('change:no_likes', comments.sort, this)
      else
        if prev == 'QUESTION'
          comments.comparator = null
          comments.off('change:no_likes', comment.sort, this)
    )

  set: (key, value, options)->
    [attrs, options] = @prepareSetParams(key, value, options)
    options = options ? {}
    if attrs?.guest && !attrs?.author
      attrs?.author = attrs?.guest
    if options.rt && attrs?.deleted && @get("author")?.id == options?.current_user_id
      if !attrs.deleted_data
        # fake deleted data, the model contains the text anyway
        attrs.deleted_data = {}
    if attrs?.deleted_data
      # copy attributes in order to render like a normal comment
      attrs = _.extend(attrs, attrs.deleted_data)
    return super(attrs, options)

  relations: [
    {
      key: "comments"
      type: {ctor:
        class Comments extends Backbone.GraphCollection
          model: Comment
          url: ->
            return @container.url() + "/comments"
          comparator: comparators.timeAsc
      }
      reverseKey: "parent"
    },
    {
      key: "challengedIn"
      type: {provider: -> require("models/challenge")}
      autoCreate: true
    },
    {
      key: "challenge"
      type: {provider: -> require("models/challenge")}
      reverseKey: ["challenger", "challenged"]
      events: true
    },
    {
      key: "author"
      type: {provider: -> User}
      autoCreate: true
      events: true
      ignoreId: true
    },
    {
      key: "context"
      type: {provider: -> require("models/context")}
      autoCreate: true
      reverseKey: "allactivities"
    },
    {
      key: "promoter"
      type: {provider: -> require("models/user")}
      autoCreate: true
      events: true
    },
    {
      key: 'bet_targeted'
      type: {ctor:
        class Targeted extends Backbone.GraphCollection
          parse: (models)->
            return _.map(models, (m)-> {_id: m})
          model: User
      }
      serialize: true
    },
    {
      key: 'bet_accepted'
      type: {ctor:
        class Accepted extends Backbone.GraphCollection
          parse: (models)->
            return _.map(models, (m)-> {_id: m})
          model: User
      }
      serialize: true
    },
    {
      key: 'bet_declined'
      type: {ctor:
        class Declined extends Backbone.GraphCollection
          parse: (models)->
            return _.map(models, (m)-> {_id: m})
          model: User
      }
      serialize: true
    },
    {
      key: 'bet_forfeited'
      type: {ctor:
        class Forfeited extends Backbone.GraphCollection
          parse: (models)->
            return _.map(models, (m)-> {_id: m})
          model: User
      }
      serialize: true
    },
    {
      key: 'bet_claimed'
      type: {ctor:
        class Claimed extends Backbone.GraphCollection
          parse: (models)->
            return _.map(models, (m)-> {_id: m})
          model: User
      }
      serialize: true
    },
    {
      key: 'bet_joined'
      type: {ctor:
        class Joined extends Backbone.GraphCollection
          parse: (models)->
            return _.map(models, (m)-> {_id: m})
          model: User
      }
      serialize: true
    },
    {
      key: "parent"
      reverseKey: "comments"
      autoCreate: true
      type: {provider: ->
        if @get("cat") == "CHALLENGE" && @get("level") == 2
          return require("models/challenge")
        else if @get("level") > 1
          return Comment
        else if @get("level") == 1
          return require("models/context")
      }
      events: true
    },
    {
      key: "ref"
      type: {provider: -> Comment}
      autoCreate: true
    }
  ]

  level: ->
    lvl = 0
    parent = @get("parent")
    while parent
      lvl++
      parent = parent.get("parent")
    return lvl

  totalLikes: ->
    return @get("no_likes")

  totalVotes: ->
    return @get("no_votes")

  sideInChallenge: ->
    challenge = @get("challenge")
    if challenge
      return (if challenge.get("challenged") == this then "challenged" else "challenger")
    return null

  updateCommentParentCount: (inc)->
    parent = @get("parent")
    if @get("question")
      noQuestions = parent.get("no_questions")
      parent.set("no_questions": noQuestions + inc)
    else
      noComments = parent.get("no_comments")
      parent.set("no_comments": noComments + inc)
    if !@get("parentIsChallenge") && !@get("parentIsConversation") && !(@get("answer") || @get("question"))
      catParent = @_store.models.get(@get("catParent"))
      if catParent
        noComments = catParent.get("no_comments")
        catParent.set("no_comments": noComments + inc)

  # like: ->
  #   @save({no_likes: 1}, {wait: true, url: @url() + "/like"})

  # vote: (value)->
  #   if !@get("challenge")
  #     return
  #   side = if @get("challenge").get("challenger") == this then "challenger" else "challenged"
  #   @get("challenge").save(null, {url: @get("challenge").url() + "/vote", data: !!(value > 0), side: side})

#   fund: (token, value)->
#     params =
#       token: token
#       value: value
#     side = @sideInChallenge()
#     if side
#       params.side = side
#       return @get('challenge').save(null, {
#         wait: true
#         @get('challenge').url() + '/fund'
#         data: params
#         processData: true
#       }
#     @save(null, {
#       wait: true
#       url: @url() + "/fund"
#       data: params
#       processData: true
#     })

  dispose: ->
    if @_disposed
      return
    for comment in @get("comments")?.toArray()
      comment.dispose()
    super

  parse: (attrs, options)->
    if !attrs?
      return null
    if attrs == @attributes
      return null
    options ?= {}
    if options.rt
      if options.rt_parent
        attrs.rt_parent = true
      if !attrs._is_new_comment && !options.rt_parent && !@get('parent')?
        # don't show edits to existing unfetched comments as real time
        # but preserve state (parent) of comments that are already loaded
        # return null
        attrs.parent = null
        attrs._v = -1
      # mark realtime comments
      # don't mark if comment is not new or rt
      author_id = @get('author')?.id || attrs.author?.id || attrs.author
      if (attrs._is_new_comment || options.rt_parent) &&
        !options._self &&
        ((!options.rt_parent && author_id != options.current_user_id) || !options.logged_in)
          attrs._is_realtime = true
    if attrs.deleted
      _.extend(attrs, attrs.deleted_data)
    # use ghost when the comments should not be added to the tree and rendered
    if options?.history || options?.funded || options?.ghost
      attrs.parent = null
      attrs._v = -1
    return super

_.extend(Comment.prototype, require("models/mixins").userContent)

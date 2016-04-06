PagedCollection = require("collections/paged_collection")
Collection = require("collections/base_collection")
Comment = require("models/comment")
Challenge = require("models/challenge")
Profile = require("models/profile")
comparators = require('comparators')

module.exports = class Context extends Backbone.GraphModel
  defaults:
    "no_comments": 0
    "no_challenges": 0
    "no_questions": 0
    "no_all_activities": 0
    "no_activities": 0
    "no_all_comments": 0

  set: (attrs, options)->
    if !attrs
      return
    if attrs.siteName && @get("site")?.get?("name") != attrs.siteName
      attrs.site = attrs.siteName
    super

  get: (name)->
    if name == "text"
      return @attributes.text || super("initialUrl")
    super

  urlRoot: ->
    return "/api/sites/#{@get("siteName")}/contexts"

  initialize: =>
    super
    @get("comments").on("add", (model)=>
      @get("activities").add(model)
    , this)
    @get("comments").on("remove", (model)=>
      @get("activities").remove(model)
    , this)
    @on('change:comment', (comment)=>
      comment?.attributes?.siteName = @get('siteName')
    , this)
    @get('comment')?.attributes?.siteName = @get('siteName')
    @get("promoted").on("change:deleted", (model)=>
      _.defer(=>
        if model.get('deleted') && !@_disposed
          @get("promoted").remove(model.id)
      )
    )
    @get('newcomments').on('add', (model)=>
      @inc('no_new_activities', 1)
    )
    @get('newcomments').on('remove', (model)=>
      @inc('no_new_activities', -1)
    )

  relations: [
    {
      # Used for keeping track of new comments, received in real-time
      key: "newcomments"
      type: {ctor:
        class Comments extends PagedCollection
          model: (attrs, options)->
            if attrs.type == "CHALLENGE"
              return new Challenge(attrs, options)
            else
              return new Comment(attrs, options)
      }
    },
    {
      # Used for fetching comments
      key: "allactivities"
      type: {ctor:
        class Comments extends PagedCollection
          model: (attrs, options)->
            if attrs.type == "CHALLENGE"
              return new Challenge(attrs, options)
            else
              return new Comment(attrs, options)
          url: ->
            return @container.url() + "/allactivities"
      }
    },
    {
      # Direct descendants, currently used for rendering
      # Duplicate of `comments`, but managed manually
      key: "activities"
      type: {ctor:
        class Comments extends PagedCollection
          model: (attrs, options)->
            if attrs.type == "CHALLENGE"
              return new Challenge(attrs, options)
            else
              return new Comment(attrs, options)
          url: ->
            return @container.url() + "/activities"
      }
    },
    {
      key: "promoted"
      type: {ctor:
        class Comments extends PagedCollection
          model: (attrs, options)->
            return new Comment(attrs, options)
          url: ->
            return @container.url() + "/promoted"
          comparator: comparators.promoted
      }
    },
    {
      # First level comments (~ direct descendants ~ children)
      key: "comments"
      type: {ctor:
        class Comments extends PagedCollection
          model: Comment
          url: ->
            return @container.url() + "/comments"
      }
      reverseKey: "parent"
    },
    {
      key: "funded_activities"
      type: {ctor:
        class FundedComments extends PagedCollection
          model: (attrs, options)->
            if attrs.type in ['COMMENT', 'QUESTION']
              return new Comment(attrs, options)
            else
              return new Challenge(attrs, options)
          url: ->
            return @container.url() + '/funded_activities'
          comparator: comparators.objectidDesc
      }
    },
    {
      key: "comment"
      type: {ctor: Comment}
      autoCreate: true
      events: true
    },
    {
      key: "author"
      type: {provider: -> require("models/user")}
      autoCreate: true
    },
    {
      key: "site"
      type: {provider: -> require("models/site")}
      autoCreate: true
      reverseKey: "contexts"
    },
    {
      key: "convprofiles"
      type: {ctor: class ConvProfiles extends PagedCollection
        model: require("models/convprofile")
        url: ->
          @container.url() + "/convprofiles"
      }
      reverseKey: "context"
    },
    {
      key: "topcommenters"
      type: {ctor: class TopCommenters extends PagedCollection
        model: require("models/user")
        url: ->
          @container.url() + "/topcommenters"
      }
    }
  ]

  computeLink: (hash = true)->
    the_hash = if hash then "#conversait_area" else "#"
    if @get("type") == "ARTICLE"
      return (@get("initialUrl") || @get("uri")) + the_hash
    else
      # forum
      return (@get("site")?.get("forum")?.url || @get("initialUrl") || @get("uri")) + the_hash

  removeAllActivities: (purge = true)->
    activities = @get("allactivities").toArray()
    @get("activities").reset([], {silent: true}).trigger('reset')
    @get("allactivities").reset([], {silent: true}).trigger('reset')
    for comment in activities
      comment.detachFromParent()

  hasMoreActivities: ->
    return @get("no_all_activities") > @get("allactivities").length && @get('allactivities').hasMore()

  fetchComment: (id, options)->
    fakeModel = new Backbone.Model({siteName: @get("siteName"), _id: id}, {urlRoot: Comment.prototype.urlRoot})
    success = options.success
    error = options.error
    options.success = (resp)->
      fakeModel.dispose()
      success && success(resp)
    options.error = (model, resp, options)->
      fakeModel.dispose()
      error && error(model, resp, options)
    @get("allactivities").fetch(_.extend({}, options, {parse: false, remove: false, url: Comment.prototype.url.call(fakeModel), recursiveParents: true}))

  fetchLeaders: ->
    @get("convprofiles").fetch({url: @url() + "/leaders"})

  minPromotePoints: (limit, min_cost)->
    if @get('promoted').length >= limit
      return @get('promoted').at(limit - 1).get("promotePoints") + 1
    else
      return -min_cost

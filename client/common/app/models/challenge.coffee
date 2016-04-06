comparators = require('comparators')
Comment = require("models/comment")
PagedCollection = require("collections/paged_collection")

module.exports = class Challenge extends Backbone.GraphModel

  urlRoot: ->
    return "/api/sites/#{@get("siteName")}/activities"

  defaults:
    "no_comments": 0
    "summary": ""
    "no_flags": 0
    "ends_on": 0

  set: (key, value, options)->
    [attrs, options] = @prepareSetParams(key, value, options)
    options = options ? {}
    if options?.rt && attrs?.deleted && !attrs?.deleted_data && (@get("challenger").get("author").id == options?.current_user_id || @get("challenged").get("author").id == options?.current_user_id)
      attrs.deleted_data = {}
    return super(attrs, options)

  relations: [
    {
      key: "allcomments"
      type: {ctor:
        class Comments extends PagedCollection
          model: Comment
          url: ->
            return "/api/sites/#{@container.get("siteName")}/activities/#{@container.id}/pageallcomments"
      }
    },
    {
      key: "comments"
      type: {ctor:
        class Comments extends PagedCollection
          model: Comment
          url: ->
            return "/api/sites/#{@container.get("siteName")}/activities/#{@container.id}/comments"
          comparator: comparators.timeAsc
      }
      reverseKey: "parent"
    },
    {
      key: "challenged"
      type: {provider: -> Comment}
      reverseKey: "challenge"
      autoCreate: true
      ignoreId: true
      autoDelete: true
    },
    {
      key: "challenger"
      type: {provider: -> Comment}
      reverseKey: "challenge"
      autoCreate: true
      ignoreId: true
      autoDelete: true
    },
    {
      key: "context"
      type: {provider: -> require("models/context")}
      autoCreate: true
      reverseKey: "allactivities"
    },
    {
      key: "parent"
      type: {provider: -> require("models/context")}
      reverseKey: "comments"
    }
  ]

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
      challenger_id = @get('challenger')?.get?('author')?.id || @get('challenger')?.author || attrs.challenger?.author?.id || attrs.challenger?.author
      if (attrs._is_new_comment || options.rt_parent) &&
        !options._self &&
        ((!options.rt_parent && challenger_id != options.current_user_id) || !options.logged_in)
          attrs._is_realtime = true
    if attrs.deleted
      _.extend(attrs, attrs.deleted_data)
    # use ghost when the comments should not be added to the tree and rendered
    if options?.history || options?.funded || options?.ghost
      attrs.parent = null
      attrs._v = -1
    return super

_.extend(Challenge.prototype, require("models/mixins").userContent)

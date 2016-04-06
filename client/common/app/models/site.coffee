PagedCollection = require("collections/paged_collection")
Comment = require("models/comment")
Challenge = require("models/challenge")
Competition = require("models/competition")
Context = require("models/context")
ModActivities = require("collections/modActivities")
comparators = require('comparators')

module.exports = class Site extends Backbone.GraphModel

  defaults:
    forum:
      tags: []
    no_conversations: 0
    no_conversations_filtered: 0
    no_forum_conversations: 0
    no_profiles: 0

  set: (attrs, options)->
    if attrs.name && !@id && !attrs[@idAttribute]
      attrs[@idAttribute] = attrs.name
    if !@get("name") && !attrs.name
      attrs.name = attrs[@idAttribute]
    if options?.filterCount
      attrs.no_conversations_filtered = attrs.result
      delete attrs.result
    super

  url: ->
    return "/api/sites/#{@get("name")}"

  relations: [
    {
      key: "contexts"
      type: {ctor: class Contexts extends PagedCollection
        model: require("models/context")
        url: ->
          @container.url() + "/contexts"
      }
    },
    {
      key: "profiles"
      type: {ctor: class Profiles extends PagedCollection
        model: require("models/profile")
        url: ->
          @container.url() + "/profiles"
      }
    },
    {
      key: "filtered_profiles"
      type: {ctor: class Profiles extends PagedCollection
        model: require("models/profile")
        url: ->
          @container.url() + "/profiles"
      }
    },
    {
      key: "competitions"
      type: {ctor: class Competitions extends PagedCollection
        model: Competition
        url: ->
          @container.url() + "/competitions"
      }
    },
    {
      key: "active_competitions"
      type: {ctor: class Competitions extends PagedCollection
        model: Competition
        url: ->
          @container.url() + "/competitions/active"
      }
    },
    {
      key: "active_competition"
      type: {provider: -> require("models/competition")}
      autoCreate: true
      events: true
    },
    {
      key: "activities"
      type: {ctor: ModActivities}
    },
    {
      key: "allactivities"
      type: {ctor: ModActivities}
    },
    {
      key: "bets"
      type: {ctor: class Bets extends PagedCollection
        model: Comment
        url: ->
          @container.url() + '/bets'
      }
    },
    {
      key: "unresolved_bets"
      type: {ctor: class UnresolvedBets extends PagedCollection
        model: Comment
        url: ->
          @container.url() + '/unresolved_bets'
      }
    },
    {
      key: "funded_activities"
      type: {ctor: class FundedComments extends PagedCollection
        model: (attrs, options)->
          if attrs.type in ['COMMENT', 'QUESTION']
            return new Comment(attrs, options)
          else
            return new Challenge(attrs, options)
        url: ->
          return @container.url() + '/funded_activities'
        comparator: comparators.objectidDesc
      }
    }
  ]

  fetchLeaders: ->
    @get("profiles").fetch({url: @url() + "/leaders"})

  # moderator only
  # total subscribers
  fetchSubscrCount: ->
    @fetch({url: "#{@url()}/subscriptions/count"})

  # moderator only
  # verified subscribers
  fetchSubscrCountV: ->
    @fetch({url: "#{@url()}/subscriptions/count", data: {verified: 1}})

  # moderator only
  # verified and active subscribers
  fetchSubscrCountVA: ->
    @fetch({url: "#{@url()}/subscriptions/count", data: {verified: 1, active: 1}})

  fetchProfileCount: ->
    @fetch({url: @url() + '/profiles/count', map: {result: 'no_profiles'}})

  fetchBetCountByFilter: (filter)->
    @fetch({url: @url() + "/bets/count?status=#{filter.status}", map: {result: 'no_bets_filtered'}})

  fetchContext: (id, options)->
    fakeModel = new Backbone.Model({siteName: @get("name"), _id: id}, {urlRoot: Context.prototype.urlRoot})
    success = options.success
    error = options.error
    options.success = (resp)->
      fakeModel.dispose()
      success && success(resp)
    options.error = (model, resp, options)->
      fakeModel.dispose()
      error && error(model, resp, options)
    @get("contexts").fetch(_.extend({}, options, {parse: false, remove: false, url: Context.prototype.url.call(fakeModel)}))

  hasMoreContexts: (filtering, reset)->
    return ((filtering && @get("no_conversations_filtered") || @get('no_forum_conversations')) > @get("contexts").length) &&
      (reset || @get('contexts').hasMore())

  hasMoreBets: (filtering, reset)->
    return (@get("no_bets_filtered") > @get("bets").length) &&
      (reset || @get('bets').hasMore())

  fetchContextsCountByFilter: (filter)->
    @fetch({url: @get("contexts").url() + "/count", data: filter, filterCount: true})

  removeAllContexts: ->
    contexts = @get("contexts").toArray()
    @get("contexts").reset([], {silent: true}).trigger('reset')
    for context in contexts
      context.set({_v: -1})

  inlineTags: ->
    result = []
    parents = []
    last_level = 0
    count = 0
    _.walkTree(@get('forum').tags.tree, 'subtags', (t, parent, level)->
      if level > last_level
        parents.push(parent)
      else if level < last_level
        parents.pop()
      last_level = level
      search = [t.displayName]
      for prev_p in parents
        search.push(prev_p.displayName)
      option = _.extend({}, t, {parent: parent, level: level, parents: parents.slice(), initial_order: count, search: search.join(' ')})
      result.push(option)
      count++
    )
    return result

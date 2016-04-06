PagedCollection = require("collections/paged_collection")

module.exports = class User extends Backbone.GraphModel

  defaults:
    no_notif_unread: 0
    no_notif_new: 0
    notifReadUntil: "0"
    no_bets_filtered: 0

  urlRoot: ->
    "/api/users"

  constructor: ->
    @relations = [
      {
        key: "notifications"
        type: {ctor: require("collections/userNotifications")}
      },
      {
        key: "history"
        type: {provider: -> require("collections/commentHistory")}
      },
      {
        key: "profile"
        type: {provider: -> require("models/profile")}
        autoCreate: true
        reverseKey: "user"
        ignoreId: true
        events: true
      },
      {
        key: "formerge"
        type: {ctor: class UsersToMerge extends PagedCollection
          model: Backbone.GraphModel
          url: ->
            @container.url() + "/formerge"
        }
      },
      {
        key: "bets"
        type: {ctor: class Bets extends PagedCollection
          model: require('models/comment')
          url: ->
            @container.url() + "/bets/#{app.api.site.get('name')}"
        }
      }
    ]
    super

  hasMoreBets: (filtering, reset)->
    return (@get("no_bets_filtered") > @get("bets").length) &&
      (reset || @get('bets').hasMore())

  initialize: (attrs, options)->
    if !options.relation || options.relation.reverse != 'profile'
      if !@get("profile")
        Profile = require("models/profile")
        @set("profile": new Profile({user: this}))
    super
    @get("notifications").on("add", (model, col, options)=>
      if options.rt
        @set({no_notif_unread: @get("no_notif_unread") + 1})
        @set({no_notif_new: @get("no_notif_new") + 1})
    , this)
    @get("notifications").on("reset", (collection)=>
      if collection.length == 0
        @set({no_notif_unread: 0})
        @set({no_notif_new: 0})
    , this)

  set: (attrs, options)->
    if options?.countNew
      attrs.no_notif_new = attrs.result
      delete attrs.result
    else if options?.countUnread
      attrs.no_notif_unread = attrs.result
      delete attrs.result
    super

  fetchBetCountByFilter: (filter)->
    @fetch({url: @get('bets').url() + '/count', data: filter, one: false, map: {result: 'no_bets'}})

  fetchUnreadNotificationCount: ->
    @fetch({url: @get("notifications").url() + "/countunread", countUnread: true, one: false})

  fetchNewNotificationCount: ->
    @fetch({url: @get("notifications").url() + "/countnew", countNew: true, one: false})

  readNotif: (notif)->
    notif.save({read: true}, {wait: true, success: =>
      @set("no_notif_unread", @get("no_notif_unread") - 1)
    })

  mergeWith: (withUserDesc)->
    options = {url: @url() + "/merge"}
    options.error = Backbone.wrapError(options.error, withUserDesc, options)
    options.success = =>
      withUserDesc.set(merging: true)
    (withUserDesc.sync || Backbone.sync).call(withUserDesc, 'create', withUserDesc, options)

  seenNotif: ->
    if @get("no_notif_new") > 0
      @save(null, {
        wait: true,
        url: @get("notifications").url() + "/read",
        success: =>
          @set("no_notif_new", 0)
      })

  removeLogin: (provider, options)->
    options ?= {}
    @save(null, _.extend(options, {
      wait: true
      url: @url() + "/rmlogin"
      data: {p: provider}
      processData: true
    }))

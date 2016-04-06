MainView = require("views/main_view")
MainRouter = require("routers/main_router")
Site = require("models/site")
HttpRequest = require("lib/httprequest")
Comment = require("models/comment")
Competition = require("models/competition")
Challenge = require("models/challenge")
Profile = require("models/profile")
User = require("models/user")
localization = require("localization")

module.exports = class Application

  initialize: (options, container)->
    @options = options ? {}
    # @siteName = options.siteName

    # @user = new User(options.user)
    # @model = new Site(_.extend(options.site, name: @siteName, verified_leaderboard: options.verified_leaderboard, timezone: options.timezone, badges: options.badges))
    @api = @options.api

    @views = {}
    @views.main = new MainView(model: @api.site)
    @container = container
    @container.append(@views.main.render().el)
    @store = Backbone.graphStore

    @usersToFetch = {}

#     @store.getCollection(User, true).on("add", (user)=>
#       _.defer(->
#         if !user.get("name")
#           user.fetch()
#       )
#     )

    # set siteName for the competition when adding to collection
    # @store.getCollection(Competition, true).on("add", (comp)=>
    #   comp.set("siteName": @siteName)
    # , this)

    removeOnApprove = (item, approve)=>
      if approve
        _.defer(=>
          @api.site.get("activities").remove(item)
        )
    removeOnNoFlags = (item, flags)=>
      if flags == 0
        _.defer(=>
          @api.site.get("activities").remove(item)
        )

    removeOnDeleted = (item, deleted)=>
      if deleted
        _.defer(=>
          @api.site.get("activities").remove(item)
        )

    removeOnBetResolved = (item, status)=>
      if status == 'resolved' || status == 'resolved_pts'
        _.defer(=>
          @api.site.get("unresolved_bets").remove(item)
        )

    @api.site.get("activities").on("change:approved", removeOnApprove)
    @api.site.get("activities").on("change:no_flags", removeOnNoFlags)
    @api.site.get("activities").on("change:deleted", removeOnDeleted)
    @api.site.get("unresolved_bets").on("change:bet_status", removeOnBetResolved)

    # @store.getCollection(Profile, true).on("add", (profile)=>
    #   if !profile.get("siteName")
    #     profile.set("siteName": @api.site.get("name"))
    # )

    # @server = new HttpRequest()
    @router = new MainRouter()

    Backbone.history.start()
    @router.navigate(document.location.hash)
    @api.modSubscription()
  #
  # Expose useful methods here
  translate: localization.translate

_.extend(Application.prototype, Backbone.Events)

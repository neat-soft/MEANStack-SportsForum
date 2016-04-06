Comment = require("models/comment")
Challenge = require("models/challenge")
Context = require("models/context")
User = require("models/user")
PollingSubscriber = require("lib/poll-subscriber")
HttpRequest = require("lib/httprequest")
sharedUtil = require("lib/shared/util")
analytics = require("lib/analytics")
UserNotification = require("models/userNotification")
util = require("lib/util")
View = require("views/base_view")
MainRouter = require("routers/main_router")
AppRouter = require("routers/app")
Site = require("models/site")
ContextView = require("views/context_view")
Profile = require("models/profile")
UsersCollection = require("collections/users")
localization = require("localization")
ForumView = require("views/forum_view")
SubscriptionWidgetView = require("views/subscriptionWidget_view")
DiscoveryWidgetView = require("views/discoveryWidget_view")
VisibilityManager = require("visibilityManager")

module.exports = class EmbeddedApplication

  language_ids: "en zh fr de it ja pl pt ru es".split(" ")
  current_language: null
  languages: {}

  load_translations: ->
    for lang in @language_ids
      mod = require("localization-#{lang}")
      if mod
        lang = lang.toUpperCase()
        @languages[lang] = mod
        @languages[lang].id = lang

  find_language: (lang)->
    lang = lang?.toUpperCase()

    # return @languages[lang] || @languages[lang.replace("-", "_")] || @languages[lang.split("-")[0]] || @languages.en

    tr = @languages[lang]
    if tr
      return tr

    lang2 = lang.replace("-", "_")
    if lang2 != lang
      tr = @languages[lang2]
    if tr
      return tr

    lang3 = lang.split("-")[0]
    if lang3 != lang
      tr = @languages[lang3]
    if tr
      return tr

    return @languages.en

  set_language_by_id: (id)->
    id = id?.toUpperCase()
    lang = @find_language(id)
    @current_language = lang
    localization.load(lang)

  get_local_storage: (key)->
    try
      return if window.localStorage then window.localStorage.getItem(key) else null
    catch e
      return null

  set_local_storage: (key, value)->
    try
      if window.localStorage
        window.localStorage.setItem(key, value)
        return true
    catch e
      return false

  # save selected language to user profile (for logged in user) or local storage
  save_language: (lid)->
    if @api.loggedIn()
      @api.user.set("language", lid)
      @api.user.save()
    else
      @set_local_storage("language", lid)

  save_comment_autoload: (checked)->
    if @api.loggedIn()
      @api.user.set("comments", {instant_show_new: checked})
      @api.user.save()
    else
      return @set_local_storage("comments.instant_show_new", checked)

  has_comment_autoload: ->
    if @api.loggedIn()
      checked = @api.user.get("comments")?.instant_show_new || false
    else
      checked = @get_local_storage("comments.instant_show_new") == "true"
    return checked

  setup_rpc: ->
    # we call this function from IE when we need to post a message to the
    # parent window from a popup (which is not supported in IE 8-9)
    # it only works if we open the popup ourselves (the same domain)
    window.iePostMessage = (message)->
      window.postMessage(message, "*")

    $(window).on("message", (ev)=>
      if ev.originalEvent.origin != @options.baseUrl
        return
      parts = ev.originalEvent.data?.split(" ")
      if parts[0] == "burnzone-rpc"
        event = "rpc:" + parts[1]
        args = parts[2..].join(" ")
        event_ns = event.split(":")
        for i in [1..event_ns.length]
          id = event_ns.slice(0, i).join(":")
          prefix = event_ns.slice(i).join(":")
          @api.trigger(id, args, prefix)
    )

  setup_stripe: ->
    @stripe_checkout = StripeCheckout.configure({
      key: @options.stripePk
      image: @api.site.get("logo")
      token: (token)=>
        @stripe_checkout.token_callback(token)
    })
    $(window).on('popstate', =>
      @stripe_checkout.token_callback = null
      @stripe_checkout.close()
    )

  initialize: (options, integrationData)->
    @options = options ? {}
    @integration = integrationData || {}
    @api = options.api
    @views = {}
    @urlHistory = []
    @parentPageOffset = {top: 0, left: 0}
    @parentPageSize = {height: 0, width: 0}

    @is_ios = /(iPad|iPhone|iPod)/gi.test(navigator.userAgent)
    @is_android = /(Android)/gi.test(navigator.userAgent)
    @is_mobile = @is_ios || @is_android
    body = $('body')
    if @is_mobile
      body.addClass('mobile')
    if @is_ios
      body.addClass('ios')
    if @is_android
      body.addClass('android')

    # will load any language here in the future
    @load_translations()
    @set_language_by_id(@get_local_storage("language") || navigator.language || navigator.userLanguage)

    @setup_rpc()
    @setup_stripe()
    @container = options.container || $("body")
    @serverTime = options.serverTime
    @initTime = new Date().getTime()
    @startTimestampTimer()

    @showLoading()
    # @visManager = new VisibilityManager()

    if @options.status != "OK"
      @showErrorLoading()
      return false
    @ssoData = integrationData.sso
    if @integration.hash
      @parentHash = @integration.hash.substring(1)
    @logins ?=
      thirdParty:
        facebook:
          logo: "/img/f_logo.png"
          loginUrl: options.loginUrl + "/facebook"
        twitter:
          logo: "/img/twitter_icon.png"
          loginUrl: options.loginUrl + "/twitter"
        google:
          logo: "/img/google_icon.png"
          loginUrl: options.loginUrl + "/google"
        disqus:
          logo: "/img/disqus_icon.png"
          loginUrl: options.loginUrl + "/disqus"
      own:
        logo: "/img/burnzone_icon.png"
        loginUrl: if options.loginUrl then options.loginUrl + "/signin?popup=true" else null
        logoutUrl: if options.loginUrl then options.loginUrl + "/logout?redirect=#{@integration.url}" else null

    navigate = (model, opts)=>
      unlinked = model.firstUnlinked()
      if unlinked instanceof Context
        @goUrl(Backbone.history.getHash(), true)
        opts.callback?()
        return
      unlinked.set("siteName": @api.site.get("name"))
      unlinked.fetch({forNavigation: true, callback: opts.callback})
      unlinked.once("sync", ->
        navigate(model, opts)
      , this)

    @api.store.models.on("add sync", (model, col, opts)=>
      if (model instanceof Comment || model instanceof Challenge) && opts.forNavigation
        _.defer(->
          navigate(model, opts)
        )
    , this)
    @api.store.models.on("add sync", (model, col, options)=>
      _.defer(->
        if options?.rt
          if !model.get('level')? && !model.get('_is_new_comment')
            model.fetch({first: true, rt: true, parse: true, rt_parent: true})
      )
    )
    # auto show all parents when the rt comment is displayed
    @api.store.models.on("change:_is_realtime", (model, rt)->
      if !rt && model.get('level') > 1
        model.get('parent').unset('_is_realtime')
    )
    @api.store.getCollection(User, true).on("add change:profile", (model, col, ops)=>
      if !model.get("dummy")&& model.id && model.get("profile") && !model.get("profile").get("permissions")
        model.get("profile").fetch()
    , this)
    @api.store.getCollection(Context, true).on('add', (model)->
      _.defer(->
        if model.get('comment') && !model.get('comment').get('type')
          model.get('comment').fetch()
      )
    )
    @api.store.getCollection(Context, true).on('add', (context)=>
      context.set('minPromotePoints', context.minPromotePoints(@options.promotedLimit, @options.promoteCost))
      context.get("promoted").on("reset sort", (comments)=>
        comments.each((model, index)=>
          if index < @options.promotedLimit
            model.set("promoted_visible", true)
          else
            model.set("promoted_visible", false)
        )
      )
      context.get("promoted").on("add", (model, col)=>
        index = col.indexOf(model)
        if index < @options.promotedLimit
          model.set("promoted_visible", true)
        else
          model.set("promoted_visible", false)
      )
      context.get("promoted").on("remove", (model, col)=>
        model.set("promoted_visible", false)
      )
      context.get('promoted').on('reset sort add remove', =>
        context.set('minPromotePoints', context.minPromotePoints(@options.promotedLimit, @options.promoteCost))
      )
    , this)

    updateModeratorMode = (user)=>
      if @api.loggedIn() && user == @api.user
        if @api.user.get("profile")?.get("permissions")?.moderator
          @container.addClass('USER_IS_MODERATOR')
        else
          @container.removeClass('USER_IS_MODERATOR')
    @api.store.getCollection(User, true).on("change:profile change.profile.permissions", updateModeratorMode, this)
    if @ssoData && @api.site.get("sso")?.enabled
      @logins.sso = @ssoData.sso_options
      @api.ssoLogin(@ssoData, (err, user)=>
        if !err
          if !user
            if @options.user && @options.user.type != "sso"
              @api.userLogin(@options.user)
            else
              analytics.commentAutoLoad(@has_comment_autoload(), null)
        else if @options.user
          @api.userLogin(@options.user)
        else
          analytics.commentAutoLoad(@has_comment_autoload(), null)
      )
    else
      @api.userLogin(@options.user)
      if !options.user
        analytics.commentAutoLoad(@has_comment_autoload(), null)
    @showMainView()
    onLogin = =>
      if @api.loggedIn()
        @container.addClass('USER_LOGGED_IN')
        if @api.user.get("language")
          # user has a preferred language set in his profile, load it
          @set_language_by_id(@api.user.get("language"))
        @api.initRtCurrentUser()
      else
        @container.removeClass('USER_LOGGED_IN')
      old_url = Backbone.history.getHash()
      @render()
      if !/\bWIDGET\b/.test(@options.appType)
        # we show notifications only on main applications, not widgets
        if @api.loggedIn() && !@api.user.get("verified")
          @trigger("warn:not_verified")
        else if @api.loggedIn() && @api.user.get("type") != "sso"
          @trigger("info:edit_profile", {maxTimesUser: 2, translate_options: {url: @options.baseUrl}})
      if Backbone.History.started
        if @gotfirsturl && !@commentInProgress
          @goUrl(old_url, true)
      updateModeratorMode(@api.user)
    onLogout = =>
      @api.disposeRtCurrentUser()
      updateModeratorMode()
      @container.removeClass('USER_LOGGED_IN')
    onLoginWithAnalytics = =>
      onLogin()
      analytics.commentAutoLoad(@has_comment_autoload(), @api.user)
    @api.on("login", onLoginWithAnalytics, this)
    @api.on("logout", onLogout, this)
    @startNavigation()
    onLogin()
    if !@views.main._rendered
      @views.main.render()
    return true

  configure: (location, type, val) ->
    # location is the ID of the target, passed in quotes, without hash sign
    # type can be css or icon (in quotes)
    # val should be like "width: 500px;" / "width:500px;height:500px;" or "icon-thumbs-up"
    if location && type && val
      cssId = '#' +  location
      elem = $(cssId)
      if type == "css"
        $("head").append($("<style type='text/css'>#{cssId} { #{val} } </style>"))
      if type == "icon"
        elem.addClass(val)
    else
      return

  setUrl: (url)->
    if @gotfirsturl
      @hasPrevUrl = true
    # Keep the iframe url synchronized with the embedding site's url
    @gotfirsturl = true
    if Backbone.history.getFragment() != url
      Backbone.history.navigate('#' + url, {replace: true})
    @currentUrl = url
    @urlHistory.push(url)
    @routes.navigate(url)

  showMainView: ->
    if @options.appType == 'ARTICLE' || @options.appType == 'ARTICLE_DEMO'
      context = new Context(@options.conversation)
      context.set("site": context.get("siteName"))

      # context.get("allactivities").model = modelFactory
      @currentContext = context
      @views.main = new ContextView(model: context)
    else if @options.appType == 'FORUM'
      @views.main = new ForumView(model: @api.site)
    else if @options.appType == 'WIDGET:SUBSCRIBE'
      @views.main = new SubscriptionWidgetView(model: @api.site)
    else if @options.appType == 'WIDGET:DISCOVERY'
      @views.main = new DiscoveryWidgetView(model: @api.site)
    @container.empty().append(@views.main.el)

  startNavigation: (hash)->
    @routes = new AppRouter()
    if !Backbone.History.started
      @router = new MainRouter()
      @router.off('route', null, this)
      @router.on('route', (route, args)=>
        @trigger("change:url", Backbone.history.getHash())
      , this)
      # silent works for iframe only
      Backbone.history?.start({silent: true})

  stopNavigation: ->
    Backbone.history?.stop()

  showErrorLoading: ->
    @views.errorLoading = new View(template: require("views/templates/errorLoading"))
    @views.errorLoading.error_message = @options.message
    @container.empty().append(@views.errorLoading.render().el)
    analytics.errorLoading(@options.message)

  showLoading: ->
    @container.empty().append((new View(template: require("views/templates/loading"))).render().el)

  serverTimeCorrected: (timestamp = new Date().getTime())->
    return timestamp - @initTime + @serverTime

  localTimeCorrected: (timestamp)->
    return timestamp - @serverTime + @initTime

  startTimestampTimer: ->
    setInterval(=>
      @trigger("server_time_passes", this, @serverTimeCorrected())
    , 60 * 1000)

  defaultUrl: ->
    if @isArticle()
      return '#brzn/comments'
    else if @isForum()
      return @views.main.forumUrl()
    return ''

  goUrl: (link, replace)->
    if Backbone.history.getFragment(link || '') == Backbone.history.fragment
      Backbone.history.loadUrl(link)
    else
      Backbone.history.navigate(link, {trigger: true, replace: replace})

  goBack: ->
    if window.history?.back? && @hasPrevUrl
      old = Backbone.history.getHash()
      @trigger('history:back')
    else
      if @isForum()
        @goUrl(@views.main.forumUrl())
      else if @isArticle()
        @goUrl('#brzn/comments')
      else
        if window.history?.back?
          @trigger('history:back')
        else
          @goUrl('#')

  backToViewUrl: (view)->
    if view.from_url
      url = view.from_url
    else
      url = @defaultUrl()
    # detect if the url points to a comment and remove that part
    # we don't want the page to lose the scroll position
    idx_cmt = url.search(/comments\/[0-9a-zA-Z]+/)
    if idx_cmt >= 0
      if @isArticle()
        url = 'brzn/comments'
      else if @isForum()
        url = url.substring(0, idx_cmt - 1)
    @goUrl(url)

  render: ->
    @views.main?.render()
    if @commentInProgress
      if @commentInProgress.comment
        @goUrl(@commentUrl(@commentInProgress.context, @commentInProgress.comment))
      else if @commentInProgress.context && @isForum()
        @goUrl("#brzn/contexts/#{@commentInProgress.context}")
    @trigger("render")

  commentUrl: (context, id)->
    if @isArticle()
      return "#brzn/comments/#{id}"
    else if @isForum()
      return "#brzn/contexts/#{context}/comments/#{id}"
    return ''

  reload: ->
    window.location.reload()

  reloadParent: ->
    @trigger("reloadparent", this)

  position: (offset)->
    @parentPageOffset = offset
    @trigger('change:scroll_offset', offset)
    @visManager?.viewport(offset)

  isArticle: ->
    return @options.appType == "ARTICLE"

  isForum: ->
    return @options.appType == "FORUM"

  scrollIntoVisibleView: (elem, options)->
    new_pos = @parentPageOffset.top_offset + $(elem).offset().top - (@views.notifications?.notifications?.height() || options?.extraOffset || 0)
    @trigger("do_scroll", new_pos)

  # Expose useful methods here
  translate: localization.translate
  localization: localization

_.extend(EmbeddedApplication.prototype, Backbone.Events)

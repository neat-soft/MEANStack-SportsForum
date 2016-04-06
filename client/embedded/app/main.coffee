$(document).ready(->

  require("backbone-setup")
  require("rivets-setup")
  require("template-setup")
  require("localization")
  require("lib/shared/underscore_mixin")

  Handlebars.registerPartial('edit_comment', require('views/templates/edit_comment'))
  Handlebars.registerPartial('user_markers', require('views/templates/user_markers'))
  Handlebars.registerPartial('new_comment_cnt_area', require('views/templates/new_comment_cnt_area'))
  Handlebars.registerPartial('login_overlay', require('views/templates/login_overlay'))
  Handlebars.registerPartial('left_box', require('views/templates/left_box'))
  Handlebars.registerPartial('options_bar', require('views/templates/options_bar'))
  Handlebars.registerPartial('promote_popup', require('views/templates/promote_popup'))
  Handlebars.registerPartial('mod_menu', require('views/templates/mod_menu'))
  Handlebars.registerPartial('top_note_bar', require('views/templates/top_note_bar'))
  Handlebars.registerPartial('conversation_header', require('views/templates/conversation_header'))
  Handlebars.registerPartial('footer', require('views/templates/footer'))
  Handlebars.registerPartial('promoted_title', require('views/templates/promoted_title'))
  Handlebars.registerPartial('funded_note', require('views/templates/funded_note'))
  Handlebars.registerPartial('bet_note', require('views/templates/bet_note'))
  Handlebars.registerPartial('load_more', require('views/templates/load_more'))

  marked.setOptions({
    gfm: true,
    tables: true,
    breaks: false,
    pedantic: false,
    sanitize: true,
    smartLists: true
  })

  View = require("views/base_view")
  browserSupport_template = require('views/templates/browserSupport')
  initialized = false

  browserSupported = ->
    minBrowserVer =
      'mozilla': 3
      'webkit': 0
      'msie': 8
      'opera': 11
    for own engine, ver of minBrowserVer
      if $.browser[engine] && parseInt($.browser.version) >= ver
        return true
    return false

  if !browserSupported()
    browserSupport = new View(template: browserSupport_template, className: "browserSupport_view")
    $("body").append(browserSupport.render().el)
    return

  lastHeight = 0
  $absolute_pos = $('.CHECK-HEIGHT')

  reportHeight = (extra)->
    extra ?= 0
    height = $("body").height()

    # Workaround for absolute positioned elements
    # We'll get rid of these when/if we get rid of the iframe
    if !$absolute_pos || $absolute_pos.length == 0
      $absolute_pos = $('.CHECK-HEIGHT')
    for elem in $absolute_pos
      $elem = $(elem)
      eheight = $elem[0].offsetHeight
      if eheight
        bottom = $elem.offset().top + eheight
        if bottom > height
          height = bottom
    height += extra
    height = Math.round(height)
    if height == lastHeight
      return
    lastHeight = height
    window.crosscomm?.height(height)
    setTimeout(->
      window.app?.trigger('change:height')
    , 300)

  reportScroll = (pos)->
    if pos
      _.defer(->
        window.crosscomm?.scroll(pos)
      )

  addWidget = (html, events, visible)->
    window.crosscomm?.addWidget(html, events, visible)

  container = $("body > #conversation")
  initializeApp = (type, connectionType, appData, integrationData)->
    Api = require('lib/api')
    if connectionType == 'LOCAL'
      rtType = require('lib/rt').local
      serverType = require('lib/httprequest_local')
    else if connectionType
      rtType = require('lib/rt').remote
      serverType = require('lib/httprequest')
    server = new serverType()
    api = new Api()
    server.initialize({api: api})
    rt = new rtType()
    api.initialize({rt: rt, server: server, site: appData.site})
    type ||= "ARTICLE"
    if type in ["ARTICLE", "FORUM", "WIDGET:SUBSCRIBE", "WIDGET:DISCOVERY"]
      AppType = require("embeddedApplication")
    if type == "ARTICLE_DEMO"
      AppType = require("articleDemo")
      type = "ARTICLE"
    window.app = new AppType()
    appData.container = container
    appData.rt = rt
    appData.api = api
    appData.appType = type
    server.app = window.app
    if inFrame
      window.app.on("do_scroll", reportScroll)
      window.app.on("reloadparent", ->
        window.crosscomm.reload()
      )
      window.app.on("change:url", (hash)->
        window.crosscomm?.url(hash)
      )
      window.app.on("history:back", ->
        window.crosscomm?.historyBack()
      )
      window.app.on("report_height", ->
        reportHeight()
      )
      window.app.on("add_widget", (view, visible)->
        html = view.el.outerHTML
        eventList = []
        for spec, callback of view.events || {}
          v = spec.split(" ")
          event = v.shift()
          sel = v.join(" ")
          eventList.push([event, sel])
        addWidget(html, eventList, visible)
      )
      window.app.on("user_is_typing", (focused)->
        window.crosscomm?.userIsTyping(focused)
      )
      window.app.on("change:currentContext render", ->
        $absolute_pos = $('.CHECK-HEIGHT')
      )
    window.app.initialize(appData, integrationData)

  handleExternalEvent = (cid, event, sel)->
    fullSelector = $("[data-view-cid='#{cid}'] #{sel}")
    handler = fullSelector[event]
    if handler
      handler.apply(fullSelector)
    else
      fullSelector.trigger(event)

  isIos = ->
    return /(iPad|iPhone|iPod)/g.test(navigator.userAgent)

  setIosClass = ->
    if isIos()
      $("body").addClass("ios")
    else
      $("body").addClass("non-ios")

  #converting RGB 2 HEX
  rgb2hex = (rgb)->
    if rgb.length > 7
      rgb = rgb.match(/^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/)
      r = parseInt (rgb[1])
      g = parseInt (rgb[2])
      b = parseInt (rgb[3])
      return (r << 16) + (g << 8) + b
    else
      return parseInt(rgb.substring(1)) || 0

  # compute luminance (https://en.wikipedia.org/wiki/Luminance_%28relative%29)
  luminance = (color)->
    R = color & 0xFF
    G = (color >> 8) & 0xFF
    B = (color >> 16) & 0xFF
    return 0.2126*R + 0.7152*G + 0.0722*B

  # LIGHT or DARK
  computeTheme = (hexcolor)->
    if luminance(hexcolor) > 128
      # we have text with luminance lighter than medium, we must use a dark background
      return "dark"
    else
      return "light"

  setTheme = (theme, data)->
    fgcolor = rgb2hex(data.color.text)
    if !theme || theme == "auto"
      theme = computeTheme(fgcolor)
    $("body").addClass(theme)
    $("head").append($("<style type='text/css'>a, .user-ref, #user_notif_accent {color: #{data.color.link};} </style>"))
    $("head").append($("<style type='text/css'>
      .inherit-back-color {background-color: #{data.color.link};}
      .inherit-border-color {border-color: #{data.color.link};}
      .inherit-color {color: #{data.color.link};}
    </style>"))
    if data.color.question && data.color.question != "transparent"
      $("head").append($("<style type='text/css'>
        .autosizejs + .dropdown-menu li:hover a,
        .autosizejs + .dropdown-menu .active a{
          background: #{data.color.question} !important;
        }
      </style>"))
    if data.premium
      premium = []
      if data.premium.color?.upvote
        premium.push("
          .cfgstyle.positive_votes .icon-chevron-up {
            background-color: #{data.premium.color.upvote} !important;
          }
        ")
      if data.premium.color?.downvote
        premium.push("
          .cfgstyle.negative_votes .icon-chevron-down {
            background-color: #{data.premium.color.downvote} !important;
          }
        ")
      if data.premium.color?.link
        premium.push("
          .cfgstyle.link a {
            color: #{data.premium.color.link} !important;
          }
        ")
      if data.premium.color?.realtime
        premium.push("
          .question_view.cfgstyle.highlight-comment > .single-item-wrapper,
          .answer_view.cfgstyle.highlight-comment > .single-item-wrapper,
          .challenge_view.cfgstyle.highlight-comment > .single-item-wrapper,
          .comment_view.cfgstyle.highlight-comment > .single-item-wrapper {
            border-color: #{data.premium.color.realtime};
          }
        ")
        premium.push("
          .cfgstyle.HAS_NEW_COMMENTS {
            border-color: #{data.premium.color.realtime} !important;
          }
        ")

      if data.premium.no_branding
        premium.push("
          .footer .burnzone-powered {
            display: none !important;
          }
        ")
      if premium.length > 0
        $("head").append($("<style type='text/css'>#{premium.join("\n")}</style>"))

  urlbuffer = []

  url = (data)->
    if initialized
      window.app.setUrl(data)
    else
      if urlbuffer[urlbuffer.length - 1] != data
        urlbuffer.push(data)

  init = (data)->
    if initialized
      return
    try
      integrationData = JSON.parse(data)
    catch error
      integrationData = {}
    integrationData.color = _.extend({}, window.conversaitData.color || {}, integrationData.color)
    integrationData.baseUrl = window.conversaitData.baseUrl
    if window.conversaitData.site?.premium
      integrationData.premium = window.conversaitData.site.premium
    setTheme(window.conversaitData.theme, integrationData)
    setIosClass()
    initialized = true
    if initializeApp(window.conversaitAppType, window.conversaitConnectionType, window.conversaitData, integrationData)
      for saved_url in urlbuffer
        window.app.setUrl(saved_url)
    urlbuffer = []

  position = (data)->
    try
      data = JSON.parse(data)
    catch error
      return
    top = Math.max(0, data.windowScroll?.top - data.offset?.top)
    left = Math.max(0, data.windowScroll?.left - data.offset?.left)
    height = data.windowScroll?.height - Math.max(0, data.offset?.top - data.windowScroll?.top)
    width = data.windowScroll?.width - Math.max(0, data.offset?.left - data.windowScroll?.left)
    window.app?.position({top: top, left: left, height: height, width: width, top_offset: data.offset?.top || 0})

  heightDomObserver = ->
    debouncedHeight = _.debounce(reportHeight, 250)
    observer = new MutationObserver((mutations)->
      debouncedHeight()
    )
    observer.observe($('body')[0], {
      attributes: true
      childList: true
      subtree: true
      characterData: true
    })

  heightTimer = null
  reportHeightPeriod = ->
    reportHeight()
    clearTimeout(heightTimer)
    window.app?.trigger("manual_size")
    heightTimer = setTimeout(reportHeightPeriod, 500)

  # if typeof MutationObserver != 'undefined'
  #   heightDomObserver()
  # else
  reportHeightPeriod()

  ready = ->
    if !initialized
      window.crosscomm.requestInit()

  inFrame = (window.top != window.self)
  if inFrame
    window.crosscomm = new easyXDM.Rpc({
      onReady: ready
    },
    {
      local: {
        init: init
        position: position
        url: url
        externalEvent: handleExternalEvent
      },
      remote: {
        height: {}
        scroll: {}
        reload: {}
        requestInit: {}
        historyBack: {}
        url: {}
        addWidget: {}
        userIsTyping: {}
      }
    })
  else
    initializeApp(window.conversaitAppType, window.conversaitConnectionType, window.conversaitData, {})
)

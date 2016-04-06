#
# This code embeds the Conversait engine.
#
(($)->
  # Using the backbone router
  Bb = Backbone.noConflict()
  __ = _.noConflict()
  jquery = $.noConflict(true)

  l = window.location
  if !window.conversait_uri
    window.conversait_uri = l.protocol + "//" + l.host + l.pathname + l.search

  area = $("#conversait_area")
  hash = l.hash

  window.conversait = {
    frames: {}
  }

  if area.length > 0
    area.addClass('conversait_area')
    if !$(area).attr('data-conversait-app-type')
      $(area).attr('data-conversait-app-type', 'article')
  fid_counter = 0
  widgets_embedded = {}
  $('.conversait_area').each((index, elem)->
    if $(elem).attr('data-conversait-app-type').toUpperCase() == "FORUM"
      widgets_embedded['FORUM'] = true
  )
  $('.conversait_area').each((index, elem)->
    $(elem).append($('<a href="#" style="display:none"></a>'))
    # if elem != window.conversait.frames["frame_0"]?.element
    fid = "frame_#{fid_counter++}"
    app_type = $(elem).attr('data-conversait-app-type').toUpperCase()
    if !(app_type in ['ARTICLE', 'FORUM', 'WIDGET:SUBSCRIBE', 'WIDGET:DISCOVERY', 'ARTICLE_DEMO'])
      app_type = 'ARTICLE'
    if widgets_embedded['FORUM'] && app_type == 'ARTICLE' && !$(elem).attr('data-conversait-force')
      return
    # collect all attributes starting with bz- and send them to the
    # IFRAME as integration data
    extra_options = {}
    $.each(elem.attributes, ()->
      marker = "bz-"
      if @specified
        if @name.slice(0, marker.length) == marker
          option_name = @name.slice(marker.length)
          extra_options[option_name] = @value
    )
    window.conversait.frames["frame_#{fid_counter++}"] = {
      element: elem
      id: fid
      app_type: app_type
      inline_options: extra_options
    }
    widgets_embedded[app_type] = true
  )

  widgets_embedded = __.keys(widgets_embedded)
  win = $(window)

  getScroll = ->
    return {
      top: win.scrollTop()
      left: win.scrollLeft()
      height: win.height()
      width: win.width()
    }

  offset = (jelem)->
    return {
      offset: jelem.offset()
      windowScroll: getScroll()
    }

  lastScroll = {top: 0, left: 0, width: 0, height: 0}
  suspendNotifications = false

  updateWidgetRelative = (widget, el)->
    anchor = widget.attr("data-anchor")
    if anchor == "top"
      widget.width(el.width())
      widget.css("top", "0px")
    else
    right = widget.attr("data-align-right")
    if right
      widget.css("right", "#{parseInt(right, 10) + $(window).width() - (el.offset().left + el.width())}px")
    if widget.attr("data-is-visible") == "false" || suspendNotifications
      widget.hide()
    else
      widget.show()

    if win.scrollTop() > el.offset().top
      widget.css("position", "fixed")
    else
      if anchor == "top"
        widget.css("position", "")

  sendOffset = ->
    cscroll = getScroll()
    if Math.abs(lastScroll.top - cscroll.top) < 0.1 && Math.abs(lastScroll.left - cscroll.left) < 0.1 &&
      Math.abs(lastScroll.height - cscroll.height) < 0.1 && Math.abs(lastScroll.width - cscroll.width) < 0.1
        return
    lastScroll = cscroll
    for own fid, frame of window.conversait.frames
      el = $(frame.element)
      for widget in el.find(".outside-widget")
        widget = $(widget)
        updateWidgetRelative(widget, el)
      frame.crosscomm?.position(JSON.stringify(offset(el)))

  $(window).on("scroll", ->
    sendOffset()
  )
  $(window).on("resize", ->
    sendOffset()
    for own fid, frame of window.conversait.frames
      if (isIos())
        frame.width = $(frame.element).parent().width() + "px"
        if frame.iframe
          $(frame.iframe).css("width", frame.width)
      el = $(frame.element)
      for widget in el.find(".outside-widget")
        widget = $(widget)
        updateWidgetRelative(widget, el)
  )

  isIos = ->
    return /(iPad|iPhone|iPod)/g.test(navigator.userAgent)

  for own fid, frame of window.conversait.frames
    do (fid, frame)->
      sendInit = ->
        data = {widgets_embedded: __.toArray(widgets_embedded)}
        if window.conversait_sso
          data.sso =
            sso_auth: window.conversait_sso
            sso_options: window.conversait_sso_options || null
        data.hash = hash
        data.url = window.conversait_uri
        data.color =
          link: $(frame.element).children("a").css("color")
          text: $(frame.element).css("color")
        data.inline_options = frame.inline_options
        frame.crosscomm?.init(JSON.stringify(data))
        frame.width = $(frame.element).parent().width() + "px"

      query = [
        "u=" + encodeURIComponent(window.conversait_uri),
        "s=" + encodeURIComponent(window.conversait_sitename),
        "a=" + encodeURIComponent(frame.app_type),
        "t=" + encodeURIComponent(window.conversait_title?.substring?(0, 100) || "")
      ]
      if window.conversait_id
        query.push("id=" + encodeURIComponent(window.conversait_id))
      iframeurl = "{{{host}}}/embed?" + query.join("&") + hash
      frame.crosscomm = new easyXDM.Rpc({
          lazy: false,
          remote: iframeurl,
          container: frame.element,
          props: {style: {border: "none", overflow: "hidden", width: "100%", height: "auto"}, id: "conversait_#{fid}", scrolling: "no"},
          hash: false,
          onReady: ->
            frame.iframe = $("#conversait_#{fid}")[0]
            sendInit()
            sendOffset()
            if (isIos())
              $(frame.iframe).css("width", frame.width)
        },
        {
          local: {
            height: (data)->
              if frame.iframe
                $(frame.iframe).css("height", data + "px")
            scroll: (pos)->
              $(window).scrollTop(pos)
            reload: ->
              window.location.reload()
            requestInit: ->
              sendInit()
              sendOffset()
            url: (hash)->
              hash = "#{hash}"
              if Bb.history.getFragment(hash || '') == Bb.history.fragment
                Bb.history.loadUrl(hash)
              else
                Bb.history.navigate(hash, {trigger: true})
            historyBack: ->
              window.history.back()
            addWidget: (html, events, options)->
              elem = $(html)
              elem.addClass("outside-widget")
              cid = elem.attr("data-view-cid")
              widgetId = elem.attr("data-widget-id")
              if widgetId
                old = $("[data-widget-id=#{widgetId}]")
              else
                old = $("[data-view-cid='#{cid}']")
              if options?.visible
                elem.attr("data-is-visible", true)
                elem.show()
              else
                elem.attr("data-is-visible", false)
                elem.hide()
              if options?.right
                elem.attr("data-align-right", options.right)
              if old.length > 0
                old.replaceWith(elem)
              else
                $(frame.iframe).before(elem)
              make_handler = (event, sel) ->
                return (ev)->
                  ev.stopPropagation()
                  frame.crosscomm?.externalEvent(cid, event, sel)
              for [event, sel] in events
                target = elem.find(sel)
                target.on(event, make_handler(event, sel))
              close = elem.find(".close")
              if close.length > 0
                close.on("click", (ev)->
                  target = close.attr("data-dismiss")
                  close.closest(".#{target}").remove()
                )
              checked = elem.find("input[type='checkbox']")
              for c in checked
                c = $(c)
                c.prop("checked", c.attr("data-checked") == "true")
              elem.attr("data-anchor", options?.anchor)
              for custom in elem.find(".has-custom-width")
                c = $(custom)
                c.width(c.attr("data-width-percent"))
              for custom in elem.find(".has-custom-margin")
                c = $(custom)
                c.css("margin", c.attr("data-margin"))
              updateWidgetRelative(elem, $(frame.element))
            userIsTyping: (focused)->
              suspendNotifications = focused
          },
          remote: {
            init: {}
            position: {}
            url: {}
            externalEvent: {}
          }
        }
      )

  # This router is used just for detection of url change.
  # The current hash is then sent to all iframes.
  router = new Bb.Router({routes: {
    '*anything': ->
      for own fid, frame of window.conversait.frames
        frame.crosscomm?.url(Bb.history.getHash())
  }})
  Bb.history.start()

)($)

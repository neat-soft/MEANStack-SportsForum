View = require('views/base_view')
AttributeView = require("views/attribute_view")
UserImageView = require("views/userImage_view")
UserBadgeView = require('views/userBadge_view')
CollectionView = require('views/collection_view')
Formatter = require("lib/format_comment")
User = require("models/user")
util = require('lib/util')
analytics = require("lib/analytics")

module.exports = class CommentProto extends View

  initialize: ->
    super
    @bindTo(@model, "change:text change:ptext", =>
      @updateText()
    )
    @bindTo(@model, "change:author", @render)
    @bindTo(@model, "change:author.name", @updateBurningHelp)
    @bindTo(@model, "change:best", @updateBest)
    @bindTo(@model, "change:author.profile.permissions change:author change:author.profile", @updatePermStatus)
    @bindTo(@model, "change:author.profile.points", @updateProfilePoints)
    debouncedUpdateSignature = _.debounce(@updateSignature, 1000)
    @bindTo(@model, "change:author change:author.signature change:author.profile change:author.profile.benefits", =>
      debouncedUpdateSignature()
    )
    @bindTo(@model, "change:is_funded change:funded change:challenge.funded", @updateFunded)
    @bindTo(@model, "change:has_voted", @updateVoted)
    @bindTo(@model, "change:minPromotePoints", @updatePromotions)
    @bindTo(@model, "change:promoted_visible change:promoter change:promoter.name", @updatePromotedVisible)

  cleanup: ->
    if @options.manage_visibility
      util.replaceImg(@$text, true)
    @$text?.expandByHeight("destroy")
    @$text = null
    @$container = null
    @$time = null
    @$funded?.popover('destroy')
    @$funded = null
    @$fund?.popover('destroy')
    @$fund = null
    super

  updateFunded: ->
    if !@_rendered && !@_rendering
      return
    if @model.get('deleted')
      return
    if @model.get('is_funded')
      @$el.addClass('FUNDED')
      no_funders = @model.get('challenge')?.get('funded')?.length || @model.get('funded').length
      @$container.find('.no_funders').text(@app.translate('no_funders', {value: no_funders}))
      if no_funders > 1
        @$el.addClass('MULTIPLE_FUNDERS')
      else
        @$el.removeClass('MULTIPLE_FUNDERS')
    else
      @$el.removeClass('FUNDED')

  updatePermStatus: ->
    if !@_rendered && !@_rendering
      return
    if !@model.get || @model.get("deleted")
      return
    perm =  @model.get("author")?.get?("profile")?.get("permissions")
    if perm?.moderator
      @$el.addClass('AUTHOR_MODERATOR')
    else
      @$el.removeClass('AUTHOR_MODERATOR')
    if @model.get("author").get?("profile")?.get("trusted")
      @$el.addClass('AUTHOR_TRUSTED')
    else
      @$el.removeClass('AUTHOR_TRUSTED')

  updateBadges: ->
    if !@_rendered && !@_rendering
      return
    if !@model.get || @model.get("deleted")
      return
    badges = @model.get("author")?.get?("profile")?.get("badges")
    @$(".badges-container").append(
      @addView("badges", new CollectionView(
        collection: badges,
        classView: "badges",
        elementView: UserBadgeView,
        elementViewOptions: {tagName: "span"},
        tagName: "span")
      ).render().el
    )

  updateBest: ->
    if @model.get("best")
      @$el.addClass("BEST")
    else
      @$el.removeClass("BEST")

  events:
    "click .positive_votes": "doVoteUp"
    "click .negative_votes": "doVoteDown"
    "click .toggle_oembed": "toggle_oembed"
    "click .stripe-button.fund": "fund"
    "click a.user-ref": "clickUser"
    "click a.user-profile-link": "clickUser"

  clickUser: (e)->
    analytics.userClick()
    e.stopPropagation()

  toggle_oembed: (e)->
    @updateText(!@oembed_active)
    e.stopPropagation()
    e.preventDefault()

  doVoteUp: ->
    if @model.get("has_voted") > 0
      @model.set("has_voted", 0)
    else
      @model.set("has_voted", 1)

  doVoteDown: ->
    if @model.get("has_voted") < 0
      @model.set("has_voted", 0)
    else
      @model.set("has_voted", -1)

  updateVoted: ->
    if !@_rendered && !@_rendering
      return
    if @model.get("has_voted") > 0
      @$(".like_section:first, .like_section_mobile:first").addClass("liked_up").removeClass("liked_down")
    else if @model.get("has_voted") < 0
      @$(".like_section:first, .like_section_mobile:first").removeClass("liked_up").addClass("liked_down")
    else
      @$(".like_section:first, .like_section_mobile:first").removeClass("liked_up liked_down")

  render: ->
    @oembed_active = false
    @$container = $(@$el.children().first())
    @$time = @$container.find(".time")

    if !@model.get("deleted") || @model.get("deleted_data")
      if @model.get("author") instanceof Backbone.Model
        @$container.find(".author_name").append(@addView(new AttributeView(model: @model.get("author"), attribute: "name")).render().el)
        @$container.find(".author_image_container").append(@addView(new UserImageView(model: @model.get("author"))).render().el)
      @$text = @$container.find(".text")
      @updateText()
      @updateSignature()
      @updateBest()
      @updatePermStatus()
      @updateProfilePoints()
      @updateBadges()
      @updateVoted()
      @updatePromotions()
      @updateFunded()
      @updatePromotedVisible()
      @$("[data-toggle=tooltip]").tooltip({animation: "true"})
      @$funded = @$container.find('.funded_note')
      @$fund = @$container.find('.fund')
      @updateBurningHelp()
      @$fund.popover({
        trigger: 'hover'
        html: true
        placement: 'right'
        container: 'body'
        content: => @app.translate('help_ignite')
        delay: {
          hide: 1000
        }
      })

  updateProfilePoints: ->
    if !@_rendered && !@_rendering
      return
    if !@model.get || @model.get("deleted")
      return
    points =  @model.get("author")?.get?("profile")?.get("points") || 0
    @$('.single-item-wrapper:first .profile-points').text(points)

  updateBurningHelp: ->
    if !@_rendered && !@_rendering
      return
    @$funded.popover('destroy')
    @$funded.popover({
      trigger: 'hover'
      html: true
      placement: 'top'
      container: 'body'
      content: =>
        author_name = @model.get('author')?.get?('name')
        if author_name
          @app.translate('help_burning_comment_user', {user: author_name})
        else
          @app.translate('help_burning_comment')
      delay: {
        hide: 1000
      }
    })

  fund: (e)->
    e.preventDefault()
    e.stopPropagation()
    if !@app.api.loggedIn()
      @app.views.login.showOverlay()
      return
    @app.stripe_checkout.token_callback = (token)=>
      if @_disposed
        return
      @app.api.fundComment(@model, token.id)
    @app.stripe_checkout.open({
      name: @app.api.site.get("display_name") || 'Ignite'
      description: @app.translate('stripe_desc_fund_comment')
      amount: @app.options.fundCommentPrice
      panelLabel: @app.translate('stripe_btn_label_fund_comment')
      email: @app.api.user?.get?("email")
    })
    top = @app.parentPageOffset.top
    wheight = $('body').height()
    eloft = @$el.offset().top
    sih = wheight * 2
    sit = -wheight + eloft
    $('.stripe_checkout_app').height(sih).offset({top: sit})

  updateSignature: ()=>
    if !@_rendered && !@_rendering
      return
    if @_disposed
      return
    profile = @model.get("author").get?('profile')
    if !profile?.get?("benefits")
      return
    if profile.get("benefits").bold_name
      @$el.addClass('AUTHOR_EMPH_NAME')
    if profile.get("benefits").signature
      @$container?.find(".signature").text(@model.get('author').get('signature'))

  updatePromotedVisible: ()->
    if !@_rendered && !@_rendering
      return
    if @model.get('promoted_visible')
      promoter_name = @model.get('promoter')?.get?('name')
      if promoter_name
        title = @app.translate('promoted_title_by', {user: promoter_name})
      else
        title = @app.translate('promoted_title')
      @$container.find('.promoted_note').attr('title', title)
      @$container?.addClass("PROMOTED")
    else
      @$container?.removeClass("PROMOTED")

  updatePromotions: ()->
    if !@_rendered && !@_rendering
      return
    if @model.get("deleted")
      return
    if @model.get("challenge")
      return
    context = @model.get('context')
    if !context?.get?
      return
    @$container?.removeClass("CAN_SELF_PROMOTE")
    if @model.get("author") == @app.api.user
      if !@app.api.user.get("profile")?.get("permissions")?.moderator
        minPoints = context.get('minPromotePoints')
        if minPoints < @app.options.modPromotePoints
          @$container?.addClass("CAN_SELF_PROMOTE")

  updateText: (oembed)->
    if !@_rendered && !@_rendering
      return
    if !@app.is_mobile
      oembed = true
    if !@$text
      return
    if @options.manage_visibility
      util.replaceImg(@$text, true)
    if @model.get("ptext")
      text_str = @app.api.textToHtml(@model.get("ptext"))
      if @options.manage_visibility
        text_str = util.textReplaceImg(text_str)
      @$text.html(text_str)
    else
      @$text.text(@model.get("text"))
    # replace user mentions with views for user name
    Formatter.formatMentionsForDisplay(this, @$text)
    if oembed
      Formatter.applyOembed(@$text)
      @oembed_active = true
      @$el.children().first().find('a.toggle_oembed').text(@app.translate('hide_embedded_items'))
    else
      @$text.html(util.imgtoa(@$text.html()))
      @oembed_active = false
      @$el.children().first().find('a.toggle_oembed').text(@app.translate('show_embedded_items'))
      if @$text.find('a').length > 0
        @$el.addClass('HAS_EMBEDDED')
      else
        @$el.removeClass('HAS_EMBEDDED')
    if @model.get("challenge")
      expander = @$el.children().first()
    else
      expander = @$text
    @$text.find("a").not(".user-ref").attr("target", "_blank")
    expander.expandByHeight("destroy")
    expander.expandByHeight({
      expandText: @app.translate("read_more")
      collapseText: @app.translate("read_less")
      maxHeight: 500
    })
    @trigger('content_update')

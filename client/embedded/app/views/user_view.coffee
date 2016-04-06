template = require('views/templates/user')
View = require('views/base_view')
UserImageView = require("views/userImage_view")
AttributeView = require("views/attribute_view")
CommentView = require("views/comment_view")
CollectionView = require("views/collection_view")
SimpleCommentView = require("views/simple_comment_view")
BetsView = require("views/bets_view")

module.exports = class User extends View
  className: "user_view CHECK-HEIGHT"

  template: template

  default_stats: {
    no_comments: 0
    no_challenges: 0
    no_questions: 0
    no_bets: 0
  }

  default_trusted: {
    social_verified: []
    upvotes: 0
    downvotes: 0
    required_comments_count: 20
    required_social_count: 1
    required_ratio: 5
    required_age: 30 * 24 * 3600 * 1000
  }

  initialize: ->
    super
    # @bindTo(@model, "change", @render)
    @bindTo(@model, 'change:profile change:profile.points', @updatePoints)
    @bindTo(@model, 'change:profile change:profile.stats', @updateStats)
    @bindTo(@model, 'change:no_bets', @updateBets)
    @$el.addClass("HAS_MORE")

  renderTrusted: (stats)->
    if !stats.trusted?
      @$(".trust-stats").addClass("display_none")
      return
    @$(".trust-stats").removeClass("display_none")

    trusted = stats.trusted || @default_trusted
    if stats.no_comments >= trusted.required_comments_count
      @$(".trust-stats .comments_required").addClass("complete")
    else
      @$(".trust-stats .comments_required").addClass("incomplete")
    if trusted.social_verified?.length >= trusted.required_social_count
      @$(".trust-stats .social_verified").addClass("complete")
    else
      @$(".trust-stats .social_verified").addClass("incomplete")
    if trusted.upvotes / (trusted.downvotes || 1) >= trusted.required_ratio
      @$(".trust-stats .vote_ratio").addClass("complete")
    else
      @$(".trust-stats .vote_ratio").addClass("incomplete")
    since = @model.get("profile").get("created")
    if moment.utc().diff(since, "milliseconds") >= trusted.required_age
      @$(".trust-stats .profile_age").addClass("complete")
    else
      @$(".trust-stats .profile_age").addClass("incomplete")
    if @model.get("profile").get("permissions").moderator
      @$(".trust-stats .stats").addClass("AUTHOR_MODERATOR")
    if @model.get("profile")?.get("trusted")
      @$(".trust-stats .stats").addClass("AUTHOR_TRUSTED")

  beforeRender: ->
    @model.get("profile").fetch()
    @model.fetchBetCountByFilter({status: 'all'})

  render: ->
    @$(".author_image_container").append(@addView(new UserImageView(model: @model)).render().el)
    # if @model.get("imageType") == "facebook"
    #   @$("input#inputFbImage").prop("checked", true)
    # else
    #   @$("input#inputGravImage").prop("checked", true)
    # @$(".change_pass").html(@app.translate("change_pass", {url: @app.options.baseUrl}))
    # @$(".change_notifications").html(@app.translate("change_notifications", {url: @app.options.baseUrl}))
    @$(".change-settings").html(@app.translate("change_settings", {url: @app.options.baseUrl}))
    # @$(".points").replaceWith(@addView(new AttributeView(model: @model, attribute: "profile.points", tagName: "p", className: "points")).render().el)
    @fetchNext()
    @$(".history").replaceWith(@addView("history", new CollectionView({
      collection: @model.get("history"),
      className: "collection_view history",
      elementView: SimpleCommentView
      copy: true
      tagName: "table"
    })).render().el)
    @$(".bets_view").replaceWith(@addView("bets", new BetsView({
      model: @model,
      className: "bets_view",
    })).render().el)
    @updatePoints()
    @updateStats()
    @updateBets()

  updateBets: ->
    @$(".no_bets").html(@app.translate("no_bets", {value: @model.get("no_bets") || 0}))

  updateStats: ->
    stats = @model.get("profile").get("stats") || @default_stats
    @$(".no_comments").html(@app.translate("no_comments", {value: stats.no_comments || 0}))
    @$(".no_challenges").html(@app.translate("no_challenges", {value: stats.no_challenges || 0}))
    @$(".no_questions").html(@app.translate("no_questions", {value: stats.no_questions || 0}))
    @renderTrusted(stats)

  updatePoints: =>
    @$(".points").text(@app.translate("no_points", {value: @model.get("profile").get("points")}))

  events:
    "click .more": "fetchNextOnMore"
    "click .vote_ratio": "infoVoteRatio"
    "click .comments_required": "infoComments"
    "click .social_verified": "infoSocial"
    "click .profile_age": "infoProfileAge"
    "click .show-history": "showHistory"
    "click .show-bets": "showBets"
    "click .bets_view .btn-filter": "filterBets"

  filterBets: (e)->
    e.preventDefault()
    e.stopPropagation()
    @view('bets').filter({status: $(e.target).attr('data-filter')})

  showHistory: (e)->
    e.preventDefault()
    e.stopPropagation()
    $(e.currentTarget).tab('show')

  showBets: (e)->
    e.preventDefault()
    e.stopPropagation()
    $(e.currentTarget).tab('show')
    if !@view('bets').filter_options
      @view('bets').filter({status: 'all'})

  infoVoteRatio: ->
    trusted = @model.get("profile").get("stats")?.trusted || @default_trusted
    @$(".trust-stats .info").removeClass("hide-info").html(@app.translate("trusted_vote_ratio", {
      upvotes: trusted.upvotes
      downvotes: trusted.downvotes
      ratio: trusted.upvotes / (trusted.downvotes || 1)
      req_ratio: trusted.required_ratio
    }))

  infoComments: ->
    stats = @model.get("profile").get("stats") || @default_stats
    trusted = @model.get("profile").get("stats")?.trusted || @default_trusted
    @$(".trust-stats .info").removeClass("hide-info").html(@app.translate("trusted_comments_required", {value: stats.no_comments || 0, req_comments: trusted.required_comments_count}))

  infoSocial: ->
    trusted = @model.get("profile").get("stats")?.trusted || @default_trusted
    if trusted.social_verified?.length
      key = "trusted_social_verified"
    else
      key = "trusted_social_noverified"
    @$(".trust-stats .info").removeClass("hide-info").html(@app.translate(key, {
      sites: (trusted.social_verified || []).join(", ")
      req_count: trusted.required_social_count
    }))

  infoProfileAge: ->
    trusted = @model.get("profile").get("stats")?.trusted || @default_trusted
    since = @model.get("profile").get("created")
    @$(".trust-stats .info").removeClass("hide-info").html(@app.translate("trusted_profile_age", {
      since: moment.utc(since).format("MMM Do, YYYY")
      age: moment.utc().diff(since, "days")
      req_age: trusted.required_age / 1000.0 / 3600 / 24
    }))

  fetchNextOnMore: ->
    @fetchNext()

  fetchNext: (options)->
    options ?= {}
    _.extend(options, {
      history: true
      remove: false
      parse: true
      success: (resp)=>
        if @_disposed
          return
        if !@model.get("history").hasMore()
          @$el.removeClass("HAS_MORE")
        @$el.removeClass("LOADING_MORE LOADING")
      error: =>
        if @_disposed
          return
        @$el.removeClass("LOADING_MORE LOADING")
    })
    @model.get("history").fetchNext(options)
    if @_rendered
      @$el.addClass("LOADING_MORE")
    else
      @$el.addClass("LOADING")

  # events:
  #   "submit form": "change"

  # change: =>
  #   data =
  #     name: @$("form .changeName").val()
  #     email: @$("form .changeEmail").val().replace(/\s/g, "")
  #     imageType: @$('form input:radio[name=image]:checked').val()
  #   if data.name && data.email && data.imageType
  #     @model.save(data, {wait: true})
  #   return false

  activate: ->
    @model.fetch()
    @model.get("profile").fetch()

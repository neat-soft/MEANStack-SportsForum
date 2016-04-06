NewCommentView = require('views/newComment_view')
NewChallengeView = require('views/newChallenge_view')
CollectionView = require("views/collection_view")
AttributeView = require("views/attribute_view")
template = require('views/templates/bet')
BaseCommentView = require('views/baseComment_view')
UserInBetView = require('views/userInBet_view')
Comment = require('models/comment')
CommentView = require('views/comment_view')
util = require('lib/util')

module.exports = class Bet extends BaseCommentView
  className: "bet_view"

  initialize: ->
    @events = _.extend({}, Bet.__super__.events, @events || {})
    super
    @$el.attr("id", "comment-#{@model.id}")
    @bindTo(@model.get('bet_targeted'), 'add remove reset', @updateAcceptedStatus)
    @bindTo(@model.get('bet_joined'), 'add remove reset', @updateAcceptedStatus)
    @bindTo(@model.get('bet_accepted'), 'add remove reset', @updateAcceptedStatus)
    @bindTo(@model.get('bet_declined'), 'add remove reset', @updateAcceptedStatus)
    @bindTo(@model.get('bet_forfeited'), 'add remove reset', @updateAcceptedStatus)
    @bindTo(@model, 'change:bet_status', @updateBetStatus)
    @bindTo(@model, 'change:bet_requires_mod', @updateBetStatus)
    @bindTo(@model, 'change:bet_type', @updateBetType)
    @bindTo(@model, 'change:bet_tpts_av_tuser change:bet_tpts_av_ntusers change:bet_tpts_av change:bet_tpts_joined change:bet_pts_max_user', =>
      if !@_disposed && @_rendered && !@model.get('deleted')
        @setRangePtsAccepted()
    )
    @users_accepted = new Backbone.GraphCollection()
    @users_declined = new Backbone.GraphCollection()
    @users_pending = new Backbone.GraphCollection() # targeted but not accepted or declined
    @users_joined = new Backbone.GraphCollection()
    @users_targeted = new Backbone.GraphCollection()

    @bindTo(@model.get('bet_targeted'), 'add', (model)=>
      if @_disposed
        return
      id = "usib_#{@model.id}_#{model.id}"
      existing = @users_pending.get(id)
      if !existing
        existing = new Backbone.Model(user: model, status: 'pending', _id: id)
        @users_pending.add(existing)
      else
        existing.set(status: 'pending')
      @users_targeted.add(new Backbone.Model(user: model, _id: id))
    )
    @bindTo(@model.get('bet_accepted'), 'add', (model)=>
      if @_disposed
        return
      id = "usib_#{@model.id}_#{model.id}"
      existing = @users_accepted.get(id)
      _.defer(=>
        if !existing
          existing = new Backbone.Model(user: model, status: 'accepted', _id: id, risked_points: @model.get('bet_accepted_points')[model.id])
          @users_accepted.add(existing)
        else
          existing.set(status: 'accepted')
        @users_pending.remove(id)
      )
    )
    @bindTo(@model.get('bet_declined'), 'add', (model)=>
      if @_disposed
        return
      id = "usib_#{@model.id}_#{model.id}"
      existing = @users_declined.get(id)
      if !existing
        existing = new Backbone.Model(user: model, status: 'declined', _id: id)
        @users_declined.add(existing)
      else
        existing.set(status: 'declined')
      @users_pending.remove(id)
    )
    @bindTo(@model.get('bet_forfeited'), 'add', (model)=>
      if @_disposed
        return
      id = "usib_#{@model.id}_#{model.id}"
      @users_accepted.get(id)?.set(forfeited: true)
    )
    @bindTo(@model, 'change:bet_status', =>
      if @_disposed
        return
      if @model.get('bet_status') != 'resolved_pts'
        return
      @setWinPoints()
    )
    @users_pending.reset(_.map(
      _.difference(@model.get('bet_targeted').models, @model.get('bet_accepted').models, @model.get('bet_declined').models)
      , (u)=> new Backbone.Model(user: u, status: 'pending', _id: "usib_#{@model.id}_#{u.id}")))
    @users_accepted.reset(_.map(
      @model.get('bet_accepted').models, (u)=>
        id = "usib_#{@model.id}_#{u.id}"
        new Backbone.Model(user: u, status: 'accepted', _id: id, risked_points: @model.get('bet_accepted_points')[u.id])
    ))
    @users_declined.reset(_.map(
      @model.get('bet_declined').models
    , (u)=> new Backbone.Model(user: u, status: 'declined', _id: "usib_#{@model.id}_#{u.id}")))
    @users_joined.reset(_.map(
      @model.get('bet_joined').models
    , (u)=> new Backbone.Model(user: u, status: 'accepted', _id: "usib_#{@model.id}_#{u.id}")))
    @users_targeted.reset(_.map(
      @model.get('bet_targeted').models
    , (u)=> new Backbone.Model(user: u, _id: "usib_#{@model.id}_#{u.id}")))
    @bindTo(@model, "change:bet_status", ->
      if @_disposed
        return
      if @_rendered
        @updateEndTime(@app.serverTimeCorrected())
    )
    @bindTo(@model, "change:bet_end_date", ->
      if @_disposed
        return
      if @_rendered
        @updateEndTime(@app.serverTimeCorrected())
    )
    @bindTo(@model, "change:bet_start_forf_date", ->
      if @_disposed
        return
      if @_rendered
        @updateEndTime(@app.serverTimeCorrected())
    )
    @bindTo(@model, "change:bet_close_forf_date", ->
      if @_disposed
        return
      if @_rendered
        @updateEndTime(@app.serverTimeCorrected())
    )
    @bindTo(@app, "server_time_passes", (app, serverTime)=>
      if @_disposed
        return
      if !@_rendered
        return
      if @model.get("bet_status") == 'open' || @model.get("bet_status") == 'closed' || @model.get("bet_status") == 'forf'
        @updateEndTime(serverTime)
    )

  setWinPoints: ->
    for own user_id, points of @model.get('bet_points_resolved')
      id = "usib_#{@model.id}_#{user_id}"
      pts_risked = @model.get('bet_accepted_points')[user_id] || @model.get('bet_joined_points')[user_id]
      won_points = points - pts_risked
      if @model.get('bet_winning_side') == 'accepted'
        @users_accepted.get(id)?.set(won: true, won_points: won_points, lost_points: 0)
      else
        @users_accepted.get(id)?.set(won: false, won_points: 0, lost_points: @model.get('bet_accepted_points')[user_id])
      if @model.get('bet_winning_side') == 'joined'
        @users_joined.get(id)?.set(won: true, won_points: won_points, lost_points: 0)
      else
        @users_joined.get(id)?.set(won: false, won_points: 0, lost_points: @model.get('bet_joined_points')[user_id] - points)

  events:
    'click .single-item-wrapper .bet-accept': 'acceptBet'
    'click .single-item-wrapper .bet-decline': 'declineBet'
    'click .single-item-wrapper .bet-forfeit': 'forfeitBet'
    'click .single-item-wrapper .bet-claim': 'claimBet'
    "blur .single-item-wrapper .bet-points-accepted": "onBlurAccepted"
    "change .single-item-wrapper .bet-points-accepted": "computeWinLossAccepted"
    "click .resolve-joined": "resolveJoined"
    "click .resolve-accepted": "resolveAccepted"
    "click .resolve-tie": "resolveTie"
    "click .single-item-wrapper .bet-close": "endBet"
    "click .single-item-wrapper .bet-start-forf": "startForfBet"

  endBet: (e)->
    e.stopPropagation()
    e.preventDefault()
    @app.api.endBet(@model)

  startForfBet: (e)->
    e.stopPropagation()
    e.preventDefault()
    @app.api.startForfBet(@model)

  resolveJoined: (e)->
    e.preventDefault()
    @app.api.resolveBet(@model, 'joined')

  resolveAccepted: (e)->
    e.preventDefault()
    @app.api.resolveBet(@model, 'accepted')

  resolveTie: (e)->
    e.preventDefault()
    @app.api.resolveBet(@model, 'tie')

  acceptBet: (e)->
    points = parseInt(@$betPtsAccepted.val())
    @app.api.acceptBet(@model, {points: points})
    e.stopPropagation()

  declineBet: (e)->
    @app.api.declineBet(@model)
    e.stopPropagation()

  forfeitBet: (e)->
    @app.api.forfeitBet(@model)
    e.stopPropagation()

  claimBet: (e)->
    @app.api.claimBet(@model)
    e.stopPropagation()

  updateBetStatus: ->
    pts_av_label = @$('.bet-tpts-av-label')
    if @model.get('bet_status') == 'open'
      pts_av_label.text(@app.translate('bet_pts_available'))
    else
      pts_av_label.text(@app.translate('bet_pts_unaccepted'))
    @$el.removeClass(_.map(Comment.betStatusTypes, (s)-> "BET_STATUS_#{s.toUpperCase()}").join(' '))
    @$el.addClass("BET_STATUS_#{@model.get('bet_status').toUpperCase()}")
    @$el.removeClass('BET_WIN_SIDE_JOINED BET_WIN_SIDE_ACCEPTED BET_WIN_SIDE_TIE BET_WIN_SIDE_UNDECIDED BET_WIN_SIDE_ROLLEDBACK')
    if @model.get('bet_requires_mod')
      @$el.addClass('BET_MOD_RESOLUTION')
    else
      @$el.removeClass('BET_MOD_RESOLUTION')
    status = @model.get('bet_status')
    if status != 'resolved' && status != 'resolving_pts' && status != 'resolved_pts'
      return
    wins = @model.get('bet_winning_side')
    if @model.get('bet_accepted').length == 0
      wins = 'rolledback'
    if wins?
      @$el.addClass("BET_WIN_SIDE_#{wins.toUpperCase()}")

  updateEndTime: (time)=>
    if @model.get("deleted")
      return
    if @model.get('bet_status') == 'open'
      intime = util.intime(@model.get("bet_end_date"), time)
      if intime.term == 'now'
        term = "closes_#{intime.term}"
      else
        term = "closes_in_#{intime.term}"
      @$endstime.text(@app.translate(term, intime.options))
    else if @model.get('bet_status') == 'closed'
      intime = util.intime(@model.get("bet_start_forf_date"), time)
      if intime.term == 'now'
        time_short = @app.translate("just_now_short")
      else
        time_short = @app.translate("#{intime.term}_short", intime.options)
      @$forfstartstime.text(@app.translate("bet_closed_forf_starts", {time: time_short}))

  updateBetType: ->
    @$el.removeClass(("BET_TYPE_#{t.toUpperCase()}" for t in Comment.betTypes).join(' '))
    type = @model.get('bet_type')
    if type
      @$el.addClass("BET_TYPE_#{type.toUpperCase()}")

  updateAcceptedStatus: ->
    @targeted = false
    @accepted = false
    if @model.get('bet_targeted').contains(@app.api.user)
      @targeted = true
      @$el.addClass('USER_TARGETED_IN_BET')
    else
      @targeted = false
      @$el.removeClass('USER_TARGETED_IN_BET')
    if @model.get('bet_accepted').contains(@app.api.user)
      @accepted = true
      @$el.addClass('USER_ACCEPTED_BET')
    else
      @accepted = false
      @$el.removeClass('USER_ACCEPTED_BET')
    if @model.get('bet_declined').contains(@app.api.user)
      @declined = true
      @$el.addClass('USER_DECLINED_BET')
    else
      @declined = false
      @$el.removeClass('USER_DECLINED_BET')
    if @model.get('bet_joined').contains(@app.api.user)
      @joined = true
      @$el.addClass('USER_JOINED_BET')
    else
      @joined = false
      @$el.removeClass('USER_JOINED_BET')
    if @model.get('bet_forfeited').contains(@app.api.user)
      @$el.addClass('USER_FORFEITED_BET')
    else
      @$el.removeClass('USER_FORFEITED_BET')
    if @model.get('bet_claimed').contains(@app.api.user)
      @$el.addClass('USER_CLAIMED_BET')
    else
      @$el.removeClass('USER_CLAIMED_BET')

  onBlurAccepted: (e)->
    e.stopPropagation()
    @setRangePtsAccepted()

  setRangePtsAccepted: ()->
    max_pts_accept = if @targeted then @model.get('bet_tpts_av_tuser') else @model.get('bet_tpts_av_ntusers')
    if @model.get('bet_pts_max_user')
      max_pts_accept = Math.min(max_pts_accept, @model.get('bet_pts_max_user'))
    min_pts_user = if @targeted then @app.options.minBetPtsTargeted else @app.options.minBetPts
    if @model.get('bet_tpts_av') < 2 * min_pts_user
      min_pts_user = @model.get('bet_tpts_av')
    current_pts = parseInt(@$betPtsAccepted.val()) || 0
    new_pts = current_pts
    if new_pts < min_pts_user
      new_pts = min_pts_user
    if new_pts > max_pts_accept
      new_pts = max_pts_accept
    if new_pts != current_pts
      @$betPtsAccepted.val(new_pts).change()
    @$betMinPtsAccept.text(min_pts_user)
    @$betMaxPtsAccept.text(max_pts_accept)
    @$betPtsOffered.text(@model.get('bet_tpts_joined'))
    @$betPtsAv.text(@model.get('bet_tpts_av'))
    if max_pts_accept == 0
      @$el.children('.single-item-wrapper').find('.accepting-ctrl').hide()
    else
      # set display to empty string instead of calling none so that the other
      # css rules will be applied
      @$el.children('.single-item-wrapper').find('.accepting-ctrl').css('display', '')

  computeWinLossAccepted: (e)->
    e.stopPropagation()
    @computeWinLoss('accepted')

  computeWinLoss: ->
    rjoined = @model.get('bet_ratio_joined')
    raccepted = @model.get('bet_ratio_accepted')
    pts = parseInt(@$betPtsAccepted.val())
    if pts
      ptswin = pts * (rjoined / raccepted)
      @$betWinPtsAccept.text(ptswin)
    else
      @$betWinPtsAccept.text(0)

  beforeRender: ->
    @text_reply = @app.translate("reply")
    @text_title_reply = @app.translate("title_reply_comment")
    @text_comment_in_challenge = @app.translate("reply_in_challenge")
    super

  render: ->
    super
    if !@model.get('deleted')
      @$el.find('.bet-accepted-users').append(new CollectionView({
        collection: @users_accepted, elementView: UserInBetView, elementViewOptions: {tagName: 'span'}
      }).render().el)
      @$el.find('.bet-pending-users').append(new CollectionView({
        collection: @users_pending, elementView: UserInBetView, elementViewOptions: {tagName: 'span'}
      }).render().el)
      @$el.find('.bet-declined-users').append(new CollectionView({
        collection: @users_declined, elementView: UserInBetView, elementViewOptions: {tagName: 'span'}
      }).render().el)
      @$el.find('.bet-joined-users').append(new CollectionView({
        collection: @users_joined, elementView: UserInBetView, elementViewOptions: {tagName: 'span'}
      }).render().el)
      @$el.find('.bet-targeted-users').append(new CollectionView({
        collection: @users_targeted, elementView: UserInBetView, elementViewOptions: {tagName: 'span'}
      }).render().el)
      @$endstime = @$container.find(".ends_time")
      @$forfstartstime = @$container.find(".forf_starts_time")
      @$betPtsAccepted = @$el.children('.single-item-wrapper').find('.bet-points-accepted')
      @$betMinPtsAccept = @$el.children('.single-item-wrapper').find('.bet-min-pts-accept')
      @$betMaxPtsAccept = @$el.children('.single-item-wrapper').find('.bet-max-pts-accept')
      @$betWinPtsAccept = @$el.children('.single-item-wrapper').find('.bet-win-pts-accept')
      @$betPtsOffered = @$el.children('.single-item-wrapper').find('.bet-tpts-joined')
      @$betPtsAv = @$el.children('.single-item-wrapper').find('.bet-tpts-av')
      @updateBetStatus()
      @updateAcceptedStatus()
      @updateBetType()
      @setRangePtsAccepted()
      @computeWinLoss()
      @updateEndTime(@app.serverTimeCorrected())
      if @model.get('bet_status') == 'resolved_pts'
        @setWinPoints()
    if @options.mode == 'full'
      @$el.children(".comments_view").replaceWith(@addView("comments", new CollectionView(
        collection: @model.get("comments"),
        elementView: (options)->
          if options.model.get('type') == 'BET'
            return new Bet(options)
          return new CommentView(options)
        elementViewOptions: {manage_visibility: @options.manage_visibility},
        className: "comments_view"
      )).render().el)
      @bindTo(@view('comments'), 'render_child', (child, after)=>
        after ?= this
        @app.visManager?.add(child, after)
      )
    return @

  template: template

  cleanup: ->
    @$betPtsAccepted = null
    @$betMinPtsAccept = null
    @$betMaxPtsAccept = null
    @$betWinPtsAccept = null
    @$betPtsOffered = null
    @$betPtsAv = null
    @$endstime = null
    @$forfstartstime = null
    super

  dispose: ->
    @unbindFrom(@model.get('bet_targeted'))
    @unbindFrom(@model.get('bet_joined'))
    @unbindFrom(@model.get('bet_accepted'))
    @unbindFrom(@model.get('bet_declined'))
    @unbindFrom(@model.get('bet_forfeited'))
    destroy_collection = (col)->
      models = col.models.slice()
      col.reset()
      for model in models
        model.dispose()
    destroy_collection(@users_joined)
    destroy_collection(@users_pending)
    destroy_collection(@users_accepted)
    destroy_collection(@users_declined)
    destroy_collection(@users_targeted)
    @users_joined = null
    @users_pending = null
    @users_accepted = null
    @users_declined = null
    @users_targeted = null
    super

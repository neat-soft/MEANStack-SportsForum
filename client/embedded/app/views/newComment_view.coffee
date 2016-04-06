template = require('views/templates/newComment')
avatar = require('views/templates/userImage')
View = require('views/base_view')
UserImageView = require("views/userImage_view")
Context = require("models/context")
Formatter = require("lib/format_comment")
Profile = require("models/profile")
Comment = require("models/comment")
analytics = require('lib/analytics')

module.exports = class NewComment extends View
  className: "newComment_view"

  initialize: ->
    super
    @mode = 'comment'
    if @model instanceof Context
      @bindTo(@model, 'change:minPromotePoints', @setupSubmitOptions)

  cleanup: (dispose)->
    @$input = null
    @isQuestion = null
    @questionPointsOffered = null
    @questionNote = null
    @$('.bet-target')[0]?.selectize.destroy()
    @$betPtsOffered = null
    Formatter.stopCompletion(@$('.xtextarea'))
    super

  beforeRender: ->
    @loggedIn = @app.api.loggedIn()
    @betting_enabled = @app.api.site.get('premium')

  render: ->
    @removeBetClassNames()
    @renderControls()
    @questionPointsOffered = @$(".question_points_offered")
    @$(".promote_points_number").prop( "disabled", true)
    @focused()
    @restoreProgress()
    if @mode == 'bet' && @betting_enabled
      @renderBetControls()

  removeBetClassNames: ->
    @$el.removeClass(("BET_TYPE_#{t.toUpperCase()}" for t in Comment.betTypes).join(' '))

  renderBetControls: ->
    @date_pick_options =
      singleDatePicker: true,
      minDate: moment().add(@app.options.minBetPeriod + 2 * 60 * 1000, 'ms'),
      timePicker: true,
      timePickerIncrement: 1,
      showDropdowns: true
      buttonClasses: ['btn-embed']
      applyClass: 'btn-primary'
      cancelClass: 'btn-default'
      template: require('views/templates/daterangepicker')(this)
    @$('.bet-end-date').daterangepicker(@date_pick_options)
    @$('.bet-start-forf-date').daterangepicker(@date_pick_options)
    @$('.bet-target').selectize({
      valueField: 'id'
      labelField: 'userName'
      searchField: 'userName'
      create: false
      maxItems: 100
      plugins: ['remove_button']
      load: (query, callback)=>
        if !query.length
          return callback()
        @app.api.site.get("filtered_profiles").fetch({
          reset: true
          restart: true
          add: true
          merge: true
          remove: false
          success: (collection)=>
            callback(_.filter(collection.map((p)-> {id: p.get('user')?.id || p.get('user'), userName: p.get('userName')}), (p)-> p.id != @app.api.user.id))
          error: ->
            callback([])
          data:
            paged: true
            full: true
            moderator: false
            s: query
        })
    })
    @$betPtsOffered = @$('.bet-points-offered')
    @setBetType()
    @computeWinLoss()

  restoreProgress: ->
    in_prog = @app.commentInProgress
    if in_prog && (in_prog.comment && in_prog.comment == @model.id || (@app.isArticle() && !in_prog.comment && @model instanceof Context || @app.isForum() && !in_prog.comment && @model.id == in_prog.context))
      @$input.html(in_prog.text)
      if @options.allowQuestion
        @userOverride = in_prog.qoverride
        @isQuestion.prop("checked", !!in_prog.isQuestion)
        if in_prog.isQuestion || in_prog.qoverride
          @$el.addClass('IS_QUESTION')
        @checkQuestionState()
      # @app.commentInProgress = null
      _.defer(=>
        @trigger('want_reply')
      )

  renderControls: ->
    @$input = @$(".input_comment")
    @$(".author_image_container").append(@addView(new UserImageView(model: @app.api.user)).render().el)
    if @options.allowQuestion
      @isQuestion = @$(".is_question")
      @questionNote = @$(".question_note")
    if !@app.api.loggedIn()
      @bindTo(@app.views.login, 'open_login', @preserveComment)
    @$("[rel=tooltip]").tooltip({trigger: "hover"})
    @$("[data-toggle=popover]").popover({trigger: "focus"})
    Formatter.startCompletion(@$('.xtextarea'), @app)

  events:
    "click .submit": "submit"
    "click .cancel": "cancel"
    "keyup .input_comment": "checkQuestion"
    "keyup .xtextarea": "preserveComment"
    "click .is_question": "overrideQuestion"
    "click .promote_checkbox": "promoteChecked"
    "click .submit_options_button": "setupSubmitOptions"
    "click .login_to_comment": "showLogin"
    "focus .xtextarea": "focusSubmitControls"
    "blur .xtextarea": "blurSubmitControls"
    "click .already_signedup a": "alreadySignedUp"
    "change .want-bet": "switchMode"
    "blur .bet-points-offered": "setMinPtsOffered"
    "change .bet-points-offered": "computeWinLoss"
    "blur .bet-ratio-accepted": "computeWinLoss"
    "blur .bet-ratio-joined": "computeWinLoss"
    "item_add .bet-target": "setMinPtsOffered"
    "blur .bet-target": "setMinPtsOffered"
    "change .bet-type": "setBetType"
    "change .bet-odds": "setBetOdds"
    "apply.daterangepicker .bet-end-date": "setMinForfDate"
    "change .bet-want-forf-date": "wantForfDate"
    "click a[rel=tooltip]": "preventToolTipAct"

  preventTooltipAct: (e)->
    e.preventDefault()

  wantForfDate: (e)->
    e.stopPropagation()
    $start_forf = @$('.bet-start-forf-date')
    if $start_forf.toggle($(e.target).prop('checked')).is(':visible')
      end_date = @$('.bet-end-date').data('daterangepicker').startDate
      $start_forf.daterangepicker(_.extend({}, @date_pick_options, {minDate: end_date}))
      if $start_forf.data('daterangepicker').startDate.valueOf() < end_date.valueOf()
        $start_forf.data('daterangepicker').setStartDate(end_date)
        $start_forf.data('daterangepicker').setEndDate(end_date)
      # $start_forf.data('daterangepicker').updateView()

  setMinForfDate: (e)->
    e.stopPropagation()
    end_date = @$('.bet-end-date').data('daterangepicker').startDate
    $start_forf = @$('.bet-start-forf-date')
    start_forf_date = $start_forf.data('daterangepicker').startDate
    $start_forf.daterangepicker(_.extend({}, @date_pick_options, {minDate: end_date}))
    if start_forf_date
      # we need to set the date again for $start_forf because setOptions
      # above internally sets startDate and endDate to today
      $start_forf.data('daterangepicker').setStartDate(start_forf_date)
      $start_forf.data('daterangepicker').setEndDate(start_forf_date)
    if start_forf_date?.valueOf() < end_date.valueOf()
      $start_forf.data('daterangepicker').setStartDate(end_date)
      $start_forf.data('daterangepicker').setEndDate(end_date)

  setBetOdds: (e)->
    e.stopPropagation()
    if $(e.target).prop('checked')
      @$('.bet-ratio').css('display', 'inline-block')
    else
      @$('.bet-ratio').hide()

  setBetType: (e)->
    type = @$('.bet-type').val()
    @$el.removeClass(("BET_TYPE_#{t.toUpperCase()}" for t in Comment.betTypes).join(' '))
    @bet_type = type
    @$el.addClass("BET_TYPE_#{type.toUpperCase()}")
    @setMinPtsOffered()

  setMinPtsOffered: ()->
    if @bet_type == 'open'
      no_targeted = 0
    else
      targets = @$('.bet-target')[0].selectize.getValue().split(',')
      no_targeted = if targets.length > 0 and targets[0] != '' then @$('.bet-target')[0].selectize.getValue().split(',').length else 0
    min_pts_user = @app.options.minBetPtsTargeted
    min_pts_bet = @app.options.minBetPts
    current_pts = @$betPtsOffered.val()
    bet_explain = @$('.bet-explain')
    bet_explain.addClass('display_none')
    if current_pts < min_pts_bet
      @$betPtsOffered.val(min_pts_bet).change()
      bet_explain.html(@app.translate("bet_explain_minimum", {points: min_pts_bet}))
      bet_explain.removeClass('display_none')
    if no_targeted > 0 && current_pts / no_targeted < min_pts_user
      @$betPtsOffered.val(no_targeted * min_pts_user).change()
      bet_explain.html(@app.translate("bet_explain_targeted", {points: min_pts_user}))
      bet_explain.removeClass('display_none')

  computeWinLoss: (e)->
    e?.stopPropagation()
    pts = parseInt(@$('.bet-points-offered').val())
    if pts
      if @$('.bet-odds').prop('checked')
        rjoined = parseInt(@$('.bet-ratio-joined').val()) || 1
        raccepted = parseInt(@$('.bet-ratio-accepted').val()) || 1
      else
        rjoined = 1
        raccepted = 1
      ptswin = Math.floor(pts * (raccepted / rjoined))
      @$('.bet-points-risked').text(pts)
      @$('.bet-points-win').text(ptswin)
      @$('.bet-points-info').show()
    else
      @$('.bet-points-risked').text('')
      @$('.bet-points-win').text('')
      @$('.bet-points-info').hide()

  switchMode: (e)->
    checked = $(e.target).prop('checked')
    if checked
      @mode = 'bet'
      @text = @$input.html()
      @render()
      @$input.html(@text)
      @$('.want-bet').prop('checked', true)
      analytics.yoloClick()
    else
      @mode = 'comment'
      @text = @$input.html()
      @render()
      @$input.html(@text)
    e.stopPropagation()

  preserveComment: =>
    @app.commentInProgress = {
      text: @$input.html()
      context: @model.get("context")?.id || @model.id
      comment: if (@model.get("type") in ["COMMENT", "CHALLENGE", "QUESTION"]) then @model.id else null
      qoverride: @userOverride
      isQuestion: @options.allowQuestion && @isQuestion.prop("checked")
    }

  checkQuestion: (e)->
    if @options.allowQuestion && !@userOverride
      if /\?(\s)|\?(<br>)?$/.test($(e.target).html())
        @$el.addClass("IS_QUESTION")
        @isQuestion.prop("checked", true)
        @questionPointsOffered.val(0)
      else
        @isQuestion.prop("checked", false)
      @checkQuestionState()

  overrideQuestion: (e)->
    @userOverride = true
    @checkQuestionState()

  checkQuestionState: (e)->
    if @isQuestion.prop("checked")
      @$el.addClass("QUESTION_CHECKED")
    else
      @$el.removeClass("QUESTION_CHECKED")

  createComment: (submitOptions)->
    text = @$input.html() || ""
    options = {promote: submitOptions.promote}
    promotePoints = submitOptions.promotePoints ? 0
    @$el.addClass("LOADING")
    @$('.submit').prop('disabled', true)
    if @mode == 'bet'
      pts = parseInt(@$betPtsOffered.val())
      if @$('.bet-odds').prop('checked')
        rjoined = parseInt(@$('.bet-ratio-joined').val()) || 1
        raccepted = parseInt(@$('.bet-ratio-accepted').val()) || 1
      else
        rjoined = 1
        raccepted = 1
      end_date = @$('.bet-end-date').data('daterangepicker').startDate?.valueOf() || moment().add(1, 'days').valueOf()
      if @$('.bet-want-forf-date').prop('checked')
        start_forf_date = @$('.bet-start-forf-date').data('daterangepicker').startDate?.valueOf() || end_date
      else
        start_forf_date = end_date
      users = @$('.bet-target')[0].selectize.getValue().split(',')
      max_points_user = parseInt(@$('.bet-pts-max-user').val()) || 0
      @app.api.createBet(text, @model, {
        points: pts
        ratio_joined: rjoined
        ratio_accepted: raccepted
        end_date: end_date
        start_forf_date: start_forf_date
        users: users
        bet_type: @bet_type
        max_points_user: max_points_user
      }, (err, result)=>
        @$el.removeClass("LOADING")
        @$('.submit').prop('disabled', false)
        if !err && !@_disposed
          @clear()
          @trigger("ok", this)
          @app.commentInProgress = null
      )
    else
      question = @options.allowQuestion && @isQuestion.prop("checked")
      questionPointsOfferedNumber = if question and @questionPointsOffered.val() then @questionPointsOffered.val() else 0
      @app.api.createComment(text, null, question, questionPointsOfferedNumber, promotePoints, @model, null, options, (err, result)=>
        @$el.removeClass("LOADING")
        @$('.submit').prop('disabled', false)
        if !err && !@_disposed
          @clear()
          @trigger("ok", this)
          @app.commentInProgress = null
      )
    return false

  promoteChecked: ->
    if @$(".promote_comment .promote_checkbox").prop("checked") || @$(".promote_li .promote_checkbox").prop("checked")
      @$(".promote_comment .promote_points_number, .promote_li .promote_points_number").prop("disabled", false)
      analytics.promoteClicked()
    else
      @$(".promote_comment .promote_points_number, .promote_li .promote_points_number").prop("disabled", true)

  submit: ->
    promote = @$(".promote_comment .promote_checkbox").prop("checked") || @$(".promote_li .promote_checkbox").prop("checked")
    promotePoints = @$(".promote_comment .promote_points_number").val() || @$(".promote_li .promote_points_number").val()
    @$(".promote_comment .promote_points_number, .promote_li .promote_points_number").val("")
    @$(".promote_comment .promote_checkbox, .promote_li .promote_checkbox").prop("checked", false)
    @$(".promote_comment .promote_points_number, .promote_li .promote_points_number").prop("disabled", true)
    @createComment({promote: promote, promotePoints: promotePoints})
    if promote
      analytics.promoteSubmit()

  controlSendButton: ->
    if @app.api.loggedIn()
      @$("button.login_to_comment").hide()
      @$("button.submit").show()
    else
      @$('input').placeholder()
      @$("button.login_to_comment").show()
      @$("button.submit").hide()

  setupSubmitOptions: ->
    minimumPoints = (@model?.get('context') || @model)?.get('minPromotePoints')
    if minimumPoints < @app.options.modPromotePoints
      tr_min_points = @app.translate("promote_points_needed_newcomment", {value: minimumPoints})
      @$el.find(".promote_points_needed")
        .text(tr_min_points)
        .attr('title', tr_min_points)
      enabled = @$(".promote_comment .promote_checkbox").prop("checked") || @$(".promote_li .promote_checkbox").prop("checked")
      if !enabled
        @$el.find(".promote_points_number").val(minimumPoints)
      @$el.find(".promote_li").show()
    else
      @$el.find(".promote_li").hide()

  focused: ->
    @$el.addClass("FOCUSED")
    if !@app.api.loggedIn()
      @controlSendButton()

  showLogin: (e)->
    @app.views.login.showOverlay(e)
    e.stopPropagation()

  focusSubmitControls: (e)->
    @app.trigger("user_is_typing", true)
    @$(".submit_controls").addClass("focused")

  blurSubmitControls: (e)->
    @app.trigger("user_is_typing", false)
    @$(".submit_controls").removeClass("focused")

  focus: ->
    @$input.focus()

  clear: ->
    @$el.removeClass("FOCUSED")
    @$el.removeClass("QUESTION_CHECKED")
    @$el.removeClass("IS_QUESTION")
    @$input.html('')
    @isQuestion?.prop("checked", false)
    @$(".promote_comment .promote_checkbox, .promote_li .promote_checkbox").prop("checked", false)
    @$(".submit_bet .want-bet, .bet .want-bet").prop("checked", false)
    @$(".bet-explain").addClass('display_none')
    @$(".bet-points-info").hide()
    @mode = 'comment'
    @removeBetClassNames()
    @userOverride = false
    if !@app.api.loggedIn()
      @controlSendButton()

  cancel: ->
    if @app.commentInProgress?.comment == @model.id
      @app.commentInProgress = null
    @clear()
    @trigger("cancel", this)

  activate: ->
    @setupSubmitOptions()

  template: template

_.extend(NewComment.prototype, require('views/mixins').login)

Comment = require("models/comment")
Challenge = require("models/challenge")
Competition = require("models/competition")
Context = require("models/context")
User = require("models/user")
PollingSubscriber = require("lib/poll-subscriber")
HttpRequest = require("lib/httprequest")
sharedUtil = require("lib/shared/util")
analytics = require("lib/analytics")
UserNotification = require("models/userNotification")
util = require("lib/util")
Site = require("models/site")
Profile = require("models/profile")
UsersCollection = require("collections/users")
Formatter = require("lib/format_comment")

modelFactory = (attributes, options)->
  if options.model
    return new options.model(attributes, _.omit(options, "collection", "model"))
  if attributes.type == "CHALLENGE"
    return new Challenge(attributes, options)
  else if attributes.type in ["COMMENT", "QUESTION", "BET"]
    return new Comment(attributes, options)
  else if attributes.user && attributes.permissions
    return new Profile(attributes, options)
  else if attributes.name && attributes.image
    return new User(attributes, options)
  else if attributes.initialUrl
    return new Context(attributes, options)
  else
    return new Backbone.Model(attributes, options)

module.exports = class Api

  onModelError: (model, resp, options)=>
    if !options.manual
      return
    try
      error_obj = JSON.parse(resp.responseText)
    catch e
      error_obj = {error_access_api: true}
    @server_error(error_obj, options)

  server_error: (error_obj, options)->
    options.operation ?= "api"
    console.log(options.operation, error_obj)
    if error_obj
      if error_obj.code
        error_type = error_obj.code
      else
        error_type = _.first(_.keys(error_obj))
      @trigger("error:error_#{options.operation}_#{error_type}", {api: true})
    else
      @trigger("error:error_access_api", {api: true})

  onModelSync: (model, resp, options)=>
    if !options.manual
      return
    @server_success(model, resp, options)

  server_success: (model, resp, options)->
    options ?= {}
    status = if model.get("approved") == true then "success" else if model.get('approved') == false then "approval" else null
    switch options.operation
      when "edit_comment" || "create_bet"
        comment_type = if model.get("parent")?.get("type") == "QUESTION" then "ANSWER" else model.get("type")
        notif_type = if model.get("approved") then "success" else "warn"
        @trigger("#{notif_type}:create_#{comment_type.toLowerCase()}_#{status || 'success'}", {api: true})
      else
        if options.operation
          @trigger("success:#{options.operation}_success", {api: true})
        else
          @trigger("success:success_api", {api: true})

  onCommentAdd: (model, col, options)=>
    options ?= {}
    if !model.get('siteName') && options.relation?.model
      rel_model = @store.models.get(options.relation.model)
      if rel_model
        model.set('siteName', rel_model.get('siteName'))

  initialize: (options)->
    @rt = options.rt
    @server = options.server
    @store = Backbone.graphStore
    @store.models.model = modelFactory
    @site = new Site(options.site)
    @site.get("active_competition")?.set("siteName": @site.get("name"))
    @userLogin(new User(dummy: true))

    @store.models.on('change:_is_new_comment change:context', (model, val, options)=>
      options ?= {}
      _.defer(=>
        if options._self || @user.id == (model.get('author')?.id || model.get('author') || model.get('challenger')?.get?('author')?.id || model.get('challenger')?.get?('author') || model.get('challenger')?.author)
          return
        if model.get("_is_new_comment")
          model.get('context')?.get('newcomments').add(model)
        else if model.previous('_is_new_comment')
          model.get('context')?.get('newcomments').remove(model)
      )
    )
    @store.getCollection(Comment, true).on("add", @onCommentAdd, this)
    @store.getCollection(Challenge, true).on("add", @onCommentAdd, this)
    @store.getCollection(User, true).on("add", (user)=>
      _.defer(->
        if !user.get("name") && !user.get("dummy")
          user.fetch()
          if !user.get('profile')?.id
            user.get('profile').fetch()
      )
    , this)
    @store.models.on("error", @onModelError, this)
    @store.models.on("sync", @onModelSync, this)
    # @store.getCollection(Context, true).on("add change:siteName", (context)=>
    #   if !context.get("site")
    #     site = @store.getCollection(Site, true).find((s)-> s.name == context.get("siteName"))
    #     context.set("site": @site)
    # )

    add_remove_promoted = (model)=>
      context = model.get('context')
      if !context?.get?
        return
      if model.get("promote") and !model.get('spam')
        context.get("promoted").add(model)
      else
        context.get("promoted").remove(model)
    @store.getCollection(Comment, true).on('change:promote change:context', add_remove_promoted, this)
    @store.getCollection(User, true).on("add change:profile", (user)=>
      user.get("profile")?.set("siteName": @site.get("name"))
    , this)
    @store.getCollection(Profile, true).on("change:permissions", (profile)=>
      if profile.get("user") == @user
        @user.set({"moderator": profile.get("permissions").moderator}, {silent: !!@user.get("moderator") && !!profile.get("permissions").moderator})
    , this)
    @store.getCollection(Comment, true).on("add change:ref", (model)->
      _.defer(->
        if !model._disposed
          model.get("ref")?.set?("challengedIn": model.get("challenge"))
      )
    , this)
    @store.getCollection(Comment, true).on("change:no_flags", (model)->
      if model.get("no_flags") == 0
        model.set("flagged": false)
    , this)
    @store.getCollection(Challenge, true).on("change:no_flags", (model)->
      if model.get("no_flags") == 0
        model.set("flagged": false)
    , this)
    @store.getCollection(Challenge, true).on("change:is_funded", (model)->
      if !model.get('deleted')
        model.get('challenger').set({is_funded: model.get('is_funded')})
    , this)
    @store.getCollection(Competition, true).on("add", (comp)=>
      comp.set("siteName": @site.get("name"))
    , this)
    @store.getCollection(User, true).on("error", (model, resp)=>
      try
        resp = JSON.parse(resp.responseText)
      catch e

      if resp.exists
        @trigger("error:user_exists")
      else if resp.email_incorrect
        @trigger("error:invalid_email")
    , this)
    @on("login", @fetchUnreadNotifications, this)
    if @site.get("active_competition")
      comp = @site.get("active_competition")
      if !comp.get("end")
        comp.fetch()
      # get competition leaders
      comp.fetchLeaders()
    @site.fetchLeaders()
    if @loggedIn()
      @fetchSiteSubscription()

  onRt: (data)=>
    if data.update
      options = {
        parse: true,
        add: true,
        remove: false,
        merge: true,
        rt: true,
        current_user_id: @user.id,
        logged_in: @loggedIn()
      }
      if data._type
        switch data._type
          when "notification"
            options.model = UserNotification
          when "context"
            options.model = Context
        delete data._type
      @store.models.set(data.update, options)
    if data.destroy
      @store.models.get(data.destroy)?.trigger('destroy')
    if data.comment_reply
      m = @store.models.get(data.comment_reply.id)
      if m
        if data.comment_reply.start
          rep = m.get("replying") || 0
          m.set("replying",  rep + 1)
        else if data.comment_reply.stop
          rep = m.get("replying") || 0
          rep = Math.max(0, rep - 1)
          m.set("replying", rep)

  initRtCurrentUser: ->
    @rt.subscribe("/notifications/#{@user.id}", @onRt)

  disposeRtCurrentUser: ->
    @rt.unsubscribe("/notifications/#{@user.id}")

  initRtSite: ->
    @rt.subscribe("/content/#{@site.get("name")}-", @onRt)

  disposeRtSite: ->
    @rt.unsubscribe("/content/#{@site.get("name")}-")

  initRtContext: (context)->
    @rt.subscribe("/content/#{@site.get("name")}/contexts/#{context.id}-", @onRt)

  disposeRtContext: (context)->
    @rt.unsubscribe("/content/#{@site.get("name")}/contexts/#{context.id}-")

  publishForContext: (context, data)->
    @rt.publish("/content/#{@site.get("name")}/contexts/#{context.id}-", data)

  notifyStartReply: (model)->
    @publishForContext(model.get("context"), {comment_reply: {start: true, id: model.id}})

  notifyStopReply: (model)->
    @publishForContext(model.get("context"), {comment_reply: {stop: true, id: model.id}})

  fetchSiteSubscription: ->
    user = @user
    @server.request("/api/sites/#{@site.get("name")}/subscriptions", (err, result)=>
      if !err
        user.set(subscribeConv: result.active)
    )

  fetchContextSubscription: (context)->
    user = @user
    @server.request("/api/sites/#{@site.get("name")}/subscriptions", {context: context.id}, (err, result)=>
      if !err
        user.set(subscribeContent: result.active)
    )

  ssoLogin: (data, callback)->
    data.sso_options ?= {}
    @server.request("/api/sites/#{@site.get("name")}/loginsso", "POST", {sso: data.sso_auth}, (err, user)=>
      if !err && user
        @userLogin(user)
      callback?(err, user)
    )

  fetchCurrentUser: ->
    @server.request("/api/users/me", (err, user)=>
      if !err
        if user
          @userLogin(user)
        else
          @userLogout()
    )

  fundComment: (comment, token, value)->
    if comment.get('challenge')
      side = comment.sideInChallenge()
      comment.get('challenge').save(null, {
        wait: true
        url: comment.get('challenge').url() + '/fund'
        data: {token: token, value: value, side: side}
        processData: true
        manual: true
        operation: "fund_challenge_#{side}"
      })
    else
      comment.save(null, {
        wait: true
        url: comment.url() + "/fund"
        data: {token: token, value: value}
        processData: true
        manual: true
        operation: 'fund_comment'
      })

  createContext: (comment_text, question, forum, user, cb)->
    comment_text = @formatText(comment_text)
    attrs = {text: comment_text, forum: forum, question: !!question}
    if !@loggedIn()
      if !user
        @trigger("error:needs_login")
        _.defer(-> cb?({needs_login: true}))
        return
      if !sharedUtil.validateEmail(user.email)
        @trigger("error:invalid_email")
        _.defer(-> cb?({invalid_email: true}))
        return
      if !sharedUtil.removeWhite(user.name)
        @trigger("error:invalid_name")
        _.defer(-> cb?({invalid_name: true}))
        return
      # if !sharedUtil.removeWhite(user.pass)
      #   @trigger("error:invalid_password")
      #   _.defer(-> cb({invalid_pass: true}))
      #   return
      attrs.user = user
    if !sharedUtil.removeWhite(attrs.text)
      @trigger("error:error_create_context_invalid_text")
      _.defer(-> cb?({invalid_text: true}))
      return
    if !sharedUtil.removeWhite(attrs.forum.text)
      @trigger("error:error_create_context_invalid_text")
      _.defer(-> cb?({invalid_text: true}))
      return
    @server.request(@site.get("contexts").url(), "POST", attrs, (err, result)=>
      if err
        console.log(err)
        if result.notallowed
          @trigger("error:user_banned")
        else if result.exists
          @trigger("error:user_exists")
        else if result.email_incorrect
          @trigger("error:invalid_email")
        else if result.invalid_password
          @trigger("error:invalid_password")
        else if result.needs_moderator
          @trigger("error:needs_moderator")
        else if result.needs_premium
          @trigger("error:needs_premium")
        else if result.low_status
          @trigger("error:context_create_low_status")
        else if result.invalid_text
          @trigger("error:error_create_context_invalid_text")
        else
          @trigger("error:error_access_api")
      else
        context = @afterCreateContext(result)
        if user
          @fetchCurrentUser()
      cb?(err, context)
    )
    analytics.createContext()

  formatText: (text)->
    text = Formatter.replaceUserRefs(text)
    text = Formatter.replaceImageLinks(text)
    return text

  textToUserRefs: (text)->
    return Formatter.replaceUserRefs(text)

  textToHtml: (text, tagForMentions)->
    # remove new lines at the end of the string
    # the server already does this, but old comments were not processed
    text = text.replace(/\n+$/, '')
    # replace newlines that are NOT between paragraphs with a break
    text = text.replace(/\n/gm, "<br>")
    # format user references to HTML using anchors (unless overriden) with client side routes
    tag = tagForMentions || "a"
    return text.replace(/\B@([0-9a-f]{24})\b(;([^;]+);)?/gim, "<#{tag} class='user-ref' data-uid='$1' href='#brzn/users/$1'>$3</#{tag}>")

  editComment: (model, text, callback)->
    text = @formatText(text)
    data = if model.get("type") == "CHALLENGE" then {challenger: {text: text}} else {text: text}
    if !sharedUtil.removeWhite(text)
      @trigger("error:error_edit_comment_invalid_text")
      _.defer(-> callback?({invalid_text: true}))
      return
    success = ->
      callback?()
    error = (model, resp, options)->
      callback?(resp)
    model.save(null, {data: data, wait: true, success: success, error: error, manual: true, processData: true, operation: "edit_comment"})

  createBet: (text, parent, options, cb)->
    if _.isFunction(options)
      cb = options
      options = {}
    options ?= {}
    text = @formatText(text)
    attrs = _.extend({}, options, {text: text, parent: parent.id})
    if !@loggedIn()
      @trigger("error:needs_login")
      _.defer(-> cb?({needs_login: true}))
      return
    if !sharedUtil.removeWhite(attrs.text)
      @trigger("error:error_create_bet_invalid_text")
      _.defer(-> cb?({invalid_text: true}))
      return
    @server.request(parent.url() + '/bets', "POST", attrs, (err, result)=>
      if err
        @server_error(result, {operation: 'create_bet'})
      else
        comment = @afterCreateComment(result, false, parent)
      cb?(err, comment)
      analytics.createBet()
    )

  startForfBet: (bet, cb)->
    @server.request(bet.url() + '/start_forf_bet', "PUT", {}, (err, result)=>
      if err
        @server_error(result, {operation: 'start_forf_bet'})
      else
        bet.set(result, {parse: true})
        @server_success(bet, result, {operation: 'start_forf_bet'})
      cb?(err, bet)
    )

  endBet: (bet, cb)->
    @server.request(bet.url() + '/end_bet', "PUT", {}, (err, result)=>
      if err
        @server_error(result, {operation: 'end_bet'})
      else
        bet.set(result, {parse: true})
        @server_success(bet, result, {operation: 'end_bet'})
      cb?(err, bet)
    )

  acceptBet: (bet, options, cb)->
    attrs = {
      points: options.points
    }
    @server.request(bet.url() + '/accept_bet', 'PUT', attrs, (err, result)=>
      if err
        @server_error(result, {operation: 'accept_bet'})
        # console.log(err)
        # if result.notsupported
        #   @trigger("error:not_bet")
        # else if result.notallowed
        #   @trigger("error:user_banned")
        # else if result.nottargeted
        #   @trigger("error:user_not_targeted")
        # else if result.already_accepted
        #   @trigger("error:user_already_accepted")
        # else
        #   @trigger("error:error_access_api")
      else
        bet.set(result, {parse: true})
        @server_success(bet, result, {operation: 'accept_bet'})
        analytics.acceptBet()
      cb?(err, bet)
    )

  declineBet: (bet)->
    @server.request(bet.url() + '/decline_bet', 'PUT', {}, (err, result)=>
      if err
        @server_error(result, {operation: 'decline_bet'})
        # console.log(err)
        # if result.notallowed
        #   @trigger("error:user_banned")
        # else if result.nottargeted
        #   @trigger("error:user_not_targeted")
        # else if result.already_declined
        #   @trigger("error:user_already_declined")
        # else
        #   @trigger("error:error_access_api")
      else
        bet.set(result, {parse: true})
        @server_success(bet, result, {operation: 'decline_bet'})
        analytics.declineBet()
      cb?(err, bet)
    )

  forfeitBet: (bet, cb)->
    @server.request(bet.url() + '/forfeit_bet', 'PUT', {}, (err, result)=>
      if err
        @server_error(result, {operation: 'forfeit_bet'})
        # console.log(err)
        # if result.notallowed
        #   @trigger("error:user_banned")
        # else if result.nottargeted
        #   @trigger("error:user_not_targeted")
        # else if result.already_forfeited
        #   @trigger("error:user_already_forfeited")
        # else
        #   @trigger("error:error_access_api")
      else
        bet.set(result, {parse: true})
        @server_success(bet, result, {operation: 'forfeit_bet'})
        analytics.declineBet()
      cb?(err, bet)
    )

  claimBet: (bet, cb)->
    @server.request(bet.url() + '/claim_bet', 'PUT', {}, (err, result)=>
      if err
        @server_error(result, {operation: 'claim_bet'})
      else
        bet.set(result, {parse: true})
        @server_success(bet, result, {operation: 'claim_bet'})
      cb?(err, bet)
    )
    analytics.claimBet?()

  resolveBet: (bet, side, cb)->
    @server.request(bet.url() + '/resolve_bet', 'PUT', {side: side}, (err, result)=>
      if err
        @server_error(result, {operation: 'resolve_bet'})
        # console.log(err)
        # if result.needs_moderator
        #   @trigger('error:needs_moderator')
        # else if result.notallowed
        #   @trigger("error:user_banned")
        # else if result.conflict
        #   @trigger("error:conflict")
        # else
        #   @trigger("error:error_access_api")
      else
        bet.set(result, {parse: true})
        @server_success(bet, result, {operation: 'resolve_bet'})
        analytics.declineBet()
      cb?(err, bet)
    )

  createComment: (text, forum, question, questionPointsOffered, promotePoints, parent, user, options, cb)->
    if _.isFunction(options)
      cb = options
      options = {}
    text = @formatText(text)
    attrs = {text: text, parent: parent.id, question: question, options: options}
    if question
      attrs.questionPointsOffered = questionPointsOffered
    if options.promote
      attrs.promotePoints = promotePoints
    if !@loggedIn()
      if !user
        @trigger("error:needs_login")
        _.defer(-> cb?({needs_login: true}))
        return
      if !sharedUtil.validateEmail(user.email)
        @trigger("error:invalid_email")
        _.defer(-> cb?({invalid_email: true}))
        return
      if !sharedUtil.removeWhite(user.name)
        @trigger("error:invalid_name")
        _.defer(-> cb?({invalid_name: true}))
        return
      # if !sharedUtil.removeWhite(user.pass)
      #   @trigger("error:invalid_password")
      #   _.defer(-> cb({invalid_pass: true}))
      #   return
      attrs.user = user
    if !sharedUtil.removeWhite(attrs.text)
      @trigger("error:error_create_comment_invalid_text")
      _.defer(-> cb?({invalid_text: true}))
      return
    @server.request(parent.get("comments").url(), "POST", attrs, (err, result)=>
      if err
        console.log(err)
        if result.notallowed
          @trigger("error:user_banned")
        else if result.exists
          @trigger("error:user_exists")
        else if result.email_incorrect
          @trigger("error:invalid_email")
        else if result.invalid_password
          @trigger("error:invalid_password")
        else if result.notenoughpoints
          @trigger("error:notenoughpoints")
        else if result.below_minimum_promote_points
          @trigger("error:below_minimum_promote_points")
        else if result.invalid_points_value
          @trigger("error:invalid_points_value")
        else if result.low_status
          @trigger("error:create_low_status")
        else if result.invalid_text
          @trigger("error:error_create_comment_invalid_text")
        else
          @trigger("error:error_access_api")
      else
        comment = @afterCreateComment(result, question, parent)
        if user
          @fetchCurrentUser()
      cb?(err, comment)
    )
    if question
      analytics.createQuestion()
    else if parent.get("question")
      analytics.createAnswer()
    else if parent instanceof Comment
      analytics.createReply()
    else
      analytics.createComment()

  createChallenge: (challenged, summary, text, user, cb)->
    text = @formatText(text)
    attrs =
      summary: summary
      challenger:
        text: text
      challenged: challenged.id
    if !@loggedIn()
      if !user
        @trigger("error:needs_login")
        _.defer(-> cb?({needs_login: true}))
        return
      if !sharedUtil.validateEmail(user.email)
        @trigger("error:invalid_email")
        _.defer(-> cb?({invalid_email: true}))
        return
      if !sharedUtil.removeWhite(user.name)
        @trigger("error:invalid_name")
        _.defer(-> cb?({invalid_name: true}))
        return
      # if !sharedUtil.removeWhite(user.pass)
      #   @trigger("error:invalid_password")
      #   _.defer(-> cb({invalid_pass: true}))
      #   return
      attrs.user = user
    if !sharedUtil.removeWhite(attrs.challenger.text)
      @trigger("error:error_create_challenge_invalid_text")
      _.defer(-> cb?({invalid_text: true}))
      return
    @server.request(challenged.get("context").url() + "/challenges", "POST", attrs, (err, result)=>
      if err
        console.log(err)
        if result.notallowed
          @trigger("error:user_banned")
        else if result.notenoughpoints
          @trigger("error:create_challenge_notpoints")
        else if result.denied
          @trigger("error:create_challenge_denied")
        else if result.low_status
          @trigger("error:create_low_status")
        else if result.invalid_text
          @trigger("error:error_create_challenge_invalid_text")
        else
          @trigger("error:error_access_api")
      else
        challenge = @afterCreateChallenge(result)
      cb?(err, challenge)
    )
    analytics.createChallenge()

  voteComment: (comment, value)->
    challenge = comment.get("challenge")
    if !challenge
      return
    if challenge.get("challenged").get("author") == @user || challenge.get("challenger").get("author") == @user
      @trigger("error:vote_commentinch_user_in_challenge")
      return
    attrs =
      challenge: comment.get("challenge").id
      up: if value > 0 then true else false
      side: comment.sideInChallenge()
    @server.request(challenge.url() + "/votes", "PUT", attrs, (err, result)=>
      if err
        console.log(err)
        if result.notallowed
          @trigger("error:user_banned")
        else if result.denied
          @trigger("error:vote_commentinch_once")
        else if result.challenge_ended
          @trigger("error:vote_ch_ended")
        else if result.low_status
          @trigger("error:vote_low_status")
        else
          @trigger("error:error_access_api")
      else
        challenge.set(result, {parse: true, merge: true})
    )
    if value > 0
      analytics.voteUp()
    else
      analytics.voteDown()

  likeComment: (comment, value)->
    if @user == comment.get("author")
      @trigger("error:like_own_comment")
      return
    attrs =
      comment: comment.id
      up: if value > 0 then true else false
    @server.request(comment.url() + "/likes", "PUT", attrs, (err, result)=>
      if err
        console.log(err)
        if result.notallowed
          @trigger("error:user_banned")
        else if result.denied
          @trigger("error:like_comment_once")
        else if result.conflict
          @trigger("error:like_comment_retry")
        else if result.not_verified
          @trigger("error:like_comment_not_verified")
        else if result.needs_login
          @trigger("error:like_comment_needs_login")
        else if result.active_competition
          @trigger("error:like_active_competition")
        else if result.low_status
          @trigger("error:like_low_status")
        else
          @trigger("error:error_access_api")
      else
        comment.set(result, {parse: true})
    )
    if value > 0
      analytics.likeUp()
    else
      analytics.likeDown()

  shareComment: (comment, social, attrs, options)->
    if options?.popup
      windowOptions = 'scrollbars=yes,resizable=yes,toolbar=no,location=yes'
      width = options?.width || 640
      height = options?.height || 700
      left = options?.left || 0
      top = options?.top || 0
      windowOptions += ',width=' + width + ',height=' + height + ',left=' + left + ',top=' + top
      popup = window.open(comment.url() + "/share/" + social + (if attrs.type then "?type=#{attrs.type}" else ""),
        "Conversait_share_popup", windowOptions)
      @once("rpc:#{social}:error", (msg)=>
        @trigger("error:error_share_#{social}", {translate_options: {error: msg}})
      )
      @once("rpc:#{social}:success", (msg)=>
        @trigger("info:info_share_#{social}", {translate_options: {text: msg}})
      )
      return popup
    else
      @server.request(comment.url() + "/share/" + social, "POST", attrs, (err, result)=>
        if err
          console.log(err)
        if result.error
          @trigger("error:error_share_#{social}", {translate_options: {error: result.error}})
        else if err
          @trigger("error:error_share_#{social}", {translate_options: {error: err.message || "Unknown error"}})
        else if result.text
          @trigger("info:info_share_#{social}", {translate_options: {text: result.text}})
      )

  flag: (item)->
    if !@loggedIn()
      @trigger("error:needs_login")
      return
    attrs = {}
    @server.request(item.url() + "/flag", "PUT", attrs, (err, result)=>
      if err
        console.log(err)
        if result.notallowed
          @trigger("error:user_banned")
        else if result.not_verified
          @trigger("error:not_verified")
        else if result.low_status
          @trigger("error:flag_low_status")
        else
          @trigger("error:error_access_api")
      else
        item.set(_.extend({}, result, {flagged: true}))
    )

  deleteComment: (comment, params)->
    params ?= {}
    @server.request(comment.url() + "/delete", "PUT", params, (err, result)=>
      if err
        if result.needs_moderator
          @trigger("error:needs_moderator")
          @initModerator(false)
        else
          @trigger("error:error_access_api")
      else
        comment.set(result)
    )

  promoteComment: (comment)->
    @server.request(comment.url() + "/promote", "PUT", (err, result)=>
      if err
        if result.needs_moderator
          @trigger("error:needs_moderator")
          @initModerator(false)
        else if result.already_promoted
          @trigger("error:already_promoted")
        else
          @trigger("error:error_access_api")
      else
        comment.set(result)
    )
    analytics.promoteSubmit()

  selfPromoteComment: (comment, points)->
    @server.request(comment.url() + "/selfpromote", "POST", {points: points}, (err, result)=>
      if err
        if result.notenoughpoints
          @trigger("error:notenoughpoints")
        else if result.below_minimum_promote_points
          @trigger("error:below_minimum_promote_points")
        else if result.invalid_points_value
          @trigger("error:invalid_points_value")
        else
          @trigger("error:error_access_api")
      else
        comment.set(result)
    )
    analytics.promoteSubmit()

  demoteComment: (comment)->
    @server.request(comment.url() + "/demote", "PUT", (err, result)=>
      if err
        if result.needs_moderator
          @trigger("error:needs_moderator")
          @initModerator(false)
        else if result.already_promoted
          @trigger("error:already_promoted")
        else
          @trigger("error:error_access_api")
      else
        comment.set(result)
    )
    analytics.promoteDemote()

  notifySubscribeResult: (err, result)->
    if err
      if result?.email_incorrect
        @trigger("error:invalid_email")
      else
        @trigger("error:error_access_api")
    else
      if result.active
        @trigger("success:subscribe_success")
      else
        @trigger("success:unsubscribe_success")

  subscribeConversation: (email, subscribe)->
    if !@loggedIn()
      if !sharedUtil.validateEmail(email)
        @trigger("error:invalid_email")
        return
    @server.request("/api/sites/#{@site.get("name")}/subscriptions", "POST", {email: email, active: subscribe}, (err, result)=>
      if !err
        @user.set("subscribeConv": result.active)
      @notifySubscribeResult(err, result)
    )

  subscribeContent: (email, subscribe, context)->
    if !@loggedIn()
      if !sharedUtil.validateEmail(email)
        @trigger("error:invalid_email")
        return
    @server.request("/api/sites/#{@site.get("name")}/subscriptions", "POST", {email: email, active: subscribe, context: context.id}, (err, result)=>
      if !err
        @user.set("subscribeContent": result.active)
      @notifySubscribeResult(err, result)
    )

  fetchUnreadNotifications: (user)->
    user.fetchUnreadNotificationCount()
    user.fetchNewNotificationCount()

  modSubscription: ->
    @server.request("/api/sites/#{@site.get('name')}/modsubscription", (err, result)=>
      if !err
        @user.set(subscribe_comments: result.active)
    )

  modSubscribe: (subscribe, cb)->
    if subscribe
      @server.request("/api/sites/#{@site.get('name')}/modsubscription", "POST", (err, result)=>
        if err
          return cb?(err)
        @user.set("subscribe_comments": true)
        cb?()
      )
    else
      @server.request("/api/sites/#{@site.get('name')}/modsubscription", "DELETE", (err, result)=>
        if err
          return cb?(err)
        @user.set("subscribe_comments": false)
        cb?()
      )

  approveItem: (item, cb)=>
    item.approve()

  destroyItem: (item, params, cb)=>
    if typeof(options) == 'function'
      cb = options
      params = {}
    options = {data: params, processData: true}
    item.destroy(_.extend({}, options, {wait: true}))

  setSpam: (item, cb)=>
    item.setSpam()

  notSpam: (item, cb)=>
    item.notSpam()

  deleteItem: (item, params, cb)=>
    if typeof(options) == 'function'
      cb = options
      params = {}
    options = {data: params, processData: true}
    item.delete(options)

  clearItemFlags: (item, cb)=>
    item.clearFlags()

  saveProfile: (profile, attrs, cb)->
    profile.save(attrs, {wait: true})

  clearPoints: (cb)=>
    @server.request("/api/sites/#{@site.get('name')}/resetpoints", "POST", {}, cb)

  fetchSubscrCount: ->
    @site.fetchSubscrCount()

  fetchSubscrCountV: ->
    @site.fetchSubscrCountV()

  fetchSubscrCountVA: ->
    @site.fetchSubscrCountVA()

  afterCreateComment: (result, question, parent)->
    if result.approved
      @store.models.add(result, {_self: true, merge: true, parse: true})
      comment = @store.models.get(result._id)
      if comment.get("author") == @user || !@loggedIn()
        if comment.get("type") == "QUESTION"
          @trigger("success:create_question_success")
        else if comment.get("cat") == "QUESTION" && parent.get("question")
          @trigger("success:create_answer_success")
        else
          @trigger("success:create_comment_success")
    else
      if question
        @trigger("warn:create_question_approval")
      else if parent.get("type") == "QUESTION"
        @trigger("warn:create_answer_approval")
      else
        @trigger("warn:create_comment_approval")
    return comment || result

  afterCreateContext: (result)->
    if result.approved
      @store.models.add(result, {_self: true, merge: true, parse: true})
      context = @store.models.get(result._id)
      @trigger("success:create_context_success")
    else
      @trigger("warn:create_context_approval")
    return context || result

  afterCreateChallenge: (result)->
    if result.approved
      @store.models.add(result, {_self: true, merge: true, parse: true})
      challenge = @store.models.get(result._id)
      @trigger("success:create_challenge_success")
    else
      @trigger("warn:create_challenge_approval")
    return challenge || result

  createUser: (attrs, cb)->
    if !sharedUtil.validateEmail(attrs.email)
      @trigger("error:invalid_email")
      return _.defer(-> cb?({invalid_email: true}))
    if !sharedUtil.removeWhite(attrs.name)
      @trigger("error:invalid_name")
      return _.defer(-> cb?({invalid_name: true}))
    @server.request("/api/users", "POST", attrs, (err, result)=>
      if err
        if result.exists
          @trigger("error:user_exists")
        else if result.email_incorrect
          @trigger("error:invalid_email")
        else if result.invalid_password
          @trigger("error:invalid_password")
        else
          @trigger("error:error_access_api")
      else
        @userLogin(result)
      cb?(err)
    )

  mergeUser: (withUserDesc)->
    @server.post(@user.url() + "/merge", withUserDesc.attributes, (err, result)=>
      if !err
        withUserDesc.set({merged: true})
    )

  get_site_stats: (from, to, cb)->
    @server.get("/api/sites/#{@site.get('name')}/analytics", {start: from, end: to}, (err, result)->
      cb?(err, result)
    )

  userLogin: (attrs)->
    if !attrs
      return false
    if @user == attrs
      return false
    if attrs instanceof Backbone.Model
      new_user = attrs
    else
      new_user = @store.models.get(attrs._id)
      if new_user
        new_user.set(attrs)
      else
        new_user = new User(attrs)
    @user?.current = false
    @user = new_user
    @user.current = true
    # Fetch the profile first and then trigger the login event so that all
    # user information is ready.
    success = =>
      if new_user == @user
        @trigger('login', @user)
        @fetchSiteSubscription()
    if @loggedIn()
      if @user.get('profile').id
        success()
      else
        if @user.get('profile').sync_status != 'fetching'
          @user.get('profile').fetch({success: success})
        else
          @user.get('profile').once('sync', success, this)
    return true

  userLogout: ->
    if !@loggedIn()
      return
    user = @user
    @user = @store.getCollection(User, true).find((e)-> e.get("dummy")) || new User(dummy: true)
    if !user.get("dummy")
      @trigger("logout", user)

  loggedIn: ->
    return !@user.get("dummy")

_.extend(Api.prototype, Backbone.Events)

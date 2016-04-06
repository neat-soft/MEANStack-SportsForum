# Adobe Site Catalyst analytics - client

module.exports = exports = analytics =

  enabled: true

  defaults: ->
    if typeof s_account == 'undefined'
      @enabled = false
    data = if @enabled then s_gi(s_account) else {contextData: {}}
    data.contextData.context = app.currentContext?.id
    data.contextData.user_id = app.user?.id || ""
    data.contextData.user_type = app.user?.get("type") || ""
    data.contextData.no_comments = app.currentContext?.get("no_comments")
    data.contextData.no_questions = app.currentContext?.get("no_questions")
    data.contextData.no_challenges = app.currentContext?.get("no_challenges")
    data.contextData.content_type = ""
    data.contextData.interaction = ""
    data.contextData.site_name = app.api.site.get("name")
    data.contextData.conversation_uri = app.currentContext?.get("uri")
    data.contextData.conversation_initial_url = app.currentContext?.get("initialUrl")
    data.linkTrackVars = [
      "contextData.interaction"
      "contextData.no_comments"
      "contextData.no_questions"
      "contextData.no_challenges"
      "contextData.user_id"
      "contextData.content_type"
      "contextData.user_type"
      "contextData.site_name"
      "contextData.conversation_uri"
      "contextData.conversation_initial_url"
      "contextData.context"
      "contextData.error_type"
    ].join(",")
    return data

  send: (s)->
    if @enabled
      s.tl(true, 'o', s.pageName)

  section: (name)->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = name
    analytics.send(s)

  errorLoading: (reason)->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "error-loading"
    s.contextData.error_type = reason
    analytics.send(s)

  toContexts: ->
    analytics.section("forum")

  toContext: (id)->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "forum-context-#{id}"
    analytics.send(s)

  toComments: ->
    analytics.section("comments")

  createContent: (type)->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "submit content"
    s.contextData.content_type = type
    analytics.send(s)

  createContext: ->
    analytics.createContent("forum")

  createComment: ->
    analytics.createContent("comment")

  createBet: ->
    analytics.createContent("bet")

  acceptBet: ->
    #TODO

  declineBet: ->
    #TODO

  createReply: ->
    analytics.createContent("reply")

  createQuestion: ->
    analytics.createContent("question")

  createAnswer: ->
    analytics.createContent("answer")

  createChallenge: ->
    analytics.createContent("challenge")

  chooseLogin: (type)->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "choose login " + type
    analytics.send(s)

  chooseLoginFacebook: ->
    analytics.chooseLogin("facebook")

  chooseLoginBurnzone: ->
    analytics.chooseLogin("burnzone")

  clickChallenge: ->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "click challenge"
    analytics.send(s)

  clickReply: ->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "click reply"
    analytics.send(s)

  shareContent: (type, service)->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "click share " + service
    s.contextData.content_type = type
    analytics.send(s)

  shareCommentFb: ->
    analytics.shareContent("comment", "facebook")

  shareQuestionFb: ->
    analytics.shareContent("question", "facebook")

  shareAnswerFb: ->
    analytics.shareContent("answer", "facebook")

  shareChallengeFb: ->
    analytics.shareContent("challenge", "facebook")

  shareConversationFb: ->
    analytics.shareContent("conversation", "facebook")

  shareCommentTw: ->
    analytics.shareContent("comment", "twitter")

  shareQuestionTw: ->
    analytics.shareContent("question", "twitter")

  shareAnswerTw: ->
    analytics.shareContent("answer", "twitter")

  shareChallengeTw: ->
    analytics.shareContent("challenge", "twitter")

  shareConversationTw: ->
    analytics.shareContent("conversation", "twitter")

  voteUp: ->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "vote up"
    analytics.send(s)

  voteDown: ->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "vote down"
    analytics.send(s)

  likeUp: ->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "like up"
    analytics.send(s)

  likeDown: ->
    s = analytics.defaults()
    s.contextData.interaction = s.pageName = "like down"
    analytics.send(s)

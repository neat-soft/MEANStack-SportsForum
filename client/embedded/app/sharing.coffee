util = require("lib/util")
analytics = require("lib/analytics")

shareLink = (comment)->
  return "#{window.app.integration.baseUrl}/go/#{comment.id}"

reduce4twComment = (comment, urlLength = 35)->
  return _.string.prune(comment.get("text"), 80) + " - " + _.string.prune(comment.get("author").get("name"), 20) + " "

reduce4twQuestion = (comment, urlLength = 35)->
  return _.string.prune(comment.get("text"), 80) + " - asked " + _.string.prune(comment.get("author").get("name"), 20) + " "

reduce4twAnswer = (comment, urlLength = 35)->
  return _.string.prune(comment.get("text"), 80) + " - responded " + _.string.prune(comment.get("author").get("name"), 20) + " "

reduce4twChallenge = (challenge, urlLength = 35)->
  challenger = challenge.get("challenger")
  return _.string.prune(challenger.get("text"), 70) + " - challenged " + _.string.prune(challenger.get("author").get("name"), 20) + " "

reduce4twContext = (context, urlLength = 35)->
  return _.string.prune(context.get("text") || "Conversation at ", 40) + _.string.prune(shareLink(context), 80)

module.exports.tweetComment = (comment, api)->
  analytics.shareCommentTw()
  return tweet(comment, "comment", api)

module.exports.tweetQuestion = (comment, api)->
  analytics.shareQuestionTw()
  return tweet(comment, "question", api)

module.exports.tweetAnswer = (comment, api)->
  analytics.shareAnswerTw()
  return tweet(comment, "answer", api)

module.exports.tweetChallenge = (challenge, api)->
  analytics.shareChallengeTw()
  return tweet(challenge, "challenge", api)

module.exports.tweetConversation = (context, api)->
  analytics.shareConversationTw()
  return tweet(context, null, api)

module.exports.tweet = tweet = (comment, type, api)->
  width = 640
  height = 700
  [top, left] = util.centerPosition(width, height)
  return api.shareComment(comment, "tw", {type: type}, {popup: true, top: top, left: left, width: width, height: height})

module.exports.fbshareConversation = (context, appId, api)->
  analytics.shareConversationFb()
  return fbshare(appId, shareLink(context), context.get("text") || "Burnzone Conversation", shareLink(context), api, context, true)

module.exports.fbshareComment = (comment, appId, api)->
  author = _.string.prune(comment.get("author").get("name"), 30)
  analytics.shareCommentFb()
  return fbshare(appId, shareLink(comment), "Burnzone Comment", "Comment by " + author, api, comment)

module.exports.fbshareQuestion = (comment, appId, api)->
  author = _.string.prune(comment.get("author").get("name"), 30)
  text = _.string.prune(comment.get("text"), 100)
  analytics.shareQuestionFb()
  return fbshare(appId, shareLink(comment), "Burnzone Question", "Asked by " + author, api, comment)

module.exports.fbshareAnswer = (comment, appId, api)->
  author = _.string.prune(comment.get("author").get("name"), 30)
  text = _.string.prune(comment.get("text"), 100)
  analytics.shareAnswerFb()
  return fbshare(appId, shareLink(comment), "Burnzone Answer", "Answered by " + author, api, comment)

module.exports.fbshareChallenge = (challenge, appId, api)->
  comment = challenge.get("challenger")
  author = _.string.prune(comment.get("author").get("name"), 30)
  text = _.string.prune(comment.get("text"), 100)
  analytics.shareChallengeFb()
  return fbshare(appId, shareLink(challenge), "Burnzone Challenge", "Challenged by " + author, api, challenge)

module.exports.fbshare = fbshare = (appId, url, name, caption, api, comment)->
  auth = FB.getAuthResponse()
  FB.login((res)->
    api.shareComment(comment, "fb", {
      user: res.authResponse.userID,
      token: res.authResponse.accessToken,
      app_id: appId,
      link: url,
      name: name,
      caption: caption
    })
  , {
    scope: "publish_actions,user_friends,public_profile"
    auth_type: "rerequest"
  })
  return

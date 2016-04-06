module.exports.userCommentView = (options)->
  if options.model.get("type") == "QUESTION"
    QuestionView = require("views/question_view")
    return new QuestionView(options)
  else if options.model.get("type") == "CHALLENGE"
    ChallengeView = require("views/challenge_view")
    return new ChallengeView(options)
  else if options.model.get("type") == "BET"
    BetView = require("views/bet_view")
    return new BetView(options)
  else if options.model.get("cat") == "QUESTION" && options.model.get("level") == 2
    AnswerView = require("views/answer_view")
    return new AnswerView(options)
  else
    CommentView = require("views/comment_view")
    return new CommentView(options)

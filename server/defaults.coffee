config = require("naboo").config

# values in config.appLogic take priority

module.exports = _.extend({
    forumCategoryDepth: 2
    forumRatingComment: 2
    forumRatingLike: 1
    forumRatingVote: 1
    maxCommentLength: 20000
    maxForumTitleLength: 100
    maxChallengeSummaryLength: 150
    maxConvTags: 3
    initialPoints: 0
    convInitialPoints: 0
    compInitialPoints: 0
    likePoints: 1
    likePointsAnswer: 1
    votePoints: 1
    flagsForApproval: 3
    maxFlags: 1000
    challengeWinnerPoints: 10
    challengeLoserPoints: -5
    freeChallenges: 1
    voterInChallenge: 0
    moderatorDeletesChallenge: -20
    moderatorDeletesComment: -20
    moderatorDeletesQuestion: -20
    commentInOwnChallengePoints: 1
    questionPoints: 0
    answerPointsAsker: 0
    bestAnswerPoints: 5
    commentPointsAuthor: 0
    sharePoints: 3
    maxSharesPerConversation: 2
    notificationsPerPage: 10
    commentsPerPage: 20
    profilesPerPage: 20
    topForumUsers: 3
    challengeTime: 72 * 3600 * 1000 # time in millis
    questionTime: 72 * 3600 * 1000 # time in millis
    editCommentPeriod: 10 * 60 * 1000 # time in millis
    tagDescriptionLength: 200
    challengeCost: -5
    promoteCost: -5
    modPromotePoints: 1000000
    promotedLimit: 3
    trustedTime: 30 * 24 * 60 * 60 * 1000 # time in millis
    trustedLikeRatio: 5
    trustedLikePoints: 2
    trustedLikePointsAnswer: 2
    trustedCommentCount: 10
    # goldBadgePrice: 700
    fundCommentPrice: 399 # price in cents
    extraVotePoints: 1
    extraLikes: 1
    expirationDays:
      funderBadge: 30
      funderBenefits: 30
      fundedBadge: 0
      fundedBenefits: 30
    fundedUserPoints: 50
    betForfPeriod: 2 * 24 * 3600 * 1000 # time in millis
    notifForfBet: 1 * 24 * 3600 * 1000 # time in millis
    minBetPts: 25
    minBetPtsTargeted: 25
    minBetPeriod: 1 * 60 * 1000 # time in millis
    minForfeiters: 3
    premiumTrialDays: 30
  }, config.appLogic || {})

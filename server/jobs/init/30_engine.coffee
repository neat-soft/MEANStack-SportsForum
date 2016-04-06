jobs = require("../jobs/jobs")
EndChallenges = require("../jobs/endChallenges")
EndQuestions = require("../jobs/endQuestions")
LikeStatus = require("../jobs/likeStatus")
Rollups = require("../jobs/rollups")
NotifyEndChallenges = require("../jobs/notifyEndChallenges")
NotifyCompetitions = require("../jobs/notifyCompetitions")
ConvActivity = require("../jobs/convActivity")
TrustedBadge = require("../jobs/trustedBadge")
Badges = require("../jobs/badges")
SendMarketingEmail = require("../jobs/sendMarketingEmail")
debug = require("debug")("worker")
CronJob = require("cron").CronJob
JobEngine = require("../jobs/jobsEngine")
emailJob = require("../jobs/email")
EndBets = require('../jobs/endBets')
NotifyBetUnresolved = require('../jobs/notifyBetUnresolved')
BetRemindForfeit = require('../jobs/betRemindForfeit')
StartForfBets = require('../jobs/startForfBets')
logger = require("../../logging").logger
PremiumUpdate = require("../jobs/premiumUpdate")

module.exports = (callback)->
  stopHandler = {}
  challenges = new EndChallenges({config: this, ctlHandle: stopHandler})
  questions = new EndQuestions({config: this, ctlHandle: stopHandler})
  likeStatus = new LikeStatus({config: this, ctlHandle: stopHandler})
  rollups = new Rollups({config: this, ctlHandle: stopHandler})
  notifyEndChallenges = new NotifyEndChallenges({config: this, ctlHandle: stopHandler})
  notifyCompetitions = new NotifyCompetitions({config: this, ctlHandle: stopHandler})
  convActivity = new ConvActivity({config: this, ctlHandle: stopHandler})
  trustedBadge = new TrustedBadge({config: this, ctlHandle: stopHandler})
  badges = new Badges({config: this, ctlHandle: stopHandler})
  endBets = new EndBets({config: this})
  notifyBetUnresolved = new NotifyBetUnresolved({config: this})
  betRemindForfeit = new BetRemindForfeit({config: this})
  startForfBets = new StartForfBets({config: this})
  sendMarketingEmail = new SendMarketingEmail({config: this, ctlHandle: stopHandler})
  premiumUpdate = new PremiumUpdate({config: this, ctlHandle: stopHandler})

  engine = new JobEngine({ctlHandle: stopHandler, maxJobs: 30})
  engine.subscribers["EMAIL"] = emailJob(
    transport: @email.transport
    delay: @emails_ps
    contact: @email.contact
    notifications: @email.notifications
    serverHost: @serverHost
  )
  engine.subscribers["MERGE_USERS"] = jobs.mergeUsers
  engine.subscribers["MERGE_SITES"] = jobs.mergeSites
  engine.subscribers["ACTIVITY"] = jobs.activity
  engine.subscribers["MARK_CONV_ACTIVITY"] = jobs.markConversationActivity
  engine.subscribers["NEW_CONVERSATION"] = jobs.newConversation
  engine.subscribers["NEW_PENDING_CONVERSATION"] = jobs.newPendingConversation
  engine.subscribers["END_QUESTION"] = jobs.endQuestion
  engine.subscribers["NEW_COMMENT"] = jobs.newComment
  engine.subscribers["NEW_PENDING_COMMENT"] = jobs.newPendingComment
  engine.subscribers["NOTIFY_PROMOTED_COMMENT"] = jobs.notifyPromotedComment
  engine.subscribers["NEW_CHALLENGE"] = jobs.newChallenge
  engine.subscribers["NEW_PENDING_CHALLENGE"] = jobs.newPendingChallenge
  engine.subscribers["END_CHALLENGE"] = jobs.endChallenge
  engine.subscribers["VOTE"] = jobs.vote
  engine.subscribers["LIKE_COMMENT"] = jobs.likeComment
  engine.subscribers["LIKE_COMMENT_UPDOWN"] = jobs.likeCommentUpDown
  engine.subscribers["LIKE_STATUS"] = jobs.likeStatus
  engine.subscribers["NOTIFY_END_CHALLENGE"] = jobs.notifyEndChallenge
  engine.subscribers["ROLLUP_PAGE_VIEWS"] = jobs.roll_up_page_views
  engine.subscribers["ROLLUP_COMMENTS"] = jobs.roll_up_comments
  engine.subscribers["ROLLUP_CONVERSATIONS"] = jobs.roll_up_conversations
  engine.subscribers["ROLLUP_PROFILES"] = jobs.roll_up_profiles
  engine.subscribers["ROLLUP_VERIFIED"] = jobs.roll_up_verified
  engine.subscribers["ROLLUP_SUBSCRIPTIONS"] = jobs.roll_up_subscriptions
  engine.subscribers["ROLLUP_NOTIFICATIONS"] = jobs.roll_up_notifications
  engine.subscribers["NOTIFY_START_COMPETITION"] = jobs.notifyStartCompetition
  engine.subscribers["NOTIFY_END_COMPETITION"] = jobs.notifyEndCompetition
  engine.subscribers["UPDATE_USER_PROFILES"] = jobs.updateUserProfiles
  engine.subscribers["CHECK_SHARED_ITEM"] = jobs.checkSharedItem
  engine.subscribers["SEND_MARKETING_EMAIL"] = jobs.sendMarketingEmail
  engine.subscribers["UPDATE_TRUSTED_BADGE"] = jobs.updateTrustedBadge
  engine.subscribers["UPDATE_BADGES"] = jobs.update_badges_all
  engine.subscribers["FUND_COMMENT"] = jobs.fundComment
  engine.subscribers["END_BETS"] = jobs.endBets
  engine.subscribers["START_FORF_BETS"] = jobs.startForfBets
  engine.subscribers["NOTIFY_BET_RESOLVED"] = jobs.betResolved
  engine.subscribers["BET_ACCEPTED"] = jobs.betAccepted
  engine.subscribers["BET_DECLINED"] = jobs.betDeclined
  engine.subscribers["BET_FORFEITED"] = jobs.betForfeited
  engine.subscribers["BET_CLAIMED"] = jobs.betClaimed
  engine.subscribers["NOTIFY_BET_CLOSED"] = jobs.betClosed
  engine.subscribers["NOTIFY_BET_FORF_STARTED"] = jobs.betForfStarted
  engine.subscribers["NOTIFY_BET_FORF_CLOSED"] = jobs.betForfClosed
  engine.subscribers["NOTIFY_BET_UNRESOLVED"] = jobs.betUnresolved
  engine.subscribers["BET_REMIND_FORFEIT"] = jobs.betRemindForfeit
  engine.subscribers["UPDATE_PREMIUM_SUBSCRIPTION"] = jobs.update_premium_subscription

  engine.on('stop', ->
    process.exit()
  )

  engine.on('error', (err)->
    logger.error(err)
  )

  process.on("SIGTERM", ->
    debug("SIGTERM, should stop")
    engine.stop()
    setTimeout(->
      process.exit(0)
    , 60000)
  )

  try
    new CronJob(@schedule_jobs, engine.run, null, true)
    new CronJob(@schedule_end_challenges, challenges.run, null, true)
    new CronJob(@schedule_end_questions, questions.run, null, true)
    new CronJob(@schedule_like_status, likeStatus.run, null, true)
    # new CronJob(@schedule_rollups, rollups.run, null, true)
    new CronJob(@schedule_notify_end_challenges, notifyEndChallenges.run, null, true)
    new CronJob(@schedule_notify_competitions, notifyCompetitions.run, null, true)
    new CronJob(@schedule_conv_activity, convActivity.run, null, true)
    new CronJob(@schedule_trusted_badge, trustedBadge.run, null, true)
    new CronJob(@schedule_badges, badges.run, null, true)
    new CronJob(@schedule_end_bets, endBets.run, null, true)
    new CronJob(@schedule_notif_bet_unresolved, notifyBetUnresolved.run, null, true)
    new CronJob(@schedule_notif_remind_forfeit, betRemindForfeit.run, null, true)
    new CronJob(@schedule_start_forf_bets, startForfBets.run, null, true)
    new CronJob(@schedule_premium_update, premiumUpdate.run, null, true)
    # new CronJob(@schedule_send_marketing_email, sendMarketingEmail.run, null, true)

    process.nextTick(callback)
  catch e
    process.nextTick(-> callback(e))

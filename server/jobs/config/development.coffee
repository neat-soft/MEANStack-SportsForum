module.exports = ()->
  @schedule_jobs = "*/10 * * * * *"
  @schedule_rollups = "0 0 * * * *"
  @schedule_end_challenges = "0 * * * * *"
  @schedule_end_questions = "0 * * * * *"
  @schedule_end_bets = "0 * * * * *"
  @schedule_end_forf_bets = "*/10 * * * * *"
  @schedule_start_forf_bets = "*/10 * * * * *"
  @schedule_notif_remind_forfeit = "*/10 * * * * *"
  @schedule_notif_bet_unresolved = "*/10 * * * * *"
  @schedule_notify_end_challenges = "0 * * * * *"
  @challenge_notif_end_before = 5 * 60 * 1000 # time in millis
  @schedule_like_status = "*/10 * * * * *"
  @schedule_notify_competitions = "*/10 * * * * *"
  @schedule_conv_activity = "0 * * * * *"
  @schedule_trusted_badge = "0 * * * * *"
  @schedule_badges = "0 * * * * *"
  @schedule_send_marketing_email = "0 * * * * *"
  @schedule_premium_update = "0 * * * * *"
  @serverHost = "http://127.0.0.1.xip.io:8080"
  @serverHostNoHTTP = "127.0.0.1.xip.io:8080"
  @resourcePath = "www.theburn-zone.com/web"
  this["db.app"] = {uri: "mongodb://localhost:27017/conversait/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.cassandra"] = {hosts: ["localhost:9042"], keyspace: "burnzone", username: "", password: ""}
  @redis = {port: 6379, host: "localhost"}
  # port for the dummy server
  @port = 8083
  @emailSubjectKey = 'g7t5iey7rwhglkjdahgdwkuyg%01!hr^'
  @email =
    transport:
      type: "SMTP"
      options:
        host: "smtp.mandrillapp.com"
        port: 587
        auth:
          user: process.env.SMTP_USER || "info@theburn-zone.com"
          pass: process.env.SMTP_PASS || "2iA-wSecJEX5asIA9jrR1w"
    contact:
      to: ["info@theburn-zone.com", "mihnea@nagemus.com"]
    notifications:
      from: "BurnZone <notifications@noreply.127.0.0.1.xip.io>"
      fromAddress: "notifications@noreply.theburn-zone.com"
      replyToHost: "reply.theburn-zone.com"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>"
      welcomeEmailCC: []

  @appLogic =
    challengeTime: 10 * 60 * 1000 # 10 minutes
    questionTime: 10 * 60 * 1000
    editCommentPeriod: 365 * 24 * 60 * 60 * 1000 # time in millis
    betForfPeriod: 10 * 60 * 1000 # time in millis
    notifForfBet: 5 * 60 * 1000 # time in millis
    minBetPts: 25
    minBetPtsTargeted: 25
    minBetPeriod: 10 * 60 * 1000 # time in millis

  @log =
    console: {asJSON: false}
  @replyHost = 'http://127.0.0.1.xip.io:8080'
  @stripe = {
    secret: "sk_test_cbnVy4PJc7jNMIwjVAEKUBlP"
    public: "pk_test_LFr9QWsiP0OhmVJFpG6k9Fep"
  }

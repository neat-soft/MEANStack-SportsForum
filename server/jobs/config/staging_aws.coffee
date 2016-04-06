module.exports = ()->
  host = "conversait.com"
  @schedule_jobs = "*/30 * * * * *"
  @schedule_rollups = "* */30 * * *"
  @schedule_end_challenges = "0 0 * * * *"
  @schedule_end_questions = "0 0 * * * *"
  @schedule_end_bets = "0 * * * * *"
  @schedule_end_forf_bets = "0 * * * * *"
  @schedule_start_forf_bets = "0 * * * * *"
  @schedule_notif_remind_forfeit = "0 * * * * *"
  @schedule_notif_bet_unresolved = "0 * * * * *"
  @schedule_notify_end_challenges = "0 0 * * * *"
  @challenge_notif_end_before = 12 * 3600 * 1000 # time in millis
  @schedule_notify_competitions = "0 * * * * *"
  @schedule_like_status = "0 0 0 * * *"
  @schedule_conv_activity = "0 * * * * *"
  @schedule_trusted_badge = "0 0 * * * *"
  @schedule_badges = "0 */5 * * * *"
  @schedule_send_marketing_email = "0 0 12 * * 1,3,5" # every monday/wednesday/friday at noon
  @schedule_premium_update = "0 */5 * * * *"
  @serverHost = "http://#{host}"
  @serverHostNoHTTP = host
  @resourcePath = "http://#{host}/web"
  this["db.app"] = {uri: process.env.DB_APP || "mongodb://burnzone:burnzone@c504.candidate.17.mongolayer.com:10504/burnzonestagingel?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.cassandra"] = {hosts: [process.env.DB_CASSANDRA || "174.129.36.168:9042"], keyspace: "burnzone_staging", username: "", password: ""}
  @redis = {port: process.env.REDIS_PORT || 6379, host: process.env.REDIS_HOST || "ip-10-139-52-47.ec2.internal", password: process.env.REDIS_PASS || "qWtuFk5uHlO+1q$wni"}
  # port for the dummy server
  @port = process.env.PORT || 80
  @email =
    transport:
      type: "SMTP"
      options:
        host: "smtp.mandrillapp.com"
        port: 587
        auth:
          user: process.env.SMTP_USER || "info@theburn-zone.com"
          pass: process.env.SMTP_PASS || "BMWCaIL19DfYs4QrMOxJqQ"
    contact:
      to: ["info@theburn-zone.com", "mihnea@nagemus.com", "burnzone@msb.avengis.com"]
    notifications:
      from: "BurnZone <notifications@#{host}>"
      fromAddress: "notifications@noreply.#{host}"
      replyToHost: "reply.#{host}"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>"
      welcomeEmailCC: ["patrick@theburn-zone.com"]
  @emailSubjectKey = 'g7t5iey7rwhglkjdahgdwkuyg%01!hr^'
  @stripe = {
    secret: "sk_test_cbnVy4PJc7jNMIwjVAEKUBlP"
    public: "pk_test_LFr9QWsiP0OhmVJFpG6k9Fep"
  }
  @appLogic =
    challengeTime: 10 * 60 * 1000 # 10 minutes
    questionTime: 10 * 60 * 1000
    editCommentPeriod: 365 * 24 * 60 * 60 * 1000 # time in millis
    betForfPeriod: 60 * 60 * 1000 # time in millis
    notifForfBet: 30 * 60 * 1000 # time in millis
    minBetPts: 25
    minBetPtsTargeted: 25
    minBetPeriod: 5 * 60 * 1000 # time in millis

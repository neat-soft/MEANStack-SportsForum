module.exports = ()->
  @schedule_jobs = "*/30 * * * * *"
  @schedule_rollups = "0 0 1 * * *"
  @schedule_end_challenges = "0 0 * * * *"
  @schedule_end_questions = "0 0 * * * *"
  @schedule_end_bets = "0 0 * * * *"
  @schedule_end_forf_bets = "0 0 * * * *"
  @schedule_start_forf_bets = "0 0 * * * *"
  @schedule_notif_remind_forfeit = "0 0 * * * *"
  @schedule_notif_bet_unresolved = "0 0 * * * *"
  @schedule_notify_end_challenges = "0 0 * * * *"
  @challenge_notif_end_before = 12 * 3600 * 1000 # time in millis
  @schedule_notify_competitions = "0 0 * * * *"
  @schedule_like_status = "0 0 0 * * *"
  @schedule_conv_activity = "0 0 * * * *"
  @schedule_trusted_badge = "0 0 0 * * *"
  @schedule_badges = "0 0 0 * * *"
  @schedule_send_marketing_email = "0 0 12 * * 1,3,5" # every monday/wednesday/friday at noon
  @schedule_premium_update = "0 0 0 * * *"
  @serverHost = "http://www.theburn-zone.com"
  @serverHostNoHTTP = "www.theburn-zone.com"
  @resourcePath = "http://www.theburn-zone.com/web"
  this["db.app"] = {uri: process.env.DB_APP || "mongodb://burnzonestrong:Vxn1Ztv2VXegE@candidate.20.mongolayer.com:10469/burnzoneprodel/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.cassandra"] = {hosts: [process.env.DB_CASSANDRA || "174.129.36.168:9042"], keyspace: "burnzone", username: "", password: ""}
  @redis = {port: process.env.REDIS_PORT || 6379, host: process.env.REDIS_HOST || "ec2-184-73-13-39.compute-1.amazonaws.com", password: process.env.REDIS_PASS || "qWtuFk5uHlO+1q$wni"}
  # port for the dummy server
  @port = process.env.PORT || 80
  @emailSubjectKey = 'hs730gRFjs8Ju(&^34kj345#$wd!sagG'
  @email =
    transport:
      type: "SMTP"
      options:
        host: "smtp.mandrillapp.com"
        port: 587
        auth:
          user: process.env.SMTP_USER || "info@theburn-zone.com"
          pass: process.env.SMTP_PASS || "BBKtSVGF9CZab_3WPXUWWQ"
    contact:
      to: ["info@theburn-zone.com", "mihnea@nagemus.com"]
    notifications:
      from: "BurnZone <notifications@theburn-zone.com>"
      fromAddress: "notifications@noreply.theburn-zone.com"
      replyToHost: "reply.theburn-zone.com"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>"
      welcomeEmailCC: ["patrick@theburn-zone.com"]

  @replyHost = 'http://www.theburn-zone.com'
  @stripe = {
    secret: "sk_live_CRehoj4VBN6YyYso7H1GlTE7"
    public: "pk_live_EYy0Lj9ptiWQ1RgV9G0KQTu5"
  }

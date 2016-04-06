module.exports = ()->
  host = "conversait.com"
  @schedule_jobs = "*/30 * * * * *"
  @schedule_rollups = "*/30 * * * * *"
  @schedule_end_challenges = "0 0 * * * *"
  @schedule_end_questions = "0 0 * * * *"
  @schedule_notify_end_challenges = "0 0 * * * *"
  @challenge_notif_end_before = 12 * 3600 * 1000 # time in millis
  @schedule_notify_competitions = "0 0 * * * *"
  @schedule_like_status = "0 0 0 * * *"
  @schedule_trusted_badge = "0 0 0 * * *"
  @schedule_badges = "0 */5 * * * *"
  @schedule_send_marketing_email = "0 0 12 * * 1,3,5" # every monday/wednesday/friday at noon
  @serverHost = "http://#{host}"
  @serverHostNoHTTP = host
  @resourcePath = "http://#{host}/web"
  this["db.app"] = {uri: process.env.DB_APP || "mongodb://burnzone:burnzone@chang.mongohq.com:10091/app13007343/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.cassandra"] = {hosts: ["127.0.0.1:9160"], keyspace: "burnzone", user: "", password: ""}
  @redis = {port: process.env.REDIS_PORT || 15325, host: process.env.REDIS_HOST || "pub-redis-15325.us-east-1-2.2.ec2.garantiadata.com", password: process.env.REDIS_PASS || "w8DUq2y2i5muuULC"}
  # port for the dummy server
  @port = process.env.PORT || 80
  @emailSubjectKey = 'g7t5iey7rwhglkjdahgdwkuyg%01!hr^'
  @email =
    transport:
      type: "SMTP"
      options:
        host: "email-smtp.us-east-1.amazonaws.com"
        port: 587
        auth:
          user: process.env.AWS_SES_USER || "AKIAJJ6U2CBGYDR7OSIQ"
          pass: process.env.AWS_SES_PASS || "Avg8KmUI/+4YxVWRP53sia+uGvxB3sBWmxhzeZeVD3g7"
    contact:
      to: ["info@theburn-zone.com", "mihnea@nagemus.com"]
    notifications:
      from: "BurnZone <notifications@#{host}>"
      fromAddress: "notifications@noreply.#{host}"
      replyToHost: "reply.#{host}"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>" 
      welcomeEmailCC: ["patrick@theburn-zone.com"]
  @stripe = {
    secret: "sk_test_cbnVy4PJc7jNMIwjVAEKUBlP"
    public: "pk_test_LFr9QWsiP0OhmVJFpG6k9Fep"
  }

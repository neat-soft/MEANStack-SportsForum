module.exports = ()->
  express = require("express")
  host = "conversait.com"
  @port = 80
  @sessionAge = 2592000000
  @sessionCookieDomain = ".#{host}"
  @serverHost = "http://#{host}"
  @loginRoot = "http://#{host}/auth"
  @resourcePath = "http://#{host}/web"
  @fbClientID = "217725921685376"
  @fbClientSecret = "cee303276c39a67046d5e67080929b7e"
  @twKey = "ZPJUCDOZ9qYnnZ1Y23E8Kg"
  @twSecret = "7GTj1SFohLEz7mYg00FV1JlCN1uP8bp9q5BI4D4"
  @googleKey = "146608272129-1qnfufe0luup2vmevaafcjkrmtg5ilfd.apps.googleusercontent.com"
  @googleSecret = "Om9OWIWwQbbxzVJezQrBPe-Y"
  @disqusKey = "bEE9Ohr6l3THL4NYYTKllboKagDvrMR4w68ecWwrKkh1rhzd1rLXIyJl79pW6HA7"
  @disqusSecret = "WCDoJfVQM0rxITXPeebkXZ6RdylJd2jzBPwXXr462fBPJxL8DHAKy661DZsmKWy3"
  @domain = "#{host}"
  @domainAndPort = "#{host}"
  # Do not set this to the same value as staticPath because it's not supposed to be public
  @cachePath = "../cache"
  @recaptcha_public = "6Lf7VPUSAAAAADwQnsqWTWp0YV3xtqb2vsFun6Th"
  @recaptcha_private = "6Lf7VPUSAAAAAHvvpFgasbUNTzdYNPNhXacb665l"
  @verify_captcha = false
  @redis = {port: process.env.REDIS_PORT || 6379, host: process.env.REDIS_HOST || "ip-10-139-52-47.ec2.internal", password: process.env.REDIS_PASS || "qWtuFk5uHlO+1q$wni"}

  this["db.session"] = {uri: "mongodb://burnzone:burnzone@c504.candidate.17.mongolayer.com:10504/burnzonestagingel?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.log"] = {uri: process.env.DB_LOG || "mongodb://burnzone:burnzone@chang.mongohq.com:10091/app13007343/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.app"] = {uri: "mongodb://burnzone:burnzone@c504.candidate.17.mongolayer.com:10504/burnzonestagingel?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}

  this["aws.auth"] = {accessKeyId: "AKIAJ45MLFTVXDLKH6DQ", secretAccessKey: "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"}
  this["aws.bucket"] = "burnzone_test"
  this["aws.keypref_plugins"] = "plugins/"

  @stripe = {
    secret: "sk_test_cbnVy4PJc7jNMIwjVAEKUBlP"
    public: "pk_test_LFr9QWsiP0OhmVJFpG6k9Fep"
    public_test: "pk_test_LFr9QWsiP0OhmVJFpG6k9Fep"
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

  @app.use(express.compress())
  @app.enable('view cache')
  @checkSpam = false
  @logRequests = true

  @email =
    notifications:
      from: "BurnZone <notifications@#{host}>"
      fromAddress: "notifications@noreply.#{host}"
      replyToHost: "reply.#{host}"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>"
      welcomeEmailCC: ["patrick@theburn-zone.com"]
  @replyHost = "http://#{host}"
  @mandrill_webhook_keys = {
    reply: 'KmNa8P9hxF_bAVuQQWtvqg'
    moderate: '3wfd7g0g9E55QYINBl4vzA'
  }
  @emailSubjectKey = 'g7t5iey7rwhglkjdahgdwkuyg%01!hr^'

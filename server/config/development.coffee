module.exports = ()->
  express = require("express")
  host = "127.0.0.1.xip.io"
  @port = 8080
  @sessionAge = 2592000000
  @sessionCookieDomain = ".#{host}"
  @serverHost = "http://#{host}:#{@port}"
  @loginRoot = "http://#{host}:#{@port}/auth"
  @resourcePath = "http://#{host}:#{@port}/web"
  @fbClientID = "552276278121454"
  @fbClientSecret = "1e73b891173a07548319d2638d52cb22"
  @domain = "#{host}"
  @domainAndPort = "#{host}:#{@port}"
  # @twKey = "pe6qnPIvIcHOnxEcazvFg"
  # @twSecret = "nLTG4lKoreX1rJdshWTAxZEW3RoM2Z8Y44KEMmzpkcY"
  @twKey = "BvB5yrDSA4VWHcZ2pktw"
  @twSecret = "AgAM3pTqsJ25018vbNxAmRvuOjsMMgHn4hGG5t4oWc0"
  @googleKey = "146608272129.apps.googleusercontent.com"
  @googleSecret = "2CwaBLjB3QT2eGV4kvX4XGXR"
  @disqusKey = "bEE9Ohr6l3THL4NYYTKllboKagDvrMR4w68ecWwrKkh1rhzd1rLXIyJl79pW6HA7"
  @disqusSecret = "WCDoJfVQM0rxITXPeebkXZ6RdylJd2jzBPwXXr462fBPJxL8DHAKy661DZsmKWy3"
  # Do not set this to the same value as staticPath because it's not supposed to be public
  @cachePath = "../cache"
  @recaptcha_public = "6LcvT90SAAAAAJLFdn9lfwv-9eSzKWSOUvWIUZTI"
  @recaptcha_private = "6LcvT90SAAAAAJdNGEIdGXW0RrxNhe_U92tDoWSv"
  @verify_captcha = false
  @redis = {port: 6379, host: "localhost"}
  @akismet_api_key = '1f36458aa647'
  @mandrill_webhook_keys = {
    reply: '-PL_PM3PFLaJfDz4nRrPcQ'
    moderate: '2TQ0jobaVMl7VCIoai4ujQ'
  }
  @replyHost = "http://#{host}:#{@port}"
  @emailSubjectKey = 'g7t5iey7rwhglkjdahgdwkuyg%01!hr^'

  this["db.session"] = {uri: "mongodb://localhost:27017/conversait/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.log"] = {uri: "mongodb://localhost:27017/logs/?auto_reconnect=true&w=0", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.app"] = {uri: "mongodb://localhost:27017/conversait/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}

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
    betForfPeriod: 10 * 60 * 1000 # time in millis
    notifForfBet: 5 * 60 * 1000 # time in millis
    minBetPts: 25
    minBetPtsTargeted: 25
    minBetPeriod: 2 * 60 * 1000 # time in millis

  @app.use(express.compress())
  # @app.enable('view cache')
  @logRequests = false
  @checkSpam = false
  @email =
    notifications:
      from: "BurnZone <notifications@noreply.#{host}:#{@port}>"
      fromAddress: "notifications@noreply.theburn-zone.com"
      replyToHost: "reply.theburn-zone.com"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>"
      welcomeEmailCC: []

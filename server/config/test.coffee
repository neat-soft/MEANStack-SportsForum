module.exports = ()->

  @port = 8090
  @sessionAge = 2592000000
  @sessionCookieDomain = ".ignorelist.com"
  @serverHost = "http://msdh.ignorelist.com:8090"
  @loginRoot = "http://msdh.ignorelist.com:8090/auth"
  @fbClientID = "552276278121454"
  @fbClientSecret = "1e73b891173a07548319d2638d52cb22"
  @domain = "msdh.ignorelist.com"
  @domainAndPort = "msdh.ignorelist.com:8090"
  @twKey = "pe6qnPIvIcHOnxEcazvFg"
  @twSecret = "nLTG4lKoreX1rJdshWTAxZEW3RoM2Z8Y44KEMmzpkcY"
  @googleKey = "146608272129.apps.googleusercontent.com"
  @googleSecret = "2CwaBLjB3QT2eGV4kvX4XGXR"
  @disqusKey = "bEE9Ohr6l3THL4NYYTKllboKagDvrMR4w68ecWwrKkh1rhzd1rLXIyJl79pW6HA7"
  @disqusSecret = "WCDoJfVQM0rxITXPeebkXZ6RdylJd2jzBPwXXr462fBPJxL8DHAKy661DZsmKWy3"
  # Do not set this to the same value as staticPath because it's not supposed to be public
  @cachePath = "../cache"
  @recaptcha_public = "6LcvT90SAAAAAJLFdn9lfwv-9eSzKWSOUvWIUZTI"
  @recaptcha_private = "6LcvT90SAAAAAJdNGEIdGXW0RrxNhe_U92tDoWSv"
  @redis = {port: 6379, host: "localhost"}
  @akismet_api_key = '1f36458aa647'

  this["db.session"] = {uri: "mongodb://localhost:27018/conversait_test/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.log"] = {uri: "mongodb://localhost:27018/conversait_test/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.app"] = {uri: "mongodb://localhost:27018/conversait_test/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}

  this["aws.auth"] = {accessKeyId: "AKIAJ45MLFTVXDLKH6DQ", secretAccessKey: "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"}
  this["aws.bucket"] = "burnzone_test"
  this["aws.keypref_plugins"] = "plugins/"
  @checkSpam = false
  @emailSubjectKey = 'g7t5iey7rwhglkjdahgdwkuyg%01!hr^'

  @stripe = {
    secret: "sk_test_cbnVy4PJc7jNMIwjVAEKUBlP"
    public: "pk_test_LFr9QWsiP0OhmVJFpG6k9Fep"
  }

  @email =
    notifications:
      from: "BurnZone <notifications@noreply.msdh.ignorelist.com>"
      fromAddress: "notifications@noreply.theburn-zone.com"
      replyToHost: "reply.theburn-zone.com"
  @replyHost = 'http://msdh.ignorelist.com:8080'

  @appLogic =
    minBetPeriod: 1000
    betForfPeriod: 1000

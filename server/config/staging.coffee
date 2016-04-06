module.exports = ()->
  host = "conversait.com"
  express = require("express")
  @port = process.env.PORT || 80
  @sessionAge = 2592000000
  @sessionCookieDomain = ".#{host}"
  @serverHost = "http://#{host}"
  @loginRoot = "http://#{host}/auth"
  @resourcePath = "http://#{host}/web"
  @fbClientID = process.env.FB_CLIENT || "217725921685376"
  @fbClientSecret = process.env.FB_SECRET || "cee303276c39a67046d5e67080929b7e"
  @twKey = process.env.TW_KEY || "ZPJUCDOZ9qYnnZ1Y23E8Kg"
  @twSecret = process.env.TW_SECRET || "7GTj1SFohLEz7mYg00FV1JlCN1uP8bp9q5BI4D4"
  @googleKey = process.env.GL_KEY || "146608272129-1qnfufe0luup2vmevaafcjkrmtg5ilfd.apps.googleusercontent.com"
  @googleSecret = process.env.GL_SECRET || "Om9OWIWwQbbxzVJezQrBPe-Y"
  @domain = "#{host}"
  @domainAndPort = "#{host}"
  # Do not set this to the same value as staticPath because it's not supposed to be public
  @cachePath = "../cache"
  @recaptcha_public = process.env.RECAPTCHA_PUBLIC || "6Lft_90SAAAAAJ8VfdDz_0IU3ldas3F2od19aKQc"
  @recaptcha_private = process.env.RECAPTCHA_PRIVATE || "6Lft_90SAAAAAEEbBQJ8g7K8PSLii8InM22T4vU6"
  @redis = {port: process.env.REDIS_PORT || 15325, host: process.env.REDIS_HOST || "pub-redis-15325.us-east-1-2.2.ec2.garantiadata.com", password: process.env.REDIS_PASS || "w8DUq2y2i5muuULC"}
  @emailSubjectKey = 'g7t5iey7rwhglkjdahgdwkuyg%01!hr^'

  this["db.session"] = {uri: process.env.DB_SESSION || "mongodb://burnzone:burnzone@chang.mongohq.com:10091/app13007343/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.log"] = {uri: process.env.DB_LOG || "mongodb://burnzone:burnzone@chang.mongohq.com:10091/app13007343/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.app"] = {uri: process.env.DB_APP || "mongodb://burnzone:burnzone@chang.mongohq.com:10091/app13007343/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}

  this["aws.auth"] = {accessKeyId: process.env.AWS_KEY || "AKIAJ45MLFTVXDLKH6DQ", secretAccessKey: process.env.AWS_SECRET || "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"}
  this["aws.bucket"] = "burnzone_test"
  this["aws.keypref_plugins"] = "plugins/"

  @appLogic =
    challengeTime: 5 * 60 * 1000 # 5 minutes
    questionTime: 5 * 60 * 1000

  @app.use(express.compress())
  @app.enable('view cache')

  @logRequests = true
  @checkSpam = false
    notifications:
      from: "BurnZone <notifications@#{host}>"
      fromAddress: "notifications@noreply.#{host}"
      replyToHost: "reply.#{host}"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>"
      welcomeEmailCC: ["patrick@theburn-zone.com"]
  @replyHost = "http://reply.#{host}"

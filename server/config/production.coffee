module.exports = ()->
  express = require("express")
  @port = process.env.PORT || 80
  @sessionAge = 30 * 24 * 3600 * 1000 # 30 days
  @sessionCookieDomain = ".theburn-zone.com"
  @serverHost = "http://www.theburn-zone.com"
  @loginRoot = "http://www.theburn-zone.com/auth"
  @resourcePath = "http://cdn.theburn-zone.com/web"
  @fbClientID = process.env.FB_CLIENT || "116634621828507"
  @fbClientSecret = process.env.FB_SECRET || "e840224ff471f6cf9bf776770c8fcba0"
  @twKey = process.env.TW_KEY || "4LfI6YgQGTGfQLJYpkU9A"
  @twSecret = process.env.TW_SECRET || "vX3yYFJ2zVgX3cPp4yzwtEXcGkgaOBBvt9tRYXoGKQ4"
  @googleKey = process.env.GL_KEY || "707831140594.apps.googleusercontent.com"
  @googleSecret = process.env.GL_SECRET || "EwSY260a1IFWQKcr-sU2ZGwp"
  @disqusKey = "h6MfYQh2sfUiZjMRKXXRk2rtgLBPnq3Dvf5hhSAv84OsMT5QmRQMj8PpcyhG9vD5"
  @disqusSecret = "iCd4ykjzyfexTXEBAnCHWceCmvnh3Mmaud05oV755vtbJu6n2ebP3oOk5fn2Jdbl"
  @domain = "theburn-zone.com"
  @domainAndPort = "theburn-zone.com"
  # Do not set this to the same value as staticPath because it's not supposed to be public
  @cachePath = "../cache"
  @recaptcha_public = process.env.RECAPTCHA_PUBLIC || "6LcWTt0SAAAAAIuW8zz5oFcY0y8WsJkULfZB6wzY"
  @recaptcha_private = process.env.RECAPTCHA_PRIVATE || "6LcWTt0SAAAAAGoTd_Zd6eqlWxkz4_an17rAhJKC"
  @verify_captcha = true
  @redis = {port: process.env.REDIS_PORT || 6379, host: process.env.REDIS_HOST || "ec2-184-73-13-39.compute-1.amazonaws.com", password: process.env.REDIS_PASS || "qWtuFk5uHlO+1q$wni"}
  @akismet_api_key = '1f36458aa647'
  @emailSubjectKey = 'hs730gRFjs8Ju(&^34kj345#$wd!sagG'
  this["db.session"] = {uri: process.env.DB_SESSION || "mongodb://burnzonestrong:Vxn1Ztv2VXegE@candidate.20.mongolayer.com:10469/burnzoneprodel/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.log"] = {uri: process.env.DB_LOG || "mongodb://burnzonestrong:Vxn1Ztv2VXegE@candidate.20.mongolayer.com:10469/burnzoneprodel/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}
  this["db.app"] = {uri: process.env.DB_APP || "mongodb://burnzonestrong:Vxn1Ztv2VXegE@candidate.20.mongolayer.com:10469/burnzoneprodel/?auto_reconnect=true&w=1", options: {server: {socketOptions: {keepAlive: 100}}}}

  this["aws.auth"] = {accessKeyId: process.env.AWS_KEY || "AKIAJ45MLFTVXDLKH6DQ", secretAccessKey: process.env.AWS_SECRET || "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"}
  this["aws.bucket"] = "burnzone"
  this["aws.keypref_plugins"] = "plugins/"

  @stripe = {
    secret: "sk_live_CRehoj4VBN6YyYso7H1GlTE7"
    public: "pk_live_EYy0Lj9ptiWQ1RgV9G0KQTu5"
    public_test: "pk_test_LFr9QWsiP0OhmVJFpG6k9Fep"
  }

  @app.use(express.compress())
  @logRequests = false

  @checkSpam = true
  @replyHost = 'http://www.theburn-zone.com'
  @mandrill_webhook_keys = {
    reply: '-PL_PM3PFLaJfDz4nRrPcQ'
    moderate: '2TQ0jobaVMl7VCIoai4ujQ'
  }
  @email =
    notifications:
      from: "BurnZone <notifications@theburn-zone.com>"
      fromAddress: "notifications@noreply.theburn-zone.com"
      replyToHost: "reply.theburn-zone.com"
      welcomeEmailFrom: "Brady <brady@theburn-zone.com>"
      welcomeEmailCC: ["patrick@theburn-zone.com"]

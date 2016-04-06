module.exports = (done)->

  if !@checkSpam
    return done()
  akismet = require("akismet").client({blog: @serverHost, apiKey: @akismet_api_key})

  akismet.verifyKey((err, verified)->
    if err
      return done(err)
    if (!verified)
      return done(new Error('Unable to verify Akismet key'))
    done()
  )

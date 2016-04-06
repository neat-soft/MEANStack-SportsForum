crypto = require("crypto")
debug = require("debug")("sso")

module.exports.createSiteSecret = (site)->
  try
    rndBytes = crypto.randomBytes(128).toString("hex")
    return rndBytes
  catch ex
    return null

module.exports.verifyCredentials = (msg, site)->
  try
    if !msg
      debug("null message")
      return null
    
    [base64data, hmac, timestamp] = msg.split(" ")

    if !base64data || !hmac || !timestamp
      debug("not enough fields")
      return null

    alg = crypto.createHmac("sha1", site.sso.secret)
    alg.update("#{base64data} #{timestamp}", "utf-8")
    verifHash = alg.digest("hex")
    if verifHash != hmac
      debug("wrong hash")
      return null

    buf = new Buffer(base64data, "base64").toString("utf-8")
    debug("got data: #{buf}")
    data = JSON.parse(buf)
    return data

  catch err
    debug("got error: #{err}")
    return null

module.exports.sha1 = (msg)->
  alg = crypto.createHash('sha1')
  alg.update(msg)
  return alg.digest('hex')


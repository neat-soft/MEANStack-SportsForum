crypto = require("crypto")
http = require("http")
https = require("https")
defaults = require("./defaults")
os = require("os")
fs = require("fs")
async = require("async")
path = require("path")
sharedUtil = require("./shared/util")
parseUrl = require('url').parse
debug = require("debug")("util")
config = require("naboo").config

millicount = 0
laststamp = 0

module.exports.md5Hash = md5Hash = (text)->
  try
    md5 = crypto.createHash("md5")
    md5.update(text, "utf8")
    return md5.digest("hex")
  catch e
    return ""

host = require("os").hostname()
pid = process.pid
machine = md5Hash(host + pid.toString())

module.exports.uniquets = uniquets = ->
  stamp = new Date().getTime()
  if stamp == laststamp
    millicount++
  else
    laststamp = stamp
    millicount = 0
  return "#{laststamp}#{millicount}"

module.exports.getValue = (name)->
  if defaults[name]?
    return defaults[name]
  else
    throw new Error("Property #{name} not found")
  # return defaults[name]

module.exports.uid = uid = (len)->
  minBytes = 24
  minExtra = uniquets() + machine
  byteslenExtra = Math.max(len - (minExtra.length + minBytes), 0)
  byteslen = minBytes + (if byteslenExtra > 0 then byteslenExtra else 0)
  bytes = crypto.pseudoRandomBytes(Math.ceil(byteslen * 3 / 4)).toString('base64')
  return (bytes + minExtra).slice(0, byteslen + minExtra.length)

module.exports.wrapError = wrapError = (cbUp, cbLow)->
  return (err, result)->
    if err
      cbUp(err, null)
    else
      cbLow(result)

module.exports.wex = wex = (fn, callback)->
  try
    fn()
  catch error
    callback(error)

module.exports.md5HashB = md5HashB = (buffer)->
  try
    md5 = crypto.createHash("md5")
    md5.update(buffer)
    return md5.digest("hex")
  catch e
    return ""

verification_headers =
  'User-Agent': 'Mozilla/5.0 (Ubuntu; Linux x86_64) Node.js'
  'Accept': 'text/html,application/xhtml+xml'
  'Connection': 'close'
  'Cache-Control': 'no-cache'

module.exports.urlExists = (url, cb)->
  engine = http
  if url.indexOf("https") == 0
    engine = https
  urlbreakdown = parseUrl(url)
  # some servers require User-Agent to be set
  engine.get({host: urlbreakdown.host, port: urlbreakdown.port, path: urlbreakdown.path, headers: verification_headers}, (res)->
    res.resume()
    if res.statusCode < 200 || res.statusCode >= 300
      cb({url_not_reachable: true, response: {status_code: res.statusCode, headers: res.headers}})
    else
      cb()
  ).on("error", (err)->
    cb(err)
  )

module.exports.token = ->
  return crypto.pseudoRandomBytes(32).toString("hex") + uniquets() + machine

module.exports.sha1hmacbase64 = (key, text)->
  data = crypto.createHmac("sha1", key)
  data.update(text)
  return data.digest('base64')

module.exports.sha1hmachex = (key, text)->
  data = crypto.createHmac("sha1", key)
  data.update(text, 'utf8')
  return data.digest('hex')

module.exports.sha256Hash = sha256Hash = (text)->
  sha = crypto.createHash("sha256")
  sha.update(text, "utf8")
  return sha.digest("hex")

module.exports.hashPassword = (passwd, salt)->
  hckeypref = "hwe75bfcd/d3@"
  hckeysuff = "#rpi;lhd!"
  passwd = hckeypref + passwd + hckeysuff + salt
  return sha256Hash(passwd)

module.exports.objNavigate = (obj, prop)->
  elems = prop.split(".")
  context = obj
  if elems.length == 0
    return obj
  for elem in elems
    context = context[elem]
    if !context
      return undefined
  return context

module.exports.jsparse = jsparse = (text)->
  try
    return JSON.parse(text)
  catch error
    return null

module.exports.urlSupported = urlSupported = (url)->
  return /^https?\:\/\//.test(url)

module.exports.ensureUrlProtocol = (url)->
  if !(/^https?\:\/\//.test(url))
    return "http://" + url
  return url

module.exports.qs = (url)->
  qmark = url.indexOf("?")
  if qmark > 0
    return url.substring(qmark)
  return ""

# Must be a color #RRGGBB, prepares it and if it does not match give null
module.exports.color = (color)->
  color = sharedUtil.removeWhite(color)
  if !_.str.startsWith(color, '#')
    color = '#' + color
  if color.length > 7
    color = color.substring(0, 7)
  if !/#[0-9a-fA-F]{6}/.test(color)
    return null
  return color.toLowerCase()

module.exports.nodeId = crypto.createHash('md5').update(os.hostname() + process.pid).digest('binary')

module.exports.walk = walk = (dir, done)->
  results = []
  fs.readdir(dir, (err, list)->
    if err then return done(err)
    async.each(list, (file, next)->
      file = path.join(dir, file)
      fs.stat(file, (err, stat)->
        if err then return next(err)
        if stat && stat.isDirectory()
          walk(file, (err, res)->
            if err then return next(err)
            results = results.concat(res)
            next()
          )
        else
          results.push(file)
          next()
      )
    , (err)->
      done(err, results)
    )
  )

# make a request to the Facebook Graph API
module.exports.fbreq = (method, path, params, callback)->
  args = []
  for k, v of params
    args.push("#{k}=#{encodeURIComponent(v)}")
  if args.length > 0
    path = "#{path}?#{args.join("&")}"
  debug("request: #{method} #{path}")
  req = https.request({
    hostname: "graph.facebook.com"
    path: path
    method: method
  }, (res)->
    code = res.statusCode
    headers = res.headers
    data = []
    res.on("data", (d)->
      data.push(d)
    )
    res.on("end", ->
      dict = data.join("")
      try
        dict = JSON.parse(dict)
      catch err
        d = {}
        for elem in dict.split("&")
          [k, v] = elem.split("=")
          d[k] = v
        dict = d
      callback(code, headers, dict)
    )
  )
  req.on("error", (e)->
    console.error(e)
    callback(-1, {}, {})
  )
  req.end()

module.exports.iter_cursor = (cursor, cb_elem, cb_finish)->
  iteritem = (err_item, item)->
    if err_item
      if !cursor.isClosed()
        cursor.close()
      return cb_finish(err_item)
    if !item
      return cb_finish()
    cb_elem(item, (err_end)->
      if err_end
        cursor.close()
        return cb_finish(err_end)
      cursor.nextObject(iteritem)
    )
  cursor.nextObject(iteritem)

# given an object 'obj' with a 'field' that contains a mongo ObjectID,
# update the field's value to contain the actual object from mongo
# eg. load_field(req.site, "user", "users") would update req.site.user with
# the actual user object instead of just the userId
module.exports.load_field = (obj, field, fromCollection, options, cb)->
  if _.isFunction(options)
    cb = options
    options = {}
  options ?= {}
  if obj[field]?._id
    return process.nextTick(-> cb(null, obj))
  fromCollection.findOne({_id: obj[field]}, (err, item)->
    if err
      cb(err, obj)
    else
      if !item && options.required
        return cb({notexists: true})
      obj[field] = item
      cb(null, obj)
  )

# variant of async.waterfall that sends the callback as first argument instead
# of last
module.exports.waterfall = (actions, done)->
  switch_callback_position = (func)->
    return ()->
      args = Array.prototype.slice.call(arguments)
      args.unshift(args.pop()) # move last element to front
      return func.apply(null, args)
  new_actions = actions.map(switch_callback_position)
  return async.waterfall(new_actions, done)

# make a payment of 'amount' cents and attach it a description
# callback has the signature (error, payment_id)
module.exports.make_payment = (token, amount, description, meta, callback)->
  if typeof meta == 'function'
    callback = meta
    meta = {}
  stripe = require("stripe")(config.stripe.secret)
  stripe.charges.create({
    card: token
    currency: "usd"
    amount: amount
    description: description
    metadata: meta
  }, (err, charge)->
    callback(err, charge?.id)
  )

module.exports.sendAsFile = (res, content, name)->
  res.setHeader("Content-Type", "application/octet-stream")
  res.setHeader("Content-Disposition", "attachment; filename=" + name)
  res.send(content)

mongo = require("mongodb")
moment = require("moment")

module.exports.streamResults = (cursor, wstream, iterator, done)->
  stream = cursor.stream()
  first = true
  stream.on("data", (doc)=>
    if !first
      wstream.write(",")
    first = false
    wstream.write(JSON.stringify(iterator?(doc) || doc))
  )
  stream.on("error", (err)->
    wstream.write("]")
    done(err)
  )
  stream.on("close", ->
    wstream.write("]")
    done(null)
  )
  wstream.write("[")

module.exports.ids2str = (id_array)->
  return _.map(id_array, (id)->
    return id.toHexString()
  )

module.exports.errDuplicateKey = (err)->
  if !err
    return false
  return err.code == 11000 || err.code == 11001 || (last = err.lastErrorObject ? {}).code == 11000 || last.code == 11001

module.exports.errColExists = (err)->
  return err.message.indexOf("already exists. Currently in safe mode") > 0

module.exports.idFrom = (id)->
  if id
    if id.toHexString
      return id
    else
      try
        return new mongo.ObjectID(id)
      catch error
        return null
  else
    return null

module.exports.idFromTime = (unixTime, options)->
  try
    unixTime = Math.floor(unixTime / 1000)
    if 0xffffffff < unixTime
      unixTime = 0xffffffff
    timePart = unixTime.toString(16)
    extraChars = []
    while timePart.length + extraChars.length < 8
      extraChars.push("0")
    if options?.random
      trailing = new mongo.ObjectID().toHexString().slice(8)
    else
      trailing = "0000000000000000"
    return new mongo.ObjectID(extraChars.join("") + timePart + trailing)
  catch error
    return ""

module.exports.id = ->
  return new mongo.ObjectID()

isPlainObject = (obj)->
  return _.isObject(obj) &&
    !(_.isDate(obj) ||
    _.isNumber(obj) ||
    _.isString(obj) ||
    _.isArray(obj) ||
    _.isRegExp(obj) ||
    _.isBoolean(obj) ||
    _.isFunction(obj) ||
    obj instanceof mongo.ObjectID)

module.exports.extend_query = (query, extra)->
  for own key, val of extra
    existing = query[key]
    if existing && isPlainObject(existing) && isPlainObject(val)
      _.extend(query[key], val)
    else
      query[key] = val
  return query

module.exports.extendExpiration = (col, query, fieldName, amount, amountType, done)->
  now = moment.utc()
  millis = moment(now).add(amount, amountType).diff(now)
  # set date to 'now' if the existing? one is in the past
  q = _.clone(query)
  q.$or = [{}, {}]
  q.$or[0][fieldName] = {$exists: false}
  q.$or[1][fieldName] = {$lt: now.valueOf()}
  to_set = {$set: {}}
  to_set.$set[fieldName] = now.valueOf()
  col.update(q, to_set, {}, (err)->
    if err
      return done(err)
    # increment expiration; the ones in the past were updated to current time
    q = _.clone(query)
    to_set = {$inc: {}}
    to_set.$inc[fieldName] = millis
    col.update(q, to_set, {}, (err)->
      done(err)
    )
  )

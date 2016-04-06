async = require("async")
dbutil = require("../../datastore/util")
debug = require("debug")("api:response")
logger = require("../../logging").logger

module.exports.csv = (attrs)->
  return {
    start: -> attrs.join(',') + "\n"
    end: -> ""
    item: (doc)->
      _.map(_.valuesOrder(doc, attrs), (v)->
        v ?= ''
        v.replace?(',', '_') || v.toString()
      ).join(",") + "\n"
  }

module.exports.handleError = handleError = (err, res)->
  debug("%j", err)
  if err.notexists ||
    err.sitenotexists ||
    err.forumnotenabled
      res.send(404, err)
  else if err.notallowed ||
    err.denied ||
    err.alreadyflagged ||
    err.needs_moderator ||
    err.needs_admin ||
    err.needs_premium ||
    err.needs_author ||
    err.notenoughpoints ||
    err.invalidurl ||
    err.challenge_ended ||
    err.not_verified ||
    err.exists ||
    err.forceid ||
    err.useqs ||
    err.invalid_text ||
    err.active_competition ||
    err.needs_login ||
    err.invalid_points_value ||
    err.below_minimum_promote_points ||
    err.bet_cannot_target_self ||
    err.user_is_author ||
    err.low_status
      res.send(403, err)
  else if err.notsupported ||
    err.siterequired ||
    err.invalid_side ||
    err.invalid ||
    err.invalid_profile ||
    err.bet_invalid_type ||
    err.bet_invalid_points ||
    err.bet_invalid_points_value ||
    err.bet_invalid_ratio ||
    err.bet_invalid_date ||
    err.bet_invalid_users ||
    err.bet_invalid_users_value ||
    err.bet_users_nonexistent
      res.send(400, err)
  else if err.email_incorrect ||
    err.bad_syntax ||
    err.invalid_name ||
    err.invalid_password ||
    err.invalid_parent
      res.send(400, err)
  else if err.conflict
    res.send(409, err)
  else
    logger.error(err, {req: logger.requestData(res.req, res)})
    if err.timeout
      res.statusCode = err.status
      return res.end()
    res.send(500)

module.exports.handleErrorAndNull = handleErrorAndNull = (err, obj, res)->
  if err
    handleError(err, res)
    return true
  if !(obj?)
    res.send(404)
    return true
  return false

module.exports.sendObj = (res, filter)->
  return (err, result)->
    debug("sending doc %j", result)
    handleErrorAndNull(err, result, res) || res.send(filter?(result) || result)

module.exports.sendObjAsyncFilter = (res, filter)->
  return (err, result)->
    debug("sending doc %j with async filter", result)
    handleErrorAndNull(err, result, res) || filter(result, (err, obj)->
      debug("sending async %j", obj)
      res.send(obj)
    )

module.exports.sendValue = (res)->
  return (err, result)->
    debug("sending value %j", result)
    handleErrorAndNull(err, result, res) || res.send({result: result})

module.exports.sendCursor = (res, filter)->
  return (err, result)->
    handleErrorAndNull(err, result, res) || dbutil.streamResults(result, res, filter, (err)->
      if err
        logger.error(err)
        if !res.headerSent
          res.status(500)
      res.end()
    )

module.exports.sendPagedCursor = (res, filter)->
  return (err, result)->
    last = null
    wrapFilter = (doc)->
      if filter
        doc = filter(doc)
      last = doc
      return doc
    if !handleErrorAndNull(err, result, res)
      res.write("{\"data\":")
      dbutil.streamResults(result, res, wrapFilter, (err)->
        res.write(",\"from\":" + JSON.stringify(last?._id || null) + "}")
        if err
          res.write(",\"error\":{}")
          logger.error(err)
          if !res.headerSent
            res.status(500)
        res.end()
      )

module.exports.sendPagedArrayAsyncFilter = sendPagedArrayAsyncFilter = (res, filter, options)->
  return (err, items)->
    if !handleErrorAndNull(err, items, res)
      debug("sending array with async filter")
      async.mapSeries(items, filter, (err, results)->
        debug("async filter done for all: #{results.length} results")
        res.write("{\"data\":")
        res.write(JSON.stringify(results))
        if options.limit? && results.length < options.limit
          from = null
        else
          from = results[results.length - 1]?._id || null
        res.write(",\"from\":" + JSON.stringify(from) + "}")
        res.end()
      )

module.exports.sendPagedArray = (res, filter, options, limit)->
  if typeof(options) != 'object'
    limit = options
    options = {}
  if options.limit
    limit = options.limit
  if limit
    options.limit = limit

  if options.async_filter
    return sendPagedArrayAsyncFilter(res, filter, options)

  return (err, result)->
    last = null
    wrapFilter = (doc)->
      if filter
        doc = filter(doc)
        debug("filtered array doc %j", doc)
      last = doc
      return doc
    if !handleErrorAndNull(err, result, res)
      debug("sending array %j", result)
      res.write("{\"data\":")
      res.write(JSON.stringify(_.map(result, wrapFilter)))
      if limit? && result.length < limit
        from = null
      else
        from = last?._id || null
      res.write(",\"from\":" + JSON.stringify(from) + "}")
      res.end()

# sends the cursor data formatted according to format
# format should return a string
# see csv above for a sample format
module.exports.sendFormatArray = sendFormatArray = (res, filter, format)->
  return (err, result)->
    if !handleErrorAndNull(err, result, res)
      debug("sending format array %j", result)
      res.write(format.start(result))
      res.write(_.map(result, (item)-> format.item(filter?(item) || item)).join(""))
      res.write(format.end(result))
      res.end()

# same as above but fetches the cursor into array first
# useful to write an error status code if something wrong happens
module.exports.sendFormatCursor = (res, filter, format)->
  return (err, result)->
    if !handleErrorAndNull(err, result, res)
      result.toArray(sendFormatArray(res, filter, format))

module.exports.streamItem = (res, filter, format)->
  return (item, next)->
    debug('stream item %j', item)
    res.write(format.item(filter?(item) || item))
    next()

module.exports.streamStartEnd = (res, iter, format)->
  debug('start stream')
  res.write(format.start())
  return (err, end)->
    if err
      debug('end stream with error')
      if !res.headerSent
        return handleError(err, res)
      else
        logger.error(err, {req: logger.requestData(res.req, res)})
        return res.socket.destroy()
    debug('end stream')
    res.write(format.end())
    res.end()

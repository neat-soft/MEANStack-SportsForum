jlog = require("./jlog")

module.exports.logger = logger =
  doLog: (item)->
    jlog.log(item)

  log: (type, item)->
    if !item
      item = type
    if !item
      return
    if item instanceof Error
      item = @prepareError(item)
    if !_.isObject(item)
      item = {_raw: item}
    if !item._time
      item._time = new Date()
    if !item._type
      item._type = type || defaultType
    item["process-pid"] = process.pid
    @doLog(item)

  prepareError: (item)->
    return {error: {message: item.message, stack: item.stack, type: item.constructor.name}}

  embedError: (err, req, site, id, url)->
    @log({_type: "embed", error: err, site: site, url: url, id: id, app_type: req.appType, req: @requestData(req, {})})

  embedOk: (req, site, id, url)->
    @log({_type: "embed", site: site, url: url, id: id, req: @requestData(req, {})})

  error: (item, options = {})->
    if item instanceof Error
      item = @prepareError(item)
    _.extend(options, item)
    @log('error', item)

  requestData: (req, res)->
    return {
      host: req.headers.host
      url: req.originalUrl || req.url
      method: req.method
      response_time: new Date() - req._startTime
      date: new Date()
      status_code: res.statusCode
      referrer: req.headers['referer'] || req.headers['referrer']
      remote_address: req.ip
      http_version: req.httpVersionMajor + '.' + req.httpVersionMinor
      user_agent: req.headers['user-agent']
    }

  request: (req, res)->
    @log("request", @requestData(req, res))

  timeout: (req, res)->
    @log("timeout", @requestData(req, res))

module.exports.express = (options)->
  options ?= {}
  return (req, res, next)->
    req._startTime = new Date()
    if options.immediate
      logger.request(req, res)
    else
      end = res.end
      res.end = (chunk, encoding)->
        res.end = end
        res.end(chunk, encoding)
        logger.request(req, res)
    next()

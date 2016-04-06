# Options:
# - immediate: whether to log the request immediately or wait until the response is ended

module.exports.request = request = (req, res)->
  return {
    _type: "request"
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

module.exports.middleware = (logger, options)->
  options ?= {}
  return (req, res, next)->
    if !(options.skip && options.skip.test?(req.path))
      if options.immediate
        logger.log(request(req, res))
      else
        end = res.end
        req._startTime = new Date()
        res.end = (chunk, encoding)->
          res.end = end
          res.end(chunk, encoding)
          logger.log(request(req, res))
    next()

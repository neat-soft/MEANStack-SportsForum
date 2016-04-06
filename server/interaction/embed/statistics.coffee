collections = require("../../datastore").collections
handlers = require("../handlers")
util = require("../../util")
sharedUtil = require("../../shared/util")
config = require("naboo").config
logger = require("../../logging").logger

site = (req, res, next)->
  siteName = req.query.s?.toLowerCase()
  req.siteName = siteName
  handlers.siteAndProfile(req, res, next)

count = (req, res)->
  id = sharedUtil.removeWhite(req.query.id)
  url = req.query.u
  title = _.str.trim(req.query.t)
  if !url || !util.urlSupported(url)
    res.send(404)
    return
  if url == config.serverHost + "/embed"
    res.send(404)
    return
  q = req.query
  collections.conversations.enter(req.site, title, id, url, (err, c)->
    if !err && c
      counts = 
        comments: c.no_comments
        challenges: c.no_challenges
        questions: c.no_questions
        all_comments: c.no_all_comments
        activities: c.no_activities
        all_activities: c.no_all_activities
      res.setHeader('Content-Type', 'text/javascript')
      if !id
        res.send(req.query.callback + "(null, '#{url}', #{JSON.stringify(counts)});")
      else
        res.send(req.query.callback + "('#{id}', '#{url}', #{JSON.stringify(counts)});")
    else
      logger.error(err)
      res.send('')
  )

module.exports = (app)->

  app.get("/web/js/count.js", site, count)
  app.get("/web/js/count.js", (err, req, res)->
    if err.sitenotexists
      res.send(404)
    else if err.notsupported || err.siterequired
      res.send(400)
    else
      res.send(500)
  )
  
collections = require("../../datastore").collections
dbutil = require("../../datastore/util")
response = require("./response")
handlers = require("../handlers")
pubsub = require("../../pubsub")
moment = require("moment")
debug = require("debug")("api:competitions")

module.exports = (app)->

  app.get("/api/sites/:site/competitions", (req, res)->
    debug("GET competitions for #{req.site.name}")
    collections.competitions.getForSite(req.site, response.sendPagedCursor(res, _.partialEnd(collections.competitions.toClient, req.site)))
  )

  pad_int_sign = (i, pad_len)->
    i = i || 0
    sign = i < 0
    if sign
      i = -i

    s = i.toString()
    while s.length < pad_len
      s = "0" + s

    return (if sign then "-" else "+") + s

  verify_competition = (req, res)->
    attrs = {
      title: req.body.title
      community: req.body.community
      # save to UTC
      start: moment.utc(req.body.start, "DD/MM/YYYY HH:mm")?.toDate()
      end: moment.utc(req.body.end, "DD/MM/YYYY HH:mm")?.toDate()
      prize: req.body.prize
      prize_url: req.body.prize_url
      site: req.params["site"]
      social_share: req.body.social_share
      rules_url: req.body.rules_url
      verified: req.body.verified
      badge_id: parseInt(req.body.badge_id, 10) || null
    }

    if !attrs.title
      res.send(400, "Competition must have a title")
      return null

    if !attrs.start || !attrs.end
      res.send(400, "Competition must have a start date and an end date")
      return null

    if attrs.end < moment().utc()
      res.send(400, "Competition must end in the future")
      return null

    return attrs


  app.post("/api/sites/:site/competitions", handlers.requireModerator, (req, res)->
    debug("POST competition #{req.params}")

    attrs = verify_competition(req, res)

    if attrs
      collections.competitions.add(attrs, (err, comp)->
        if err
          res.send(400, "Error creating competition")
        else
          debug("got: #{JSON.stringify(comp)}")
          res.send(200, collections.competitions.toClient(comp, req.site))
      )
  )

  app.get("/api/sites/:site/competitions/active", (req, res)->
    debug("GET active competitions for #{req.site.name}")
    collections.competitions.getActiveForSite(req.site, response.sendPagedCursor(res, _.partialEnd(collections.competitions.toClient, req.site)))
  )

  app.get("/api/sites/:site/competitions/:comp", (req, res)->
    debug("GET competition #{req.params["comp"]}")
    collections.competitions.get(req.params["comp"], (err, comp)->
      if err
        res.send(404)
      else
        debug("sending competition #{JSON.stringify(comp)}")
        res.send(200, collections.competitions.toClient(comp, req.site))
    )
  )

  app.put("/api/sites/:site/competitions/:comp", handlers.requireModerator, (req, res)->
    debug("PUT competition #{JSON.stringify(req.body)}")
    attrs = verify_competition(req, res)

    if attrs
      collections.competitions.findAndModify({_id: dbutil.idFrom(req.params["comp"])}, [], {$set: attrs}, {new: true}, (err, comp)->
        debug("got: #{JSON.stringify(comp)}")
        res.send(200, collections.competitions.toClient(comp, req.site))
      )
  )

  app.delete("/api/sites/:site/competitions/:comp", handlers.requireModerator, (req, res)->
    debug("DELETE competition #{JSON.stringify(req.params["comp"])}")

    collections.competitions.remove({_id: dbutil.idFrom(req.params["comp"])}, (err)->
      if err
        res.send(400, "Error deleting competition")
      else
        res.send(200, "")
    )
  )

  app.get("/api/sites/:site/competitions/:comp/leaders", (req, res)->
    compId = req.params["comp"]
    debug("GET leaders of competition #{compId} for #{req.site.name}")
    collections.competitions.findOne({_id: dbutil.idFrom(compId)}, (err, comp)->
      if comp?.badge_id
        collections.badges.leaders(comp.badge_id, dbutil.idFrom(compId), req.site, req.user, req.profile, req.query.min_rank, response.sendPagedArray(res))
      else
        collections.competition_profiles.leaders(req.params["comp"], response.sendPagedArray(res, collections.competition_profiles.toClient))
    )
  )


module.exports = (app)->

  updates = require("../../datastore/updates")

  fetchAllUpdates = (req, res)->
    conv = req.query.context
    sinceComments = sinceChallenges = sinceContext = parseInt(req.query.since) || 0
    updates.fetchAll(conv, sinceComments, sinceChallenges, sinceContext, res)

  app.get("/api/updates", (req, res)->
    res.send({comments: [], challenges: [], contexts: [], deleted: []})
  )

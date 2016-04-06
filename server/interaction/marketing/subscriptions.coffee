module.exports = (app)->

  collections = require("../../datastore").collections
  templates = require("../../templates")

  app.get("/subscription/:token", (req, res)->
    collections.subscriptions.findAndModify({token: req.params["token"]}, [], {$set: {verified: true}}, (err, subscription)->
      if err
        templates.render(res, "marketing/error", {error: "Your request could not be fulfilled due to an error"})
      else if subscription
        templates.render(res, "marketing/verify_subscription", subscription)
      else
        templates.render(res, "marketing/error", {error: "This subscription does not exist"})
    )
  )

  app.get("/unsubscribe/:token", (req, res)->
    collections.subscriptions.findAndModify({token: req.params["token"]}, [], {$set: {active: false}}, (err, subscription)->
      if err
        templates.render(res, "marketing/error", {error: "Your request could not be fulfilled due to an error"})
      else if subscription
        templates.render(res, "marketing/unsubscribe", subscription)
      else
        templates.render(res, "marketing/error", {error: "This subscription does not exist"})
    )
  )

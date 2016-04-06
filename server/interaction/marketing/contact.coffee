email = require("../../email")
templates = require("../../templates")
BaseCollection = require("../../datastore/base")
collections = require("../../datastore").collections
handlers = require("../handlers")
logger = require("../../logging").logger

module.exports = (app)->

  app.post("/about", (req, res)->
    name = req.body.name || ""
    eaddress = req.body.email || ""
    phone = req.body.phone || ""
    text = req.body.text

    collections.jobs.add({type:"EMAIL", emailType: "CONTACT", name: name, email: eaddress, phone: phone, text: text, can_reply: false}, (err, result)->
      error = null
      info = null
      if err
        logger.error(err)
        error = "We encountered an error while sending your message. Please try again."
      else
        info = "Thank you for being interested in our work! We will contact you as soon as possible."
      templates.render(res, "marketing/company", {error: error, info: info})
    )
  )

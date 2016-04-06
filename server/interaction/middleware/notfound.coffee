templates = require("../../templates")

module.exports = (req, res, next)->
  templates.render(res.status(404), "marketing/404_not_found", {user: req.user})

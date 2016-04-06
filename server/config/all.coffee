consolidate = require('consolidate')
io = require("socket.io")
express = require("express")
module.exports = ()->

  @app = express()
  @app.disable('x-powered-by')
  # setup the view engines
  @app.engine('hbs', consolidate.handlebars)
  @app.set('views', './render')
  @app.set('view engine', 'hbs')
  @useSubdomains = true

  # these subdomains serve another purpose, we don't redirect them
  @special = {
    blog: true
    cdn: true
    www: true
    calendar: true
    email: true
    fax: true
    files: true
    ftp: true
    help: true
    imap: true
    mail: true
    mobilemail: true
    pop: true
    smtp: true
    staging: true
    zb13745412: true
    reply: true
    noreply: true
  }

  this["plugins.wordpress.v"] = "1.0.3"
  this["plugins.vbulletin.v"] = "0.2.0"
  this["sockets"] = io.sockets

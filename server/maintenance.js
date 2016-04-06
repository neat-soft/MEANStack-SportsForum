require('coffee-script');
var proxy = require("proxywrap")
  , express = require("express")
  , fs = require("fs")
  , naboo = require("naboo")
  , templates = require("./shared/templates")
  , handlebars = require("handlebars")
  , http = require("http");
global._ = require("underscore");
global._.str = require("underscore.string");

naboo({init: ['10_statichash']}, function(err){
  var config = naboo.config;
  var maintenance_view = handlebars.compile(fs.readFileSync('./render/maintenance/index.html.hbs', {encoding: 'utf-8'}))();
  var maintenance_script = handlebars.compile(fs.readFileSync('./render/maintenance/embed.js.hbs', {encoding: 'utf-8'}))();
  estatic = express.static('./static');
  config.app.use('/web', function(req, res, next){
    if (/font\//.test(req.path))
      res.setHeader("Access-Control-Allow-Origin", "*");
    estatic(req, res, next);
  });
  config.app.get('*', function(req, res) {
    if (req.path == '/web/js/embed.js') {
      res.setHeader('Content-Type', 'application/javascript');
      res.send(maintenance_script);
    }
    else if(!/\/web/.test(req.path)) {
      res.setHeader('Content-Type', 'text/html');
      res.send(200, maintenance_view);
    }
    else
      res.send(200);
  });

  var server = http.createServer(config.app);
  var port = config.port || 80;
  server = proxy.wrapServer(server, {strict:false});
  server.listen(port);
});

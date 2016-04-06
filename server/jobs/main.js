if (process.env.NEW_RELIC_ENABLED && !process.env.MAKE)
  require('newrelic');
global._ = require('underscore');
global._.str = require('underscore.string');
require("coffee-script");
logging = require("../logging");
require('naboo')();
process.on("uncaughtException", function(err){
  logging.logger.log("fatal", err);
  process.exit(1);
});

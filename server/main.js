if (process.env.NEW_RELIC_ENABLED && !process.env.MAKE)
  require('newrelic');

global._ = require('underscore');
global._.str = require('underscore.string');
require("coffee-script");
require("../shared/underscore_mixin");
var logging = require("./logging");
var cluster = require("cluster");
var numCPUs = require('os').cpus().length;
var debug = require("debug")("main");
var closing = false;
var wclosed = 0;
if (process.env.NODE_ENV === "test" || process.env.MAKE || process.env.CLUSTER === "single") {
  require('naboo')();
}
else {
  if (cluster.isMaster) {
    // Fork workers.
    debug("Launching %d workers", numCPUs)
    for (var i = 0; i < numCPUs; i++) {
      cluster.fork();
    }

    cluster.on('exit', function(worker, code, signal) {
      // worker died, respawn if not exiting
      debug("worker %s died, suicide = %s", worker.id, worker.suicide)
      if (!worker.suicide) {
        debug("refork...");
        cluster.fork();
      }
      else {
        wclosed++;
        if (wclosed === numCPUs && closing) {
          debug("all workers finished, closing");
          process.exit(0);
        }
      }
    });

    process.on("SIGTERM", function(){
      debug("got term, propagate to children")
      closing = true;
      for (var id in cluster.workers) {
        cluster.workers[id].kill();
      }
      setTimeout(function(){
        process.exit(0);
      }, 65000)
    });
  } else {
    // Workers can share any TCP connection
    // In this case its a HTTP server
    require('naboo')();
  }
}

// This is executed in all situations
process.on("uncaughtException", function(err){
  logging.logger.log("fatal", err);
  process.exit(0);
});

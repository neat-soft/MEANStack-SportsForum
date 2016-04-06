global._ = require('underscore');
global._.str = require('underscore.string');

require("coffee-script");
require("../shared/underscore_mixin");

var express = require('express');
var path = require('path');

require('naboo')({
  configPath: "../server/config",
  initPath: "../server/init",
  init: ["20_db"]
}, function(){
  var collections = require("../server/datastore").collections;
  var async = require("async");
  var LineByLineReader = require("line-by-line");
  var stream = require("stream");
  var moment = require("moment");
  var debug = require("debug")("import");

  var rl = new LineByLineReader(process.stdin);

  var currentConv = null;
  var currentSite = null;
  var processCount = 0;
  var lastTime = 0;

  function process_line(line) {
    var j = JSON.parse(line);
    if (j.uri) {
      // conversation
      async.waterfall([
        function (cb) {
          collections.sites.findOne({name: j.site}, cb);
        },
        function (site, cb) {
          collections.conversations.enter(site, j.title, j.id, j.uri, {silent: true}, function (err, conv) {
            cb(err, site, conv);
          });
        }
      ], function (err, site, conv) {
        if (!err) {
          currentSite = site;
          currentConv = conv;
          debug("found site and conv " + site.name + " " + conv.initialUrl);
        } else {
          debug(err);
        }
        rl.resume();
      });
    } else if (currentConv && currentSite) {
      // new comment
      if (j.content == null) {
        console.log(JSON.stringify(j, null, 2));
        throw new Error();
      }
      collections.comments.importComment(
        "wordpress",
        j.id,
        (j.parent !== "0") ? j.parent : null,
        currentSite,
        currentConv,
        {
          id: (j.user_id != 0) ? j.user_id : null,
          name: j.author,
          email: j.author_email
        },
        j.content,
        moment.utc(j.date_gmt, "YYYY-MM-DD HH:mm:ss").unix(),
        j.approved !== "0",
        {
          ip: "127.0.0.1",
          user_agent: "wp-pipe-comments.js"
        },
        function (err, comment) {
          if (err) {
            debug("skipped "+ j.id +": " + err.message);
          } else {
            debug("added "+ j.id +", continuing to next");
          }
          processCount++;
          process.stdout.write("processed: " + processCount + "                              \r");
          rl.resume();
        }
      );
    } else {
      debug("skip ");
      rl.resume();
    }
  }


  rl.on("line", function (line) {
    rl.pause();
    process_line(line);
  });

  rl.on("end", function () {
    process.stdout.write("\n\n");
    process.exit();
  });
});


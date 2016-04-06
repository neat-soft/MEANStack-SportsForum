// Underscore stuff
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
  var util = require('../server/util');
  var async = require("async");
  var modified = 0;
  var emails = [];
  async.waterfall([
    function(callback) {
      collections.users.find({email: {$exists: true}, deleted: {$ne: true}, $where: 'this.email !== this.email.toLowerCase()'}, callback);
    },
    function(cursor, callback) {
      cursor.toArray(callback);
    },
    function(all, callback) {
      // console.log(_.pluck(all, 'email'));
      // callback();
      async.forEach(all,
        function(u, done) {
          async.waterfall([
              function(ci) {
                modified++;
                console.log('Updating ', u.email);
                collections.users.update({_id: u._id}, {$set: {email: u.email.toLowerCase(), emailHash: util.md5Hash(u.email.toLowerCase())}}, function(err) {
                  if (err) {
                    emails.push(u.email);
                  }
                  ci();
                });
              }
            ],
            function(err) {
              done(err);
            });
        },
        function(err) {
          callback(err);
        }
      )
    }],
    function(err) {
      console.log('Modified', modified);
      if (err)
        console.error(err);
      else {
        if (emails.length > 0) {
          console.log("Problems with ", emails.length, " emails");
          console.log(emails);
        }
        else {
          console.log("Done, no problems");
        }
      }
      process.exit(err ? 1 : 0);
    }
  );
});

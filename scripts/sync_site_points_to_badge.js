/*
 * Script to migrate points from the site profile to the Top 5% badge.
 *
 * A dummy transaction is created for each user, with a timestamp as old as
 * the site profile, that contains all points that were NOT recorded by other
 * transactions.
 */
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
  var dbutil = require('../server/datastore/util');
  var async = require("async");
  console.log("find all profiles");
  collections.profiles.find({}, function (err, cursor) {
    console.log("iterating...");
    util.iter_cursor(cursor, function (profile, next_profile) {
      async.waterfall([
        function (callback) {
          collections.transactions.remove({type: "POINTS_FROM_PROFILE", user: profile.user, siteName: profile.siteName}, callback);
        },
        function (_, callback) {
          collections.transactions.aggregate([
            {$match: {siteName: profile.siteName, user: profile.user}},
            {$group: {
              _id: {user: "$user"},
              value: {$sum: "$value"}
            }}
          ], callback);
        },
        function (doc, callback) {
          callback(null, doc.length > 0 ? doc[0].value : 0);
        },
        function (other_txn_points, callback) {
          var remaining_points = profile.points - other_txn_points;
          if (remaining_points != 0) {
            console.log("extra points for " + profile.userName + " on site " + profile.siteName + ": " + remaining_points);
            collections.transactions.record({
              // create a transacrion ID as old as the profile
              _id: dbutil.idFrom(parseInt(profile._id.toHexString().slice(0, 8), 16), {random: true}),
              type: "POINTS_FROM_PROFILE",
              siteName: profile.siteName,
              user: profile.user,
              value: profile.points - other_txn_points
            }, callback);
          } else {
            console.log("no extra points for " + profile.userName + " on site " + profile.siteName);
            // nothing to do
            callback(null);
          }
        }
      ], function (err) {
        next_profile(err);
      });
    }, function (err) {
      console.log("done iterating profiles");
      process.exit(0);
    });
  });
});


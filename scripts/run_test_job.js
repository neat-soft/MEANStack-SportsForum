/*
 * Script to run a test job.
 */
global._ = require('underscore');
global._.str = require('underscore.string');

require("coffee-script");
require("../shared/underscore_mixin");

var express = require('express');
var path = require('path');

if (process.argv.length != 4) {
  console.log("usage: node " + process.argv[1] + " <function in jobs.coffee> <job type>");
  process.exit();
}

require('naboo')({
  configPath: "../server/config",
  initPath: "../server/init",
  init: ["20_db"]
}, function(){
  var collections = require("../server/datastore").collections;
  var util = require('../server/util');
  var dbutil = require('../server/datastore/util');
  var async = require("async");
  var jobs = require("../server/jobs/jobs/jobs");
  var job_func = process.argv[2];
  var job_type = process.argv[3];
  var the_job = jobs[job_func];
  console.log("running job." + job_func + " for " + job_type + " - " + typeof (the_job));
  the_job({locked: true, finished: false, type: process.argv[1]}, function (error) {
    console.log("JOB FINISHED: " + JSON.stringify(error));
    process.exit();
  });
});



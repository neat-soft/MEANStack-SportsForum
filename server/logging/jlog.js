/**
 * JSON logging module.
 * usage:
 *
 * jlog = require("jlog");
 * jlog.log(myJsonObject);
 *
 * OR
 *
 * log require("jlog").log
 * log(jsonObj)
 */

module.exports.MARKER = MARKER = "\x02log\x03";

module.exports.stringify = stringify = function () {
  var obj = {};
  if (arguments.length > 1) {
    obj = JSON.stringify(arguments);
  } else {
    obj = JSON.stringify(arguments[0]);
  }
  return obj;
}

module.exports.log = function() {
  console.log(MARKER + stringify.apply(null, [].slice.call(arguments, 0)) + MARKER + "\n");
}

/**
 * Run a process and redirect it's output to a Mongo database.
 *
 * Usage:
 * node redirect.js <description> <process name> [process arguments]
 */

os = require("os");
moment = require("moment");
spawn = require("child_process").spawn;
MongoClient = require("mongodb").MongoClient;
helenus = require("helenus");
_ = require("underscore");
jlog = require("./logging/jlog");

/* DB to use for logs */
URI = process.env.DB_LOG || "mongodb://localhost:27017/logs/?auto_reconnect=true&w=0"
CASS_URI = process.env.DB_CASSANDRA || "localhost:9160"
TIME_FORMAT = "MM_DD_HH_mm";

/* utility stuff missing from String */
if (typeof(String.prototype.endsWith) === "undefined") {
  String.prototype.endsWith = function(suffix) {
    return this.slice(-suffix.length) == suffix;
  };
}

if (typeof String.prototype.startsWith === "undefined") {
  String.prototype.startsWith = function (prefix){
    return this.slice(0, prefix.length) == prefix;
  };
}

if (typeof(String.prototype.trim) === "undefined") {
  String.prototype.trim = function() {
    return String(this).replace(/^\s+|\s+$/g, '');
  };
}

if (require.main === module) {
  main();
}

function main() {
  /* first 2 arguments are "node" and the current script name */
  args = process.argv.slice(2);

  source = args[0];
  args = args.slice(1);

  if (args[0] && args[0].endsWith(".js")) {
    childName = "node";
  } else {
    childName = args[0];
    args = args.slice(1);
  }

  var ks_name = "burnzone";

  if (process.env.NODE_ENV.indexOf("staging")  >= 0 || process.env.NODE_ENV.indexOf("dev") >= 0) {
    ks_name = "burnzone_staging";
  }

  console.log("using keyspace: ", ks_name);

  MongoClient.connect(URI, {}, function (err, db) {
    if (err) {
      throw err;
    }
    console.log("connected to mongo");

    cas = null
    // cas = new helenus.ConnectionPool({
    //   hosts: [CASS_URI],
    //   keyspace: ks_name,
    //   user: "",
    //   password: "",
    // });

    // cas.connect(function (err, ks) {
    //   console.log("helenus:", err);
      col = db.collection("logs");

      child = spawn_child(childName, args, col, cas, {"process-host":os.hostname(), "process-source": source});

      process.on('SIGTERM', function () {
        /* the child is a process group leader, we can kill the entire group by negating it's PID  */
        process.kill(-child.pid);
        process.exit(0);
      });

      child.on("close", function (code) {
        db.close();
      });
    // });
  });
}

/**
 * Spawn a subprocess and redirect it's output to mongo collections.
 *
 * @param name
 *        executable name
 * @param args
 *        command line arguments
 * @param col
 *        where to put the stdout/stderr text of the child process
 * @param attrs
 *        additional attributes to insert in collections
 *
 * @return a process object
 */
function spawn_child(name, args, col, cas, attrs) {
  console.log("spawning '"+ name +"' with "+ JSON.stringify(args));
  child = spawn(name, args, {detached: true, stdio: [0, "pipe", "pipe"], env: process.env});

  attrs["process-pid"] = child.pid;

  child.stdout.on("data", collection_inserter(col, cas, _.extend({}, attrs, {_type: "info"})));
  child.stderr.on("data", collection_inserter(col, cas, _.extend({}, attrs, {_type: "error"})));

  return child;
}

function first_key(dict) {
  for (var k in dict) {
    if (dict.hasOwnProperty(k)) {
      return k;
    }
  }

  return undefined;
}

function update_counter(cas, counter_name, site, conv) {
  table_name = "embed_count_" + moment().startOf("day").format(TIME_FORMAT);
  cas.cql("UPDATE " + table_name + " SET " + counter_name + " = " + counter_name + " + 1 WHERE site = ? AND conv = ?",
    [site, conv],
    function (err, res) {
      if (err) {
        console.error("failed to log %s: %s - %s", table_name, err.name, err.message);
      }
    }
  );
}

function do_insert(col, cas, attr, data) {

  if (attr.remote_address && (attr.remote_address.startsWith("10.") || attr.remote_address.startsWith("127."))) {
    /* don't polute the database with requests from the load balancer OR monit */
    return;
  }
  if (attr._type === "request") {
    /* insert into cassandra */
    /*
    cas.cql("INSERT INTO requests ("+
      "id, host, url, method, response_time, date, status_code, referrer, remote_address, http_version, user_agent"+
      ") VALUES ("+
      "now(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"+
      ")", [
      attr.host,
      attr.url,
      attr.method,
      attr.response_time,
      attr.date,
      attr.status_code,
      attr.referrer || '',
      attr.remote_address,
      attr.http_version,
      attr.user_agent || ''
      ], function (err) {
        if (err) {
          console.error("failed to log request: %s - %s", err.name, err.message);
        }
      });
    */
    return;
  } else if (attr._type === "embed") {
    var error = undefined;
    if (attr.error) {
      error = first_key(attr.error);
    }
    /*
    cas.cql("INSERT INTO embed ("+
      "time, error, conversation, site, url, req_referrer, req_host, req_http_version, req_method, req_remote_address, req_url, req_user_agent"+
      ") VALUES ("+
      "now(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?"+
      ")", [
      error || '',
      attr.id || '',
      attr.site || '*',
      attr.url || '',
      attr.req.referrer || '',
      attr.req.host,
      attr.req.http_version,
      attr.req.method,
      attr.req.remote_address,
      attr.req.url,
      attr.req.user_agent || ''
      ], function (err) {
        if (err) {
          console.error("failed to log embed: %s - %s", err.name, err.message);
        }
      });
    */
    console.log(attr);
    if (error) {
      // update_counter(cas, "err", attr.site || '*', attr.id);
    } else {
      // update_counter(cas, "ok", attr.site, attr.id);
      return; // avoid logging successful embeds to mongo
    }
  }
  col.insert(attr, function (err, res) {
    if (err) {
      console.error(err);
      process.stderr.write(data);
      return;
    }
    // no reason to pollute console output
    // process.stdout.write(data);
  });
}

/**
 * Create a closure that inserts it's argument into a collection.
 *
 * @param collection
 *        the target collection for inserting
 * @param attrs
 *        additional attributes to insert in collections
 * @return a closure of the form {@c f(x)} that when called
 *         inserts {@c x} into {@c collection}; {@c x} is parsed
 *         for possible JSON encoded objects (marked by {@c jlog.MARKER})
 *         which are insterted in the DB as-they-are (plus some
 *         required fields)
 */
function collection_inserter(collection, cas, attrs) {
  var ctx = {buffer: []};

  return function (data) {
    line = data.toString();
    now = new Date();

    attrs = _.extend({}, attrs, {"process-time": new Date()});

    while (line.length > 0) {
      currentAttr = _.clone(attrs);

      if (ctx.buffer.length > 0) {
        /* we are waiting to complete a JSON object */
        endPos = line.indexOf("}" + jlog.MARKER + "\n");
        if (endPos == -1) {
          /* not yet, push everything to buffer */
          ctx.buffer.push(line);
          line = "";
        } else {
          /* assemble the JSON from buffer (include the closing brace) */
          objStr = line.slice(0, endPos + 1);
          ctx.buffer.push(objStr);
          obj = JSON.parse(ctx.buffer.join(""));
          ctx.buffer = [];

          do_insert(collection, cas, _.extend(currentAttr, obj), objStr);
          /* 1 extra for the closing brace and 1 for the '\n' */
          line = line.slice(endPos + jlog.MARKER.length + 2);
        }
      } else {
        startPos = line.indexOf(jlog.MARKER + "{");
        if (startPos > -1) {
          prefix = line.slice(0, startPos);
          line = line.slice(startPos + jlog.MARKER.length);
          /* signal that we're processing */
          ctx.buffer.push("");
        } else {
          prefix = line;
          line = ""
        }
        if (prefix && prefix !== "\n") {
          /* something preceding the marker */
          do_insert(collection, cas, _.extend(currentAttr, {text: prefix}), prefix);
        }
      }
    }
  }
}

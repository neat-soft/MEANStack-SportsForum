print('Removing finished jobs older than one week')
var now = new Date().getTime()
  , last_week = now - (7 * 24 * 3600 * 1000)
  , last_week_id = ObjectId((Math.floor(last_week / 1000).toString(16) + "000000000000000000000000").substring(0, 24));

var result = db.jobs.remove({_id: {$lt: last_week_id}, finished: true});
print('Removed: ' + result.nRemoved.toString());
print('Remaining: ' + db.jobs.count().toString());

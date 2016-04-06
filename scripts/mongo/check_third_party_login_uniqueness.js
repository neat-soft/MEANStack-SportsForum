/* This script checks if we can add unique indexes for logins.<type>,
 * <type> can be one of 'facebook', 'google', 'twitter', 'disqus'
 */
var total_invalid = 0;
login_types = ['facebook', 'google', 'twitter', 'disqus']
for (var i = 0; i < login_types.length; i++) {
  match = {merged_into: {$exists: false}, deleted: {$ne: true}};
  match['logins.' + login_types[i]] = {$exists: true};
  results = db.users.aggregate([
    {$match: match},
    {$group: {_id: {login_type: "$logins." + login_types[i]}, count: {$sum: 1}}}
  ]).toArray();
  for (var j = 0; j < results.length; j++) {
    var r = results[j];
    if (r.count > 1) {
      printjson(r);
      total_invalid++;
    }
  }
}
if (total_invalid === 0) {
  print('Everything OK');
}
else {
  print('Found duplicates, check output!');
}

db.comments.find({type: {$in: ["CHALLENGE", "QUESTION"]}, finished: false, locked_finish: false}).forEach(function(c){
  var ends_on = c._id.getTimestamp().getTime() + 72 * 3600 * 1000;
  db.comments.update({_id: c._id}, {$set: {ends_on: ends_on}});
});

db.comments.find().forEach(function(c){
  db.comments.update({_id: c._id}, {$set: {url: c.initialUrl + "#comments/" + c._id.str}});
});

db.comments.update({type: "CHALLENGE"}, {$set: {locked_nfinish: false, notified_end: false}}, {multi: true});

db.sites.find().forEach(function(s){
  var no_conv = db.conversations.count({siteName: s.name});
  db.sites.update({_id: s._id}, {$set: {no_conversations: no_conv}});
});
db.sites.update({forum: {$exists: false}}, {$set: {forum: {enabled: true, tags: []}}}, {multi: true});
db.conversations.update({type: {$exists: false}}, {$set: {approved: true, spam: false, type: "ARTICLE"}}, {multi: true});
db.likes.find().forEach(function(l){
  var comment = db.comments.findOne({_id: l.comment});
  if (comment) {
    db.likes.update({_id: l._id}, {$set: {context: comment.context}});
  }
});
db.votes.find().forEach(function(l){
  var challenge = db.comments.findOne({_id: l.challenge});
  if (challenge) {
    db.votes.update({_id: l._id}, {$set: {context: challenge.context}});
  }
});
db.conversations.update({}, {$set: {activity_rating: 0, latest_activity: 0}}, {multi: true});
var conv_updated = 0;
db.conversations.find().forEach(function(c){
  if (c.no_all_activities === 0) {
    db.conversations.update({_id: c._id, latest_activity: 0}, {$set: {latest_activity: c.created}});
  }
  else {
    var latest_vote = db.votes.find({siteName: c.siteName, context: c._id}).sort({created: -1}).limit(1);
    if (latest_vote.hasNext())
      latest_vote = latest_vote.next()._id.getTimestamp().getTime();
    else
      latest_vote = 0;
    var latest_like = db.likes.find({siteName: c.siteName, context: c._id}).sort({created: -1}).limit(1);
    if (latest_like.hasNext())
      latest_like = latest_like.next()._id.getTimestamp().getTime();
    else
      latest_like = 0;
    var latest_comment = db.comments.find({siteName: c.siteName, context: c._id}).sort({created: -1}).limit(1);
    if (latest_comment.hasNext())
      latest_comment = latest_comment.next()._id.getTimestamp().getTime();
    else
      latest_comment = 0;
    db.conversations.update({_id: c._id, latest_activity: 0}, {$set: {latest_activity: Math.max(latest_comment, latest_like, latest_vote) || c.created}});
    conv_updated++;
    if (conv_updated % 1000 === 0) {
      print(conv_updated);
    }
  }
});
db.comments.update({contextType: {$exists: false}}, {$set: {contextType: "ARTICLE"}}, {multi: true});

db.likes.find().forEach(function(l){
  var c = db.comments.findOne({_id: l.comment});
  if (c)
    db.likes.update({_id: l._id}, {$set: {cauthor: c.author}});
});

db.votes.find().forEach(function(v){
  var c = db.challenges.findOne({_id: v.challenge});
  if (c)
    db.votes.update({_id: v._id}, {$set: {sideauthor: c[v.side].author}});
});

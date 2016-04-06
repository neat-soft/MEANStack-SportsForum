db.users.update({type: "own"}, {$unset: {serviceId: 1}}, {multi: true});
db.votes.find().forEach(function(v){
  var challenge = db.comments.findOne({_id: v.challenge});
  if (challenge.deleted) {
    db.votes.update({_id: v._id}, {$set: {challenged_author: challenge.deleted_data.challenged.author, challenger_author: challenge.deleted_data.challenger.author}});
  } 
  else {
    db.votes.update({_id: v._id}, {$set: {challenged_author: challenge.challenged.author, challenger_author: challenge.challenger.author}});
  }
});

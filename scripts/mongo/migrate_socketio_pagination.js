function getParents(comment){
  var parents = [];
  var slugParents = comment.parentSlug.split("/");
  for(var i = 0; i < slugParents.length; i++){
    if (slugParents[i])
      parents.push(ObjectId(slugParents[i]));
  }
  return parents;
}

db.comments.update({inChallenge: {$ne: true}}, {$set: {inChallenge: false}}, {multi: true})
db.comments.update({question: {$ne: true}}, {$set: {question: false}}, {multi: true})
db.comments.update({answer: {$ne: true}}, {$set: {answer: false}}, {multi: true})

db.challenges.find().forEach(function(challenge){
  db.comments.update({_id: challenge.challenged.ref}, {$set: {challenge: challenge._id}})
});

db.conversations.find().forEach(function(conversation){
  db.conversations.update({_id: conversation._id}, {$set: {slug: "/" + conversation._id.str}})
});
db.comments.find().forEach(function(comment){
  db.comments.update({_id: comment._id}, {$set: {parents: getParents(comment), slug: "/" + comment.context.str + comment.parentSlug + comment._id.str}})
  if (!comment.catParent)
    db.comments.update({_id: comment._id}, {$set: {catParent: comments.context}})
});
db.challenges.find().forEach(function(challenge){
  db.challenges.update({_id: challenge._id}, {$set: {parents: [challenge.context], slug: "/" + challenge.context.str + challenge.parentSlug + challenge._id.str}})
});

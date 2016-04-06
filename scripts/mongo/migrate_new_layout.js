function getParents(c){
  var parents = [];
  var parent = c;
  while (parent.parent) {
    var newparent = null;
    if (parent.level == 1)
      newparent = db.conversations.findOne({_id: parent.parent});
    else
      newparent = db.comments.findOne({_id: parent.parent});
    if (newparent) {
      parents.push(newparent._id);
    }
    else
      break;
    parent = newparent;
  }
  if (c.level != parents.length) {
    print("ERROR", c.type, c.level, parents.length);
  }
  parents.reverse();
  return parents;
}

db.comments.remove({deleted: true});
db.challenges.remove({deleted: true});
// db.comments.update({inChallenge: {$ne: true}}, {$set: {inChallenge: false}}, {multi: true});
// db.comments.update({question: {$ne: true}}, {$set: {question: false}}, {multi: true});
// db.comments.update({answer: {$ne: true}}, {$set: {answer: false}}, {multi: true});

db.conversations.update({}, {$set: {no_activities: 0, no_all_activities: 0, no_all_comments: 0}}, {multi: true})

db.challenges.find().forEach(function(challenge){
  db.comments.update({_id: challenge.challenged.ref}, {$set: {challengedIn: challenge._id}});
});

db.conversations.find().forEach(function(conversation){
  db.conversations.update({_id: conversation._id}, {$set: {slug: "/" + conversation._id.str}});
});

db.comments.update({question: true}, {$set: {type: "QUESTION", cat: "QUESTION"}}, {multi: true});
db.comments.update({question: false}, {$set: {type: "COMMENT", cat: "COMMENT"}}, {multi: true});
db.comments.update({answer: false, inChallenge: false}, {$set: {type: "COMMENT", cat: "COMMENT"}}, {multi: true});
db.comments.update({answer: true}, {$set: {cat: "QUESTION"}}, {multi: true});
db.comments.update({inChallenge: true}, {$set: {cat: "CHALLENGE"}}, {multi: true});

db.challenges.find().forEach(function(challenge){
  challenge.type = "CHALLENGE";
  db.comments.insert(challenge);
})
db.comments.update({type: "CHALLENGE"}, {$set: {cat: "CHALLENGE"}}, {multi: true});

db.challenges.drop();

db.comments.update({cat: "CHALLENGE"}, {$inc: {level: 1}}, {multi: true});
db.comments.update({cat: "QUESTION"}, {$inc: {level: 1}}, {multi: true});

db.comments.find().forEach(function(comment){
  var parents = getParents(comment);
  ids = []
  for (var i=0; i < parents.length; i++)
    ids.push(parents[i].str);
  var slug = "/" + ids.join("/") + "/" + comment._id.str;
  db.comments.update({_id: comment._id}, {$set: {parents: parents, slug: slug}});
  // if (!comment.catParent)
    // db.comments.update({_id: comment._id}, {$set: {catParent: comment.context}});
});
// db.challenges.find().forEach(function(challenge){
//   db.challenges.update({_id: challenge._id}, {$set: {parents: [challenge.context], slug: "/" + challenge.context.str + challenge.parentSlug + challenge._id.str}});
// });

// db.comments.find({cat: {$in: ["CHALLENGE", "QUESTION"]}, level: 4}).forEach(function(comment){
//   var toset = {$set: {
//     parent: comment.parents[2], 
//     parents: comment.parents.slice(0, comment.parents.length - 1),
//     parentSlug: "/" + comment.parents[0].str + "/" + comment.parents[1].str + "/" + comment.parents[2].str,
//     slug: "/" + comment.parents[0].str + "/" + comment.parents[1].str + "/" + comment.parents[2].str + "/" + comment._id.str
//   }};
//   db.comments.update({_id: comment._id}, toset);
// });

db.comments.find().forEach(function(comment){
  if (comment.type == "CHALLENGE")
    db.comments.update({_id: comment._id}, {$set: {rating: comment.challenger.no_votes + comment.challenged.no_votes}});
  else
    db.comments.update({_id: comment._id}, {$set: {rating: comment.no_likes}});
});

// CHANGE THE WAY COMMENTS ARE COUNTED

db.comments.find({type: "CHALLENGE"}).forEach(function(challenge){
  db.comments.update({_id: challenge._id}, {$set: {no_comments: db.comments.count({parent: challenge._id}), no_all_comments: challenge.no_comments}});
});

db.comments.find({type: "QUESTION"}).forEach(function(question){
  db.comments.update({_id: question._id}, {$set: {no_comments: db.comments.count({parent: question._id}), no_all_comments: question.no_comments}});
});

db.conversations.find().forEach(function(conversation){
  db.conversations.update({_id: conversation._id}, 
    {$set: 
      {
        no_comments: db.comments.count({type: "COMMENT", parent: conversation._id}),
        no_all_comments: db.comments.count({cat: "COMMENT", context: conversation._id}),
        no_activities: db.comments.count({parent: conversation._id}),
        no_all_activities: db.comments.count({context: conversation._id})
      }
    }
  );
});

// db.comments.find({type: "CHALLENGE"}).forEach(function(challenge){
//   db.conversations.update({_id: challenge.context}, {$inc: {no_all_activities: challenge.no_all_comments}});
// });

// db.comments.find({type: "QUESTION"}).forEach(function(question){
//   db.conversations.update({_id: question.context}, {$inc: {no_all_activities: question.no_all_comments}});
// });

// set the created field to major comments in the challenge
db.comments.find({type: "CHALLENGE"}).forEach(function(challenge){
  var challenged = db.comments.findOne({_id: challenge.challenged.ref});
  db.comments.update({_id: challenge._id}, {$set: {"challenger.created": challenge.created, "challenged.created": challenged.created}});
});

// set finished, locked_finish, locked_activity
db.comments.update({type: {$in: ["QUESTION", "CHALLENGE"]}, locked_finish: {$ne: true}}, {$set: {locked_finish: false}}, {multi: true});
db.comments.update({type: {$in: ["QUESTION", "CHALLENGE"]}, finished: {$ne: true}}, {$set: {finished: false}}, {multi: true});
db.sites.update({locked_activity: {$ne: true}}, {$set: {locked_activity: false}}, {multi: true});

// catParent is either the comment itself if level == 1 or the parent on the first level (parents[1]) otherwise
db.comments.find().forEach(function(c){
  if (c.level == 1)
    db.comments.update({_id: c._id}, {$set: {catParent: c._id}});
  else
    db.comments.update({_id: c._id}, {$set: {catParent: c.parents[1]}});
});

// challenges need to be displayed immediately before the next first level comment.
// we introduce a field "order_time"
db.comments.find().forEach(function(c){
  if (c.type === "CHALLENGE") {
    var challenged, catParent;
    if (c.deleted)
      challenged = db.comments.findOne({_id: c.deleted_data.challenged.ref});
    else
      challenged = db.comments.findOne({_id: c.challenged.ref});
    if (challenged.level === 1)
      catParent = challenged;
    else
      catParent = db.comments.findOne({_id: challenged.catParent});
    db.comments.update({_id: c._id}, {$set: {order_time: catParent.created.toString() + "1"}});
  }
  else
    db.comments.update({_id: c._id}, {$set: {order_time: c.created.toString() + "0"}});
});

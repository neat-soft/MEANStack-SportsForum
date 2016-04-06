var olduser = null; // query for old user - e.g. db.users.findOne({name: "GaryJacobson", type: "own"});
var user = null;  // query for new user - e.g. db.users.findOne({name: "Gary Jacobson", type: "facebook"});

if (olduser && user) {
  var oldprofile = db.profiles.findOne({user: olduser._id, siteName: "deepshadesofblue"});
  var profile = db.profiles.findOne({user: user._id, siteName: "deepshadesofblue"});
  if (oldprofile && profile) {
    db.profiles.update({_id: profile._id}, {$inc: {points: oldprofile.points}});
    db.profiles.update({_id: oldprofile._id}, {$set: {points: 0}});
    db.comments.update({type: "COMMENT", author: olduser._id}, {$set: {author: user._id}}, {multi:true});
    db.comments.update({type: "QUESTION", author: olduser._id}, {$set: {author: user._id}}, {multi:true});
    db.comments.update({type: "CHALLENGE", "challenger.author": olduser._id}, {$set: {"challenger.author": user._id}}, {multi:true});
    db.comments.update({type: "CHALLENGE", "challenged.author": olduser._id}, {$set: {"challenged.author": user._id}}, {multi:true});
    db.subscriptions.update({user: olduser._id}, {$set: {user: user._id}}, {multi: true});
    db.subscriptions.update({email: olduser.email}, {$set: {email: user.email}}, {multi: true});
    db.notifications.update({user: olduser._id}, {$set: {user: user._id}}, {multi: true});
    db.likes.update({user: olduser._id}, {$set: {user: user._id}}, {multi: true});
    db.votes.update({user: olduser._id}, {$set: {user: user._id}}, {multi: true});

    db.profiles.remove({_id: oldprofile._id});
    db.users.remove({_id: olduser._id});
  }
}

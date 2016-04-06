db.users.find({verified: false}).forEach(function(u){
  db.subscriptions.update({user: u._id, email: u.email}, {$set: {verified: false}}, {multi: true});
});

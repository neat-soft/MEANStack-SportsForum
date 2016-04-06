db.subscriptions.find({context: null, verified: true}).forEach(function(s){
  print(s.email);
});

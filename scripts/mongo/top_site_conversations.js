db.conversations.find({siteName:"", no_all_activities: {$gt: 0}}).sort({no_all_activities: -1}).forEach(function(c){
  print(c.initialUrl + "     " + c.no_all_activities);
});

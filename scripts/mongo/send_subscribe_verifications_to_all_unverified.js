db.subscriptions.find({verified: false, user: null}).forEach(function(s){
  var query = {
    siteName: s.siteName,
    to: s.email,
    type: "EMAIL"
  };
  var update = {
    $set: {
      siteName: s.siteName,
      to: s.email,
      type: "EMAIL",
      token: s.token,
      locked:false,
      finished:false
    }
  };
  if (s.context) {
    query.emailType = "SUBSCRIBE_CONTENT";
    update.$set.emailType = "SUBSCRIBE_CONTENT";
    update.$set.url = db.conversations.findOne(s.context).initialUrl;
  }
  else {
    query.emailType = "SUBSCRIBE_CONV";
    update.$set.emailType = "SUBSCRIBE_CONV";
  }
  db.jobs.findAndModify({
    query: query,
    update: update,
    upsert: true
  });
})

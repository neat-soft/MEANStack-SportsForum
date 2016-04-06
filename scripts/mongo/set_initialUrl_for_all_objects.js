// comment.initialUrl = conversation.url
// challenge.initialUrl = conversation.url
db.conversations.find().forEach(function(conv){
  if (!conv.initialUrl) {
    conv = db.conversations.findAndModify({
      query: {_id: conv._id},
      sort: {},
      update: {$set: {initialUrl: conv.uri}},
      new: true
    });
  }
  db.comments.update({context: conv._id}, {$set: {initialUrl: conv.initialUrl}}, {multi: true})
  db.challenges.update({context: conv._id}, {$set: {initialUrl: conv.initialUrl}}, {multi: true})
});

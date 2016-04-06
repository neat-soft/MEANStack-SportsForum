db.conversations.find().forEach(function(conv){
  if (conv.uri !== conv.initialUrl) {
    conv.initialUrl = conv.initialUrl.replace(new RegExp('/+$'), '');
    print("changing " + conv.uri + " to " + conv.initialUrl);
    db.conversations.update({_id: conv._id}, {$set: {uri: conv.initialUrl}});
  }
});

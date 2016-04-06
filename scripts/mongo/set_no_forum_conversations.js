db.sites.find().forEach(function(s) {
  var no_conv = db.conversations.count({siteName: s.name, approved: true});
  var no_forum_conv = db.conversations.count({siteName: s.name, approved: true, deleted: {$ne: true}, show_in_forum: true});
  if (s.no_conversations !== no_conv || s.no_forum_conversations !== no_forum_conv) {
    db.sites.update({name: s.name}, {$set: {no_conversations: no_conv, no_forum_conversations: no_forum_conv}});
  };
});

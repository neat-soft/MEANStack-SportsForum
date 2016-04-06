var posts = [];
db.conversations.find().forEach(function(c){
  if (c.initialUrl !== c.uri) {
    posts.push({
      _id: c._id.str,
      siteName: c.siteName,
      uri: c.uri,
      initialUrl: c.initialUrl
    });
  }
})

print("var posts = " + JSON.stringify(posts, null, 2) + ";");

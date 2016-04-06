/*
  Count conversations with no explicit id (i.e. id + "/" === initialUrl) for which there are no
  other conversations with the same initialUrl and an explicit id
*/
var count = 0;
db.conversations.find({$where: "this.uri + \"/\" === this.initialUrl"}).forEach(function(c){
  var urlnoslash = c.initialUrl.replace(new RegExp('/+$'), '');
  var same = db.conversations.count({_id: {$ne: c._id}, uri: {$ne: urlnoslash}, initialUrl: {$in: [c.initialUrl, urlnoslash]}});
  if (same === 0) {
    count++;
    print(c.initialUrl);
  }
});
print(count);

db.sites.find().sort({_id: -1}).forEach(function(site){
  var user = db.users.findOne({_id: site.user});
  var nconv = db.conversations.count({siteName: site.name});
  if (user) {
    print(site.name + ", " + site.baseUrl + ", " + nconv + ", " + user.email);
  }
});

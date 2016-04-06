print("NAME,EMAIL,SITE_NAME,DOMAIN_URL,TIMEZONE")
cursor = db.sites.find({});
cursor.batchSize(5);
cursor.forEach(function (site) {
  var user = db.users.findOne({_id: site.user});
  print('"' + user.name + '","' + user.email + '","' + site.name + '","' + (((site.urls || [])[0] || {}).base || "") + '","' + (site.tz_name || "Etc/UTC") + '"');
});
print("done");

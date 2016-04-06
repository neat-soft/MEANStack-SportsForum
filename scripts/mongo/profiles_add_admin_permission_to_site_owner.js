// add permissions object to all profiles
// db.profiles.update({}, {$set: {"permissions.admin":false, "permissions.moderator":false}}, {multi: true});

// ensure that site owners have a profile
// set admin & moderator permissions for site owners
db.sites.find().forEach(function(site){
  var profile = db.profiles.findOne({user: site.user, siteName: site.name});
  var user = db.users.findOne({_id: site.user});
  if (profile) {
    db.profiles.update({_id: profile._id}, {$set: {"permissions.admin": true, "permissions.moderator": true}});
  }
  else {
    var cdate = new Date().getTime();
    attrs = {
      points: 0,
      name: user.name,
      email: user.email,
      emailHash: user.emailHash,
      type: user.type,
      serviceId: user.serviceId,
      imageType: user.imageType,
      imageUrl: user.imageUrl,
      created: cdate,
      changed: cdate,
      user: user._id,
      siteName: site.name,
      approval: site.approvalForNew != null ? site.approvalForNew : 2,
      permissions: {admin: true, moderator: true}
    };
    db.profiles.insert(attrs);
  }
  // if(site && site.user.equals(profile.user)) {
  //   db.profiles.update({_id: profile._id}, {$set: {"permissions.admin": true, "permissions.moderator": true}});
  // }
});

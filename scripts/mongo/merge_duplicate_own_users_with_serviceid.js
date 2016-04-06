db.users.find({type: 'own', serviceId: {$exists: true}, merged_into: {$exists: false}, deleted: {$exists: false}}).forEach(function(u) {
  print(u.email + '   ' + u.verified + '   ' + u.name + '   ' + JSON.stringify(u.subscribe));
  db.users.find({type: 'own', _id: {$ne: u._id}, email: u.email, serviceId: {$exists: false}, merged_into: {$exists: false}, deleted: {$exists: false}}).forEach(function(utomerge) {
    db.jobs.insert({type: 'MERGE_USERS', from: u, into: utomerge, force_unverified: true, locked: false, finished: false})
    print('   ' + utomerge.type + '   ' + utomerge.verified + '   ' + utomerge.name + '   ' + JSON.stringify(utomerge.subscribe));
  });
});

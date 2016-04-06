db.users.update({subscribe: {$ne: null}}, {$set: {'subscribe.ignited': true}}, {multi: true});

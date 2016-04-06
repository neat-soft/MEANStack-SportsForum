db.users.update({}, {$set: {'subscribe.marketing': true}}, {multi: true});

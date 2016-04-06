db.notifications.update({read: {$exists: false}}, {$set: {read: false}}, {multi:true});

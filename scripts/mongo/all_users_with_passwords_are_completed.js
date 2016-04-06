db.users.update({password: {$exists: true}}, {$set: {completed: true}}, {multi: true})

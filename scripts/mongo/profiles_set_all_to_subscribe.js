db.users.update({}, {$set: {subscribe: {own_activity: true, auto_to_conv: true}}}, {multi: true})

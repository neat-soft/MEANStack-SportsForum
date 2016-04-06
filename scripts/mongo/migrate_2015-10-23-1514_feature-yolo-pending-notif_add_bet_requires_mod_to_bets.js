db.comments.update({type: 'BET'}, {$set: {bet_requires_mod: false}}, {multi: true})
db.comments.update({type: 'BET', bet_notif_unresolved: true}, {$set: {bet_requires_mod: true}}, {multi: true})

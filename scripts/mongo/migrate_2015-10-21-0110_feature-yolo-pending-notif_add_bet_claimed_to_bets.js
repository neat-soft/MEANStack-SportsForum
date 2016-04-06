db.comments.update({type: 'BET', bet_claimed: {$exists: false}}, {$set: {bet_claimed: []}}, {multi: true})

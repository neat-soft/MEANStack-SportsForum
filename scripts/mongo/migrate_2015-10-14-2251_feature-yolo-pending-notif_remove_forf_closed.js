db.comments.update({type: 'BET', bet_notif_unresolved: {$exists: false}}, {$set: {bet_notif_unresolved: false, bet_notif_remind_forf: false}}, {multi: true})
db.comments.update({type: 'BET', bet_status: 'forf_closed'}, {$set: {bet_status: 'forf'}}, {multi: true})

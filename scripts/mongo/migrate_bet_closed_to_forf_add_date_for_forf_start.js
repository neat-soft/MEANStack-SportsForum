db.comments.update({type: 'BET', {bet_start_forf_date: {$exists: false}}}, {$set: {bet_start_forf_date: 0}}, {multi: true});
db.comments.update({type: 'BET', bet_status: 'closed'}, {$set: {bet_status: 'forf'}}, {multi: true});

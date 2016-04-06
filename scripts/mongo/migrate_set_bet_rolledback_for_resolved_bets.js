db.comments.update({type: 'BET'}, {$set: {bet_rolledback: false}}, {multi: true});
db.comments.update({type: 'BET', bet_status: {$in: ['resolved', 'resolving_pts', 'resolved_pts']}, bet_winning_side: 'tie'}, {$set: {bet_rolledback: true}}, {multi: true});
db.comments.update({type: 'BET', bet_status: {$in: ['resolved', 'resolving_pts', 'resolved_pts']}, bet_accepted: {$size: 0}}, {$set: {bet_rolledback: true}}, {multi: true});

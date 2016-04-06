db.likes.update({}, {$set: {dir: 1}}, {multi:true});
db.votes.update({}, {$set: {dir: 1}}, {multi:true});
db.comments.update({type: "COMMENT"}, {$set: {no_likes_down: 0}}, {multi: true});
db.comments.update({type: "QUESTION"}, {$set: {no_likes_down: 0}}, {multi: true});
// db.comments.update({type: "CHALLENGE"}, {$set: {"challenged.no_votes_down": 0, "challenger.no_votes_down": 0}});

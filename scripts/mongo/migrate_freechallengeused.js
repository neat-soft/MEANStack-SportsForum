db.profiles.update({freeChallengeUsed: true}, {$set:{freeChallengeUsed: 1}}, {multi:true});
db.profiles.update({freeChallengeUsed: {$exists: false}}, {$set:{freeChallengeUsed: 0}}, {multi:true});


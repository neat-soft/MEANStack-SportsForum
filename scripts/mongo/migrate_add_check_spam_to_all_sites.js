db.sites.update({}, {$set: {checkSpam: true}}, {multi: true});

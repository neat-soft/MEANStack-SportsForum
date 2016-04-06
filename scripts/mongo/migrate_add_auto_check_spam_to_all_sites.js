db.sites.update({}, {$set: {auto_check_spam: true}}, {multi: true});

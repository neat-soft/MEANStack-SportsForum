db.sites.update({}, {$set: {conv: {forceId: false, qsDefineNew: [], useQs: false}}}, {multi: true});

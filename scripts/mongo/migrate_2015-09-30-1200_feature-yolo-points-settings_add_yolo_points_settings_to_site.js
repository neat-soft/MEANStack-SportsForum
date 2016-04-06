db.sites.update({"points_settings.min_bet": {$exists: false}}, {$set:{ "points_settings.min_bet": 25}}, {multi:true});
db.sites.update({"points_settings.min_bet_targeted": {$exists: false}}, {$set:{ "points_settings.min_bet_targeted": 25}}, {multi:true});

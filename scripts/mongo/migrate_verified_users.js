// new indexes: 
// db.users.ensureIndex({_id: 1, "subscribe.own_activity": 1, verified: 1});
// db.users.ensureIndex({_id: 1, verified: 1});
// db.subscriptions.ensureIndex({user: 1}, {sparse: true});
// db.users.ensureIndex({_id: 1, customData: 1});
// db.users.ensureIndex({vtoken: 1, verified: 1});
db.users.update({}, {$set: {verified: true}}, {multi: true});

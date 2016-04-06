/*
 * Migrate all users
 * - add subscribe.name_references field for notifications on @-mentioning
 */
db.users.update({"subscribe.name_references": {$exists: false}}, {$set: {"subscribe.name_references": true}}, {multi: true});

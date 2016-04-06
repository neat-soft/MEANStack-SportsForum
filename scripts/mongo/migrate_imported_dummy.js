/*
 * Migrate all comments
 * - add imported_dummy field with a unique value, to allow an unique index for
 *   imported comments
 */

db.comments.find({imported_dummy: {$exists: false}}).forEach(function (c) {
  c.imported_dummy = ObjectId();
  db.comments.save(c);
});

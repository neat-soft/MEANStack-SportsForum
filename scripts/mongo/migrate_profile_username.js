/*
 * Migrate the profiles collection:
 * - add userName field to each profile
 */

db.users.find().forEach(function (user) {
  db.profiles.update({user: user._id},
    {
      $set: {
        userName: user.name
      }
    }
  );
});

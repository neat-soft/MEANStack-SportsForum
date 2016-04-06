db.runCommand({dropIndexes: "comments", index: "*" });
db.comments.ensureIndex({"challenged.ref": 1}, {unique: true, sparse: true});
db.comments.ensureIndex({_id: 1, changed: 1});
db.comments.ensureIndex({catParent: 1, cat: 1, level: 1, approved: 1, deleted: 1, rating: -1});
db.comments.ensureIndex({_id: 1, flags: 1, no_flags: 1});
db.comments.ensureIndex({_id: 1, approved: 1, deleted: 1});
db.comments.ensureIndex({siteName: 1, approved: 1, deleted: 1, no_flags: 1});
db.comments.ensureIndex({siteName: 1, approved: 1, deleted: 1, author: 1, _id: 1});
db.comments.ensureIndex({context: 1, approved: 1, slug: 1});
db.comments.ensureIndex({context: 1, parents: 1, approved: 1, slug: 1});
db.comments.ensureIndex({context: 1, level: 1, approved: 1, slug: 1, _id: 1});
db.comments.ensureIndex({context: 1, level: 1, approved: 1, order_time: 1, _id: 1}); //for ordering challenges by order_time
db.comments.ensureIndex({context: 1, level: 1, approved: 1, rating: -1, _id: 1});
db.comments.ensureIndex({context: 1, level: 1, approved: 1, no_comments: -1, _id: 1});
db.comments.ensureIndex({type: 1, ends_on: -1, approved: 1, deleted: 1, locked_finish: 1, finished: 1, locked_nfinish: 1, notified_end: 1});

db.comments.ensureIndex({siteName: 1, approved: 1, _id: 1});
db.comments.ensureIndex({siteName: 1, _id: 1});
db.comments.ensureIndex({siteName: 1, context: 1, approved: 1});
db.comments.ensureIndex({siteName: 1, deleted: 1, approved: 1, _id: 1});
db.comments.ensureIndex({siteName: 1, deleted: 1, no_flags: 1, _id: 1});
db.comments.ensureIndex({siteName: 1, context: 1, _id: 1});
db.comments.ensureIndex({context: 1, deleted: 1, approved: 1, promote: 1, promotePoints: -1, _id: 1});

// Bets
db.comments.ensureIndex({type: 1, bet_status: 1, bet_end_date: 1});
db.comments.ensureIndex({type: 1, bet_status: 1, bet_closed_at: 1});
db.comments.ensureIndex({type: 1, bet_status: 1, bet_forf_started_at: 1, bet_notif_unresolved: 1});
db.comments.ensureIndex({type: 1, bet_status: 1, bet_requires_mod: 1, bet_notif_unresolved: 1});
db.comments.ensureIndex({type: 1, bet_status: 1, bet_start_forf_date: 1});
db.comments.ensureIndex({siteName: 1, type: 1, bet_status: 1, bet_rolledback: 1, deleted: 1, approved: 1, _id: 1});
db.comments.ensureIndex({siteName: 1, type: 1, bet_rolledback: 1, deleted: 1, approved: 1, _id: 1});

db.comments.ensureIndex({imported_from: 1, imported_id: 1, imported_dummy: 1, context: 1}, {unique: true}); // for imported comments, avoid dup

// Trusted
db.comments.ensureIndex({"challenge.author": 1, siteName: 1, deleted: 1, approved: 1})
db.comments.ensureIndex({author: 1, siteName: 1, deleted: 1, approved: 1, type: 1})

// Merging
db.comments.ensureIndex({"guest.email": 1});
db.comments.ensureIndex({"challenged.guest.email": 1, "challenger.author": 1});
db.comments.ensureIndex({"answer.guest.email": 1});
db.comments.ensureIndex({author: 1});
db.comments.ensureIndex({"challenged.author": 1, "challenger.author": 1});
db.comments.ensureIndex({"answer.author": 1});

db.runCommand({dropIndexes: "conversations", index: "*" });
db.conversations.ensureIndex({siteName: 1, uri: 1}, {unique: true});
db.conversations.ensureIndex({siteName: 1, _id: 1});
db.conversations.ensureIndex({_id: 1, changed: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, latest_activity: -1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, activity_rating: -1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, no_all_activities: -1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, tags: 1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, tags: 1, latest_activity: -1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, tags: 1, activity_rating: -1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({siteName: 1, approved: 1, tags: 1, no_all_activities: -1, show_in_forum: 1, _id: 1});
db.conversations.ensureIndex({latest_activity: 1});

// this index is used in the following situations:
// - when fetching forum threads ordered by most activity 24h (activity_rating), latest_activity and _id at the same time
db.conversations.ensureIndex({siteName: 1, approved: 1, deleted: 1, show_in_forum: 1, activity_rating: -1, latest_activity: -1, _id: -1}, {name: 'conv_sn_1_appr_1_del_1_sif_1_actrat_-1_lat_-1__id_-1'});
db.conversations.ensureIndex({siteName: 1, approved: 1, deleted: 1, show_in_forum: 1, tags: 1, activity_rating: -1, latest_activity: -1, _id: -1}, {name: 'conv_sn_1_appr_1_del_1_sif_1_tag_1_actrat_-1_lat_-1__id_-1'});

db.runCommand({dropIndexes: "likes", index: "*" });
db.likes.ensureIndex({comment: 1, user: 1, session: 1}, {unique: true});
db.likes.ensureIndex({siteName: 1, context: 1, _id: 1});

//Trusted
db.likes.ensureIndex({cauthor: 1, siteName: 1, dir: 1})

// Merging
db.likes.ensureIndex({"cguest.email": 1, user: 1});
db.likes.ensureIndex({user: 1, cauthor: 1});

db.runCommand({dropIndexes: "votes", index: "*" });
db.votes.ensureIndex({challenge: 1, user: 1, session: 1}, {unique: true});
db.votes.ensureIndex({_id: 1, side: 1});
db.votes.ensureIndex({siteName: 1, context: 1, _id: 1});

//Merging
db.votes.ensureIndex({"challenged_guest.email": 1, "challenger_author": 1});
db.votes.ensureIndex({user: 1, "challenger_author": 1, "challenged_author": 1});

db.shares.ensureIndex({user: 1, context: 1});

db.runCommand({dropIndexes: "users", index: "*" });
db.users.ensureIndex({email: 1, type: 1, site: 1, serviceId: 1}, {unique: true}); // When deploying users unification
db.users.ensureIndex({pwreset: 1}, {unique: true, sparse: true});
db.users.ensureIndex({_id: 1, "subscribe.own_activity": 1, verified: 1});
db.users.ensureIndex({_id: 1, customData: 1});
db.users.ensureIndex({_id: 1, verified: 1});
db.users.ensureIndex({vtoken: 1, verified: 1});
db.users.ensureIndex({verified_time: 1});

// Merging
db.users.ensureIndex({_id: 1, deleted: 1});
db.users.ensureIndex({type: 1, email: 1, deleted: 1, merged_into: 1});
db.users.ensureIndex({type: 1, serviceId: 1, deleted: 1, _id: 1});

// these indexes are only used when logging in and to prevent attaching of
// the same third-party profile to multiple accounts
// notice the sparse option, don't use them to get an exhaustive list of users!
db.users.ensureIndex({"logins.facebook": 1}, {unique: true, sparse: true});
db.users.ensureIndex({"logins.twitter": 1}, {unique: true, sparse: true});
db.users.ensureIndex({"logins.google": 1}, {unique: true, sparse: true});
db.users.ensureIndex({"logins.disqus": 1}, {unique: true, sparse: true});

db.runCommand({dropIndexes: "profiles", index: "*" });
db.profiles.ensureIndex({user: 1, siteName: 1}, {unique: true, sparse: true});
db.profiles.ensureIndex({siteName: 1, "permissions.admin": 1, "permissions.moderator": 1, merged_into: 1, points: -1});
db.profiles.ensureIndex({siteName: 1, _id: 1});
db.profiles.ensureIndex({siteName: 1, merged_into: 1, userName: 1}); // for query-ing mentions with/without regex on userName
db.profiles.ensureIndex({user: 1, "permissions.moderator": 1});
// db.profiles.ensureIndex({user: 1, siteName: 1, points: -1}); // for losing points when challenging
db.profiles.ensureIndex({user: 1, "benefits.signature.expiration": 1}); // for listing benefits for all sites in profile page

// Merging
db.profiles.ensureIndex({user: 1, deleted: 1});

// free challenge
db.profiles.ensureIndex({user: 1, siteName: 1, freeChallengeUsed: 1})

db.runCommand({dropIndexes: "convprofiles", index: "*" });
db.convprofiles.ensureIndex({user: 1, context: 1}, {unique: true, sparse: true});
db.convprofiles.ensureIndex({context: 1, merged_into: 1, points: -1});

// Merging
db.convprofiles.ensureIndex({user: 1, deleted: 1});

db.competition_profiles.ensureIndex({competition: 1, user: 1});
db.competition_profiles.ensureIndex({competition: 1, merged_into: 1, points: -1});
//
// Merging
db.competition_profiles.ensureIndex({user: 1, deleted: 1});

db.runCommand({dropIndexes: "sites", index: "*" });
db.sites.ensureIndex({name: 1}, {unique: true});
db.sites.ensureIndex({user: 1});
db.sites.ensureIndex({name: 1, locked_activity: 1});
db.sites.ensureIndex({created: 1});//used for sendMarketingEmail
db.sites.ensureIndex({"premium.subscription.id": 1});

db.runCommand({dropIndexes: "jobs", index: "*" });
db.jobs.ensureIndex({type: 1, locked: 1, finished: 1, siteName: 1});
db.jobs.ensureIndex({locked: 1, finished: 1, _id: 1});
db.jobs.ensureIndex({locked: 1, finished: 1, _id: 1, start_after: 1});
db.jobs.ensureIndex({uid: 1}, {unique: true, sparse: true});

db.runCommand({dropIndexes: "sessions", index: "*" });
db.sessions.ensureIndex({expires: 1}, {expireAfterSeconds: 5184000, background: true});

db.runCommand({dropIndexes: "subscriptions", index: "*" });
db.subscriptions.ensureIndex({siteName: 1, email: 1, context: 1}, {unique: true});
db.subscriptions.ensureIndex({siteName: 1, email: 1, context: 1, verified: 1, active: 1});
db.subscriptions.ensureIndex({token: 1});
db.subscriptions.ensureIndex({siteName: 1, context: 1, verified: 1, active: 1});
db.subscriptions.ensureIndex({user: 1, email: 1});
db.subscriptions.ensureIndex({_id: 1, context: 1});

db.runCommand({dropIndexes: "notifications", index: "*" });
db.notifications.ensureIndex({user: 1, _id: -1});
db.notifications.ensureIndex({user: 1, read: 1, _id: 1});

db.competitions.ensureIndex({site: 1, start: 1, end: 1});

// required by badge update job
db.transactions.ensureIndex({siteName: 1, type: 1, profile_created: 1, user_verified: 1, _id: 1});

db.badges.ensureIndex({siteName: 1});
db.badges.ensureIndex({siteName: 1, user: 1});
db.badges.ensureIndex({global: 1, user: 1});
db.badges.ensureIndex({gold: 1, user: 1});
db.badges.ensureIndex({siteName: 1, user: 1, badge_id: 1}, {unique: true});
db.badges.ensureIndex({siteName: 1, badge_id: 1});
db.badges.ensureIndex({siteName: 1, badge_id: 1, value: 1});
db.badges.ensureIndex({siteName: 1, badge_id: 1, value: 1, rank: 1});

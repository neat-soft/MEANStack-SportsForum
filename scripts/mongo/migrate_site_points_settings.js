db.sites.update({points_settings: {$exists: false}},
{$set:{
  points_settings: {
    status_comment: "unverified",
    status_leaderboard: "verified",
    status_downvote: "trusted",
    status_upvote: "verified",
    status_flag: "trusted",
    for_comment: 0,
    free_challenge_count: 1,
    for_challenge_winner: 10,
    for_share: 3,
    disable_upvote_points: false,
    disable_downvote_points: true,
    ignite_create_thread: false
  }
}}, {multi:true});


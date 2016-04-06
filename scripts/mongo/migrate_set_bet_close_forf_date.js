var forf_period = 14 * 24 * 3600 * 1000;
db.comments.find({type: 'BET'}).forEach(function(bet){
  db.comments.update({_id: bet._id}, {$set: {bet_close_forf_date: bet.bet_forf_started_at + forf_period}});
});

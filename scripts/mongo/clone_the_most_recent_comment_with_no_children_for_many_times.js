var c = db.comments.find({siteName: 'test', deleted: {$ne: true}, type: "COMMENT", approved: true, level: 1, no_comments: 0}).sort({_id:-1})[0];
printjson(c);
delete c._id;
var to_add = 1000;
var cdate = new Date().getTime();
var items_to_add = [];
for (var i = 0; i < to_add; i++) {
  var new_c = c;
  new_c.created = cdate;
  new_c.changed = cdate;
  new_c.order_time = cdate.toString() + '0';
  new_c.imported_dummy = new ObjectId();
  items_to_add.push(new_c);
  cdate += 50;
  db.comments.insert(new_c);
}
// db.comments.insert(items_to_add, {writeConcern: {w: 1}, ordered: true});
db.conversations.update({_id:c.context}, {$inc: {no_activities: to_add, no_all_activities: to_add, no_all_comments: to_add, no_comments: to_add}});

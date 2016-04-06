db.conversations.update({show_in_forum: {$exists: false}}, {$set: {show_in_forum: true}}, {multi:true})

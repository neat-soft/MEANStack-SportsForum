// Counts the number of conversations where url = uri + "/" to see how many were created
// since the we took out the id

db.conversations.count({$where: "this.uri + \"/\" === this.initialUrl"});
var cols = db.getCollectionNames()
  , date = new Date()
  , year = date.getFullYear().toString()
  , month = ("00" + (date.getMonth() + 1).toString()).slice(-2)
  , day = ("00" + date.getDate().toString()).slice(-2);

for (var i = 0; i < cols.length; i++) {
  if (/^_tmp_/.test(cols[i]) || (/^like_status_/.test(cols[i]) && !(new RegExp("^like_status_" + year + "_" + month + "_" + day).test(cols[i])))) {
    print(cols[i]);
    db.getCollection(cols[i]).drop();
  }
}

/*
 * Migrate the sites collection:
 * - replace single 'baseUrl' with 'urls' list
 * - drop 'baseUrl' field
 */

db.sites.find().forEach(function (site) {
  if (!site.baseUrl) {
    return;
  }
  if (site.urls) {
    return;
  }

  var pb = site.baseUrl.split("://", 2);
  var p = pb[0], b = pb[1];
  var s = false;
  if (!b) {
    return;
  }
  if (b.startsWith("([a")) {
    s = true;
    b = b.split(".)?")[1];
  }

  print("site = " + site.baseUrl);
  print("p = " + p + " b = " + b + " s = " + s);

  db.sites.update({name: site.name},
    {
      $set: {
        urls: [{protocol: p, base: b, subdomains: s}]
      }
      // Let's delete it after the migration
      //,
      // $unset: {
      //   baseUrl: 1
      // }
    }
  );
});


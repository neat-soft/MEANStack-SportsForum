module.exports = function(done) {
  /*
   * We start a dummy server to keep monit happy (it checks for 200 OK on http)
   */
  http = require('http')

  srv = http.createServer(function (req, res) {
    res.end("OK");
  });

  srv.listen(this.port || 80);
  process.nextTick(done);
}

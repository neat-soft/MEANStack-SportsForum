util = require("../util")
fs = require("fs")
path = require("path")

module.exports = (done)->
  @app.statics = {}
  location = path.normalize(__dirname + "/../static")
  util.walk(location, util.wrapError(done, (files)=>
    for file in files
      content = fs.readFileSync(file)
      file = _.str.strRight(file, location)
      @app.statics[file] = util.md5HashB(content)
    done?()
  ))

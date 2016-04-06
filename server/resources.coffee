path = require("path")
fs = require("fs")
async = require("async")
archiver = require("archiver")
AWS = require("aws-sdk")
config = require("naboo").config
util = require("./util")

wppluginfiles = []

wpPluginFiles = (cb)->

  if wppluginfiles.length > 0
    process.nextTick(-> cb(null, wppluginfiles))
  else
    util.walk("../plugins/wordpress/conversait", (err, files)->
      if err then return cb(err)
      wppluginfiles = _.map(files, (file)-> return path.relative("../plugins/wordpress/conversait", file))
      cb(null, wppluginfiles)
    )

module.exports =

  compactPolicyHeader: _.once(->
    try
      return fs.readFileSync("./static/w3c/compact_policy", "utf-8").replace("\n", "")
    catch err
      return ""
  )

  embedScript: _.once(->
    try
      return fs.readFileSync(path.join(".", "..", "plugins/generic/embed_script"), "utf-8")
    catch error
      return ""
  )

  embedScriptCore: _.once(->
    try
      return fs.readFileSync(path.join(".", "..", "plugins/generic/embed_script_core"), "utf-8")
    catch error
      return ""
  )

  embedScriptTypepad: _.once(->
    try
      return fs.readFileSync(path.join(".", "..", "plugins/generic/embed_script_typepad"), "utf-8")
    catch error
      return ""
  )

  bloggerPlugin: _.once(->
    try
      return fs.readFileSync(path.join(".", "..", "plugins/blogger/widget.xml"), "utf-8")
    catch error
      return ""
  )

  vbPlugin: _.once(->
    try
      return fs.readFileSync(path.join(".", "..", "plugins/vbulletin/product-burnzone.xml"), "utf-8")
    catch error
      return ""
  )

  buildBloggerPlugin: (siteName)->
    return @bloggerPlugin()
      .replace(/\{\{\{sitename\}\}\}/g, if siteName then siteName else "")
      .replace(/\"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")

  buildEmbedScript: (siteName)->
    return @embedScript().replace("{{{sitename}}}", if siteName then siteName else "<put your site name here>")

  buildEmbedScriptCore: (siteName)->
    return @embedScriptCore().replace("{{{sitename}}}", if siteName? then siteName else "<put your site name here>")

  buildEmbedScriptTypepad: (siteName)->
    return @embedScriptTypepad().replace("{{{sitename}}}", if siteName then siteName else "<put your site name here>")

  archiveWpPlugin: (site, callback)->
    buffers = []
    archive = archiver.createZip()
    archive.on('data', (data)->
      buffers.push(data)
    )
    async.waterfall([
      (cb)->
        wpPluginFiles(cb)
      (files, cb)->
        files = _.filter(files, (file)-> file.indexOf("_") != 0)
        files.push("site.php")
        async.forEachSeries(files, (file, next)->
          if file == "site.php"
            data = "<?php\n  $conv_site_name_default = '#{site.name}';"
            data += "\n  $conv_sso_key_default = '#{site.sso.secret}';\n?>"
            archive.addFile(new Buffer(data), { name: file }, (err)->
              next(err)
            )
          else
            stream = fs.createReadStream(path.join("../plugins/wordpress/conversait", file))
            archive.addFile(stream, { name: file }, (err)->
              next(err)
            )
        , (err)->
            if err
              cb(err)
            else
              archive.finalize((err, written)->
                cb(err)
              )
        )
    ], (err, result)->
      if err
        callback(err)
      else
        buffer = Buffer.concat(buffers)
        callback(err, buffer)
    )

  generatePluginFN: (type, version, site)->
    return site._id.toHexString() + "/#{type}_#{version}_#{site.name}.zip"

  buildWpPluginS3: (site, callback)->
    AWS.config.update(config["aws.auth"])
    version = config["plugins.wordpress.v"]
    key = config["aws.keypref_plugins"] + @generatePluginFN("wordpress", config["plugins.wordpress.v"], site)
    s3 = new AWS.S3()
    async.waterfall([
      (cb)->
        s3.client.headObject({Bucket: config["aws.bucket"], Key: key}, (err, data)->
          if err
            if err.statusCode == 404
              cb()
            else
              cb(err)
          else
            callback(null, key)
        )
      (cb)=>
        @archiveWpPlugin(site, cb)
      (content, cb)->
        s3.client.putObject({Bucket: config["aws.bucket"], Key: key, Body: content}, cb)
    ], (err, result)->
      callback(err, key)
    )

  buildWpPlugin: (site, callback)->
    version = config["plugins.wordpress.v"]
    filePath = path.join(config.cachePath, "wordpress_#{version}_#{site.name}.zip")
    fs.exists(filePath, (exists)=>
      if exists
        return callback(null, filePath)
      else
        @archiveWpPlugin(site, (err, content)->
          if (err)
            fs.unlink(filePath, ->
              callback(err)
            )
          else
            fs.writeFile(filePath, content, (err)->
              callback(err, filePath)
            )
        )
    )

  buildVbPlugin: (site, callback)->
    plugin = @vbPlugin()
      .replace(/\{\{\{sitename\}\}\}/g, if site then site.name else "")
      .replace(/\{\{\{ssokey\}\}\}/g, if site then site.sso.secret else "")
    if !plugin
      return callback(new Error('could not find vb plugin'), null)
    callback(null, plugin)

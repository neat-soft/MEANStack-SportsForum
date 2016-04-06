collections = require("../datastore").collections
templates = require("../templates")
dbutil = require("../datastore/util")
async = require("async")
debug = require("debug")("resolver")

module.exports = (app)->

  app.get("/go/:item", (req, res)->
    the_conv = null
    the_comment = null
    the_site = null
    async.waterfall([
      (cb)->
        async.waterfall([
          (cbs)->
            collections.comments.findOne({_id: dbutil.idFrom(req.params["item"]), approved: true, deleted: {$ne: true}}, cbs)
          (comment, cbs)->
            if comment
              the_comment = comment
              collections.conversations.findOne({_id: comment.context, approved: true, deleted: {$ne: true}}, cbs)
            else
              collections.conversations.findOne({_id: dbutil.idFrom(req.params["item"]), approved: true, deleted: {$ne: true}}, cbs)
        ], cb)
      (conv, cb)->
        if conv
          the_conv = conv
        if the_comment
          if the_conv.type == "ARTICLE"
            debug("item is comment, redirecting to article page")
            return res.redirect(conv.initialUrl + "#brzn/comments/#{the_comment._id.toHexString()}")
          else
            # comment in forum, get url of forums
            debug("item is comment in forum, fetch site to get url of forums")
            collections.sites.findOne({name: conv.siteName}, cb)
        else if the_conv
          if the_conv.type == "ARTICLE"
            debug("item is article, redirecting to article page")
            return res.redirect(conv.initialUrl)
          else
            debug("item is forum topic, fetch site to get url of forums")
            collections.sites.findOne({name: conv.siteName}, cb)
        else
          return templates.render(res, "marketing/error", {error: "The comment or conversation could not be found"})
      (site, cb)->
        if !site
          return templates.render(res, "marketing/error", {error: "The comment or conversation could not be found"})
        if the_comment
          debug("redirect to comment in forum")
          res.redirect(site.forum.url + "#brzn/contexts/#{the_conv._id.toHexString()}/comments/#{the_comment._id.toHexString()}")
        else
          debug("redirect to forum topic")
          res.redirect(site.forum.url + "#brzn/contexts/#{the_conv._id.toHexString()}")
    ], (err, cb)->
      templates.render(res, "marketing/error", {error: "There was an error accessing the server"})
    )
  )

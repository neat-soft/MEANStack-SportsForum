config = require("naboo").config

module.exports.for_model = (type, model, options = {})->
  options.route_server ?= true
  if options.route_server
    return "#{config.serverHost}/go/#{model._id.toHexString()}"
  if type == "conversation"
    if model.type == "ARTICLE"
      return model.initialUrl
    else if options.site?.forum.url
      return "#{options.site.forum.url}#brzn/contexts/#{model._id.toHexString()}"
    else if model.initialUrl
      return "#{model.initialUrl}#brzn/contexts/#{model._id.toHexString()}"
    else
      return "#{config.serverHost}/go/#{model._id.toHexString()}"
  else if type == "comment"
    if model.contextType == "ARTICLE"
      return "#{model.initialUrl}#brzn/comments/#{model._id.toHexString()}"
    else if options.site?.forum.url
      return "#{options.site.forum.url}#brzn/contexts/#{model.context.toHexString()}/comments/#{model._id.toHexString()}"
    else if model.initialUrl
      return "#{model.initialUrl}#brzn/contexts/#{model.context.toHexString()}/comments/#{model._id.toHexString()}"
    else
      return "#{config.serverHost}/go/#{model._id.toHexString()}"
  else
    return "#{config.serverHost}/go/#{model._id.toHexString()}"

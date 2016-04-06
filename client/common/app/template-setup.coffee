require("lib/shared/templates")
util = require("lib/shared/util")

Handlebars.registerHelper("url", (context)->
  return encodeURIComponent(window.location.href)
)

get_avatar_id = _.memoize(
    (user, avatars)->
      return util.hashString(user._id || user.name) % avatars.length
    ,
    (user)->
      return user._id || user.name
  )

pick_avatar = (user, avatars)->
  return avatars[get_avatar_id(user, avatars)]

Handlebars.registerHelper("avatar", (context)->
  if !context
    return util.resource("/img/avatar.png")
  if context.imageType == "custom"
    return context.imageUrl
  if context.imageType == "facebook" && context.logins?.facebook
    return "https://graph.facebook.com/#{context.logins.facebook}/picture"
  if context.imageType == "disqus" && context.logins?.disqus && context.logins_usernames?["disqus"]
    return "https://disqus.com/api/users/avatars/#{context.logins_usernames["disqus"]}.jpg"
  if context.imageType == "gravatar" || !context.imageType?
    if window.app.api?.site
      avatars = window.app.api.site.get("avatars") || []
    else
      avatars = window.app.options.avatars || []
    gravatar_base = "http://www.gravatar.com/avatar/#{context.emailHash}?s=50&d="
    if avatars.length
      if !context._id && !context.name
        return gravatar_base + encodeURIComponent(avatars[avatars.length - 1])
      return gravatar_base + encodeURIComponent(pick_avatar(context, avatars))
    else
      return gravatar_base + encodeURIComponent(util.resource("/img/default_avatar.png"))
  return util.resource("/img/default_avatar.png")
)

Handlebars.registerHelper("avatarProfileLink", (context)->
  return "http://www.gravatar.com/#{context.emailHash}"
)

Handlebars.registerHelper("global", (context)->
  return window[context]
)

Handlebars.registerHelper("notificon", (context)->
  switch context
    when "error" then return '<i class="icon-exclamation-sign"></i>'
    when "success" then return '<i class="icon-ok"></i>'
    else
      return '<i class="icon-info-sign"></i>'
)

Handlebars.registerHelper("color", (text)->
  hash = 0
  for i in [0...text.length]
    hash = text.charCodeAt(i++) + ((hash << 5) - hash)
  color = "#"
  for i in [0...3]
    color += ("00" + ((hash >> i++ * 8) & 0xFF).toString(16)).slice(-2)
  return color
)

Handlebars.registerHelper("colorgray", (text)->
  hash = 0
  for i in [0...text.length]
    hash = text.charCodeAt(i++) + ((hash << 5) - hash)
  channel = ("00" + Math.min((hash >> i++ * 8) & 0xFF, 200).toString(16)).slice(-2)
  color = "##{channel}#{channel}#{channel}"
  return color
)

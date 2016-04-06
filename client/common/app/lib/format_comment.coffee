AttributeView = require("views/attribute_view")
User = require("models/user")

blacklist = []

module.exports.applyOembed = ($text, after)->
  twitterrgx = new RegExp("^https?://twitter.com/[a-zA-Z0-9_-]+/status/[0-9]+")
  $text.find('a').not(".user-ref").each((index, element)->
    $anchor = $(element)
    url = $anchor.attr('href')
    twittermatch = $anchor.attr('href').match(twitterrgx)
    if twittermatch
      url = twittermatch[0] #manually reassign twitter status urls to the correct embedding url
    if $anchor.text().trim() != ""
      oembed = true
      for reg in blacklist
        if url.match(reg)
          oembed = false
          break
      if oembed
        $anchor.oembed(url, {includeHandle: false, afterEmbed: after, apikeys: {}}, null, $text, index)
    )

module.exports.replaceImageLinks = (text)->
  if !text.match(/!?(\[.*\]\(.*\))/ig) #if no markdown links detected in text
    text = text.replace(/(https?:\/\/[^\s]*\.(?:png|jpg|jpeg|gif))/ig, '![image]($&)') # replace all image urls with markdown image code
  return text

# given a HTML chunk containing user references created by the startCompletion
# method, return a plain text with all user references replaced by @uid
module.exports.replaceUserRefs = (text)->
  userRefs = []
  re = /<span\b[^>]+>[^<]+<\/span>/g
  for sp in text.match(re) || []
    if sp.match(/\bclass=["']user-ref["']/)
      uid = sp.match(/\bdata-uid=["']([^"']{24})["']/)?[1]
      name = sp.match(/<span[^>]+>([^<]+)<\/span>/)[1]
      text = text.replace(sp, "@#{uid};#{name};")
  # replace divs with breaks
  text = text.replace(/<div>(.+?)<\/div>/gm, "\n$1")
  # replace breaks with newlines
  text = text.replace(/<br>/gm, "\n")
  # kill all tags
  text = text.replace(/<[^>]+>/gm, "")
  # don't allow more than 2 newlines
  text = text.replace(/\n[\n]+/gm, "\n\n")
  return text


module.exports.startCompletion = (selector, app)->
  selector[0].onpaste = (origin, ev)->
    # defer an update of the editable comment area: leave only text and user mentions
    setTimeout(->
      text = app.api.textToUserRefs(selector.html())
      html = app.api.textToHtml(text)
      selector.html(html)
    , 1)

  if !selector.hasClass("completion-started")
    selector.textcomplete([{
      match: /\B@([\-+\w ]*)$/i
      search: (term, callback)=>
        if term.split(" ").length > 2
          return callback([])
        vals = []
        app.api.site.get("filtered_profiles").fetch({
          reset: true
          restart: true
          add: true
          merge: true
          remove: false
          success: (collection)->
            callback(collection.models)
          error: ->
            callback([])
          data:
            paged: true
            full: true
            moderator: false
            s: term
        })
      template: (profile)->
        return profile.get("userName")
      replace: (profile)->
        uid = profile.get("user")
        if uid.id
          uid = uid.id
        # use 'span' instead of 'a' to avoid triggering navigation on clicks while editing
        return "<span class='user-ref' contenteditable='false' data-uid='#{uid}' href='#brzn/users/#{uid}'>#{profile.get("userName")}</span>"
      index: 1,
      maxCount: 10
    }])
    selector.addClass("completion-started")

module.exports.stopCompletion = (selector)->
  if selector.hasClass("completion-started")
    selector.textcomplete('destroy')


module.exports.formatMentionsForDisplay = (owner, selector)->
  for span in selector.find("a.user-ref")
    uid = $(span).attr("data-uid")
    mention = owner.app.api.store.models.get(uid)
    if !mention
      mention = new User({_id: uid})
    owner.addView(new AttributeView(model: mention, attribute: "name", className: "user-ref", el: span))

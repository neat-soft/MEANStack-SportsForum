async = require("async")
collections = require("./datastore").collections
util = require("./util")
marked = require("marked")
logger = require("./logging").logger

marked.setOptions({
  gfm: true,
  tables: true,
  breaks: false,
  pedantic: false,
  sanitize: true,
  smartLists: true
})

defaultBadWords = [
  'shit'
  'piss'
  'fuck'
  'cunt'
  'cocksucker'
  'motherfucker'
  'tits'
  'ass'
  'asshole'
]

module.exports = class ContentFilter
  constructor: (word_list)->
    word_list = _.union(word_list || [], [])
    badWordsSpaced = (word.split('').join('\\s*') for word in word_list)
    # sanitize
    badWordsSpaced = (word.replace(/[#-.]|[[-^]|[?|{}]/g, '\\$&') for word in word_list)
    badWordsSpaced.unshift("\b")
    @badWordsRegexp = new RegExp(badWordsSpaced.join("\\b|\\b"), "gi")

  filterBadWords: (text)->
    return text.replace(@badWordsRegexp, '[...]')

  containsBadWords: (text)->
    return @badWordsRegexp.test(text)

  filterCommentText: (text)->
    return _.str.truncate(@filterBadWords(text), util.getValue("maxCommentLength"))

  extractUserRefs: (text)->
    userRefs = []
    re = /\B@([0-9a-f]{24})\b(;([^;]+);)?/g
    for user in text.match(re) || []
      [junk, uid, junk2, name] = user.match(/\B@([0-9a-f]{24})\b(;([^;]+);)?/)
      userRefs.push([user, uid, name])
    return userRefs

  formatPlain: (text, options, callback)->
    if typeof(options) == 'function'
      callback = options
      options = {}
    @formatAll(text, options, (err, text, html)->
      callback(err, text)
    )

  formatHtml: (text, callback)->
    if typeof(options) == 'function'
      callback = options
      options = {}
    @formatAll(text, options, (err, text, html)->
      callback(err, html)
    )

  formatAll: (text, options, callback)->
    if typeof(options) == 'function'
      callback = options
      options = {}
    html = text
    refs = @extractUserRefs(text)
    async.map(refs, (ref, cb)->
      collections.users.findOne({_id: ref[1]}, (err, user)->
        if user
          ref[2] = user.name
        cb(err, ref)
      )
    , (err, results)->
      for ref in results
        text = text.replace(ref[0], "#{if options.noPlainAt then "" else "@"}#{ref[2] || ref[1]}")
        html = html.replace(ref[0], "#{if options.includeAt then "@" else ""}<span class='user-ref'>#{ref[2] || ref[1]}</span>")
      callback(err, text, html)
    )


  processCommentText: (text)->
    try
      m = marked(text)
      # markdown leaves a \n between paragraphs, don't replace that with <br>
      m = m.replace(/([^>])\n([^<])/gm, "$1<br>$2")
      # markdown leaves a \n at the end of the string, remove it
      m = m.replace(/\n+$/, '')
      return m
    catch e
      logger.error(e)
      return null

  filterChallengeSummary: (text)->
    return _.str.truncate(@filterBadWords(text), util.getValue("maxChallengeSummaryLength"))

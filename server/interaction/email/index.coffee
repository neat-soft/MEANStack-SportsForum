module.exports = (app)->

  async = require('async')
  util = require('../../util')
  config = require('naboo').config
  logger = require("../../logging").logger
  debug = require('debug')('reply_by_email')
  inspect = require('util').inspect
  collections = require("../../datastore").collections
  handlers = require("../handlers")
  email_reply_parser = require('emailreplyparser').EmailReplyParser
  build_reply_to = require("../../email").build_reply_to

  parse_user_reply = (email_text, email_html)->
    if email_text
      # Using a variant of Github's library for Node: https://github.com/timhaines/emailreplyparser
      # the general convention is to start quoting with '>', so we find the first line that starts with > and take all the text before that
      # some email clients add a quoted header (e.g. 'On 2012-02-02, gigi wrote:'). This can be written in
      # any language, but this library only supports English.
      # TODO improve detection
      return email_reply_parser.parse_reply(email_text)
    else
      return ''

  parse_moderator_action = (email_text)->
    lines = email_text.split('\n')
    for line in lines
      line = _.str.trim(line).toLowerCase()
      if line
        return line
    return null

  user_site_profile = (user_id, site_name, callback)->
    user = null
    site = null
    profile = null
    async.waterfall([
      (cbs)->
        async.parallel({
          site: (cbp)->
            collections.sites.findOne({name: site_name}, cbp)
          user: (cbp)->
            collections.users.findById(user_id, cbp)
        }, cbs)
      (user_site, cbs)->
        {user, site} = user_site
        if !user || !site
          return cbs({notexists: true})
        collections.profiles.create(user, site, (err, result)->
          if err
            return cbs(err)
          profile = result
          cbs(null, {user: user, profile: profile, site: site})
        )
    ], callback)

  verify_mandrill = (type)->
    (req, res, next)->
      debug('Webhook request %j', inspect(req.body))
      if !req.body.mandrill_events
        return res.send(400)
      signature = req.headers['x-mandrill-signature']
      debug('Signature = %s', signature)
      if !signature
        return res.send(400)
      # authenticating Mandrill webhook request
      # http://help.mandrill.com/entries/23704122-Authenticating-webhook-requests
      calc_signature = util.sha1hmacbase64(config.mandrill_webhook_keys[type], config.replyHost + req.originalUrl + _.map(_.keys(req.body).sort(), (e)-> e + req.body[e]?.toString()).join(''))
      debug('Computed signature = %s', calc_signature)
      if signature != calc_signature
        return res.send(400)
      try
        req.body.mandrill_events = JSON.parse(req.body.mandrill_events)
      catch e
        logger.error(e)
        return res.send(400)
      next()

  # Mandrill makes a head request first, so we let it know that it works
  app.head('/email/reply', (req, res)->
    res.send(200)
  )

  # Reply by email
  app.post('/email/reply', verify_mandrill('reply'), (req, res)->
    async.each(req.body.mandrill_events, (incoming, cb)->
      debug('Inbound email %j', inspect(incoming))
      # TODO verify the authenticity of the email (encrypt comment id and user email)
      [site_name, comment_id, user_id, hmac] = /^reply-([0-9a-zA-Z]+)-([0-9a-zA-Z]+)-([0-9a-zA-Z]+)-([0-9a-zA-Z]+)@/i.exec(incoming.msg.email)[1..4]
      req.siteName = site_name
      user_email = incoming.msg.from_email
      debug('Reply by email to comment %s from user %s', comment_id, user_email)
      async.waterfall([
        (cbs)->
          user_site_profile(user_id, site_name, cbs)
        (result, cbs)->
          if !result.user
            return cbs({usernotexists: true})
          if !result.site
            return cbs({sitenotexists: true})
          if incoming.msg.email != build_reply_to('reply', site_name, comment_id, user_id, config.emailSubjectKey)
            return cbs({notallowed: true})
          collections.comments.addComment(result.site, result.user, result.profile, 
            {text: parse_user_reply(incoming.msg.text, incoming.msg.html), question: false, top: false, parent: comment_id}, 
            {user_agent: 'email', ip: ''}, cbs)
      ], (err, result)->
        if err
          logger.error(err)
          if err.stack
            # thrown exception, something wrong happened, cancel everything
            return cb(err)
        debug('Handled inbound email')
        cb()
      )
    , (err)->
      if err
        logger.error(err)
        res.send(500)
      else
        res.send(200, {})
    )
  )

  # Mandrill makes a head request first, so we let it know that it works
  app.head('/email/moderate', (req, res)->
    res.send(200)
  )

  # Moderate by email
  app.post('/email/moderate', verify_mandrill('moderate'), (req, res)->
    async.each(req.body.mandrill_events, (incoming, cb)->
      # TODO verify the authenticity of the email (encrypt comment id and user email)
      [site_name, comment_id, user_id, hmac] = /^moderate-([0-9a-zA-Z]+)-([0-9a-zA-Z]+)-([0-9a-zA-Z]+)-([0-9a-zA-Z]+)@/i.exec(incoming.msg.email)[1..4]
      req.siteName = site_name
      user_email = incoming.msg.from_email
      # the action is specified on the first line of the email
      action = parse_moderator_action(incoming.msg.text, incoming.msg.html)
      if !(action in ['approve', 'delete', 'spam'])
        return cb() 
      async.waterfall([
        (cbs)->
          user_site_profile(user_id, site_name, cbs)
        (result, cbs)->
          if !result.user
            return cbs({usernotexists: true})
          if !result.site
            return cbs({sitenotexists: true})
          if incoming.msg.email != build_reply_to('moderate', site_name, comment_id, user_id, config.emailSubjectKey)
            return cbs({notallowed: true})
          if !collections.profiles.isModerator(result.profile, result.site)
            return cbs({notallowed: true})
          if action == 'approve'
            debug("Approve by email")
            collections.comments.approve(result.site, comment_id, result.user, cbs)
          else if action == 'delete'
            debug("Delete by email")
            collections.comments.destroy(result.site, comment_id, cbs)
          else if action == 'spam'
            debug("Mark as spam by email")
            collections.comments.setSpam(result.site, comment_id, cbs)
          else
            cbs()
      ], (err, result)->
        if err
          logger.error(err)
          if err.stack
            # thrown exception, something wrong happened, cancel everything
            return cb(err)
        debug('Handled inbound email')
        cb()
      )
    , (err)->
      if err
        logger.error(err)
        res.send(500)
      else
        res.send(200, {})
    )
  )

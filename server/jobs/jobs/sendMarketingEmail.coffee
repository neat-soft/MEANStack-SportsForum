collections = require("../../datastore").collections
async = require("async")
debug = require("debug")("worker:send_marketing_email")
dbutil = require("../../datastore/util")
logger = require("../../logging").logger

module.exports = class SendMarketingEmail

  constructor: (options)->
    @options = options
    @ctlHandle = options.ctlHandle

  run: (done)=>
    if @running
      debug("Already started")
      return
    @running = true
    debug("START")
    if @ctlHandle.stop
      @running = false
      debug("STOP")
      return
    createdTimePast = new Date().getTime() - 14*24*60*60*1000 # 2 weeks in ms
    lastEmailSentPast = new Date().getTime() - 1.9*24*60*60*1000 # 2 days in ms
    async.waterfall([
      (cb)=>
        collections.sites.find({'created': {$gte: createdTimePast}}, cb)
      (cursor, cb)=>
        iter = (err, site)=>
          if err
            if !cursor.isClosed()
              cursor.close()
            return cb(err)
          if !site
            return cb()
          async.waterfall([
            (cbi)=>
              collections.users.findOne({_id: site.user, 'subscribe.marketing': true, 'marketingEmails.lastSent': {$not: {$gte: lastEmailSentPast}}}, cbi)
            (user, cbi)=>
              if user
                emailToSend = null
                #emailsArray = ['NEW_SITE_WELCOME','NEW_SITE_MODERATION', 'NEW_SITE_SETTINGS']
                emailsArray = ['NEW_SITE_WELCOME']
                for field in emailsArray
                  if(!user.marketingEmails?[field.toLowerCase()])
                    emailToSend = field
                    break
                if emailToSend
                  collections.subscriptions.sendMarketingEmail(emailToSend, site.name, user, cbi)
                else
                  cbi()
              else
                cbi()
          ],
          (err)=>
            if err
              cursor.close()
              return cb(err)
            cursor.nextObject(iter)
          )
        cursor.nextObject(iter)
    ], (err)=>
      @running = false
      if err
        debug(err)
      debug("STOP")
      done?()
      return
    )

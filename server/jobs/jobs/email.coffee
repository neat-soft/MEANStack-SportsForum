EmailSender = require("../../email").EmailSender
debug = require("debug")("worker:jobs:email")
consolidate = require("consolidate")
async = require("async")
config = require('naboo').config
util = require('../../util')
collections = require("../../datastore").collections
juice = require('juice')
fs = require('fs')

module.exports = (options)->
  cache = {}
  juiceStarted = {}
  callbacks = {}
  juice.ignoredPseudos = []
  esender = new EmailSender(
    transport: options.transport
    # delay: 1000 / options.emails_ps
  )

  keep = (callback)->
    return (err)->
      if err
        if (err.name == "DeliveryError" && /454 Throttling failure/.test(err.message)) || /454 Temporary authentication failure/.test(err.message)
          callback(err, {retry: true})
        else
          callback(err, {keep: true})
      else
        callback(err)

  return (job, callback)->
    async.waterfall([
      (cb)->
        if job.siteName
          collections.sites.findOne({name: job.siteName}, (err, site)->
            if collections.sites.hasPremium(site)
              cb(null, site)
            else
              cb(null, {})
          )
        else cb(null, {})
      (site, callback)->
        if collections.sites.hasPremium(site)
          email_from = site.premium.options?.mail_from
          email_addr = site.premium.options?.mail_addr
          # don't change reply address
          # email_reply = site.premium.options.reply_addr
          email_reply = null
        else
          email_from = null
          email_addr = null
          email_reply = null
        email_from = email_from || options.notifications.from
        email_addr = email_addr || options.notifications.fromAddress
        email_reply = email_reply || email_addr || options.notifications.fromAddress
        if job.email
          esender.send(_.extend({from: email_from, replyTo: email_reply}, job.email), keep(callback))
        else
          html = text = subject = null
          email_type = job.emailType.toLowerCase()
          async.waterfall([
            (cb)->
              if !cache[email_type] && !juiceStarted[email_type]
                debug("no cached email found for " + email_type)
                callbacks[email_type] = [cb]
                juiceStarted[email_type] = true
                async.waterfall([
                  (cbw)->
                    fs.readFile("./emails/template.html", 'utf8', cbw)
                  (data, cbw)->
                    content = data.replace('<% body %>', "<% include #{email_type}_html %>")
                    consolidate.ejs.render(content, _.extend({}, {filename: "./emails/template.html", open: '<%', close: '%>'}), cbw)
                  (html, cbw)->
                    path = 'file://' + process.cwd() + '/emails/'
                    juice.juiceContent(html, {url: path}, cbw)
                ], (err, result)->
                  cache[email_type] = result
                  juiceStarted[email_type] = false
                  while cb_i = callbacks[email_type].pop()
                    cb_i(err, result)
                  )
              else if cache[email_type]
                debug('cached email found for ' + email_type)
                cb(null, cache[email_type])
              else #juice is already running on email_type
                debug('waiting for juice to finish ' + email_type)
                callbacks[email_type].push(cb)
            (result, cb)->
              html = result
              consolidate.ejs.render(html, _.extend({}, job, {config: config, cache: true, filename: "./emails/#{email_type}_html.ejs", open: '{{', close: '}}'}), cb)
            (result, cb)->
              html = result
              consolidate.ejs("./emails/#{email_type}_text.ejs", _.extend({}, job, {config: config, cache: true, filename: "emails/#{email_type}_text.ejs", open: '{{', close: '}}'}), cb)
            (result, cb)->
              text = result
              consolidate.ejs("./emails/#{email_type}_subject.ejs", _.extend({}, job, {config: config, cache: true, filename: "emails/#{email_type}_subject.ejs", open: '{{', close: '}}'}), cb)
            (result, cb)->
              subject = result
              if job.email_from
                email_from = job.email_from
              if job.email_addr
                email_addr = job.email_addr
              if job.email_reply_to
                email_reply = job.email_reply_to
              esender.send({
                from: "#{email_from} <#{email_addr}>"
                to: job.to
                replyTo: email_reply
                cc: job.email_cc
                text: text
                html: html
                subject: subject
              }, cb)
          ], (err)->
            if err?.code == 'ENOENT'
              # template does not exist, ignore email
              return callback()
            keep(callback)(err)
          )
    ], callback)

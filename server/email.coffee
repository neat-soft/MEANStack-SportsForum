nodemailer = require("nodemailer")
util = require("./util")
config = require("naboo").config

# Options
# - transport {type, options} The transport configuration to pass to nodemailer
# - delay Send at most once per delay milliseconds
class EmailSender

  constructor: (options)->
    @options = options
    @transport = nodemailer.createTransport(options.transport.type || "SMTP", options.transport.options || {})
    if @options.delay
      @send = _.limit(@send, @options.delay)

  send: (data, callback)->
    @transport.sendMail(data, callback)

module.exports.EmailSender = EmailSender

module.exports.build_reply_to = (prefix, site_name, comment_id, user_id, key)->
  if comment_id.toHexString?
    comment_id = comment_id.toHexString()
  if user_id.toHexString?
    user_id = user_id.toHexString()
  text = "#{site_name}-#{comment_id}-#{user_id}"
  hmac = util.sha1hmachex(key, text)
  return "#{prefix}-#{text}-#{hmac}@#{config.email.notifications.replyToHost}"

async = require("async")
moment = require("moment")
templates = require("../../templates")
collections = require("../../datastore").collections
passport = require("passport")
sharedUtil = require("../../../shared/util")
util = require("../../util")
urls = require("../urls")
debug = require("debug")("marketing:profiles")
logger = require("../../logging").logger
handlers = require("../handlers")
config = require("naboo").config
stripe = require("stripe")(config.stripe.secret)

module.exports = (app)->

  available_languages = ->
    lang_id_name = "en=English,cn=中文 (Zhōngwén),fr=Français,de=Deutsch,it=Italiano,jp=日本語 (にほんご),pl=Polski,pt=Português,ru=Pусский язык,es=Español".split(",")
    languages = []
    for id_name in lang_id_name
      id_name = id_name.split("=")
      languages.push({id: id_name[0].toUpperCase(), name: id_name[1]})
    return languages

  load_transactions_fields = (cursor, done_all)->
    cursor.toArray((err, txn)->
      cursor.close()
      async.map(txn, (item, done_with_element)->
        item.time = item._id.getTimestamp()
        util.waterfall([
          (cb)->
            util.load_field(item, "user", collections.users, (err, item)->
              cb(err, item)
            )
          (cb, item)->
            util.load_field(item, "source", collections.users, cb)
          (cb, item)->
            util.load_field(item, "ref", collections.comments, cb)
          (cb, item)->
            item.commentUrl = urls.for_model("comment", item.ref)
            cb(null, item)
        ], done_with_element)
      , done_all)
    )

  app.get("/profile", handlers.shouldLogin, (req, res)->
    async.parallel({
      toMe: (cb)->
        collections.transactions.find({type: "FUND_COMMENT", user: req.user._id}, {sort: {date: 1}}, (err, cursor)->
          if !cursor
            return cb(err)
          load_transactions_fields(cursor, cb)
        )
      fromMe: (cb)->
        collections.transactions.find({type: "FUND_COMMENT", source: req.user._id}, {sort: {date: 1}}, (err, cursor)->
          if !cursor
            return cb(err)
          load_transactions_fields(cursor, cb)
        )
      siteBenefits: (cb)->
        collections.profiles.find({user: req.user._id, "benefits.signature.expiration": {$gt: moment.utc().valueOf()}}, (err, cursor)->
          cursor.toArray((err, elements)->
            cursor.close()
            for e in elements || []
              days = moment.utc(e.benefits.signature.expiration).diff(moment.utc(), "days")
              if days < 0
                days = 0
              e.expiration = days
            cb(err, elements)
          )
        )
    }, (err, results)->
      templates.render(res, "marketing/profile", {
        user: req.user,
        languages: available_languages(),
        pk: config.stripe.public,
        email: req.user.email,
        funds_to_me: results.toMe
        funds_from_me: results.fromMe
        benefits: results.siteBenefits
        sso: req.user.type == 'sso'
        own: req.user.type == 'own'
      })
    )
  )

  handle_payment = (req, res)->
    token = req.body.stripeToken
    stripe.charges.create({
      card: token
      currency: "usd"
      amount: 100000
      description: "Gold Badge for #{req.user.email}"
    }, (err, charge)->
      if err
        logger.error(err)
        req.flash('error', "Could not process payment: #{err.type} - #{err.message}")
        res.redirect("/profile")
        return
      collections.users.addGold(req, req.user, {id: charge.id, from_user: req.user._id, date: moment.utc().toDate()}, (err)->
        res.redirect("/profile")
      )
    )

  app.post("/profile", (req, res)->
    if !req.user
      res.redirect("/auth/signin")
      return
    if req.body.stripeToken
      handle_payment(req, res)
      return
    passwd = sharedUtil.removeWhite(req.body.passwd)
    newPasswd = sharedUtil.removeWhite(req.body.new_passwd)
    if req.user.type == "own"
      if passwd || !req.user.completed
        if !newPasswd
          debug("new password is blank")
          req.flash('error', 'Please enter the new password.')
          return res.redirect('/profile')
        else if req.user.completed
          hashedPassword = util.hashPassword(passwd, String(req.user.created))
          if req.user.password != hashedPassword
            debug("old password is incorrect")
            req.flash('error', 'Please enter your current password correctly.')
            return res.redirect('/profile')
    debug("updating user data")
    req.body.subscribe = _.pick(_.set(req.body.subscribe), "own_activity", "auto_to_conv", "name_references", "marketing", "ignited")
    req.body.comments = _.pick(_.set(req.body.comments), "instant_show_new")
    req.body.imageType = req.body.imagetype
    collections.users.modify(req.user, req.body, newPasswd, (err, user)->
      if err
        if err.exists
          req.flash('error', 'This email address is already used by another user. Please try another one.')
        else if err.email_incorrect
          req.flash('error', 'Please enter a valid email address.')
        else
          logger.error(err)
          req.flash('error', 'Could not change your profile at the moment.')
      else
        req.flash('success', 'Your changes have been successfully saved. It could take a while until we propagate the changes to all your data.')
      res.redirect('/profile')
    )
  )

  app.post("/profile/verify", (req, res)->
    if !req.user
      return res.redirect("/auth/signin")
    if req.user.verified == true
      return res.redirect('/profile')
    collections.users.sendVerification(req.user, (err, result)->
      if err
        return next(err)
      req.flash('success', 'Verification email sent.')
      res.redirect('/profile')
    )
  )

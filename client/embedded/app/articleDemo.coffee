User = require("models/user")
EmbeddedApplication = require("embeddedApplication")
analytics = require("lib/analytics")
util = require("lib/shared/util")

module.exports = class ArticleDemo extends EmbeddedApplication

  initialize: ->
    analytics.enabled = false

    hankaaron = new User({
      _id: _.uniqueId('id')
      name: "Hank Aaron"
      imageType: "custom"
      imageUrl: util.resource("/img/demo/hankaaron.jpg")
      verified: true
    })
    hankaaron.get("profile").set({_id: _.uniqueId('id'), points: 130, permissions: {}, userName: 'Hank Aaron'})

    baberuth = new User({
      _id: _.uniqueId('id')
      name: "Babe Ruth"
      imageType: "custom"
      imageUrl: util.resource("/img/demo/baberuth.jpg")
      verified: true
    })
    baberuth.get("profile").set({_id: _.uniqueId('id'), points: 260, permissions: {}, userName: 'Babe Ruth'})

    williemays = new User({
      _id: _.uniqueId('id')
      name: "Willie Mays"
      imageType: "custom"
      imageUrl: util.resource("/img/demo/williemays.jpeg")
      verified: true
    })
    williemays.get("profile").set({_id: _.uniqueId('id'), points: 50, permissions: {}, userName: 'Willie Mays'})

    wiltchamberlain = new User({
      _id: _.uniqueId('id')
      name: "Wilt Chamberlain"
      imageType: "custom"
      imageUrl: util.resource("/img/demo/wiltchamberlain.jpg")
      verified: true
    })
    wiltchamberlain.get("profile").set({_id: _.uniqueId('id'), points: 215, permissions: {}, userName: 'Wilt Chamberlain'})

    walterpayton = new User({
      _id: _.uniqueId('id')
      name: "Walter Payton"
      imageType: "custom"
      imageUrl: util.resource("/img/demo/walterpayton.jpg")
      verified: true
    })
    walterpayton.get("profile").set({_id: _.uniqueId('id'), points: 30, permissions: {}, userName: 'Walter Payton'})

    @logins =
      own:
        logo: "burnzone_icon.png"
        loginUrl: ""
        logoutUrl: ""

    me = new User({
      _id: _.uniqueId('id')
      name: "John Doe"
      email: "johndoe@example.com"
      imageType: "custom"
      imageUrl: util.resource("/img/demo/mattkemp.png")
      verified: true
    })
    me.get("profile").set({_id: _.uniqueId('id'), points: 150, permissions: {}, userName: 'John Doe'})
    super

    # show an alert about the transactions
    # open a popup with test cards accepted by Stripe
    stripe_open = @stripe_checkout.open
    @stripe_checkout.open = =>
      alert(@translate('help_demo_payment'))
      window.open('https://stripe.com/docs/testing#cards')
      return stripe_open.apply(@stripe_checkout, _.toArray(arguments))

    @api.site.set({
      badges:
        '0': {
          title: 'Top 5 This Month'
          icon: 'top5'
          enabled: true
          rank_cutoff: 2
        },
        '1': {
          title: 'Igniter'
          icon: 'igntr'
          color_bg: 'rgb(189, 183, 107)'
          manually_assigned: true
        }
      points_settings:
        min_bet: 25
        min_bet_targeted: 25
    })
    wiltchamberlain.get('profile').set(trusted: true)
    wiltchamberlain.get('profile').get('badges').add([
      {badge_id: '0', rank: 1, rank_cutoff: 2, value: 10},
      {badge_id: '1', manually_assigned: true}
    ])
    baberuth.get('profile').get('badges').add([
      {badge_id: '0', rank: 2, rank_cutoff: 2, value: 7},
    ])
    @currentContext.get('convprofiles').add([
      {user: wiltchamberlain.id, points: 4, permissions: {}}
      {user: hankaaron.id, points: 3, permissions: {}}
      {user: baberuth.id, points: 1, permissions: {}}
    ])

    old_trigger = @api.trigger
    @api.trigger = (->)
    to_challenge = null
    async.waterfall([
      (cb)=>
        @api.userLogin(hankaaron)
        @api.createComment("How about the MLB these days and a lot of high profile players getting busted for steriods.  A-rods chances of catching me have all but gone out the window", null, false, 0, 0, @currentContext, null, cb)
      (comment, cb)=>
        comment.set({is_funded: true, funded: [wiltchamberlain.id]})
        comment.get('context').get('funded_activities').add(comment)
        @api.site.get('funded_activities').add(comment)
        @api.userLogin(baberuth)
        @api.createComment("Even if he did there would be a large Asterisk next to his name like you know who.  Hank you are still #1 in my book.", null, false, 0, 0, comment, null, cb)
      (comment, cb)=>
        @api.userLogin(williemays)
        @api.createComment("I agree Babe.  Its us 1,2,3.", null, false, 0, 0, comment, null, cb)
      (comment, cb)=>
        @api.userLogin(hankaaron)
        text = "In fact, here is a Yolo that A-Rod will not hit 700 career home runs and I'm willing to risk 50 points to anyone who disagrees with me."
        @api.createBet(text, comment, {points: 50, bet_type: 'targeted_closed', ratio_accepted: 1, ratio_joined: 1, users: [me.id, wiltchamberlain.id], end_date: moment().add(3, 'days').valueOf()}, cb)
      (comment, cb)=>
        @api.userLogin(wiltchamberlain)
        @api.acceptBet(comment, {points: 25}, cb)
      (comment, cb)=>
        @api.userLogin(wiltchamberlain)
        @api.createComment("Guys can take as many steroids as they want but they will never drop 100 pts in a game.", null, false, 0, 0, @currentContext, null, (err, new_comment)->
          if !err
            to_challenge = new_comment
          cb(err, new_comment)
        )
      (comment, cb)=>
        @api.userLogin(walterpayton)
        @api.createComment("Truth Wilt...", null, false, 0, 0, comment, null, cb)
      (comment, cb)=>
        @api.userLogin(hankaaron)
        hankaaron.get('profile').set(points: 100)
        if to_challenge
          @api.createChallenge(to_challenge, '', "You're dead wrong Wilt, the only reason your 100 pts record still stands is because all of the good athletes play baseball and football.", null, cb)
        else
          cb(null, comment)
    ], =>
      @api.once('login', =>
        # We need to set these manually for navigation, as the comments collection will not be fetched
        @views.main.commentsFetched = true
        @views.main.promotedFetched = true
      )
      @api.trigger = old_trigger
      @api.userLogin(me)
    )
    Comment = require('models/comment')
    all_users = _.filter(@api.store.getCollection(User, true).models, (u)-> u != me && !u.get('dummy'))

    @api.store.getCollection(Comment, true).on('add', (comment)=>
      setTimeout(=>
        if comment.get('type') != 'BET'
          return
        if comment.get('author') != me
          return
        if comment.get('bet_status') != 'open'
          return
        @api.trigger = (->)
        async.forEachSeries(_.union(comment.get('bet_targeted').models, all_users), (user, done)=>
          @api.userLogin(user)
          if comment.get('bet_accepted').length < 2 && comment.get('bet_tpts_av') > 0
            @api.acceptBet(comment, {points: if comment.get('bet_tpts_av') < 50 then comment.get('bet_tpts_av') else 25}, (err)->
              done()
            )
          else
            if user in comment.get('bet_targeted').models
              @api.declineBet(comment, (err)->
                done()
              )
            else
              done()
        , (err)=>
          @api.userLogin(me)
          @api.trigger = old_trigger
        )
      , 5000)
    )

    @api.store.getCollection(Comment, true).on('add', (comment)=>
      _.defer(=>
        if comment.get('type') != 'BET'
          return
        if comment.get('author') == me
          return
        comment.get('bet_forfeited').on('reset', =>
          if comment.get('bet_forfeited').last() != me
            return
          setTimeout(=>
            @api.trigger = (->)
            async.forEachSeries(comment.get('bet_accepted').models, (user, done)=>
              if user == me
                return done()
              if comment.get('bet_status') != 'forf'
                return done('Forf closed')
              @api.userLogin(user)
              @api.forfeitBet(comment, done)
            , =>
              @api.userLogin(me)
              @api.trigger = old_trigger
            )
          , 1000)
        )
        comment.get('bet_claimed').on('reset', =>
          if comment.get('bet_claimed').last() != me
            return
          setTimeout(=>
            @api.trigger = (->)
            async.series([
              (cb)=>
                @api.userLogin(comment.get('author'))
                @api.claimBet(comment, cb)
              (cb)=>
                async.forEachSeries(comment.get('bet_accepted').models, (user, done)=>
                  if user == me
                    return done()
                  if comment.get('bet_status') != 'forf'
                    return done('Forf closed')
                  @api.userLogin(user)
                  @api.forfeitBet(comment, done)
                , cb)
            ], =>
              @api.userLogin(me)
              @api.trigger = old_trigger
            )
          , 1000)
        )
        comment.get('bet_accepted').on('reset', =>
          if comment.get('bet_accepted').last() != me
            return
          async.series([
            (cb)=>
              # close
              setTimeout(=>
                if comment.get('bet_status') == 'open'
                  @api.trigger = (->)
                  @api.userLogin(comment.get('author'))
                  @api.endBet(comment, cb)
                else
                  cb()
              , 1000)
            (cb)=>
              @api.userLogin(me)
              @api.trigger = old_trigger
              # resolution
              setTimeout(=>
                if comment.get('bet_status') == 'closed'
                  @api.trigger = (->)
                  @api.userLogin(comment.get('author'))
                  @api.startForfBet(comment, cb)
                else
                  cb()
              , 1000)
          ], =>
            @api.userLogin(me)
            @api.trigger = old_trigger
          )
        )
        comment.get('bet_declined').on('reset', =>
          if comment.get('bet_declined').last() != me
            return
          async.series([
            (cb)=>
              # close
              setTimeout(=>
                @api.trigger = (->)
                @api.userLogin(comment.get('author'))
                @api.endBet(comment, cb)
              , 1000)
            (cb)=>
              @api.userLogin(me)
              @api.trigger = old_trigger
              # resolution
              setTimeout(=>
                if comment.get('bet_status') == 'closed'
                  @api.trigger = (->)
                  @api.userLogin(comment.get('author'))
                  @api.startForfBet(comment, cb)
                else
                  cb()
              , 1000)
            (cb)=>
              @api.userLogin(me)
              @api.trigger = old_trigger
              setTimeout(=>
                @api.trigger = (->)
                async.forEachSeries(comment.get('bet_accepted').models, (user, done)=>
                  if comment.get('bet_status') != 'forf'
                    return done('Forf closed')
                  @api.userLogin(user)
                  @api.forfeitBet(comment, done)
                , cb)
              , 1000)
          ], =>
            @api.userLogin(me)
            @api.trigger = old_trigger
          )
        )
      )
    )

    @api.store.getCollection(Comment, true).on('change:bet_status', (comment, status)=>
      if comment.get('type') != 'BET'
        return
      if comment.get('author') != me
        return
      if status == 'forf'
        comment.get('bet_claimed').on('reset', =>
          if comment.get('bet_claimed').last() != me
            return
          if comment.iclaimed
            return
          comment.iclaimed = true
          @api.trigger = (->)
          async.forEachSeries(comment.get('bet_accepted').models, (user, done)=>
            @api.userLogin(user)
            if comment.get('bet_status') != 'forf'
              return done('Forf closed')
            @api.forfeitBet(comment, done)
          , =>
            @api.userLogin(me)
            @api.trigger = old_trigger
          )
        )
    )

  logout: null

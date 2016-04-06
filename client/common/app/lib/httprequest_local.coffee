HttpRequest = require('lib/httprequest')

id = 1

getId: ->
  return (id++).toString()

module.exports = class LocalHttpRequest extends HttpRequest

  initialize: (options)->
    @api = options.api
    Backbone.sync = require("Backbone.Sync-localApp")({api: @api})

  doRequest: (url, method, params, cb)->
    _.defer(=>
      if new RegExp("/api/sites/[a-zA-Z0-9]+/subscriptions").test(url)
        if method == 'POST'
          return cb?(null, {active: params.active})
        else if method == 'GET'
          return cb?(null, {active: false})
      if method == 'POST' && new RegExp("/api/sites/[a-zA-Z0-9]+/loginsso").test(url)
        return cb?({status: 404})
      if method == 'GET' && new RegExp("/api/users/me").test(url)
        return cb?({status: 404})
      if method == 'GET' && new RegExp("/api/users/me").test(url)
        if @api.loggedIn()
          return cb?(null, @api.user.attributes)
        else
          return cb?({status: 404})

      validate_new_bet = (attrs)=>
        now = moment()
        if !(attrs.bet_type in ['open', 'targeted_open', 'targeted_closed'])
          return {bet_invalid_type: true}
        if !(attrs.points > 0)
          return {bet_invalid_points_value: true}
        if !(attrs.ratio_joined > 0 && attrs.ratio_accepted > 0)
          return {bet_invalid_ratio: true}
        if attrs.points < @api.site.get("points_settings").min_bet
          return {bet_invalid_points_value: true}
        if attrs.end_date < now.valueOf() + 1 * 60 * 1000
          return {bet_invalid_date: true}
        if attrs.start_forf_date && attrs.start_forf_date < attrs.end_date
          return {bet_invalid_start_forf_date: true}
        if !_.isArray(attrs.users)
          return {bet_invalid_users: true}
        if attrs.users.length > 0
          for i in [0..attrs.users.length - 1]
            if attrs.users[i] == @api.user.id
              return {bet_cannot_target_self: true}
        ratio = attrs.ratio_accepted / attrs.ratio_joined
        if (attrs.bet_type == 'targeted_open' || attrs.bet_type == 'targeted_closed')
          if @api.site.get("points_settings").min_bet_targeted * attrs.users.length > Math.floor(attrs.points * ratio)
            return {bet_invalid_points_value: true}
        if attrs.max_points_user && attrs.max_points_user < Math.min(@api.site.get("points_settings").min_bet_targeted, @api.site.get("points_settings").min_bet)
          return {bet_invalid_points_value: true}
        users_count = @api.store.getCollection(require('models/user'), true).filter((u)-> _.contains(attrs.users, u.id)).length
        if users_count != attrs.users.length
          return {bet_users_nonexistent: true}

      createComment = (siteName, parentId)=>
        # create comment in context
        if !@api.loggedIn()
          return cb?({status: 403})
        parent = @api.store.models.get(parentId)
        cdate = new Date().getTime()
        id = _.uniqueId('id')
        if params.question || params.bet
          level = 1
          parentId = parent.get("context")?.id || parent.id
        else
          if parent.get("level") >= 3
            level = 3
            parentId = parent.get("parent").id
          else
            level = (parent.get("level") || 0) + 1
            parentId = parent.id
        params.promotePoints = parseInt(params.promotePoints)
        if params.bet
          params.users ?= []
          if params.users.length == 1 && params.users[0] == ""
            params.users = []
          if valid_result = validate_new_bet(params)
            return cb({status: 400}, valid_result)
          if @api.user.get('profile').get('points') < params.points
            return cb({status: 403}, {notenoughpoints: true})
        if params.promotePoints > 0
          ctx = parent.get('context') || parent
          promoted_limit = @app.options.promotedLimit
          if ctx.get('promoted').models[promoted_limit - 1]?.get('promotePoints') > params.promotePoints
            return cb({status: 403}, {below_minimum_promote_points: true})
          if @api.user.get('profile').get('points') < params.promotePoints
            return cb({status: 403}, {notenoughpoints: true})
          @api.user.get('profile').inc('points', -params.promotePoints)
        comment =
          _v: 0
          _id: id
          created: cdate
          changed: cdate
          no_likes: 0
          no_likes_down: 0
          text: params.text
          ptext: marked(params.text)
          no_comments: 0
          no_all_comments: 0
          rating: 0
          order_time: cdate.toString() + "0"
          approved: true
          siteName: @api.site.get("name")
          context: parent.get("context")?.id || parent.id
          parent: parent.id
          level: level
          type: if params.question then "QUESTION" else if params.bet then "BET" else "COMMENT"
          author: @api.user.id
          question: params.question
          cat: if params.question then "QUESTION" else "COMMENT"
          catParent: if level == 1 then id else (parent.get("catParent") || parentId)
        parent.set({
          no_activities: parent.get('no_activities') + 1
          no_all_activities: parent.get('no_all_activities') + 1
        })
        if comment.type == 'BET'
          ratio = params.ratio_accepted / params.ratio_joined
          points = params.points
          tpts_av = Math.floor(points * ratio)
          pts_tuser = 25
          if params.type == 'open'
            params.users = []
          _.extend(comment, {
            bet_type: params.bet_type
            bet_joined_points: _.object([[@api.user.id, params.points]])
            bet_accepted_points: {}
            bet_ratio_joined: params.ratio_joined
            bet_ratio_accepted: params.ratio_accepted
            bet_targeted: params.users
            bet_accepted: []
            bet_declined: []
            bet_forfeited: []
            bet_joined: [@api.user.id]
            bet_end_date: params.end_date
            bet_start_forf_date: params.start_forf_date
            bet_winning_side: ''
            bet_total_points: params.points
            bet_rolledback: false
            bet_status: 'open'
            bet_tpts_joined: points
            bet_tpts_accepted: 0
            bet_tpts_av: tpts_av
            bet_pts_tuser: pts_tuser
            bet_tpts_av_tuser: if params.users.length == 0 then 0 else Math.floor(tpts_av - (params.users.length - 1) * pts_tuser)
            bet_tpts_av_ntusers: if params.users.length == 0 then Math.floor(points * ratio) else Math.floor(tpts_av - params.users.length * pts_tuser) # total points available for the next user who wasn't targeted
            bet_pts_max_user: params.bet_pts_max_user # TODO check values
            bet_points_resolved: {}
            bet_notif_unresolved: false
            bet_notif_remind_forf: false
            bet_requires_mod: false
          })
          if !comment.bet_start_forf_date
            comment.bet_start_forf_date = comment.bet_end_date
        if params.promotePoints
          comment.promote = true
          comment.promotePoints = params.promotePoints
        context = parent.get("context") || parent
        context.get("allactivities").add(comment, {parse: true})
        if params.promotePoints
          bkbcomment = context.get("allactivities").get(id)
          context.get("promoted").add(bkbcomment)
        if parent.get("level") >= 1
          context.set({
            no_activities: context.get('no_activities') + 1
            no_all_activities: context.get('no_all_activities') + 1
          })
        if comment.type == 'BET'
          @api.user.get('profile').inc('points', -params.points)
          setTimeout(=>
            comment = @api.store.models.get(id)
            if comment.get('bet_status') == 'open'
              comment.set(bet_status: 'closed')
              comment.inc('_v')
          , comment.bet_end_date - new Date().getTime())
          setTimeout(=>
            comment = @api.store.models.get(id)
            if comment.get('bet_status') == 'closed'
              comment.set(bet_status: 'forf')
              comment.inc('_v')
          , comment.bet_start_forf_date - new Date().getTime())
        return cb(null, comment)

      if method == "POST" && ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/(?:contexts|activities)/([a-zA-Z0-9]+)/bets").exec(url)))
        params.bet = true
        return createComment(match[1], match[2])

      if method == "POST" && (((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/contexts/([a-zA-Z0-9]+)/comments").exec(url))) ||
        ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/comments").exec(url))) ||
        ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/challenges/([a-zA-Z0-9]+)/comments").exec(url))))
          return createComment(match[1], match[2])

      if method == "POST" && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/contexts/([a-zA-Z0-9]+)/challenges").exec(url))) )
        if !@api.loggedIn()
          return cb?({status: 403})
        if @api.user.get('profile').get('points') + @app.options.challengeCost < 0
          return cb?({status: 403}, {notenoughpoints: true})
        siteName = match[1]
        parent = @api.store.models.get(match[2])
        cdate = new Date().getTime()
        challenged = @api.store.models.get(params.challenged)
        id = _.uniqueId('id')
        challenge =
          _id: id
          _v: 0
          created: cdate
          changed: cdate
          no_comments: 0
          no_all_comments: 0
          no_all_activities: 0
          no_activities: 0
          rating: 0
          order_time: @api.store.models.get(challenged.get("catParent")).get("created").toString() + "1"
          approved: true
          siteName: siteName
          context: parent.id
          level: 1
          summary: params.summary
          challenger:
            text: params.challenger.text
            ptext: marked(params.challenger.text)
            no_votes: 0
            no_votes_down: 0
            created: cdate
            author: @api.user.id
          challenged:
            text: challenged.get("text")
            ptext: challenged.get("ptext")
            no_votes: 0
            no_votes_down: 0
            ref: challenged.id
            created: challenged.get("created")
            author: challenged.get("author").id
          parent: parent.id
          type: "CHALLENGE"
          cat: "CHALLENGE"
        parent.get("allactivities").add(challenge)
        parent.set({
          no_activities: parent.get('no_activities') + 1
          no_all_activities: parent.get('no_all_activities') + 1
          no_challenges: parent.get('no_challenges') + 1
        })
        @api.user.get('profile').inc('points', @app.options.challengeCost)
        return cb?(null, challenge)

      accept_bet = (siteName, comment_id)=>
        comment = @api.store.models.get(comment_id)
        points = params.points
        if !comment || !comment.get('type') == 'BET'
          return cb({status: 403}, {notexists: true})
        if comment.get("bet_status") != 'open'
          return cb({status: 403}, {denied: true})
        if points < @api.site.get("points_settings").min_bet
          return cb({status: 400}, {invalid_points_value: true})
        if comment.get("bet_tpts_av") < 2 * @api.site.get("points_settings").min_bet && points != comment.get("bet_tpts_av")
          return cb({status: 400}, {invalid_points_value: true})
        if comment.get("bet_pts_max_user") && comment.get("bet_pts_max_user") < points
          if !(comment.get("bet_tpts_av") < 2 * site.get("points_settings").min_bet && points == comment.get("bet_tpts_av"))
            return cb({status: 400}, {invalid_points_value: true})
        accepted = comment.get("bet_accepted").find((t)=> t.id == @api.user.id)?
        if accepted
          return cb({status: 400}, {conflict: true})
        declined = comment.get("bet_declined").find((t)=> t.id == @api.user.id)?
        if declined
          return cb({status: 400}, {conflict: true})
        targeted = comment.get("bet_targeted").find((t)=> t.id == @api.user.id)?
        if targeted
          if points > comment.get("bet_tpts_av_tuser")
            return cb({status: 400}, {invalid_points_value: true})
        else
          if comment.get("bet_type") == 'targeted_closed'
            return cb({status: 403}, {denied: true})
          if points > comment.get("bet_tpts_av_ntusers")
            return cb({status: 400}, {invalid_points_value: true})
        if @api.user.get('profile').get('points') < points
          return cb({status: 403}, {notenoughpoints: true})
        @api.user.get('profile').inc('points', -points)
        result = JSON.parse(JSON.stringify(comment.attributes))
        result.bet_accepted = _.union(result.bet_accepted, [@api.user.id])
        result.bet_accepted_points[@api.user.id] = points
        result._v += 1
        result.bet_tpts_av -= points
        result.bet_tpts_accepted += points
        if targeted
          dec_tpts_av_tuser = dec_tpts_av_ntusers = Math.max(0, points - comment.get("bet_pts_tuser"))
        else
          dec_tpts_av_tuser = 0
          dec_tpts_av_ntusers = points
        result.bet_tpts_av_tuser -= dec_tpts_av_tuser
        result.bet_tpts_av_ntusers -= dec_tpts_av_ntusers
        return cb(null, result)

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/accept_bet").exec(url))) )
        return accept_bet(match[1], match[2])

      compute_winning_side = (comment)=>
        forf_joined = _.intersection(_.pluck(comment.get("bet_joined").models, 'id'), _.pluck(comment.get("bet_forfeited").models, 'id'))
        forf_accepted = _.intersection(_.pluck(comment.get("bet_accepted").models, 'id'), _.pluck(comment.get("bet_forfeited").models, 'id'))
        major_acc = Math.ceil(comment.get("bet_accepted").length / 2)
        if forf_accepted.length >= major_acc && forf_joined.length == 0
          return 'joined'
        if forf_accepted.length == 0 && forf_joined.length == 1
          return 'accepted'
        return 'undecided'

      get_side_in_bet = (comment, user)=>
        if comment.get("bet_joined_points")[user.id]
          return 'joined'
        else
          return 'accepted'

      rollback_bet = (comment)=>
        for user in _.union(comment.get('bet_accepted').models, comment.get('bet_joined').models)
          points = comment.get("bet_accepted_points")[user.id] || comment.get("bet_joined_points")[user.id]
          user.get('profile').set(points: user.get('profile').get('points') + points)

      bet_points_user = (bet, user, side)=>
        winning_side = bet.get("bet_winning_side")
        ratio_wj = bet.get("bet_ratio_accepted") / bet.get("bet_ratio_joined")
        ratio_wa = bet.get("bet_ratio_joined") / bet.get("bet_ratio_accepted")
        pts_won = 0
        pts_get_back = 0
        pts_all = 0
        if side == 'joined'
          pts_risked = bet.get("bet_joined_points")[user.id]
          pts_risked_other = bet.get("bet_tpts_accepted")
          if winning_side == side
            # winner
            # get back everything risked + everything risked by the other side
            pts_get_back = pts_risked
            pts_won = pts_risked_other * pts_risked / bet.get("bet_tpts_joined")
          else
            # loser
            # can lose only a part of the points risked, depending on the amount risked by the other party
            # here we calculate how much the user gets back of the risked amount
            given = pts_risked_other * ratio_wa * pts_risked / bet.get("bet_tpts_joined")
            pts_get_back = Math.floor(pts_risked - given)
            pts_won = 0
        else if side == 'accepted'
          # accepted
          pts_risked = bet.get("bet_accepted_points")[user.id]
          pts_risked_other = bet.get("bet_tpts_joined")
          if winning_side == side
            # winner
            # get back everything risked + everything risked by the other side
            pts_get_back = pts_risked
            pts_won = pts_risked * ratio_wa
          else
            # loser
            pts_won = 0
            pts_get_back = 0
        pts_all = pts_won + pts_get_back
        if pts_won != 0
          user.get('profile').inc('points', pts_won)
        if pts_get_back != 0
          user.get('profile').inc('points', pts_get_back)
        return pts_all

      resolve_bet = (comment)=>
        pts_resolved = {}
        if comment.get('bet_winning_side') == 'tie' || comment.get('bet_accepted').length == 0
          rollback_bet(comment)
        else
          for user in _.union(comment.get('bet_accepted').models, comment.get('bet_joined').models)
            side = get_side_in_bet(comment, user)
            pts_resolved[user.id] = bet_points_user(comment, user, side)
        comment.set({
          bet_status: 'resolved_pts'
          bet_points_resolved: pts_resolved
          _v: comment.get('_v') + 1
        })

      bet_requires_mod = (comment)=>
        bet_accepted_str = _.pluck(comment.get("bet_accepted").models, 'id')
        bet_joined_str = _.pluck(comment.get("bet_joined").models, 'id')
        bet_forfeited_str = _.pluck(comment.get("bet_forfeited").models, 'id')
        bet_claimed_str = _.pluck(comment.get("bet_claimed").models, 'id')
        # If one of more users claims they Won from each side
        if _.intersection(bet_accepted_str, bet_claimed_str).length > 0 && _.intersection(bet_joined_str, bet_claimed_str).length > 0
          return true
        # Either side claims both won and lost
        if _.intersection(bet_accepted_str, bet_claimed_str).length > 0 && _.intersection(bet_accepted_str, bet_forfeited_str).length > 0 ||
          _.intersection(bet_joined_str, bet_claimed_str).length > 0 && _.intersection(bet_joined_str, bet_forfeited_str).length > 0
            return true
        return false

      mark_requires_mod = (comment)=>
        comment.set({
          bet_requires_mod: true
          bet_notif_remind_forf: true
          _v: comment.get('_v') + 1
        })

      end_forf_bet = (comment)=>
        now = new Date().getTime()
        comment.set({
          bet_status: 'forf_closed'
          bet_forf_closed_at: now
          _v: comment.get('_v') + 1
        })
        winning_side = compute_winning_side(comment)
        comment.set({
          bet_status: 'resolved'
          bet_winning_side: winning_side
          _v: comment.get('_v') + 1
        })
        resolve_bet(comment)

      forfeit_bet = (siteName, comment_id)=>
        comment = @api.store.models.get(comment_id)
        if !comment || !comment.get('type') == 'BET'
          return cb({status: 403}, {notexists: true})
        if comment.get("bet_status") != 'forf'
          return cb({status: 403}, {denied: true})
        if comment.get('bet_claimed').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        if comment.get('bet_forfeited').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        if !comment.get('bet_accepted').contains(@api.user) && !comment.get('bet_joined').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        if comment.get('bet_declined').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        result = JSON.parse(JSON.stringify(comment))
        result.bet_forfeited = _.union(result.bet_forfeited, @api.user.id)
        result._v += 1
        cb(null, result)
        _.defer(=>
          if !comment.bet_requires_mod
            if bet_requires_mod(comment)
              return mark_requires_mod(comment)
            if compute_winning_side(comment) != 'undecided'
              return end_forf_bet(comment)
        )

      claim_bet = (siteName, comment_id)=>
        comment = @api.store.models.get(comment_id)
        if !comment || !comment.get('type') == 'BET'
          return cb({status: 403}, {notexists: true})
        if comment.get("bet_status") != 'forf'
          return cb({status: 403}, {denied: true})
        if comment.get('bet_claimed').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        if comment.get('bet_forfeited').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        if !comment.get('bet_accepted').contains(@api.user) && !comment.get('bet_joined').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        if comment.get('bet_declined').contains(@api.user)
          return cb({status: 409}, {conflict: true})
        result = JSON.parse(JSON.stringify(comment))
        result.bet_claimed = _.union(result.bet_claimed, @api.user.id)
        result._v += 1
        cb(null, result)
        _.defer(=>
          if !comment.bet_requires_mod && bet_requires_mod(comment)
            mark_requires_mod(comment)
        )

      end_bet = (siteName, comment_id)=>
        comment = @api.store.models.get(comment_id)
        if !comment || !comment.get('type') == 'BET'
          return cb({status: 403}, {notexists: true})
        if comment.get("bet_status") != 'open'
          return cb({status: 403}, {conflict: true})
        comment.set({
          bet_status: 'closed'
          bet_closed_at: new Date().getTime()
          _v: comment.get('_v') + 1
        })
        if comment.get('bet_accepted').length == 0
          comment.set({
            bet_winning_side: 'tie'
            bet_status: 'resolved'
            _v: comment.get('_v') + 1
          })
          if !comment.get("bet_start_forf_date")? || comment.get("bet_start_forf_date") <= comment.get("bet_end_date")
            return start_forf_bet(comment)
        cb(null, JSON.parse(JSON.stringify(comment)))

      start_forf_bet = (siteName, comment_id)=>
        comment = @api.store.models.get(comment_id)
        if !comment || !comment.get('type') == 'BET'
          return cb({status: 403}, {notexists: true})
        if comment.get("bet_status") != 'closed'
          return cb({status: 403}, {conflict: true})
        now = new Date().getTime()
        comment.set({
          bet_status: 'forf'
          bet_forf_started_at: now
          bet_close_forf_date: now + 48 * 3600 * 1000
          _v: comment.get('_v') + 1
        })
        return cb(null, JSON.parse(JSON.stringify(comment)))

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/forfeit_bet").exec(url))) )
        return forfeit_bet(match[1], match[2])

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/claim_bet").exec(url))) )
        return claim_bet(match[1], match[2])

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/end_bet").exec(url))) )
        return end_bet(match[1], match[2])

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/start_forf_bet").exec(url))) )
        return start_forf_bet(match[1], match[2])

      decline_bet = (siteName, comment_id)=>
        comment = @api.store.models.get(comment_id)
        if !comment || !comment.get('type') == 'BET'
          return cb({status: 403}, {notexists: true})
        if comment.get("bet_status") != 'open'
          return cb({status: 403}, {denied: true})
        accepted = comment.get("bet_accepted").find((t)=> t.id == @api.user.id)?
        if accepted
          return cb({status: 400}, {conflict: true})
        declined = comment.get("bet_declined").find((t)=> t.id == @api.user.id)?
        if declined
          return cb({status: 400}, {conflict: true})
        result = JSON.parse(JSON.stringify(comment.attributes))
        result.bet_declined = _.union(result.bet_declined, [@api.user.id])
        result._v += 1
        result.bet_tpts_av_tuser += result.bet_pts_tuser
        result.bet_tpts_av_ntusers += result.bet_pts_tuser
        return cb(null, result)

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/decline_bet").exec(url))) )
        return decline_bet(match[1], match[2])

      if method == 'POST' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/decline_bet").exec(url))) )
        siteName = match[1]
        bet = @api.store.models.get(match[2])
        if !bet?
          return cb({status: 404}, {notexists: true})
        if !bet.get('bet_targeted').contains(@api.user)
          return cb({status: 403}, {user_not_targeted: true})
        # TODO extra validation here
        if !bet.get('bet_declined').contains(@api.user)
          declined = bet.get('bet_declined').map((u)-> u.id)
          declined.push(@api.user.id)
          return cb(null, {_v: bet.get('_v') + 1, bet_declined: declined})
        return cb({status: 403}, {already_declined: true})

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/votes").exec(url))) )
        siteName = match[1]
        challenge = @api.store.models.get(match[2])
        if !challenge.get("challenged")
          return cb({status: 403})
        if challenge.get("challenged").get("author") == @api.user || challenge.get("challenger").get("author") == @api.user
          return cb({status: 403})
        if challenge.get("finished")
          return cb({status: 403}, {challenge_ended: true})
        comment = challenge.get(params.side)
        if (comment.votedBy?[@api.user.id] and params.up) or (!comment.votedBy?[@api.user.id] and !params.up)
          return cb({status: 403}, {denied: true})
        otherside = if params.side == 'challenged' then 'challenger' else 'challenged'
        if challenge.get(otherside).votedBy?[@api.user.id]
          return cb({status: 403}, {denied: true})
        up = if params.up then 1 else -1
        comment.set("votes": comment.get("votes") + up)
        comment.votedBy ?= {}
        if params.up
          comment.votedBy[@api.user.id] = true
        else
          comment.votedBy[@api.user.id] = false
        comment.set("no_votes": comment.get("no_votes") + up)
        challenge.set("rating": challenge.get("rating") + up)
        result = {
          _v: challenge.get("_v") + 1
          rating: challenge.get("rating") + up
          challenger: JSON.stringify(challenge.get('challenger'))
          challenged: JSON.stringify(challenge.get('challenged'))
        }
        result[params.side].no_votes = comment.get("no_votes") + up
        return cb?(null, result)

      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/likes").exec(url))) )
        siteName = match[1]
        comment = @api.store.models.get(match[2])
        if @api.user == comment.get("author")
          return cb({status: 403}, {like_own_comment: true})
        want_up = if params.up then 1 else -1
        up = 0
        down = 0
        comment.likedBy ?= {}
        if comment.likedBy[@api.user.id]?
          if want_up == comment.likedBy[@api.user.id]
            comment.likedBy[@api.user.id] = null
            if params.up
              up = -1
            else
              down = -1
          else
            if comment.likedBy[@api.user.id] == 1
              up = -1
              down = 1
            else
              up = 1
              down = -1
            comment.likedBy[@api.user.id] = want_up
        else
          comment.likedBy[@api.user.id] = want_up
          if params.up
            up = 1
          else
            down = 1
        result = {
          _v: comment.get("_v") + 1
          no_likes: comment.get("no_likes") + up
          no_likes_down: comment.get("no_likes_down") + down
          rating: comment.get("no_likes") - comment.get("no_likes_down")
        }
        return cb?(null, result)
      if method == 'PUT' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)/flag").exec(url))) )
        siteName = match[1]
        comment = @api.store.models.get(match[2])
        if comment.flaggedBy?[@api.user.id]
          return cb({status: 403}, {denied: true})
        comment.flaggedBy ?= {}
        comment.flaggedBy[@api.user.id] = true
        result =
          _v: comment.get("_v") + 1
          no_flags: comment.get("no_flags") + 1
          flagged: true
        return cb(null, result)
      if method == 'DELETE' && ( ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/activities/([a-zA-Z0-9]+)").exec(url))) )
        if !@api.user.get("profile").permissions.moderator
          return cb?({status: 403}, {needs_moderator: true})
        return cb?(null, {deleted: true})
      return cb?({status: 501})
    )

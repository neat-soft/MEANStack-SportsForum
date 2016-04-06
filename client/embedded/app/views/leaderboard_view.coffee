View = require('views/base_view')
CollectionView = require('views/collection_view')
UserLeaderView = require('views/userLeader_view')
PagedCollection = require("collections/paged_collection")
Profile = require("models/profile")
template = require("views/templates/leaderboard")
comparators = require("comparators")
analytics = require("lib/analytics")

module.exports = class Leaderboard extends View

  className: "leaderboard_view"
  template: template
  max_to_show: 10

  events:
    "click .ldb-hide": "hide"

  hide: (e)->
    @deactivate?()
    @$el.hide()
    @trigger('hide')

  show: (e)->
    @activate?()
    @$el.show()
    @trigger('show')

  initialize: ->
    super
    @FORMAT = "DD/MM/YYYY HH:mm"
    @all_badges = @app.api.site.get("badges")
    @app.api.site.get("active_competitions").fetch()
    @appIsForum = @app.isForum()
    @bindTo(@app.api.site, "change:active_competition change:active_competition.end change:active_competition.title", =>
      @updateCompetitionDetails(@app.api.site.get("active_competition"))
      @willRender()
    )

  events:
    "click .ldb-hide": "hideLeaderboard"
    "change .top_users": "changeLeaderboard"
    "click .go_to_top": "scrollTop"
    "click .go_up": "scrollUp"
    "click .go_down": "scrollDown"

  hideLeaderboard: (e)->
    @$el.hide()
    @trigger('hide')

  updateCompetitionDetails: (comp)->
    @competition = comp
    badge = @app.api.site.get("badges")?[@competition.get("badge_id")]
    if @competition.get("prize_url")
      competition_phrase = "competition_win_prize"
    else
      competition_phrase = "competition_win"
    @competition_win = @app.translate(competition_phrase, {
      badge_icon: badge?.icon || ""
      prize: @competition.get("prize") || ""
      prize_url: @competition.get("prize_url")
      end: moment.utc(@competition.get("end"), @FORMAT).local().format("MMMM Do YYYY"),
    })

  setActiveLeaderboard: (value, updateAnalytics)->
    @competition = null
    col = @collection
    @current_badge = null
    @min_rank = Number.MAX_VALUE
    @max_rank = 0
    selected = value
    if !selected?
      @select_users.append("<option value='site'>#{@app.translate("site_leaderboard")}</option>")
      selected = "site"
    if selected == "site"
      if updateAnalytics
        analytics.chooseLeaderboard("site")
      col = @app.api.site.get("profiles")
    else if selected == "conversation"
      col = @app.currentContext.get("convprofiles")
      if col.length == 0
        @app.currentContext.fetchLeaders()
      if updateAnalytics
        analytics.chooseLeaderboard("conversation")
    else if selected.slice(0, "competition".length) == "competition"
      comp_id = selected.slice("competition-".length)
      comp = @app.api.store.models.get(comp_id)
      comp.fetchLeaders()
      @updateCompetitionDetails(comp)
      col = comp.get("profiles")
      if updateAnalytics
        analytics.chooseLeaderboard("competition")
    else
      siteName = @app.api.site.get("name")
      BadgesCollection = class Badges extends PagedCollection
        model: require("models/badge_profile")
        url: "/api/sites/#{siteName}/badges/#{encodeURIComponent(selected)}/leaders"
      col = new BadgesCollection()
      @bindTo(col, "add change:rank", (model)=>
        rank = model.get("rank")
        if rank < @min_rank
          @min_rank = rank
        if rank > @max_rank
          @max_rank = rank
        @showScroll(col)
      )
      @bindTo(col, "remove", (model)=>
        rank = model.get("rank")
        if rank == @min_rank
          @min_rank += 1
        if rank == @max_rank
          @max_rank -= 1
        @showScroll(col)
      )
      col.fetch()
      @current_badge = @app.api.site.get("badges")[selected]
      if updateAnalytics
        analytics.chooseLeaderboard(@current_badge.title)
    if @setupCollection(col)
      @willRender()

  changeLeaderboard: (e)->
    new_sel = $(e.target).children().filter(":selected").val()
    if @selected == new_sel || new_sel == undefined
      return true
    @selected = new_sel
    # analytics.chooseLeaderboard(@selected)
    @setActiveLeaderboard(@selected, true)
    return true

  showScroll: (col)->
    @$(".show_top").addClass("display_none")
    @$(".show_bottom").addClass("display_none")
    @$(".nobody_has_points").addClass("display_none")
    if !col
      @$(".nobody_has_points").removeClass("display_none")
      return
    if @min_rank > 1 && @min_rank <= @max_rank && col.length > 1 && !isNaN(@selected)
      @$(".show_top").removeClass("display_none")
    else
      @$(".show_top").addClass("display_none")
      if col.length < 1 || (col.length == 1 && col.models[0].get("fake"))
        @$(".nobody_has_points").removeClass("display_none")

    if col.length < @max_to_show || isNaN(@selected)
      @$(".show_bottom").addClass("display_none")
    else
      @$(".show_bottom").removeClass("display_none")

  scrollTop: (e)->
    analytics.navLeaderboardTop()
    e.preventDefault()
    if !@current_badge
      return false
    @collection.fetch({data: {min_rank: 0}})

  scrollUp: (e)->
    analytics.navLeaderboardUp()
    e.preventDefault()
    if !@current_badge
      return false
    @collection.fetch({data: {min_rank: @min_rank - 1}})

  scrollDown: (e)->
    analytics.navLeaderboardDown()
    e.preventDefault()
    if !@current_badge
      return false
    mod = @collection.findWhere({rank: @min_rank})
    new_rank = @min_rank + 1
    @collection.remove(mod)
    @collection.fetch({data: {min_rank: new_rank}})

  setupCollection: (force)->
    if force
      new_col = force
    else
      if @has_active_competition
        type = "competition"
        if !@selected
          # nothing selected, default to the active competition
          @selected = "competition-#{comp.id}"
        @updateCompetitionDetails(comp)
      else
        new_col = @app.currentContext?.get?("convprofiles")
        if new_col != @collection && new_col?.length == 0
          @app.currentContext?.fetchLeaders?()
        type = "conversation"
    modified = false
    if new_col != @collection
      @collection && @unbindFrom(@collection)
      @collection = new_col
      @bindTo(@collection, "add remove", (model)=>
        @showScroll(@collection)
      )
      modified = true
    return modified

  cleanup: ->
    if @view("users")
      @unbindFrom(@view("users"), "render_child remove_child")
    super

  renderCompetitions: ->
    sel = @$(".top_users option:first")
    FillerCollectionView = class FillerCollectionView extends CollectionView
      addChildViewToDOM: (child, after)->
        if after
          return super
        sel.after(child)

    comps = @addView('competitions', new FillerCollectionView(
      collection: @app.api.site.get("active_competitions")
      elementView: class OptionView extends View
        tagName: "option"
        render: ->
          @$el.val("competition-#{@model.id}")
          @$el.text(@model.get("title"))
    ))
    @bindTo(@view('competitions'), 'render_child', (child_view)=>
      child_view.once('render', =>
        if !@selected && @has_active_competition && !@competition.get('badge_id')
          @select_users.val(child_view.$el.val()).trigger("change.customSelect").trigger('render.customSelect')
        if @selected == child_view.$el.val()
          @select_users.val(@selected).trigger("change.customSelect").trigger('render.customSelect')
      )
    )
    comps.render()

  getDefaultLeaderboard: ->
    # default to a random leaderboard
    options = @select_users.find("option")
    index = ~~(Math.random() * options.length)
    return options.eq(index).attr("value")

  render: ->
    @select_users = @$('.top_users')
    if !@select_users.hasClass("customSelect")
      # we need to activate customSelect only once; the operation must be defered
      # because the widget requires the DOM to be rendered before it can calculate
      # the width & height of the select box
      _.defer(=>
        if !@_disposed
          @select_users.customSelect()
      )
    @renderCompetitions()
    if @selected
      @select_users.val(@selected).trigger("change.customSelect").trigger('render.customSelect')
    else
      @selected = @getDefaultLeaderboard()
      @setActiveLeaderboard(@selected)

    @showScroll(@collection)
    @$(".rank_cutoff").html(@collection.models[0]?.get("rank_cutoff") || '')

    if !@collection
      return

    users = @addView("users", new CollectionView({
      collection: @collection,
      elementView: UserLeaderView,
      elementViewOptions:
        badge: @current_badge
      copy: true,
      top: @max_to_show,
      filter: (profile)=>
        if @current_badge
          return true
        perms = profile.get("permissions")
        points = profile.get("points")
        if !perms || ((!points || points <= 0) && profile.get("user") != @app.api.user)
          return false
        if @app.api.site.get("verified_leaderboard") && !profile.get("user")?.get?("verified")
          return false
        return !(perms.admin || perms.moderator)
      reconsiderOn: "change:user.verified change:rank"
    }))
    users.sort((if @current_badge then comparators.rankAsc else comparators.pointsDesc), {updateOn: "change:points"})
    @$(".users_view").replaceWith(users.render().el)

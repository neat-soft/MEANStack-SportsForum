View = require('views/base_view')
BetsView = require('views/bets_view')
CurrentUserView = require("views/currentUser_view")
HeaderLoginView = require("views/headerLogin_view")
ConvSubscriptionView = require("views/convSubscription_view")
NotificationsView = require("views/notifications_view")
CollectionView = require("views/collection_view")
ContextView = require("views/context_view")
ContextSummaryView = require("views/contextSummary_view")
UserView = require("views/user_view")
analytics = require("lib/analytics")
NewContextView = require("views/newContext_view")
SortCommentsView = require("views/sortComments_view")
LeaderboardView = require("views/leaderboard_view")
CompetitionAnnounceView = require("views/competitionAnnounce_view")
Competition = require("models/competition")
CompetitionDetailsView = require("views/competition_details_view")
CompetitionsView = require("views/competitions_view")
comparators = require("comparators")
tagSelectOptionTemplate = require('views/templates/tagSelectOption')
selectedFilterItemTemplate = require('views/templates/selectedFilterItem')
util = require('lib/util')
qs = require('lib/qs')
sharedUtil = require('lib/shared/util')

sort_mtd_pmap = {
  timeCreatedAsc: {sort: 'time', dir: 1},
  timeCreatedDesc: {sort: 'time', dir: -1},
  activitiesDesc: {sort: 'comments', dir: -1},
  activitiesAsc: {sort: 'comments', dir: 1},
  latestActivityDesc: {sort: 'latest_activity', dir: -1},
  latestActivityAsc: {sort: 'latest_activity', dir: 1},
  activityRatingDesc: {sort: 'activity_rating', dir: -1}
}

sort_analytics_map = {
  activityRatingDesc: "Most Activity",
  latestActivityDesc: "Latest Activity",
  latestActivityAsc: "Oldest Activity",
  activitiesDesc: "Most Comments",
  activitiesAsc: "Least Comments",
}

sort_mtd_to_params = (method)->
  sort_mtd_pmap[method]

sort_params_to_mtd = (params)->
  for own key, val of sort_mtd_pmap
    if params.sort == val.sort && parseInt(params.dir) == val.dir
      return key

module.exports = class Forum extends View

  className: 'forum_view'

  template: 'forum'

  events:
    "click .more": "fetchNextOnMore"
    "change .context_filter": "filterFromSelect"
    "click .create_thread": "createThread"
    "click .ldb-show": "showLeaderboard"
    "apply.daterangepicker #filter-date": "filterFromDate"
    "show.daterangepicker #filter-date": "setDatePickerDate"
    "click .filtering_options > .btn-filter.activity-rating": "filterActivityRating"
    "click .head-comments .full-columns": "sortByComments"
    "click .head-latest-activity .full-columns": "sortByActivity"
    "click .contextSummary_view .tag": "filterFromTag"
    "click .back-to-forums": "goToForums"
    "click .user_view .close": "closeUser"
    # "click .badge_view .close": "closeBadge"

  closeUser: (e)->
    e.stopPropagation()
    @closeUserProfile(true)

  closeBadge: (e)->
    e.stopPropagation()
    @closeBadgeDetails(true)

  initialize: ->
    super
    @rel_date = {
      today: @app.translate('date_filter_today')
      yesterday: @app.translate('date_filter_yesterday')
      last_7_days: @app.translate('date_filter_last_7_days')
      last_30_days: @app.translate('date_filter_last_30_days')
      this_month: @app.translate('date_filter_this_month')
      last_month: @app.translate('date_filter_last_month')
      all: @app.translate('date_filter_all')
    }
    @date_ranges = _.object([
      [@app.translate('date_filter_today'), [moment().startOf('day'), moment().endOf('day')]],
      [@app.translate('date_filter_yesterday'), [moment().subtract(1, 'days').startOf('day'), moment().subtract(1, 'days').endOf('day')]],
      [@app.translate('date_filter_last_7_days'), [moment().subtract(6, 'days').startOf('day'), moment().endOf('day')]],
      [@app.translate('date_filter_last_30_days'), [moment().subtract(29, 'days').startOf('day'), moment().endOf('day')]],
      [@app.translate('date_filter_this_month'), [moment().startOf('month'), moment().endOf('month')]],
      [@app.translate('date_filter_last_month'), [moment().subtract(1, 'month').startOf('month'), moment().subtract(1, 'month').endOf('month')]],
      [@app.translate('date_filter_all'), [moment(0), moment().add(100, 'years').endOf('day')]]
    ])
    @$el.addClass("HAS_MORE")
    @bindTo(@model.get("contexts"), "add", (c, col, options)->
      if @filter_options.tags.length > 0 && options.rt && _.intersection(c.get("tags"), @filter_options.tags).length > 0
        @model.inc("no_conversations_filtered")
    )
    @bindTo(@model, "change:no_forum_conversations change:no_conversations_filtered", @updateConvCount)
    @app.api.initRtSite()
    @appIsForum = @app.isForum()
    available_tags = @app.api.site.get('forum').tags || []
    @bindTo(@app, 'manual_size', @manual_size_table)
    @default_filter = _.extend({tags: [], filter: 'all'}, sort_mtd_to_params(@model.get("forum").defsort || "activityRatingDesc"))
    @filter_options = _.clone(@default_filter)

  updateConvCount: ->
    value = @model.get(if @filter_options.tags then "no_conversations_filtered" else "no_forum_conversations")
    @$(".no_conversations").text(@app.translate("no_conversations", {value: value}))
    if !@model.hasMoreContexts(@filter_options.tags.length > 0)
      @$el.removeClass("HAS_MORE")
    else
      @$el.addClass("HAS_MORE")

  fetchNextOnMore: ->
    @fetchNext()

  fetchNext: (options)->
    options ?= {}
    _.extend(options, {
      remove: false
      success: (resp)=>
        if !@model.hasMoreContexts(@filter_options.tags.length > 0)
          @$el.removeClass("HAS_MORE")
        @$el.removeClass("LOADING_MORE LOADING")
      error: =>
        @$el.removeClass("LOADING_MORE LOADING")
    })
    @$el.addClass("HAS_MORE")
    @model.get("contexts").fetchNext(options)
    if @_rendered
      @$el.addClass("LOADING_MORE")
    else
      @$el.addClass("LOADING")

  createThread: (e)->
    @view('newContext').focused()

  showLeaderboard: (e)->
    @view('leaderboard').show()
    @$('#contexts > #contexts_wrapper > .ldb-show').hide()

  showLdbMarker: (e)->
    @$('#contexts > #contexts_wrapper > .ldb-show').show()

  sortByComments: (e)->
    filter = _.clone(@filter_options)
    if filter.sort == 'comments'
      filter.dir = -filter.dir
    else
      filter.sort = 'comments'
      filter.dir = -1
    e.stopPropagation()
    interaction = sort_analytics_map[if filter.dir > 0 then "activitiesAsc" else "activitiesDesc"]
    if interaction?
      analytics.forumSort(interaction)
    @navigate(filter)

  sortByActivity: (e)->
    filter = _.clone(@filter_options)
    if filter.sort == 'latest_activity'
      filter.dir = -filter.dir
    else
      filter.sort = 'latest_activity'
      filter.dir = -1
    e.stopPropagation()
    interaction = sort_analytics_map[if filter.dir > 0 then "latestActivityAsc" else "latestActivityDesc"]
    if interaction?
      analytics.forumSort(interaction)
    @navigate(filter)

  filterActivityRating: (e)->
    filter = _.extend({}, @default_filter, @filter_options)
    filter.sort = 'activity_rating'
    filter.dir = -1
    delete filter.tfrom
    delete filter.tuntil
    filter.filter = 'all'
    filter.tags = []
    e.stopPropagation()
    @navigate(filter)

  filterFromTag: (e)->
    tag = $(e.target).attr('data-tag')
    filter = _.clone(@filter_options)
    filter.tags = [tag]
    e.stopPropagation()
    e.preventDefault()
    @navigate(filter)

  filterFromSelect: (e)->
    if @skip_handler_tags
      return
    tag = @$tags_filter.val()
    # tag == '' immediately after clearing options. We don't want to continue
    # in that case
    if (tag in @filter_options.tags) || tag == ' ' && @filter_options.tags.length == 0 || tag == ''
      return
    # @filter_options.tags = [tag]
    filter = _.clone(@filter_options)
    if sharedUtil.removeWhite(tag)
      filter.tags = [tag]
    else
      delete filter.tags
    # if tag && $(@$tags_filter[0].selectize.getOption(tag)).prev().length > 0
      # Backbone.history.navigate("#brzn/contexts/tags/#{tag}", {trigger: true})
    # else
      # Backbone.history.navigate("#brzn/contexts", {trigger: true})
    @navigate(filter)
    e.stopPropagation()

  resetTagsFilter: ->
    @skip_handler_tags = true
    @$tags_filter[0].selectize.clearOptions()
    @$tags_filter[0].selectize.addOption(@select_options)
    @$tags_filter[0].selectize.refreshOptions(false)
    @skip_handler_tags = false

  filter: (filter)->
    # set default values for the filter
    if _.isEmpty(filter)
      filter = @default_filter
    filter.tags ?= []
    filter.filter ?= []
    if filter.tfrom
      filter.tfrom = parseInt(filter.tfrom)
    if filter.tuntil
      filter.tuntil = parseInt(filter.tuntil)
    if filter.trel
      if !@rel_date[filter.trel]
        delete filter.trel
    if !filter.trel && !filter.tfrom && !filter.tuntil
      filter.trel = 'all'
    if filter.dir
      filter.dir = parseInt(filter.dir) || 0

    prev_filter = @filter_options
    @filter_options = _.extend({}, @default_filter, filter)
    if _.isEqual(@filter_options, prev_filter)
      return
    @resetTagsFilter()
    sel = @$tags_filter[0].selectize
    if @filter_options.tags.length > 0
      allowContexts = (c)=>
        return _.intersection(c.get("tags"), @filter_options.tags).length > 0
      @view("contexts").options.filter = allowContexts
      @model.set("no_conversations_filtered": 0)
      if @$tags_filter[0].selectize.getValue() != @filter_options.tags[0]
        if @$tags_filter[0].selectize.getOption(@filter_options.tags[0]).length == 0
          @skip_handler_tags = true
          @$tags_filter[0].selectize.addOption({
            displayName: @filter_options.tags[0],
            parent: null,
            level: 0,
            parents: [],
            initial_order: -1,
            search: @filter_options.tags[0]
          })
          @$tags_filter[0].selectize.refreshOptions(false)
          @skip_handler_tags = false
        @$tags_filter[0].selectize.setValue(@filter_options.tags[0], true)
    else
      @view("contexts").options.filter = null
      @$tags_filter[0].selectize.setValue(' ', true)
    @$(".context_filter").val(@filter_options.tags[0] || "")
    @updateConvCount()
    if @filter_options.sort == 'activity_rating'
      col_sort_opts = {updateOn: "change:#{@filter_options.sort} change:latest_activity change:_id"}
    else
      col_sort_opts = {updateOn: "change:#{@filter_options.sort}"}
    @view("contexts").sort(comparators[sort_params_to_mtd(_.pick(@filter_options, 'sort', 'dir'))], col_sort_opts)

    if @filter_options.trel
      date_filter_str = @app.translate("date_filter_#{@filter_options.trel}")
    else
      if @filter_options.tfrom
        start_date = moment(@filter_options.tfrom)
        start_date_str = start_date.format('MMMM D, YYYY') + ' - '
      else
        start_date_str = ''
      if @filter_options.tuntil
        end_date = moment(@filter_options.tuntil)
        end_date_str = end_date.format('MMMM D, YYYY')
      else
        end_date_str = 'now'
      date_filter_str = start_date_str + end_date_str
      if !@filter_options.tfrom? && !@filter_options.tuntil?
        date_filter_str = @app.translate('date_filter_all')
    @$('#filter-date span').text(date_filter_str)

    @updateSortingElements(prev_filter)
    @update_contexts(@filter_options, !_.isEqual(@filter_options.tags, prev_filter.tags))

  updateSortingElements: (prev_filter)->
    all_sort_classes = [
      'SORT_COMMENTS'
      'SORT_ACTIVITY_RATING'
      'SORT_LATEST_ACTIVITY'
      'SORT_TIME'
      'SORT_UP'
      'SORT_DOWN'
    ]
    dir_to_str = {}
    dir_to_str[1] = 'UP'
    dir_to_str[-1] = 'DOWN'
    @$el.removeClass(all_sort_classes.join(' '))
    @$el.addClass("SORT_#{(@filter_options.sort || '').toUpperCase()}")
    @$el.addClass("SORT_#{dir_to_str[@filter_options.dir]}")
    @$('#contexts_collection .column-sorter select')
      .val(sort_params_to_mtd(@filter_options))
      # .trigger('change.customSelect')
      .trigger('render.customSelect')

  filterFromSort: (method)->
    params = sort_mtd_to_params(method) || {dir: -1, sort: 'time'}
    filter = _.extend(_.clone(@filter_options), params)
    @navigate(filter)

  update_contexts: (filter, forceRefresh = false)->
    filter = _.clone(filter)
    if filter.trel
      date_ranges = @date_ranges[@rel_date[filter.trel]]
      if date_ranges
        filter.tfrom = Math.max(@app.serverTimeCorrected(date_ranges[0].valueOf()), 0)
        filter.tuntil = Math.max(@app.serverTimeCorrected(date_ranges[1].valueOf()), 0)
      delete filter.trel
    if @model.hasMoreContexts(false, true)
      @model.removeAllContexts()
      @fetchNext({data: filter, restart: true})
    else if forceRefresh
      @view("contexts").render(true)
    @model.fetchContextsCountByFilter(filter)
    @updateConvCount()

  beforeRender: ->
    @loggedIn = @app.api.loggedIn()

  cleanup: ->
    super
    @view("contexts") && @unbindFrom(@view("contexts"))

  render: ->
    if !@app.api.loggedIn()
      @app.views.login = new HeaderLoginView()
      @$(".headerLogin_view").replaceWith(@addView("headerlogin", @app.views.login).render().el)
    else
      @$(".currentUser_view").replaceWith(@addView("currentuser", new CurrentUserView(model: @app.api.user)).render().el)
    @app.views.competitions = @addView("competitions", new CompetitionsView(collection: @app.api.site.get("competitions")))
    @$(".newContext_view").replaceWith(@addView("newContext", new NewContextView(allowQuestion: true)).render().el)
    @app.views.bets = @addView("bets", new BetsView(model: @model))

    class ContextsView extends CollectionView
      cleanElements: ->
        @$el.children('.contextSummary_view').remove()

      addChildViewToDOM: (child, after_el)->
        # pass
        if after_el
          after_el.after(child)
        else
          @$el.children('tr.bets_thread').last().after(child)

    @app.views.contexts = @addView("contexts", new ContextsView(collection: @model.get("contexts"), elementView: ContextSummaryView, tagName:'tbody', className: 'contexts_view', el: @$('.contexts_view')[0]))
    @$(".content_forum > #competitions").append(@app.views.competitions.el)
    @$(".competitionAnnounce_view").replaceWith(@addView("competition_announce", new CompetitionAnnounceView()).render().el)
    @$(".content_forum > #bets").append(@app.views.bets.el)
    # @$(".contexts_view").replaceWith(@app.views.contexts.render().el)
    app.views.contexts.render()
    @$(".convSubscription_view").replaceWith(@addView("convSubscription", new ConvSubscriptionView(model: @app.api.user)).render().el)
    @app.views.notifications = @addView("notifications", new NotificationsView())
    @$(".notifications_view").replaceWith(@app.views.notifications.render().el)
    @$tags_filter = @$(".context_filter")
    @select_options = @model.inlineTags()
    @select_options.unshift({displayName: ' ', blank: true, initial_order: -1})
    @$tags_filter.selectize(
      create: true
      persist: false
      labelField: "displayName"
      valueField: "displayName"
      plugins: ['remove_button']
      options: @select_options
      sortField: [{field: 'initial_order', direction: 'asc'}]
      searchField: ['search']
      render:
        option: (data, escape)->
          return tagSelectOptionTemplate(data)
        item: (data, escape)->
          return selectedFilterItemTemplate(data)
    )
    $(@$tags_filter[0].selectize.$dropdown).addClass('CHECK-HEIGHT')
    $main_view_el = @app.views.main.$el
    old_positionDropdown = @$tags_filter[0].selectize.positionDropdown
    @$tags_filter[0].selectize.positionDropdown = ->
      old_positionDropdown.call(this)
      parent = @$dropdown.offsetParent()
      @$dropdown.css({width: $main_view_el.width() + 'px', left: -parent.offset().left})

    @$("#contexts > #contexts_wrapper > .leaderboard").append(@addView("leaderboard", new LeaderboardView()).render().el)
    @bindTo(@view('leaderboard'), 'hide', @showLdbMarker)
    @$('#filter-date').daterangepicker({
      timePicker: false,
      showDropdowns: true,
      minDate: moment(0).toDate(),
      maxDate: moment(0).add(100, 'years').toDate(),
      ranges: @date_ranges,
      buttonClasses: ['btn-embed'],
      applyClass: 'btn-primary',
      cancelClass: 'btn-default',
      linkedCalendars: false,
      template: require('views/templates/daterangepicker')(this),
      locale: {
        separator: @app.translate('date_filter_separator'),
        applyLabel: @app.translate('date_filter_apply'),
        cancelLabel: @app.translate('date_filter_cancel'),
        fromLabel: @app.translate('date_filter_from'),
        toLabel: @app.translate('date_filter_to'),
        customRangeLabel: @app.translate('date_filter_custom'),
        daysOfWeek: moment.weekdaysShort(),
        monthNames: moment.months(),
        firstDay: moment.localeData().firstDayOfWeek()
      }
    })
    $('body').children('.daterangepicker').addClass('CHECK-HEIGHT')
    @renderMobileSorts()

  renderMobileSorts: ->
    column_html = (selected)=>
      sort_field = sort_mtd_to_params(selected.val())?.sort || ''
      sort_field = sort_field.replace('_', '-')
      return @$("#contexts_collection").children(".table_head").find("td.head-#{sort_field} .full-columns").html()
    sort_for_col_comments = new SortCommentsView(
      template: 'sortContexts',
      className: 'mobile column-sorter touch',
      id: "mobile-sort-comments",
      initialValue: @filter_options.sort
      customSelect: {
        displayHtml: column_html
      }
    )
    @$(".head-comments > .mobile.column-sorter").replaceWith(sort_for_col_comments.render().el)
    @bindTo(sort_for_col_comments, 'sort', (mtd)->
      @sortByMethod(mtd)
    this)
    sort_for_col_latest = new SortCommentsView(
      template: 'sortContexts',
      className: 'mobile column-sorter touch',
      id: "mobile-sort-latest-activity",
      initialValue: @filter_options.sort
      customSelect: {
        displayHtml: column_html
      }
    )
    @$(".head-latest-activity > .mobile.column-sorter").replaceWith(sort_for_col_latest.render().el)
    @bindTo(sort_for_col_latest, 'sort', (mtd)->
      @sortByMethod(mtd)
    this)

  sortByMethod: (mtd)->
    interaction = sort_analytics_map[mtd]
    if interaction?
      analytics.forumSort(interaction)
    params = sort_mtd_to_params(mtd)
    filter = _.extend({}, @filter_options, params)
    @navigate(filter)

  setDatePickerDate: (e, picker)->
    if @filter_options.trel
      picker.chosenLabel = @rel_date[@filter_options.trel]
      range_elems = picker.container.find('.ranges li')
      picker.container.find('.ranges li').removeClass('active').each((i, elem)->
        if $(elem).text() == picker.chosenLabel
          $(elem).addClass('active')
      )
    else
      picker.setStartDate(@filter_options.tfrom && @app.localTimeCorrected(@filter_options.tfrom) || moment(0))
      picker.setEndDate(@filter_options.tuntil && @app.localTimeCorrected(@filter_options.tuntil) || moment(0).add(100, 'years').endOf('day'))
      picker.chosenLabel = @app.translate('date_filter_custom')

  filterFromDate: (e, picker)->
    filter = _.clone(@filter_options)
    if picker.chosenLabel != @app.translate('date_filter_custom')
      filter.trel = _.invert(@rel_date)[picker.chosenLabel]
      delete filter.tfrom
      delete filter.tuntil
    else
      filter.tfrom = picker.startDate.valueOf()
      filter.tuntil = picker.endDate.valueOf()
      delete filter.trel
    e.stopPropagation()
    @navigate(filter)

  forumUrl: (filter)->
    return '#brzn/contexts' + (filter && ('?' + qs.stringify(filter)) || '')

  navigate: (filter)->
    @app.goUrl(@forumUrl(filter))

  preparePlaceholders: (navName)->
    @$("#navigation > li").removeClass("active")
    if navName
      @$("#navigation > li.nav-#{navName}").addClass("active")
    @$(".content_forum > .tab-pane").removeClass("active")

  displayView: (viewName)->
    @$(".content_forum > ##{viewName}").addClass("active")
    @activeView = @view(viewName)
    @activeView.activate?()
    @trigger("change:view", this, @activeView)

  catView: (navName)->
    if @activeView == @app.views[navName]
      return
    @preparePlaceholders(navName)
    @view('current_context')?.remove()
    @$("#navigation a[href='#brzn/#{navName}']").tab("show")
    if !@app.views[navName]._rendered
      @app.views[navName].render()
    @displayView(navName)

  itemView: (viewType, viewName, modelId, navName)->
    @preparePlaceholders(navName)
    view = @view(viewName)
    if view
      if view.model.id != modelId
        view.remove()
        view = null
    if !view
      model = @app.api.store.models.get(modelId)
      if model
        @$(".content_forum > ##{viewName}").append(@addView(viewName, view = new viewType(model: model)).render().el)
    view && @displayView(viewName)

  historyBack: (e)->
    e.preventDefault()
    e.stopPropagation()
    @app.goBack()

  goToForums: (e)->
    e.preventDefault()
    e.stopPropagation()
    @app.goUrl(@forumUrl(@filter_options))

  showCompetitionDetails: (id)->
    if !@app.api.store.models.get(id)
      new Competition({_id: id})
    @itemView(CompetitionDetailsView, "competition_details", id)

  showCompetitions: ->
    if @activeView == @view("competitions")
      return
    @catView("competitions")

  showContexts: ->
    if @activeView == @view("contexts")
      return
    @catView("contexts")
    analytics.toContexts()
    if !@_rendered
      @render()
    @app.currentContext = null
    @app.trigger("change:currentContext")
    @$el.removeClass("IN_CONTEXT")

  showContext: (id, callback)->
    Context = require('models/context')
    ctx = @app.api.store.getCollection(Context, true).get(id)

    do_show = =>
      @app.currentContext = ctx
      @app.trigger("change:currentContext")
      @itemView(ContextView, "current_context", ctx.id, "current_context")
      @view('current_context').showComments()
      @$el.addClass("IN_CONTEXT")

    if ctx && ctx.get("site")
      do_show()
      callback?()
    else
      @model.fetchContext(id, {
        success: =>
          ctx = @app.api.store.getCollection(Context, true).get(id)
          do_show()
          callback?()
        error: (model, resp)=>
          callback?(resp)
      })

  showBets: ()->
    if @activeView == @view('bets')
      return
    if @app.currentContext
      @app.currentContext = null
      @app.trigger('change:currentContext')
    if !@_rendered
      @render()
    @catView('bets')
    @$el.removeClass("IN_CONTEXT")

  showCommentInContext: (idctx, idco)->
    @showContext(idctx, (err)=>
      if !err
        @view('current_context').scrollToComment(idco)
    )

  dispose: ->
    @unbindFrom(@model.get("contexts"))
    @app.api.disposeRtSite()
    super

_.extend(Forum.prototype, require('views/mixins').app_popups)

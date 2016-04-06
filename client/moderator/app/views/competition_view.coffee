View = require("views/base_view")
template = require("views/templates/competition")
edit_template = require("views/templates/edit_competition")
CollectionView = require("views/collection_view")
ProfileView = require("views/competition_profile_view")

module.exports = class Competition extends View

  className: "competition_view"

  notify_parent: null

  initialize: ->
    super
    @bindTo(@model, "change", @render)
    # we presume operations succeed and only re-render on errors
    # this avoids any flickering effects
    @bindTo(@model, "error", @render)
    if @model.isNew()
      @template = edit_template
    @FORMAT = "DD/MM/YYYY HH:mm"
    @all_badges = @app.api.site.get("badges")

  beforeRender:->
    # format start/end in selected timezone format
    @tz = @app.api.site.get("tz_name")
    if @model.isNew()
      @start_tz = ""
      @end_tz = ""
    else
      @start_tz = moment.utc(@model.get("start"), @FORMAT)?.tz(@tz).format(@FORMAT) || ""
      @end_tz = moment.utc(@model.get("end"), @FORMAT)?.tz(@tz).format(@FORMAT) || ""

    @error = null
    if @pending_error
      @error = @pending_error
      @pending_error = null
    @ended = @model.get("end") < moment.utc().format(@FORMAT)

  render: ->
    @$(".competition-profiles .placeholder").replaceWith(@addView("competition-profiles", new CollectionView(className: "profiles", collection: @model.get("profiles"), elementView: ProfileView)).render().el)
    $("[rel=tooltip]").tooltip({ trigger: "hover" })
    $('.input_competition_start').daterangepicker({
      singleDatePicker: true,
      timePicker: true,
      timePickerIncrement: 15,
      timePicker12Hour: false,
      locale:
        format: 'DD/MM/YYYY HH:mm'
    })
    $('.input_competition_end').daterangepicker({
      singleDatePicker: true,
      timePicker: true,
      timePickerIncrement: 15,
      timePicker12Hour: false,
      locale:
        format: 'DD/MM/YYYY HH:mm'
    })

  edit: ->
    @template = edit_template
    @render()

  save: ->
    fresh = @model.isNew()
    start = @$("#input_competition_start").val()
    if !moment(start, @FORMAT)?.isValid()
      start = ""
    end = @$("#input_competition_end").val()
    if !moment(end, @FORMAT)?.isValid()
      end = ""
    attrs = {
      title: @$("#input_competition_title").val()
      community: @$("#input_competition_community").val()
      start: if start then moment.tz(start, @FORMAT, @tz).utc().format(@FORMAT) else ""
      end: if end then moment.tz(end, @FORMAT, @tz).utc().format(@FORMAT) else ""
      prize: @$("#input_competition_prize").val()
      prize_url: @$("#input_competition_prize_url").val()
      rules_url: @$("#input_competition_rules_url").val()
      social_share: @$("#input_competition_share").prop("checked")
      verified: @$("#input_competition_verified").prop("checked")
      badge_id: @$("#input_competition_badge").val() || null
    }
    _.extend(@model.attributes, attrs)
    @model.save(attrs, {
      wait: true
      success: =>
        if fresh
          @remove()
          @notify_parent()
          return
        @template = template
        @render()
        return false
      error: (model, res)=>
        @pending_error = res.responseText
        return false
    })
    return false

  cancel: ->
    if @model.isNew()
      @model.destroy()
      @remove()
    else
      @model.fetch()
      @template = template
      @render()

  delete: ->
    @model.destroy({
      wait: true
      error: (model, res)=>
        @error = res.responseText
        return true
    })
    return false

  leaderboard: ->
    if @$(".competition-profiles").hasClass("display_none")
      @model.fetchLeaders()
      @$(".competition-profiles").removeClass("display_none")
    else
      @$(".competition-profiles").addClass("display_none")

  template: template

  events:
    "click .edit-competition": "edit"
    "click .save-competition": "save"
    "click .cancel-competition": "cancel"
    "click .remove-competition": "delete"
    "click .view-leaderboard": "leaderboard"


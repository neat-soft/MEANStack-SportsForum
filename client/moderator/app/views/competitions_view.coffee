View = require("views/base_view")
template = require("views/templates/competitions")
Competition = require("models/competition")
CollectionView = require("views/collection_view")
CompetitionView = require("views/competition_view")

module.exports = class Competitions extends View

  className: "competitions_view"

  initialize: ->
    super
    @prev = 0

  render: ->
    @$(".competitions").replaceWith(@addView("competitions", new CollectionView(className: "competitions", collection: @collection, elementView: CompetitionView)).render().el)
    @view("competitions").$el.scroll(@scroll)

  template: template

  events:
    "click .add-competition": "add_new"

  scroll: =>
    area = @view("competitions").$el
    if area.scrollTop() > @prev
      if area.prop("scrollHeight") - area.scrollTop() - area.height() < 50 && !@disabled
        @fetchNext()
    @prev = area.scrollTop()

  signal: =>
    @refresh()

  add_new: ->
    v = new CompetitionView(className: "competition", model: new Competition({
      verified: @model.get("verified_leaderboard"),
      rules_url: "http://help.theburn-zone.com/customer/portal/articles/1499936-how-do-i-join-a-competition"
    }))
    v.notify_parent = @signal
    @$(".new-competition").append(@addView("competition", v).render().el)
    #@render()
    #@refresh()
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
    return false

  refresh: ->
    @disabled = false
    @view("competitions").$el.scrollTop(0)
    @fetchNext({reset: true, silent: false, restart: true})
    return false

  activate: ->
    @refresh()

  fetchNext: (options)->
    @disabled = true
    @$el.addClass("disabled")
    done = =>
      @disabled = false
      @$el.removeClass("disabled")
    _.extend(options ?= {}, {
      data:
        moderator: true
        sort: "time"
        dir: 1
      resetSession: false
      success: done
      error: done
      add: true
      merge: true
      remove: false
    })
    @collection.fetchNext(options)

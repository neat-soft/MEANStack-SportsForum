module.exports = class PollSubscriber

  constructor: (options)->
    options ?= {}
    @baseUrl = options.baseUrl || "/"
    @channel = options.channel || ""
    @url = @baseUrl + @channel
    @period = options.period
    @options = options.options
    @lastUpdate = new Date().getTime()

  _success: (data, status, xhr)=>
    if @running
      @options.since = data.time
      @trigger("data", data, this)
      @_startTimer()

  _error: (xhr, status, ex)=>
    if @running
      @trigger("error", {status: status, error: ex})
      @_startTimer()

  _requester: =>
    $.ajax(@url, {
      data: @options
      type: "GET"
      dataType: "json"
      cache: false
      success: @_success
      error: @_error
    })

  _startTimer: ->
    clearTimeout(@timer)
    @timer = setTimeout(@_requester, @period)

  start: ->
    @stop()
    @_requester()
    @running = true

  stop: ->
    clearTimeout(@timer)
    @running = false
    @timer = null

_.extend(PollSubscriber.prototype, Backbone.Events)

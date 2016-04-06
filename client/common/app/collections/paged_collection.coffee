module.exports = class PagedCollection extends Backbone.GraphCollection

  initialize: ->
    super

  # response is:
  # {data: [], from: "from"}
  parse: (response, options)->
    if response.from
      @from = response.from || @from # if response.from is null then next time try reuse the old @from
    else
      @from = null
    return response.data || []

  fetch: (options)->
    resetSession = options?.resetSession ? true
    if resetSession
      delete @from
    super

  fetchNext: (options)->
    options = _.extend({}, options, {
      parse: true
    })
    if options.restart
      @from = null
    if options.data
      @lastData = _.extend({}, @lastData, _.clone(options.data))
    else if @lastData
      options.data = _.clone(@lastData)
    if @from
      options.data ?= {}
      options.data.from = @from
    @fetch(_.extend(options, {add: true}))

  hasMore: ->
    # from is either undefined or a value !== null
    return @from != null

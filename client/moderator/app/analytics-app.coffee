AnalyticsView = require("views/analytics_view")
Site = require("models/site")
HttpRequest = require("lib/httprequest")
User = require("models/user")
localization = require("localization")

module.exports = class AnalyticsApplication

  initialize: (options, container)->
    @options = options ? {}
    @views = {}
    @views.main = new AnalyticsView(model: @api.site)
    @container = container
    @container.append(@views.main.render().el)

  # Expose useful methods here
  translate: localization.translate

  format_date: (d)->
    return d.format("YYYY-MM-DD-HH-mm")

  trans: (arr, scale, func)->
    out = []
    for x in arr
      out.push([x[0], scale * Math.abs(func(x[1]))])
    return out

  test_stats: (from, to)->
    s = moment(from)
    stat = []
    while s < moment(to)
      stat.push([s.valueOf(), stat.length])
      s.add("days", 1)

    return {
      loads: @trans(stat, 2000, Math.sin)
      comments: @trans(stat, 2000, Math.cos)
      conversations: @trans(stat, 2000, (x)->
        Math.sin(x) + Math.cos(x)
      )
      notifications: @trans(stat, 2000, (x)->
        Math.sin(x) * Math.sin(x)
      )
      profiles: @trans(stat, 2000, (x)->
        Math.cos(x) * Math.cos(x)
      )
      subscriptions: @trans(stat, 2000, (x)->
        Math.sin(x) - Math.cos(x)
      )
      verified: stat
    }

  get_site_stats: (from, to, cb)->
    if window.location.href.indexOf("?test-stats=1&") >= 0
      cb?(null, @test_stats(from, to))
    else
      @api.get_site_stats(@format_date(from), @format_date(to), (err, result)->
        cb?(err, result)
      )

_.extend(AnalyticsApplication.prototype, Backbone.Events)

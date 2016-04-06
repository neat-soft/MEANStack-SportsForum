$(document).ready(->

  require("backbone-setup")
  require("rivets-setup")
  require("template-setup")
  localization = require("localization")

  # will load any language here in the future
  localization.loadTerms(localization.terms)

  Api = require('lib/api')
  serverType = require('lib/httprequest')
  rtType = require('lib/rt').remote
  server = new serverType()
  api = new Api()
  server.initialize({api: api})
  rt = new rtType()
  # site = _.extend(window.conversaitData.site, name: @siteName, verified_leaderboard: options.verified_leaderboard, timezone: options.timezone, badges: options.badges)
  api.initialize({rt: rt, server: server, site: window.conversaitData.site})
  api.userLogin(window.conversaitData.user)
  appData = _.extend({}, window.conversaitData, {
    api: api,
    rt: rt
  })
  if window.conversaitData.type == "analytics"
    AnalyticsApplication = require("analytics-app")
    window.app = new AnalyticsApplication()
    window.app.initialize(appData, $("#conversait_moderator"))
  else
    Application = require("application")
    window.app = new Application()
    window.app.initialize(appData, $("#conversait_moderator"))
)

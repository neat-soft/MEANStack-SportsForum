module.exports.collections = collections = {}

module.exports.init = (dbs, callback)->

  module.exports.db = dbs.app

  # complex collections follow here
  names = [
    'conversations'
    'comments'
    'users'
    'profiles'
    'convprofiles'
    'competition_profiles'
    'sites'
    'jobs'
    'subscriptions'
    'notifications'
    'competitions'
    'transactions'
    'badges'
  ]
  for name in names
    Type = require("./#{name}")
    collections[name] = new Type({db: dbs.app, name: name})

  # simple collections follow here
  BaseCol = require("./base")
  collections.votes = new BaseCol({db: dbs.app, name: "votes"})
  collections.shares = new BaseCol({db: dbs.app, name: "shares"})
  collections.likes = new BaseCol({db: dbs.app, name: "likes"})
  collections.locks = new BaseCol({db: dbs.app, name: "locks"})
  collections.page_view_count = new BaseCol({db: dbs.app, name: "page_view_count"})
  if dbs.log
    collections.logs = new BaseCol({db: dbs.log, name: "logs"})

  callback()

module.exports.db = null

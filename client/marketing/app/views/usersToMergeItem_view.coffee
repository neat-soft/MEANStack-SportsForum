View = require("views/base_view")
util = require("lib/util")

module.exports = class UsersToMergeItem extends View

  className: "usersToMergeItem_view"
  template: 'usersToMergeItem'

  events:
    'click .merge_account': 'merge'

  initialize: ->
    super
    @bindTo(@model, 'change', @render)

  merge: ->
    @app.api.user.mergeWith(@model)
    return false

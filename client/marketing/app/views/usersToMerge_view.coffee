View = require("views/base_view")
CollectionView = require("views/collection_view")
UsersToMergeItemView = require("views/usersToMergeItem_view")
util = require("lib/util")

module.exports = class UsersToMerge extends View

  className: "usersToMerge_view"
  template: 'usersToMerge'

  events:
    'merge': 'merge'

  render: ->
    @$('.users_to_merge').replaceWith(@addView('collection', new CollectionView(collection: @collection, emptyText: "There are no users to merge", elementView: UsersToMergeItemView)).render().el)
    @collection.fetch()

  merge: ->
    return false

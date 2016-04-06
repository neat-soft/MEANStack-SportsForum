View = require('views/base_view')
AttributeView = require("views/attribute_view")
CommentView = require("views/comment_view")
PagedCollectionView = require("views/pagedCollection_view")
SimpleCommentView = require("views/simple_comment_view")
SimpleChallengeView = require("views/simpleChallenge_view")

simple_activity_view = (options)->
  if options.model.get('type') == 'CHALLENGE'
    return new SimpleChallengeView(options)
  else
    return new SimpleCommentView(options)

module.exports = class FundedComments extends View
  className: "fundedComments_view CHECK-HEIGHT"

  template: 'fundedComments'

  events:
    'click .show-for-conv': 'showForConv'
    'click .show-for-site': 'showForSite'

  render: ->
    # @model.get('site').get('funded_activities').reset()
    # @model.get('funded_activities').reset()
    @$('.funded-comments-site').append(@addView("col_for_site", new PagedCollectionView({
      collection: @model.get('site').get("funded_activities"),
      className: "for_site_collection_view",
      collection_view_options: {
        elementView: simple_activity_view,
        className: 'collection_view',
        collection: @model.get('site').get('funded_activities'),
        emptyText: @app.translate('empty_collection_generic')
      },
      fetch_options: {
        funded: true
      }
    })).el)
    @$('.funded-comments-conv').append(@addView("col_for_conv", new PagedCollectionView({
      collection: @model.get("funded_activities"),
      className: "for_conv_collection_view",
      collection_view_options: {
        elementView: simple_activity_view,
        className: 'collection_view',
        collection: @model.get('funded_activities'),
        emptyText: @app.translate('empty_collection_generic')
      },
      fetch_options: {
        funded: true
      }
    })).el)
    _.defer(=>
      @showForConv()
    )

  showForConv: (e)->
    e?.stopPropagation()
    e?.preventDefault()
    @$(".tabs-funded-comments .show-for-conv").tab('show')
    @view("col_for_conv").activate()

  showForSite: (e)->
    e?.stopPropagation()
    e?.preventDefault()
    @$(".tabs-funded-comments .show-for-site").tab('show')
    @view("col_for_site").activate()

module.exports = ()->
  $(->
    require("backbone-setup")
    require("rivets-setup")
    require("template-setup")
    require("lib/shared/underscore_mixin")

    CollectionView = require('views/collection_view')
    View = require('views/base_view')
    HttpRequest = require('lib/httprequest')
    Site = require('models/site')
    Tag = require('models/tag')
    TagView = require('views/tag_view')

    class SiteSettingsApp extends View
      initialize: (options)->
        @options = options
        server = new HttpRequest()
        @api = {
          store: Backbone.graphStore
          site: new Site(Burnzone.site)
          server: server
        }

      events: ->
        'submit form': @beforeSubmit

      render: ->
        tags = @api.site.get('forum').tags
        if tags.tree
          tags = tags.tree
        @root_tag = new Tag({root: true})
        if _.isString(tags[0])
          @root_tag.get('subtags').reset(_.map(tags, (t)-> {displayName: t, subtags: []}))
        else
          @root_tag.get('subtags').reset(tags)
        @$('.tags_view').append(@addView('root_tag', new TagView(model: @root_tag, className: 'rootTag', root: true, level: 0)).render().el)

      beforeSubmit: ->
        if !@root_tag.isValid()
          return false
        @$('#inputTags').val(JSON.stringify(@root_tag.get('subtags').toJSON({flat: true})))
        return true

    app = window.app = Burnzone.siteSettingsForumApp = new SiteSettingsApp(_.extend({}, {el: $('body')}, Burnzone.conversaitData))
    app.render()
  )

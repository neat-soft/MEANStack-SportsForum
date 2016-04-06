module.exports = (options)->

  api = options.api

  return (method, model, options)->
    options ?= {}
    wrap = (fn)->
      return ->
        args = _.toArray(arguments)
        _.defer(->
          fn.apply(null, args)
        )
    success = wrap(options.success || ((resp)->))
    error = wrap(options.error || ((resp)->))
    modelUrl = _.result(model, 'url')
    url = options.url || modelUrl

    switch method
      when 'read'
        if model instanceof Backbone.Collection
          if !options.remove?
            options.remove = false
        if model instanceof require("models/user")
          if url == modelUrl
            success(api.store.models.get(model.id).attributes)
          else if url == modelUrl + "/countunread"
            success({no_notif_unread: 0})
          else
            success(0)
        else if model instanceof Backbone.Model
          success({})
        else if ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/profiles").exec(url)))
          site = api.store.models.get(match[1])
          profiles = api.store.getCollection(require("models/profile"), true).filter((p)-> p.get("siteName") == site.get("name"))
          if model instanceof require("collections/paged_collection")
            success({data: profiles.map((p)-> p.toJSON()), from: null})
          else
            success(profiles)
        else if model.container instanceof require("models/site") && ((match = new RegExp("/api/sites/([a-zA-Z0-9]+)/leaders").exec(url)))
          site = api.store.models.get(match[1])
          profiles = api.store.getCollection(require("models/profile"), true).filter((p)-> p.get("siteName") == site.get("name"))
          if model instanceof require("collections/paged_collection")
            success({data: profiles, from: null})
          else
            success(profiles)
        else if model instanceof require("collections/paged_collection")
          if (match = new RegExp("/api/sites/([a-zA-Z0-9]+)/badges/([a-zA-Z0-9]+)/leaders").exec(url))
            site = api.store.models.get(match[1])
            badge_id = match[2]
            badge = site.get('badges')?[badge_id]
            if badge
              profiles = api.store.getCollection(require('models/profile'), true).filter((p)-> p.get('badges').find((b)-> b.get('badge_id') == badge_id))
              result = []
              for p in profiles
                pbadge = p.get('badges').find((b)-> b.get('badge_id'))
                result.push({
                  permissions: p.get('permissions')
                  user: p.get('user').id
                  rank: pbadge.get('rank')
                  rank_cutoff: badge.rank_cutoff
                  points: pbadge.get('value')
                })
              result = _(result).sortBy((p)-> -p.rank)
              success(data: result, from: null)
            else
              success(data: [], from: null)
          else if model.container instanceof require("models/context") && model.key == "allactivities"
            success(data: api.store.models.find((m)-> m.get("context") == model))
          else
            success(data: [], from: null)
        else if url == modelUrl
          success(model.attributes || model.models)
        else if model instanceof Backbone.Collection
          success([])
      when 'create'
        cdate = new Date().getTime()
        success(_.extend({}, model.attributes, {_v: 0, created: cdate, changed: cdate, _id: (@id++).toString()}))
      when 'update'
        if url == modelUrl
          if model instanceof require("models/user")
            return success(_.extend(model.attributes, {imageType: "custom"}))
          success(model.attributes)
        else if url == modelUrl + "/delete"
          success({deleted: true})
        else if url == modelUrl + "/approve"
          success({approved: true})
        else if url == modelUrl + "/clearflags"
          success({no_flags: 0, flags: []})
        else if url == modelUrl + "/fund"
          user = api.user
          ctx = model.get('context')
          ctx.get('funded_activities').add(model)
          api.site.get('funded_activities').add(model)
          success({is_funded: true, funded: (model.get('funded') || []).concat([user.id])})
        else
          success({})
      when 'delete'
        success()

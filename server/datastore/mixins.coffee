dbutil = require("./util")
async = require("async")

module.exports.merge_points =
  merge: (from_user, into_user, field_for_create, callback)->
    from_profile = null
    into_profile = null
    async.forever(
      (next)=>
        async.waterfall([
          (cb)=>
            @findAndModify({user: from_user._id, deleted: {$ne: true}}, [], {$set: {deleted: true}}, {new: true}, cb)
          (profile, info, cb)=>
            from_profile = profile
            if !from_profile
              return cb({notexists: true})
            if field_for_create == 'siteName'
              @create(into_user, from_profile[field_for_create], false, cb)
            else
              @create(into_user, from_profile[field_for_create], cb)
          (profile, cb)=>
            into_profile = profile
            @update({_id: into_profile._id}, {$inc: {points: from_profile.points}}, cb)
          (no_updated, info, cb)=>
            @findAndModify({_id: from_user._id}, [], {$set: {merged_into: into_profile._id}}, {new: true}, cb)
        ], next)
      (err)->
        if err?.notexists
          return callback()
        callback(err)
    )

module.exports.sorting =
  multipleSortTopLevel: (query, sort, from, limit, options, callback)->
    if !callback?
      callback = options
      options = null
    options ?= {}
    fromElem = null
    async.waterfall([
      (cb)=>
        if from
          queryFrom = {_id: dbutil.idFrom(from)}
          if query.approved?
            queryFrom.approved = query.approved
          @findOne(queryFrom, cb)
        else
          cb(null, null)
      (fromDoc, cb)=>
        queries = _.map(@prepareSortQueries(query, sort, fromDoc, options), (q)-> {query: q, options: {sort: sort}})
        @findMultiple(queries, limit, cb)
    ], callback)

  sortTopLevel: (query, field, direction, from, limit, callback)->
    elements = []
    sort = if field != "_id" then [[field, direction], ["_id", 1]] else [[field, direction]]
    fromElem = null
    async.waterfall([
      (cb)=>
        if from
          queryFrom = {_id: dbutil.idFrom(from)}
          if query.approved?
            queryFrom.approved = query.approved
          @findOne(queryFrom, cb)
        else
          cb(null, null)
      (fromDoc, cb)=>
        fromElem = fromDoc
        if fromElem
          @prepareTopLevelQuery(query, field, direction, fromElem)
        @find(query, {sort: sort, limit: limit}, cb)
      (cursor, cb)->
        cursor.toArray(cb)
      (result, cb)=>
        elements = result
        if fromElem && elements.length < limit
          @prepareTopLevelQuery(query, field, direction, fromElem, true)
          @find(query, {sort: sort, limit: limit}, cb)
        else
          callback(null, elements)
      (cursor, cb)->
        cursor.toArray(cb)
      (result, cb)->
        elements = elements.concat(result)
        cb(null, elements)
    ], callback)

  prepareSortQueries: (base_query, sort, from, options)->
    queries = []
    sort = _.array(sort)
    if from
      for i in [0..sort.length - 1]
        query = {}
        for j in [0..sort.length - 1 - i]
          field = sort[j][0]
          dir = sort[j][1]
          if j < sort.length - 1 - i
            query[field] = from[field]
          else if j == sort.length - 1 - i
            query[field] = if dir == 1 then {$gt: from[field]} else {$lt: from[field]}
        queries.push(dbutil.extend_query(_.clone(base_query), query))
    else
      queries = [base_query]
    return queries

  prepareTopLevelQuery: (query, field, direction, from, strict = false)->
    switch field
      when "slug"
        if direction == 1
          query[field] = {$gt: from[field]}
        else
          query[field] = {$lt: from[field]}
      when "_id"
        if direction == 1
          query[field] = {$gt: from[field]}
        else
          query[field] = {$lt: from[field]}
      else
        if strict
          if direction == 1
            query[field] = {$gt: from[field]}
          else
            query[field] = {$lt: from[field]}
          delete query._id
        else
          query[field] = from[field]
          query._id = {$gt: from._id}

    return query

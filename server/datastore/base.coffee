util = require("../util")
async = require("async")
mongo = require("mongodb")
dbutil = require("./util")
debug = require("debug")("data:base")

module.exports = class CollectionWrapper

  constructor: (options)->
    @db = options.db
    @name ?= options.name

  c: (callback)->
    @db.collection(@name, callback)

  preQuery: (query)->
    #

  drop: (callback)->
    return @c(util.wrapError(callback, (col)=>
      debug("DROP collection #{@name}")
      col.drop(callback)
    ))

  findAndRemove: (attrs, sort, options, callback)->
    if typeof(options) == "function"
      callback = options
      options = {}
    @preQuery?(attrs)
    return @c(util.wrapError(callback, (col)->
      debug("findAndRemove: %j %j", attrs, options)
      col.findAndRemove(attrs, options, callback)
    ))

  findToArray: (attrs, options, callback)->
    if typeof(options) == "function"
      callback = options
      options = {}
    async.waterfall([
      (cb)=>
        @find(attrs, options, cb)
      (cursor, cb)->
        cursor.toArray(cb)
    ], callback)

  find: (attrs, options, callback)->
    if typeof(options) == "function"
      callback = options
      options = {}
    @preQuery?(attrs)
    return @c(util.wrapError(callback, (col)->
      debug("find: %j %j", attrs, options)
      col.find(attrs, options, callback)
    ))

  update: (attrs, updates, options, callback)->
    if typeof(options) == "function"
      callback = options
      options = {}
    @preQuery?(attrs)
    return @c(util.wrapError(callback, (col)->
      debug("update: %j %j %j", attrs, updates, options)
      col.update(attrs, updates, options, callback)
    ))

  findOne: (attrs, options, callback)->
    if typeof(options) == "function"
      callback = options
      options = {}
    @preQuery?(attrs)
    return @c(util.wrapError(callback, (col)->
      debug("findOne: %j %j", attrs, options)
      col.findOne(attrs, options, callback)
    ))

  findAndModify: (query, sort, update, options, callback)->
    @preQuery?(query)
    if typeof(options) == "function"
      callback = options
      options = {}
    return @c(util.wrapError(callback, (col)->
      debug("findAndModify: %j %j %j %j", query, sort, update, options)
      col.findAndModify(query, sort, update, options, callback)
    ))

  findById: (id, options, callback)->
    if typeof(options) == "function"
      callback = options
      options = {}
    id = dbutil.idFrom(id)
    query = {_id: id}
    @preQuery?(query)
    @findOne(query, options, callback)

  insert: (attrs, callback)->
    return @c(util.wrapError(callback, (col)->
      debug("insert: %j", attrs)
      col.insert(attrs, callback)
    ))

  remove: (attrs, callback)->
    return @c(util.wrapError(callback, (col)->
      debug("remove: %j", attrs)
      col.remove(attrs, callback)
    ))

  count: (attrs, callback)->
    # if !attrs.deleted?
    #   attrs.deleted = {$ne: true}
    return @c(util.wrapError(callback, (col)->
      debug("count: %j", attrs)
      col.count(attrs, callback)
    ))

  insertOrModifyEval: (query, whenNew, whenUpdate, callback)->
    @preQuery?(query)
    # whenNew should not contain mongo operations like $set, $inc. It is just a set of fields that the desired new object should contain
    # whenUpdate should contain a set of operations to apply to the existing object
    @db.eval("""
      function(colName, query, whenNew, whenUpdate){
        var existing = db[colName].findOne(query);
        if (existing) {
          return {
            new: db[colName].findAndModify({query: {_id: existing._id}, update: whenUpdate, new: true}),
            old: existing
          }
        }
        else {
          whenNew._id = new ObjectId();
          db[colName].insert(whenNew);
          return {new: db[colName].findOne({_id: whenNew._id})};
        }
      }
    """, [@name, query, whenNew, whenUpdate], (err, result)->
      if result
        if result.old
          callback(err, result.new, result.old)
        else
          callback(err, result.new)
      else
        callback(err, result)
    )

  # works only with unique indexes for fields in whenNew
  insertOrModify: (query, whenNew, queryOrFWhenUpdate, whenUpdate, callback)->
    @preQuery?(query)
    async.waterfall([
      (cb)=>
        @findOne(query, cb)
      (doc, cb)=>
        if doc && whenUpdate
          if _.isFunction(queryOrFWhenUpdate)
            queryWhenUpdate = queryOrFWhenUpdate(doc)
          else
            queryWhenUpdate = queryOrFWhenUpdate
          @preQuery?(queryWhenUpdate)
          @findAndModify((if !queryWhenUpdate then doc else queryWhenUpdate), [], whenUpdate, {new: true}, (err, result)->
            # if result then no one modified the document during our queries, so it was a successful update
            if result
              cb(err, result, {updated: true})
            else
              # no modification => The update is controlled by queryWhenUpdate
              cb(err, doc, {})
          )
        else if !doc && whenNew
          @insert(whenNew, (err, results)=>
            if dbutil.errDuplicateKey(err)
              @findOne(query, (finderror, existing)->
                cb(finderror, existing, {})
              )
            else
              cb(err, results?[0], {new: true})
          )
        else
          cb(null, doc, {})
    ], callback)

  findOrCreate: (query, create, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    options ?= {}
    if create._id
      create = _.omit(create, "_id")
    debug("findOrCreate: %j, %j", query, create)
    @findAndModify(query, [], {$setOnInsert: create}, _.extend({}, options, {new: true, upsert: true}), callback)

  toClient: (doc)->
    return doc

  changes: (contextId, since, callback)->
    query =
      context: dbutil.idFrom(contextId)
      changed: { $gt: since }
      approved: true
    @find(query, callback)

  modifyChanged: (query, current, callback)->
    @preQuery?(query)
    @findAndModify(_.extend({}, query, {changed: {$lte: current}}), {$set: {changed: new Date().getTime()}}, callback)

  findAndModifyWTime: (query, sort, update, options, callback)->
    async.waterfall([
      (cb)=>
        @findAndModify(query, sort, update, options, cb)
      (item, info, cb)=>
        if !item
          cb(item, info, cb)
        else
          cdate = new Date().getTime()
          options.upsert = null
          @findAndModify({_id: item._id, changed: {$lt: cdate}}, [], {$set: {changed: cdate}}, options, cb)
    ], callback)

  # to be used for updating ONE ELEMENT ONLY and then set the changed timestamp
  updateWTime: (query, update, optionsFind, optionsUpdate, callback)->
    if _.isFunction(optionsFind)
      callback = optionsFind
      optionsFind = {}
      optionsUpdate = {}
    if _.isFunction(optionsUpdate)
      callback = optionsUpdate
      optionsUpdate = {}
    async.waterfall([
      (cb)=>
        @findAndModify(query, [], update, optionsFind, cb)
      (item, info, cb)=>
        if !item
          callback(null, 0)
        else
          cdate = new Date().getTime()
          @update({_id: item._id, changed: {$lt: cdate}}, {$set: {changed: cdate}}, optionsUpdate, cb)
    ], callback)

  mapReduce: (map, reduce, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    return @c(util.wrapError(callback, (col)->
      debug("mapreduce, options: %j", options)
      col.mapReduce(map, reduce, options, callback)
    ))

  aggregate: (pipeline, options, callback)->
    if _.isFunction(options)
      callback = options
      options = {}
    return @c(util.wrapError(callback, (col)->
      debug("aggregate, pipeline: %j, options: %j", pipeline, options)
      col.aggregate(pipeline, options, callback)
    ))

  # Returns a page of documents, unfiltered and sorted by id in decreasing order.
  # curfirst: the first element of the current page - returned by a previous call
  # curlast: the last element of the current page - returned by a previous call
  # prev: true if fetching previous page, false if fetching next page
  pageById: (query, curfirst, curlast, perpage, prev, callback)->
    query = _.clone(query)
    options = {limit: perpage, sort: [["_id", -1]]}
    if prev
      if curfirst
        query._id = {$gt: curfirst}
    else
      if curlast
        query._id = {$lt: curlast}
    async.parallel([
      (cbp)=>
        @count(query, cbp)
      (cbp)=>
        async.waterfall([
          (cb)=>
            @find(query, options, cb)
          (cursor, cb)->
            cursor.toArray(cb)
        ], cbp)
    ], (err, results)->
      if err
        return callback(err)
      [total, list] = results
      if list.length != perpage
        if prev
          firstpage = true
          lastpage = false
        else
          firstpage = false
          lastpage = true
      callback(err, {
        firstpage: firstpage
        lastpage: lastpage
        firstinpage:
          if list.length == 0
            firstpage && curfirst || ""
          else
            list[0]._id
        lastinpage:
          if list.length == 0
            lastpage && curlast || ""
          else
            list[list.length - 1]._id
        data: list
        total: total
      })
    )

  findIter: (attrs, options, iter, done)->
    if typeof(options) == "function"
      done = iter
      iter = options
      options = {}
    @preQuery?(attrs)
    return @find(attrs, options, (err, cursor)->
      if err
        return done(err)
      util.iter_cursor(cursor, iter, done)
    )

  # Each object in queries is an object {query, options}
  # options is most often used to specify the sort option
  # Example:
  #   {query: {name: 'John Doe'}, options: {sort: [['_id', -1]]}}
  findMultiple: (queries, limit, callback)->
    results = []
    i = 0
    async.whilst(
      ->
        if limit && results.length >= limit || i >= queries.length
          return false
        return true
      (cb)=>
        @findToArray(queries[i].query, _.extend({}, queries[i].options || {}, if limit then {limit: limit - results.length} else {}), (err, arr)->
          if err
            return cb(err)
          results = results.concat(arr)
          i++
          cb()
        )
      (err)->
        if err
          return callback(err)
        callback(null, results.slice(0, limit))
    )

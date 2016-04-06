_.mixin(

  partialEnd: (func)->
    args = Array.prototype.slice.call(arguments, 1)
    return ->
      return func.apply(this, Array.prototype.slice.call(arguments).concat(args))

  limit: (func, delay)->
    lastCalled = 0
    args = null
    to = 0
    delayed = ->
      lastCalled = new Date().getTime()
      func.apply(context, args)
    return ->
      context = this
      args = arguments
      now = new Date().getTime()
      passed = now - lastCalled
      remaining = delay - passed
      if remaining <= 0
        to = 0
        delayed()
      else
        to += remaining
        setTimeout(delayed, to)

  set: (obj)->
    result = {}
    @each(obj, (elem)->
      result[elem] = true
    )
    return result

  deferTimes: (fn, wait, times, factor)->
    times ?= 1
    if times <= 0
      times = 1
    factor ?= 1
    wait ?= 0
    i = 0
    delay = wait
    call = ->
      setTimeout(->
        fn()
        i++
        if i < times
          delay *= factor
          call()
      , delay)
    call()

  uniqStr: (array, fn)->
    result = []
    visited = {}
    @each(array, (elem)->
      if fn then elem = fn(elem)
      if !elem? then return
      if !visited[elem]
        visited[elem] = true
        result.push(elem)
    )
    return result

  valuesOrder: (obj, order)->
    return (obj[key] for key in order when @has(obj, key))

  keep: (obj)->
    keys = {}
    for key in arguments
      keys[key.toString()] = true
    @each(obj, (value, key)->
      if !(key of keys)
        delete obj[key]
    )

  array: (obj)->
    if @isArray(obj)
      return obj
    if @isEmpty(obj)
      return obj
    return []

  # Calls a function on each node of a tree structure that is commonly encountered in applications
  # Child nodes are reached through `child_key`
  # Depth can be limited with `max_depth`, if `max_depth` is greater than 0. Everything deeper than
  # `max_depth` is ignored.
  walkTree: (obj, child_key, max_depth, fn)->
    if _.isFunction(max_depth)
      fn = max_depth
      max_depth = null
    walkItem = (node, parent, level)->
      if max_depth? && max_depth != false && max_depth >= 0 && level > max_depth
        return
      fn(node, parent, level)
      child_value = node[child_key]
      if !child_value
        return
      if _.isArray(child_value)
        for elem in child_value
          walkItem(elem, node, level + 1)
      else
        walkItem(elem, node, level + 1)
    if _.isArray(obj)
      for elem in obj
        walkItem(elem, null, 0)
    else
      walkItem(obj, null, 0)

  # Limits a tree depth by deleting nodes
  limitTree: (obj, child_key, max_depth)->
    walkItem = (node, level)->
      child_value = node[child_key]
      if !child_value
        return
      if max_depth? && max_depth != false && max_depth >= 0 && level + 1 > max_depth
        delete node[child_key]
      else
        if _.isArray(child_value)
          for elem in child_value
            walkItem(elem, level + 1)
        else
          walkItem(elem, level + 1)
    if _.isArray(obj)
      for elem in obj
        walkItem(elem, 0)
    else
      walkItem(obj, 0)

  # Uses `walkTree` to build an array of all the elements found in a tree
  flattenTree: (obj, child_key, max_depth)->
    result = []
    @walkTree(obj, child_key, max_depth, (e)-> result.push(e))
    return result

  # Uses `walkTree` to build a set of all the elements found in a tree
  # Elements are keyed by the value defined by `pick` (in case `pick` is a function,
  # _.result will be called)
  flattenTreeToSet: (obj, child_key, max_depth, pick)->
    result = {}
    @walkTree(obj, child_key, max_depth, (e)-> result[@result(obj, pick)] = e)
    return result
)

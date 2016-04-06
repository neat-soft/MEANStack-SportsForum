module.exports = class HttpRequest

  initialize: ->
    

  request: (url, method, params, cb)->
    if _.isFunction(method)
      cb = method
      method = "GET"
      params = {}
    else if _.isFunction(params)
      cb = params
      if _.isObject(method)
        params = method
        method = "GET"
      else
        params = {}
    @doRequest(url, method, params, cb)

  get: (url, params, cb)->
    @request(url, "GET", params, cb)

  post: (url, params, cb)->
    @request(url, "POST", params, cb)

  put: (url, params, cb)->
    @request(url, "PUT", params, cb)

  delete: (url, params, cb)->
    @request(url, "DELETE", params, cb)

  doRequest: (url, method, params, cb)->
    success = (data, status, xhr)->
      cb && cb(null, data)
    error = (xhr, status, ex)->
      try
        response = JSON.parse(xhr.responseText)
      catch err
        response = xhr.responseText
      cb && cb({status: status, data: ex, xhr: xhr}, response)
    $.ajax(url, {
      data: params
      type: method || "GET"
      dataType: "json"
      cache: false
      success: success
      error: error
    })

  callMethod: (name, type, toAppend, params)->
    args = _.toArray(arguments).slice(1)
    if _.isFunction(args[args.length - 1])
      cb = args[args.length - 1]
      args.shift()
    url = @url + "/#{name}"
    for appendToUrl in toAppend
      if params[appendToUrl]
        url += "/#{params[appendToUrl]}"
    params = _.omit(params, toAppend)
    data = params || {}
    @doRequest(url, type, data, cb)

  setMethods: (methods)->
    @methods = {}
    wrapCall = (name, type, toAppend)=>
      return =>
        args = _.toArray(arguments)
        args.unshift(toAppend || [])
        args.unshift(type)
        args.unshift(name)
        @callMethod.apply(this, args)

    for method in (methods || [])
      if "GET" == method.type or "GET" in method.type
        @methods["get_#{method.name}"] = wrapCall(method.name, "GET", method.appendToUrl)
      if "PUT" == method.type or "PUT" in method.type
        @methods["update_#{method.name}"] = @methods["put_#{method.name}"] = wrapCall(method.name, "PUT", method.appendToUrl)
      if "POST" == method.type or "POST" in method.type
        @methods["create_#{method.name}"] = @methods["post_#{method.name}"] = wrapCall(method.name, "POST", method.appendToUrl)
      if "DELETE" == method.type or "DELETE" in method.type
        @methods["del_#{method.name}"] = wrapCall(method.name, "DELETE", method.appendToUrl)

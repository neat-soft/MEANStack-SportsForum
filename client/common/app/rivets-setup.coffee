rivets.configure({
  prefix: "rv"
  adapter: {
    subscribe: (obj, keypath, callback)->
      obj.on("change:" + keypath, callback)

    unsubscribe: (obj, keypath, callback)->
      obj.off("change:" + keypath, callback)

    read: (obj, keypath)->
      return obj.get(keypath)

    publish: (obj, keypath, value)->
      obj.set(keypath, value)
  }
})

rivets.formatters.avatar = (value)->
  return "http://www.gravatar.com/avatar/#{value}?s=50&d=" + encodeURIComponent((window.conversaitData.baseUrlResources || "") + "/img/default_avatar.png")

module.exports.remote = class RtRemote

  constructor: ->
    @initialize()

  initialize: ->
    @fayeClient = new Faye.Client('/rtupdates', {
      timeout: 30
      retry: 5
    })

  subscribe: (channel, fn)->
    @fayeClient.subscribe(channel, fn)

  unsubscribe: (channel)->
    @fayeClient.unsubscribe(channel)

  publish: (channel, data)->
    @fayeClient.publish(channel, data)
    
module.exports.local = class LocalRemote

  constructor: ->
    @initialize()

  initialize: ->
    #pass

  subscribe: ->
    #pass

  publish: ->
    #pass

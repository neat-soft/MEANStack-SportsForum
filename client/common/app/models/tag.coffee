sharedUtil = require('lib/shared/util')

module.exports = class Tag extends Backbone.GraphModel

  defaults:
    displayName: ''
    subtags: []

  relations: [
    {
      key: "subtags"
      type: {ctor: class Tags extends Backbone.GraphCollection
        model: Tag
      }
      serialize: true
    }
  ]

  validate: (attrs)->
    if attrs.displayName?
      if !sharedUtil.validateTag(attrs.displayName)
        return 'error:invalid_name'
    return null

  isValid: (options)->
    return (@get('root') || super(options)) && _.all(@get('subtags').models, (m)-> m.isValid(options))

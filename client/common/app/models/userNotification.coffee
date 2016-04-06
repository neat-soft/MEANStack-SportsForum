module.exports = class UserNotification extends Backbone.GraphModel

  relations: [
    {
      key: "context"
      type: {provider: -> require("models/context")}
      autoCreate: true
    },
    {
      key: "by"
      type: {provider: -> require("models/user")}
      autoCreate: true
    },
    {
      key: "comment"
      type: {provider: -> require("models/comment")}
      autoCreate: true
    },
    {
      key: "question"
      type: {provider: -> require("models/comment")}
      autoCreate: true
    },
    {
      key: "challenge"
      type: {provider: -> require("models/challenge")}
      autoCreate: true
    },
    {
      key: "user"
      type: {provider: -> require("models/user")}
      autoCreate: true
      reverseKey: "notifications"
    }
  ]


require("./setup")
datastore = require("../datastore")
dbutil = require("../datastore/util")
async = require("async")
urls = require("../interaction/urls")
config = require("naboo").config

describe("urls", ->

  describe("#for_model", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should return with server route when route_server is set", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      url = urls.for_model("comment", comment, {route_server: true})
      expect(url).to.equal("#{config.serverHost}/go/#{comment._id.toHexString()}")
      done()
    )
  )
)

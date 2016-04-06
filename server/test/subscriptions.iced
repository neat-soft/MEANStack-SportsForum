require("./setup")
datastore = require("../datastore")

describe("subscriptions", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#userSubscribeForConv", ->
    it("should add unverified subscription for unverified users", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.subscriptions.userSubscribeForConv(user2, site, defer(err, subscription))
      expect(subscription.verified).to.be.false
      done()
    )
  )

  describe("#userSubscribeForContent", ->
    it("should add unverified subscription for unverified users", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.subscriptions.userSubscribeForContent(user2, site, conversation._id, defer(err, subscription))
      expect(subscription.verified).to.be.false
      done()
    )
  )
)

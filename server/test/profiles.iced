require("./setup")
datastore = require("../datastore")

describe("Profiles", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#modify", ->
    it("can't assign moderator permissions to unverified users", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.users.createOwnAccount "u1", "email2", "pass", false, defer err, user2
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, false, defer(err, profile))
      await datastore.collections.profiles.findOne({siteName: site.name, user: user1._id}, defer(err, u1profile))
      await datastore.collections.profiles.modify(site, user2._id, {permissions: {moderator: true}}, user1, u1profile, defer(err, profile))
      expect(err.not_verified).to.be.true
      done()
    )

    it("should allow zeus users to change moderators", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", defer(err, user1))
      await datastore.collections.users.createOwnAccount("u1", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u1", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.update({_id: user3._id}, {$set: {zeus: true}}, defer(err))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, false, defer(err, profile))
      await datastore.collections.profiles.modify(site, user2._id, {permissions: {moderator: true}}, user3, datastore.collections.profiles.default, defer(err, profile))
      expect(err).to.not.exist
      done()
    )
  )
)

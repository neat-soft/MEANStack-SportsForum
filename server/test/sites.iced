setup = require("./setup")
datastore = require("../datastore")
request = require('supertest')

describe("Sites", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#add", ->
    it("should add a new site", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))

      await datastore.collections.sites.findOne({}, defer(err, siteInDb))
      expect(siteInDb.name).to.equal("test")
      expect(siteInDb.urls[0].base).to.equal("localhost")
      done()
    )

    it("should add a new profile for site owner", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))

      await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
      expect(u1profile).to.exist
      expect(u1profile.permissions.admin).to.equal(true)
      expect(u1profile.points).to.equal(util.getValue("initialPoints"))
      done()
    )
  )

  describe("#modify", ->
    it("should set conv.qsDefineNew to an empty array when given a whitespace string", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      attrs = {"conv.qsDefineNew": "\n\n    \n   \n"}
      await datastore.collections.sites.modify("test", attrs, defer(err, site))
      expect(err).to.be.null
      expect(site.conv.qsDefineNew).to.be.empty
      done()
    )

    it("should set conv.qsDefineNew to an array of unique params when given a string with duplicate params", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      attrs = {"conv.qsDefineNew": "\na\na    \nb   \nb\nc\na   b"}
      await datastore.collections.sites.modify("test", attrs, defer(err, site))
      expect(err).to.be.null
      expect(site.conv.qsDefineNew).to.deep.equal(['a', 'b', 'c', 'ab'])
      done()
    )

    it("should not allow tags with .(dot) in their name", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      tags = [
        {
          displayName: 't1'
          subtags: [
            {
              displayName: 't4'
              subtags: [
                {
                  displayName: 't5'
                  subtags: []
                }
                {
                  displayName: 't6'
                  subtags: []
                }
              ]
            }
          ]
        }
        {displayName: 't2.a'}
        {displayName: 't3'}
      ]
      await datastore.collections.sites.modify(site.name, {"forum.tags": tags}, defer(err, site))
      expect(err).to.exist
      expect(err.invalid_tag).to.be.true
      done()
    )
  )

  describe("interaction#/admin/settingsadv", ->
    it("should create empty conv.qsDefineNew if not provided", (done)->
      email = "email1@email.com"
      pass = "pass"
      await datastore.collections.users.createOwnAccount "u1", email, pass, true, defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      await request(setup.app).post('/auth/signin').send({email: email, passwd: pass}).end(defer(err, res))
      cookie = res.headers['set-cookie'][0]
      cookie = cookie.substring(0, cookie.indexOf(';') + 1)
      await request(setup.app)
        .post("/admin/settingsadv")
        .set("host", "test.#{setup.config.domainAndPort}")
        .set('Cookie', cookie)
        .send({qsdefinenew: ""})
        .end(defer(err, res))
      expect(err).to.not.exist
      expect(res.statusCode).to.equal(302)
      await datastore.collections.sites.findOne({name: "test"}, defer(err, site))
      expect(site.conv.qsDefineNew).to.be.empty
      done()
    )
  )
)

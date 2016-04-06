require("./setup")
datastore = require("../datastore")

describe("Conversations", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#processForumTags", ->
    it("should perform intersection between the site tags and forum tags if the tags are not categorized", (done)->
      site =
        forum:
          categories: false
          tags: {
            tree: [{displayName: 't1'}, {displayName: 't2'}, {displayName: 't3'}]
            set: {'t1': {displayName: 't1'}, 't2': {displayName: 't2'}, 't3': {displayName: 't3'}}
          }
      result_tags = datastore.collections.conversations.processForumTags(site, ['t1', 't2', 't5'])
      expect(result_tags).to.deep.equal(['t1', 't2'])
      done()
    )

    it("should return an array with the leaf first and then all parent tags if the tags are categorized", (done)->
      site =
        forum:
          categories: true
          tags: {
            tree: [
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
              {displayName: 't2'}
              {displayName: 't3'}
            ]
            set: {
              't1': {displayName: 't1'}
              't2': {displayName: 't2'}
              't3': {displayName: 't3'}
              't4': {displayName: 't4', parent: 't1'}
              't5': {displayName: 't5', parent: 't4'}
              't6': {displayName: 't6', parent: 't4'}
            }
          }
      result_tags = datastore.collections.conversations.processForumTags(site, ['t5'])
      expect(result_tags).to.deep.equal(['t5', 't4', 't1'])
      done()
    )
  )

  describe("#showInForum", ->
    it("should increase no_forum_conversations by 1 if previously the conversation was not shown in forum", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site))
      expect(site.no_forum_conversations).to.equal(0)
      initial = site.no_forum_conversations
      await datastore.collections.conversations.showInForum(site, conversation._id, true, defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site))
      expect(site.no_forum_conversations - initial).to.equal(1)
      done()
    )

    it("should decrease site.no_forum_conversations by 1 if previously the conversation was shown in forum", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.conversations.showInForum(site, conversation._id, true, defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site))
      initial = site.no_forum_conversations
      await datastore.collections.conversations.showInForum(site, conversation._id, false, defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site))
      expect(site.no_forum_conversations - initial).to.equal(-1)
      done()
    )

  )

  describe("#delete", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should decrease site.no_forum_conversations by 1, but not modify site.no_conversations", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      commentAttrs = {top: true, text: "demo", parent: null, forum: {text: "This is a new forum", tags: []}}
      await datastore.collections.conversations.addForum(site, user2, null, commentAttrs, defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site_initial))
      await datastore.collections.conversations.delete(site, conversation._id, defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site_after))
      expect(site_after.no_conversations).to.equal(site_initial.no_conversations)
      expect(site_after.no_forum_conversations - site_initial.no_forum_conversations).to.equal(-1)
      done()
    )
  )

  describe("#destroyApproved", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should delete the conversation and all the related data", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      commentAttrs = {top: true, text: "demo", parent: null, forum: {text: "This is a new forum", tags: []}}
      await datastore.collections.conversations.addForum(site, user2, null, commentAttrs, defer(err, conversation))
      await datastore.collections.conversations.destroyApproved(site, conversation._id, defer(err))
      await datastore.collections.conversations.count({}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.comments.count({}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site))
      expect(site.no_conversations).to.equal(0)
      done()
    )

    it("should decrease site.no_forum_conversations and site.no_conversations by 1", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      commentAttrs = {top: true, text: "demo", parent: null, forum: {text: "This is a new forum", tags: []}}
      await datastore.collections.conversations.addForum(site, user2, null, commentAttrs, defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site_initial))
      await datastore.collections.conversations.destroyApproved(site, conversation._id, defer(err))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site_after))
      expect(site_after.no_conversations - site_initial.no_conversations).to.equal(-1)
      expect(site_after.no_forum_conversations - site_initial.no_forum_conversations).to.equal(-1)
      done()
    )
  )

  describe("#addForum", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should add both a new comment and a forum conversation", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      commentAttrs = {top: true, text: "demo", parent: null, forum: {text: "This is a new forum", tags: []}}
      await datastore.collections.conversations.addForum(site, user2, null, commentAttrs, defer(err, conversation))
      expect(err).to.not.exist
      expect(conversation.approved).to.be.true
      await datastore.collections.comments.findOne({_id: conversation.comment}, defer(err, comment))
      expect(comment).to.exist
      done()
    )

    it("should increment site.no_forum_conversations by 1", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      commentAttrs = {top: true, text: "demo", parent: null, forum: {text: "This is a new forum", tags: []}}
      await datastore.collections.conversations.addForum(site, user2, null, commentAttrs, defer(err, conversation))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site))
      expect(site.no_forum_conversations).to.equal(1)
      done()
    )
  )

  describe("#enter", ->
    it("should create conversation once", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))

      await datastore.collections.conversations.enter(site, null, 1, "http://localhost.com/bla", defer(err, conv))
      await datastore.collections.conversations.enter(site, null, 1, "http://localhost.com/bla", defer(err, conv))
      await datastore.collections.conversations.count({}, defer(err, count))
      expect(conv).to.exist
      expect(count).to.equal(1)
      done()
    )

    it("should enter conversation when baseUrl has mixed case", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))

      await datastore.collections.conversations.enter(site, null, 1, "http://localhost.com/bla", defer(err, conv))
      expect(conv).to.exist
      done()
    )

    it("should add a notification job only when the conversation is new", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))

      await datastore.collections.conversations.enter(site, null, 1, "http://localhost.com/bla", defer(err, conv))
      await datastore.collections.jobs.count({type: "NEW_CONVERSATION"}, defer(err, count))
      expect(count).to.equal(1)

      await datastore.collections.conversations.enter(site, null, 1, "http://localhost.com/bla", defer(err, conv))
      await datastore.collections.jobs.count({type: "NEW_CONVERSATION"}, defer(err, count))
      expect(count).to.equal(1)

      done()
    )

    it("should not allow creating conversations without id when site.conv.forceId == true", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      attrs = {"conv.forceId": true}
      await datastore.collections.sites.modify("test", attrs, defer(err, site))
      await datastore.collections.conversations.enter(site, null, null, "http://localhost.com/bla", defer(err, conv))
      expect(err).to.deep.equal({forceid: true})
      done()
    )

    it("should change the url to conform with site.conv.qsDefineNew when site.conv.useQs == true", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      attrs = {"conv.forceId": false, "conv.qsDefineNew": ['a', 'b'], "conv.useQs": true}
      await datastore.collections.sites.modify("test", attrs, defer(err, site))
      await datastore.collections.conversations.enter(site, null, null, "http://localhost.com/bla?z=e&b=2&f=4&a=4", defer(err, conv))
      expect(err).to.be.null
      expect(conv.initialUrl).to.be.equal("http://localhost.com/bla?a=4&b=2")
      done()
    )

    it("should not allow creating conversations when the url does not contain all the required query strings parameters when site.conv.useQs == true", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      attrs = {"conv.forceId": false, "conv.qsDefineNew": ['a', 'b'], "conv.useQs": true}
      await datastore.collections.sites.modify("test", attrs, defer(err, site))
      await datastore.collections.conversations.enter(site, null, null, "http://localhost.com/bla?z=e&b=2&f=4", defer(err, conv))
      expect(err).to.deep.equal({useqs: true})
      done()
    )

    it("should not verify the url for a trusted site", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", defer err, user1
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}]}, user1, defer(err, site))
      site.trust_urls = true
      oldenv = process.env.NODE_ENV
      process.env.NODE_ENV = ''
      await datastore.collections.conversations.enter(site, null, null, "http://localhost:43536", defer(err, conv))
      process.env.NODE_ENV = oldenv
      expect(err).to.be.null
      done()
    )
  )
)

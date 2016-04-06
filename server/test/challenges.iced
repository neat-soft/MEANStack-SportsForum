require("./setup")
datastore = require("../datastore")

describe("Challenges", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#vote", ->

    it("should increment conversation.activity_rating and set conversation.latest_activity", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial_rating = conversation.activity_rating
      initial_activity = conversation.latest_activity
      await datastore.collections.comments.vote(site, challenge._id, null, null, "session_id", "challenger", true, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial_rating).to.equal(util.getValue("forumRatingVote"))
      expect(conversation.latest_activity).to.be.gt(initial_activity)
      done()
    )

    it("should increment no_votes for one side and rating for the entire challenge when there's no user, only session", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, null, null, "session_id", "challenger", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: challenge._id}, defer(err, challenge))
      expect(challenge.rating).to.equal(1)
      expect(challenge.challenger.no_votes).to.equal(1)
      done()
    )

    it("should do nothing when has already voted when there's no user, only session", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, null, null, "session_id", "challenged", true, defer(err, result))
      await datastore.collections.comments.vote(site, challenge._id, null, null, "session_id", "challenged", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: challenge._id}, defer(err, challenge))
      expect(challenge.rating).to.equal(1)
      expect(challenge.challenged.no_votes).to.equal(1)
      done()
    )

    it("should add 2 votes with different sessions when there's no user, only session", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, null, null, "session_id1", "challenged", true, defer(err, result))
      await datastore.collections.comments.vote(site, challenge._id, null, null, "session_id2", "challenged", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: challenge._id}, defer(err, challenge))
      expect(challenge.rating).to.equal(2)
      expect(challenge.challenged.no_votes).to.equal(2)
      done()
    )

  )

  describe("#endChallenge", ->

    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should mark as finished", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: challenge._id}, defer(err, challenge))
      await datastore.collections.comments.endChallenge(challenge, defer(err, challenge))
      expect(challenge.finished).to.equal(true)
      done()
    )

    it("should return challenge", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: challenge._id}, defer(err, challenge))
      await datastore.collections.comments.endChallenge(challenge, defer(err, challengeEnded))
      expect(challengeEnded._id.equals(challenge._id)).to.equal(true)
      done()
    )
  )
)

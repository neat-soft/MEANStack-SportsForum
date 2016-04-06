require("./setup")
datastore = require("../datastore")
dbutil = require("../datastore/util")
async = require("async")
moment = require('moment')

sortStringReverse = (a, b)->
  if a < b
    return 1
  else if a > b
    return -1
  else
    return 0

describe("Comments", ->

  describe("#addComment", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should add an approved comment when the user is not verified and not admin", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      expect(comment.approved).to.be.true
      done()
    )

    it("should add an approved comment when the user is not verified and admin", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", false, defer(err, user1))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      expect(comment.approved).to.be.true
      done()
    )
  )

  describe("#addChallenge", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should add an approved challenge when the user is not verified and not admin", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
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
      expect(challenge.approved).to.be.true
      done()
    )

    it("should add an approved challenge when the user is not verified and admin", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", false, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user1, site, defer(err, u1profile))
      await datastore.collections.profiles.update({_id: u1profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user1, null, challengeAttrs, defer(err, challenge))
      expect(challenge.approved).to.be.true
      done()
    )
  )

  describe("#approve", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should approve the forum topic also if the comment initiated a forum topic", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: false}, user1, defer(err, site))
      await datastore.collections.conversations.addForum(site, user2, null, {text: "1", forum: {text: "title", tags: []}}, defer(err, conversation))
      expect(conversation.approved).to.equal(false)
      await datastore.collections.comments.approve(site, conversation.comment, user1, defer(err, comment))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.approved).to.equal(true)
      done()
    )
  )

  describe("#destroy", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should destroy the forum topic also if the comment initiated a forum topic", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: false}, user1, defer(err, site))
      await datastore.collections.conversations.addForum(site, user2, null, {text: "1", forum: {text: "title", tags: []}}, defer(err, conversation))
      await datastore.collections.comments.destroy(site, conversation.comment, defer(err, comment))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation).to.not.exist
      done()
    )
  )


  describe("#flag", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should increment the number of flags", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.create(user2, site, defer(err, profile))
      await datastore.collections.comments.flag(site, comment._id, user2, profile, defer(err, comment))
      expect(comment.no_flags).to.equal(1)
      done()
    )

    it("should attach the user that flagged to the comment object", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.create(user2, site, defer(err, profile))
      await datastore.collections.comments.flag(site, comment._id, user2, profile, defer(err, comment))
      expect(comment.flags[0].equals(user2._id)).to.be.true
      done()
    )
  )

  describe("#clearFlags", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should clear the comment's flags", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.create(user2, site, defer(err, profile))
      await datastore.collections.comments.flag(site, comment._id, user2, profile, defer(err, comment))
      await datastore.collections.comments.clearFlags(site, comment._id, user1, defer(err, comment))
      expect(comment.no_flags).to.equal(0)
      expect(comment.flags).to.be.empty
      done()
    )
  )

  describe("#delete", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should delete the challenge", (done)->
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
      await datastore.collections.comments.delete(site, challenge._id, defer(err, challenge))
      expect(challenge.deleted).to.equal(true)
      done()
    )

    it("should delete the comment", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.delete(site, comment._id, defer(err, comment))
      expect(comment.deleted).to.equal(true)
      done()
    )

    it("should not delete the comment if it is not approved", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: false}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.delete(site, comment._id, defer(err, comment))
      expect(err).to.deep.equal({notexists: true})
      done()
    )

    it.skip("should delete the forum topic also if the comment initiated a forum topic", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.addForum(site, user2, null, {text: "1", forum: {text: "title", tags: []}}, defer(err, conversation))
      await datastore.collections.comments.delete(site, conversation.comment, defer(err, comment))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.deleted).to.equal(true)
      done()
    )

  )

  describe("#likeUpDown", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should increment no_likes and rating if liking up", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(1)
      expect(comment.no_likes_down).to.equal(0)
      expect(comment.rating).to.equal(1)
      done()
    )

    it("should increment conversation activity_rating and set conversation.latest_activity if liking up", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial_rating = conversation.activity_rating
      initial_activity = conversation.latest_activity
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial_rating).to.equal(util.getValue("forumRatingLike"))
      expect(conversation.latest_activity).to.be.gt(initial_activity)
      done()
    )

    it("should leave no_likes, no_likes_down and rating unchanged if liking up twice", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(0)
      expect(comment.no_likes_down).to.equal(0)
      expect(comment.rating).to.equal(0)
      done()
    )

    it("should leave conversation.activity_rating unchanged if liking up twice", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial = conversation.activity_rating
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial).to.equal(0)
      done()
    )

    it("should increment no_likes_down and decrement rating if liking down", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(0)
      expect(comment.no_likes_down).to.equal(1)
      expect(comment.rating).to.equal(-1)
      done()
    )

    it("should increment conversation.activity_rating if liking down", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial = conversation.activity_rating
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial).to.equal(util.getValue("forumRatingLike"))
      done()
    )

    it("should leave no_likes, no_likes_down and rating unchanged if liking down twice", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(0)
      expect(comment.no_likes_down).to.equal(0)
      expect(comment.rating).to.equal(0)
      done()
    )

    it("should leave conversation.activity_rating unchanged if liking down twice", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial = conversation.activity_rating
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial).to.equal(0)
      done()
    )

    it("should retract up like and add down-like if liking up and then down", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(0)
      expect(comment.no_likes_down).to.equal(1)
      expect(comment.rating).to.equal(-1)
      done()
    )

    it("should increment conversation.activity_rating only once if liking up and then down", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial = conversation.activity_rating
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial).to.equal(util.getValue("forumRatingLike"))
      done()
    )

    it("should retract down like and add up like if liking down and then up", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(1)
      expect(comment.no_likes_down).to.equal(0)
      expect(comment.rating).to.equal(1)
      done()
    )

    it("should increment conversation.activity_rating only once if liking down and then up", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial = conversation.activity_rating
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", false, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial).to.equal(util.getValue("forumRatingLike"))
      done()
    )

    it("should increment no_likes and rating when there's no user, only session", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      await datastore.collections.conversations.enter( site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment( site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.likeUpDown(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(1)
      expect(comment.rating).to.equal(1)
      done()
    )

    it("should increment no_likes with extra likes when the user has the benefit", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter( site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.findAndModify({_id: u2profile._id}, [], {$set: {'benefits.extra_vote_points': {expiration: moment().utc().add(1, 'days').valueOf()}}}, {new: true}, defer(err, u2profile))
      await datastore.collections.comments.likeUpDown(site, comment._id, user2, u2profile, null, true, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(util.getValue('likePoints') + util.getValue('extraLikes'))
      done()
    )

    it("should increment no_likes with extra likes and trusted when the user has the benefit and is trusted", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter( site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.findAndModify({_id: u2profile._id}, [], {$set: {trusted: true, 'benefits.extra_vote_points': {expiration: moment().utc().add(1, 'days').valueOf()}}}, {new: true}, defer(err, u2profile))
      await datastore.collections.comments.likeUpDown(site, comment._id, user2, u2profile, null, true, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(util.getValue('trustedLikePoints') + util.getValue('extraLikes'))
      done()
    )

    it("should give extra points to the author if voting with extra_vote_points benefit", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter( site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.findAndModify({_id: u2profile._id}, [], {$set: {'benefits.extra_vote_points': {expiration: moment().utc().add(1, 'days').valueOf()}}}, {new: true}, defer(err, u2profile))
      await datastore.collections.profiles.forSite(user1._id, site, defer(err, u1profileBefore))
      await datastore.collections.comments.likeUpDown(site, comment._id, user2, u2profile, null, true, defer(err, result))
      await datastore.collections.profiles.forSite(user1._id, site, defer(err, u1profile))
      expect(u1profile.points - u1profileBefore.points).to.equal(util.getValue('likePoints') + util.getValue('extraVotePoints'))
      done()
    )

    it("should give extra points and trusted points to the author if voting with extra_vote_points benefit and is trusted", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter( site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment( site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.findAndModify({_id: u2profile._id}, [], {$set: {trusted: true, 'benefits.extra_vote_points': {expiration: moment().utc().add(1, 'days').valueOf()}}}, {new: true}, defer(err, u2profile))
      await datastore.collections.profiles.forSite(user1._id, site, defer(err, u1profileBefore))
      await datastore.collections.comments.likeUpDown(site, comment._id, user2, u2profile, null, true, defer(err, result))
      await datastore.collections.profiles.forSite(user1._id, site, defer(err, u1profile))
      expect(u1profile.points - u1profileBefore.points).to.equal(util.getValue('trustedLikePoints') + util.getValue('extraVotePoints'))
      done()
    )
  )

  describe.skip("#like", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should increment no_likes and rating when there's no user, only session", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.comments.like(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.no_likes).to.equal(1)
      expect(comment.rating).to.equal(1)
      done()
    )

    it("should increment conversation.activity_rating and set conversation.latest_activity", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      initial_rating = conversation.activity_rating
      initial_activity = conversation.latest_activity
      await datastore.collections.comments.like(site, comment._id, null, null, "session_id", true, defer(err, result))
      await datastore.collections.conversations.findOne({_id: conversation._id}, defer(err, conversation))
      expect(conversation.activity_rating - initial_rating).to.equal(util.getValue("forumRatingLike"))
      expect(conversation.latest_activity).to.be.gt(initial_activity)
      done()
    )
  )

  describe("#updateParentsForNew", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should increment context.activity_rating if the activity is a comment", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      comment =
        top: true
        text: "demo"
        parent: conversation._id
        cat: "COMMENT"
        type: "COMMENT"
        level: 1
        context: conversation._id
      await datastore.collections.comments.updateParentsForNew(comment, defer(err))
      await datastore.collections.conversations.findById(conversation._id, defer(err, conversation))
      expect(conversation.activity_rating).to.equal(util.getValue("forumRatingComment"))
      done()
    )

    it("should increment context.(no_comments,no_all_comments,no_activities,no_all_activities) if the activity is a top level comment", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      comment =
        top: true
        text: "demo"
        parent: conversation._id
        cat: "COMMENT"
        type: "COMMENT"
        level: 1
        context: conversation._id
      await datastore.collections.comments.updateParentsForNew(comment, defer(err))
      await datastore.collections.conversations.findById(conversation._id, defer(err, conversation))
      expect(conversation.no_comments).to.equal(1)
      expect(conversation.no_all_comments).to.equal(1)
      expect(conversation.no_activities).to.equal(1)
      expect(conversation.no_all_activities).to.equal(1)
      expect(conversation.no_challenges).to.equal(0)
      expect(conversation.no_questions).to.equal(0)
      done()
    )

    it("should increment context.(no_questions,no_activities,no_all_activities) if the activity is a question", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      question =
        top: true
        text: "demo"
        parent: conversation._id
        question: true
        level: 1
        cat: "QUESTION"
        type: "QUESTION"
        context: conversation._id
      await datastore.collections.comments.updateParentsForNew(question, defer(err))
      await datastore.collections.conversations.findById(conversation._id, defer(err, conversation))
      expect(conversation.no_comments).to.equal(0)
      expect(conversation.no_all_comments).to.equal(0)
      expect(conversation.no_activities).to.equal(1)
      expect(conversation.no_all_activities).to.equal(1)
      expect(conversation.no_challenges).to.equal(0)
      expect(conversation.no_questions).to.equal(1)
      done()
    )

    it("should increment context.(no_challenges,no_activities,no_all_activities) if the activity is a challenge", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      challenge =
        top: true
        parent: conversation._id
        level: 1
        cat: "CHALLENGE"
        type: "CHALLENGE"
        context: conversation._id
      await datastore.collections.comments.updateParentsForNew(challenge, defer(err))
      await datastore.collections.conversations.findById(conversation._id, defer(err, conversation))
      expect(conversation.no_comments).to.equal(0)
      expect(conversation.no_all_comments).to.equal(0)
      expect(conversation.no_activities).to.equal(1)
      expect(conversation.no_all_activities).to.equal(1)
      expect(conversation.no_challenges).to.equal(1)
      expect(conversation.no_questions).to.equal(0)
      done()
    )

    it("should increment context.(no_all_comments,no_all_activities) if the activity is a comment reply to a top level comment", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      id = dbutil.id()
      parent =
        _id: id
        no_comments: 0
      await datastore.collections.comments.insert(parent, defer(err))
      comment =
        top: false
        text: "demo"
        parent: id
        cat: "COMMENT"
        type: "COMMENT"
        level: 2
        context: conversation._id
      await datastore.collections.comments.updateParentsForNew(comment, defer(err))
      await datastore.collections.conversations.findById(conversation._id, defer(err, conversation))
      expect(conversation.no_comments).to.equal(0)
      expect(conversation.no_all_comments).to.equal(1)
      expect(conversation.no_activities).to.equal(0)
      expect(conversation.no_all_activities).to.equal(1)
      expect(conversation.no_challenges).to.equal(0)
      expect(conversation.no_questions).to.equal(0)
      done()
    )

    it("should increment parent.(no_comments) if the activity is a comment reply to a top level comment", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      id = dbutil.id()
      parent =
        _id: id
        no_comments: 0
      await datastore.collections.comments.insert(parent, defer(err))
      comment =
        top: false
        text: "demo"
        parent: id
        cat: "COMMENT"
        type: "COMMENT"
        level: 2
        context: conversation._id
        no_comments: 0
      await datastore.collections.comments.updateParentsForNew(comment, defer(err))
      await datastore.collections.comments.findById(id, defer(err, parent))
      expect(parent.no_comments).to.equal(1)
      expect(parent.no_all_comments).to.equal(undefined)
      expect(parent.no_activities).to.equal(undefined)
      expect(parent.no_all_activities).to.equal(undefined)
      expect(parent.no_challenges).to.equal(undefined)
      expect(parent.no_questions).to.equal(undefined)
      done()
    )

    it("should increment parent.(no_comments,no_all_comments) if the activity is a comment reply to a question", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      id = dbutil.id()
      parent =
        _id: id
        no_comments: 0
        no_all_comments: 0
      await datastore.collections.comments.insert(parent, defer(err))
      comment =
        top: false
        text: "demo"
        parent: id
        cat: "QUESTION"
        type: "COMMENT"
        catParent: id
        level: 2
        context: conversation._id
        no_comments: 0
      await datastore.collections.comments.updateParentsForNew(comment, defer(err))
      await datastore.collections.comments.findById(id, defer(err, parent))
      expect(parent.no_comments).to.equal(1)
      expect(parent.no_all_comments).to.equal(1)
      expect(parent.no_activities).to.equal(undefined)
      expect(parent.no_all_activities).to.equal(undefined)
      expect(parent.no_challenges).to.equal(undefined)
      expect(parent.no_questions).to.equal(undefined)
      done()
    )

    it("should increment parent.(no_comments,no_all_comments) if the activity is a comment reply to a challenge", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      id = dbutil.id()
      parent =
        _id: id
        no_comments: 0
        no_all_comments: 0
      await datastore.collections.comments.insert(parent, defer(err))
      comment =
        top: false
        text: "demo"
        parent: id
        cat: "CHALLENGE"
        type: "COMMENT"
        catParent: id
        level: 2
        context: conversation._id
        no_comments: 0
      await datastore.collections.comments.updateParentsForNew(comment, defer(err))
      await datastore.collections.comments.findById(id, defer(err, parent))
      expect(parent.no_comments).to.equal(1)
      expect(parent.no_all_comments).to.equal(1)
      expect(parent.no_activities).to.equal(undefined)
      expect(parent.no_all_activities).to.equal(undefined)
      expect(parent.no_challenges).to.equal(undefined)
      expect(parent.no_questions).to.equal(undefined)
      done()
    )

    it("should increment parent.(no_comments) and catParent.(no_all_comments) if the activity is a comment at level 2 in a question", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      id = dbutil.id()
      idcat = dbutil.id()
      catParent =
        _id: idcat
        no_comments: 0
      parent =
        _id: id
        no_comments: 0
      await datastore.collections.comments.insert(parent, defer(err))
      await datastore.collections.comments.insert(catParent, defer(err))
      comment =
        top: false
        text: "demo"
        parent: id
        cat: "QUESTION"
        type: "COMMENT"
        catParent: idcat
        level: 2
        context: conversation._id
      await datastore.collections.comments.updateParentsForNew(comment, defer(err))
      await datastore.collections.comments.findById(id, defer(err, parent))
      await datastore.collections.comments.findById(idcat, defer(err, catParent))
      expect(parent.no_comments).to.equal(1)
      expect(parent.no_all_comments).to.equal(undefined)
      expect(parent.no_activities).to.equal(undefined)
      expect(parent.no_all_activities).to.equal(undefined)
      expect(parent.no_challenges).to.equal(undefined)
      expect(parent.no_questions).to.equal(undefined)
      expect(catParent.no_all_comments).to.equal(1)
      expect(catParent.no_activities).to.equal(undefined)
      expect(catParent.no_all_activities).to.equal(undefined)
      expect(catParent.no_challenges).to.equal(undefined)
      expect(catParent.no_questions).to.equal(undefined)
      done()
    )
  )

  describe("#endQuestion", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should mark question as finished", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
      await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      questionAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: true
      await datastore.collections.comments.addComment(site, user1, null, questionAttrs, defer(err, question))
      await datastore.collections.comments.endQuestion(question, defer err, answer, question)
      expect(question.finished).to.equal(true)
      done()
    )

    it("should mark answer as best", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
      await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      questionAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: true
      await datastore.collections.comments.addComment site, user1, null, questionAttrs, defer err, question
      commentAttrs =
        top: false
        text: "demo"
        parent: question._id
      await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, answer
      await datastore.collections.comments.endQuestion(question, defer err, answer, question)

      expect(answer.best).to.equal(true)
      done()
    )
  )
  describe("#modify", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should modify the challenge text if the challenge is approved automatically", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, profile))
      await datastore.collections.comments.modify(site, challenge._id, user2, profile, {challenger: {text: "challenge text modified"}}, defer(err, challenge))
      expect(err).to.not.exist
      expect(challenge.challenger.text).to.equal("challenge text modified")
      done()
    )

    it("should modify the comment text if the comment is approved automatically", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: false
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))
      await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, profile))
      await datastore.collections.comments.modify(site, comment._id, user1, profile, {text: "demo_modified"}, defer(err, comment))
      expect(err).to.not.exist
      expect(comment.text).to.equal("demo_modified")
      done()
    )
  )
)

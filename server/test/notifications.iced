require("./setup")
datastore = require("../datastore")

describe("Notifications", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#newComment", ->

    it("should notify all subscribers except for author when posting comment at level 1", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.subscriptions.userSubscribeForContent(user1, site, conversation._id, defer(err, subscription))
      await datastore.collections.subscriptions.userSubscribeForContent(user2, site, conversation._id, defer(err, subscription))

      await datastore.collections.jobs.remove({}, defer(err))

      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))

      await datastore.collections.jobs.find({}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      job = jarray[0]

      newComment = require("../jobs/jobs/jobs").newComment
      await newComment(job, defer(err))
      await datastore.collections.jobs.remove({_id: job._id}, defer(err))

      await datastore.collections.jobs.find({type: "EMAIL", emailType: "NEW_COMMENT"}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      expect(jarray).to.have.length(1)
      expect(jarray[0].to).to.equal(user2.email)
      expect(jarray[0].emailType).to.equal("NEW_COMMENT")

      await datastore.collections.notifications.find({}, defer(err, notif))
      await notif.toArray(defer(err, narray))
      expect(narray).to.have.length(1)
      expect(narray[0].user.equals(user2._id)).to.be.true
      expect(narray[0].type).to.equal("NEW_COMMENT")

      done()
    )

    it("should notify parent only about the reply when posting comment at level > 1 and parent is subscribed to own activity and parent is also subscribed to conversation", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1@email.com", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2@email.com", "pass", true, defer(err, user2))
      await datastore.collections.users.modify(user2, {name: user2.name, email: user2.email, subscribe: {own_activity: true}}, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.subscriptions.userSubscribeForContent(user1, site, conversation._id, defer(err, subscription))
      await datastore.collections.subscriptions.userSubscribeForContent(user2, site, conversation._id, defer(err, subscription))

      await datastore.collections.jobs.remove({}, defer(err))

      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      commentAttrs = {text: "demo", parent: comment._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, reply))

      await datastore.collections.jobs.find({}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      job = jarray[0]

      newComment = require("../jobs/jobs/jobs").newComment
      await newComment(job, defer(err))
      await datastore.collections.jobs.remove({_id: job._id}, defer(err))

      await datastore.collections.jobs.find({type: "EMAIL", emailType: "REPLY"}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      expect(jarray).to.have.length(1)
      expect(jarray[0].emailType).to.equal("REPLY")
      expect(jarray[0].to).to.equal(user2.email)

      await datastore.collections.notifications.find({}, defer(err, notif))
      await notif.toArray(defer(err, narray))
      expect(narray).to.have.length(1)
      expect(narray[0].user.equals(user2._id)).to.be.true
      expect(narray[0].type).to.equal("REPLY")

      done()
    )

    it("should notify parent about the comment when posting comment at level > 1 and parent is NOT subscribed to own activity and parent is subscribed to conversation", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1@email.com", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2@email.com", "pass", true, defer(err, user2))
      await datastore.collections.users.modify(user2, {name: user2.name, email: user2.email, subscribe: {own_activity: false}}, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.subscriptions.userSubscribeForContent(user1, site, conversation._id, defer(err, subscription))
      await datastore.collections.subscriptions.userSubscribeForContent(user2, site, conversation._id, defer(err, subscription))

      await datastore.collections.jobs.remove({}, defer(err))

      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      commentAttrs = {text: "demo", parent: comment._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, reply))

      await datastore.collections.jobs.find({}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      job = jarray[0]

      newComment = require("../jobs/jobs/jobs").newComment
      await newComment(job, defer(err))
      await datastore.collections.jobs.remove({_id: job._id}, defer(err))

      await datastore.collections.jobs.find({type: "EMAIL", emailType: "NEW_COMMENT"}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      expect(jarray).to.have.length(1)
      expect(jarray[0].emailType).to.equal("NEW_COMMENT")
      expect(jarray[0].to).to.equal(user2.email)

      await datastore.collections.notifications.find({}, defer(err, notif))
      await notif.toArray(defer(err, narray))
      expect(narray).to.have.length(1)
      expect(narray[0].user.equals(user2._id)).to.be.true
      expect(narray[0].type).to.equal("NEW_COMMENT")

      done()
    )

    it("should notify all moderators when posting comment", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.profiles.create(user2, site, false, defer(err, profile))
      await datastore.collections.profiles.findOne({siteName: site.name, user: user1._id}, defer(err, u1profile))
      await datastore.collections.profiles.modify(site, user2._id, {permissions: {moderator: true}}, user1, u1profile, defer(err, profile))
      await datastore.collections.subscriptions.addModSubscription(site, user2, defer(err, subscription))

      await datastore.collections.jobs.remove({}, defer(err))

      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user1, null, commentAttrs, defer(err, comment))

      await datastore.collections.jobs.find({}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      job = jarray[0]

      newComment = require("../jobs/jobs/jobs").newComment
      await newComment(job, defer(err))
      await datastore.collections.jobs.remove({_id: job._id}, defer(err))

      await datastore.collections.jobs.find({type: "EMAIL", emailType: "NEW_COMMENT_MOD"}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      expect(jarray).to.have.length(1)
      expect(jarray[0].to).to.equal(user2.email)

      done()
    )
  )

  describe("#newChallenge", ->

    it("should notify challenged when posting challenge", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user1, site, defer(err, u1profile))
      await datastore.collections.profiles.update({_id: u1profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.subscriptions.userSubscribeForContent(user1, site, conversation._id, defer(err, subscription))
      await datastore.collections.subscriptions.userSubscribeForContent(user2, site, conversation._id, defer(err, subscription))

      await datastore.collections.jobs.remove({}, defer(err))

      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user1, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.jobs.find({}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      job = jarray[0]

      newChallenge = require("../jobs/jobs/jobs").newChallenge
      await newChallenge(job, defer(err))
      await datastore.collections.jobs.remove({_id: job._id}, defer(err))

      await datastore.collections.jobs.find({type: "EMAIL", emailType: "CHALLENGED"}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      expect(jarray).to.have.length(1)
      expect(jarray[0].emailType).to.equal("CHALLENGED")
      expect(jarray[0].to).to.equal(user2.email)

      await datastore.collections.notifications.find({}, defer(err, notif))
      await notif.toArray(defer(err, narray))
      expect(narray).to.have.length(1)
      expect(narray[0].user.equals(user2._id)).to.be.true
      expect(narray[0].type).to.equal("CHALLENGED")

      done()
    )

    it("should notify all moderators when posting challenge", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      # challenged author should not be subscribed to own activity
      await datastore.collections.users.update({_id: user2._id}, {$set: {"subscribe.own_activity": false}}, defer(err))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.profiles.create(user2, site, false, defer(err, profile))
      await datastore.collections.profiles.findOne({siteName: site.name, user: user1._id}, defer(err, u1profile))
      await datastore.collections.profiles.modify(site, user2._id, {permissions: {moderator: true}}, user1, u1profile, defer(err, profile))
      await datastore.collections.profiles.update({_id: u1profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.subscriptions.addModSubscription(site, user2, defer(err, subscription))

      await datastore.collections.jobs.remove({}, defer(err))

      commentAttrs = {top: true, text: "demo", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      challengeAttrs =
        parent: conversation._id
        challenged: comment._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user1, null, challengeAttrs, defer(err, challenge))

      await datastore.collections.jobs.find({}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      job = jarray[0]

      newChallenge = require("../jobs/jobs/jobs").newChallenge
      await newChallenge(job, defer(err))
      await datastore.collections.jobs.remove({_id: job._id}, defer(err))

      await datastore.collections.jobs.find({type: "EMAIL", emailType: "NEW_CHALLENGE_MOD"}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      expect(jarray).to.have.length(1)
      expect(jarray[0].to).to.equal(user2.email)

      done()
    )
  )
)

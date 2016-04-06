require("./setup")
datastore = require("../datastore")
dbutil = require("../datastore/util")
async = require("async")
moment = require('moment')

describe("Comments", ->

  describe("#addComment", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should add bet", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, 'test', defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, bet: true, bet_type: 'targeted_closed', text: "demo", parent: conversation._id, points: 200, users: [user1._id], ratio_joined: 1, ratio_accepted: 1, end_date: moment().add('days', 1).valueOf()}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      expect(comment).to.exist
      done()
    )

    it("should not allow adding a bet when the odds would split into chunks smaller than the minimum pts to accept", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, 'test', defer(err, u2profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, bet: true, bet_type: 'targeted_closed', text: "demo", parent: conversation._id, points: 30, users: [user1._id], ratio_joined: 2, ratio_accepted: 1, end_date: moment().add('days', 1).valueOf()}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      expect(err).to.exist
      expect(err.bet_invalid_points_value).to.equal(true)
      done()
    )
  )

  describe("#acceptBet", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it('should create job to notify participants in bet', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.jobs.findToArray({type: 'BET_ACCEPTED', 'comment._id': comment._id}, defer(err, jobs))
      expect(jobs.length).to.equal(1)
      done()
    )

    it('should not accept bet with less than the available points when there are less than (2 * minimum points) available points', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_open',
        users: [user3._id]
        points: 85,
        ratio_joined: 1,
        ratio_accepted: 1,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 25}, defer(err, comment))
      expect(err).to.exist
      expect(err.invalid_points_value).to.be.true
      done()
    )
  )

  describe("#declineBet", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it('should create job to notify participants in bet', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.declineBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.jobs.findToArray({type: 'BET_DECLINED', 'comment._id': comment._id}, defer(err, jobs))
      expect(jobs.length).to.equal(1)
      done()
    )
  )

  describe("#forfeitBet", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it('should create job to notify participants in bet', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user6, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.forfeitBet(site, conversation, user2, comment, defer(err, comment))
      await datastore.collections.jobs.findToArray({type: 'BET_FORFEITED', 'comment._id': comment._id}, defer(err, jobs))
      expect(jobs.length).to.equal(1)
      done()
    )

    it('should resolve bet if 2 out of 3 who accepted forfeit', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.forfeitBet(site, conversation, user3, comment, defer(err, comment))
      await datastore.collections.comments.forfeitBet(site, conversation, user4, comment, defer(err, comment))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.bet_status).to.equal('resolved')
      done()
    )

    it('should resolve bet if 2 out of 4 who accepted forfeit', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.profiles.update({user: user6._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 300,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user6, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.forfeitBet(site, conversation, user3, comment, defer(err, comment))
      await datastore.collections.comments.forfeitBet(site, conversation, user4, comment, defer(err, comment))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.bet_status).to.equal('resolved')
      done()
    )

    it('should resolve bet if only the initiator forfeits', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.forfeitBet(site, conversation, user2, comment, defer(err, comment))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.bet_status).to.equal('resolved')
      done()
    )

    it('should not resolve bet if 2 out of 5 who accepted forfeit', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.users.createOwnAccount("u7", "email7", "pass", true, defer(err, user7))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.profiles.update({user: user6._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user7, site, defer(err, u7profile))
      await datastore.collections.profiles.update({user: user7._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id, user7._id]
        points: 200,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user6, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user7, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.forfeitBet(site, conversation, user3, comment, defer(err, comment))
      await datastore.collections.comments.forfeitBet(site, conversation, user4, comment, defer(err, comment))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.bet_status).to.equal('forf')
      done()
    )
  )

  describe("#endBet", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it('should end bets that have expired', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.profiles.update({user: user1._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user2, site, defer(err, u6profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'open',
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        start_forf_date: now.add('days', 1).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user1, comment, {points: 50}, defer(err, comment))
      check = (comment)->
        await datastore.collections.comments.endBet(comment, defer(err, comment))
        expect(comment.bet_status).to.equal('closed')
        done()
      setTimeout((-> check(comment)), 3000)
    )

    it('should directly resolve as tie if no users accepted', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.profiles.update({user: user1._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user2, site, defer(err, u6profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'open',
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        start_forf_date: now.add('days', 1).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      expect(comment.bet_status).to.equal('resolved')
      await datastore.collections.jobs.count({type: 'NOTIFY_BET_RESOLVED', 'comment._id': comment._id}, defer(err, no_jobs_notif_rsv))
      expect(no_jobs_notif_rsv).to.equal(1)
      done()
    )

    it('should end bet if all points have been accepted', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", false, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.profiles.update({user: user1._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'open',
        points: 50,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        start_forf_date: now.add('days', 1).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user1, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      expect(comment.bet_status).to.equal('closed')
      done()
    )

  )

  describe("#endForfBet", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it('should end forfeiting period', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.profiles.update({user: user1._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user2, site, defer(err, u6profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'open',
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        end_date: now.add('days', 1).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user1, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.comments.endForfBet(comment, {force: true}, defer(err))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.bet_status).to.equal('forf_closed')
      done()
    )

    it('should add job to send message to the moderators if the bet cannot be resolved (undecided)', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.subscriptions.addModSubscription(site, user1, defer(err))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.profiles.update({user: user1._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user2, site, defer(err, u6profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_open',
        users: [user1._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user1, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.comments.endForfBet(comment, {force: true}, defer(err, comment))
      expect(comment.bet_winning_side).to.equal('undecided')
      await datastore.collections.jobs.findToArray({type: 'NOTIFY_BET_UNRESOLVED', 'comment._id': comment._id}, defer(err, jobs))
      expect(jobs.length).to.equal(1)
      done()
    )

    # it.skip('should send message to the moderators if the bet cannot be resolved (undecided)', (done)->
    #   await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
    #   await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
    #   await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
    #   await datastore.collections.subscriptions.addModSubscription(site, user1, defer(err))
    #   await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
    #   await datastore.collections.profiles.update({user: user1._id}, {$set: {points: 1000}}, defer(err))
    #   await datastore.collections.profiles.create(user2, site, defer(err, u6profile))
    #   await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
    #   now = moment()
    #   commentAttrs = {
    #     top: true,
    #     text: "demo",
    #     parent: conversation._id,
    #     bet: true,
    #     bet_type: 'targeted_open',
    #     users: [user1._id]
    #     points: 100,
    #     ratio_joined: 1,
    #     ratio_accepted: 2,
    #     end_date: now.add('seconds', 2).valueOf()
    #     users: []
    #   }
    #   await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
    #   await datastore.collections.comments.acceptBet(site, conversation, user1, comment, {points: 50}, defer(err, comment))
    #   await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
    #   await datastore.collections.comments.endForfBet(comment, {force: true}, defer(err, comment))
    #   expect(comment.bet_winning_side).to.equal('undecided')
    #   await datastore.collections.jobs.findToArray({type: 'EMAIL', emailType: 'BET_UNRESOLVED', to: user1.email, 'comment._id': comment._id}, defer(err, jobs))
    #   expect(jobs.length).to.equal(1)
    #   done()
    # )
  )

  describe("#resolveBetPoints", ->
    beforeEach((done)->
      require("./setup").clear(done)
    )

    it('should distribute all 100 offered points to all 3 accepting users', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", false, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", false, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", false, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", false, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.declineBet(site, conversation, user6, comment, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.comments.forfeitBet(site, conversation, user2, comment, defer(err, comment))
      await datastore.collections.comments.endForfBet(comment, {force: true}, defer(err))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      expect(comment.bet_status).to.equal('resolved')
      await datastore.collections.comments.resolveBetPoints(comment, defer(err, comment))
      expect(comment.bet_status).to.equal('resolved_pts')
      pts_accepted = _.pick(comment.bet_points_resolved, _.map(comment.bet_accepted, (a)-> a.toHexString()))
      expect(_.reduce(pts_accepted, (sum, p)-> sum + p)).to.equal(225)
      done()
    )
  )
)

describe("jobs", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("newComment", ->

    it("should notify bet targets about the new bet", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))

      await datastore.collections.jobs.findOne({type: 'NEW_COMMENT'}, defer(err, job))
      newComment = require("../jobs/jobs/jobs").newComment
      await datastore.collections.jobs.remove({}, defer(err))
      await newComment(job, defer(err))

      await datastore.collections.jobs.find({type: "EMAIL", emailType: "BET_TARGETED"}, defer(err, jobs))
      await jobs.toArray(defer(err, jarray))
      expect(jarray).to.have.length(4)
      expect(_.pluck(jarray, 'to')).to.deep.equal([user3.email, user4.email, user5.email, user6.email])

      await datastore.collections.notifications.find({type: "BET_TARGETED"}, defer(err, notif))
      await notif.toArray(defer(err, narray))
      expect(narray).to.have.length(4)
      expect(_.map(narray, (n)-> n.user.toHexString())).to.deep.equal([user3._id.toHexString(), user4._id.toHexString(), user5._id.toHexString(), user6._id.toHexString()])
      done()
    )
  )

  describe('#betAccepted', ->
    it('should send emails to the other participants (accepted + author + pending) (not to the user who accepted)', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.jobs.findToArray({type: 'BET_ACCEPTED', 'comment._id': comment._id}, defer(err, jobs))
      expect(jobs.length).to.equal(1)
      job_accepted = require("../jobs/jobs/jobs").betAccepted
      await datastore.collections.jobs.remove({}, defer(err))
      await job_accepted(jobs[0], defer(err))
      await datastore.collections.jobs.findToArray({type: 'EMAIL', emailType: 'BET_ACCEPTED'}, defer(err, emails))
      expect(emails.length).to.equal(4)
      expect(_.pluck(emails, 'to').sort()).to.deep.equal([user2.email, user4.email, user5.email, user6.email].sort())
      done()
    )
  )

  describe('#betDeclined', ->
    it('should send emails to the other participants (accepted + author + pending) (not to the user who declined)', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.declineBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.jobs.findToArray({type: 'BET_DECLINED', 'comment._id': comment._id}, defer(err, jobs))
      expect(jobs.length).to.equal(1)
      job_accepted = require("../jobs/jobs/jobs").betDeclined
      await datastore.collections.jobs.remove({}, defer(err))
      await job_accepted(jobs[0], defer(err))
      await datastore.collections.jobs.findToArray({type: 'EMAIL', emailType: 'BET_DECLINED'}, defer(err, emails))
      expect(emails.length).to.equal(4)
      expect(_.pluck(emails, 'to').sort()).to.deep.equal([user2.email, user4.email, user5.email, user6.email].sort())
      done()
    )
  )

  describe('#betForfeited', ->
    it('should send emails to the other participants (accepted + author) (not to the user who declined)', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", true, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", true, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.declineBet(site, conversation, user6, comment, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.jobs.remove({}, defer(err))
      await datastore.collections.comments.forfeitBet(site, conversation, user3, comment, defer(err, comment))
      await datastore.collections.jobs.findToArray({type: 'BET_FORFEITED', 'comment._id': comment._id}, defer(err, jobs))
      expect(jobs.length).to.equal(1)
      job_forfeited = require("../jobs/jobs/jobs").betForfeited
      await datastore.collections.jobs.remove({}, defer(err))
      await job_forfeited(jobs[0], defer(err))
      await datastore.collections.jobs.findToArray({type: 'EMAIL', emailType: 'BET_FORFEITED'}, defer(err, emails))
      expect(emails.length).to.equal(3)
      expect(_.pluck(emails, 'to').sort()).to.deep.equal([user2.email, user4.email, user5.email].sort())
      done()
    )
  )

  describe('#getWinStatusInBet', ->
    it('should say winner for user3', (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", false, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", false, defer(err, user4))
      await datastore.collections.users.createOwnAccount("u5", "email5", "pass", false, defer(err, user5))
      await datastore.collections.users.createOwnAccount("u6", "email6", "pass", false, defer(err, user6))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({user: user2._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user4, site, defer(err, u4profile))
      await datastore.collections.profiles.update({user: user4._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user5, site, defer(err, u5profile))
      await datastore.collections.profiles.update({user: user5._id}, {$set: {points: 1000}}, defer(err))
      await datastore.collections.profiles.create(user6, site, defer(err, u6profile))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      now = moment()
      commentAttrs = {
        top: true,
        text: "demo",
        parent: conversation._id,
        bet: true,
        bet_type: 'targeted_closed',
        users: [user3._id, user4._id, user5._id, user6._id]
        points: 100,
        ratio_joined: 1,
        ratio_accepted: 2,
        end_date: now.add('seconds', 2).valueOf()
        users: []
      }
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user3, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user4, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.acceptBet(site, conversation, user5, comment, {points: 50}, defer(err, comment))
      await datastore.collections.comments.declineBet(site, conversation, user6, comment, defer(err, comment))
      await datastore.collections.comments.endBet(comment, {force: true}, defer(err, comment))
      await datastore.collections.comments.forfeitBet(site, conversation, user2, comment, defer(err, comment))
      await datastore.collections.comments.endForfBet(comment, {force: true}, defer(err))
      await datastore.collections.comments.findOne({_id: comment._id}, defer(err, comment))
      await datastore.collections.comments.resolveBetPoints(comment, defer(err, comment))
      win_status_u3 = datastore.collections.comments.getWinStatusInBet(comment, user3._id)
      expect(win_status_u3).to.equal('winner')
      done()
    )
  )
)

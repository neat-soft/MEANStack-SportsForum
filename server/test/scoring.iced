require("./setup")
datastore = require("../datastore")

describe("Point system", ->

  describe("Challenges", ->

    beforeEach((done)->
      require("./setup").clear(done)
    )

    describe("#end", ->

      it("should give points to the winner", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge
        await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", true, defer(err, result))
        await datastore.collections.comments.findOne {_id: challenge._id}, defer err, challenge

        await datastore.collections.profiles.findOne {user: user2._id, siteName: "test"}, defer err, u2profilebefore
        await datastore.collections.convprofiles.findOne {user: user2._id, context: challenge.context}, defer err, u2convprofilebefore

        await datastore.collections.comments.endChallenge challenge, defer err, challenge
        await datastore.collections.profiles.findOne {user: user2._id, siteName: "test"}, defer err, u2profile
        await datastore.collections.convprofiles.findOne {user: user2._id, context: challenge.context}, defer err, u2convprofile

        expect(u2profile.points - u2profilebefore.points).to.equal(site.points_settings.for_challenge_winner)
        expect(u2convprofile.points - u2convprofilebefore.points).to.equal(site.points_settings.for_challenge_winner)
        done()
      )

      it("should take points from the loser", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge
        await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", true, defer(err, result))
        await datastore.collections.comments.findOne {_id: challenge._id}, defer err, challenge

        await datastore.collections.profiles.findOne {user: user1._id, siteName: "test"}, defer err, u1profilebefore
        await datastore.collections.convprofiles.findOne {user: user1._id, context: challenge.context}, defer err, u1convprofilebefore

        await datastore.collections.comments.endChallenge challenge, defer err, challenge

        await datastore.collections.profiles.findOne {user: user1._id, siteName: "test"}, defer err, u1profile
        await datastore.collections.convprofiles.findOne {user: user1._id, context: challenge.context}, defer err, u1convprofile

        expect(u1profile.points - u1profilebefore.points).to.equal(util.getValue("challengeLoserPoints"))
        expect(u1convprofile.points - u1convprofilebefore.points).to.equal(util.getValue("challengeLoserPoints"))
        done()
      )
    )

    describe("#vote", ->
      it("should give points to the voter", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge
        await datastore.collections.profiles.create(user3, site, defer(err, u3profilebefore))
        await datastore.collections.convprofiles.create(user3, challenge.context, defer(err, u3convprofilebefore))
        await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", true, defer(err, result))
        await datastore.collections.profiles.findOne({user: user3._id, siteName: site.name}, defer(err, u3profile))
        await datastore.collections.convprofiles.findOne({user: user3._id, context: challenge.context}, defer(err, u3convprofile))

        expect(u3profile.points - u3profilebefore.points).to.equal(util.getValue("voterInChallenge"))
        expect(u3convprofile.points - u3convprofilebefore.points).to.equal(util.getValue("voterInChallenge"))
        done()
      )

      it("should take points from the voter if voted down", (done)->
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge
        await datastore.collections.profiles.create(user3, site, defer(err, u3profilebefore))
        await datastore.collections.convprofiles.create(user3, challenge.context, defer(err, u3convprofilebefore))
        await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", true, defer(err, result))
        await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", false, defer(err, result))
        await datastore.collections.profiles.findOne({user: user3._id, siteName: site.name}, defer(err, u3profile))
        await datastore.collections.convprofiles.findOne({user: user3._id, context: challenge.context}, defer(err, u3convprofile))
        expect(u3profile.points - u3profilebefore.points).to.equal(0)
        expect(u3convprofile.points - u3convprofilebefore.points).to.equal(0)

        done()
      )

      it("should give points to the voted side", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profilebefore))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: challenge.context}, defer(err, u2convprofilebefore))
        await datastore.collections.comments.vote(site, challenge._id, user3, null, null, "challenger", true, defer(err, result))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: challenge.context}, defer(err, u2convprofile))
        expect(u2profile.points - u2profilebefore.points).to.equal(util.getValue("votePoints"))
        expect(u2convprofilebefore).to.equal(null) # conversation profiles are only created when points are awarded
        expect(u2convprofile.points).to.equal(util.getValue("votePoints"))

        done()
      )

      it("should take points from the voted side if voted down", (done)->
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge

        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profilebefore))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: challenge.context}, defer(err, u2convprofilebefore))
        await datastore.collections.comments.vote site, challenge._id, user3, null, null, "challenger", true, defer err, result
        await datastore.collections.comments.vote site, challenge._id, user3, null, null, "challenger", false, defer err, result
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: challenge.context}, defer(err, u2convprofile))
        expect(u2profile.points - u2profilebefore.points).to.equal(0)
        expect(u2convprofilebefore).to.equal(null)
        expect(u2convprofile.points).to.equal(0)

        done()
      )
    )

    describe("#destroy", ->
      it("should take profile & conv points if removed", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge(site, user2, null, challengeAttrs, defer(err, challenge))
        # set to not approved
        await datastore.collections.comments.findAndModify({_id: challenge._id}, {}, {$set: {approved: false}}, {new: true}, defer(err, challenge))
        await datastore.collections.profiles.create(user2, site, defer(err, u2profilebefore))
        await datastore.collections.convprofiles.create(user2, conversation, defer(err, u2convprofilebefore))
        await datastore.collections.comments.destroy(site, challenge._id, false, defer(err, result))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: challenge.context}, defer(err, u2convprofile))
        expect(u2profile.points - u2profilebefore.points).to.equal(util.getValue("moderatorDeletesChallenge") - challenge.cost)
        expect(u2convprofile.points - u2convprofilebefore.points).to.equal(util.getValue("moderatorDeletesChallenge") - challenge.cost)

        done()
      )
    )
  )

  describe("Comments", ->

    beforeEach((done)->
      require("./setup").clear(done)
    )

    describe("#likeUpDown", ->
      it("should give points to the voter if comment is regular")
      it("should give points to the voter if comment is answer")

      it("should give points to the author if the comment is answer", (done)->
        util = require("../util")
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
        answerAttrs =
          top: false
          text: "demo answer"
          parent: question._id
        await datastore.collections.comments.addComment site, user2, null, answerAttrs, defer err, answer
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profilebefore))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofilebefore))
        await datastore.collections.comments.likeUpDown(site, answer._id, user3, null, null, true, defer(err, result))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: question.context}, defer(err, u2convprofile))

        expect(u2profile.points - u2profilebefore.points).to.equal(util.getValue("likePointsAnswer"))
        expect(u2convprofilebefore).to.equal(null)
        expect(u2convprofile.points).to.equal(util.getValue("likePointsAnswer"))

        done()
      )

      it("should take points from the author if the comment is answer and liked down", (done)->
        util = require("../util")
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
        answerAttrs =
          top: false
          text: "demo answer"
          parent: question._id
        await datastore.collections.comments.addComment site, user2, null, answerAttrs, defer err, answer
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profilebefore))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofilebefore))
        await datastore.collections.comments.likeUpDown(site, answer._id, user3, null, null, false, defer(err, result))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofile))

        expect(u2profile.points - u2profilebefore.points).to.equal(-util.getValue('likePointsAnswer'))
        expect(u2convprofilebefore).to.equal(null)
        expect(u2convprofile.points).to.equal(-util.getValue('likePointsAnswer'))

        done()
      )
    )

    describe("#addComment", ->
      it("should give points to the author if the comment is regular", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        questionAttrs =
          top: true
          text: "demo"
          parent: conversation._id
        await datastore.collections.profiles.create(user1, site, defer(err, u1profilebefore))
        await datastore.collections.convprofiles.create(user1, conversation, defer(err, u1convprofilebefore))
        await datastore.collections.comments.addComment site, user1, null, questionAttrs, defer err, comment
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))

        expect(u1profile.points - u1profilebefore.points).to.equal(site.points_settings.for_comment)
        expect(u1convprofile.points - u1convprofilebefore.points).to.equal(site.points_settings.for_comment)

        done()
      )

      it("should give points to the challenged and challenger if the comment is in a challenge", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge
        commentAttrs =
          top: false
          parent: challenge._id
          text: "aaa"

        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profilebefore))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profilebefore))

        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofilebefore))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofilebefore))

        await datastore.collections.comments.addComment site, user3, null, commentAttrs, defer err, commentInChallenge

        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))
        expect(u1profile.points - u1profilebefore.points).to.equal(util.getValue("commentInOwnChallengePoints"))
        expect(u1convprofile.points - u1convprofilebefore.points).to.equal(util.getValue("commentInOwnChallengePoints"))

        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofile))
        expect(u2profile.points - u2profilebefore.points).to.equal(util.getValue("commentInOwnChallengePoints"))
        expect(u2convprofilebefore).to.equal(null)
        expect(u2convprofile.points).to.equal(util.getValue("commentInOwnChallengePoints"))

        done()
      )

      it("should give points to the challenged and challenger if replying to a comment in a challenge", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs = {top: true, text: "demo", parent: conversation._id}
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        challengeAttrs =
          parent: conversation._id
          challenged: comment._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
        await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
        await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
        await datastore.collections.comments.addChallenge site, user2, null, challengeAttrs, defer err, challenge
        commentAttrs =
          top: false
          parent: challenge._id
          text: "aaa"
        await datastore.collections.comments.addComment(site, user3, null, commentAttrs, defer(err, commentInChallenge))

        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profilebefore))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofilebefore))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profilebefore))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofilebefore))

        replyAttrs =
          top: false
          parent: commentInChallenge._id
          text: "aaa"
        await datastore.collections.comments.addComment site, user3, null, replyAttrs, defer err, reply

        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))
        expect(u1profile.points - u1profilebefore.points).to.equal(util.getValue("commentInOwnChallengePoints"))
        expect(u1convprofile.points - u1convprofilebefore.points).to.equal(util.getValue("commentInOwnChallengePoints"))

        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofile))
        expect(u2profile.points - u2profilebefore.points).to.equal(util.getValue("commentInOwnChallengePoints"))
        expect(u2convprofile.points - u2convprofilebefore.points).to.equal(util.getValue("commentInOwnChallengePoints"))

        done()
      )

      it("should take points for asking a question", (done)->
        util = require("../util")
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
        await datastore.collections.profiles.create(user1, site, defer(err, u1profilebefore))
        await datastore.collections.comments.addComment site, user1, null, questionAttrs, defer err, question
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))
        expect(u1profile.points - u1profilebefore.points).to.equal(util.getValue("questionPoints"))
        expect(u1convprofile.points).to.equal(util.getValue("questionPoints"))
        done()
      )

      it("should give points to the asker for each answer", (done)->
        util = require("../util")
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
        answerAttrs =
          top: false
          text: "demo answer"
          parent: question._id
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profilebefore))
        await datastore.collections.comments.addComment site, user2, null, answerAttrs, defer err, answer
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))
        expect(u1profile.points - u1profilebefore.points).to.equal(util.getValue("answerPointsAsker"))
        expect(u1convprofile.points).to.equal(util.getValue("answerPointsAsker"))
        done()
      )

      it("should not give points to the asker for replies to answers", (done)->
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
        answerAttrs =
          top: false
          text: "demo answer"
          parent: question._id
        await datastore.collections.comments.addComment site, user2, null, answerAttrs, defer err, answer
        replyAttrs =
          top: false
          text: "demo answer"
          parent: answer._id
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profilebefore))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofilebefore))
        await datastore.collections.comments.addComment site, user2, null, replyAttrs, defer err, reply
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))
        expect(u1profile.points - u1profilebefore.points).to.equal(0)
        expect(u1convprofile.points - u1convprofilebefore.points).to.equal(0)
        done()
      )
    )

    describe("#endQuestion", ->
      it("should give points to the best answer", (done)->
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.users.createOwnAccount "u4", "email4", "pass", true, defer err, user4
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        questionAttrs =
          top: true
          text: "demo"
          parent: conversation._id
          question: true
        await datastore.collections.comments.addComment site, user1, null, questionAttrs, defer err, question
        answerAttrs =
          top: false
          text: "demo answer"
          parent: question._id
        await datastore.collections.comments.addComment site, user4, null, answerAttrs, defer err, answer
        answer2Attrs =
          top: false
          text: "demo answer"
          parent: question._id
        await datastore.collections.comments.addComment site, user2, null, answer2Attrs, defer err, answer2
        answer3Attrs =
          top: false
          text: "demo answer"
          parent: question._id
        await datastore.collections.comments.addComment site, user3, null, answer3Attrs, defer err, answer3
        await datastore.collections.comments.likeUpDown(site, answer._id, user3, null, null, true, defer(err, result))
        await datastore.collections.comments.likeUpDown(site, answer2._id, user3, null, null, true, defer(err, result))
        await datastore.collections.comments.likeUpDown(site, answer3._id, user4, null, null, true, defer(err, result))
        await datastore.collections.comments.likeUpDown(site, answer2._id, user4, null, null, true, defer(err, result))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profilebefore))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofilebefore))
        await datastore.collections.comments.endQuestion(question, defer(err, answer, question))
        await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
        await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2convprofile))
        expect(u2profile.points - u2profilebefore.points).to.equal(question.questionPointsOffered)
        expect(u2convprofile.points - u2convprofilebefore.points).to.equal(question.questionPointsOffered)
        done()
      )
    )

    describe("#destroy", ->
      it("should take points if removed and comment is regular", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs =
          top: true
          text: "demo"
          parent: conversation._id
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profilebefore))
        # mark comment as not approved
        await datastore.collections.comments.findAndModify({_id: comment._id}, {}, {$set: {approved: false}}, {new: true}, defer(err, comment))
        await datastore.collections.comments.destroy(site, comment._id, defer(err, result))
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))
        expect(u1profile.points - u1profilebefore.points).to.equal(util.getValue("moderatorDeletesComment"))
        expect(u1convprofile.points).to.equal(util.getValue("moderatorDeletesComment"))
        done()
      )

      it("should take points if removed and comment is question", (done)->
        util = require("../util")
        await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
        await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
        await datastore.collections.users.createOwnAccount "u3", "email3", "pass", true, defer err, user3
        await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

        await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
        commentAttrs =
          top: true
          text: "demo"
          parent: conversation._id
          question: true
        await datastore.collections.comments.addComment site, user1, null, commentAttrs, defer err, comment
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profilebefore))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofilebefore))
        # mark comment as not approved
        await datastore.collections.comments.findAndModify({_id: comment._id}, {}, {$set: {approved: false}}, {new: true}, defer(err, comment))
        await datastore.collections.comments.destroy(site, comment._id, defer(err, result))
        await datastore.collections.profiles.findOne({user: user1._id, siteName: site.name}, defer(err, u1profile))
        await datastore.collections.convprofiles.findOne({user: user1._id, context: conversation._id}, defer(err, u1convprofile))
        expect(u1profile.points - u1profilebefore.points).to.equal(util.getValue("moderatorDeletesQuestion"))
        expect(u1convprofile.points - u1convprofilebefore.points).to.equal(util.getValue("moderatorDeletesQuestion"))
        done()
      )
    )
  )
)

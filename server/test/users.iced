require("./setup")
datastore = require("../datastore")
moment = require("moment")

describe("Users", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#ensureUser", ->
    it("should send verification email only when the user is new", (done)->
      query = {serviceId: 'email@email.com', type: 'own', site: 'burnzone'}
      attrs = {email: 'email@email.com', verified: false, customData: false}
      await datastore.collections.users.ensureUser(query, attrs, defer(err, user))
      expect(user).to.exist
      await datastore.collections.jobs.count({type: "EMAIL", emailType: "VERIFICATION"}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.ensureUser(query, attrs, defer(err, user))
      await datastore.collections.jobs.count({type: "EMAIL", emailType: "VERIFICATION"}, defer(err, count))
      expect(count).to.equal(1)
      done()
    )
  )

  describe("#ensureUserAutoUpdate", ->
    it("should create user", (done)->
      query = {email: 'email@email.com', type: 'own', site: 'burnzone'}
      attrs = {email: 'email@email.com', verified: false, customData: false, name: "name1"}
      await datastore.collections.users.ensureUserAutoUpdate(query, attrs, defer(err, user))
      expect(err).to.not.exist
      expect(user).to.exist
      done()
    )

    it("should update user attrs ", (done)->
      query = {email: 'email@email.com', type: 'own', site: 'burnzone'}
      attrs = {email: 'email@email.com', verified: false, customData: false, name: "name1"}
      await datastore.collections.users.ensureUserAutoUpdate(query, attrs, defer(err, user))
      expect(user.name).to.equal("name1")
      attrs.name = "name2"
      await datastore.collections.users.ensureUserAutoUpdate(query, attrs, defer(err, user))
      expect(user.name).to.equal("name2")
      done()
    )
  )

  describe("#login3rdParty", ->
    it("should create facebook user with verified address", (done)->
      profile =
        id: "123"
        emails: [{value: "email@email.com"}]
        displayName: "blabla"
      await datastore.collections.users.login3rdParty("facebook", profile, defer(err, user))
      expect(err).to.not.exist
      expect(user.logins.facebook).to.equal(profile.id)
      expect(user.name).to.equal(profile.displayName)
      expect(user.email).to.equal(profile.emails[0].value)
      expect(user.verified).to.be.true
      done()
    )

    it("should automatically merge existing old type facebook/twitter/google users", (done)->
      await datastore.collections.users.insert({type: "facebook", serviceId: "123", email: "gigi"}, defer(err, fb_inserted))
      profile =
        id: "123"
        emails: [{value: "email@email.com"}]
        displayName: "blabla"
      await datastore.collections.users.login3rdParty("facebook", profile, defer(err, user))
      await datastore.collections.jobs.findOne({type: "MERGE_USERS"}, defer(err, job))
      expect(job).to.exist
      expect(job.from._id.equals(fb_inserted[0]._id)).to.equal(true)
      done()
    )
  )

  describe("#attach3rdPartyLogin", ->
    it("should automatically merge existing old type facebook/twitter/google users", (done)->
      await datastore.collections.users.insert({type: "facebook", serviceId: "123", email: "gigi"}, defer(err, fb_inserted))
      profile =
        id: "123"
        emails: [{value: "email@email.com"}]
        displayName: "blabla"
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", true, defer(err, user))
      await datastore.collections.users.attach3rdPartyLogin(user, "facebook", profile, defer(err, user))
      await datastore.collections.jobs.findOne({type: "MERGE_USERS"}, defer(err, job))
      expect(job).to.exist
      expect(job.from._id.equals(fb_inserted[0]._id)).to.equal(true)
      done()
    )
  )

  describe("#createOwnAccount", ->
    it("should create user with verified address", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", true, defer(err, user))
      expect(err).to.not.exist
      expect(user.name).to.equal(name)
      expect(user.email).to.equal(email)
      expect(user.verified).to.be.true
      done()
    )

    it("should send verification email if not verified", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", false, defer(err, user))
      expect(user.verified).to.be.false
      await datastore.collections.jobs.findOne({type: "EMAIL", emailType: "VERIFICATION"}, defer(err, job))
      expect(job).to.exist
      done()
    )
  )

  describe("#verify", ->
    it("should mark the user object as verified", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", false, defer(err, user))
      await datastore.collections.users.verify(user.vtoken, defer(err, user))
      expect(err).to.not.exist
      expect(user.verified).to.be.true
      done()
    )
  )

  describe("#modify", ->
    it("should mark the user as not verified when changing the email address", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", true, defer(err, user))
      await datastore.collections.users.modify(user, {name: "a", email: "email2@email.com"}, "pass", defer(err, user))
      expect(user.verified).to.be.false
      done()
    )

    it("should set the email to lowercase", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", true, defer(err, user))
      await datastore.collections.users.modify(user, {name: "a", email: "EmAil2@email.com"}, "pass", defer(err, user))
      expect(user.email).to.equal('email2@email.com')
      done()
    )

    it("should unsubscribe from all conversations when the user disables auto subscribe to conversations", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.modify(user2, {name: 'a', subscribe: {auto_to_conv: true}}, "pass", defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      await datastore.collections.subscriptions.userSubscribeForConv(user2, site, defer(err, subscription))
      await datastore.collections.users.modify(user2, {name: 'a', subscribe: {auto_to_conv: false}}, "pass", defer(err, user2))
      await datastore.collections.subscriptions.forSite(site, user2.email, defer(err, subscr))
      expect(subscr.active).to.equal(false)
      done()
    )
  )

  describe("#forMerge", ->
    it("should return imported and guest as a single entry with summed counts", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", true, defer(err, user))
      await datastore.collections.users.insert({type: "imported", email: "email@email.com"}, defer(err, imported_user))
      imported_user = imported_user[0]
      await datastore.collections.comments.insert({guest: {name: 'gigi', email: "email@email.com"}, text: "aaa", ptext: "<p>aaa</p>"}, defer(err, guest_comment))
      guest_comment = guest_comment[0]
      await datastore.collections.users.forMerge(user, defer(err, users_for_merge))
      expect(users_for_merge).to.have.length(1)
      expect(users_for_merge[0].count).to.equal(2)
      done()
    )
  )

  describe("#merge", ->
    it("should copy the logins from the source user", (done)->
      await datastore.collections.users.createOwnAccount("name", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("name", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.attach3rdPartyLogin(user2, "facebook", {id: "1234"}, defer(err))
      await datastore.collections.users.merge(user2._id, user1._id, defer(err))
      await datastore.collections.users.findOne({_id: user1._id}, defer(err, user1))
      expect(user1.logins?.facebook).to.equal("1234")
      done()
    )

    it("should set deleted and merge_into for the old user object", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", true, defer(err, user))
      fbuser_attrs =
        email: "adwhisper@gmail.com"
        name: "Gigi Marga"
        serviceId : "346456"
        type: "facebook"
      await datastore.collections.users.insert(fbuser_attrs, defer(err, fbuser))
      fbuser = fbuser[0]
      await datastore.collections.users.merge(fbuser._id, user._id, defer(err))
      await datastore.collections.users.findOne({_id: fbuser._id}, defer(err, fbuser))
      expect(fbuser.deleted).to.equal(true)
      expect(fbuser.merged_into.equals(user._id)).to.equal(true)
      done()
    )

    it("should attach 3rd party logins (facebook, google, twitter) to merge users if merging from old_style 3rd party users", (done)->
      email = "email@email.com"
      name = "blabla"
      await datastore.collections.users.createOwnAccount(name, email, "pass", true, defer(err, user))
      fbuser_attrs =
        email: "adwhisper@gmail.com"
        name: "Gigi Marga"
        serviceId : "346456"
        type: "facebook"
      await datastore.collections.users.insert(fbuser_attrs, defer(err, fbuser))
      fbuser = fbuser[0]
      await datastore.collections.users.merge(fbuser._id, user._id, defer(err))
      await datastore.collections.users.findOne({_id: user._id}, defer(err, user))
      expect(user.logins.facebook).to.equal(fbuser_attrs.serviceId)
      done()
    )

    it("should assign all comments to the new user", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment))
      await datastore.collections.comments.count({author: user2._id}, defer(err, count))
      expect(count).to.equal(3)
      await datastore.collections.users.merge(user2._id, user1._id, defer(err))
      await datastore.collections.comments.count({author: user2._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.comments.count({author: user1._id}, defer(err, count))
      expect(count).to.equal(3)
      done()
    )

    it("should assign all challenges to the new user", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", false, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
        parent: conversation._id
        challenged: comment1._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge1))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: -2 * util.getValue("challengeCost")}}, defer(err, profile1))
      challengeAttrs.challenged = comment2._id
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge2))
      challengeAttrs.challenged = comment3._id
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge3))
      await datastore.collections.comments.count({"challenger.author": user3._id}, defer(err, count))
      expect(count).to.equal(3)
      await datastore.collections.comments.count({"challenger.author": user1._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.users.merge(user3._id, user1._id, defer(err))
      await datastore.collections.comments.count({"challenger.author": user3._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.comments.count({"challenger.author": user1._id}, defer(err, count))
      expect(count).to.equal(3)
      done()
    )

    it("should not assign challenges if the challenged user is the merged into user", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", false, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user2, site, defer(err, u2profile))
      await datastore.collections.profiles.update({_id: u2profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
        parent: conversation._id
        challenged: comment1._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge1))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: -2 * util.getValue("challengeCost")}}, defer(err, profile1))
      challengeAttrs.challenged = comment2._id
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge2))
      challengeAttrs.challenged = comment3._id
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge3))
      await datastore.collections.comments.count({"challenger.author": user3._id}, defer(err, count))
      expect(count).to.equal(3)
      await datastore.collections.comments.count({"challenger.author": user2._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.users.merge(user3._id, user2._id, defer(err))
      await datastore.collections.comments.count({"challenger.author": user3._id}, defer(err, count))
      expect(count).to.equal(3)
      await datastore.collections.comments.count({"challenger.author": user2._id}, defer(err, count))
      expect(count).to.equal(0)
      done()
    )

    it("should not assign challenges if the challenger user is the merged into user", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", false, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
        parent: conversation._id
        challenged: comment1._id
        summary: "demo summery"
        challenger:
          text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge1))
      await datastore.collections.profiles.update({user: user3._id}, {$set: {points: -2 * util.getValue("challengeCost")}}, defer(err, profile1))
      challengeAttrs.challenged = comment2._id
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge2))
      challengeAttrs.challenged = comment3._id
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge3))
      await datastore.collections.comments.count({"challenger.author": user3._id}, defer(err, count))
      expect(count).to.equal(3)
      await datastore.collections.comments.count({"challenger.author": user2._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.users.merge(user2._id, user3._id, defer(err))
      await datastore.collections.comments.count({"challenger.author": user3._id}, defer(err, count))
      expect(count).to.equal(3)
      await datastore.collections.comments.count({"challenger.author": user2._id}, defer(err, count))
      expect(count).to.equal(0)
      done()
    )

    it("should assign answers (decided after a question was ended) to the new user", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", false, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", false, defer(err, user3))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))

      questionAttrs =
        top: true
        text: "demo"
        parent: conversation._id
        question: true
      await datastore.collections.comments.addComment(site, user2, null, questionAttrs, defer(err, question))
      commentAttrs =
        top: false
        text: "demo"
        parent: question._id
      await datastore.collections.comments.addComment(site, user3, null, commentAttrs, defer(err, answer))
      await datastore.collections.comments.endQuestion(question, defer(err, answer, question))
      expect(question.answer).to.exist
      expect(question.answer.author.equals(user3._id)).to.equal(true)

      await datastore.collections.users.merge(user3._id, user1._id, defer(err))
      await datastore.collections.comments.count({"answer.author": user3._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.comments.count({"answer.author": user1._id}, defer(err, count))
      expect(count).to.equal(1)
      done()
    )

    it("should set like.cauthor to the new user", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      await datastore.collections.comments.likeUpDown(site, comment1._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment1._id, user1, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment2._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment2._id, user1, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment3._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment3._id, user1, null, null, true, defer(err, result))

      await datastore.collections.likes.count({cauthor: user2._id}, defer(err, count))
      expect(count).to.equal(6)
      await datastore.collections.users.merge(user2._id, user4._id, defer(err))
      await datastore.collections.likes.count({cauthor: user2._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.likes.count({cauthor: user4._id}, defer(err, count))
      expect(count).to.equal(6)
      done()
    )

    it("should set like.user to the new user", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))
      await datastore.collections.comments.likeUpDown(site, comment1._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment2._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment3._id, user3, null, null, true, defer(err, result))
      await datastore.collections.likes.count({user: user3._id}, defer(err, count))
      expect(count).to.equal(3)
      await datastore.collections.users.merge(user3._id, user4._id, defer(err))
      await datastore.collections.likes.count({user: user3._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.likes.count({user: user4._id}, defer(err, count))
      expect(count).to.equal(3)
      done()
    )

    it("should set vote.user to the new user", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
          parent: conversation._id
          challenged: comment1._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user4, null, null, "challenger", true, defer(err, result))

      await datastore.collections.votes.count({user: user4._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.merge(user4._id, user1._id, defer(err))
      await datastore.collections.votes.count({user: user4._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.votes.count({user: user1._id}, defer(err, count))
      expect(count).to.equal(1)
      done()
    )

    it("should not set vote.user to the new user if the user is challenger", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u3", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u4", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
          parent: conversation._id
          challenged: comment1._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user4, null, null, "challenger", true, defer(err, result))

      await datastore.collections.votes.count({user: user4._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.merge(user4._id, user3._id, defer(err))
      await datastore.collections.votes.count({user: user4._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.votes.count({user: user3._id}, defer(err, count))
      expect(count).to.equal(0)
      done()
    )

    it("should not set vote.user to the new user if the user is challenged", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
          parent: conversation._id
          challenged: comment1._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user4, null, null, "challenger", true, defer(err, result))

      await datastore.collections.votes.count({user: user4._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.merge(user4._id, user2._id, defer(err))
      await datastore.collections.votes.count({user: user4._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.votes.count({user: user2._id}, defer(err, count))
      expect(count).to.equal(0)
      done()
    )

    it("should set vote.challenger_author to the new user if the user is not challenged", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
          parent: conversation._id
          challenged: comment1._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user4, null, null, "challenger", true, defer(err, result))

      await datastore.collections.votes.count({"challenger_author": user3._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.merge(user3._id, user1._id, defer(err))
      await datastore.collections.votes.count({"challenger_author": user3._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.votes.count({"challenger_author": user1._id}, defer(err, count))
      expect(count).to.equal(1)
      done()
    )

    it("should set vote.challenged_author to the new user if the user is not challenger", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
          parent: conversation._id
          challenged: comment1._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user4, null, null, "challenger", true, defer(err, result))

      await datastore.collections.votes.count({"challenged_author": user2._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.merge(user2._id, user1._id, defer(err))
      await datastore.collections.votes.count({"challenged_author": user2._id}, defer(err, count))
      expect(count).to.equal(0)
      await datastore.collections.votes.count({"challenged_author": user1._id}, defer(err, count))
      expect(count).to.equal(1)
      done()
    )

    it("should not set vote.challenger_author to the new user if the user is challenged", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
          parent: conversation._id
          challenged: comment1._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user4, null, null, "challenger", true, defer(err, result))

      await datastore.collections.votes.count({"challenger_author": user3._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.merge(user3._id, user2._id, defer(err))
      await datastore.collections.votes.count({"challenger_author": user3._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.votes.count({"challenger_author": user2._id}, defer(err, count))
      expect(count).to.equal(0)
      done()
    )

    it("should not set vote.challenged_author to the new user if the user is challenger", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.profiles.create(user3, site, defer(err, u3profile))
      await datastore.collections.profiles.update({_id: u3profile._id}, {$inc: {points: 1000000}}, defer(err, noupdated))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))

      challengeAttrs =
          parent: conversation._id
          challenged: comment1._id
          summary: "demo summery"
          challenger:
            text: "challenge text"
      await datastore.collections.comments.addChallenge(site, user3, null, challengeAttrs, defer(err, challenge))
      await datastore.collections.comments.vote(site, challenge._id, user4, null, null, "challenger", true, defer(err, result))

      await datastore.collections.votes.count({"challenged_author": user2._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.users.merge(user2._id, user3._id, defer(err))
      await datastore.collections.votes.count({"challenged_author": user2._id}, defer(err, count))
      expect(count).to.equal(1)
      await datastore.collections.votes.count({"challenged_author": user3._id}, defer(err, count))
      expect(count).to.equal(0)
      done()
    )

    it("should assign sites to the new user", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      await datastore.collections.users.merge(user1._id, user2._id, defer(err))
      await datastore.collections.sites.findOne({name: site.name}, defer(err, site))
      expect(site.user.equals(user2._id)).to.equal(true)
      done()
    )

    it("should assign admin permissions to the new user if the old user owned sites", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      await datastore.collections.users.merge(user1._id, user2._id, defer(err))
      await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, profile))
      expect(profile.permissions.admin).to.equal(true)
      done()
    )

    it("should assign moderator permissions to the new user if the old user had moderator permissions", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))

      await datastore.collections.users.merge(user1._id, user2._id, defer(err))
      await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, profile))
      expect(profile.permissions.moderator).to.equal(true)
      done()
    )

    it("should assign profile points of the old user to the new user", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))
      await datastore.collections.comments.likeUpDown(site, comment1._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment2._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment3._id, user3, null, null, true, defer(err, result))
      await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
      expect(u2profile.points).to.equal(3 * util.getValue("likePoints"))
      await datastore.collections.profiles.findOne({user: user4._id, siteName: site.name}, defer(err, u4profile))
      expect(u4profile).to.be.null
      await datastore.collections.users.merge(user2._id, user4._id, defer(err))
      await datastore.collections.profiles.findOne({user: user4._id, siteName: site.name}, defer(err, u4profile))
      expect(u4profile.points).to.equal(3 * util.getValue("likePoints"))
      done()
    )

    it("should assign conversation points of the old user to the new user", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))
      await datastore.collections.comments.likeUpDown(site, comment1._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment2._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment3._id, user3, null, null, true, defer(err, result))
      await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2profile))
      expect(u2profile.points).to.equal(3 * util.getValue("likePoints"))
      await datastore.collections.convprofiles.findOne({user: user4._id, context: conversation._id}, defer(err, u4profile))
      expect(u4profile).to.be.null
      await datastore.collections.users.merge(user2._id, user4._id, defer(err))
      await datastore.collections.convprofiles.findOne({user: user4._id, context: conversation._id}, defer(err, u4profile))
      expect(u4profile.points).to.equal(3 * util.getValue("likePoints"))
      done()
    )

    it("should assign competition points of the old user to the new user", (done)->
      util = require("../util")
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      competitionAttrs =
        title: "demo competition"
        start: moment.utc().toDate()
        end: moment.utc().add("days", 1).toDate()
        site: site.name
      await datastore.collections.competitions.add(competitionAttrs, defer(err, competition))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment3))
      await datastore.collections.comments.likeUpDown(site, comment1._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment2._id, user3, null, null, true, defer(err, result))
      await datastore.collections.comments.likeUpDown(site, comment3._id, user3, null, null, true, defer(err, result))
      await datastore.collections.competition_profiles.findOne({user: user2._id, competition: competition._id}, defer(err, u2profile))
      expect(u2profile.points).to.equal(3 * util.getValue("likePoints"))
      await datastore.collections.competition_profiles.findOne({user: user4._id, competition: competition._id}, defer(err, u4profile))
      expect(u4profile).to.be.null
      await datastore.collections.users.merge(user2._id, user4._id, defer(err))
      await datastore.collections.competition_profiles.findOne({user: user4._id, competition: competition._id}, defer(err, u4profile))
      expect(u4profile.points).to.equal(3 * util.getValue("likePoints"))
      done()
    )

    it("should mark profiles as merged", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.users.merge(user2._id, user4._id, defer(err))
      await datastore.collections.profiles.findOne({user: user2._id, siteName: site.name}, defer(err, u2profile))
      expect(u2profile.merged_into).to.exist
      done()
    )

    it("should mark conversation profiles as merged", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.sites.add({name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer(err, site))
      await datastore.collections.conversations.enter(site, null, "1", "http://localhost/1", defer(err, conversation))
      commentAttrs = {top: true, text: "demo1", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment1))
      commentAttrs = {top: true, text: "demo2", parent: conversation._id}
      await datastore.collections.comments.addComment(site, user2, null, commentAttrs, defer(err, comment2))
      commentAttrs = {top: true, text: "demo3", parent: conversation._id}
      await datastore.collections.users.merge(user2._id, user4._id, defer(err))
      await datastore.collections.convprofiles.findOne({user: user2._id, context: conversation._id}, defer(err, u2profile))
      expect(u2profile.merged_into).to.exist
      done()
    )

    it("should remove all logins from a merged user", (done)->
      await datastore.collections.users.createOwnAccount("u1", "email1", "pass", true, defer(err, user1))
      await datastore.collections.users.createOwnAccount("u2", "email2", "pass", true, defer(err, user2))
      await datastore.collections.users.createOwnAccount("u2", "email3", "pass", true, defer(err, user3))
      await datastore.collections.users.createOwnAccount("u2", "email4", "pass", true, defer(err, user4))
      await datastore.collections.users.attach3rdPartyLogin(user2, "facebook", {id: "1234"}, defer(err))
      await datastore.collections.users.merge(user2._id, user4._id, defer(err))
      await datastore.collections.users.findOne({_id: user2._id}, defer(err, user2))
      expect(user2.logins).to.not.exist
      done()
    )
  )
)

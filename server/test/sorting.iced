require("./setup")
datastore = require("../datastore")
dbutil = require("../datastore/util")
async = require("async")

sortStringReverse = (a, b)->
  if a < b
    return 1
  else if a > b
    return -1
  else
    return 0

describe("sorting", ->

  c = []
  # c1 = c2 = c3 = c4 = c5 = c6 = c7 = c8 = c9 = c10 = null
  conv = null

  before((done)->
    require("./setup").clear(done)
  )

  before((done)->
    await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
    await datastore.collections.users.createOwnAccount "u2", "email2", "pass", true, defer err, user2
    await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

    await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
    conv = conversation
    attrs1 = {top: true, text: "c1", parent: conversation._id}
    attrs5 = {top: true, text: "c5", parent: conversation._id}
    attrs8 = {top: true, text: "c8", parent: conversation._id}
    attrs9 = {top: true, text: "c9", parent: conversation._id}
    await datastore.collections.comments.addComment site, user1, null, attrs1, defer err, c1
    await datastore.collections.comments.addComment site, user1, null, attrs5, defer err, c5
    await datastore.collections.comments.addComment site, user1, null, attrs8, defer err, c8
    await datastore.collections.comments.addComment site, user1, null, attrs9, defer err, c9
    attrs4 = {top: false, text: "c4", parent: c1._id}
    attrs2 = {top: false, text: "c2", parent: c1._id}
    attrs6 = {top: false, text: "c6", parent: c5._id}
    attrs7 = {top: false, text: "c7", parent: c5._id}
    attrs10 = {top: false, text: "c10", parent: c9._id}
    await datastore.collections.comments.addComment site, user1, null, attrs2, defer err, c2
    await datastore.collections.comments.addComment site, user1, null, attrs4, defer err, c4
    await datastore.collections.comments.addComment site, user1, null, attrs6, defer err, c6
    await datastore.collections.comments.addComment site, user1, null, attrs7, defer err, c7
    await datastore.collections.comments.addComment site, user1, null, attrs10, defer err, c10
    attrs3 = {top: false, text: "c3", parent: c2._id}
    await datastore.collections.comments.addComment site, user1, null, attrs3, defer err, c3
    await datastore.collections.comments.findAndModify({_id: c5._id}, [], {$set: {no_likes: 3}}, {new: true}, defer(err, c5))
    await datastore.collections.comments.findAndModify({_id: c8._id}, [], {$set: {no_likes: 2}}, {new: true}, defer(err, c8))
    await datastore.collections.comments.findAndModify({_id: c1._id}, [], {$set: {no_likes: 1}}, {new: true}, defer(err, c1))
    # liking children, set no_likes directly (level > 1)
    await datastore.collections.comments.findAndModify({_id: c2._id}, [], {$set: {no_likes: 2}}, {new: true}, defer(err, c2))
    await datastore.collections.comments.findAndModify({_id: c3._id}, [], {$set: {no_likes: 1}}, {new: true}, defer(err, c3))
    await datastore.collections.comments.findAndModify({_id: c4._id}, [], {$set: {no_likes: 3}}, {new: true}, defer(err, c4))
    await datastore.collections.comments.findAndModify({_id: c6._id}, [], {$set: {no_likes: 1}}, {new: true}, defer(err, c6))
    await datastore.collections.comments.findAndModify({_id: c7._id}, [], {$set: {no_likes: 2}}, {new: true}, defer(err, c7))
    await datastore.collections.comments.findAndModify({_id: c10._id}, [], {$set: {no_likes: 3}}, {new: true}, defer(err, c10))

    c = [c1, c2, c3, c4, c5, c6, c7, c8, c9, c10]
    done()
  )

  describe("#sortSlug", ->
    it("should return all comments by slug in ascending order from the beginning when number of comments = page size", (done)->
      await datastore.collections.comments.sortChronologically({context: conv._id}, null, 10, defer(err, elements))
      expect(elements.length).to.equal(10)
      expids = _.map(c, (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by slug in ascending order from a certain element when number of comments = page size", (done)->
      await datastore.collections.comments.sortChronologically({context: conv._id}, c[2]._id, 10, defer(err, elements))
      expect(elements.length).to.equal(7)
      expids = _.map(c, (e)-> return e.slug).sort().slice(3)
      ids = _.map(elements, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments when called successively when limit = 2", (done)->
      from = null
      elems = []
      part = (cb)->
        await datastore.collections.comments.sortChronologically({context: conv._id}, from, 2, defer(err, elements))
        if err then return cb(err)
        elems = elems.concat(elements)
        from = elements[elements.length - 1]._id
        cb()
      await async.series([part, part, part, part, part], defer(err))
      if err then throw err
      expect(elems.length).to.equal(c.length)
      expids = _.map(c, (e)-> return e.slug)
      ids = _.map(elems, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
  )

  describe("#sortTopLevel", ->
    it("should return all comments on the top level sorted by likes in decreasing order when number of comments = page size", (done)->
      await datastore.collections.comments.sortTopLevel({context: conv._id, level: 1}, "no_likes", -1, null, 10, defer(err, elements))
      expect(elements.length).to.equal(4)
      expids = _.map([c[4], c[7], c[0], c[8]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
  )

  describe("#sortKeepTree", ->
    it("should return all comments by slug in descending order from the beginning when number of comments = page size", (done)->
      await datastore.collections.comments.sortSlugDsc({context: conv._id, cat: "COMMENT", level: 1}, null, 10, defer(err, elements))
      expect(elements.length).to.equal(10)
      expids = _.map([c[8], c[9], c[7], c[4], c[5], c[6], c[0], c[1], c[2], c[3]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by slug in descending order from a last child element when number of comments = 2 (another child)", (done)->
      await datastore.collections.comments.sortSlugDsc({context: conv._id, cat: "COMMENT", level: 1}, c[2]._id, 2, defer(err, elements))
      expect(elements.length).to.equal(1)
      expids = _.map([c[3]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by slug in descending order from a certain element when number of comments = 2 and the elements returned are at the top level", (done)->
      await datastore.collections.comments.sortSlugDsc({context: conv._id, cat: "COMMENT", level: 1}, c[6]._id, 2, defer(err, elements))
      expect(elements.length).to.equal(2)
      expids = _.map([c[0], c[1]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by slug in descending order from a top level element when number of comments = 2 (~ its children)", (done)->
      await datastore.collections.comments.sortSlugDsc({context: conv._id, cat: "COMMENT", level: 1}, c[0]._id, 2, defer(err, elements))
      expect(elements.length).to.equal(2)
      expids = _.map([c[1], c[2]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in ascending order from the beginning when number of comments = page size", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, 1, null, 10, defer(err, elements))
      expids = _.map([c[8], c[9], c[0], c[1], c[2], c[3], c[7], c[4], c[5], c[6]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(10)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in descending order from the beginning when number of comments = page size", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, null, 10, defer(err, elements))
      expids = _.map([c[4], c[5], c[6], c[7], c[0], c[1], c[2], c[3], c[8], c[9]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(10)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in ascending order from the beginning when number of comments = 5", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, 1, null, 5, defer(err, elements))
      expids = _.map([c[8], c[9], c[0], c[1], c[2]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(5)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in descending order from the beginning when number of comments = 5", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, null, 5, defer(err, elements))
      expids = _.map([c[4], c[5], c[6], c[7], c[0]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(5)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in ascending order from a certain element when number of comments = page size", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, 1, c[2]._id, 10, defer(err, elements))
      expids = _.map([c[3], c[7], c[4], c[5], c[6]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(5)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in descending order from a certain element when number of comments = page size", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, c[2]._id, 10, defer(err, elements))
      expids = _.map([c[3], c[8], c[9]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(3)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in ascending order from a certain element when number of comments = 3", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, 1, c[2]._id, 3, defer(err, elements))
      expids = _.map([c[3], c[7], c[4]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(3)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in descending order from a certain element when number of comments = 2", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, c[2]._id, 2, defer(err, elements))
      expids = _.map([c[3], c[8]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(2)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in descending order from a top level element when number of comments = 2", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, c[0]._id, 2, defer(err, elements))
      expids = _.map([c[1], c[2]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(2)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in ascending order from a certain element when number of comments = 1", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, 1, c[2]._id, 1, defer(err, elements))
      expids = _.map([c[3]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(1)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments by likes in descending order from a certain element when number of comments = 1", (done)->
      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, c[2]._id, 1, defer(err, elements))
      expids = _.map([c[3]], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)
      expect(elements.length).to.equal(1)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments called successively when the field = no_likes && dir = -1", (done)->
      from = null
      elems = []
      part = (cb)->
        await datastore.collections.comments.sortKeepTree({context: conv._id, level: 1}, "no_likes", -1, from, 2, 1, defer(err, elements))
        if err then return cb(err)
        elems = elems.concat(elements)
        from = elements[elements.length - 1]._id
        cb()
      await async.series([part, part, part, part, part], defer(err))
      if err then throw err
      expect(elems.length).to.equal(c.length)
      expids = _.map([c[4], c[5], c[6], c[7], c[0], c[1], c[2], c[3], c[8], c[9]], (e)-> return e.slug)
      ids = _.map(elems, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return all comments called successively when the field = slug && dir = -1", (done)->
      from = null
      elems = []
      part = (cb)->
        await datastore.collections.comments.sortKeepTree({context: conv._id, level: 1}, "slug", -1, from, 2, 1, defer(err, elements))
        if err then return cb(err)
        elems = elems.concat(elements)
        from = elements[elements.length - 1]._id
        cb()
      await async.series([part, part, part, part, part], defer(err))
      if err then throw err
      expect(elems.length).to.equal(c.length)
      expids = _.map([c[8], c[9], c[7], c[4], c[5], c[6], c[0], c[1], c[2], c[3]], (e)-> return e.slug)
      ids = _.map(elems, (e)-> return e.slug)
      expect(ids).to.deep.equal(expids)
      done()
    )
  )
)

describe("sorting", ->

  describe("#sortTopLevel", ->

    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should sort by likes in ascending order when they have equal likes and the page is less than the number of comments", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      conv = conversation
      attrs1 = {top: true, text: "c1", parent: conversation._id}
      attrs2 = {top: true, text: "c2", parent: conversation._id}
      attrs3 = {top: true, text: "c3", parent: conversation._id}
      attrs4 = {top: true, text: "c4", parent: conversation._id}

      await datastore.collections.comments.addComment site, user1, null, attrs1, defer err, c1
      await datastore.collections.comments.addComment site, user1, null, attrs2, defer err, c2
      await datastore.collections.comments.addComment site, user1, null, attrs3, defer err, c3
      await datastore.collections.comments.addComment site, user1, null, attrs4, defer err, c4
      await datastore.collections.comments.findAndModify({_id: c1._id}, [], {$set: {no_likes: 1}}, {new: true}, defer(err, c1))
      await datastore.collections.comments.findAndModify({_id: c2._id}, [], {$set: {no_likes: 2}}, {new: true}, defer(err, c2))
      await datastore.collections.comments.findAndModify({_id: c3._id}, [], {$set: {no_likes: 2}}, {new: true}, defer(err, c3))
      await datastore.collections.comments.findAndModify({_id: c4._id}, [], {$set: {no_likes: 3}}, {new: true}, defer(err, c4))
      ids = _.map([c1, c2, c3, c4], (e)-> e._id.toHexString())

      await datastore.collections.comments.sortTopLevel({context: conv._id}, "no_likes", 1, null, 2, defer(err, elements_1))
      expect(elements_1.length).to.equal(2)
      expect(_.map(elements_1, (e)-> e._id.toHexString())).to.deep.equal(_.first(ids, 2))

      await datastore.collections.comments.sortTopLevel({context: conv._id}, "no_likes", 1, elements_1[1]._id, 2, defer(err, elements_2))
      expect(elements_2.length).to.equal(2)
      expect(_.map(elements_2, (e)-> e._id.toHexString())).to.deep.equal(_.last(ids, 2))

      done()
    )
  )

  describe("#sortKeepTree", ->

    beforeEach((done)->
      require("./setup").clear(done)
    )

    it("should return comments in natural order when sorted by likes in ascending order when they have equal likes", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      conv = conversation
      attrs1 = {top: true, text: "c1", parent: conversation._id}
      attrs5 = {top: true, text: "c5", parent: conversation._id}
      await datastore.collections.comments.addComment site, user1, null, attrs1, defer err, c1
      await datastore.collections.comments.addComment site, user1, null, attrs5, defer err, c5
      attrs4 = {top: false, text: "c4", parent: c1._id}
      attrs2 = {top: false, text: "c2", parent: c1._id}
      attrs6 = {top: false, text: "c6", parent: c5._id}
      attrs7 = {top: false, text: "c7", parent: c5._id}
      await datastore.collections.comments.addComment site, user1, null, attrs2, defer err, c2
      await datastore.collections.comments.addComment site, user1, null, attrs4, defer err, c4
      await datastore.collections.comments.addComment site, user1, null, attrs6, defer err, c6
      await datastore.collections.comments.addComment site, user1, null, attrs7, defer err, c7
      attrs3 = {top: false, text: "c3", parent: c2._id}
      await datastore.collections.comments.addComment site, user1, null, attrs3, defer err, c3

      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, 1, null, 10, defer(err, elements))
      expids = _.map([c1, c2, c3, c4, c5, c6, c7], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)

      expect(ids.length).to.equal(7)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return comments in natural order when sorted by likes in descending order when they have equal likes", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      conv = conversation
      attrs1 = {top: true, text: "c1", parent: conversation._id}
      attrs5 = {top: true, text: "c5", parent: conversation._id}
      await datastore.collections.comments.addComment site, user1, null, attrs1, defer err, c1
      await datastore.collections.comments.addComment site, user1, null, attrs5, defer err, c5
      attrs4 = {top: false, text: "c4", parent: c1._id}
      attrs2 = {top: false, text: "c2", parent: c1._id}
      attrs6 = {top: false, text: "c6", parent: c5._id}
      attrs7 = {top: false, text: "c7", parent: c5._id}
      await datastore.collections.comments.addComment site, user1, null, attrs2, defer err, c2
      await datastore.collections.comments.addComment site, user1, null, attrs4, defer err, c4
      await datastore.collections.comments.addComment site, user1, null, attrs6, defer err, c6
      await datastore.collections.comments.addComment site, user1, null, attrs7, defer err, c7
      attrs3 = {top: false, text: "c3", parent: c2._id}
      await datastore.collections.comments.addComment site, user1, null, attrs3, defer err, c3

      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, null, 10, defer(err, elements))
      expids = _.map([c1, c2, c3, c4, c5, c6, c7], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)

      expect(ids.length).to.equal(7)
      expect(ids).to.deep.equal(expids)
      done()
    )
    it("should return comments in natural order when sorted by likes in descending from a certain element order when they have equal likes and limit = 2 - last child + next top", (done)->
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.sites.add {name: "test", urls:[{protocol: "http", base: "localhost", subdomains: false}], approvalForNew: 0, autoApprove: true}, user1, defer err, site

      await datastore.collections.conversations.enter site, null, "1", "http://localhost/1", defer err, conversation
      conv = conversation
      attrs1 = {top: true, text: "c1", parent: conversation._id}
      attrs5 = {top: true, text: "c5", parent: conversation._id}
      await datastore.collections.comments.addComment site, user1, null, attrs1, defer err, c1
      await datastore.collections.comments.addComment site, user1, null, attrs5, defer err, c5
      attrs4 = {top: false, text: "c4", parent: c1._id}
      attrs2 = {top: false, text: "c2", parent: c1._id}
      attrs6 = {top: false, text: "c6", parent: c5._id}
      attrs7 = {top: false, text: "c7", parent: c5._id}
      await datastore.collections.comments.addComment site, user1, null, attrs2, defer err, c2
      await datastore.collections.comments.addComment site, user1, null, attrs4, defer err, c4
      await datastore.collections.comments.addComment site, user1, null, attrs6, defer err, c6
      await datastore.collections.comments.addComment site, user1, null, attrs7, defer err, c7
      attrs3 = {top: false, text: "c3", parent: c2._id}
      await datastore.collections.comments.addComment site, user1, null, attrs3, defer err, c3

      await datastore.collections.comments.sortByLikes({context: conv._id, cat: "COMMENT", level: 1}, -1, c3._id, 2, defer(err, elements))
      expids = _.map([c4, c5], (e)-> return e.slug)
      ids = _.map(elements, (e)-> return e.slug)

      expect(ids.length).to.equal(2)
      expect(ids).to.deep.equal(expids)
      done()
    )
  )
)

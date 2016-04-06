setup = require("./setup")
datastore = require("../datastore")

describe("Generic collection operations", ->

  beforeEach((done)->
    require("./setup").clear(done)
  )

  describe("#findIter", ->
    it("should iterate through all elements in the cursor", (done)->
      no_calls = 0
      await datastore.collections.users.createOwnAccount "u1", "email1", "pass", true, defer err, user1
      await datastore.collections.users.createOwnAccount "u1", "email2", "pass", true, defer err, user2
      await datastore.collections.users.createOwnAccount "u1", "email3", "pass", true, defer err, user3
      ids = [user1._id.toHexString(), user2._id.toHexString(), user3._id.toHexString()]
      await datastore.collections.users.findIter({}, (user, callback)->
        no_calls++
        expect(user._id.toHexString()).to.equal(ids[no_calls - 1])
        callback()
      , defer(err))
      expect(no_calls).to.equal(3)
      done()
    )
  )

  describe("#prepareSortQueries", ->
    it("should compute multiple queries needed for ordering by multiple fields starting from a certain element", (done)->
      elem = {p1: 23, p2: 24, p3: 25}
      sort = datastore.collections.comments.prepareSortQueries({}, [['p1', -1], ['p2', -1], ['p3', -1]], elem)
      expect(sort).to.deep.equal([{p1: 23, p2: 24, p3: {$lt: 25}}, {p1: 23, p2: {$lt: 24}}, {p1: {$lt: 23}}])
      done()
    )
  )
)

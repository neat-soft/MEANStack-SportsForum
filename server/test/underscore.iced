require("./setup")
require("../shared/underscore_mixin")

describe("Underscore_mixin", ->

  describe.skip("#limit", ->
    it("should limit the number of calls", (done)->
      f = (cb)->
        cb()
      lf = _.limit(f, 100)
      nocalls = 0
      ctl = ->
        nocalls++
      for i in [0..20]
        lf(ctl)
      setTimeout(->
        expect(nocalls).to.equal(10)
        done()
      , 990)
    )
  )

  describe("#deferTimes", ->
    it("should call the function several times > 0 without increasing the delay when the factor is 1", (done)->
      nocalls = 0
      f = ->
        nocalls++
      _.deferTimes(f, 100, 5, 1)
      setTimeout(->
        expect(nocalls).to.equal(5)
        done()
      , 1000)
    )
  )

  describe("#walkTree", ->
    it('should navigate through all the nodes of the tree with no limit', (done)->
      tree = {
        text: 1
        children: [
          {
            text: 2
            children: [
              {
                text: 3
                children: []
              },
              {
                text: 4
                children: []
              }
            ]
          },
          {
            text: 5
            children: [
              {
                text: 6
                children: [
                  {
                    text: 7
                  },
                  {
                    text: 8
                  }
                ]
              }
            ]
          }
        ]
      }
      results = []
      _.walkTree(tree, 'children', false, (e)->
        results.push(e.text)
      )
      expect(results).to.deep.equal([1..8])
      done()
    )

    it('should limit the depth', (done)->
      tree = {
        text: 1
        children: [
          {
            text: 2
            children: [
              {
                text: 3
                children: []
              },
              {
                text: 4
                children: []
              }
            ]
          },
          {
            text: 5
            children: [
              {
                text: 6
                children: [
                  {
                    text: 7
                  },
                  {
                    text: 8
                  }
                ]
              }
            ]
          }
        ]
      }
      results = []
      _.walkTree(tree, 'children', 2, (e)->
        results.push(e.text)
      )
      expect(results).to.deep.equal([1, 2, 3, 4, 5, 6])
      done()
    )
  )

)

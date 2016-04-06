describe("#color", ->
  it("should do nothing when the color is ok", (done)->
    util = require("../util")
    color = util.color("#34a3f5")
    expect(color).to.equal("#34a3f5")
    done()
  )

  it("should add #", (done)->
    util = require("../util")
    color = util.color("34a3f5")
    expect(color).to.equal("#34a3f5")
    done()
  )

  it("should eliminate spaces and truncate", (done)->
    util = require("../util")
    color = util.color(" # 34a 3f5xx")
    expect(color).to.equal("#34a3f5")
    done()
  )

  it("should bail when there is an invalid character", (done)->
    util = require("../util")
    color = util.color("#34xxf5")
    expect(color).to.be.null
    done()
  )
)

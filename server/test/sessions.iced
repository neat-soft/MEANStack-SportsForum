setup = require("./setup")
datastore = require("../datastore")
request = require('supertest')

describe("Sessions", ->

  beforeEach((done)->
    setup.clear(done)
  )

  it("should not create a session if the browser does not send a session", (done)->
    request(setup.app)
      .get('/')
      .end((err, res)->
        expect(err).to.not.exist
        expect(res.headers['set-cookie']).to.not.exist
        done()
      )
  )
  it("should clear the session if the browser sends a cookie but there's no session", (done)->
    request(setup.app)
      .get('/')
      .set('Cookie', 'connect.sid=s%3AViLOdmncrYhDGQJffS%2F%2FOikB.BwdkW1YSWDAeEScvnxApZPeKPisNZ8WxyzDnh6ekFDQ')
      .end((err, res)->
        expect(err).to.not.exist
        expect(res.headers['set-cookie'][0]).to.match(/connect\.sid=;/)
        done()
      )
  )

  it("should create session when logging in", (done)->
    email = "email@email.com"
    name = "blabla"
    pass = "pass"
    await datastore.collections.users.createOwnAccount(name, email, pass, true, defer(err, user))
    request(setup.app)
      .post('/auth/signin')
      .send({email: email, passwd: pass})
      .end((err, res)->
        expect(err).to.not.exist
        expect(res.headers['set-cookie'][0]).to.match(/connect\.sid=.+?;/)
        done()
      )
  )

  it("should delete session when logging out", (done)->
    email = "email@email.com"
    name = "blabla"
    pass = "pass"
    await datastore.collections.users.createOwnAccount(name, email, pass, true, defer(err, user))
    await request(setup.app)
      .post('/auth/signin')
      .send({email: email, passwd: pass})
      .end(defer(err, res))
    cookie = res.headers['set-cookie'][0]
    cookie = cookie.substring(0, cookie.indexOf(';') + 1)
    await request(setup.app)
      .get('/auth/logout')
      .set('cookie', cookie)
      .end(defer(err, res2))
    expect(res2.headers['set-cookie'][0]).to.match(/connect\.sid=;/)
    done()
  )
)

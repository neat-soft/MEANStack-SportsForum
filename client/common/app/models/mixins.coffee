module.exports.userContent =

  setSpam: ->
    @save({spam: true}, {wait: true, url: @url() + "/spam"})

  notSpam: ->
    @save({spam: false}, {wait: true, url: @url() + "/notspam"})

  approve: ->
    @save({approved: true}, {wait: true, url: @url() + "/approve"})

  clearFlags: ->
    @save({no_flags: 0, flags: []}, {wait: true, url: @url() + "/clearflags"})

  delete: (options)->
    options ?= {}
    @save(null, _.extend({wait: true, url: @url() + "/delete"}, options))

  computeLink: (full = true)->
    hash = "brzn/comments/#{@id}"
    if full
      return @get("context").computeLink(false) + hash
    return "##{hash}"

  detachFromParent: ->
    if @get('parent')
      @set({parent: null, _parent: @get('parent'), _v: -1})
    for child in @get('comments').toArray()
      child.detachFromParent()

  parentList: ->
    parents = []
    parent = @get("parent")
    while parent
      parents.push(parent)
      parent = parent.get("parent")
    return parents

  firstUnlinked: ->
    model = this
    while model.get('parent')
      model = model.get("parent")
    return model

module.exports.parseChildrenCreateRest = (resp, xhr)->
  data = resp.data
  result = []
  for attr in data
    if attr.parent == @container.id
      result.push(attr)
    else
      obj = new type(attr)
  return result

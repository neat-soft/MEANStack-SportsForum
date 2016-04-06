View = require("views/base_view")

module.exports = class Item extends View

  beforeRender: ->
    if @model.get("approved")
      @conv_url = "/go/#{@model.id}"
    else if @model.get("context")
      @conv_url = "/go/#{@model.get("context").id}"

  events:
    "click .approve": "approve"
    "click .delete": "deleteKeepPoints"
    "click .delete-points": "deleteWithPoints"
    "click .clearflags": "clearFlags"
    "click .setspam": "setSpam"
    "click .setnotspam" : "notSpam"

  approve: ->
    @app.api.approveItem(@model)
    return false

  delete: (keepPoints)->
    params = {keep_points: keepPoints}
    if !@model.get("approved") && !@model.get("modified_by_user")
      @app.api.destroyItem(@model, params)
    else
      @app.api.deleteItem(@model, params)

  deleteKeepPoints: ->
    @delete(true)

  deleteWithPoints: ->
    @delete(false)

  clearFlags: ->
    @app.api.clearItemFlags(@model)

  setSpam: ->
    @app.api.setSpam(@model)

  notSpam: ->
    @app.api.notSpam(@model)

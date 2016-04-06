util = require("../shared/util")

loader = (resourceName)->
  return (req, res)->
    res.setHeader('Content-Type', 'text/javascript')
    resource = util.resource(resourceName)
    content = """
  (function() {
    var s = document.createElement("script"); 
    s.type = "text/javascript"; 
    s.async = true;
    s.src = "#{resource}";
    (document.getElementsByTagName("head")[0] || document.getElementsByTagName("body")[0]).appendChild(s);
  })();
    """
    res.send(content)

module.exports = (app)->

  app.get("/web/js/embed.js", loader("/js/embed-c.js"))
  app.get("/web/js/counts.js", loader("/js/counts-c.js"))
  app.get("/web/js/blogger-posts.js", loader("/js/blogger-posts-c.js"))

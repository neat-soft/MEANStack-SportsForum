module.exports = (p3pheader)->
  
  return (req, res, next)->
    try
      res.setHeader("P3P", p3pheader)
    catch err

    next()

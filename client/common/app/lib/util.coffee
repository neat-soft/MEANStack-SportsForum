module.exports.formatString = (str, params)->
  if not params?
      return str
  for key, val of params
      regex = new RegExp("{#{key}}", "g")
      str = str.replace(regex, val)
  return str

module.exports.centerPosition = (width, height, winWidth = screen.width, winHeight = screen.height)->
  left = Math.round((winWidth / 2) - (width / 2))
  top = 0
  if (winHeight > height)
    top = Math.round((winHeight / 2) - (height / 2))
  return [top, left]

module.exports.rectIntersect = (rect1, rect2)->
  return rect2.top < rect1.bottom && rect2.bottom > rect1.top &&
    rect2.left < rect1.right && rect2.right > rect1.left

# Limit the width with css (min-width, max-width)
module.exports.growRightAbsolute = ($elem, $container)->
  offset =  $elem.offset().left - $container.offset().left
  width = $container.width() - offset
  $elem.width(width)

module.exports.imgtoa = (text)->
  return text.replace(/<img(.*?)src=['"]([a-z0-9-_:\/?%\-.]+)['"](.*?)\/?>(?:<\/img>)?/gi, '<a href="$2">$2</a>')

module.exports.textReplaceImg = (text)->
  return text.replace(/<img(.*?)src=['"]([a-z0-9-_:\/?%\-.]+)['"](.*?)\/?>(?:<\/img>)?/gi, '<div class="img-pholder" src="$2"></div>')

module.exports.replaceImg = (el, replaceSrc = false)->
  $el = $(el)
  images = $el.find('img')
  images.each((i, e)->
    # console.log("Hiding image #{i}")
    $e = $(e)
    if !$e.attr('src')
      return
    pholder = $('<div></div>')
    pholder[0].className = e.className
    pholder.addClass('img-pholder')
    if $e.attr('id')
      pholder.attr('id', $e.attr('id'))
    pholder.css({
      'display': 'inline-block'
      'height': $e.height()
      'width': $e.width()
    })
    pholder.attr('src', $e.attr('src'))
    $e.before(pholder)
    $e.detach()
    if replaceSrc
      $e.attr('src', 'data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=')
      setTimeout(->
        $e.remove()
        e = $e = null
      , 3000)
  )
  if !replaceSrc
    images.remove()

module.exports.restoreImg = (el)->
  $el = $(el)
  pholders = $el.find('div.img-pholder')
  pholders.each((i, e)->
    # console.log("Showing image #{i}")
    $e = $(e)
    if !$e.attr('src')
      return
    img = $('<img/>')
    img[0].className = e.className
    img.removeClass('img-pholder')
    img.attr('src', $e.attr('src'))
    if $e.attr('id')
      img.attr('id', $e.attr('id'))
    $e.replaceWith(img)
  )
  pholders.remove()

module.exports.intime = (time, now)->
  diff = time - now
  seconds = diff / 1000
  if seconds < 60
    return {term: 'now'}
  else if seconds < 3600
    return {term: "minutes", options: {value: Math.floor(seconds/60)}}
  else if seconds < 86400 # a day
    return {term: "hours", options: {value: Math.floor(seconds/3600)}}
  else
    return {term: "days", options: {value: Math.floor(seconds/86400)}}

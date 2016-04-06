exports.config =
  # See http://brunch.readthedocs.org/en/latest/config.html for documentation.
  files:
    javascripts:
      joinTo:
        'javascripts/blogger-posts-c.js': /^(app|vendor)/
        'test/javascripts/test.js': /^test(\/|\\)(?!vendor)/
        'test/javascripts/test-vendor.js': /^test(\/|\\)(?=vendor)/

    stylesheets:
      joinTo:
        'stylesheets/blogger-posts-c.css': /^(app|vendor)/
        'test/stylesheets/test.css': /^test/

    templates:
      joinTo: 'javascripts/blogger-posts-c.js'
        
  modules:
    wrapper: (path, data)->
      """
(function(){
  #{data}
})();
      """
    definition: false

  sourceMaps: false
  
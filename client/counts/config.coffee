exports.config =
  # See http://brunch.readthedocs.org/en/latest/config.html for documentation.
  files:
    javascripts:
      joinTo:
        'javascripts/counts-c.js': /^(app|vendor)/
        'test/javascripts/test.js': /^test(\/|\\)(?!vendor)/
        'test/javascripts/test-vendor.js': /^test(\/|\\)(?=vendor)/

    stylesheets:
      joinTo:
        'stylesheets/counts-c.css': /^(app|vendor)/
        'test/stylesheets/test.css': /^test/

    templates:
      joinTo: 'javascripts/counts-c.js'
        
  modules:
    wrapper: (path, data)->
      """
(function(){
  #{data}
})();
      """
    definition: false
    
  sourceMaps: false

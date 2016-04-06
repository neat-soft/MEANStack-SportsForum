exports.config =
  # See http://brunch.readthedocs.org/en/latest/config.html for documentation.
  files:
    javascripts:
      joinTo:
        'javascripts/embed-c.js': /^(app|vendor)/
        'test/javascripts/test.js': /^test(\/|\\)(?!vendor)/
        'test/javascripts/test-vendor.js': /^test(\/|\\)(?=vendor)/
      order:
        before: [
          'vendor/scripts/jquery-1.8.2.js',
          'vendor/scripts/json3.js'
          'vendor/scripts/underscore.js',
          'vendor/scripts/backbone.js'
        ]

    stylesheets:
      joinTo:
        'stylesheets/embed-c.css': /^(app|vendor)/
        'test/stylesheets/test.css': /^test/

    templates:
      joinTo: 'javascripts/embed-c.js'

  modules:
    wrapper: (path, data)->
      """
(function(){
  #{data}
})();
      """
    definition: false

  sourceMaps: false


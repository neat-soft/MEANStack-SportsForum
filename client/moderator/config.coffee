exports.config =
  # See http://brunch.readthedocs.org/en/latest/config.html for documentation.
  files:
    javascripts:
      joinTo:
        'javascripts/moderator.js': /^app/
        'javascripts/moderator-vendor.js': /^vendor/
        'test/javascripts/test.js': /^test(\/|\\)(?!vendor)/
        'test/javascripts/test-vendor.js': /^test(\/|\\)(?=vendor)/
      order:
        # Files in `vendor` directories are compiled before other files
        # even if they aren't specified in order.before.
        before: [
          'vendor/scripts/jquery-1.8.2.js',
          'vendor/scripts/jquery.flot.js',
          'vendor/scripts/console-helper.js',
          'vendor/scripts/underscore.js',
          'vendor/scripts/backbone.js',
          'vendor/scripts/rivets.js',
          'vendor/scripts/bootstrap.js',
          'vendor/scripts/moment/moment.js',
          'vendor/scripts/moment/moment-timezone.js'
          'vendor/scripts/moment/moment.tzdata.js'
          'vendor/scripts/daterangepicker.js'
        ]

    stylesheets:
      joinTo:
        'stylesheets/moderator.css': /^(app|vendor)/
        'test/stylesheets/test.css': /^test/
      order:
        before: ['app/stylesheets/bootstrap/bootstrap.less']
        after: ['vendor/styles/helpers.css']

    templates:
      joinTo: 'javascripts/moderator.js'

  conventions:
    ignored: (path)->
      # ignore bootstrap files that are included from bootstrap.less
      if path.match(/^app(\/|\\)stylesheets(\/|\\)bootstrap/)
        return !path.match(/^app(\/|\\)stylesheets(\/|\\)bootstrap(\/|\\)bootstrap\.less/)
      else if path.match(/^app(\/|\\)stylesheets/)
        return !path.match(/^app(\/|\\)stylesheets(\/|\\)main\.styl/)
      else
        return false

  sourceMaps: false


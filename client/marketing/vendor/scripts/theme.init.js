// Carousel init
(function($) {

  'use strict';

  if ($.isFunction($.fn['themePluginCarousel'])) {
    $(function() {
        $('[data-plugin-carousel]:not(.manual), .owl-carousel:not(.manual)').each(function() {
          var $this = $(this),
            opts;
          var pluginOptions = $this.data('plugin-options');
          if (pluginOptions)
            opts = pluginOptions;
          $this.themePluginCarousel(opts);
        });
    });
  }
}).apply(this, [jQuery]);

// Word Rotate
(function($) {

	'use strict';

	if ($.isFunction($.fn['themePluginWordRotate'])) {
		$(function() {
			$('[data-plugin-word-rotate]:not(.manual), .word-rotate:not(.manual)').each(function() {
				var $this = $(this),
					opts;
				var pluginOptions = $this.data('plugin-options');
				if (pluginOptions)
					opts = pluginOptions;
				$this.themePluginWordRotate(opts);
			});
		});
	}
}).apply(this, [jQuery]);

// Toggle
(function($) {

	'use strict';

	if ($.isFunction($.fn['themePluginToggle'])) {
		$(function() {
			$('[data-plugin-toggle]:not(.manual)').each(function() {
				var $this = $(this),
					opts;

				var pluginOptions = $this.data('plugin-options');
				if (pluginOptions)
					opts = pluginOptions;

				$this.themePluginToggle(opts);
			});
		});
	}
}).apply(this, [jQuery]);

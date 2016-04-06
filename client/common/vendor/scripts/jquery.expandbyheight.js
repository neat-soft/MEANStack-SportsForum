(function($) {

  var ccc = 0;
  var methods = {
    init: function(options) {
      var settings = $.extend({
        expanderClassName: 'expander',
        expandText: 'Show more',
        collapseText: 'Show less',
        maxHeight: 200,
        afterExpand: function() {},
        afterCollapse: function() {}
      }, options);

      return this.each(function(){
        var $this = $(this)
          , data = $this.data('expandbyheight');
        if (!data) {
          var expander = $('<a href="#" class="' + settings.expanderClassName + '" data-expand-id="' + ccc + '">' + settings.expandText + '</a>');
          ccc += 1;
          data = {
            settings: settings,
            expander: expander
          };
          $this.after(expander);
          expander.bind('click.expandbyheight', function(e){
            e.preventDefault();
            if ($this.height() > settings.maxHeight)
              methods.collapse.call($this);
            else
              methods.expand.call($this);
          });
          setTimeout(function(){
            if ($this.height() < settings.maxHeight) {
              expander.css('display', 'none');
            }
            else {
              methods.collapse.call($this);
            }
          }, 1);
        }
        $this.data('expandbyheight', data);
      });
    },
    expand: function() {
      return this.each(function(){
        var $this = $(this);
        data = $this.data('expandbyheight');
        data.expander.text(data.settings.collapseText);
        $this.css({
          height: 'auto',
          overflow: 'none'
        });
        if (typeof data.settings.afterExpand === 'function')
          data.settings.afterExpand.call($this)
      });
    },
    collapse: function() {
      return this.each(function(){
        var $this = $(this);
        data = $this.data('expandbyheight');
        data.expander.text(data.settings.expandText);
        $this.css({
          height: data.settings.maxHeight + 'px',
          overflow: 'hidden'
        });
        if (typeof data.settings.afterCollapse === 'function')
          data.settings.afterCollapse.call($this)
      });
    },
    destroy: function() {
      return this.each(function(){
        var $this = $(this),
          data = $this.data('expandbyheight');
        if (data) {
          data.expander.unbind('.expandbyheight');
          data.expander.remove();
          $this.removeData('expandbyheight');
        }
       });
    }
  }

  $.fn.expandByHeight = function(method) {
    if (methods[method]) {
      return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
    } else if (typeof method === 'object' || !method) {
      return methods.init.apply(this, arguments);
    } else {
      $.error('Method ' +  method + ' does not exist on jQuery.expandbyheight');
    }
  }

})(jQuery);

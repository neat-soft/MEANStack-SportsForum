(function($){
  var originalLeave = $.fn.popover.Constructor.prototype.leave;

  $.fn.popover.Constructor.prototype.leave = function(obj) {
    var self = obj instanceof this.constructor ?
      obj : $(obj.currentTarget)[this.type](this._options).data(this.type)
    var container, timeout;

    originalLeave.call(this, obj);

    if (obj.currentTarget) {
      // for bootstrap 3
      // container = $(obj.currentTarget).siblings('.popover');
      container = $('.popover');
      timeout = self.timeout;
      container.one('mouseenter', function(){
        //We entered the actual popover – call off the dogs
        clearTimeout(timeout);
        //Let's monitor popover content instead
        container.one('mouseleave', function(){
          self.hide();
          // for bootstrap 3
          // $.fn.popover.Constructor.prototype.leave.call(self, self);
        });
      })
    }
  };
})(jQuery);

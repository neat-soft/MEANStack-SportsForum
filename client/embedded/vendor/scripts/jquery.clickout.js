/**
 * |-----------------|
 * | jQuery-Clickout |
 * |-----------------|
 *  jQuery-Clickout is freely distributable under the MIT license.
 *
 *  <a href="https://github.com/chalbert/Backbone-Elements">More details & documentation</a>
 *
 * @author Nicolas Gilbert
 *
 * @requires jQuery
 */

(function(factory){
  'use strict';

  if (typeof define === 'function' && define.amd) {
    define(['jquery'], factory);
  } else {
    factory($);
  }

})(function ($){
  'use strict';

     /**
      * A static counter is tied to the doc element to track click-out registration
      * @static
      */
  var counter = 0;

     /**
      * On mobile Touch browsers, 'click' are not triggered on every element.
      * Touchstart is.
      * @static
      *
      * Edit: use both events for now
      * window.Touch is available on Chrome even when not on mobile
      */
      // click = window.Touch ? 'touchstart' : 'click';


  /**
   * Shortcut for .on('clickout')
   *
   * @param data
   * @param fn
   */

  $.fn.clickout = function(data, fn) {
    if (!fn) {
      fn = data;
      data = null;
    }

    if (arguments.length > 0) {
      this.on('clickout', data, fn);
    } else {
      return this.trigger('clickout');
    }

  };

  /**
   * Implements the 'special' jQuery event interface
   * Native way to add non-conventional events
   */
  jQuery.event.special.clickout = {

    /**
     * When the event is added
     * @param handleObj Event handler
     */

    add: function(handleObj){
      counter++;
      var self = this;

       // Add counter to element
      var target = handleObj.selector
        ? $(this).find(handleObj.selector)
        : $(this);
      if (!target.length) {
        return;
      }
      target.attr('data-clickout', counter);

      (function(id) {
        // When the click is inside, extend the Event object to mark it as so
        var setClickin = function(e){
          if (e.originalEvent) {
            e.originalEvent.clickin = id;
          }
        }
        $(this).on('touchstart.clickout' + id, handleObj.selector, setClickin);
        $(this).on('click.clickout' + id, handleObj.selector, setClickin);

        // Bind a click event to the document, to be cought after bubbling
        var triggerClickout = function(e){
          // If the click is not inside the element, call the callback
          if (self !== e.target && !$(self).has(e.target).length) {
            if (!e.originalEvent || !e.originalEvent.clickin || e.originalEvent.clickin !== id) {
              handleObj.handler.apply(this, arguments);
            }
            else {
              if (e.originalEvent) {
                e.originalEvent.clickin = false;
              }
            }
          }
        }
        $(document).bind('touchstart.clickout' + id, triggerClickout);
        $(document).bind('click.clickout' + id, triggerClickout);
      })(counter);
    },

    /**
     * When the event is removed
     * @param handleObj Event handler
     */
    remove: function(handleObj) {
      var target = handleObj.selector
          ? $(this).find(handleObj.selector)
          : $(this)
        , id = target.attr('data-clickout');

      target.removeAttr('data-clickout');

      $(document).unbind('touchstart.clickout' + id);
      $(document).unbind('click.clickout' + id);
      $(this).off('touchstart.clickout' + id, handleObj.selector);
      $(this).off('click.clickout' + id, handleObj.selector);
      return false;
    }
  };

  return $;

});

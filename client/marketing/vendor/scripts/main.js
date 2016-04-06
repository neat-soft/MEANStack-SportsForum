_.extend(Burnzone, {
  init: function() {
    $(window).scroll(function(){
      // add navbar opacity on scroll
      if ($(this).scrollTop() > 100) {
        $(".navbar.navbar-fixed-top").addClass("scroll");
      } else {
        $(".navbar.navbar-fixed-top").removeClass("scroll");
      }

      // global scroll to top button
      if ($(this).scrollTop() > 300) {
        $('.scrolltop').fadeIn();
      } else {
        $('.scrolltop').fadeOut();
      }
    });

    // scroll back to top btn
    $('.scrolltop').click(function(){
      $("html, body").animate({ scrollTop: 0 }, 700);
      return false;
    });

    if($('.commenting-demo, .forums-demo').length > 0) {
      $(".navbar.navbar-fixed-top").css({"position": "absolute"});
    }

    // FAQs
    var $faqs = $("#faq .faq");
    $faqs.click(function () {
      var $answer = $(this).find(".answer");
      $answer.slideToggle('fast');
    });

    if (!$.support.leadingWhitespace) {
      //IE7 and 8 stuff
      $("body").addClass("old-ie");
    }
    $('.spinedit.discovery-limit').change(function (ev) {
      var el = $(this);
      var clean = parseInt(el.val(), 10);
      if (clean < 0 || clean > 20) {
        clean = 3;
      }
      el.val(clean);
      $(el.attr("data-target")).text(clean);
    });
    $('.dropdown-toggle').dropdown();
    $('#slider-id').liquidSlider();
    $("[rel=tooltip]").tooltip({ trigger: "hover" });
    $("#inputName").popover({ trigger: "focus", container: "body"  });
    $("#inputUrl").popover({ trigger: "focus", container: "body"  });
    $("#inputEmail").popover({ trigger: "focus", container: "body" });
    $("#signup_email").popover({ trigger: "focus", container: "body" });
    $('#color_question, #color_challenge, .color_badge, .pick-color').ColorPicker({
      onSubmit: function(hsb, hex, rgb, el) {
        $(el).val('#' + hex);
        $(el).ColorPickerHide();
      },
      onBeforeShow: function () {
        $(this).ColorPickerSetColor(this.value);
      },
      onChange: function (hsb, hex, rgb, el) {
        owner = $(this.data("colorpicker").el);
        owner.closest(".badge-wrap").find(".badge_sample").css('backgroundColor', '#' + hex);
      },
      onHide: function(picker) {
        owner = $($(picker).data("colorpicker").el);
        hex = owner.val();
        owner.closest(".badge-wrap").find(".badge_sample").css('backgroundColor', hex);
      }
    })
    .bind('keyup', function(){
      $(this).ColorPickerSetColor(this.value);
      $(this).closest(".badge-wrap").find(".badge_sample").css('backgroundColor', this.value);
    });

    $('.badge_name').bind('keyup', function () {
      $(this).closest(".badge-wrap").find(".badge_sample .badge-title").text(this.value);
    });

    if (typeof(Burnzone[Burnzone.onstart]) === 'function') {
      Burnzone[Burnzone.onstart]();
    }

    var enable_wp_admin_hooks = function() {
      var oldFrameHeight = 0;

      var update_height = function() {
        var newHeight = $('body').height();
        if (oldFrameHeight == newHeight) {
          return;
        }

        window.parent.postMessage("burnzone-need-height " + newHeight, "*");
        oldFrameHeight = newHeight;
      }

      setInterval(update_height, 200);

      var split_first = function(s, sub) {
        var v = [];
        s = s.split(sub);
        v.push(s.shift());
        v.push(s.join(sub));
        return v;
      }

      update_height();

      $('.framed_page button.import-comments').click(function (ev) {
        ev.preventDefault();
        window.parent.postMessage("burnzone-export-comments", "*");
      });

      window.addEventListener("message", function(ev) {
        args = split_first(ev.data, " ");
        if (args[0] === "burnzone-current-url") {
          v = split_first(args[1], " ");
          currentUrl = v[0].match(/(https?:\/\/)?(.+)/)[2]
          currentName = v[1].toLowerCase().replace(/[^a-z0-9]/g, '');
          $('.signin_box #inputName').val(currentName);
          $('.signin_box #inputUrl').val(currentUrl);
        } else if (args[0] === "burnzone-start-export") {
          $('.framed_page button.import-comments').prop('disabled', true).removeClass('btn-success');
          $('.framed_page .import-comments-progress').removeClass('display_none');
        } else if (args[0] === "burnzone-end-export") {
          $('.framed_page button.import-comments').prop('disabled', false).addClass('btn-success');
          $('.framed_page .import-comments-progress').addClass('display_none');
          if (args[1] === "ok") {
            $('.framed_page .alert-import-comments').addClass('display_none');
          }
        } else if (args[0] === "burnzone-status-export") {
          $('.framed_page .import-comments-status').html(args[1]);
        }
      }, false);

      var all_links = $('.framed_page a');
      for (var i = 0; i < all_links.length; i++) {
        var anchor = $(all_links[i]);
        var url = anchor.prop("href");
        var link = url;
        var hash = "";

        if (url.indexOf("#") > 0) {
          link = url.slice(0, url.indexOf("#"));
          hash = url.slice(url.indexOf("#"));
        }

        if (anchor.prop("target")) {
          continue;
        }
        if (link.slice(0, 4) !== "http") {
          continue;
        }
        if (link.indexOf("frame=true") > 0) {
          continue;
        }


        if (link.indexOf("?") > 0) {
          link = link + "&frame=true"
        } else {
          link = link + "?frame=true"
        }
        anchor.prop("href", link + hash);
      }

      var all_links = $('.framed_page form');
      for (var i = 0; i < all_links.length; i++) {
        var anchor = $(all_links[i]);
        var url = anchor.prop("action");
        var link = url;
        var hash = "";

        if (url.indexOf("#") > 0) {
          link = url.slice(0, url.indexOf("#"));
          hash = url.slice(url.indexOf("#"));
        }

        if (link.indexOf("frame=true") > 0) {
          continue;
        }

        if (link.indexOf("?") > 0) {
          link = link + "&frame=true"
        } else {
          link = link + "?frame=true"
        }
        anchor.prop("action", link + hash);
      }

      $('.site_box .dropdown-menu a').click(function (ev) {
        ev.preventDefault();
        var name = $(this).text().replace(/^\s+|\s+$/g, '');
        window.parent.postMessage("burnzone-set-site " + name, "*");
      });

      $('.framed_page button.merge-demo').click(function (ev) {
        ev.preventDefault();
        var btn = $(this);
        btn.prop('disabled', true);
        $.post("/admin/merge?frame=true&site=" + encodeURIComponent($(this).attr("data-site")) + "&demo=" + encodeURIComponent($(this).attr("data-demo")))
          .done(function() {
            $('.framed_page .merge-demo-status').html('Merge request successful.');
          })
          .fail(function(data, x, z) {
            msg = JSON.parse(data.responseText);
            $('.framed_page .merge-demo-status').html('Error while merging sites: ' + msg.error);
            btn.prop('disabled', false);
          });
      });

      window.parent.postMessage("burnzone-have-sites", "*");
      var currentSiteName = $(".site_box .site_box_info").text().replace(/^\s+|\s+$/g, '');
      var currentSso = $(".site_box .site_box_sso").text().replace(/^\s+|\s+$/g, '');

      if (currentSiteName) {
        window.parent.postMessage("burnzone-set-site " + currentSiteName, "*");
        window.parent.postMessage("burnzone-set-sso " + currentSso, "*");
      }
    }

    if ($('.framed_page').length > 0) {
      // we are embedded in WP admin
      enable_wp_admin_hooks();
    }


    var bind_remove_avatars = function () {
      $('.avatar-control button.del-avatar').off('click.remove-avatar');
      $('.avatar-control button.del-avatar').on('click.remove-avatar', function () {
        $(this).parents('.avatar-control').remove()
        return false;
      });
    }

    var bind_update_avatars = function () {
      $('.avatar-control input').off('focusout.avatar-url');
      $('.avatar-control input').on('focusout.avatar-url', function () {
        full_url = "http://www.gravatar.com/avatar/d75476089c2518c0fb474b4331785f3f?d=" + encodeURIComponent($(this).val());
        $(this).parents('.avatar-control').find('img').attr('src', full_url);
        return false;
      });
    }

    // connect the click and image update for existing avatars
    bind_remove_avatars();
    bind_update_avatars();

    var add_avatar = $('#avatar_add button');
    add_avatar.click(function () {
      var avatar_template = $('#avatar_template');
      var new_avatar = avatar_template.clone();
      var url = new_avatar.find('input');

      new_avatar.removeClass('display_none')
      nextId = parseInt(add_avatar.attr('count'), 10);
      new_avatar.attr('id', "avatar_control_" + nextId)
      url.attr('name', "avatar_" + nextId);
      add_avatar.attr('count', nextId + 1);
      $('#avatar_list').prepend(new_avatar);

      // rebind click and url update
      bind_remove_avatars();
      bind_update_avatars();

      return false;
    });
  },

  profileAddEmail: function() {
    $(document).ready(function(){
      $("#inputEmail").focus();
    });
  },

  showAdvancedTypepad: function() {
    $(".toggle_advanced_note").click(function() {
      $(".advanced_note").toggle();
    });
  },

  loadProfileApp: function() {
    require('profile')();
  },

  loadSiteSettingsApp: function() {
    require('site_settings_forum')();
  },

  introSportsVideo: function() {
    // create youtube player
    window.onYouTubePlayerAPIReady = function() {
      var player = new YT.Player('player', {
        height: '390',
        width: '690',
        videoId: 'qCDxEif_9js',
        events: {
          'onReady': onPlayerReady,
          'onStateChange': onPlayerStateChange
        }
      });
    }

    // autoplay video
    function onPlayerReady(event) {
      event.target.playVideo();
      $('.close').click(function(){
        window.location = "/demo/sports";
      });
    }

    // when video ends
    function onPlayerStateChange(event) {
      if(event.data === 0) {
        window.location = "/demo/sports";
      }
    }

    onYouTubePlayerAPIReady();
  },

  sportsVideo: function() {
    // create youtube player
    window.onYouTubePlayerAPIReady = function() {
      var player = new YT.Player('player', {
        height: '390',
        width: '690',
        videoId: '43jHG-yH9Gc',
        playerVars: {rel: 0},
        events: {
          'onReady': onPlayerReady,
          'onStateChange': onPlayerStateChange
        }
      });
    }

    // autoplay video
    function onPlayerReady(event) {
      event.target.playVideo();
    }

    // when video ends
    function onPlayerStateChange(event) {
    }

    onYouTubePlayerAPIReady();
  },

  introVideo: function() {
    // create youtube player
    window.onYouTubePlayerAPIReady = function() {
      var player = new YT.Player('player', {
        height: '390',
        width: '690',
        videoId: 'qCDxEif_9js',
        events: {
          'onReady': onPlayerReady,
          'onStateChange': onPlayerStateChange
        }
      });
    }

    // autoplay video
    function onPlayerReady(event) {
      event.target.playVideo();
      $('.close').click(function(){
        window.location = "/demo";
      });
    }

    // when video ends
    function onPlayerStateChange(event) {
      if(event.data === 0) {
        window.location = "/demo";
      }
    }

    onYouTubePlayerAPIReady();
  }
})

$(document).ready(Burnzone.init);

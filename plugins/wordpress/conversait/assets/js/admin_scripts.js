jQuery(document).ready(function(){
  jQuery('#conversait_activation_date').datetimepicker({
    buttonImageOnly: true,
    dateFormat: "yy-mm-dd",
    timeFormat: "hh:mm TT",
    controlType: "slider",
    minDateTime: new Date(0)
  });
  conv_setup_exports();
  conv_setup_frame();
});

conv_setup_frame = function() {
  var $ = jQuery;
  var frameHeight = 0;
  var frameBaseUrl = bz_url + "/admin/settings?frame=true";
  var btnAdvanced = $('a.conv-show-advanced');
  var hintAdvanced = $('i.conv-hint-advanced');

  var url_for = function (siteName) {
    return frameBaseUrl + "&site=" + siteName;
  }

  btnAdvanced.click(function (ev) {
    var adv_settings = $('.conv-advanced-settings');
    ev.preventDefault();
    if (adv_settings.hasClass('display_none')) {
      $('#burnzone_frame').addClass('display_none');
      adv_settings.removeClass('display_none');
      btnAdvanced.html("<< Back to settings");
      hintAdvanced.addClass('display_none');
    } else {
      adv_settings.addClass('display_none');
      $('#burnzone_frame').removeClass('display_none');
      btnAdvanced.html("Advanced");
      hintAdvanced.removeClass('display_none');
    }
  });

  var reload_frame_with = function (site) {
    $('#burnzone_frame').replaceWith(
      $('<iframe></iframe>', {
        id: 'burnzone_frame',
        src: url_for(site),
        style: "width: 100%; height: " + frameHeight + ";"
      })
    );
  };

  window.addEventListener("message", function (ev) {
    var site = $("#conversait_site_name");
    var sso = $("#conversait_sso_key");

    if (ev.data.split(" ")[0] === "burnzone-need-height") {
      frameHeight = ev.data.split(" ")[1];
      $('#burnzone_frame').height(frameHeight);
      return;
    }

    if (ev.data === "burnzone-reload") {
      reload_frame_with(site.val());
    } else if (ev.data === "burnzone-have-sites") {
      ev.source.postMessage("burnzone-default-site " + site.val(), ev.origin);
      ev.source.postMessage("burnzone-current-url " + self_url + " " + self_name, ev.origin);
    } else if (ev.data.split(" ")[0] === "burnzone-set-site") {
      var name = ev.data.split(" ")[1];
      if (name !== site.val()) {
        reload_frame_with(name);
      }
      site.val(name);
      $("#burnzone_save_reminder .burnzone_site_name").html(name);
      if (name === bz_default_site) {
        $('#burnzone_save_reminder').addClass("display_none");
      } else {
        $('#burnzone_save_reminder').removeClass("display_none");
      }
    } else if (ev.data.split(" ")[0] === "burnzone-set-sso" && sso.val() != ev.data.split(" ")[1]) {
      sso.val(ev.data.split(" ")[1]);
      $('#burnzone_save_reminder').removeClass("display_none");
      if (bz_default_site === "" ||  bz_default_site.slice(0, 5) === "site-") {
        // we currently have a demo site, auto-set to this new site
        $("input[type='submit']").trigger("click");
      }
    } else if (ev.data === "burnzone-export-comments") {
      ev.source.postMessage("burnzone-start-export", ev.origin);
      do_export_comments(function (status) {
        ev.source.postMessage("burnzone-end-export " + status, ev.origin);
      }, function (msg) {
        ev.source.postMessage("burnzone-status-export " + msg, ev.origin);
      });
    }
  }, false);
}

conv_setup_exports = function() {
  var $ = jQuery;
  $('#conv-export-comments a.button').unbind().click(function() {
    $('#conv-export-comments a.button').addClass('display_none');
    $('#conv-export-status').addClass("export_loading").removeClass('export_finished').html('<i class="fa fa-spinner fa-spin"></i> Exporting...');
    do_export_comments();
    return false;
  });
}

do_export_comments = function(on_complete, on_status) {
  var $ = jQuery;
  var btn_export = $('#conv-export-comments a.button')
  var status = $('#conv-export-status');
  var export_info = (status.attr('rel') || '0|' + (new Date().getTime()/1000)).split('|');
  $.get(
    wp_index_url,
    {
      conv_action: 'export-comment',
      post_id: export_info[0],
      timestamp: export_info[1]
    },
    function(response) {
      switch (response.result) {
        case 'success':
          status.html(response.msg).attr('rel', response.post_id + '|' + response.timestamp);
          if (on_status) {
            on_status(response.msg);
          }
          switch (response.status) {
            case 'partial':
              do_export_comments(on_complete, on_status);
              break;
            case 'complete':
              btn_export.removeClass('display_none');
              status.addClass('export_finished').removeClass('export_loading').html('Export finished!');
              if (on_complete) {
                on_complete('ok');
              }
              break;
          }
          break;
        case 'fail':
          btn_export.removeClass('display_none');
          status.addClass('export_error').removeClass('export_loading').html('There was an error exporting the comments: ' + response.msg + '.')
          if (on_status) {
            on_status('There was an error importing comments to BurnZone: ' + response.msg + '.');
          }
          if (on_complete) {
            on_complete('error');
          }
          break;
      }
    },
    'json'
  );
}


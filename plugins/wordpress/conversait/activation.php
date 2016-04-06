<?php

function conv_gen_demo_site() {
  $http = new WP_Http();
  $response = $http->request(
    CONVERSAIT_SERVER_HOST . "/admin/demosite",
    array(
      'method' => 'POST',
      'body' => array(
        'pass' => wp_generate_password(),
        'url' => get_bloginfo('url')
      )
    )
  );

  return (array) json_decode($response['body']);
}

function conv_add_forum_page() {
  $forum = get_page_by_title('Forum');
  if (!$forum) {
    $post = array(
      'post_content'   => '<div class="conversait_area" data-conversait-app-type="forum"></div>',
      'post_name'      => 'forum',
      'post_title'     => 'Forum',
      'post_status'    => 'publish',
      'post_type'      => 'page',
      'comment_status' => 'closed',
    );
    $forum = wp_insert_post($post);
    if ($forum != 0) {
      echo "<div class='updated'>BurnZone Commenting has created a <a href='". get_permalink($forum) ."'>Forum</a> page.</div>";
    } else {
      echo "<div class='updated'>BurnZone Commenting failed to create a Forum page.</div>";
    }
  }
}

function conv_activate_plugin() {
  global $conv_opt_name, $conv_opt, $conv_opt_name_demo_site, $conv_opt_name_demo_sso, $conv_opt_name_site_name, $conv_opt_name_sso_key;

  if (empty($conv_opt[$conv_opt_name_demo_site])) {
    # generate demo site
    $demo = conv_gen_demo_site();
    if ($demo) {
      $conv_opt[$conv_opt_name_demo_site] = $demo["site"];
      $conv_opt[$conv_opt_name_demo_sso] = $demo["key"];
      # also set sitename/sso
      $conv_opt[$conv_opt_name_site_name] = $demo["site"];
      $conv_opt[$conv_opt_name_sso_key] = $demo["key"];
      # save new settings
      update_option($conv_opt_name, $conv_opt);
      echo "<div class='updated'>BurnZone Commenting is now active in <strong>demo</strong> mode.</div>";
    } else {
      echo "<div class='updated'>Failed to create demo site</div>";
    }
  } else {
    if (empty($conv_opt[$conv_opt_name_site_name]) || $conv_opt[$conv_opt_name_site_name] == "") {
      # also set sitename/sso
      $conv_opt[$conv_opt_name_site_name] = $conv_opt[$conv_opt_name_demo_site];
      $conv_opt[$conv_opt_name_sso_key] = $conv_opt[$conv_opt_name_demo_sso];
      # save new settings
      update_option($conv_opt_name, $conv_opt);
    }
  }

  conv_add_forum_page();
}

function conv_check_demo() {
  global $conv_opt, $conv_opt_name_demo_site, $conv_opt_name_site_name;

  if ($conv_opt[$conv_opt_name_site_name] === $conv_opt[$conv_opt_name_demo_site]) {
    echo "<br><div class='update-nag'>BurnZone Commenting is now active in <strong>demo</strong> mode. Update your <a href='". conv_settings_link() ."'>settings.</a></div>";
  }
}

add_action('admin_notices', 'conv_check_demo');

?>

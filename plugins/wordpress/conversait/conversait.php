<?php

/*
Plugin Name: BurnZone Commenting Wordpress Plugin
Plugin URI: http://www.theburn-zone.com
Description: Integrates the BurnZone commenting engine
Version: 1.0.3
Author: The Burnzone team
Author URI: http://www.theburn-zone.com
License: GPL2
*/

/*  Copyright 2012  theburn-zone.com  (email : info@theburn-zone.com)

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License, version 2, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/

define('CONVERSAIT_PATH', plugin_dir_path(__FILE__));

include(CONVERSAIT_PATH . 'options.php');
include(CONVERSAIT_PATH . 'sso.php');

$conv_opt = conv_ensure_options();

/*
* Function to check whether to replace the default commenting platform or not.
*/
function conv_should_replace_comments($post) {
  global $conv_opt_name_enabledfor,
    $conv_opt_name_activation_type, $conv_opt_name_activation_date, //activation
    $conv_opt, $conv_opt_name_dis_comments;
  if (is_null($post))
    return false;
  if (isset($conv_opt[$conv_opt_name_dis_comments]) && $conv_opt[$conv_opt_name_dis_comments] === '1')
    return false;
  $post_time = strtotime($post->post_date);
  if ($conv_opt[$conv_opt_name_enabledfor][$post->post_type] !== "1")
    return false;
  if ($conv_opt[$conv_opt_name_activation_type] === "wpcomments_closed")
    return ($post->comment_status === "closed");
  else if ($post->comment_status === "closed")
    return false;
  if ($post->post_status !== "publish" && $post->post_status !== "private")
    return false;
  if ($conv_opt[$conv_opt_name_activation_type] === "all")
    return true;
  if ($conv_opt[$conv_opt_name_activation_type] === "since") {
    if ($post_time >= $conv_opt[$conv_opt_name_activation_date])
      return true;
  }
  return false;
}

/**
* Embed the conversait script in the post body.
*/
function conv_comments_template($file) {
  global $post;
  if (conv_should_replace_comments($post))
    return CONVERSAIT_PATH . 'comments.php';
  return $file;
}

/**
* If comment_status == 'closed' then Wordpress does not call 'comments_number'. We can't display the number of comments if
* the plugin is enabled for posts with comment_status == 'closed'. This hook overrides comments_open when we're not in admin mode.
*/
function conv_comments_open($open, $post_id = null) {
  $post = get_post($post_id);
  if (!$open && conv_should_replace_comments($post) && !is_admin())
    $open = true;
  return $open;
}

function conv_get_comments_number($count, $post_id = null) {
  $post = get_post($post_id);
  if (conv_should_replace_comments($post))
    return 0;
  return $count;
}

function conv_comments_number($output) {
  global $post;
  if (conv_should_replace_comments($post))
    return '<span data-conversation-id="' . conv_unique_post_id($post->ID) . '" data-conversation-url="' . get_permalink($post->ID) . '" data-conversation-title="' . get_the_title($post->ID) . '"></span>';
  else
    return $output;
}

function conv_enqueue_scripts() {
  wp_enqueue_script('convcommentscount', CONVERSAIT_SERVER_HOST . '/web/js/counts.js', array(), null);
}

function conv_head() {
  global $conv_opt_name_site_name, $conv_opt;
  $site_name = $conv_opt[$conv_opt_name_site_name];
  echo '<script type="text/javascript">var conversait_sitename = "' . $site_name . '";</script>';
}

/**
* Always load the embed script. If there's no area to embed a BurnZone widget into then the embed script will bail.
*/
function conv_load_embed_script() {
  global $conv_opt_name_site_name, $conv_opt;
  $site_name = $conv_opt[$conv_opt_name_site_name];
?>
  <script type="text/javascript">
    (function() {
      <?php if (ssoEnabled()) { ?>
        window.conversait_sso = <?php echo '"' . conv_build_sso_string() . '"'; ?>;
        window.conversait_sso_options = <?php echo conv_build_sso_options(); ?>;
      <?php } ?>
      var conversait = document.createElement("script");
      conversait.type = "text/javascript";
      conversait.async = true;
      conversait.src = <?php echo '"' . CONVERSAIT_SERVER_HOST . '/web/js/embed.js' . '"' ?>;
      (document.getElementsByTagName("head")[0] || document.getElementsByTagName("body")[0]).appendChild(conversait);
    })();
  </script>
<?php
}

/**
* We have to make sure that when multisite is activated the post id is globally unique.
*/
function conv_unique_post_id($post_id) {
  global $blog_id, $conv_opt, $conv_opt_name_def_blog_id;
  if (is_multisite())
    return $blog_id . "-" . $post_id;
  else
    return $post_id;
}

$site_name = $conv_opt[$conv_opt_name_site_name];

if (isset($site_name) and $site_name !== '') {
  add_filter('comments_template', 'conv_comments_template', 20);
  add_filter('comments_open', 'conv_comments_open', 20);
  add_filter('get_comments_number', 'conv_get_comments_number', 20);
  add_filter('comments_number', 'conv_comments_number', 20);
  add_action('wp_enqueue_scripts', 'conv_enqueue_scripts');
  add_action('wp_head', 'conv_head');
  add_action('wp_footer', 'conv_load_embed_script');
}

/**
* Add dashboard widget
*/
add_action( 'wp_dashboard_setup', 'conv_dashboard_widget' );
function conv_dashboard_widget() {
  add_meta_box(
    'conv-dashboard-widget',
    'BurnZone Commenting Widget',
    'conv_dashboard_content',
    'dashboard',
    'normal',
    'high'
  );
}

function conv_dashboard_content(){
  global $conv_opt_name_site_name, $conv_opt;
    $site_name = $conv_opt[$conv_opt_name_site_name];
  ?>

  <div class="wrap">
  <iframe src="<?php echo "http://" . $site_name . "." . CONVERSAIT_DOMAIN_PORT . "/admin/moderator?embed=true"; ?>" style="width:100%; min-height:500px;"></iframe>
  </div>
<?php }

/*
* Compute settings link
*/
function conv_settings_link() {
  return get_bloginfo('wpurl') . '/wp-admin/options-general.php?page=conversait';
}

/*
* Add a settings link
*/
function conv_plugin_action_links($links, $file) {
  static $this_plugin;
  if (!$this_plugin) {
    $this_plugin = plugin_basename(__FILE__);
  }
  // check to make sure we are on the correct plugin
  if ($file == $this_plugin) {
    // the anchor tag and href to the URL we want. For a "Settings" link, this needs to be the url of your settings page
    $settings_link = '<a href="' . conv_settings_link() . '">Settings</a>';
    // add the link to the list
    array_unshift($links, $settings_link);
  }
  return $links;
}

add_filter('plugin_action_links', 'conv_plugin_action_links', 10, 2);

/**
* Allow redirects to external sites
*/
function conv_allow_redirect($allowed)
{
  $allowed[] = CONVERSAIT_DOMAIN;
  return $allowed;
}

if (ssoEnabled()) {
  add_filter('allowed_redirect_hosts', 'conv_allow_redirect');
}

function conv_activation_hook() {
  add_option('conv_plugin_stage', 'activation');
}

register_activation_hook(__FILE__, 'conv_activation_hook');

add_action('admin_init', 'conv_load_plugin');

function conv_load_plugin() {
  if (is_admin() && get_option('conv_plugin_stage') == 'activation') {
    delete_option('conv_plugin_stage');
    /* plugin is being activated */
    conv_activate_plugin();
  }
}

function conv_filter_allowed_html($allowed, $context) {
  if ('post' === $context || is_null($context)) {
    $allowed['div'] = array_merge($allowed['div'], array(
      'data-conversait-app-type' => true,
      'bz-article-entries' => true,
      'bz-forum-entries' => true
    ));
  }
  return $allowed;
}

add_filter('wp_kses_allowed_html', 'conv_filter_allowed_html', 10, 2);

include(CONVERSAIT_PATH . 'activation.php');

include(CONVERSAIT_PATH . 'settings_page.php');
?>

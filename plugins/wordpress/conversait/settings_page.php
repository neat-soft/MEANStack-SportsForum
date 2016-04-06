<?php

// create custom plugin settings menu
add_action('admin_menu', 'conv_create_menu');

//call register settings function
add_action('admin_init', 'conv_register_settings');

//add stuff in head
add_action('admin_head', 'conv_set_head');

//intercept requests made with jquery
add_action('init', 'conv_intercept_request');

$conv_actions = array(
  'export-comment' => 'conv_export_from_wp',
  'import-comment' => 'conv_import_to_wp',
);

function conv_intercept_request() {
  global $conv_actions;
  $action = isset($_GET['conv_action']) ? $_GET['conv_action'] : '';
  if (!empty($action) and !empty($conv_actions[$action])) {
    call_user_func($conv_actions[$action]);
    die();
  }
}

function conv_get_all_comments($post) {
  global $wpdb;

  $comments = $wpdb->get_results($wpdb->prepare(
    "SELECT
      comment_ID AS id,
      comment_author AS author,
      comment_author_email AS email,
      comment_date_gmt AS date_gmt,
      comment_content AS content,
      comment_karma AS votes,
      comment_approved AS approved,
      comment_parent AS parent_id,
      user_id AS user_id
    FROM $wpdb->comments
    WHERE
      comment_post_ID = %d AND
      comment_agent NOT LIKE 'Burnzone/%%'",
    $post->post_id));

  # update IDs to be unique
  foreach ($comments as $c) {
    $c->id = conv_unique_post_id($c->id);
    $c->parent_id = conv_unique_post_id($c->parent_id);
    $c->user_id = conv_unique_post_id($c->user_id);
  }

  return $comments;
}

function conv_get_next_post($post_id) {
  global $wpdb;

  $posts = $wpdb->get_results($wpdb->prepare(
    "SELECT
      ID AS post_id,
      post_name AS name,
      post_title AS title,
      comment_status AS status
    FROM $wpdb->posts
    WHERE
      post_type != 'revision' AND
      post_status = 'publish' AND
      id > %d
    ORDER BY
      id ASC
    LIMIT 1
    ", $post_id));

  if (empty($posts)) {
    return null;
  }

  $p = $posts[0];
  $p->id = conv_unique_post_id($p->post_id);
  $p->uri = get_permalink($p->post_id);
  $p->comments = conv_get_all_comments($p);
  return $p;
}

function conv_sign_message($data) {
  global $conv_opt, $conv_opt_name_sso_key;

  $message = array(
    'sha1' => sha1($data)
  );
  $message = base64_encode(json_encode($message));
  $timestamp = time();
  $hmac = hash_hmac('sha1', "$message $timestamp", $conv_opt[$conv_opt_name_sso_key]);
  return "$message $hmac $timestamp";
}

function conv_import_on_burnzone($post) {
  $http = new WP_Http();
  $data = json_encode($post);
  $auth = conv_sign_message($data);
  $response = $http->request(
    CONVERSAIT_SERVER_HOST . "/api/sites/$post->site/import",
    array(
      'method' => 'POST',
      'body' => array(
        'auth' => $auth,
        'data' => $data
      )
    )
  );

  $data = (array) json_decode($response['body']);
  if (!$data) {
    $data = array(
      'status' => 'fail',
      'message' => 'Burnzone Internal Server Error'
    );
  }

  return $data;
}

function conv_export_from_wp() {
  global $conv_opt;
  global $conv_opt_name_site_name;
  global $conv_opt_name_sso_key;

  $post_id = intval($_GET['post_id']);
  $timestamp = intval($_GET['timestamp']);

  $result = 'success';
  $msg = "Imported conversation $post_id&hellip;";
  $timestamp = time();
  $status = 'complete';

  if (empty($conv_opt[$conv_opt_name_sso_key])) {
    $result = 'fail';
    $msg = 'Please add a SSO key';
  } else if (current_user_can('manage_options')) {
    global $wpdb, $dsq_api;
    $post = conv_get_next_post($post_id);
    if ($post != null) {
      $status = 'partial';
      $post->site = $conv_opt[$conv_opt_name_site_name];

      $resp = conv_import_on_burnzone($post);
      $result = $resp['status'];

      if ($result == 'success') {
        $msg = "Imported conversation $post_id&hellip;";
        $post_id = $post->post_id;
      } else {
        $msg = isset($resp['message']) ? $resp['message'] : 'Unknown error';
      }
    } else {
      $msg = "Finished";
    }
  } else {
    $result = 'fail';
    $msg = 'You are not authorized to export comments';
  }

  $response = compact('result', 'status', 'msg', 'post_id', 'timestamp');
  header('Content-type: text/javascript');

  echo json_encode($response);
}

function conv_import_to_wp() {
}

function conv_set_head() {
  global $conv_opt_name_site_name, $conv_opt, $conv_opt_name;
  $site_name = $conv_opt[$conv_opt_name_site_name];
  echo "<script type='text/javascript'>wp_index_url = '". admin_url('index.php') ."'; bz_default_site = '$site_name'; bz_url = '". CONVERSAIT_SERVER_HOST ."'; self_name = '".get_bloginfo("name")."'; self_url = '".get_bloginfo("url")."';</script>";
}

function conv_create_menu() {
  //create new top-level menu
  add_options_page('BurnZone Commenting Plugin Settings', 'BurnZone Settings', 'administrator', 'conversait', 'conv_frame_page');
  //add_options_page('BurnZone Commenting Advanced Settings', 'BurnZone Advanced', 'administrator', 'conversait', 'conv_settings_page');
  add_options_page('BurnZone Moderator', 'BurnZone Moderator', 'administrator', 'conversait_mod', 'conv_mod_page');
}

function conv_register_settings() {
  global $conv_opt_name_site_name, $conv_opt_name_sso_logo, $conv_opt_name_sso_key,
    $conv_opt_name_enabledfor, $conv_opt_name, $conv_opt_name_activation_type,
    $conv_opt_name_dis_comments;
  //register our settings
  register_setting('conv_settings_group', $conv_opt_name, 'conv_validate_settings');

  add_settings_section('conv_settings_main', 'Main settings', 'conv_settings_main_title', 'conversait');
  add_settings_field($conv_opt_name_activation_type, 'Activated for', 'conv_render_setting_activation', 'conversait', 'conv_settings_main');
  add_settings_field($conv_opt_name_site_name, 'Site Name', 'conv_render_setting_site_name', 'conversait', 'conv_settings_main', array( 'label_for' => $conv_opt_name_site_name));
  add_settings_field($conv_opt_name_enabledfor, 'Enable options', 'conv_render_settings_enabledfor', 'conversait' , 'conv_settings_main');
  add_settings_field($conv_opt_name_dis_comments, 'Disable comments', 'conv_render_settings_disable_comments', 'conversait' , 'conv_settings_main');
  add_settings_field($conv_opt_name_dis_discovery, 'Disable default discovery widget', 'conv_render_settings_disable_discovery', 'conversait' , 'conv_settings_main');
  add_settings_field('conv_name_export', 'Export', 'conv_render_settings_export', 'conversait' , 'conv_settings_main');

  add_settings_section('conv_settings_sso', 'Single Sign On', 'conv_settings_sso_title', 'conversait');
  add_settings_field($conv_opt_name_sso_logo, 'Logo', 'conv_render_setting_sso_logo', 'conversait', 'conv_settings_sso', array( 'label_for' => $conv_opt_name_sso_logo));
  add_settings_field($conv_opt_name_sso_key, 'Key', 'conv_render_setting_sso_key', 'conversait', 'conv_settings_sso', array( 'label_for' => $conv_opt_name_sso_key));
}

/*
 * Disable the comments, but the script will still be loaded. Useful when you only want to use the forums or other widgets.
 */
function conv_render_settings_disable_comments() {
  global $conv_opt, $conv_opt_name, $conv_opt_name_dis_comments;
  $checked = '';
  if (isset($conv_opt[$conv_opt_name_dis_comments]) && $conv_opt[$conv_opt_name_dis_comments] === "1")
    $checked = 'checked="true"';
?>
  <div>
    <input type="checkbox" name="<?php echo $conv_opt_name . "[$conv_opt_name_dis_comments]" ?>" value="1" <?php echo $checked ?> id="<?php echo $conv_opt_name_dis_comments ?>" />
    <p>Check this if you only want to use the forums</p>
  </div>
<?php
}

/*
 * Disable the default discovery widget.
 */
function conv_render_settings_disable_discovery() {
  global $conv_opt, $conv_opt_name, $conv_opt_name_dis_discovery;
  $checked = '';
  if (isset($conv_opt[$conv_opt_name_dis_discovery]) && $conv_opt[$conv_opt_name_dis_discovery] === "1")
    $checked = 'checked="true"';
?>
  <div>
    <input type="checkbox" name="<?php echo $conv_opt_name . "[$conv_opt_name_dis_discovery]" ?>" value="1" <?php echo $checked ?> id="<?php echo $conv_opt_name_dis_discovery ?>" />
    <p>Check this if you don't want the default discovery widget automatically added.</p>
  </div>
<?php
}

/*
* Enabling the commenting platform based on post type.
*/
function conv_render_settings_enabledfor() {
  global $conv_opt, $conv_opt_name_enabledfor, $conv_opt_name;
  $posttypes = get_post_types();
  foreach ($posttypes as $key => $value) {
    $checked = "";
    if (array_key_exists($key, $conv_opt[$conv_opt_name_enabledfor]) && $conv_opt[$conv_opt_name_enabledfor][$key] === "1")
      $checked = 'checked="true"';
  ?>
    <div>
      <input type="checkbox" name="<?php echo $conv_opt_name . "[$conv_opt_name_enabledfor]" ?>[]" value="<?php echo $key ?>" <?php echo $checked ?> id="conv_opt_<?php echo $key ?>"/>
      <label for="conv_opt_<?php echo $key ?>"><?php echo $value ?></label>
    </div>
  <?php
  } ?>
  <p class="description">Type of posts where you want the commenting system to be activated.</p>
  <?php
}

function conv_render_settings_export() {
  ?>
    <div id="conv-export-comments">
      <a href="#" class="button">Export comments</a><span id="conv-export-loading"></span><span id="conv-export-status" class="status"></span>
    </div>
    <p class="description">Export existing Wordpress comments to Burnzone (you need a valid SSO key)</p>
  <?php
}

function conv_settings_main_title() {
  echo '<p>Main settings of BurnZone Commenting</p>';
}

/*
* Loading the timepicker addon dependencies.
* http://trentrichardson.com/examples/timepicker/
*/

function conv_load_scripts_styles(){
  wp_register_style('settings-page-style', plugin_dir_url(__FILE__ ) . 'assets/css/settings_page.css');
  wp_register_style('font-awesome-style', plugin_dir_url(__FILE__ ) . 'assets/css/font-awesome.min.css');
  wp_register_style('jquery-ui-timepicker', plugin_dir_url(__FILE__ ) . 'assets/css/jquery-ui-timepicker-addon.css');
  wp_register_style('jquery-ui-smoothness', plugin_dir_url(__FILE__ ) . 'assets/css/jquery-ui-smoothness/jquery-ui-1.10.2.custom.min.css');
  //wp_register_script('jquery-ui-slider_access', plugin_dir_url(__FILE__ ) . 'assets/js/jquery-ui-sliderAccess.js', array('jquery-ui-slider'));
  wp_register_script('jquery-ui-timepicker', plugin_dir_url(__FILE__ ) . 'assets/js/jquery-ui-timepicker-addon.js', array('jquery-ui-datepicker'));
  wp_register_script('conv-admin-scripts', plugin_dir_url(__FILE__ ) . 'assets/js/admin_scripts.js', array('jquery'));
  wp_enqueue_style('jquery-ui-timepicker');
  wp_enqueue_style('jquery-ui-smoothness');
  wp_enqueue_style('settings-page-style');
  wp_enqueue_style('font-awesome-style');
  wp_enqueue_script('jquery-ui-timepicker');
  // wp_enqueue_script('jquery-ui-slider_access');
  wp_enqueue_script('conv-admin-scripts');
}

add_action('admin_enqueue_scripts', 'conv_load_scripts_styles');

function conv_acttype_checked($forvalue) {
  global $conv_opt_name_activation_type, $conv_opt;
  if ($conv_opt[$conv_opt_name_activation_type] === $forvalue)
    return 'checked="true"';
  return "";
}

function conv_render_setting_activation() {
  global $conv_opt_name_activation_type, $conv_opt_name_activation_date, $conv_opt, $conv_opt_name;
  $activation_type = $conv_opt[$conv_opt_name_activation_type];
  $activation_date = date("Y-m-d h:i A", $conv_opt[$conv_opt_name_activation_date]);
  $typeRadio='type="radio"';

  echo "
    <form>
    <input $typeRadio name=\"" . $conv_opt_name . "[$conv_opt_name_activation_type] \" id=\"1\" value=\"all\" " . conv_acttype_checked('all') . " /> <label for=\"1\">All posts</label> <br/>
    <input $typeRadio name=\"" . $conv_opt_name . "[$conv_opt_name_activation_type] \" id=\"2\" value=\"wpcomments_closed\" " . conv_acttype_checked('wpcomments_closed') . " /> <label for=\"2\">Posts with closed comments</label> <br/>
    <input $typeRadio name=\"" . $conv_opt_name . "[$conv_opt_name_activation_type] \" id=\"3\" value=\"since\" " . conv_acttype_checked('since') . " />
      <label for=\"3\">Posts published since:
          <input type=\"text\" id=\"$conv_opt_name_activation_date\" name=\"" . $conv_opt_name . "[$conv_opt_name_activation_date]\" value=\"$activation_date\" />
      </label>
    </form>
  ";
}

function conv_render_setting_site_name() {
  global $conv_opt_name_site_name, $conv_opt, $conv_opt_name;
  $site_name = $conv_opt[$conv_opt_name_site_name];
  echo "<input type=\"text\" id=\"$conv_opt_name_site_name\" name=\"" . $conv_opt_name . "[$conv_opt_name_site_name]\" value=\"$site_name\" /><p class=\"description\">This is the name of your site which you <a href=\"" . CONVERSAIT_SERVER_HOST . "/auth/signin?redirect=/admin\" target=\"_blank\" title=\"BurnZone Commenting sign-up page\">register</a> at Burnzone.</p>";
}

function conv_settings_sso_title() {
  echo '<p>Settings related to Single Sign On</p>';
}

function conv_render_setting_sso_logo() {
  global $conv_opt_name_sso_logo, $conv_opt, $conv_opt_name;
  $sso_logo = $conv_opt[$conv_opt_name_sso_logo];
  echo "<input type=\"text\" id=\"$conv_opt_name_sso_logo\" name=\"" . $conv_opt_name . "[$conv_opt_name_sso_logo]\" value=\"$sso_logo\" /><p class=\"description\">The url of the image to show in the login panel of Burnzone Commenting for the option to login with the credentials for your site.</p>";
}

function conv_render_setting_sso_key() {
  global $conv_opt_name_sso_key, $conv_opt, $conv_opt_name;
  $sso_key = $conv_opt[$conv_opt_name_sso_key];
  echo "<input type=\"text\" id=\"$conv_opt_name_sso_key\" name=\"" . $conv_opt_name . "[$conv_opt_name_sso_key]\" value=\"$sso_key\" /><p class=\"description\">Your unique SSO key.</p>";
}

function conv_validate_settings($options) {
  global $conv_opt_name_site_name, $conv_opt_name_sso_logo, $conv_opt_name_sso_key, $conv_opt_name_enabledfor,
    $conv_opt, $conv_opt_name_activation_type, $conv_opt_name_activation_date, $conv_opt_name_dis_comments,
    $conv_opt_name_dis_discovery;

  $newOptions = array_merge(array(), (array)$conv_opt);

  /*
  * sso logo
  */
  $newOptions[$conv_opt_name_sso_logo] = $options[$conv_opt_name_sso_logo];

  /*
  * sso key
  */
  $newOptions[$conv_opt_name_sso_key] = $options[$conv_opt_name_sso_key];

  /*
  * site name
  */
  $site_name = trim($options[$conv_opt_name_site_name]);
  /* if(!preg_match('/^[a-z0-9]+$/i', $site_name)) */
  /*   $site_name = ""; */
  $newOptions[$conv_opt_name_site_name] = strtolower($site_name);

  /*
  * enabled for
  */
  $posttypes = get_post_types();
  $newEnabledfor = array();
  $enabledfor = $options[$conv_opt_name_enabledfor];
  for ($i=0; $i < count($enabledfor); $i++) {
    if ($posttypes[$enabledfor[$i]])
      $newEnabledfor[$enabledfor[$i]] = "1";
  }
  $newOptions[$conv_opt_name_enabledfor] = $newEnabledfor;

  /*
  * activation type
  */
  $atype = $options[$conv_opt_name_activation_type];
  if ($atype === "all" || $atype === "since" || $atype === "wpcomments_closed") {
    $newOptions[$conv_opt_name_activation_type] = $atype;
    if ($atype === "since") {
      $activation_date = date_create_from_format("Y-m-d h:i A", $options[$conv_opt_name_activation_date]);
      if ($activation_date) {
        $activation_date = $activation_date->getTimestamp();
      }
      else
        $activation_date = time();
      $newOptions[$conv_opt_name_activation_date] = $activation_date;
    }
  }

  /*
   * disable comments
   */
  $newOptions[$conv_opt_name_dis_comments] = $options[$conv_opt_name_dis_comments];

  /*
   * disable discovery
   */
  $newOptions[$conv_opt_name_dis_discovery] = $options[$conv_opt_name_dis_discovery];

  return $newOptions;
}

function conv_settings_page() {
?>

<div class="wrap">
<h2>BurnZone Advanced Settings</h2>

<form method="post" action="options.php">
  <?php settings_fields('conv_settings_group'); ?>
  <?php do_settings_sections('conversait'); ?>

  <?php submit_button(); ?>

</form>
</div>

<?php }

function conv_frame_page() {
  global $conv_opt_name_site_name, $conv_opt, $conv_opt_name_demo_site, $conv_opt_name_demo_sso;
  $site_name = $conv_opt[$conv_opt_name_site_name];
  $demo_site = $conv_opt[$conv_opt_name_demo_site];
  if ($site_name == $demo_site) {
    $signed = urlencode($demo_site.':'.conv_sign_message(json_encode(array("name" => $demo_site))));
  }
?>

<div class="wrap">
<h2>BurnZone Commenting Settings</h2>

<form method="post" action="options.php">
  <?php settings_fields('conv_settings_group'); ?>

  <div id="burnzone_save_reminder" class="display_none">
    <div class="update-nag">
      Apply '<strong class="burnzone_site_name"></strong>' settings to this WordPress site.
    </div>
    <?php submit_button('Update Site'); ?>
  </div>
  <!-- <iframe id="burnzone_frame" src="<?php echo CONVERSAIT_SERVER_HOST . "/wordpress_frame?site=$site_name&amp;frame=true"; ?>" style="width:100%; height: 0px;"></iframe> -->
  <?php if (empty($signed)) { ?>
  <iframe id="burnzone_frame" src="<?php echo CONVERSAIT_SERVER_HOST . "/admin/settings?frame=true&site=$site_name"; ?>" style="width:100%; height: 400px;"></iframe>
  <?php } else { ?>
  <iframe id="burnzone_frame" src="<?php echo CONVERSAIT_SERVER_HOST . "/admin/settings?frame=true&site=$site_name&demo=$signed"; ?>" style="width:100%; height: 400px;"></iframe>
  <?php } ?>
  <div>
    <a class="conv-show-advanced" href="#">Advanced</a>
    <i class="conv-hint-advanced">(only use if you experience errors)</i>
  </div>

  <div class="conv-advanced-settings display_none">
  <?php do_settings_sections('conversait'); ?>
  <?php submit_button(); ?>
  </div>

</form>
</div>

<?php }
function conv_mod_page() {
  global $conv_opt_name_site_name, $conv_opt;
  $site_name = $conv_opt[$conv_opt_name_site_name];
?>

<div class="wrap">
<h2>BurnZone Commenting Moderator</h2>
<iframe src="<?php echo "http://" . $site_name . "." . CONVERSAIT_DOMAIN_PORT . "/admin/moderator?embed=true"; ?>" style="width:100%; min-height:650px;"></iframe>
</div>
<?php } ?>

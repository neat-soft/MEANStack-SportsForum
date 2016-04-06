<?php

  function conv_build_sso_string() {
    global $current_user, $conv_opt, $conv_opt_name_sso_key;
    get_currentuserinfo();
    if ($current_user->ID) {
      $data = array(
        'id' => conv_unique_post_id("$current_user->ID"),
        'name' => $current_user->display_name,
        'email' => $current_user->user_email
      );
    }
    else {
      $data = array();
    }
    $message = base64_encode(json_encode($data));
    $timestamp = time();
    $hmac = hash_hmac('sha1', "$message $timestamp", $conv_opt[$conv_opt_name_sso_key]);
    return "$message $hmac $timestamp";
  }

  function conv_build_sso_options() {
    global $conv_opt_name_sso_logo, $conv_opt;
    $data = array(
      'logo' => $conv_opt[$conv_opt_name_sso_logo],
      'loginUrl' => wp_login_url(CONVERSAIT_SERVER_HOST . '/web/auth/popup_auth_ok.html'),
      'logoutUrl' => wp_logout_url(get_permalink())
    );
    return json_encode($data);
  }

  function ssoEnabled() {
    global $conv_opt, $conv_opt_name_sso_key;
    return isset($conv_opt[$conv_opt_name_sso_key]) && $conv_opt[$conv_opt_name_sso_key] !== '';
  }

?>

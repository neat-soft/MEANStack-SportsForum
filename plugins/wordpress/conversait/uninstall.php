<?php

  if(!defined('WP_UNINSTALL_PLUGIN')) exit();
  define('CONVERSAIT_PATH', plugin_dir_path(__FILE__));
  include(CONVERSAIT_PATH . 'options.php');
  conv_remove_options();

?>
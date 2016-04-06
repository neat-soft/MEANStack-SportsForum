<?php

  global $conv_opt_name_dis_discovery, $conv_opt;
  global $post;

  $conv_area_tag = "";
  $post_link = get_permalink($post->ID);
  $disable_discovery = (isset($conv_opt[$conv_opt_name_dis_discovery]) && $conv_opt[$conv_opt_name_dis_discovery] === "1");
  $conv_area_tag = '<div id="conversait_area" class="conversait_area" data-conversait-app-type="article"></div>';
  if (!$disable_discovery) {
    $conv_area_tag = '<div id="conversait_area" class="conversait_area" data-conversait-app-type="widget:discovery"></div>' . $conv_area_tag;
  }
  $conv_embed_data = '
<script type="text/javascript">
  var conversait_id = "' . conv_unique_post_id($post->ID) . '";
  var conversait_uri = "' . $post_link . '";
  var conversait_title = "' . get_the_title($post->ID) . '";
</script>
';
?>
<div id="comments">
  <div id="respond" style="background:none; width: auto; border: none">
    <?php
      echo $conv_area_tag . $conv_embed_data;
    ?>
  </div>
</div>

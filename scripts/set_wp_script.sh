#!/bin/sh

GENERIC_PLUGIN=`cat plugins/generic/embed_script`
cd plugins/wordpress/conversait/
echo "<?php\n  \$conv_embed_script = '$GENERIC_PLUGIN';\n?>\n" > comments.php
cat _comments.php >> comments.php
WP_VERSION=`cat _version`
sed "s,{{{version}}},$WP_VERSION," _conversait.php > conversait.php
cd ../../..

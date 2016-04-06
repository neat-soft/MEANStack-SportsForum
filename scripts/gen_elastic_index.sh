#!/bin/sh

# WARNING: DROPS EVERYTHING!
# curl -XDELETE $1:9200/page_views
# curl -XDELETE $1:9200/comments
# curl -XDELETE $1:9200/conversations
# curl -XDELETE $1:9200/notifications
# curl -XDELETE $1:9200/profiles
# curl -XDELETE $1:9200/subscriptions
# curl -XDELETE $1:9200/verified

curl -XPOST $1:9200/page_views/ -d @page_views_daily.json
curl -XPOST $1:9200/comments/ -d @comments_daily.json
curl -XPOST $1:9200/conversations/ -d @conversations_daily.json
curl -XPOST $1:9200/notifications/ -d @notifications_daily.json
curl -XPOST $1:9200/profiles/ -d @profiles_daily.json
curl -XPOST $1:9200/subscriptions/ -d @subscriptions_daily.json
curl -XPOST $1:9200/verified/ -d @verified_daily.json


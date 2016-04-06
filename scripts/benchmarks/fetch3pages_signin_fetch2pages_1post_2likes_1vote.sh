#!/bin/sh
httperf --hog --server burnzonestaging.herokuapp.com --max-connections 4 --retry-on-failure --rate 100 -v --session-cookie --debug 5 --wsesslog=1000,2,fetch3pages_signin_fetch2pages_1post_2likes_1vote.httperf

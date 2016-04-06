#!/bin/bash

#
# Usage:
# run_with_logging.sh <description> <process/script name> [arguments]

THIS_DIR=${0%/*}
node ${THIS_DIR}/../server/launch.js $*

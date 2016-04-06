#!/bin/bash
THIS_DIR=${0%/*}
cd $THIS_DIR/../server

export NODE_PATH="./server:./shared"

ulimit -Hn 65000
ulimit -n 65000
node ./main.js "$1"

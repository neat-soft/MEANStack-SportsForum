#!/bin/bash
THIS_DIR=${0%/*}
cd $THIS_DIR/../server

export NODE_PATH="./server:./shared"
export NODE_ENV="development"
export CLUSTER="single"

node ./main.js "$1"

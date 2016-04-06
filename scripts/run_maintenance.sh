#!/bin/bash
THIS_DIR=${0%/*}
cd $THIS_DIR/../server

export NODE_PATH="./server:./shared"

node ./maintenance.js "$1"

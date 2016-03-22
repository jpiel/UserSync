#!/bin/zsh

INST_DIR=$(dirname $0)

#echo $(date "+%Y-%m-%d--%H:%M:%S : ")Launch UserSync >>~/.UserSync/History.log

(nohup ${INST_DIR}/UserSync.sh &!)

#echo $(date "+%Y-%m-%d--%H:%M:%S : ")End launchUserSync >>~/.UserSync/History.log

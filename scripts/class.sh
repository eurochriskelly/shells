#!/bin/bash

# class helper functions

class::init() {
  local name=$1;shift
  local instance=$(uuidgen)
  instance=${SEED//-/}
  local log=/tmp/${instance}-${seed}.txt
  touch $log
  for var in "$@";do
    echo "export ${name}_${instance}_${var}=\${$var}" >> $log
  done
  echo $log
}
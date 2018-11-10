#!/bin/bash

BASE_D=$(realpath "${BASH_SOURCE%/*}/..")
export NODE=$(basename $BASE_D)
cd "$BASE_D"
exec python "./service"

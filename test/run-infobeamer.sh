#!/bin/bash

export INFOBEAMER_ENV_SERIAL=${1:-1234567890}
if [ -n "$2" ]; then
  export INFOBEAMER_WIDTH=$2
fi
if [ -n "$3" ]; then
  export INFOBEAMER_HEIGHT=$3
fi

BASE_D=$(realpath "${BASH_SOURCE%/*}/..")
exec info-beamer "$BASE_D"

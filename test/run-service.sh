#!/bin/bash

BASE_D=$(realpath "${BASH_SOURCE%/*}/../")
NODE_NAME=$(basename $BASE_D)

exec sudo docker run --network host --rm -it -v "/$BASE_D:/space/root" -w "/space/root" -e "NODE=$NODE_NAME" infobeamer:bionic python "./service"

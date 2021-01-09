#!/bin/bash

BASE_D=$(realpath "${BASH_SOURCE%/*}/")

sudo docker build -t infobeamer:bionic "$BASE_D"

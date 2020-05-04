#!/bin/sh
set -e
./download-origs.sh
./create-dscs.sh
./build-from-dsc.sh

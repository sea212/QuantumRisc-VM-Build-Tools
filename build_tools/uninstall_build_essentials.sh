#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Dec. 29 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

RED='\033[1;31m'
NC='\033[0m'

# require sudo
if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# exit when any command fails
set -e

# file that contains the newly added build tools
REMOVE_HINT_FILE="remove_after_build.txt"

if [ ! -f $REMOVE_HINT_FILE ]; then
    echo -e "${RED}Error: File \"${REMOVE_HINT_FILE}\" not found.${NC}"
    exit 1
fi
       
# remove newly added build tools
while IFS= read -r LINE; do
    for APTPKG in $LINE; do
        apt-get remove -y $APTPKG
    done
done < $REMOVE_HINT_FILE

apt-get autoremove -y
rm $REMOVE_HINT_FILE

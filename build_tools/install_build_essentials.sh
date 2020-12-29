#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jun. 23 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# require sudo
if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# exit when any command fails
set -e

# required tools
TOOLS="build-essential git clang gcc meson ninja-build g++ python3-dev \
       make flex bison libc6 binutils gzip bzip2 tar perl autoconf m4 \
       automake gettext gperf dejagnu expect tcl"
REMOVE_HINT_FILE="remove_after_build.txt"
       
# check which tools are not installed, so that they can be removed
# after installation
NOT_INSTALLED=""
APTLIST=`apt list --installed`

for TOOL in $TOOLS; do
    case "$APTLIST" in
        *"${TOOL}/"*)
            echo "found $TOOL"
            continue
            ;;
    esac
    
    NOT_INSTALLED="${NOT_INSTALLED} $TOOL"
done

echo -e "$NOT_INSTALLED" >> $REMOVE_HINT_FILE

# install and upgrade tools
apt-get update
apt-get install -y $TOOLS
apt-get install --only-upgrade -y $TOOLS

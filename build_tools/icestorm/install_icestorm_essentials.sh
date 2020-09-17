#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jun. 24 2020
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
TOOLS="build-essential clang bison flex libreadline-dev \
       gawk tcl-dev libffi-dev git mercurial graphviz   \
       xdot pkg-config python python3 libftdi-dev \
       qt5-default python3-dev libboost-all-dev cmake libeigen3-dev"

# install and upgrade tools
apt-get update
apt-get install -y $TOOLS
apt-get install --only-upgrade -y $TOOLS

#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jun. 25 2020
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
TOOLS="git perl python3 make g++ libfl2 libfl-dev zlibc zlib1g zlib1g-dev \
       ccache libgoogle-perftools-dev numactl git autoconf flex bison"

# install and upgrade tools
apt-get update
apt-get install -y $TOOLS
apt-get install --only-upgrade -y $TOOLS

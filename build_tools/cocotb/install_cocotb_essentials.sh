#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Oct. 24 2020
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
TOOLS="g++ python3 python3-pip"

# install and upgrade tools
apt-get update
apt-get install -y $TOOLS
apt-get install --only-upgrade -y $TOOLS
# install cocotb
python3 -m pip install --upgrade pip
python3 -m pip install cocotb

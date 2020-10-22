#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jun. 25 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
LIBRARY="../libraries/library.sh"
REPO="https://github.com/SpinalHDL/openocd_riscv.git"
PROJ="openocd_vexriscv"
BUILDFOLDER="build_and_install_openocd_vexriscv"
VERSIONFILE="installed_version.txt"
TAG="latest"
INSTALL=false
INSTALL_PREFIX="default"
CLEANUP=false

CONFIGURE_STRING="--prefix=/usr/local --program-suffix=-vexriscv 
--datarootdir=/usr/local/share/vexriscv --enable-maintainer-mode 
--disable-werror --enable-ft232r --enable-ftdi --enable-jtag_vpi"


# parse arguments
USAGE="$(basename "$0") [-h] [-c] [-d dir] [-i path] [-t tag] -- Clone latested tagged ${PROJ} version and build it. Optionally select the build directory and version, install binaries and cleanup setup files.

where:
    -h          show this help text
    -c          cleanup project
    -d dir      build files in \"dir\" (default: ${BUILDFOLDER})
    -i path     install binaries to path (use \"default\" to use default path)
    -t tag      specify version (git tag or commit hash) to pull (default: Latest tag)"
   
 
while getopts ':hi:cd:t:' OPTION; do
    case $OPTION in
        i)  INSTALL=true
            # Adjust configure string
            if [ "$OPTARG" != 'default' ]; then
                CONFIGURE_STRING="${CONFIGURE_STRING//"/usr/local"/"$OPTARG"}"
            fi
            # INSTALL_PREFIX="$OPTARG"
            echo "-i set: Installing built binaries to $OPTARG"
            ;;
    esac
done

OPTIND=1

while getopts ':hi:cd:t:' OPTION; do
    case "$OPTION" in
        h)  echo "$USAGE"
            exit
            ;;
        c)  if [ $INSTALL = false ]; then
                >&2 echo -e "${RED}ERROR: -c only makes sense if the built binaries were installed before (-i)"
                exit 1
            fi
            CLEANUP=true
            echo "-c set: Removing build directory"
            ;;
        d)  echo "-d set: Using folder $OPTARG"
            BUILDFOLDER="$OPTARG"
            ;;
        t)  echo "-t set: Using version $OPTARG"
            TAG="$OPTARG"
            ;;
        :)  echo -e "${RED}ERROR: missing argument for -${OPTARG}\n${NC}" >&2
            echo "$USAGE" >&2
            exit 1
            ;;
        \?) echo -e "${RED}ERROR: illegal option: -${OPTARG}\n${NC}" >&2
            echo "$USAGE" >&2
            exit 1
            ;;
    esac
done

shift "$((OPTIND - 1))"

# exit when any command fails
set -e

# require sudo
if [[ $UID != 0 ]]; then
    echo -e "${RED}Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# cleanup files if the programm was shutdown unexpectedly
trap 'echo -e "${RED}ERROR: Script was terminated unexpectedly, cleaning up files..." && pushd -0 > /dev/null && rm -rf $BUILDFOLDER' INT TERM

# load shared functions
source $LIBRARY

# fetch specified version 
if [ ! -d $BUILDFOLDER ]; then
    mkdir $BUILDFOLDER
fi

pushd $BUILDFOLDER > /dev/null

if [ ! -d "${PROJ%%/*}" ]; then
    git clone --recursive "$REPO" "${PROJ%%/*}"
fi

pushd $PROJ > /dev/null
select_and_get_project_version "$TAG" "COMMIT_HASH"
# build and install if wanted
./bootstrap
./configure $CONFIGURE_STRING
  
make -j$(nproc)

if [ $INSTALL = true ]; then
    make install
fi

# return to first folder and store version
pushd -0 > /dev/null
echo "${PROJ##*/}: $COMMIT_HASH" >> "$VERSIONFILE"

# cleanup if wanted
if [ $CLEANUP = true ]; then
    rm -rf $BUILDFOLDER
fi



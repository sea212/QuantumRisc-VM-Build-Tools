#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jun. 25 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
REPO="https://github.com/YosysHQ/nextpnr.git"
PROJ="nextpnr"
CHIP="ice40"
BUILDFOLDER="build_and_install_nextpnr"
VERSIONFILE="installed_version.txt"
TAG="latest"
LIBPATH=""
INSTALL=false
CLEANUP=false
# trellis config
TRELLIS_LIB="/usr"
TRELLIS_REPO="https://github.com/SymbiFlow/prjtrellis"
TRELLIS_PROJ="prjtrellis"
# icestorm config
ICESTORM_REPO="https://github.com/cliffordwolf/icestorm.git"
ICESTORM_PROJ="icestorm"
ICESTORM_LIB="/usr/local/share/icebox"
ICESTORM_ICEBOX_DIR="icestorm"


# parse arguments
USAGE="$(basename "$0") [-h] [-c] [-e] [-d dir] [-i path] [-l path] [-t tag] -- Clone latested tagged ${PROJ} version and build it. Optionally select the build directory, chip files, chipset and version, install binaries and cleanup setup files.

where:
    -h          show this help text
    -c          cleanup project
    -e          install NextPNR for ecp5 chips (default: ice40)
    -d dir      build files in \"dir\" (default: ${BUILDFOLDER})
    -i path     install binaries to path (use \"default\" to use default path)
    -l path     use local chip files for ice40 or ecp5 from \"path\" (use empty string for default path in ubuntu)
    -t tag      specify version (git tag or commit hash) to pull (default: Latest tag)"
   
 
while getopts ":hecd:i:t:l:" OPTION; do
    case $OPTION in
        i)  INSTALL=true
            INSTALL_PREFIX="$OPTARG"
            echo "-i set: Installing built binaries to $INSTALL_PREFIX"
            ;;
        e)  echo "-e set: Installing NextPNR for ecp5 chipset"
            CHIP="ecp5"
            ;;
    esac
done

OPTIND=1

while getopts ':hecd:i:t:l:' OPTION; do
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
    l)  echo "-l set: Using local chip data"
        if [ -z "$OPTARG" ]; then
            if [ "$CHIP" = "ice40" ]; then
                LIBPATH="$ICESTORM_LIB"
            else
                LIBPATH="$TRELLIS_LIB"
            fi
        else
            if [ ! -d "$OPTARG" ]; then
                echo -e "${RED}ERROR: Invalid path \"${OPTARG}\""
                exit 1
            fi

            LIBPATH="$OPTARG"
        fi
        ;;
    :)  echo -e "${RED}ERROR: missing argument for -${OPTARG}\n${NC}" >&2
        echo "$USAGE" >&2
        exit 1
        ;;
    \?) echo -e "${RED}ERROR: illegal option: -${OPTARG}\n${NC}" "$OPTARG" >&2
        echo "$USAGE" >&2
        exit 1
        ;;
    esac
done

shift "$((OPTIND - 1))"

# This function does checkout the correct version and return the commit hash or tag name
# Parameter 1: Branch name, commit hash, tag or one of the special keywords default/latest/stable
# Parameter 2: Return variable name (commit hash or tag name)
function select_and_get_project_version {
    # Stable selected: Choose latest tag if available, otherwise use default branch
    if [ "$1" == "stable" ]; then
        local L_TAGLIST=`git rev-list --tags --max-count=1`
        
        # tags found?
        if [ -n "$L_TAGLIST" ]; then
            local L_COMMIT_HASH="`git describe --tags $L_TAGLIST`"
            git checkout --recurse-submodules "$L_COMMIT_HASH"
        else
            git checkout --recurse-submodules $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
            local L_COMMIT_HASH="$(git rev-parse HEAD)"
            >&2 echo -e "${RED}WARNING: No git tags found, using default branch${NC}"
        fi
    else
        # Either checkout defaut/stable branch or use custom commit hash, tag or branch name
        if [ "$1" == "default" ] || [ "$1" == "latest" ]; then
            git checkout --recurse-submodules $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
            local L_COMMIT_HASH="$(git rev-parse HEAD)"
        else
            # Check if $1 contains a valid tag and use it as the version if it does
            git checkout --recurse-submodules "$1"
            local L_COMMIT_HASH="$(git rev-parse HEAD)"
            
            for CUR_TAG in `git tag --list`; do
                if [ "$CUR_TAG" == "$1" ]; then
                    L_COMMIT_HASH="$1"
                    break
                fi
            done
        fi
    fi
    
    # Apply return value
    eval "$2=\"$L_COMMIT_HASH\""
}

# exit when any command fails
set -e

# require sudo
if [[ $UID != 0 ]]; then
    echo -e "${RED}Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Cleanup files if the programm was shutdown unexpectedly
trap 'echo -e "${RED}ERROR: Script was terminated unexpectedly, cleaning up files..." && pushd -0 > /dev/null && rm -rf $BUILDFOLDER' INT TERM

# fetch specified version 
if [ ! -d $BUILDFOLDER ]; then
    mkdir $BUILDFOLDER
fi

pushd $BUILDFOLDER > /dev/null

if [ ! -d "$PROJ" ]; then
    git clone --recursive "$REPO" "${PROJ%%/*}"
fi

pushd $PROJ > /dev/null

select_and_get_project_version "$TAG" "COMMIT_HASH"

# build and install if wanted
# chip ice40?
if [ "$CHIP" = "ice40" ]; then
    # is icestorm installed?
    if [ -n "$LIBPATH" ]; then
        if [ "$INSTALL_PREFIX" == "default" ]; then
            cmake -DARCH=ice40 -DICEBOX_ROOT=${LIBPATH} .
        else
            cmake -DARCH=ice40 -DICEBOX_ROOT=${LIBPATH} -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" .
        fi
    else
        echo "Note: Pulling Icestorm from Github."
        
        if [ ! -d "$ICESTORM_PROJ" ]; then
            git clone $ICESTORM_REPO "$ICESTORM_ICEBOX_DIR"
        fi
        
        NEXTPNR_FOLDER=`pwd -P`
        # build icebox (chipdbs)
        pushd "${ICESTORM_ICEBOX_DIR}/icebox" > /dev/null
        make -j$(nproc)
        make install DESTDIR=$NEXTPNR_FOLDER PREFIX=''
        popd +0 > /dev/null
        # build icetime (timing)
        pushd "${ICESTORM_ICEBOX_DIR}/icetime" > /dev/null
        make -j$(nproc) PREFIX=$NEXTPNR_FOLDER
        make install DESTDIR=$NEXTPNR_FOLDER PREFIX=''
        popd +0 > /dev/null
        # build nextpnr-ice40 next
        
        if [ "$INSTALL_PREFIX" == "default" ]; then
            cmake -j$(nproc) -DARCH=ice40 -DICEBOX_ROOT="${NEXTPNR_FOLDER}/share/icebox" .
        else
            cmake -j$(nproc) -DARCH=ice40 -DICEBOX_ROOT="${NEXTPNR_FOLDER}/share/icebox" -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" .
        fi
    fi
# chip ecp5?
else
    # is project trellis installed?
    if [ -d "$LIBPATH" ]; then
        if [ "$INSTALL_PREFIX" == "default" ]; then
            cmake -j$(nproc) -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX=${LIBPATH} .
        else
            cmake -j$(nproc) -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX=${LIBPATH} -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" .
        fi
    else
        echo "Note: Pulling Trellis from Github."
        
        if [ ! -d "$TRELLIS_PROJ" ]; then
            git clone --recursive $TRELLIS_REPO
        fi
        
        TRELLIS_MAKE_PATH="$(pwd -P)/${TRELLIS_PROJ}/libtrellis"
        pushd "$TRELLIS_MAKE_PATH" > /dev/null
        cmake -j$(nproc) -DCMAKE_INSTALL_PREFIX="$TRELLIS_MAKE_PATH" .
        make -j$(nproc)
        make install
        popd +0 > /dev/null
        
        if [ "$INSTALL_PREFIX" == "default" ]; then
            cmake -j$(nproc) -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX="$TRELLIS_MAKE_PATH" .
        else
            cmake -j$(nproc) -DARCH=ecp5 -DTRELLIS_INSTALL_PREFIX="$TRELLIS_MAKE_PATH" -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" .
        fi
    fi
fi

make -j$(nproc)

if [ $INSTALL = true ]; then
    make install
fi

# return to first folder and store version
pushd -0 > /dev/null

if [ "$CHIP" == "ice40" ]; then
    echo "${PROJ##*/}-ice40: $COMMIT_HASH" >> "$VERSIONFILE"
else
    echo "${PROJ##*/}-ecp5: $COMMIT_HASH" >> "$VERSIONFILE"
fi

# cleanup if wanted
if [ $CLEANUP = true ]; then
    rm -rf $BUILDFOLDER
fi

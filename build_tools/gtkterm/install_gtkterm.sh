#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Oct. 08 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
REPO="https://github.com/Jeija/gtkterm"
PROJ="gtkterm"
BUILDFOLDER="build_and_install_gtkterm"
VERSIONFILE="installed_version.txt"
TAG="latest"
INSTALL=false
INSTALL_PREFIX="default"
CLEANUP=false


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
            INSTALL_PREFIX="$OPTARG"
            echo "-i set: Installing built binaries to $INSTALL_PREFIX"
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

if [ "$INSTALL_PREFIX" == "default" ]; then
    meson build
else
    meson build -Dprefix="$INSTALL_PREFIX"
fi

if [ $INSTALL = true ]; then
    ninja -C build install
else
    ninja -C build
fi

# return to first folder and store version
pushd -0 > /dev/null
echo "${PROJ##*/}: $COMMIT_HASH" >> "$VERSIONFILE"

# cleanup if wanted
if [ $CLEANUP = true ]; then
    rm -rf $BUILDFOLDER
fi


#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jun. 25 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
REPO="https://github.com/f32c/tools.git"
PROJ="tools/ujprog"
BUILDFOLDER="build_and_install_ujprog"
VERSIONFILE="installed_version.txt"
TAG="latest"
INSTALL=false
CLEANUP=false


# parse arguments
USAGE="$(basename "$0") [-h] [-i] [-c] [-d dir] [-t tag] -- Clone latested tagged ${PROJ} version and build it. Optionally select the build directory and version, install binaries and cleanup setup files.

where:
    -h  		show this help text
    -i  		install binaries
    -c			cleanup project
    -d dir 		build files in \"dir\" (default: ${BUILDFOLDER})
    -t tag		specify version (git tag or commit hash) to pull (default: Latest tag)"
   
 
while getopts ":i" OPTION; do
	case $OPTION in
		i)	INSTALL=true
		   	echo "-i set: Installing built binaries"
		   	;;
	esac
done

OPTIND=1

while getopts ':hicd:t:' OPTION; do
	case "$OPTION" in
    	h) 	echo "$USAGE"
       		exit
       		;;
		c) 	if [ $INSTALL = false ]; then
				>&2 echo -e "${RED}ERROR: -c only makes sense if the built binaries were installed before (-i)"
				exit 1
			fi
			CLEANUP=true
		   	echo "-c set: Removing build directory"
		   	;;
		d)	echo "-d set: Using folder $OPTARG"
			BUILDFOLDER="$OPTARG"
			;;
		t)	echo "-t set: Using version $OPTARG"
			TAG="$OPTARG"
			;;
		:) 	echo -e "${RED}ERROR: missing argument for -${OPTARG}\n${NC}" >&2
		   	echo "$USAGE" >&2
		   	exit 1
		   	;;
	   \?) 	echo -e "${RED}ERROR: illegal option: -${OPTARG}\n${NC}" >&2
		   	echo "$USAGE" >&2
		   	exit 1
		   	;;
	esac
done
shift $((OPTIND - 1))

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
    git clone --recursive $REPO
fi

pushd $PROJ > /dev/null

if [ "$TAG" = "latest" ]; then
	TAGLIST=`git rev-list --tags --max-count=1`
	
	# tags found?
	if [ -n "$TAGLIST" ]; then
	    COMMIT_HASH="`git describe --tags $TAGLIST`"
		git checkout "$COMMIT_HASH"
	else
	    COMMIT_HASH="$(git rev-parse HEAD)"
		>&2 echo -e "${RED}WARNING: No git tags found, using master branch${NC}"
	fi
else
	git checkout $TAG
	
	if [ "$TAG" == "master" ] || [ "${TAG::7}" = "develop" ]; then
	    COMMIT_HASH="$(git rev-parse HEAD)"
	else
	    COMMIT_HASH="$TAG"
	fi
fi

# build and install if wanted
cp Makefile.linux Makefile
make -j$(nproc)

if [ $INSTALL = true ]; then
	make install
fi

# return to first folder and store version
pushd -0 > /dev/null
echo "Ujprog: $COMMIT_HASH" >> "$VERSIONFILE"

# cleanup if wanted
if [ $CLEANUP = true ]; then
	rm -rf $BUILDFOLDER
fi


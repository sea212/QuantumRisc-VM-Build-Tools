#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Oct. 23 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
LIBRARY="../libraries/library.sh"
REPO="https://github.com/ghdl/ghdl.git"
REPO_LIBBACKTRACE="https://github.com/ianlancetaylor/libbacktrace.git"
REPO_GCC="https://gcc.gnu.org/git/gcc.git"
REPO_GHDL_YOSYS_PLUGIN="https://github.com/ghdl/ghdl-yosys-plugin"
PROJ="ghdl"
PROJ_GHDL_YOSYS_PLUGIN="ghdl-yosys-plugin"
BUILDFOLDER="build_and_install_ghdl"
VERSIONFILE="installed_version.txt"
TAG="latest"
INSTALL=false
INSTALL_PREFIX="default"
CLEANUP=false
BUILD_MCODE=false
BUILD_LLVM=false
BUILD_GCC=false
BUILD_YOSYS_PLUGIN=''
DEFAULT_PREFIX='/usr/local'
GHDL_GCC_SUFFIX='-ghdl'
BUILD_GCC_DEFAULT_CONFIG="--enable-languages=c,vhdl --disable-bootstrap \
--disable-lto --disable-multilib --disable-libssp --program-suffix=${GHDL_GCC_SUFFIX}"

# parse arguments
USAGE="$(basename "$0") [-h] [-c] [-l] [-m] [-g] [-y] [-d dir] [-i path] [-t tag] -- Clone latested tagged ${PROJ} version and build it. Optionally select the build directory and version, install binaries and cleanup setup files.

where:
    -h          show this help text
    -c          cleanup project
    -g          build GCC backend
    -l          build LLVM backend
    -m          build mcode backend
    -y          build ghdl-yosys-plugin
    -d dir      build files in \"dir\" (default: ${BUILDFOLDER})
    -i path     install binaries to path (use \"default\" to use default path)
    -t tag      specify version (git tag or commit hash) to pull (default: Latest tag)"
   
 
while getopts ':hcglmyd:i:t:' OPTION; do
    case $OPTION in
        i)  INSTALL=true
            INSTALL_PREFIX="$OPTARG"
            echo "-i set: Installing built binaries to $INSTALL_PREFIX"
            ;;
    esac
done

OPTIND=1

while getopts ':hcglmyd:i:t:' OPTION; do
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
        g)  echo "-g set: Building GCC backend for GHDL"
            BUILD_GCC=true
            ;;
        l)  echo "-l set: Building LLVM backend for GHDL"
            BUILD_LLVM=true
            ;;
        m)  echo "-m set: Building MCODE backend for GHDL"
            BUILD_MCODE=true
            ;;
        y)  echo "-y set: Building ghdl yosys plugin"
            BUILD_YOSYS_PLUGIN='--enable-synth'
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

function build_mcode {
    mkdir -p 'build_mcode'
    pushd 'build_mcode' > /dev/null
    
    if [ $INSTALL = true ]; then
        if [ "$INSTALL_PREFIX" == "default" ]; then
            INSTALL_PREFIX="$DEFAULT_PREFIX"
        fi
    else
        INSTALL_PREFIX="$(pwd -P)/build"
    fi
        
    mkdir -p "$INSTALL_PREFIX"
    ../configure $BUILD_YOSYS_PLUGIN --prefix="$INSTALL_PREFIX"
    make -j$(nproc)
    
    # ugly workarround: makefile offers no option to add a suffix, therefore
    # two variants of ghdl (e.g. mcode and gcc) overwrite each other.
    cp ghdl_mcode ghdl_mcode-mcode
    make install EXEEXT='-mcode'
    
    popd > /dev/null
}

function build_llvm {
    mkdir -p 'build_llvm'
    pushd 'build_llvm' > /dev/null
    
    if [ $INSTALL = true ]; then
        if [ "$INSTALL_PREFIX" == "default" ]; then
            INSTALL_PREFIX="$DEFAULT_PREFIX"
        fi
    else
        INSTALL_PREFIX="$(pwd -P)/build"
    fi

    # compile latest libbacktrace.a to compile ghdl-llvm with stack backtrace support
    if [ ! -d './libbacktrace' ]; then
        git clone --recursive "$REPO_LIBBACKTRACE" 'libbacktrace'
    fi
    
    # build libbacktrace
    pushd 'libbacktrace' > /dev/null
    ./configure
    make -j$(nproc)
    local L_LIBBACKTRACE_PATH="$(pwd -P)/.libs/libbacktrace.a"
    popd > /dev/null
    
    # build ghdl-llvm
    ../configure $BUILD_YOSYS_PLUGIN --with-llvm-config --with-backtrace-lib="$L_LIBBACKTRACE_PATH" --prefix="$INSTALL_PREFIX"
    make -j$(nproc)
    
    # ugly workarround: makefile offers no option to add a suffix, therefore
    # two variants of ghdl (e.g. mcode and gcc) overwrite each other.
    cp ghdl_llvm ghdl_llvm-llvm
    make install EXEEXT='-llvm'
    popd > /dev/null
}

function build_gcc {
    # download GCC sources
    if [ ! -d 'gcc' ]; then
        git clone --recursive "$REPO_GCC" 'gcc'
    fi
    
    # checkout latest release and build prerequisites
    pushd 'gcc' > /dev/null
    local L_GCC_SRC_PATH=`pwd -P`
    select_and_get_project_version 'stable' 'THROWAWAY_VAR' 'releases/*'
    ./contrib/download_prerequisites
    popd > /dev/null
    # configure ghdl-gcc
    mkdir -p 'build_gcc'
    pushd 'build_gcc' > /dev/null
    
    if [ $INSTALL = true ]; then
        if [ "$INSTALL_PREFIX" == "default" ]; then
            INSTALL_PREFIX="$DEFAULT_PREFIX"
        fi
    else
        INSTALL_PREFIX="$(pwd -P)/build"
    fi
    
    ../configure $BUILD_YOSYS_PLUGIN --with-gcc="$L_GCC_SRC_PATH" --prefix="$INSTALL_PREFIX"
    local L_GCC_CONFIG="--prefix=${INSTALL_PREFIX}"
    
    make -j$(nproc) copy-sources
    mkdir -p 'gcc-objs'
    pushd 'gcc-objs' > /dev/null
    
    # check if the gcc used to compile ghdl-gcc uses default pie
    if [ `gcc -v 2>&1 | grep -c -- "--enable-default-pie"` -gt 0 ]; then
        L_GCC_CONFIG="${L_GCC_CONFIG} --enable-default-pie"
    fi
    
    # compile gcc
    $L_GCC_SRC_PATH/configure $L_GCC_CONFIG $BUILD_GCC_DEFAULT_CONFIG
    make -j$(nproc)
    make install
    popd > /dev/null
    # compile ghdl
    make -j$(nproc) ghdllib
    make install
    popd > /dev/null
}


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

# invalid configuration
if [ $BUILD_MCODE = false ] && [ $BUILD_LLVM = false ] && [ $BUILD_GCC = false ]; then
    echo -e "${RED}ERROR: Invalid configuration (at least one of -m, -l and -g must be specified)${NC}"
    exit 2
fi

# load shared functions
source $LIBRARY

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
if [ $BUILD_MCODE = true ]; then
    build_mcode
    PLUGIN_VARIANT='ghdl-mcode'
fi
if [ $BUILD_LLVM = true ]; then
    build_llvm
    PLUGIN_VARIANT='ghdl-llvm'
fi
if [ $BUILD_GCC = true ]; then
    build_gcc
    PLUGIN_VARIANT='ghdl'
fi

# build ghdl plugin for yosys if wanted
if [ -n "$BUILD_YOSYS_PLUGIN" ]; then
    # clone
    if [ ! -d "$PROJ_GHDL_YOSYS_PLUGIN" ]; then
        git clone --recursive "$REPO_GHDL_YOSYS_PLUGIN" "${PROJ_GHDL_YOSYS_PLUGIN%%/*}"
    fi

    pushd $PROJ_GHDL_YOSYS_PLUGIN > /dev/null
    
    # build
    GHDL="${INSTALL_PREFIX}/bin/${PLUGIN_VARIANT}"
    make -j$(nproc) GHDL="$GHDL"
    
    # install
    make install GHDL="$GHDL"
fi

# return to first folder and store version
pushd -0 > /dev/null
echo "${PROJ##*/}: $COMMIT_HASH" >> "$VERSIONFILE"

# cleanup if wanted
if [ $CLEANUP = true ]; then
    rm -rf $BUILDFOLDER
fi

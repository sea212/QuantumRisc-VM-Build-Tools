#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jul. 02 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
LIBRARY="../libraries/library.sh"
REPO="https://github.com/riscv/riscv-gnu-toolchain.git"
PROJ="riscv-gnu-toolchain"
BUILDFOLDER="build_and_install_riscv_gnu_toolchain"
VERSIONFILE="installed_version.txt"
TOOLCHAIN_SUFFIX="linux-multilib"
TAG="latest"
NEWLIB=false
# INSTALL=false
INSTALL_PATH="/opt/riscv"
PROFILE_PATH="/etc/profile"
CLEANUP=false
EXPORTPATH=false

VERSION_FILE_NAME="versions.cfg"
VERSION_FILE='## Define sourcecode branch
# default = use predefined versions from current riscv-gnu-toolchain branch
# or any arbitrary git tag or commit hash
# note that in most projects there is no master branch
QEMU=default
RISCV_BINUTILS=default
RISCV_DEJAGNU=default
RISCV_GCC=default
RISCV_GDB=default
RISCV_GLIBC=default
RISCV_NEWLIB=default

## Define which RiscV architectures and ABIs are supported (space seperated list "arch-abi")

# Taken from Sifive:
# https://github.com/sifive/freedom-tools/blob/120fa4d48815fc9e87c59374c499849934f2ce10/Makefile
NEWLIB_MULTILIBS_GEN="\
    rv32e-ilp32e--c \
    rv32ea-ilp32e--m \
    rv32em-ilp32e--c \
    rv32eac-ilp32e-- \
    rv32emac-ilp32e-- \
    rv32i-ilp32--c,f,fc,fd,fdc \
    rv32ia-ilp32-rv32ima,rv32iaf,rv32imaf,rv32iafd,rv32imafd- \
    rv32im-ilp32--c,f,fc,fd,fdc \
    rv32iac-ilp32--f,fd \
    rv32imac-ilp32-rv32imafc,rv32imafdc- \
    rv32if-ilp32f--c,d,dc \
    rv32iaf-ilp32f--c,d,dc \
    rv32imf-ilp32f--d \
    rv32imaf-ilp32f-rv32imafd- \
    rv32imfc-ilp32f--d \
    rv32imafc-ilp32f-rv32imafdc- \
    rv32ifd-ilp32d--c \
    rv32imfd-ilp32d--c \
    rv32iafd-ilp32d-rv32imafd,rv32iafdc- \
    rv32imafdc-ilp32d-- \
    rv64i-lp64--c,f,fc,fd,fdc \
    rv64ia-lp64-rv64ima,rv64iaf,rv64imaf,rv64iafd,rv64imafd- \
    rv64im-lp64--c,f,fc,fd,fdc \
    rv64iac-lp64--f,fd \
    rv64imac-lp64-rv64imafc,rv64imafdc- \
    rv64if-lp64f--c,d,dc \
    rv64iaf-lp64f--c,d,dc \
    rv64imf-lp64f--d \
    rv64imaf-lp64f-rv64imafd- \
    rv64imfc-lp64f--d \
    rv64imafc-lp64f-rv64imafdc- \
    rv64ifd-lp64d--c \
    rv64imfd-lp64d--c \
    rv64iafd-lp64d-rv64imafd,rv64iafdc- \
    rv64imafdc-lp64d--"


# Linux install (cross-compile for linux)
# Default value from riscv-gcc repository
GLIBC_MULTILIBS_GEN="\
    rv32imac-ilp32-rv32ima,rv32imaf,rv32imafd,rv32imafc,rv32imafdc- \
    rv32imafdc-ilp32d-rv32imafd- \
    rv64imac-lp64-rv64ima,rv64imaf,rv64imafd,rv64imafc,rv64imafdc- \
    rv64imafdc-lp64d-rv64imafd-"'


# parse arguments
USAGE="$(basename "$0") [-h] [-c] [-n] [-d dir] [-t tag] [-u user] [-p path] -- Clone latested ${PROJ} version and build it. Optionally select compiler (buildtool), build directory and version, install binaries and cleanup setup files.

where:
    -h          show this help text
    -c          cleanup project
    -n          use \"newlib multilib\" instead of \"linux multilib\" cross-compiler
    -e          extend PATH in by RiscV binary path (default: /etc/profile)
    -d dir      build files in \"dir\" (default: ${BUILDFOLDER})
    -t tag      specify version (git tag or commit hash) to pull (default: default branch)
    -u user     install RiscV tools for user \"user\". (default: install globally)
    -p path     choose install path (default: /opt/riscv)"

while getopts ':hcend:t:u:p:' OPTION; do
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
        e)  EXPORTPATH=true
            echo "-e set: Extending PATH by RiscV binary path"
            ;;
        n)  echo "-n set: Using newlib cross-compiler"
            NEWLIB=true
            TOOLCHAIN_SUFFIX="newlib-multilib"
            ;;
        d)  echo "-d set: Using folder $OPTARG"
            BUILDFOLDER="$OPTARG"
            ;;
        t)  echo "-t set: Using version $OPTARG"
            TAG="$OPTARG"
            ;;
        p)  echo "-p set: Using install path $OPTARG"
            INSTALL_PATH="$OPTARG"
            ;;
        u)  echo "-u set: Installing for user $OPTARG"
            PROFILE_PATH="$(grep $OPTARG /etc/passwd | cut -d ":" -f6)/.profile"
            
            if [ ! -f "$PROFILE_PATH" ]; then
                echo -e "${RED}ERROR: No .profile file found for user \"${OPTARG}\"${NC}" >&2
                exit 1;
            fi
            ;;
        :)  echo -e "${RED}ERROR: missing argument for -${OPTARG}\n${NC}" >&2
            echo "$USAGE" >&2
            exit 1
            ;;
       \?)  echo -e "${RED}ERROR: illegal option: -${OPTARG}\n${NC}" >&2
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

# cleanup files if the programm was shutdown unexpectedly
trap 'echo -e "${RED}ERROR: Script was terminated unexpectedly, cleaning up files..." >&2 && pushd -0 > /dev/null && rm -rf $BUILDFOLDER' INT TERM

# load shared functions
source $LIBRARY

# does the config exist?
if [ ! -f "$VERSION_FILE_NAME" ]; then
    echo -e "${RED}Warning: No version.cfg file found. Generating file and using default versions${NC}";
    echo "$VERSION_FILE" > "$VERSION_FILE_NAME"
fi

source "$VERSION_FILE_NAME"
CFG_LOCATION=`pwd -P`

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
VERSIONLIST="RiscV-GNU-Toolchain-${TOOLCHAIN_SUFFIX}: $COMMIT_HASH"

# fetch versions for all subrepos (as specified in versions.cfg)
while read LINE; do
    if [ -n "$LINE" ] && [ "${LINE:0:1}" != "#" ]; then
        SUBREPO=`echo "$LINE" | sed "s/[=].*$//"`
        if [ -n "${!SUBREPO}" ]; then
            SUBREPO_LOWER=`echo "$SUBREPO" | tr [A-Z,_] [a-z,-]`
            if [ -d "$SUBREPO_LOWER" ]; then
                pushd $SUBREPO_LOWER > /dev/null
                
                if [ "${!SUBREPO}" != "default" ]; then
                    git checkout --recurse-submodules ${!SUBREPO}
                fi
                
                SUBREPO_COMMIT_HASH="$(git rev-parse HEAD)"
                         
                # set return value to tag name if available
                # we have to cheat here: Since riscv-collaborators used branch names instead
                # of tag names (why?!), we have to check both and hack the version a bit to
                # indicate that.
                POSSIBLE_TAGS=`git tag --points-at $SUBREPO_COMMIT_HASH`
                
                if [ -n "$POSSIBLE_TAGS" ]; then
                    SUBREPO_COMMIT_HASH="${POSSIBLE_TAGS%%[$'\n']*}"
                else
                    # check branches
                    POSSIBLE_BRANCHES=`git branch -r --points-at $SUBREPO_COMMIT_HASH`
                    if [ -n "$POSSIBLE_BRANCHES" ]; then
                        ONE_BRANCH="${POSSIBLE_BRANCHES%%[$'\n']*}"
                        # this is hacky. Extracts the number and anything after the number
                        # matching the the pattern d.d, where d is an arbitrary long number
                        SUBREPO_COMMIT_HASH="$(echo "$ONE_BRANCH" | grep -Po '\d+\.\d+.*') (${SUBREPO_COMMIT_HASH})"
                    fi
                fi
                
                popd > /dev/null
                VERSIONLIST="${VERSIONLIST}\n${SUBREPO_LOWER}-${TOOLCHAIN_SUFFIX}: ${SUBREPO_COMMIT_HASH}"
            fi
        fi
    fi
done < "${CFG_LOCATION}/${VERSION_FILE_NAME}"


pushd -0 > /dev/null
echo -e "$VERSIONLIST" >> "$VERSIONFILE"

# cleanup if wanted
if [ $CLEANUP = true ]; then
    rm -rf $BUILDFOLDER
fi


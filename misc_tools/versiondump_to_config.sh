#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jan. 22 2021
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>


RED='\033[1;31m'
NC='\033[0m'

# parse arguments
USAGE="$(basename "$0") [-h] versionfile configfile outputfile - adjust configfile to contain fixed tool versions as specified in versionfile (the file that is created by install_everything.sh) and store it as outputfile. The tool does not yet support the creation of version files for sub repositories, like in RiscV-GNU-Toolchain.

where:
    -h          show this help text"

while getopts ':h' OPTION; do
    case "$OPTION" in
        h)  echo "$USAGE"
            exit
            ;;
        \?) echo -e "${RED}ERROR: illegal option: -${OPTARG}\n${NC}" >&2
            echo "$USAGE" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# exit when any command fails
set -e

# argument count
if [ $# -ne 3 ]; then
    echo -e "${RED}ERROR: invalid argument count${NC}"
    echo "$USAGE"
    exit 1
fi

VERSIONFILE=$1
CONFIGFILE=$2
OUTPUTFILE=$3

# check that input files exist
for IFILE in "$VERSIONFILE" "$CONFIGFILE"; do
    if [ ! -f "$IFILE" ]; then
        echo -e "${RED}ERROR: ${IFILE} does not exist.${NC}"
        exit 1
    fi
done

# mapping: all tool names in the version file that DO NOT match to the tool name in the config file are mapped here (versionfile_toolname -> configfile_toolname)
LIBTRELLIS='TRELLIS'
GTKWAVE3_GTK3='GTKWAVE'
RISCV_GNU_TOOLCHAIN_NEWLIB_MULTILIB='RISCV_NEWLIB'
RISCV_GNU_TOOLCHAIN_LINUX_MULTILIB='RISCV_LINUX'
IVERILOG='ICARUSVERILOG'

# blacklist: tools that do not allow configuration of version
BLACKLIST=('RUSTC' 'COCOTB' 'SPINALHDL')

if [ -f "$OUTPUTFILE" ]; then
    echo -e "${RED}WARNING${NC}: ${OUTPUTFILE} already exists. Overwrite? (y/n): \c"
    read -n 1 ANS && echo -e "\n"
    
    if [ "$ANS" != 'y' ]; then
        exit 0
    fi
fi

cp "$CONFIGFILE" "$OUTPUTFILE"
unset CONFIGFILE

while IFS= read -r LINE; do
    TNAME_FILTER1="${LINE%%:*}" # extract tool name 1 (before :)
    TNAME_FILTER2="${TNAME_FILTER1%% *}" # extract tool name 2 (before space)
    TNAME_FILTER3="${TNAME_FILTER2^^}" # to upper case
    TNAME="${TNAME_FILTER3//-/_}" # - to _
    TVERSION="${LINE##*: }"
    
    # tool blacklisted (version not configurable)?
    for BITEM in "${BLACKLIST[@]}"; do
        if [ "$BITEM" == "$TNAME" ]; then
            continue
        fi
    done
    
    # change version dump toolname to config tool name
    if [ -n "${!TNAME}" ]; then
        TNAME="${!TNAME}"
    fi
    
    # adjust tool version in target file
    sed -i "s/${TNAME}_TAG.*/${TNAME}_TAG=${TVERSION}/" "$OUTPUTFILE" 
done < "$VERSIONFILE"

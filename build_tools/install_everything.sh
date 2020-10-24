#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jul. 23 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
LIBRARY="libraries/library.sh"
CONFIG="config.cfg"
BUILDFOLDER="build_and_install_quantumrisc_tools"
VERSIONFILE="installed_version.txt"
SUCCESS_FILE_TOOLS="latest_success_tools.txt"
SUCCESS_FILE_PROJECTS="latest_success_projects.txt"
DIALOUT_USERS=default
VERSION_FILE_USERS=default
CLEANUP=false
VERBOSE=false
SCRIPTS="YOSYS TRELLIS ICESTORM NEXTPNR_ICE40 NEXTPNR_ECP5 UJPROG OPENOCD \
OPENOCD_VEXRISCV VERILATOR GTKTERM GTKWAVE RISCV_NEWLIB RISCV_LINUX FUJPROG \
SPINALHDL ICARUSVERILOG"
PROJECTS="PQRISCV_VEXRISCV DEMO_PROJECT_ICE40"


# parse arguments
USAGE="$(basename "$0") [-c] [-h] [-o] [-p] [-v] [-d dir] -- Build and install QuantumRisc toolchain.

where:
    -c          cleanup, delete everything after successful execution
    -h          show this help text
    -o          space seperated list of users who shall be added to dialout
                (default: every logged in user)
    -p          space seperated list of users for whom the version file shall
                be copied to the desktop (default: every logged in user)
    -v          be verbose (spams the terminal)
    -d dir      build files in \"dir\" (default: ${BUILDFOLDER})"

while getopts ':chopvd:' OPTION; do
    case "$OPTION" in
        c)  echo "-c set: Cleaning up everything in the end"
            CLEANUP=true
            ;;
        d)  echo "-d set: Using folder $OPTARG"
            BUILDFOLDER="$OPTARG"
            ;;
        h)  echo "$USAGE"
            exit
            ;;
        o)  echo "-o set: Adding users \"${OPTARG}\" to dialout"
            DIALOUT_USERS="$OPTARG"
            ;;
        p)  echo "-o set: Copying version file to desktop of \"${OPTARG}\""
            VERSION_FILE_USERS="$OPTARG"
            ;;
        v)  echo "-v set: Being verbose"
            VERBOSE=true
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

# load shared functions
source $LIBRARY

# Read config
echo_verbose "Loading configuration file"
source config.cfg

# create and cd into buildfolder
if [ ! -d $BUILDFOLDER ]; then
    echo_verbose "Creating build folder \"${BUILDFOLDER}\""
    mkdir $BUILDFOLDER
fi

cp -r install_build_essentials.sh $BUILDFOLDER
pushd $BUILDFOLDER > /dev/null
ERROR_FILE="$(pwd -P)/errors.log"

# Potentially create and empty errors.log file
echo '' > errors.log
echo "Executing: ./install_build_essentials.sh"
exec_verbose "./install_build_essentials.sh" "$ERROR_FILE"

# Cleanup files if the programm was shutdown unexpectedly
# trap 'echo -e "${RED}ERROR: Script was terminated unexpectedly, cleaning up files..." && pushd -0 > /dev/null && rm -rf $BUILDFOLDER' INT TERM

echo -e "\n--- Installing tools ---\n"
get_latest "$SCRIPTS" "$SUCCESS_FILE_TOOLS" "tool" "SCRIPTS"

# Process scripts
for SCRIPT in $SCRIPTS; do
    # Should the tool be build/installed?
    if [ "${!SCRIPT}" = true ]; then
        echo "Installing $SCRIPT"
        PARAMETERS=""
        parameters_tool "$SCRIPT" "PARAMETERS"
        COMMAND_INSTALL_ESSENTIALS=""
        COMMAND_INSTALL=""
        find_script "$SCRIPT" "COMMAND_INSTALL_ESSENTIALS" "COMMAND_INSTALL"
        
        # Execute any file that is available
        # build essentials
        if [ -f "$COMMAND_INSTALL_ESSENTIALS" ]; then
            echo "Executing: $COMMAND_INSTALL_ESSENTIALS"
            exec_verbose "$COMMAND_INSTALL_ESSENTIALS" "$ERROR_FILE"
        else
            echo -e "Warning: ${COMMAND_INSTALL_ESSENTIALS##*/} not found"
        fi
        
        # tool install script
        if [ -f "$COMMAND_INSTALL" ]; then
            echo "Executing: ${COMMAND_INSTALL} ${PARAMETERS}"
            exec_verbose "${COMMAND_INSTALL} ${PARAMETERS}" "$ERROR_FILE"
            echo "$SCRIPT" > $SUCCESS_FILE_TOOLS
        else
            echo -e "Warning: ${COMMAND_INSTALL##*/} not found"
        fi
    fi
done


echo -e "\n--- Setting up projects ---\n"
get_latest "$PROJECTS" "$SUCCESS_FILE_PROJECTS" "project" "PROJECTS"

for PROJECT in $PROJECTS; do
    if [ "${!PROJECT}" = true ]; then
        echo "Setting up $PROJECT"
        install_project "$PROJECT"
        echo "$PROJECT" > $SUCCESS_FILE_PROJECTS
    fi
done

# secure version file before it gets deleted (-c)
pushd -0 > /dev/null

if [ -f "${BUILDFOLDER}/${VERSIONFILE}" ]; then
    cp "${BUILDFOLDER}/${VERSIONFILE}" .
fi

# add users to dialout
if [ "$DIALOUT_USERS" == "default" ]; then
    for DIALOUT_USER in `who | cut -d' ' -f1`; do
        usermod -a -G dialout "$DIALOUT_USER"
    done
else
    for DIALOUT_USER in "$DIALOUT_USERS"; do
        usermod -a -G dialout "$DIALOUT_USER"
    done
fi

# copy version file to users desktop
if [ "$VERSION_FILE_USERS" == "default" ]; then
    copy_version_file "$(pwd -P)/${VERSIONFILE}" `who | cut -d' ' -f1`
else
    copy_version_file "$(pwd -P)/${VERSIONFILE}" "$VERSION_FILE_USERS"
fi

# cleanup
if [ $CLEANUP = true ]; then
    echo_verbose "Cleaning up files"
    rm -rf $BUILDFOLDER
fi

echo "Script finished successfully."

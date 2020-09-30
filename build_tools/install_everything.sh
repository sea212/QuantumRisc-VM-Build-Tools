#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Jul. 23 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# constants
RED='\033[1;31m'
NC='\033[0m'
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
OPENOCD_VEXRISCV VERILATOR GTKWAVE RISCV_NEWLIB RISCV_LINUX"
PROJECTS="PQRISCV_VEXRISCV DEMO_PROJECT"


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

# Prints only if verbose is set
function echo_verbose {
    if [ $VERBOSE = true ]; then
        echo "$1"
    fi
}

# Prints only errors from executed commands if verbose is set
# Parameter $1: Command to execute
# Parameter $2: Path to error file
function exec_verbose {
    if [ $VERBOSE = false ]; then
        $1 > /dev/null 2>> "$2"
    else
        $1 2>> "$2"
    fi
}

# Read latest executed tool/project/etc.
# Parameter $1: tool/project/etc. list
# Parameter $2: success file
# Parameter $3: string containing list element type (tool/project/etc.)
# Parameter $4: Return variable name
function get_latest {
    if [ ! -f "$2" ]; then
        return 0
    fi
    
    local LATEST_SCRIPT=`cat $2`
    local SCRIPTS_ADAPTED=`echo "$1" | sed "s/.*${LATEST_SCRIPT} //"`
    
    if [ "$SCRIPTS_ADAPTED" == "$1" ]; then
        local AT_END=true
        echo -e "\nThe script detected a checkpoint after the last ${3}. This means that all ${3}s already have been checked and installed if configured that way. Do you want to check every ${3} and install them again if configured that way (y/n)?"
    else
        local AT_END=false
        echo -e "\nThe script detected a checkpoint. Do you want to install every ${3} from the checkpoint onwards (y) if configured that way or do you want to start over from the beginning (n)?"
        echo "${3}s yet to be check for installation after the checkpoint: $SCRIPTS_ADAPTED"
    fi
    
    local DECISION="z"

    while [ $DECISION != "n" ] && [ $DECISION != "y" ]; do
        read -p "Decision(y/n): " DECISION
        
        if [ -z $DECISION ]; then
            DECISION="z"
        fi
    done
    
    echo -e "\n"
    
    if [ $DECISION == "n" ]; then
        if [ $AT_END = true ]; then
            eval "$4=\"\""
        fi
    else
        eval "$4=\"$SCRIPTS_ADAPTED\""
    fi
}

# Process riscv_gnu_toolchain script parameters
# Parameter $1: Script name
# Parameter $2: Variable to store the parameters in
# Returns parameter string in variable SCRIPT_PARAMETERS
function parameters_tool_riscv {
    # set -n flag
    if [ "${1:6}" == "NEWLIB" ]; then
        eval "$2=\"${!2} -n\""
    fi
    
    # Set "e" parameter
    if [ "$(eval "echo $`echo $1`_EXTEND_PATH")" = true ]; then
        eval "$2=\"${!2} -e\""
    fi
    
    # set "u" parameter
    local L_BUILD_USER="$(eval "echo $`echo $1`_USER")"
    
    if [ -n "$L_BUILD_USER" ] && [ "$L_BUILD_USER" != "default" ]; then
        eval "$2=\"${!2} -u \"$L_BUILD_USER\"\""
    fi
    
    # set "p" parameter
    local L_BUILD_INSTALL_PATH="$(eval "echo $`echo $1`_INSTALL_PATH")"
    
    if [ -n "$L_BUILD_INSTALL_PATH" ] && [ "$L_BUILD_INSTALL_PATH" != "default" ]; then
        eval "$2=\"${!2} -p \"$L_BUILD_INSTALL_PATH\"\""
    fi
}

# Process nextpnr script parameters
# Parameter $1: Script name
# Parameter $2: Variable to store the parameters in
# Returns parameter string in variable SCRIPT_PARAMETERS
function parameters_tool_nextpnr {
    # set -e flag
    if [ "${1:8}" == "ECP5" ]; then
        eval "$2=\"${!2} -e\""
    fi
    
    local L_BUILD_CHIPDB="$(eval "echo $`echo $1`_CHIPDB_PATH")"
    
    if [ -n "$L_BUILD_CHIPDB" ] && [ "$L_BUILD_CHIPDB" != "default" ]; then
        eval "$2=\"${!2} -l \"$L_BUILD_CHIPDB\"\""
    fi
}

# Process common script parameters
# Parameter $1: Script name
# Parameter $2: Variable to store the parameters in
# Returns parameter string in variable SCRIPT_PARAMETERS
function parameters_tool {
    # Set "i" parameter
    if [ "$(eval "echo $`echo $1`_INSTALL")" = true ]; then
        eval "$2=\"${!2} -i $(eval "echo $`echo $1`_INSTALL_PATH")\""
    fi
    
    # Set "c" parameter
    if [ "$(eval "echo $`echo $1`_CLEANUP")" = true ]; then
        eval "$2=\"${!2} -c\""
    fi
    
    # Set "d" parameter
    local L_BUILD_DIR="$(eval "echo $`echo $1`_DIR")"
    
    if [ -n "$L_BUILD_DIR" ] && [ "$L_BUILD_DIR" != "default" ]; then
        eval "$2=\"${!2} -d \"$L_BUILD_DIR\"\""
    fi
    
    # Set "t" parameter
    local L_BUILD_TAG="$(eval "echo $`echo $1`_TAG")"
    
    if [ -n "$L_BUILD_TAG" ] && [ "$L_BUILD_TAG" != "default" ]; then
        eval "$2=\"${!2} -t \"$L_BUILD_TAG\"\""
    fi
    
    # Set "c" for Yosys only
    if [ $1 == "YOSYS" ]; then
        local L_BUILD_COMPILER="$(eval "echo $`echo $1`_COMPILER")"
        
        if [ -n "$L_BUILD_COMPILER" ]; then
            eval "$2=\"${!2} -b \"$L_BUILD_COMPILER\"\""
        fi
    fi
    
    # Append special parameters for gnu-riscv-toolchain and nextpnr variants
    if [ "${1::5}" == "RISCV" ]; then
        parameters_tool_riscv "$1" "$2"
    elif [ "${1::7}" == "NEXTPNR" ]; then
        parameters_tool_nextpnr "$1" "$2"
    fi
}

# Copies the project to documents and creates a symbolic link if desired
# Parameter $1: Project name
# Parameter $2: User name
# Parameter $3: Create symbolic link (bool)
function install_project_for_user {
    # Get user and home directory
    local L_USER_HOME=$(getent passwd "$2" | cut -d: -f6)
    
    # User not found
    if [ -z "$L_USER_HOME" ]; then
        echo -e "${RED}ERROR: User ${L_USER} does not exist (home directory not found).${NC}"
        exit 1;
    fi
    
    # Lookup Documents and Desktop and create if not existant
    local L_USER_DOCUMENTS="${L_USER_HOME}/Documents"
    local L_USER_DESKTOP="${L_USER_HOME}/Desktop"
    
    # TODO: Improve for multiple languages (currently only en support)
    if [ ! -d "${L_USER_DOCUMENTS}" ]; then
        mkdir $L_USER_DOCUMENTS
        chown -R ${L_USER}:$L_USER $L_USER_DOCUMENTS
    fi
    
    if [ ! -d "${L_USER_DESKTOP}" ]; then
        mkdir $L_USER_DESKTOP
        chown -R ${L_USER}:$L_USER $L_USER_DESKTOP
    fi
    
    # Copy project to Documents
    cp -r "$1" "$L_USER_DOCUMENTS"
    chown -R ${L_USER}:$L_USER "${L_USER_DOCUMENTS}/$1"
    
    # Create symbolic link if desired
    if [ "$3" = true ]; then
        ln -s "${L_USER_DOCUMENTS}/$1" "${L_USER_DESKTOP}/$1"
    fi
}

# Install project ("configure projects" section in config.cfg)
# Parameter $1: Project name
function install_project {
    if [ "${!1}" = false ]; then
        return 0
    fi
    
    local L_NAME_LOWER=`echo "$1" | tr [A-Z] [a-z]`
    
    # Clone
    if [ ! -d "$L_NAME_LOWER" ]; then
        exec_verbose "git clone --recurse-submodules ""$(eval "echo $`echo $1`_URL")"" ""$L_NAME_LOWER""" "$ERROR_FILE"
    fi
    
    # Checkout specified version
    local L_TAG="$(eval "echo $`echo $1`_TAG")"
    
    if [ "$L_TAG" != "default" ]; then
        pushd $L_NAME_LOWER > /dev/null
        exec_verbose "git checkout --recurse-submodules ""$L_TAG""" "$ERROR_FILE"
        popd > /dev/null
    fi
    
    local L_LINK="$(eval "echo $`echo $1`_LINK_TO_DESKTOP")"
    
    # Get users to install the projects for
    local L_USERLIST="$(eval "echo $`echo $1`_USER")"
    
    if [ "$L_USERLIST" == "default" ]; then
        for L_USER in `who | cut -d: -f1`; do
            install_project_for_user "$L_NAME_LOWER" "$L_USER" $L_LINK
        done
    else
        for L_USER in "$L_USERLIST"; do
            install_project_for_user "$L_NAME_LOWER" "$L_USER" $L_LINK
        done
    fi
    
    rm -rf "$L_NAME_LOWER"
}

# Moves script folder into build folder and returns script path
# Parameter $1: Script name
# Parameter $2: Variable to store the script path for requirements script in
# Parameter $3: Variable to store the script path for installation script in
function find_script {
    if [ "${SCRIPT::5}" == "RISCV" ]; then
        cp -r ../riscv_tools .
        eval "$2=\"$(pwd -P)/riscv_tools/install_riscv_essentials.sh\""
        eval "$3=\"$(pwd -P)/riscv_tools/install_riscv.sh\""
        cp "$(pwd -P)/riscv_tools/versions.cfg" .
    elif [ "${SCRIPT::7}" == "NEXTPNR" ]; then
        cp -r ../nextpnr .
        eval "$2=\"$(pwd -P)/nextpnr/install_nextpnr_essentials.sh\""
        eval "$3=\"$(pwd -P)/nextpnr/install_nextpnr.sh\""
    else
        local L_NAME_LOWER=`echo "$1" | tr [A-Z] [a-z]`
        cp -r ../${L_NAME_LOWER} .
        eval "$2=\"$(pwd -P)/${L_NAME_LOWER}/install_${L_NAME_LOWER}_essentials.sh\""
        eval "$3=\"$(pwd -P)/${L_NAME_LOWER}/install_${L_NAME_LOWER}.sh\""
        
        # TODO: Extend to automatically find all configuration files
        if [ -f "$(pwd -P)/${L_NAME_LOWER}/versions.cfg" ]; then
            cp "$(pwd -P)/${L_NAME_LOWER}/versions.cfg" .
        fi
    fi
}

# Copies version file $1 to the desktop of the users specified in $2
# Parameter $1: Version file path
# Parameter $2: User list
function copy_version_file {
    for L_USER in "$2"; do
        local L_VERSION_USER_DESKTOP="$(getent passwd "$L_USER" | cut -d: -f6)/Desktop"
        
        # TODO: add multiple language support
        if [ ! -d "$L_VERSION_USER_DESKTOP" ]; then
            mkdir "$L_VERSION_USER_DESKTOP"
        fi
        
        cp "$1" "$L_VERSION_USER_DESKTOP"
    done
}

# exit when any command fails
set -e

# require sudo
if [[ $UID != 0 ]]; then
    echo -e "${RED}Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

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
        COMMAND_INSTALL="${COMMAND_INSTALL} $PARAMETERS"
        echo "Executing: $COMMAND_INSTALL_ESSENTIALS"
        exec_verbose "$COMMAND_INSTALL_ESSENTIALS" "$ERROR_FILE"
        echo "Executing: $COMMAND_INSTALL"
        exec_verbose "$COMMAND_INSTALL" "$ERROR_FILE"
        echo "$SCRIPT" > $SUCCESS_FILE_TOOLS
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
cp "${BUILDFOLDER}/${VERSIONFILE}" .
# add users to dialout
if [ "$DIALOUT_USERS" == "default" ]; then
    for DIALOUT_USER in `who | cut -d: -f1`; do
        usermod -a -G dialout "$DIALOUT_USER"
    done
else
    for DIALOUT_USER in "$DIALOUT_USERS"; do
        usermod -a -G dialout "$DIALOUT_USER"
    done
fi

# copy version file to users desktop
if [ "$VERSION_FILE_USERS" == "default" ]; then
    copy_version_file "$(pwd -P)/${VERSIONFILE}" `who | cut -d: -f1`
else
    copy_version_file "$(pwd -P)/${VERSIONFILE}" "$VERSION_FILE_USERS"
fi

# cleanup
if [ $CLEANUP = true ]; then
    echo_verbose "Cleaning up files"
    rm -rf $BUILDFOLDER
fi

echo "Script finished successfully."

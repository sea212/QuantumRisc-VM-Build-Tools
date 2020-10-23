#!/bin/bash

# Author: Harald Heckmann <mail@haraldheckmann.de>
# Date: Oct. 22 2020
# Project: QuantumRisc (RheinMain University) <Steffen.Reith@hs-rm.de>

# This file contains functions that are shared by the build and install scripts.

# constants
RED='\033[1;31m'
NC='\033[0m'

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
            return 0
        else
            git checkout --recurse-submodules $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
            local L_COMMIT_HASH="$(git rev-parse HEAD)"
            >&2 echo -e "${RED}WARNING: No git tags found, using default branch${NC}"
        fi
    else
        # Either checkout default/stable branch or use custom commit hash, tag or branch name
        if [ "$1" == "default" ] || [ "$1" == "latest" ]; then
            git checkout --recurse-submodules $(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
        else
            # Check if $1 contains a valid tag and use it as the version if it does
            git checkout --recurse-submodules "$1"
        fi
        
        local L_COMMIT_HASH="$(git rev-parse HEAD)"
    fi
    
    # Set return value to tag name if available
    local L_POSSIBLE_TAGS=`git tag --points-at $L_COMMIT_HASH`
    
    if [ -n "$L_POSSIBLE_TAGS" ]; then
        L_COMMIT_HASH="${L_POSSIBLE_TAGS%%[$'\n']*}"
    fi
    
    # Apply return value
    eval "$2=\"$L_COMMIT_HASH\""
}

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
    
    # Set "b" for Yosys only
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
# Parameter $4: Project directory (where to copy it)
function install_project_for_user {
    local L_USER_HOME=$(getent passwd "$2" | cut -d: -f6)
    
    # User not found (link to desktop impossible)
    if [ $3 = true ] || [ "$4" == "default" ]; then
        if [ -z "$L_USER_HOME" ]; then
            echo -e "${RED}ERROR: User ${L_USER} does not exist (home directory not found).${NC}"
            exit 1;
        fi
    fi
    
    # Lookup Documents and Desktop and create if not existant
    if [ "$4" == "default" ]; then
        local L_DESTINATION="${L_USER_HOME}/Documents"
    else
        # Strip last possible "/" path
        if [ "${4: -1}" == "/" ]; then
            local L_DESTINATION="${4:: -1}"
        else
            local L_DESTINATION="$4"
        fi
    fi
    
    local L_PROJECT="$1"
    local L_USER="$2"
    
    # TODO: Improve for multiple languages (Documents / Desktop only in en)
    if [ ! -d "${L_DESTINATION}" ]; then
        mkdir "$L_DESTINATION"
        chown -R "${L_USER}:${L_USER}" "$L_DESTINATION"
    fi
    
    # Copy project
    cp -r "$L_PROJECT" "$L_DESTINATION"
    chown -R "${L_USER}:${L_USER}" "${L_DESTINATION}/${L_PROJECT}"
    
    # Create symbolic link to desktop if desired
    if [ $3 = true ]; then
        local L_USER_DESKTOP="${L_USER_HOME}/Desktop"
        
        if [ ! -d "${L_USER_DESKTOP}" ]; then
            mkdir "$L_USER_DESKTOP"
            chown -R "${L_USER}:${L_USER}" "$L_USER_DESKTOP"
        fi
        
        ln -s "${L_DESTINATION}/${L_PROJECT}" "${L_USER_DESKTOP}/${L_PROJECT}"
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
        exec_verbose "select_and_get_project_version ""$L_TAG"" ""L_COMMIT_HASH""" "$ERROR_FILE"
        popd > /dev/null
    fi
    
    local L_LINK="$(eval "echo $`echo $1`_LINK_TO_DESKTOP")"
    # Get users to install the projects for
    local L_USERLIST="$(eval "echo $`echo $1`_USER")"
    # Get project install location
    local L_INST_LOC="$(eval "echo $`echo $1`_LOCATION")"
    
    if [ "$L_USERLIST" == "default" ]; then
        for L_USER in `who | cut -d' ' -f1`; do
            install_project_for_user "$L_NAME_LOWER" "$L_USER" $L_LINK "$L_INST_LOC"
        done
    else
        for L_USER in "$L_USERLIST"; do
            install_project_for_user "$L_NAME_LOWER" "$L_USER" $L_LINK "$L_INST_LOC"
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
        local L_CFG_FILES=`find "$(pwd -P)/${L_NAME_LOWER}" -iname "*.cfg"`

        for CFG_FILE in $L_CFG_FILES; do
            cp "$CFG_FILE" .
        done
    fi
}

# Copies version file $1 to the desktop of the users specified in $2
# Parameter $1: Version file path
# Parameter $2: User list
function copy_version_file {
    if [ ! -f "$1" ]; then
        return
    fi
    
    for L_USER in "$2"; do
        local L_VERSION_USER_DESKTOP="$(getent passwd "$L_USER" | cut -d: -f6)/Desktop"
        
        # TODO: add multiple language support
        if [ ! -d "$L_VERSION_USER_DESKTOP" ]; then
            mkdir "$L_VERSION_USER_DESKTOP"
        fi
        
        cp "$1" "$L_VERSION_USER_DESKTOP"
    done
}

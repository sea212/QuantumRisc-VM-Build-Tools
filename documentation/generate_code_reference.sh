#!/bin/bash

# Relative path starting from docs/source
SCRIPT_BASE_FOLDER="../../build_tools"

RST_FILE_NAME="script_and_configuration_index.rst"

# Templates for contents within the documentation
# TODO: Add reference names 
REFERENCE_CONTENTS=".. highlight:: sh

Script and configuration index
==============================
.. empty
"

# TODO: Fix heading underline symbol count
EVAL_FOLDER_TEMPLATE="printf \"\\n\\r
.. _script-\${FOLDERNAME}:\\n\\r
\${FOLDERNAME}
\"
printf '\"-\"%.0s' \$(eval echo {1..\$(expr length \${FOLDERNAME})})
printf '
.. empty
\\r'"

EVAL_CONTENT_TEMPLATE="printf \"\\n\\r
.. _script-\${FOLDERNAME##*/}-\${FILENAME}:\\n\\r
\${FILENAME}
\"
printf '^%.0s' \$(eval echo {1..\$(expr length \${FILENAME})})
printf \"
.. literalinclude:: \${FOLDERNAME}/\${FILENAME}
    :linenos:
\\r\""

# Get current directory name without the complete path
# Parameter 1: Return variable name
# Returns directory name in parameter 1
# https://stackoverflow.com/a/1371283
function get_current_dirname {
    eval "$1=\"${PWD##*/}\""
}

# Get shell scripts in current directory
# Parameter 1: Return variable name
# Returns space separated list of shell scripts in parameter 1
function get_shell_scripts {
    eval "$1=\"$(find . -maxdepth 1 -name '*.sh' | sed 's/.\///')\""
}

# Get config files in current directory
# Parameter 1: Return variable name
# Returns space separated list of config files in parameter 1
function get_config_files {
    eval "$1=\"$(find . -maxdepth 1 -name '*.cfg' | sed 's/.\///')\""
}

# Assemble the section for one tool
# Parameter 1: Base folder
# Parameter 2: Tool directory name (optimally tool name)
# Parameter 3: Space separated list of scripts
# Parameter 4: Space separated list of config files
# Parameter 5: Return variable name
# Returns rst source code for one tool section in parameter 5
function assemble_section {
    # Prepare script section
    local FOLDERNAME="$2"
    local L_SNIPPET=`eval "$EVAL_FOLDER_TEMPLATE"`
    eval "$5=\"${L_SNIPPET}\""
    local FOLDERNAME="$1/$2"
    
    # Append scripts
    for FILENAME in $3; do
        L_SNIPPET=`eval "$EVAL_CONTENT_TEMPLATE"`
        eval "$5=\"${!5}${L_SNIPPET}\""
    done
    
    # Append configuration files
    for FILENAME in $4; do
        L_SNIPPET=`eval "$EVAL_CONTENT_TEMPLATE"`
        eval "$5=\"${!5}${L_SNIPPET}\""
    done
}

RST_FILE_CONTENTS="$REFERENCE_CONTENTS"

# Create base script section
pushd "source" > /dev/null
pushd "$SCRIPT_BASE_FOLDER" > /dev/null
get_current_dirname "CURDIR"
get_shell_scripts "SCRIPTS"
get_config_files "CONFIGS"
assemble_section "${SCRIPT_BASE_FOLDER%/*}" "$CURDIR" "$SCRIPTS" "$CONFIGS" "BT_CONTENTS"
RST_FILE_CONTENTS="${RST_FILE_CONTENTS}${BT_CONTENTS}"

# List all folders within the tools folder
FOLDERS=`find . -type d`

# Iterate over each folder (except the current folder)
for FOLDER in `echo ${FOLDERS#*.}`; do
    # Change to relevant folder
    pushd "$FOLDER" > /dev/null
    
    # Get relevant information
    get_current_dirname "CURDIR"
    get_shell_scripts "SCRIPTS"
    get_config_files "CONFIGS"
    
    # remove "./" from current folder path
    FOLDER_WITHOUT_CURDIR="${FOLDER:2}"
    
    # Assemble base folder
    BASE_FOLDER="${SCRIPT_BASE_FOLDER}/${FOLDER_WITHOUT_CURDIR}"
    
    # Append rst contents
    assemble_section "${BASE_FOLDER%/*}" "$CURDIR" "$SCRIPTS" "$CONFIGS" "BT_CONTENTS"
    RST_FILE_CONTENTS="${RST_FILE_CONTENTS}${BT_CONTENTS}"
    
    # Change back to tools folder
    popd > /dev/null
done

# Flush to file
pushd +1 > /dev/null
echo "$RST_FILE_CONTENTS" > "$RST_FILE_NAME"

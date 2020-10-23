.. highlight:: sh

Extending the install scripts
=============================

This section covers the most difficult task of this project: Extending the install scripts. Please read the chapter :doc:`direct_usage_of_the_scripts` and get familiar with the folder structure and scripts before we dive deep into the structure of the single scripts, the relationship of the scripts and configuration files and a workflow that allows usage of generic code patterns.


Single tool build and install script
------------------------------------

Inside the folder *build_tools* are many other folders, all named after a single tool or a collection of tools. Each of those folders contains at least 2 scripts and optionally configuration files. One script, *install_<toolname>_essentials.sh* does install all the required libraries to build the tools. The other script, *install_<toolname>.sh*, is a parametrisable fetch, configure, build and install script for <toolname>.


Extending a tool script
^^^^^^^^^^^^^^^^^^^^^^^

Since all of the tool build and install scripts are very similar, it should be sufficient to explain the structure using one specific example. In this section, we will use build_tools/verilator/:ref:`script-verilator` as an example. 

The easiest and probably most common extension is to add (new) missing dependencies. Refer to :ref:`missing_dependencies` to understand how this is done.

All the scripts follow a specific code structure. We will disassemble build_tools/verilator/:ref:`script-verilator-install_verilator.sh` to explain the code. If you want to understand how a complete script is structured and functioning, you can just go on with this section. Alternatively, you can select one specific segment of the code:

- :ref:`default-variable-initialization`
- :ref:`parameter-parsing`
- :ref:`function-section`
- :ref:`error-handling-and-superuser-privilege-enforcement`
- :ref:`tool-fetch-and-initialization`
- :ref:`configuration-and-build`
- :ref:`installation`
- :ref:`cleanup`

.. TODO: Add configuration file example (riscv_tools)

.. _missing_dependencies:

Missing dependencies
~~~~~~~~~~~~~~~~~~~~

Take a look at build_tools/verilator/:ref:`script-verilator-install_verilator_essentials.sh`::
    
    # require sudo
    if [[ $UID != 0 ]]; then
        echo "Please run this script with sudo:"
        echo "sudo $0 $*"
        exit 1
    fi

    # exit when any command fails
    set -e

    # required tools
    TOOLS="git perl python3 make g++ libfl2 libfl-dev zlibc zlib1g zlib1g-dev \
           ccache libgoogle-perftools-dev numactl git autoconf flex bison"

    # install and upgrade tools
    apt-get update
    apt-get install -y $TOOLS
    apt-get install --only-upgrade -y $TOOLS

This script is rather simple. It updates the apt cache, installs all packages specified within the *TOOLS* variable and upgrades all packages that were already installed and were therefore skipped during the installation. If you want to add new dependencies, extend the *TOOLS* variable by a space followed by the package name::

    # required tools
    TOOLS="git perl python3 make g++ libfl2 libfl-dev zlibc zlib1g zlib1g-dev \
           ccache libgoogle-perftools-dev numactl git autoconf flex bison MY-NEW-VALID-PACKAGE"

Be careful though that the package exists, otherwise APT will throw an error which in return will cancel the execution of the script.


.. _default-variable-initialization:

Default variable initialization
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Every tool build and install script begins with the initialization of default variables, which are either constant values or values that might be overwritten by a parameter that was passed with a flag during the invocation of the script. Take a look at the following default variable initialization section of build_tools/verilator/:ref:`script-verilator-install_verilator.sh`::
    
    RED='\033[1;31m'
    NC='\033[0m'
    REPO="https://github.com/verilator/verilator.git"
    PROJ="verilator"
    BUILDFOLDER="build_and_install_verilator"
    VERSIONFILE="installed_version.txt"
    TAG="latest"
    INSTALL=false
    INSTALL_PREFIX="default"
    CLEANUP=false
    
    USAGE="--snip--"

Currently constants and variables cannot be distinguished, it would be a good practice to add this information to the variable name in the future. This examples are the most common default variables. *RED*, *NC*, *REPO*, *PROJ*, *VERSIONFILE* and *USAGE* are constants. *RED* and *NC* are color codes, that allow you to color your console output red (*RED*) or to reset the color (*NC*). *REPO* contains the Git URL to the project. It's important that this URL begins with *https://*, otherwise the user must supply a key. *PROJ* contains the relevant folder. Most of the time it is just the project name, sometimes it is a path to a folder within the project, like in build_tools/gtkwave/:ref:`script-gtkwave-install_gtkwave.sh`. *VERSIONFILE* contains the name of the file the version number is written into. The major build_tools/:ref:`script-build_tools-install_everything.sh` script relies on the circumstance that all scripts use the same version filename, so it's best to never change this value and just to adapt it or change it in every single script altogether. *USAGE* contains a help string that can be printed when the program invocation was invalid.

*BUILDFOLDER*, *TAG*, *INSTALL*, *INSTALL_PATH* and *CLEANUP* are default variables that might be altered by parameters that were supplied during the invocation of the tool build and install script. If a parameter is not passed during invocation, the script uses the value that is assigned to the corresponding default variable during initialization. Check out :ref:`Tool build and install script parameters <tool-build-and-install-scripts-parameters>` to learn more about tool build and install script parameters.


.. _parameter-parsing:

Parameter parsing
~~~~~~~~~~~~~~~~~

The first functional action of the script is to parse arguments. Let's take a look how :ref:`script-verilator-install_verilator.sh` does that::

    while getopts ':hi:cd:t:' OPTION; do
        case $OPTION in
            i)  INSTALL=true
                INSTALL_PREFIX="$OPTARG"
                echo "-i set: Installing built binaries to $INSTALL_PREFIX"
                ;;
        esac
    done

    OPTIND=1


The script checks the flags and parameters two times, because some parameters have a causal connection (e.g. cleaning up freshly built files is only reasonable if those file already have been installed/copied). The code snippet above shows the first iteration. The scripts uses getopts to parse the flags and parameters. The getopts command takes at least two parameters: A string, in this case *':hi:cd:t:'*, containing all valid flags and the information whether they expect a parameter, and a variable name to stored the flag that is currently processed. The string containing the flags *':hi:cd:t:'* starts with a colon followed by flag letters and an optional colon after the flag letter. Every letter is a valid flag, every colon after the letter indicates that the flag is followed by a parameter. In a switch-case statement, every flag can be processed. The current parameter is stored in *$OPTARG*. After the flags have been processed, the 'flag pointer' *OPTIND* that indicates which flag is currently processed is reset to the first flag. After that the flags are parsed a second time::

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

It is important that both iterations use identical "flag strings", otherwise some flags might be ignored. One difference to the previous run of parsing flags is that two additional cases that do not represent a specific flag are used: *:* and *\\?*. The first one handles the case that a flag that requires a parameter was specified without one, the second one handles the case that a flag that is not contained in the "flag string" was passed. This is also the first output of an error messages we encounter in this section. It is printed in *RED* and redirected to stderr *>&2*. After the flags have been parsed, they are popped (removed) using the *shift* command.

.. _function-section:

Function section
~~~~~~~~~~~~~~~~

After the flag and parameters parsing section functions are defined. Common operations or complex operations are sourced out into functions. This increases the readability of the functional core section that configures, builds and installs the tool. Furthermore it increases the reusability in different context. Example::


    # This function does checkout the correct version and return the commit hash or tag name
    # Parameter 1: Branch name, commit hash, tag or one of the special keywords default/latest/stable
    # Parameter 2: Return variable name (commit hash or tag name)
    function select_and_get_project_version {
        # --snip--
    }

For someone who is not familiar with shell scripting it might be worth mentioning that a return value (other than a return code [int]) must be passed back to the caller using a parameter that contains the variable name to store the result in.


.. _error-handling-and-superuser-privilege-enforcement:

Error handling and superuser privilege enforcement
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After the function section behavior in error cases and superuser privilege enforcement are defined::

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
    
The error handling is straightforward: If an error occurs, stop the execution (*set -e*). Since the script sequentially executes interdependent steps, this approach seems fine. If the project could not be downloaded, the version can't be set, it can be configured, build or installed. If the version could not be checked out, it won't go on and build the tool, using a wrong version. If it can't be configured, there is no point in building it. If nothing was build, nothing is to be installed. Either the user has to fix the error by himself (for example specify a correct project version) or to contact the developers. If the script receives a *SIGINT* or *SIGTERM* signal, it stops the execution and deletes any file it created (*trap* command).

Only one command might requires superuser privileges (install), but to avoid that long-lasting scripts ask the user after an indefinite amount of time to enter superuser credentials, the script enforces superuser privileges (*$UID == 0*).


.. _tool-fetch-and-initialization:

Tool fetch and initialization
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The next snippet fetches the git project and checks out the specified version::

    # fetch specified version 
    if [ ! -d $BUILDFOLDER ]; then
        mkdir $BUILDFOLDER
    fi

    pushd $BUILDFOLDER > /dev/null

    if [ ! -d "$PROJ" ]; then
        git clone --recursive "$REPO"
    fi

    pushd $PROJ > /dev/null
    select_and_get_project_version "$TAG" "COMMIT_HASH"
    
First it creates a workspace by creating a folder name *$BUILDFOLDER*, which is controlled by the *-d* flag. This approach renders a simultaneous execution of multiple instances of the script possible, for example to build different versions at the same time. After that the directory is changed to the workspace. All the scripts use *pushd* and *popd*, which uses a rotatable directory stack to keep track of visited directories. The git project is fetched if the git project does not exist in the workspace yet. The *--recursive* flag is ignored if no submodules are existent, therefore it is supplied every time *git clone* is invoked. If submodules are added to the git project in the future, the script still remains functioning. At last the git project version is changed to *$TAG*, which is controlled by the *-t* flag. If it is a valid tag, it is stored in the variable *COMMIT_HASH*. If it is not, the commit hash is stored in *COMMIT_HASH*. This code block is highly flexible and can be used for most if not every git project.


.. _configuration-and-build:

Configuration and build
~~~~~~~~~~~~~~~~~~~~~~~

Next the project is configured and built, which is a part that differs from project to project::

    # build and install if wanted
    # unset var
    if [ -n "$BASH" ]; then
        unset VERILATOR_ROOT
    else
        unsetenv VERILATOR_ROOT
    fi

    autoconf

    if [ "$INSTALL_PREFIX" == "default" ]; then
        ./configure
    else
        ./configure --prefix="$INSTALL_PREFIX"
    fi

    make -j$(nproc)

This part of the script is basically a copy of different instructions from the build instruction of the tool in question that are weld together in a causally correct order. In this case the parameter within *INSTALL_PREFIX*, which is either a default value or the parameter of the *-i* flag, is specified. This can happen here or later, when the command that triggers the tool installation is executed. Be sure to always supply the *-j$(nproc)* flag to take full advantage of multi threading during the build process.


.. _installation:

Installation
~~~~~~~~~~~~

.. code-block::

    if [ $INSTALL = true ]; then
        make install
    fi
    
Here the tool is installed, depending on whether the *-i* flag was set. Sometimes the install location must be supplied here, this depends on the project. This is the only code segment that potentially requires superuser privileges.

.. _cleanup:

Cleanup
~~~~~~~

At the end of the project, irrelevant data can be removed::

    # return to first folder and store version
    pushd -0 > /dev/null
    echo "Verilator: $COMMIT_HASH" >> "$VERSIONFILE"

    # cleanup if wanted
    if [ $CLEANUP = true ]; then
        rm -rf $BUILDFOLDER
    fi
    
We make use of the directory stack here that comes with *pushd* and *popd*. By executing *pushd -0*, we rotate the oldest folder from the bottom to the top of the stack. Remember that the commit hash or tag was stored during the git project retrieval? At this point it is stored in a version file, which will be created at the root directory, more specifically the directory where the scripts are located. This is important if multiple people work on the same project (to ensure consistency regarding the tools) and for publications. The fully automatic and configurable tools and projects installation script, :ref:`script-build_tools-install_everything.sh`, collects all the tool versions in one single file. If the script was invoked with the *-c* flag, the workspace is removed completely.


Creating a tool script
^^^^^^^^^^^^^^^^^^^^^^

Creating a tool build and install script might be easier than you think right now. Most of the time it requires only minor adaption to one of the existing scripts to create a new fully functional tool build and install script. In most cases even the integration in the major tools and projects installation script (:ref:`script-build_tools-install_everything.sh`) only takes some minutes.


Step 1: Naming conventions
~~~~~~~~~~~~~~~~~~~~~~~~~~

The naming convention is very important, because the major tools and projects installation script (:ref:`script-build_tools-install_everything.sh`) uses them to find the scripts. Create a new folder in the build_tools directory which will contain the new scripts. You can give it any name, but for convenience reasons we suggest using the tool name or the collection name that are going to be installed. We'll use *<toolname>* as the name of the folder. The scripts within must be named *install_<toolname>.sh* and *install_<toolname>_essentials.sh*.


Step 2: Copying a template
~~~~~~~~~~~~~~~~~~~~~~~~~~

Copy the *build_tools/verilator/*:ref:`script-verilator-install_verilator.sh` and *build_tools/verilator/*:ref:`script-verilator-install_verilator_essentials.sh` scripts to your freshly created folder *build_tools/<toolname>*. After that replace *verilator* in the name of the scripts with *<toolname>*. If your *<toolname>* is *yosys* for example, the scripts should be named *install_yosys.sh* and *install_yosys_essentials.sh*


Step 3: Adjusting dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Lookup the dependencies on the project page and find appropriate packages in the apt packet manager. If you have a list of all dependencies, adjust the *install_<toolname>_essentials.sh* file to only install relevant apt packages, as described in section :ref:`missing_dependencies`


Step 4: Changing relevant constants
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The next step encompasses the adjustment of some constants. You can view all default variables and constants at section :ref:`default-variable-initialization`. You have to change the repository url, the folder where the relevant project lies and the default value for the build folder (workspace)::

    REPO="https://github.com/verilator/verilator.git"
    PROJ="verilator"
    BUILDFOLDER="build_and_install_verilator"
    
At this point, your script already can parse the default flags *-c*, *-d*, *-i* and *-t*, interpret them, create a workspace based on *-d*, download the correct git project and checkout the desired version based on *-t*.


Step 5: Adding additional flags
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. TODO: Replace reference for "adding new flags" to something more precise

Adding additional flags is not difficult by itself, however, if new flags are added, the major install script :ref:`script-build_tools-install_everything.sh` must be adjusted to process those new flags. Refer to section :ref:`extending-the-major-script` for more information. If you have to add additional flags, :ref:`parameter-parsing` elucidates how parameters are registered, received and handled.


Step 6: Adjusting the configure, build and install section
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Depending on the project, the build process is initialized and configured differently. Get to know how to configure and build the project and reflect that knowledge in the :ref:`configuration-and-build` segment of the script. At last, adjust the code segment that installs the project (:ref:`installation`).


Step 7: Adding the script to the major install script
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This last step includes the tool install script into the major install script :ref:`script-build_tools-install_everything.sh`. Besides potential adjustments of that script to incorporate new flags and parameters (id est any flags except *c*, *d*, *i* and *t*), the script must be registered in the major script and a config section must be created. Refer to section :ref:`adding-a-tool-to-major-script` to learn how this is done. After working through that section, you are done. You now have a fully functioning tool build and install script and it is integrated into the major install script, well done!


.. _extending-the-major-script:

Fully configurable tools and project installation script
--------------------------------------------------------

This section explains how the major install script build_tools/:ref:`script-build_tools-install_everything.sh` is structured and how to add tool build and install scripts and projects to it.


.. _adding-a-tool-to-major-script:

Adding a tool to the script
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Let's assume you have created a tool install script in *build_folder/<toolname>*. To add the script to the major install script, append *<TOOLNAME>* in uppercase to the following variable within the :ref:`script-build_tools-install_everything.sh` script::

    SCRIPTS="YOSYS TRELLIS ICESTORM NEXTPNR_ICE40 NEXTPNR_ECP5 UJPROG OPENOCD \
    OPENOCD_VEXRISCV VERILATOR GTKWAVE RISCV_NEWLIB RISCV_LINUX <TOOLNAME>"

After that, open the configuration file for the major install script, :ref:`script-build_tools-config.cfg`, and append the tool configuration section by a copy of the verilator configuration::

    ### Configure tools
    
    # --snip--
    
    ## Verilator
    # Build and (if desired) install Verilator?
    VERILATOR=true
    # Build AND install Verilator?
    VERILATOR_INSTALL=true
    # Install path (default = default path)
    VERILATOR_INSTALL_PATH=default
    # Remove build directory after successful install?
    VERILATOR_CLEANUP=true
    # Folder name in which the project is built
    VERILATOR_DIR=default
    # Specify project version to pull (default/latest, stable, tag, branch, hash)
    VERILATOR_TAG=default
    
now simply replace VERILATOR by *<TOOLNAME>* in uppercase and specify your desired default configuration::

    ### Configure tools
    
    # --snip--
    
    ## <Toolname>
    # Build and (if desired) install <Toolname>?
    <TOOLNAME>=true
    # Build AND install <Toolname>?
    <TOOLNAME>_INSTALL=true
    # Install path (default = default path)
    <TOOLNAME>_INSTALL_PATH=default
    # Remove build directory after successful install?
    <TOOLNAME>_CLEANUP=true
    # Folder name in which the project is built
    <TOOLNAME>_DIR=default
    # Specify project version to pull (default/latest, stable, tag, branch, hash)
    <TOOLNAME>_TAG=default


.. _additional_parameters:

Registering additional parameters
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In short, the configuration file build_tools/:ref:`script-build_tools-config.cfg` is *sourced*, which means that every variable within it is included in the current environment. Since you followed the naming convention and included the name of your tool in the *SCRIPTS* list, the variable names that were supplied in :ref:`script-build_tools-config.cfg` can be derived for the default configuration flags *-c*, *-d*, *-i* and *-t*. Let's take a look at the function that decides which flags and parameters are used based on the sourced :ref:`script-build_tools-config.cfg`::

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

Since every tool build and install script must follow the naming convention and support the default flags *-c*, *-d*, *-i* and *-t*, and in addition must supply the corresponding entries in :ref:`script-build_tools-config.cfg`, the script can just derive the variable name that was specified in :ref:`script-build_tools-config.cfg` and controls a specific flag.

Let's work through one example. You have added a tool called *MYTOOL* which support the four basic flags. In addition, you have added the configuration entry in :ref:`script-build_tools-config.cfg`::

    ## Mytool
    # Build and (if desired) install Mytool?
    MYTOOL=true
    # Build AND install Mytool?
    MYTOOL_INSTALL=true   
    # --snip--
    
At some point the :ref:`script-build_tools-install_everything.sh` script does source the configuration file, so all the variables within are now in the environment of the current instance of :ref:`script-build_tools-install_everything.sh`, including the configuration variables for *MYTOOL*. Now at some point the :ref:`script-build_tools-install_everything.sh` script must figure out which flags and parameters have to be set, which is done in the *parameters_tool* function in the code snippet above. The function is called like that: ``parameters_tool 'MYTOOL' 'RESULT'``. First it scans the configuration variables that control the common default flags, for example for *-i*::

    # Set "i" parameter
    if [ "$(eval "echo $`echo $1`_INSTALL")" = true ]; then
        eval "$2=\"${!2} -i $(eval "echo $`echo $1`_INSTALL_PATH")\""
    fi
    
In this example the variable *$1* contains our tool name, *MYTOOL*. Within the if-statement, the eval command ``"$(eval "echo $`echo $1`_INSTALL")"`` evaluates to ``"$MYTOOL_INSTALL"``. This is exactly the variable name we assigned in the configuration :ref:`script-build_tools-config.cfg` and which the script already sourced in its own environment. If the flag is set, the parameter list, which is stored in the variable name contained within *$2*, is appended by "-i $MYTOOL_INSTALL_PATH". This is repeated for every default value, which the scripts resolves to the variables *MYTOOL_CLEANUP*, *MYTOOL_BUILD_DIR* and *MYTOOL_TAG*.

If you want to add a custom parameter, let's assume *MYTOOL* does now allow a *-z* flag, which builds a specific feature, you have to add it to the configuration file :ref:`script-build_tools-config.cfg` and you have to write some custom code to handle that parameter in addition to the default parameters. You added a configuration variable::

    MYTOOL_NICE_FEATURE=true
    
Take a look at the end of the *parameters_tools* function::

    # Append special parameters for gnu-riscv-toolchain and nextpnr variants
    if [ "${1::5}" == "RISCV" ]; then
        parameters_tool_riscv "$1" "$2"
    elif [ "${1::7}" == "NEXTPNR" ]; then
        parameters_tool_nextpnr "$1" "$2"
    fi
    
For each tool that uses additional parameters, it calls a specific function that can handle those parameters. The ```${1::X}``` command reads the first X characters from the variable *$1*. It is only required if multiple tools with the same prefix use the same additional parameter function. In our case, it is sufficient to add another *elif* branch that compares the complete name::

    elif [ "$1" == "MYTOOL" ]; then
        parameters_tool_mytool "$1" "$2"
    fi
    
Create a new function *parameters_tool_mytool* that handles the additional parameters::

    # Process additional mytool script parameters
    # Parameter $1: Script name
    # Parameter $2: Variable to store the parameters in
    function parameters_tool_mytool {
        # set -z flag
        if [ "$(eval "echo $`echo $1`_NICE_FEATURE")" = true ]; then
            eval "$2=\"${!2} -z\""
        fi
    }

Just as for the other default flags, the if-statement checks the value of *MYTOOL_NICE_FEATURE* and appends the parameter string *$2* by *-z* if it is set to true. Congratulations, you have successfully added a custom parameters to the configuration.

Adding a project to the script
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To add a project to the major install script, two steps are required:

1. Copy and adapt an existing configuration for a project from :ref:`script-build_tools-config.cfg`
2. Add the project name to the *PROJECTS* variable in :ref:`script-build_tools-install_everything.sh`

Step 1: Open :ref:`script-build_tools-config.cfg` and duplicate the last project configuration, in this case it is *DEMO_PROJECT_ICE40*::

    ## Hello world demo application
    # Download git repository
    DEMO_PROJECT_ICE40=false
    # Git URL
    DEMO_PROJECT_ICE40_URL="https://github.com/ThorKn/icebreaker-vexriscv-helloworld.git"
    # Specify project version to pull (default/latest, stable, tag, branch, hash)
    DEMO_PROJECT_ICE40_TAG=default
    # If default is selected, the project is stored in the documents folder
    # of each user listed in the variable DEMO_PROJECT_ICE40_USER
    DEMO_PROJECT_ICE40_LOCATION=default
    # Space seperated list of users (in quotation marks) to install the project for
    # in /home/$user/Documents (if DEMO_PROJECT_ICE40_LOCATION=default). 
    # default = all logged in users. Linking to desktop is also based on this list.
    DEMO_PROJECT_ICE40_USER=default
    # Symbolic link to /home/$user/Desktop
    DEMO_PROJECT_ICE40_LINK_TO_DESKTOP=true
    
Replace DEMO_PROJECT with the project you want to add and adjust the configuration values as you desire::

    ## Hello world demo application
    # Download git repository
    <YOUR_PROJECT>=false
    # Git URL
    <YOUR_PROJECT>_URL="<YOUR_PROJECT_GIT_HTTPS_URL>"
    # Specify project version to pull (default/latest, stable, tag, branch, hash)
    <YOUR_PROJECT>_TAG=default
    # If default is selected, the project is stored in the documents folder
    # of each user listed in the variable <YOUR_PROJECT>_USER
    <YOUR_PROJECT>_LOCATION=default
    # Space separated list of users (in quotation marks) to install the project for
    # in /home/$user/Documents (if <YOUR_PROJECT>_LOCATION=default). 
    # default = all logged in users. Linking to desktop is also based on this list.
    <YOUR_PROJECT>_USER=default
    # Symbolic link to /home/$user/Desktop
    <YOUR_PROJECT>_LINK_TO_DESKTOP=true

Double check every configuration parameter, especially the *URL* and if *<YOUR_PROJECT>* is set to *true*.

Step 2: Open :ref:`script-build_tools-install_everything.sh` and look for the definition of the *PROJECTS* variable in the constant/default variable initialization section of the code::

    PROJECTS="PQRISCV_VEXRISCV DEMO_PROJECT"
    
Append your project name to list, using a space as a separator::

    PROJECTS="PQRISCV_VEXRISCV DEMO_PROJECT <YOUR_PROJECT>"
    
The major install script should now download and copy your project.


Extending the install script
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The script is designed in a generic way to allow smooth integration of additional tool build and install scripts. By using naming conventions, the major install script is able to find the tool install scripts, find their configuration and invoke them with default parameters. In this section, we'll walk through the structure of the script and explain each segment.


Default variable initialization
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The major install script first initializes default variables and constants, just like the tool build and install scripts do it::

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
    
Some constants and default variables are equivalent to those of a tool build and install script, refer to section :ref:`default-variable-initialization` to get an explanation about their function.

*CONFIG*, *SUCCESS_FILE_TOOLS*, *SUCCESS_FILE_PROJECTS*, *SCRIPTS* and *PROJECTS* are new constants. *CONFIG* specifies the location of the configuration file. *SUCCESS_FILE_TOOLS* defines the name of the file that contains the latest successfully installed script. *SUCCESS_FILE_PROJECTS* does the same for projects. Those files contain all the information required for the checkpoint mechanism used in this script. *SCRIPTS* contains a space separated list of tool install scripts. By using naming conventions, the major install script is able to find the location of the tool build scripts and configuration values within *CONFIG*. *PROJECTS* contains a space separated list of projects, which the script uses to find the configuration for each project listed there.

In addition to those constants, some default values are defined: *DIALOUT_USERS*, *VERSION_FILE_USERS* and *VERBOSE*. *DIALOUT_USERS* contains a space separated list of users that are added to the dialout group. It is modified by the parameter of the *-o* flag. By default every logged in user is added. *VERSION_FILE_USERS* contains a space separated list of users for whom a copy of the final version file is placed on their desktop. The default behavior is to add the version file to the desktop of every logged in user. It is modified by the parameter of the *-p* flag. *VERBOSE* contains a boolean that toggles whether warning and errors are printed to stdout. It is toggles by the *-v* flag.


Parameter parsing
~~~~~~~~~~~~~~~~~

Refer to section :ref:`parameter-parsing` for more information.


Function section
~~~~~~~~~~~~~~~~~

Please refer to section :ref:`function-section` before continuing in this section.

This script contains many more functions than the tool build scripts. A method that is used often in those function is the deduction of other variable names. Section :ref:`additional_parameters` explains how to add additional parameters, which includes the explanation of two important functions that use variable name deduction.


Error handling and superuser privilege enforcement
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Refer to section :ref:`error-handling-and-superuser-privilege-enforcement` for more information. In contrast to the tool build and install scripts, the major install script does not delete the workspace (*BUILDFOLDER*) when SIGINT or SIGTERM signals are received. This decision was made because a checkpoint mechanism was implemented, which uses files within the workspace. If the workspace would be deleted, the :ref:`script-build_tools-install_everything.sh` script would not know the previous progress. Running tool build and install scripts are killed and their workspace is still removed though.


Initialization
~~~~~~~~~~~~~~

Before the tool build and install scripts are invoked, the workspace is set up and the configuration is parsed::

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
    
Parsing the configuration file build_tools/:ref:`script-build_tools-config.cfg` is really simple. Since it only contains variable assignments in the form `VAR=value`, it is enough to *source* the configuration file. Now the script can use all the variables defined within :ref:`script-build_tools-config.cfg`.

Just like for tool build and install scripts, a *BUILDFOLDER* is created to serve as a workspace. All builds will happen within it and every script will temporarily be copied into that workspace. Within that folder an error file *errors.log* is created. This file is going to contain any warnings and errors. The last step of the initialization includes the execution of the *install_build_essentials.sh* script, which install packages that deliver the functionality to download from git, configure, build and install projects.

Handling the tools
~~~~~~~~~~~~~~~~~~

At the core of the script lies one for loop, that iterates through every *SCRIPT* and utilizes the functions which were defined to build and eventually install the scripts::

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
    
Before the scripts iterates over the tool build and install scripts, it checks whether some of the scripts already have successfully been installed during a previous invocation in the same workspace. The *get_latest* function takes a list of tool build and install script names *$SCRIPTS*, checks at which position the script contained within the checkpoint file *$SUCCESS_FILE_TOOLS* is in that list, offers the users to start over or go on from there and finally stores the modified list in the last parameter, which is also called *SCRIPTS* here.

The for loop iterates over the modified list of tool build and install script names. Remember that the configuration file only contains variable assignments and the naming convention to enter *<TOOLNAME>_PARAMETER=value*? This circumstance is used now to evaluate the tool configuration. In each iteration, the *SCRIPT* variable contains the current tool name. The command "${!SCRIPT}" evaluates the variable that has the name that is stored in *$SCRIPT*. So effectively the if statement looks like this in every iteration::

    if [ "$TOOLNAME" = true ]; then
    
Since we have parsed config.cfg before, which contains "TOOLNAME=value" for any tool, we effectively have tested one element of our configuration. If the tool was configured to be build, we enter the body, which first does evaluate the configuration (using the same trick line in the if-statement) and creates a string containing the flags and parameters::

    PARAMETERS=""
    parameters_tool "$SCRIPT" "PARAMETERS"
    
After that it copies the *install_<toolname>_essentials.sh* script and the *install_<toolname>.sh* script into the current workspace and appends the flags and parameters after the *install_<toolname>.sh* script path::

    COMMAND_INSTALL_ESSENTIALS=""
    COMMAND_INSTALL=""
    find_script "$SCRIPT" "COMMAND_INSTALL_ESSENTIALS" "COMMAND_INSTALL"
    COMMAND_INSTALL="${COMMAND_INSTALL} $PARAMETERS"
    echo "Executing: $COMMAND_INSTALL_ESSENTIALS"
    
At this point the naming convention is important again. The *find_script* function assumes that the naming convention was incorporated. It copies the tool build and install script folder *<toolname>* to the current workspace and returns a path in the current workspace to *<toolname>/install_<toolname>.sh* and *<toolname>/install_<toolname>_essentials.sh*. In addition, it copies an additional configuration file within the tool folder if it exists, that must be named *versions.cfg* (this will likely be changed to an arbitrary amount of config files with arbitrary names).

Everything is prepared now to execute the scripts, respecting the configuration::

    echo "Executing: $COMMAND_INSTALL_ESSENTIALS"
    exec_verbose "$COMMAND_INSTALL_ESSENTIALS" "$ERROR_FILE"
    echo "Executing: $COMMAND_INSTALL"
    exec_verbose "$COMMAND_INSTALL" "$ERROR_FILE"
    
At last, the current tool name *$SCRIPT* is stored in the checkpoint file. If the next tool script should fail, this script will know where to continue.


Handling the projects
~~~~~~~~~~~~~~~~~~~~~

In comparison to handling the tools, handling the projects is much simpler. Basically a project differs from tools by not requiring to be built or installed. So projects are only fetched from the web in the desired version and copied to some locations::

    echo -e "\n--- Setting up projects ---\n"
    get_latest "$PROJECTS" "$SUCCESS_FILE_PROJECTS" "project" "PROJECTS"

    for PROJECT in $PROJECTS; do
        if [ "${!PROJECT}" = true ]; then
            echo "Setting up $PROJECT"
            install_project "$PROJECT"
            echo "$PROJECT" > $SUCCESS_FILE_PROJECTS
        fi
    done

Just as for tools, a checkpoint mechanism is used for projects. Same logic, just a different file name. The configuration trick is the same here as well. *PROJECT* contains the name of the current project, *${!PROJECT}* checks its value, which previously was defined in the configuration file in the form of *<PROJECT>=value*. If the project was configured to be installed, the body of the for loop is entered::

    echo "Setting up $PROJECT"
    install_project "$PROJECT"
    echo "$PROJECT" > $SUCCESS_FILE_PROJECTS
    
The function *install_project* is called, which downloads and configures the project based on the configuration. The project is placed at the users documents folder and if desired, linked to desktop. After the projects was successfully installed, it is stored in the projects checkpoints file. 


Cleanup
~~~~~~~

Before cleaning up the workspace (*-c*), that means deleting it, the version file is copied out of the workspace and into the same folder the :ref:`script-build_tools-install_everything.sh` script lies. Additionally, it is copied to the desktop of the users specified in the variable *VERSION_FILE_USERS*::

    # secure version file before it gets deleted (-c)
    pushd -0 > /dev/null

    if [ -f "${BUILDFOLDER}/${VERSIONFILE}" ]; then
        cp "${BUILDFOLDER}/${VERSIONFILE}" .
    fi

    # --snip--

    # copy version file to users desktop
    if [ "$VERSION_FILE_USERS" == "default" ]; then
        copy_version_file "$(pwd -P)/${VERSIONFILE}" `who | cut -d: -f1`
    else
        copy_version_file "$(pwd -P)/${VERSIONFILE}" "$VERSION_FILE_USERS"
    fi
    
In addition, a set of users contained within the variable *DIALOUT_USERS* is copied to the dialout group::

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
    
After that the workspace is deleted, if the *-c* flag was set.

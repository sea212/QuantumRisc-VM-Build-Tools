Tool build- and install scripts
===============================

The entire project consists mainly of folders, which contain two scripts and sometimes a configuration file. The folder is named after the tool or the collection of tools, which are installed by the scripts contained within. One script does install the build essentials, using the apt package manager as it's primary source. The other script pulls, configures, builds and installs the tool in question. All scripts can be found in this documentation in :doc:`script_and_configuration_index`. The usage of those tool build and install scripts is described in section :ref:`tool-build-and-install-scripts`.

In addition to scripts for every single tool, a major fully configurable script exists, which automatically builds and installs all tools and projects, for which a tool build script exists and for which the installation flag is toggled in the configuration file. For more details, skip to section :ref:`fully-automated-script`


Prerequisites
-------------

* `Ubuntu <https://releases.ubuntu.com/20.04.1/ubuntu-20.04.1-desktop-amd64.iso>`__ (tested with version 20.04 LTS)
* `Build tools <https://github.com/sea212/QuantumRisc-VM-Build-Tools/tree/master/build_tools>`__
* Bash (tested with version 5.0.17)
* Apt package manager (tested with version 2.0.2ubuntu0.1)


.. _tool-build-and-install-scripts:

Tool build and install scripts
------------------------------

This section describes how to configure and use the tool build and install scripts.


Preparation
^^^^^^^^^^^

Before attempting to install the tools, you have to install some build-essentials like make, compilers and the python interpreter. You only have to execute this script once on a specific machine. Locally browse to :ref:`script-build_tools` and execute :ref:`script-build_tools-install_build_essentials.sh` as a superuser:

``sudo ./install_build_essentials.sh``


Usage
^^^^^

The scripts are structured similarly and most of the time offer identical configuration options. Let us simulate the usage of one tool together, using explanations of the configuration options and what the script does internally.
Browse to *build_tools/*:ref:`script-verilator`. This folder contains the two script:

#. :ref:`script-verilator-install_verilator_essentials.sh`
#. :ref:`script-verilator-install_verilator.sh`

This is a common naming pattern in this project, you can replace *verilator* by the names of other tools supported by this project. Both scripts require superuser privileges. To install the build essentials, the apt install command is used, that requires superuser privileges. Furthermore to install the built script, superuser privileges are required. The script could be designed such that superuser privileges are requested when required. By using this alternative approach, a fully automatic sequential installation of all tools would not be possible if the user does forget to run the scripts as superuser, because after a certain time the user must type in the superuser credentials again. You should install the software required to build the tool before building it by invoking the *install_<toolname>_essentials.sh* script, in this case:

``sudo ./install_verilator_essentials.sh``

After the build essentials have been installed, we can build and install the tool. Let's check out the parameters by executing the script with the *-h* option:

``./install_verilator.sh -h``

This prints the following output (for verilator)::

    install_verilator.sh [-h] [-c] [-d dir] [-i path] [-t tag] -- Clone latested tagged verilator
    version and build it. Optionally select the build directory and version, install binaries and
    cleanup setup files.

    where:
        -h          show this help text
        -c          cleanup project
        -d dir      build files in "dir" (default: build_and_install_verilator)
        -i path     install binaries to path (use "default" to use default path)
        -t tag      specify version (git tag or commit hash) to pull (default: Latest tag)


.. _tool-build-and-install-scripts-parameters:

The *-c*, *-d*, *-i* and *-t* options are default options that are available for every tool build and install script.

The script creates a build folder, in which the source code for the project is being pulled into and in which temporary files might be stored. The name of the build folder can be specified by using the *-d* flag.

The source code version that should be pulled can be specified by using the *-t* flag. You can specify a branch name, tag, commit hash or one of the following options:

- default/latest: Pulls the default branch
- stable: Pulls the latest tag

The default behaviour (in case *-t* was not specified) is to pull the default branch. Before using the *stable* option, be sure to check whether the repository stopped to use tags at some point in time. If this is the case, the script will pull and use an outdated version, because it does not check timestamps. If no tags are found, the default branch is used.

The scripts only builds the tools by default. To also install them (using the default path specified in the tool itself), execute the script with the *-i* flag. The *-i* flag takes one parameter, which is used to specify the install path. Set it to default to use the default install path preconfigured within the tool in question.

The last default flag is the *-c* flag, which deletes all files after the tool has been successfully installed. It is only relevant if the *-i* flag is supplied at the same invocation. Otherwise a tool that was build but not installed would be removed, which is obviously pointless because it is equivalent to no changes at all.

Some tools have additional parameters which should be documented well enough in the output of the *-h* flag.

If the tool build essentials have been installed and the invocation of the tool is realized with superuser privileges and correct parameters, the script will fully automatically install the tool in question. Note that the build and/or installation process can be canceled by the SIGINT or SIGTERM signals, the default behavior of the scripts is to remove any files created by the script though. Therefore any progress will be lost.


.. _fully-automated-script:


Fully automated and configurable tools and projects install script
------------------------------------------------------------------

This section describes how to configure and use the major tools and projects install script.


Preparation
^^^^^^^^^^^

The script depends on a configuration file, which specifies which tools and projects should be installed and how they are configured. This file is located in build_tools/:ref:`script-build_tools-config.cfg`. The configuration parameters should be commented well enough to be understood, but let's take a look at Verilators configuration section


Tool configuration
~~~~~~~~~~~~~~~~~~
.. code-block::
    :linenos:
    :lineno-start: 130
    
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
    
The configuration parameter names for tools follow the name conception *TOOLNAME_PARAMETER=VALUE*. The ``TOOL=true`` flag specifies whether this tool should be build and optionally installed or whether it should be ignored. Other than that, the four basic tool build and install script flags, that were described in :ref:`Tool build and install script parameters <tool-build-and-install-scripts-parameters>`, are mirrored by the config parameters followed by ``TOOL=true``. This is the minimal configuration, at the same time it is the complete set of configuration parameters for most of the tools.


Project configuration
~~~~~~~~~~~~~~~~~~~~~

Beside configuration entries for tools, projects can also be configured. The configuration is identical for every project and looks like this:

.. code-block::
    :linenos:
    :lineno-start: 182
    
    ## Pqvexriscv project
    # Download git repostiory
    PQRISCV_VEXRISCV=true
    # Git URL
    PQRISCV_VEXRISCV_URL="https://github.com/mupq/pqriscv-vexriscv"
    # Specify git branch or commit hash to pull (default = default branch)
    PQRISCV_VEXRISCV_TAG=default
    # Space seperated list of users (in quotation marks) to install the project for
    # /home/$user/Documents and link to desktop. default = all logged in users
    PQRISCV_VEXRISCV_USER=default
    # Symbolic link to /home/$user/Desktop
    PQRISCV_VEXRISCV_LINK_TO_DESKTOP=true
    
The configuration parameter names for projects follow the name conception *PROJECT_PARAMETER=VALUE*. You can toggle whether you'd like the project to be installed by specifying ``PROJECT=true``. Currently the projects are limited to projects that can be pulled by using git. The git repository url can be specified as an HTTP-link in the ``PROJECT_URL=HTTPURL`` parameter. The state of the git repository that should be used is reflected in the ``PROJECT_TAG=STATE`` parameter. *STATE* can either be a branch name, a tag or a commit hash.


.. _fully-automated-script-usage:

Usage
^^^^^
After configuring the tools and projects that shall be installed by adjusting :ref:`script-build_tools-config.cfg`, execute the install script :ref:`script-build_tools-install_everything.sh` and toggle the *-h* parameter (note that the real execution requires superuser privileges):

``./install_everything.sh -h``

It should emit the following output::

    install_everything.sh [-c] [-h] [-o] [-p] [-v] [-d dir] -- Build and install QuantumRisc 
    toolchain.

    where:
        -c          cleanup, delete everything after successful execution
        -h          show this help text
        -o          space seperated list of users who shall be added to dialout
                    (default: every logged in user)
        -p          space seperated list of users for whom the version file shall
                    be copied to the desktop (default: every logged in user)
        -v          be verbose (spams the terminal)
        -d dir      build files in "dir" (default: build_and_install_quantumrisc_tools)

The parameters *-c* and *-d* are equal to the default parameters mentioned in :ref:`Tool build and install script parameters <tool-build-and-install-scripts-parameters>`.

The *-o* parameter is used to specify the users who are added to the dialout group. By default (if *-o* is not set), the install script installs all tools and projects for every user who is logged in during the installation process. *-o* can by used in a scenario where the install script is configured to install the tools and projects for a single user or a set of users.

The *-p* parameter lets us control which users get a copy of the version file. This file is explained in the following section :ref:`version-file`. Identical to the behavior of *-o*, *-p* does target all logged on users by default.

The *-v* parameter enables or disables the verbose output. By default, only the current operations are printed to the console. This keeps the console relatively clean. Note that errors are still logged in a file (see :ref:`error-file`). By setting the *-v* parameter, every output is passed to the console. This includes compiler logs, which spam the console.

The default behavior of the script in case it receives SIGINT or SIGTERM signals, is to leave everything as it was before receiving the signal and to terminate the script. Nevertheless, the tool build script will delete the tool build folder in that case.


.. _version-file:

Version file
~~~~~~~~~~~~

Every single tool installation script does log the version the tool was build for in a file called *installed_version.txt*. The major tools and projects installation script, that is covered in this chapter, does collect the information from the version file of every tool that was build into a file called *installed_versions.txt*. The file is copied to the desktop of each user, who was specified by the *-p* parameter (every logged on user by default). This file can be used for instance when releasing a new QuantumRisc-VM version or when publishing a paper. The contents of the version file look like this::

    Yosys: 0.9 
    Project-Trellis: fef7e5fd16354c2911673635dd78e2dae3a775c0 
    Icestorm: d12308775684cf43ab923227235b4ad43060015e 
    Nextpnr-ice40: e6991ad5dc79f6118838f091cc05f10d3377eb4a 
    Nextpnr-ecp5: b39a2a502065ec1407417ffacdac2154385bf80f 
    Ujprog: 0698352b0e912caa9b8371b8f692e19aac547a69 
    OpenOCD: 9ed6707716b72a88ba6b31219b766c1562aec8d0 
    OpenOCD-Vexriscv: b77b41cf06d8981f3cf10c639d0f65d8ee6498b8 
    Verilog: v4.038 
    GTKWave: e049b936203c5a9b8e48de48a3d505e4e33e3d65 
    RiscV-GNU-Toolchain-linux-multilib: 256a4108922f76403a63d6567501c479971d5575
    qemu-linux-multilib: 134b7dec6ec2d90616d7986afb3b3b7ca7a4c383 
    riscv_binutils-linux-multilib: 2.34 
    riscv_dejagnu-linux-multilib: 1.6 
    riscv_gcc-linux-multilib: 10.1.0 
    riscv_gdb-linux-multilib: 9.1 
    riscv_glibc-linux-multilib: 2.29 
    RiscV-GNU-Toolchain-newlib-multilib: 256a4108922f76403a63d6567501c479971d5575 
    qemu-newlib-multilib: 134b7dec6ec2d90616d7986afb3b3b7ca7a4c383 
    riscv_binutils-newlib-multilib: 2.34 
    riscv_dejagnu-newlib-multilib: 1.6 
    riscv_gcc-newlib-multilib: 10.1.0 
    riscv_gdb-newlib-multilib: 9.1 
    riscv_newlib-newlib-multilib: 3.2.0


.. _error-file:

Error file
~~~~~~~~~~

Any errors that occur during the execution of the :ref:`script-build_tools-install_everything.sh` script are logged in the build directory, whose name is specified by the *-d* or whose name is set to the default value "build_and_install_quantumrisc_tools" if *-d* was not set. The file is named "errors.log". If *-v* is not set, the error messages are only redirected to this file. If *-v* is set, the error messages are additionally printed in the console.


Checkpoints
~~~~~~~~~~~

The :ref:`script-build_tools-install_everything.sh` script does remember which tools or projects have been successfully installed. By default, this information is stored inside the build directory in a file that's called "latest_success_tools.txt". For projects, by default a file named "latest_success_projects.txt" is used. If the execution of this script is canceled by the user or an error, the script remembers the state and during the next execution offers the user to continue were it stopped. The user can either decide to go on or start over. If the script terminated successfully, the user can only decide to install the latest tool or project in case the build directory was not cleaned up (id est *-c* was not set).


Projects
~~~~~~~~

All projects are only downloaded using the version that was specified in the configuration file :ref:`script-build_tools-config.cfg`. The downloaded files are placed in the "Documents" folder inside the home folder of all users who were specified in the configuration file. In addition, a symbolic link to the projects is placed on the desktop. Currently this part only works on English systems, because the folder names "Documents" and "Desktop" are hard-coded.

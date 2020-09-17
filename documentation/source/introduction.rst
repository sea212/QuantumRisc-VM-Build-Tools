Introduction
============
QuantumRisc is a project that aims to extend RiscV CPUs by post-quantum secure cryptography. This enables the future users of such extended RiscV CPUs to securely execute cryptography on classical computers, irrespective of the actuality that strong quantum computers exist.


What is this project?
---------------------
This project offers an out-of-the-box usuable Virtual Machine (VM) that includes many tools required for hardware and software development within the QuantumRisc project. This VM can be created by anyone by using build and install scripts, which are supplied in this project. Those scripts are configurable and depending on the configuration completely automatically install the tools. Every tool has its own script. Those scripts can be invoked one-by-one, alternatively another script can be used though, which installs and configures all tools and projects as specified in a simple configuration file.


Goals
-----
The major goals were defined before the VM was specified and ultimately led to the creation of this QuantumRisc-VM project. The goals include, but are not limited to:

* A team should be able to work on a whole set of tools with identical versions. This allows progress to be shared and executed in a way that ensures that no difference in tool versions leads to errors.
* New project members should be able to start working in the project in a fast and uncomplicated manner, eliminating the effort to build and install every tool in the correct version by themselves.
* In regards to future publications, with view on the mentioning of the used development environment, a VM with a set of tools with fixed versions (which easily can be retrieved) is convenient.
* A platform-independent development environment is required to allow any project member to choose their favorite operating system.
* Single tools and complete VMs should be setup fully automatically, reducing the preliminaries to adjusting a configuration file.


Contents
--------
In this section the single components of this project (QuantumRisc-VM) are summarized. This project can be used on three layers:

#. User - Hardware or Software developer in the QuantumRisc project (chapter :doc:`using_the_vm`)
#. Configurator - Usage of build and install scripts (chapter :doc:`creating_a_vm` and :doc:`direct_usage_of_the_scripts`)
#. Developer - Extension of build and install scripts (chapter :doc:`direct_usage_of_the_scripts`, :doc:`advanced_extending_the_install_scripts` and :doc:`script_and_configuration_index`)


Tool installation scripts
~~~~~~~~~~~~~~~~~~~~~~~~~
Any tool that is required for hardware or software development within the QuantumRisc can be installed using a fully automated installation script. Those scripts can be used independently from the VM to install the tools. Explanation on how to use these scripts is given in chapter :doc:`direct_usage_of_the_scripts`. All scripts and their configuration files are listed in chapter :doc:`script_and_configuration_index`.


QuantumRisc-VM build script
~~~~~~~~~~~~~~~~~~~~~~~~~~~
The QuantumRisc-VM build script is a configurable builder/installer of all tools for which an installation script exists. It was made with two priorities:

1. It should be easily configurable and executable
2. The operator should be able to leave the machine and come back to a fully configured VM in a couple of hours

In a configuration file every tool and project that the script will configure, build and if desired install, can be configured. After the script has been launched and possibly after answering some prompts, the script will work autonomously. A detailed description is given in chapter :doc:`creating_a_vm`.


QuantumRisc-VM
~~~~~~~~~~~~~~
RheinMain University offers an out-of-the-box usable VM that includes any tools required to work in the QuantumRisc project. The VM includes tools for open-source FPGA development from source code to simulation or programming of a real FPGA. This includes compilation of SpinalHDL code to Verilog or VHDL, synthesis, place and route, bitstream creation, bitstream programming for lattice fpgas, simulation and debugging. The VM also includes tools for RiscV CPU extension development which enable compiling, simulating and debugging. Finally, the VM includes projects that assist during the development of hardware-software-co-designs. It also includes a hello world project to test the available tools. The structure and usage of the QuantumRisc-VM is described in chapter :doc:`using_the_vm`.


Documentation
~~~~~~~~~~~~~
The installation scripts and QuantumRisc-VM build scripts are kept up to date in this documentation. Any remote changes will be automatically build and updated, so that the most recent changes are transparent. Users of the VM, users of the build scripts and developers who extend those scripts all should be able to get a majority of their relevant questions answered here.

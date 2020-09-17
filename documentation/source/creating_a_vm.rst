Creating a QuantumRisc-VM
=========================

In this section you can learn how to setup a virtual machine, how to configure the tool and project installation script and finally how to start the fully automatic QuantumRisc-VM setup process.

Prerequisites
-------------

* `VirtualBox <https://www.virtualbox.org/wiki/Downloads>`__
* `Ubuntu 20.04 LTS setup iso <https://releases.ubuntu.com/20.04.1/ubuntu-20.04.1-desktop-amd64.iso>`__
* >6GB RAM
* >70GB hard disk space (~54GB for the VM, ~12GB to archive it)



Preparing the VM
----------------

Follow the instructions on `how to install Ubuntu 20.04 LTS <https://fossbytes.com/how-to-install-ubuntu-20-04-lts-virtualbox-windows-mac-linux/>`__, but instead of allocating 30GB of disk space, choose at least 60GB. You can set the username and password both to "quantumrisc". After the successful installation of Ubuntu and all tools and projects, about 54 GB are used up. In case you selected 60GB, about 6GB are still available for the end user to download and install addtional software. During the installation of the tools and projects, the disk will use up to almost 60 GB temporarily.

After the successful installation of Ubuntu 20.04 LTS on the VM, shutdown the VM and follow the instructions from section :ref:`usage-setting-up-vm`. In addition to those instructions, you also have to raise the available memory for the VM to at least 6GB. To achieve this, select the VM and enter the *Settings* dialogue:

.. image:: pictures/using_the_vm/setting_up_vm/select_settings.png

Switch to the *System* tab in the left menu and set the base memory to 6144 MB or more:

.. image:: pictures/creating_a_vm/preparing/adjust_memory.png


Configuring the build script
----------------------------

This part has yet to be written


Configuring the tools
^^^^^^^^^^^^^^^^^^^^^

This part has yet to be written


Configuring the default projects
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

This part has yet to be written


Running the build script
------------------------

This part has yet to be written


Checkpoint mechanism
^^^^^^^^^^^^^^^^^^^^

This part has yet to be written
.. The latest installed tool or project will be logged


Installed files and folders
^^^^^^^^^^^^^^^^^^^^^^^^^^^

This part has yet to be written
.. Which stuff will be available on the VM?



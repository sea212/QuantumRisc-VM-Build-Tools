|Documentation Status| |License: MIT|

QuantumRisc-VM-Build-Tools
==========================

QuantumRisc is a project that aims to extend RiscV CPUs by post-quantum secure cryptography. This enables the future users of such extended RiscV CPUs to securely execute cryptography on classical computers, irrespective of the actuality that strong quantum computers exist.

What is this project?
=====================

This project offers an out-of-the-box usuable Virtual Machine (VM) that includes many tools required for hardware and software development within the QuantumRisc project. This VM can be created by anyone by using build and install scripts, which are supplied in this project. Those scripts are configurable and depending on the configuration completely automatically install the tools. Every tool has its own script. Those scripts can be invoked one-by-one, alternatively another script can be used though, which installs and configures all tools and projects as specified in a simple configuration file.

Further information
===================

| This project was sponsored by `RheinMain University`_ on behalf of `Prof. Dr. Steffen Reith`_, research director of the `QuantumRisc`_ project for `RheinMain University`_.
| You can get the latest QuantumRisc-VM and RiscV-Toolchain that were built with the scripts provided in this repository, as well as examples that can be run on the VM, at the `Random Oracles`_ website. The VMs are also available in `IPFS`_ (ipns://qrvm.haraldheckmann.de).
| For further information regarding this GitHub project, refer to the `project documentation`_.

.. Hyperlink-Images
.. |Documentation Status| image:: https://readthedocs.org/projects/quantumrisc-vm-build-tools/badge/?version=latest
    :target: https://quantumrisc-vm-build-tools.readthedocs.io/en/latest/?badge=latest
    :alt: Documentation Status
.. |License: MIT| image:: https://img.shields.io/badge/License-MIT-yellow.svg
   :target: https://opensource.org/licenses/MIT

.. Hyperlinks
.. _RheinMain University: https://www.hs-rm.de/en
.. _Prof. Dr. Steffen Reith: https://www.hs-rm.de/en/rheinmain-university/people/reith-steffen
.. _QuantumRisc: https://quantumrisc.org
.. _IPFS: https://ipfs.io/ipns/k51qzi5uqu5dh8vlsenkplnznnmbh3kba3eby2j4rzuq5xynhmx9p5a30fyyc4
.. _Random Oracles: https://random-oracles.org/risc-v-development
.. _project documentation: https://quantumrisc-vm-build-tools.readthedocs.io/en/latest/?badge=latest

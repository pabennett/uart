VHDL UART
=========

Description
-----------

A VHDL UART for communicating over a serial link with an FPGA. This example
implements a loopback so that data received by the FPGA will be returned down
the serial link.

The default settings for the link are 115200 BAUD, 8 Data, 1 Stop, No parity.

Source files
------------

+--------------------+--------+----------------------------------------------------+
| File               | Type   | Description                                        |
+====================+========+====================================================+
| uart.vhd           | VHDL   | UART implementation                                |
+--------------------+--------+----------------------------------------------------+
| loopback.vhd       | VHDL   | Instance UART in loopback @ 115200 baud & 100MHz   |
+--------------------+--------+----------------------------------------------------+
| top.vhd            | VHDL   | Instance loopback in FPGA top level wrapper        |
+--------------------+--------+----------------------------------------------------+
| tb_uart.vhd        | VHDL   | Testbench for the UART component                   |
+--------------------+--------+----------------------------------------------------+
| uart_unit_tests.py | Python | ChipTools unit test suite for tb_uart.vhd          |
+--------------------+--------+----------------------------------------------------+
| uart.ucf           | UCF    | Constraints for Spartan 6 LX9 Microboard (Avnet)   |
+--------------------+--------+----------------------------------------------------+
| uart.xml           | XML    | Project file for ChipTools framework               |
+--------------------+--------+----------------------------------------------------+

Getting Started
----------------

The UART core includes a project file so that it can be built and tested using
the `ChipTools framework <https://github.com/pabennett/chiptools>`_

Run the Unit Tests
~~~~~~~~~~~~~~~~~~

To run the unit tests invoke ChipTools in the top level directory:

.. code-block:: bash

    $ chiptools

Load the project and run the tests:

.. code-block:: bash

    $ load_project uart.xml
    $ run_tests

The default simulator is set to Modelsim, to run the tests using a different
simulator supply either 'isim', 'ghdl' or 'vivado' to the **run_tests**
command.

The report file: **report.html** is saved in the **simulation** directory and
contains the results of the simulation test suite.

Synthesise the Design
~~~~~~~~~~~~~~~~~~~~~

A constraints file is provided to allow the design to be built for the
**Spartan 6 LX9 Microboard**. To initiate a build perform the following in the
top level directory:

.. code-block:: bash

    $ chiptools
    $ load_project uart.xml
    $ synthesise lib_uart.top

The synthesis flow is set to 'ise' as this is targeted at a Spartan6 FPGA.

Build outputs will be automatically archived and stored in the **synthesis**
directory.

Further reading
--------------------

Original release post
~~~~~~~~~~~~~~~~~~~~~

http://www.bytebash.com/2011/10/rs232-uart-vhdl/

ChipTools repository
~~~~~~~~~~~~~~~~~~~~~

http://github.com/pabennett/chiptools

ChipTools documentation
~~~~~~~~~~~~~~~~~~~~~~~

http://chiptools.readthedocs.org/en/latest/index.html
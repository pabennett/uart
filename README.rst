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

The following source files can be found in the 'source' directory.

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
| fpga_unit_tests.py | Python | Hardware unit tests for the LX9 Microboard         |
+--------------------+--------+----------------------------------------------------+

The **uart.xml** file in the top level directory is a project file to allow you
to build and test this design using the `ChipTools framework <https://github.com/pabennett/chiptools>`_

Getting Started
----------------

The following instructions explain how to test and build the loopback example
using the ChipTools framework. Simulation and hardware tests are included.

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

Run the Hardware Unit Tests
~~~~~~~~~~~~~~~~~~~~~~~~~~~

A set of unit tests have been written to test the UART loopback example after 
it has been programmed onto a Spartan 6 LX9 Microboard. The unit tests check
different transfer sizes of random data using the default BAUD rate of 115200.

The tests require `PySerial <https://github.com/pyserial/pyserial>`_ to allow
Python to read and write to the serial port. Before running the tests the board
should be programmed and connected to your PC and the serial port setting in
the unit test should be edited to map to the serial port of the FPGA board.


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
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
Below source/

- uart.vhd     - The UART Receiver/Sender module, this is what you want to use in you design
- loopback.vhd - Example usage of the UART module, just echoing back the received data
- top.vhd      - Sample Toplevel implementation of Loopback module


Further reading
--------------------
Read more about UART module usage in the header of the module file source/uart.vhd

Original release post:
http://www.bytebash.com/2011/10/rs232-uart-vhdl/

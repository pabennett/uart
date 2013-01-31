call F:\Development\ISE_DS\settings64.bat

cd .

echo off

REM AVNET IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" 
REM SOLELY FOR USE IN DEVELOPING PROGRAMS AND SOLUTIONS FOR XILINX 
REM DEVICES.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION
REM AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE, APPLICATION
REM OR STANDARD, AVNET IS MAKING NO REPRESENTATION THAT THIS
REM IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,
REM AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE
REM FOR YOUR IMPLEMENTATION.  AVNET EXPRESSLY DISCLAIMS ANY
REM WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE
REM IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR
REM REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF
REM INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
REM FOR A PARTICULAR PURPOSE.
REM     
REM (c) Copyright 2011 AVNET, Inc.
REM All rights reserved.

@echo ##########################################################################
@echo # This file configures the XC6SLX9-CSG324 FPGA on the Avnet              #
@echo #   Spartan-6 LX9 MicroBoard using the on-board Digilent JTAG.           #
@echo ##########################################################################

set   bitstream=message_gen_routed.bit
set   cmd_file=config_s6lx9.cmd

@echo setMode -bscan                       > %cmd_file%
@echo setCable -target "digilent_plugin"  >> %cmd_file%
@echo identify                            >> %cmd_file%
@echo assignfile -p 1 -file %bitstream%   >> %cmd_file%
@echo program -p 1                        >> %cmd_file%
@echo quit                                >> %cmd_file%
 
impact -batch %cmd_file%

erase %cmd_file%

pause

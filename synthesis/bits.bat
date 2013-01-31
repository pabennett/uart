call F:\Development\ISE_DS\settings64.bat

set ncd_filename=top

bitgen -w -b -g UnusedPin:Pullnone -g compress -g Reset_on_err:Yes -g configrate:26 -g spi_buswidth:1 -g startupclk:cclk -g binary:yes %ncd_filename%_routed.ncd %ncd_filename%_bitstream %ncd_filename%.pcf

pause

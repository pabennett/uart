call F:\Development\ISE_DS\settings64.bat

set core=top
set part=xc6slx9-csg324-2

rmdir /S /Q xst_work
erase %core%*

xst -ifn implement.ifn -ofn implement.log
ngdbuild -p %part% -uc uart.ucf %core%
map -pr b %core%.ngd -o %core%.ncd %core%.pcf
par -ol std -w %core%.ncd %core%_routed %core%.pcf
trce -v 10 %core%_routed.ncd %core%.pcf

bitgen -w -b -g UnusedPin:Pullnone -g compress -g Reset_on_err:Yes -g configrate:26 -g spi_buswidth:1 -g startupclk:cclk -g binary:yes %core%_routed.ncd %core%_routed %core%.pcf

rmdir /S /Q xst_work
erase netlist.lst *.xml *.unroutes

pause
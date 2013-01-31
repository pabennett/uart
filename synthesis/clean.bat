set core=top

rmdir /S /Q xst_work
rmdir /S /Q _xmsgs
erase %core%*
erase netlist.lst *.xml *.unroutes implement.log
rmdir /S /Q xlnx_auto_0_xdb
erase xlnx_auto*
erase par_usage*
erase *.log

pause
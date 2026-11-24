# P2-05 ONLY. Digilent Basys-3-Master.xdc JA1 = J1 LVCMOS33.
# Add only if the current project XDC does not already constrain cds_digital.
# No duplicate PACKAGE_PIN or IOSTANDARD entries allowed.
set_property PACKAGE_PIN J1 [get_ports cds_digital]
set_property IOSTANDARD LVCMOS33 [get_ports cds_digital]
# NEVER connect a 5V DO signal directly to this 3.3V FPGA input.

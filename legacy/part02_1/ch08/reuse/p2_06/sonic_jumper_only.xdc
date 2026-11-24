# P2-06 ONLY new top ports; keep P2-05 JA1 cds_digital on J1.
# JA2 physical pin L2: HC-SR04 TRIG (FPGA output, verify module VIH).
set_property PACKAGE_PIN L2 [get_ports sonic_trig]
set_property IOSTANDARD LVCMOS33 [get_ports sonic_trig]
# JA3 physical pin J2: HC-SR04 Echo through 5V->3.3V level divider/shifter!
set_property PACKAGE_PIN J2 [get_ports sonic_echo]
set_property IOSTANDARD LVCMOS33 [get_ports sonic_echo]

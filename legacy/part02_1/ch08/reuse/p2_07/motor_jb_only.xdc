# P2-07 ONLY. Append to confirmed P2-06 XDC; no duplicate constraints.
# Digilent Basys3 Master XDC: JB1=A14, JB2=A16, JB3=B15.
# ENA hardware pulldown required so motor stays disabled during FPGA configuration.
set_property PACKAGE_PIN A14 [get_ports motor_in1]
set_property IOSTANDARD LVCMOS33 [get_ports motor_in1]
set_property PACKAGE_PIN A16 [get_ports motor_in2]
set_property IOSTANDARD LVCMOS33 [get_ports motor_in2]
set_property PACKAGE_PIN B15 [get_ports motor_ena]
set_property IOSTANDARD LVCMOS33 [get_ports motor_ena]

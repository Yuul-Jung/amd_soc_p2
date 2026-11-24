# P2-12.2: Basys3 JC1~JC4 후보 핀 (Digilent Basys-3-Master.xdc).
# (주의) 실제 기존 설계에서 JC가 비어 있는지 반드시 확인 후 적용!
# (주의) 기존 XDC와 중복 추가하지 말 것. 신호 포트명은 USER TOP과 일치.
# 출력 비트 0→IN1, 1→IN2, 2→IN3, 3→IN4.
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports {stepper_coil_o[0]}]
set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {stepper_coil_o[1]}]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {stepper_coil_o[2]}]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {stepper_coil_o[3]}]

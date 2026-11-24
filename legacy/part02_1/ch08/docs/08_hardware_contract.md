# P2-08 하드웨어/소프트웨어 동작 계약

## IP 선정
- **신규 AMD 제공 IP**: `xadc_wiz_0` (XADC Wizard, AXI4-Lite). `p2_08_axi_adc` 같은 임의 사용자 RTL은 생성하지 않는다.
- 기존 제2부 01~07장의 RTL/AXI IP 원본은 수정하지 않는다.
- P2-07 프로젝트를 P2-08로 Save As 복제한 뒤 XADC Wizard만 BD에 추가한다.

## 실제 포트
- 외부 아날로그 채널: VAUX6 = `vauxp6` / `vauxn6`, Basys3 JXADC1(J3) / JXADC7(K3).
- Vivado XADC Wizard: `AXI4-Lite`, `Continuous`, `Single Channel VAUX6`, `Unipolar`.
- BD에서 외부 포트로 만든 이름과 자동 생성 `soc11_integration_wrapper.v` 선언부를 **실제 비교**한다.
- 아날로그 포트에는 보통 디지털 I/O 방식의 `IOSTANDARD LVCMOS33`를 임의 적용하지 않는다. XADC Wizard가 아날로그 기능을 설정하며 핀 매핑은 보드 공식 XDC/구현 결과 대조. 실제 명칭/제약이 다르면 수정 후 다시 확인.

## 측정 데이터
- `XSM_AUX06_OFFSET` = `0x258` (`xsysmon_hw.h`, 7-series XADC AXI register map).
- 32비트 AXI 결과의 하위 16비트 중 상위 12비트 `[15:4]`가 결과 코드.
- `RAW12` 범위 0..4095; 단극성 VAUX6 차동 입력 0..1.0 V.
- 환산(표시용 근사): `mV = (RAW12 * 1000 + 2047) / 4095`.
- PWM Duty 요청: `percent = (RAW12 * 100 + 2047) / 4095`.
- 변환 유효성: 읽기는 **저장된 결과 레지스터** 조회이며 새 변환 완료 시각/유효성 비트는 본 C 코드에서 직접 확인하지 않음. 전원 켠 직후 결과는 보류해야 한다.

## UART 계약
- `ADC READ`: 현재 XADC 결과 레지스터를 읽어 `RAW`, `MV`, `PWM_REF` 출력.
- `ADC PWM`: 현재 결과를 LED1의 PWM 설정으로 **단 한 번** 반영 (`pwm_queue_percent`), 주기 경계 반영, Pending이면 BUSY.
- `PWM 0..100`: 기존 수동 PWM 명령 유지. `ADC PWM`은 자동 지속 추종이 아님.
- `AUTO ON/OFF`: 기존 CdS 기반 LED1 게이트이며, ADC PWM과 독립. CdS AUTO 상태에서 밝은 환경에서는 LED1이 켜지지 않을 수 있다.
- `MOTOR FWD/REV/STOP`: 초음파 보호 완전 독립. 아날로그 입력은 모터 속도/보호를 직접 바꾸지 않음.
- `STATUS`: 이전 필드를 유지하며 `ADC_RAW`, `ADC_MV`, `ADC_PWM_LAST`, `ADC_FRESH=UNVERIFIED` 추가.
- FND는 06장의 SONIC 거리 모드 또는 03장의 VALUE/EVENTS 정책 그대로, ADC는 **UART만 표시**.

## 입력 안전
- 실제 JXADC `vauxp6-vauxn6` 차동 전압은 단극성 0..1.0V 범위로 한정.
- 3.3V 직접 연결 금지. 10k potentiometer 0~3.3V 출력을 27k/10k 분압하여 최대 약 0.892V로 축소할 수 있다. 전압·배선 실측 전에는 FPGA 연결하지 않는다.
- GND 기준 사용 시 VauxN6는 아날로그 GND에 연결. 전원·공통모드·전압 정격은 공식 UG480과 실물 모듈을 대조한다.

## 확정하지 않은 값
- 신규 AXI XADC `P2_08_XADC_BASEADDR`, XADC IP 포트 노출 이름, XADC Wizard 2024.2 최종 GUI/빌드 결과.
- WNS/TNS/DRC, BSP 헤더 매크로, 샘플 갱신 주기, 보드 캡처와 아날로그 입력 회로 실측값.

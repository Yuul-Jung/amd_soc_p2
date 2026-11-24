# 제2부 01~10장 과제·문자열 명령·자원 계약

> 이 문서는 설계 계약의 정리이며 실물 검증 통과 기록이 아니다.

| 장 | 프로젝트 | 핵심 기능 | 주요 명령·입력 | 보드 출력 자원 |
|---|---|---|---|---|
| 01 | `soc_ip_design_01` | 사용자 AXI LED IP | `LED ON / LED OFF / STATUS` | LED0 |
| 02 | `soc_ip_design_02` | FND 4자리 표시 | `DISP dddd / DISP OFF` | 4자리 FND |
| 03 | `soc_ip_design_03` | 방향 버튼 Short/Long·IRQ | `BTNU/BTND/BTNL/BTNR · 5초 Long` | FND 값·모드 |
| 04 | `soc_ip_design_04` | 범용 PWM 밝기 제어 | `PWM 0..100` | LED1 |
| 05 | `soc_ip_design_05` | 디지털 CdS 자동 조명 | `AUTO ON/OFF · CDS READ/POL` | LED1 |
| 06 | `soc_ip_design_06` | HC-SR04 거리 측정 | `SONIC ON/OFF/READ/SHOT · WARN` | FND 거리·LED2 |
| 07 | `soc_ip_design_07` | DC 모터 보호·제어 | `MOTOR FWD/REV/STOP/STATUS` | 외부 L298N |
| 08 | `soc_ip_design_08` | XADC 측정·PWM 반영 | `ADC READ / ADC PWM` | LED1 설정 |
| 09 | `soc_ip_design_09` | UART·IRQ·운전 모드 통합 | `MODE AUTO/MANUAL/STATUS · IRQ STATUS` | LED14/15 |
| 10 | `soc_ip_design_10` | 안전 상태 기반 종합제어 | `RUN START/STOP/RESET/STATUS` | LED/FND/모터 |

## 장별 선행 관계

`P1-11(검증된 기존 SoC)` → `P2-01` → `P2-02` → `P2-03` → `P2-04` → `P2-05` → `P2-06` → `P2-07` → `P2-08` → `P2-09` → `P2-10`.

- 각 장의 새 XPR은 직전 장의 실제 성공 프로젝트를 **독립 복제**한 뒤 변경한다. 문서 파일만 존재하는 상태를 성공 프로젝트라고 가정하지 않는다.
- **Top**은 포트·배선·모듈 연결만 맡고, 기능은 독립 Core/Controller와 AXI IP/C 프로그램으로 분리한다.
- **LED 소유권**: LED0 = 01장 AXI IP, LED1 = 04/05장 PWM/Auto, LED2 = 06장 초음파 경고, LED3~15 = 기존 GPIO 연결. LED14·15 C 표시 기능은 09/10장에 신규 통합되어 있음.
- **FND 자리**: 일반값/이벤트/거리의 표시 모드를 구분. 거리 모드 `0050`은 50cm, 실측 invalid는 표시 소등. `DISP 0050`은 네 자리 선행 0 유지.
- **버튼**: BTNC는 리셋. 방향 4개 BTNU/BTND/BTNL/BTNR은 5초 Long 및 Short 이벤트.
- **UART**: ASCII 대문자 문자열+Enter. 동일 과제의 명령·C 파서·도식·해설을 일치시킴.
- **IRQ**: 버튼·Timer 다중 소스 공유 시 Classic/SDT BSP 차이와 INTC 연결/주소 확인 필요.
- **모터**: 근접·Timeout·샘플 신선도·Deadtime·TRIP 보호는 RTL. 제10장 RUN 모드 C의 안전 정책은 부가적인 정책으로, 물리 긴급정지 아님.
- **전기적 입력**: JA1 CdS 3.3V 디지털 확인, JA3 초음파 ECHO 5V→3.3V 변환, JXADC VAUX6 0~1V. 모터 전원 외부/공통 GND.
- **절대주소와 IP/IRQ ID**: 예제에 적힌 값이나 호스트 테스트 가짜 값을 사용하지 않는다. 실제 Vivado Address Editor/XSA/Vitis `xparameters.h`를 확인한다.

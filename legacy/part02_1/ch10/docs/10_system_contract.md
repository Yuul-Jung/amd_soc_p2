# 제2부 10장 — 종합제어 시스템 계약

## 0. 원칙
- 독립 프로젝트: `$HOME/soc/hw/soc_ip_design_10/` (목표 경로; 실제 생성·검증 별개).
- 기준: 09장 검증된 프로젝트 복제. 09장까지의 기존 사용자 IP/RTL/Top 재사용.
- 신규 AXI IP 없음. 10장의 변화는 `main_p2_10.c` 및 독립 `p2_10_capstone_logic.[ch]`.
- Basys3와 Vitis 2024.2 프로젝트의 실제 주소·IRQ·Clock 값을 사용한다.

## 1. 사용자 명령
- 신규: `RUN START`, `RUN STOP`, `RUN RESET`, `RUN STATUS`.
- 유지: `MODE AUTO/MANUAL/STATUS`, `IRQ STATUS`, `LED ON/OFF`, `DISP dddd/OFF`, `PWM n`, `AUTO ON/OFF`, `CDS READ/POL`, `SONIC ON/OFF/READ/SHOT`, `WARN n/OFF`, `MOTOR FWD/REV/STOP/STATUS`, `ADC READ/PWM`, `STATUS`.
- PC UART 115200 8N1, ASCII 대문자 문자열과 Enter. 구 1/0/r/h 단일 문자 명령을 되살리지 않는다.
- MODE AUTO: SONIC/CdS 자동 상태 활성화 및 모터 STOP 요청. *모터 자동 시작 없음*.
- RUN START: MODE AUTO, SONIC 유효·AUTO·UNSAFE 0, MOTOR RTL SAFE/FRESH/AUTO, TRIP 0, CDS VALID 1, WARN 20..400cm일 때만 FWD 요청.
- RUN STOP: 항상 모터 STOP. 오류 latch는 유지.
- RUN RESET: 모터 STOP 명령·실제 ENA OFF 확인 후 C 오류 latch 해제; 재시작은 별도 RUN START.
- RUN STATUS: IDLE/RUNNING/FAULT, FAULT 코드, 실측 MOTOR_EN과 명령 구분.
- RUNNING 중 `WARN ...`와 `CDS POL ...` 조작 거부. MODE MANUAL 진입 시 모터 STOP 먼저 수행.
- BTNR 장누름 5초: FND 초기화(03장 의미 보존) + RUNNING이면 STOP/FAULT latch. BTNC Reset 보존.

## 2. 실패 안전 경계
- 07장 `motor_controller.v`: 센서 비유효·근접·신선도 타임아웃·direction change에 대해 ENA를 하드웨어에서 게이트.
- 10장 C: 추가 정책과 오류 latch. MAIN 루프 및 IRQ가 정상 동작해야 작동하는 소프트웨어 방어임.
- XADC는 `ADC_FRESH=UNVERIFIED`; 최신성 보증이 없는 아날로그 샘플을 안전 인터록에 사용하지 않음.
- CdS 디지털 센서가 VALID인지는 확인하되, 밝기 판단은 조명 LED1만 제어하고 모터 거리를 추정하지 않음.
- CPU 정지·소프트웨어 무한루프·AXI bus hang 시 C 정책이 즉시 모터를 정지시킨다는 주장은 금지. 독립 HW Watchdog은 구현되지 않음.
- BTNR 장누름은 SW 정지 요청이며 물리적 E-Stop/별도 전원 차단 장치가 아님.

## 3. 전원·전압
- HC-SR04 ECHO 5V → FPGA 3.3V 레벨변환 필요.
- XADC VAUX6 차동 단극성 0..1V 준수. 센서 출력 3.3V 직접 연결 금지.
- L298N 모터별도전원·공통GND, 동작확인 전 물리 차단 준비, 관성 정지 고려.

## 4. 실제 검증 게이트
1. 09장 XPR가 실제 성공인지 확인하고 10장 XPR로 Save As, 모든 원본 소스 참조·XDC·BD·Wrapper 정합성 확인.
2. P2-01~08 AXI IP Base, BTN/Timer IRQ 인코딩, Timer Clock을 실제 생성 BSP와 비교.
3. RTL_SIM: motor deadtime, trip, stale, timeout, near; AXI_SIM: read/write, reset, `WSTRB`, AW/W/B/AR/R.
4. Vivado Validate → Synthesis/Implementation → DRC/Timing → Bitstream → XSA.
5. Vitis 2024.2 실제 BSP 빌드(모의 구문 검사 대체 불가), ELF 및 target run.
6. Basys3: UART 10장 명령, LED0/1/2/14/15, FND, 버튼 4개, CdS/SONIC/XADC, 모터 실제 ENA/STOP, 오류 래치/복구.
7. HTML 실제 브라우저 및 공개정보 노출 검사, GitHub 게시 여부 별도 기록.

## 5. 수정 경계
- 01~09장 ZIP·GitHub·실제 성공 XPR 수정하지 않음.
- `reference/main_p2_09.c`는 비교 원본이고 Vitis `src`에서 빌드 대상 아님.
- `rtl/basys3_soc11_top_p2_08.v`는 실제 모듈 이름 `basys3_soc11_top`의 검증 대기 소스. 파일 복사 시 중복 Top 생성 주의.
- 기존 BaseAddr·Timer 매크로에 09 번호가 포함된 것은 누적 C 코드 계약이며 실물 BSP에 따라 실제 값 결정.

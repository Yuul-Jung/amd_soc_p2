# 제2부 09장 — 하드웨어·명령·안전 통합 계약

## 구현 범위
- 프로젝트 `soc_ip_design_09` (08장 성공 복제본). 08장 원본 보호.
- 추가 사용자 RTL IP **없음**. 기존 01~08장 IP 재사용. Top은 08장 동일한 소스.
- BD에서 AXI Timer IRQ와 03장 버튼 IRQ는 서로 다른 AXI INTC 입력/ID에 연결.
- UART Lite는 Polling. GPIO bit14/bit15는 CPU가 출력한 상위 `gpio_led[15:3]` 중 LED14/15.

## UART 문자열 명령
| 명령 | 동작 |
|---|---|
| `MODE AUTO` | 모터 STOP 요청 → SONIC ON 및 FND DIST → CdS AUTO ON. 자동 기동 없음. |
| `MODE MANUAL` | CdS AUTO OFF 및 FND VALUE/EVENTS 복귀, SONIC 안전 감시 유지. |
| `MODE STATUS` | CPU 모드, CdS/SONIC 설정, MOTOR 요청 상태. 실제 모터 출력은 `MOTOR STATUS`. |
| `IRQ STATUS` | Timer/버튼 카운터(8종) 및 COALESCED. 전체 동시 스냅샷 아님. |
| `STATUS` | 08장 기존 상태 + CTRL_MODE, IRQ_TIMER, LED14_ACTIVITY/LED15_HEARTBEAT. |

AUTO 중 `MOTOR FWD`/`MOTOR REV`/`AUTO OFF`/`SONIC OFF` 거부. `MOTOR STOP` 항상 허용. `WARN OFF`는 LED2 표시만 해제하며 모터 하드웨어 안전 차단에는 영향을 미치지 않음. `PWM 50`은 AUTO 중 Duty 설정은 가능하지만 CdS의 빛 게이트가 최종 LED1을 제어.

## Timer와 IRQ
- Timer 0의 DOWN_COUNT/AUTO_RELOAD/INT_MODE, 0.5초 목표.
- `P2_09_TIMER_CLK_HZ`는 실제 AXI Timer Clock 값에 근거하여 설정. 클록 100MHz라면 50,000,000 tick당 0.5초 목표.
- SDT: `XTmrCtr.Config.IntrId/IntrParent`, 버튼은 `P2_03_BTN_INTR_ID/PARENT`. Classic: 하나의 XIntc에 버튼과 Timer를 서로 다른 IRQ ID로 연결.
- SDT/Classic 구조는 실제 2024.2 BSP의 xinterrupt_wrap API와 IRQ 연결을 사용.
- ISR에서는 카운터 증가만. 메인 루프에서 LED14/15 업데이트.

## 외부 전기적 안전
- HC-SR04 ECHO 5V → 3.3V 레벨변환, 모터 전원 별도 공급 및 공통 GND.
- XADC VAUX6는 단극성 차동 입력 전압 0~1V 제한(08장 기준).
- 모터 `motor_controller`의 hardware interlock을 SW 모드로 우회하지 않는다.

## 실습 전 미확인
실제 09장 XPR 생성, BD의 xlconcat 및 AXI INTC 인터럽트 연결, xparameters.h 09장 값, Timer 입력 클록, SDT BSP 두 소스 동시 처리, XSA/ELF/Bitstream, 실물 LED14/15, 모터 실측, RTL/AXI 시뮬레이션, 타이밍/전력, 사이트 브라우저 검증.

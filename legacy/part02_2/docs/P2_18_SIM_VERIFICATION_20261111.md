# 제2부 18장 — HC-SR501 PIR/IRQ 시뮬레이션 검증 보고서

- 검증일: 2026-11-11 KST
- 기준 저장소: `Yuul-Jung/soc`의 `CURRICULUM.md`, `MIGRATION.md`, `VALIDATION.md`, `COLLABORATION.md` 최신 파일 확인.
- 구현 저장소: `Yuul-Jung/amd_soc`, 브랜치 `work/part02-second-half-20261110`.
- **실행 근거**: [GitHub Actions Run #42949369769](https://github.com/Yuul-Jung/amd_soc/actions/runs/42949369769), 테스트 커밋 `7b11150432d9de38091307a040bd178a7f67748e`.
- 실행 환경: GitHub-hosted `ubuntu-24.04`, Icarus Verilog + vvp.
- 사용자의 Ubuntu/Vivado/Vitis/실물 보드에서 설치·실행한 것이 아님.

## 1. 실제 실행 로그

| 검증 | 결과 | 로그 |
|---|---|---|
| 초기 안정화 구간의 출력 HIGH 무시 | **PASS** | `P2_18_PIR_WARMUP_MASK_PASS` |
| 안정화 필터와 짧은 입력 스파이크 | **PASS** | `P2_18_PIR_GLITCH_FILTER_PASS` |
| 1회 상승 에지, 계속 HIGH 중 중복 방지 | **PASS** | `P2_18_PIR_RISE_ONLY_STICKY_IRQ_PASS` |
| IRQ_ENABLE 마스크·Pending 유지·ACK | **PASS** | `P2_18_PIR_IRQ_ENABLE_ACK_PASS` |
| LOW 복귀 후 두 번째 HIGH 이벤트 | **PASS** | `P2_18_PIR_RETRIGGER_PASS` |
| ARM 비활성 중 엣지 무시 | **PASS** | `P2_18_PIR_ARM_GATE_PASS` |
| ACK와 신규 이벤트 동시 발생, 신규 이벤트 승리 | **PASS** | `P2_18_PIR_ACK_EVENT_PRIORITY_PASS` |
| Event Count Clear와 Pending 별도 유지 | **PASS** | `P2_18_PIR_COUNT_CLEAR_PASS` |
| PIR RTL Core 전체 | **PASS** | `P2_18_PIR_IRQ_CONTROLLER_RTL PASS` |
| AXI ID, Reset 기본값 ARM/IRQ_DISABLED | **PASS** | `P2_18_AXI_ID_RESET_PASS` |
| AXI AW/W 별도 도착·WSTRB/CTRL | **PASS** | `P2_18_AXI_WSTRB_CTRL_PASS` |
| AXI STATUS 및 EVENT_COUNT | **PASS** | `P2_18_AXI_IRQ_STATUS_COUNT_PASS` |
| AXI IRQ 마스크/복구/ACK | **PASS** | `P2_18_AXI_IRQ_MASK_ACK_PASS` |
| AXI 잘못된 주소·읽기전용 영역 쓰기 SLVERR | **PASS** | `P2_18_AXI_ERROR_RESP_PASS` |
| AXI4-Lite PIR IRQ 전체 Unit | **PASS** | `P2_18_AXI_PIR_IRQ_PASS` |

## 2. 주요 설계 원칙

1. 비동기 입력 `pir_in_async` → `pir_meta` / `pir_sync` 2단 동기화 후 `FILTER_CYCLES` 동안 동일 입력 상태가 유지되면 `pir_level` 변경.
2. PIR LOW→HIGH 전환만 `motion_pulse` 1회, `event_pending` Sticky 상태 유지.
3. `irq_enable`은 Pending 삭제가 아닌 CPU IRQ 라인 마스킹이며 `irq=irq_enable && event_pending`.
4. `irq_ack_pulse`와 새로운 상승 에지가 동시인 경우 **새 이벤트 우선**. 실제 인터럽트 핸들러에서 새 이벤트 유실 가능성을 줄임.
5. `event_count`는 최대 `0xFFFFFFFF`에서 포화, 초기화 `count_clear_pulse` 별도.
6. `WARMUP_CYCLES`는 64bit 설정(100MHz에서 60초 = 6,000,000,000 시스템 클록). TB는 20클록으로 축소했으므로 현물에서 60초 대기 성능을 실측한 것이 아님.
7. HC-SR501 트리거 모드 H/L, 감지 거리, 출력 지속 시간, 전원 5V 공급 구성은 보드 외부 모듈에서 설정/측정하며 본 RTL은 0/1 이벤트만 수신.

## 3. 신규 AXI4-Lite 레지스터맵

| Offset | Name | 설명 |
|---|---|---|
| 0x00 | CTRL | bit0 ARM, bit1 IRQ_ENABLE (Reset 0) |
| 0x04 | CMD | W1P bit0 ACK, bit1 COUNT_CLEAR |
| 0x08 | STATUS | bit0 ready, bit1 pir_level, bit2 pending, bit3 irq |
| 0x0C | EVENT_COUNT | rising event count |
| 0x10 | ID | `0x00180001` |

- AW/W 분리 핸드셰이크, WSTRB, B/R 응답, 금지 주소 SLVERR 테스트 완료.
- 실제 MicroBlaze V AXI Interconnect/Interrupt Controller 연결·Address Editor·BSP 매핑·CPU ISR 실행은 **NOT_RUN**.
- 하드웨어 IRQ는 Level-high이므로 실제 인터럽트 IP의 설정과 ACK/EOI 처리 순서는 별도 통합 검증 필요.

## 4. 전기·실물 시험 보류

- 참고 HC-SR501 모듈 일반 사양: 전원 5~20V DC, OUT 로직 HIGH 3.3V, 모듈 초기 안정화 약 1분. 공급사·모듈 변형별 상이할 수 있음.
- FPGA 입력에 5V 직접 인가 금지. 센서 OUT의 실측 전압과 Basys3 전원 공급 용량/공통 GND를 검토 후 XDC 지정.
- HC-SR501 실제 HIGH 유지 시간과 트리거 H/L 설정에 따라 `event_count`가 사람 수와 같을 수 없으며, 단일 HIGH 지속 구간은 1회 처리.
- Vivado Synthesis/Timing, Vitis CPU, 실제 HC-SR501 센서/LED/IRQ 계측, UVM: **NOT_RUN** (사용자 합성·실물 보류 지시 존중).
- HTML 저장 및 상대 링크 검사와 실제 브라우저 표시 검증은 별도 단계.

## 5. 근거 자료

- [HC-SR501 센서 모듈 데이터시트](https://www.taydaelectronics.com/datasheets/files/A-4432.pdf), 출력 3.3V/전원/초기 안정화·트리거 설정.
- [AMD AXI4-Lite 개념 및 AXI 인터페이스](https://docs.amd.com/r/en-US/ug1037-vivado-axi-reference-guide).
- `Yuul-Jung/soc`의 공통 교육과정 및 검증 기준.

**결론:** 18장 PIR Core **RTL_SIM PASS**, 신규 AXI-Lite 단위 **AXI_SIM PASS**. 실제 MicroBlaze V ISR/실물·합성/타이밍은 검증하지 않음.

# 제2부 18장 — HC-SR501 PIR 감지 + AXI4-Lite IRQ

> RTL Controller + AXI4-Lite Slave **자가검증 시뮬레이션 PASS**.
> Vivado 합성/타이밍, Vitis 타깃, 실제 Basys3/HC-SR501 및 실제 MicroBlaze V 인터럽트 연결은 사용자 요청에 따라 **보류/미검증**.

## 자료

- [제18장 HTML 배포 교재(전체 RTL·테스트벤치)](P2_18_Study_Guide_v01.html)
- [제18장 CI 실행 근거/검증 보고서](../../docs/P2_18_SIM_VERIFICATION_20261111.md)
- [GitHub Actions 자동 검증](https://github.com/Yuul-Jung/amd_soc/actions/workflows/p2-18-pir-irq-verification.yml)
- [HC-SR501 실물 참고 자료](https://www.taydaelectronics.com/datasheets/files/A-4432.pdf)

## RTL 파일

| 파일 | 역할 |
|---|---|
| `rtl/pir_irq_controller.v` | PIR 비동기 2단 동기화 → 3클록 안정화 → 상승 에지 이벤트 → IRQ Pending → CPU ACK |
| `rtl/p2_18_axi_pir_irq_v1_0.v` | 32비트 AXI4-Lite Slave, IRQ mask/arm, W1P 명령, 상태·이벤트 카운트 |
| `tests/tb_pir_irq_controller.v` | warmup, glitch, long HIGH, re-trigger, irq_enable, ACK 우선순위, arm, count-clear 검증 |
| `tests/tb_p2_18_axi_pir_irq.v` | AXI AW/W 분리, WSTRB, STATUS, W1P, 금지 주소 SLVERR |
| `tests/run_rtl_tests.sh` | Icarus Verilog 코어/AXI 독립 테스트 실행 |

## 입력·출력 계층

```text
HC-SR501 OUT (비동기 3.3V 논리, 모듈별 실제 검증 필요)
   → pir_in_async (2-FF clock synchronizer)
   → pir_level (FILTER_CYCLES 동안 안정된 상태)
   → rising event (motion_pulse)
   → event_pending (W1P ACK 전까지 유지)
   → irq_enable & event_pending → irq (CPU level-sensitive interrupt)

AXI4-Lite CPU Control
   → CTRL(ARM/IRQ_ENABLE), CMD(ACK/CLEAR_COUNT)
   → STATUS / EVENT_COUNT / ID
```

- FPGA에 HC-SR501 전원 5V를 직접 공급하는 방향은 보드 전력 예산 및 외부 전원 구성을 검토해야 하며, **센서 전원 VCC와 OUT 신호는 다르다**.
- 모듈 OUT은 흔히 3.3V HIGH지만, 실제 제품의 출력 전압은 반드시 확인. FPGA 입력에는 5V 금지.
- 입력 HIGH는 장시간 지속될 수 있고 트리거 H/L 모드 및 지연 가변저항에 좌우된다.
- `event_count`는 출력 LOW→HIGH 전환 횟수이지 사람 수·움직임 횟수의 참값이 아님.
- 실제 HC-SR501는 전원 후 약 1분 안정화가 필요할 수 있으므로 `WARMUP_CYCLES=6_000_000_000`을 100MHz 기준 기본값으로 사용. 64bit 파라미터를 사용해 32bit 정수 오버플로우를 피한다.
- 리셋 전원 및 센서 전원의 투입 순서는 실제 하드웨어 환경에서 조정해야 한다.

## Register Map — 실제 주소 BaseAddr는 미정

| Offset | 명칭 | R/W | 설명 |
|---|---|---|---|
| 0x00 | CTRL | R/W | bit0 ARM, bit1 IRQ_ENABLE. Reset 0 |
| 0x04 | CMD | W1P | bit0 ACK_EVENT, bit1 CLEAR_COUNT |
| 0x08 | STATUS | R | bit0 WARMUP_READY, bit1 PIR_LEVEL, bit2 EVENT_PENDING, bit3 IRQ |
| 0x0C | EVENT_COUNT | R | 상승 에지 누적, 최대 0xFFFFFFFF |
| 0x10 | ID | R | 0x00180001 |

- `W1P`는 값을 1로 쓰는 그 거래에서 한 클록 펄스를 발생시키며 자동 0으로 복귀한다. 읽기용 명령 레지스터가 아니므로 CMD 읽기는 SLVERR.
- AW와 W 채널이 별도로 도착해도 정상 동작해야 하며 AXI WSTRB를 적용한다.
- 등록되지 않은 주소/읽기전용 주소 쓰기와 비정렬 주소는 SLVERR.
- 새 이벤트 발생과 ACK가 같은 클록에 겹치면 **이벤트 등록을 우선**한다.
- `irq`는 Pulse가 아닌 **Level Interrupt**이다. MicroBlaze V Interrupt Controller 구성에 맞게 Active-high/level 타입을 검증해야 한다.

## 테스트 실행

```bash
# 저장소 루트
bash part02/chapters/P2_18_Lesson/tests/run_rtl_tests.sh
```

GitHub Actions에서 `ubuntu-24.04`, `iverilog`, `vvp`를 사용하여 실제 테스트 실행. 사용자 PC에 설치하지 않음.

## 검증 상태

| Gate | 결과 |
|---|---|
| PIR Core RTL_SIM | **PASS** |
| 신규 AXI4-Lite IP Unit SIM | **PASS** |
| Vivado Synthesis/Timing/IOSTANDARD | **보류 / NOT_RUN** |
| Vitis Target BSP/ELF·실제 CPU IRQ 핸들러 | **보류 / NOT_RUN** |
| Basys3+HC-SR501 실물 감지 | **보류 / NOT_RUN** |
| UVM | **NOT_RUN** |
| 브라우저 시각 렌더 | **NOT_RUN** |

기존 제2부 01~17장 RTL·HTML 및 성공 XPR을 보존하며, `main` 브랜치를 건드리지 않는다.

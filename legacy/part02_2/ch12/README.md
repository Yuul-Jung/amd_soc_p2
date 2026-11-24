## 12.1~12.4 파생 실습 (2026-11-11 신규)

기존 12장과 01~10장 RTL을 보존하고 네 개의 누적 실습을 별도 HTML로 제공한다.

| 파생 실습 | 전체 학생용 HTML | 현재 검증 |
|---|---|---|
| **12.1 Vivado IP 실제 SoC 통합** | [12.1](labs/P2_12_1_Lab_v04.html) | 기존 RTL·AXI 단위 PASS / 실제 Vivado 통합 NOT_RUN |
| **12.2 ULN2003 전원·핀 배선** | [12.2](labs/P2_12_2_Lab_v04.html) | 배선·XDC 후보 작성 / 보드 전기 검사 NOT_RUN |
| **12.3 정·역회전 및 스텝 수** | [12.3](labs/P2_12_3_Lab_v04.html) | Vitis 스모크 C 작성 / 실제 모터 회전 NOT_RUN |
| **12.4 가감속 기능 확장** | [12.4](labs/P2_12_4_Lab_v04.html) | **HOST_C·RTL_SIM·확장 AXI_SIM PASS**, 실제 보드 NOT_RUN |

- [파생 실습 전체 파일·실행 순서](labs/README.md)
- [12.1~12.4 검증 결과 및 실제 CI 증거](../../docs/P2_12_4_SIM_VERIFICATION_20261111.md)
- [12.4 실제 가감속 RTL·AXI 확장 시험 실행](https://github.com/Yuul-Jung/amd_soc/actions/runs/42938368784)

기존 `stepper_core.v` / `p2_12_axi_stepper_v1_0.v`는 변경하지 않고, 12.4에 별도의 `stepper_ramp_core.v` / `p2_12_axi_stepper_v1_1.v`를 추가한다. 새 AXI ID는 `0x000C0002`.

---

# 제2부 12장 — 28BYJ-48 유니폴러 스테핑 모터 + ULN2003

> 상태: **HOST_C + RTL_SIM + 신규 AXI_SIM 통과** (GitHub Actions, 2026-11-11).
> Vivado 합성·타이밍·Vitis BSP·Basys3 실제 구동은 **NOT_RUN**.
> 제2부 01~10장 및 기존 L298N Motor IP/RTL을 수정하지 않음.

## 배포 자료

- [12장 HTML 학습안내서](P2_12_Study_Guide.html)
- [검증 보고서](../../docs/P2_12_SIM_VERIFICATION_20261111.md)
- [GitHub Actions 검증 실행](https://github.com/Yuul-Jung/amd_soc/actions/runs/42934931469)
- [후반부 테크트리](../../docs/P2_11_20_ROADMAP.md)

## 소스 구성

| 파일 | 용도 |
|---|---|
| `rtl/stepper_core.v` | 독립 4상 여자 시퀀스·스텝 수·주기·정역회전·STOP 제어 |
| `rtl/p2_12_axi_stepper_v1_0.v` | 신규 AXI4-Lite 슬레이브 및 Core 연결 |
| `sw/stepper_logic.c/.h` | 실제 AXI 클록 기준 주기 계산 |
| `sw/stepper_axi.c/.h` | `Xil_Out32/In32` 레지스터 접근 함수 |
| `tests/tb_stepper_core.v` | Half/Full, 정/역, 오류/STOP, 정확한 코일 출력 |
| `tests/tb_p2_12_axi_stepper.v` | AXI AW/W 분리, WSTRB, 상태, BUSY, 오류 응답 |
| `tests/test_stepper_logic.c` | 50/100MHz 등 설정 변환 확인 |
| `tests/run_rtl_tests.sh` | Icarus Verilog 실제 실행 |
| `tests/run_host_tests.sh` | GCC 호스트 단위 테스트 |

## 모듈 동작 계약

- `coil_o[0]` → ULN2003 IN1, `coil_o[1]` → IN2, `coil_o[2]` → IN3, `coil_o[3]` → IN4.
- Full-step(2상 여자): `0011→0110→1100→1001`.
- Half-step(1-2상 여자): `0001→0011→0010→0110→0100→1100→1000→1001`.
- 4비트 표현은 **`{IN4,IN3,IN2,IN1}`** 순서임.
- 방향 반전 시 시퀀스를 역순으로 순회. 첫 상태는 양 방향 모두 phase0 기준.
- 명령 START 시 `cfg_steps`, `cfg_step_period`, 방향·모드를 래치하며 동작 중 변경은 현재 동작에 영향 없음.
- END 처리 후 코일을 한 클록 뒤 해제, STOP은 출력에서 조합적으로 차단.
- `steps_done`는 **명령상 전기적 여자 횟수**이며 기구적 회전량을 확인하지 않음.
- `MIN_STEP_CYCLES=200000`은 **100MHz에서 2ms**를 뜻하는 기본값이며 실제 IP 클록이 다르면 파라미터를 조정한다. 테스트벤치는 시뮬레이션을 위해 MIN=2로 축소한다.
- 가감속(Ramp)은 초기 버전 **미구현**. 시뮬레이션으로 검증된 범위는 고정 스텝 주기.
- `C_S_AXI_DATA_WIDTH=32`, `C_S_AXI_ADDR_WIDTH>=6`.

## Register Map

| Offset | 이름 | 접근 | 설명 |
|---|---|---|---|
| `0x00` | STEP_COUNT | RW | 1~100000 권장, RTL 최대 32비트 양수 |
| `0x04` | STEP_PERIOD | RW | 1스텝 대기 클록 수, MIN 이상 |
| `0x08` | CONTROL | RW | bit0 reverse, bit1 half_step |
| `0x0C` | COMMAND | WO | `1` START, `2` STOP |
| `0x10` | STATUS | RO | bit0 busy, bit1 done_sticky, bit2 error_sticky |
| `0x14` | STEPS_DONE | RO | 누적 실행 스텝 수(마지막 START 이후) |
| `0x18` | ID | RO | `0x000C0001` |
| `0x1C` | MIN_STEP_TICKS | RO | 해당 IP 최소 스텝 주기 |

## Ubuntu 실행

```bash
cd part02/chapters/P2_12_Lesson
bash tests/run_host_tests.sh
bash tests/run_rtl_tests.sh
```

GitHub Runner에는 `iverilog`를 설치하여 실제 시뮬레이션 실행했으나, 사용자의 로컬 PC에는 설치하지 않았다.

## Vivado 실제 통합 (미완료)

1. 별도 XPR `soc_ip_design_12`을 기존 프로젝트의 **복제본**으로 만든다.
2. `stepper_core.v` + `p2_12_axi_stepper_v1_0.v`를 독립 사용자 IP로 패키징.
3. MicroBlaze V AXI Interconnect에 신규 Slave를 연결하고 Address Editor 실제 주소 지정.
4. FPGA 외부 포트 4개와 Basys3 XDC 핀은 **기존 JB L298N 포트와 중복되지 않는 여유 디지털 포트**를 선정한다.
5. 외부 5V 전원으로 ULN2003 모터 코일을 공급하고 Basys3와 공통 GND. FPGA 3.3V 출력과 ULN2003 입력 회로 호환을 모듈별 확인.
6. Vitis C에서 실제 주소·클록 확인 후 STOP/START/STATUS 연동. 기존 RUN/MODE, UART 입력 우선순위는 아직 미통합.
7. Vivado timing, Vitis actual BSP, 보드 파형·회전 실측 근거를 별도 기록하고 통과 여부 판정.

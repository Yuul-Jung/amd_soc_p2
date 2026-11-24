# 제2부 12장 파생 실습 — 12.1~12.4

> 2026-11-11 기준: 12.1~12.3은 **현장 실습용 절차·코드 준비 상태**, 12.4는 **HOST_C / RTL_SIM / AXI_SIM PASS** 상태. 보드·Vivado·Vitis 실제 실행은 확인되지 않음.
>
> 기존 12장 `stepper_core.v`, `p2_12_axi_stepper_v1_0.v` 및 기존 01~10장 성공 자산은 수정하지 않는다.

## 실습별 진입 문서

| 실습 | 교육 주제 | 배포용 HTML | 실행/검증 |
|---|---|---|---|
| **12.1** | Vivado 사용자 AXI IP 패키징·Block Design 연결 | [12.1 HTML](P2_12_1_Lab_v04.html) | 실제 XPR/BD, Clock/Reset, Address Editor, Synthesis/Timing: NOT_RUN |
| **12.2** | ULN2003 5V 배선·IN1~IN4·XDC | [12.2 HTML](P2_12_2_Lab_v04.html) | [JC 후보 XDC](12_2_jc_candidate.xdc), 실제 핀 충돌·전기 검사: NOT_RUN |
| **12.3** | 정/역 Full/Half 회전·스텝 수·위치 시험 | [12.3 HTML](P2_12_3_Lab_v04.html) | [Vitis 스모크 C](12_3_board_smoke.c), 실제 보드: NOT_RUN |
| **12.4** | 가감속(주기 감소 → 유지 → 증가) 독립 RTL/AXI v1.1 | [12.4 HTML](P2_12_4_Lab_v04.html) | HOST_C / RTL_SIM / AXI_SIM: PASS, Vivado/Vitis/보드: NOT_RUN |

## 파일 구성

```text
part02/chapters/P2_12_Lesson/
├── rtl/
│   ├── stepper_core.v                 # 12장 원본 유지
│   ├── p2_12_axi_stepper_v1_0.v      # 12장 원본 유지
│   ├── stepper_ramp_core.v            # 12.4 신규
│   └── p2_12_axi_stepper_v1_1.v      # 12.4 신규
├── sw/
│   ├── stepper_logic.c/.h             # 12장 원본 유지
│   ├── stepper_axi.c/.h               # 12장 원본 유지
│   └── stepper_ramp_logic.c/.h        # 12.4 신규
├── tests/
│   ├── tb_stepper_core.v              # 12장 원본 유지
│   ├── tb_p2_12_axi_stepper.v        # 12장 원본 유지
│   ├── tb_stepper_ramp_core.v         # 12.4 신규
│   ├── tb_p2_12_4_axi_ramp.v         # 12.4 신규
│   ├── run_ramp_tests.sh
│   └── run_ramp_host_tests.sh
└── labs/
    ├── P2_12_1_Lab_v04.html
    ├── P2_12_2_Lab_v04.html
    ├── P2_12_3_Lab_v04.html
    ├── P2_12_4_Lab_v04.html
    ├── 12_2_jc_candidate.xdc
    ├── 12_3_board_smoke.c
    ├── 12_4_ramp_vitis_example.c
    └── README.md
```

## 실행 방법

```bash
# 프로젝트 루트에서 실행: 12장 기본 기능 전체 회귀 검사
bash part02/chapters/P2_12_Lesson/tests/run_host_tests.sh
bash part02/chapters/P2_12_Lesson/tests/run_rtl_tests.sh

# 12.4 가감속 기능 추가 검사
bash part02/chapters/P2_12_Lesson/tests/run_ramp_host_tests.sh
bash part02/chapters/P2_12_Lesson/tests/run_ramp_tests.sh
```

설치 확인: `iverilog -V`, `gcc --version`. CI는 GitHub-hosted Ubuntu runner에 Icarus Verilog 12.0을 설치해 실행한다. **사용자 Ubuntu PC에 설치한 것은 아니다.**

## 설계 및 검증 계약

- 12.1: 실제 연결 전에 P2-12 IP와 기존 P2-07 L298N의 AXI 주소 및 I/O 소유권을 확인한다. 사용자 Top에는 기능 로직 금지.
- 12.2: 제안 핀 JC1=K17, JC2=M18, JC3=N17, JC4=P18은 Digilent 공식 Master XDC를 따른다. **현행 프로젝트에서 미사용이라는 증거는 없음**. 중복 배정 시 XDC 변경 보류.
- 12.3: 실제 XSA/BSP에서 확인한 baseaddr·UART·AXI 클록만 사용한다. `Xil_Out32`는 AXI BRESP 예외를 C로 반환하지 않는다. `STEPS_DONE`은 구동 신호의 스텝 이벤트 수이며 실제 모터 축 회전 증거가 아니다.
- 12.4: `stepper_ramp_core.v` + `p2_12_axi_stepper_v1_1.v`은 원본의 독립 확장판이다. 새 v1.1 ID는 `0x000C0002`; 레지스터 0x20/24/28/2C를 추가한다.
- 12.4: `start_period - cruise_period`를 `ramp_steps`로 나눈 tick이 정수인 설정만 C helper에서 허용한다. RTL 코어 단독 구동 시에도 유효 범위·포화 처리를 적용한다.
- 전기 안전: 모터의 5V 전원은 ULN2003로 공급하고 Basys3 I/O에는 5V를 넣지 않는다. 입력 로직 임계값은 실제 모듈 회로 확인.
- VERIFY 기준은 `Yuul-Jung/soc`의 VALIDATION.md를 따른다. HOST_C, RTL_SIM, AXI_SIM, SYNTH_TIMING, VITIS_TARGET, BOARD, WEB, UVM을 서로 별도 기록.

## 검증 링크

- [12장 기존 Icarus C/RTL/AXI PASS](https://github.com/Yuul-Jung/amd_soc/actions/runs/42935110974)
- [12.4 최초 호스트 C+RTL+AXI PASS](https://github.com/Yuul-Jung/amd_soc/actions/runs/42937205860)
- [12.4 검증 보고서](../../../docs/P2_12_4_SIM_VERIFICATION_20261111.md)

**미실행 게이트:** Vivado IP Packager, 합성, 타이밍, XSA, Vitis ELF, 모터/전원 실측, 브라우저 GUI 전체 표시. 미검증을 성공이라고 보고하지 않는다.

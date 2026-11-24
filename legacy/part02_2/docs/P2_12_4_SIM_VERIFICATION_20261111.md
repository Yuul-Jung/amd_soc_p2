# 제2부 12.1~12.4 파생 실습 검증 기록 (2026-11-11)

> 본 기록은 **실제로 수행한 GitHub 호스트 C/RTL/AXI 시뮬레이션**과 **아직 수행하지 않은 Vivado/Vitis/실물 동작**을 구분한다. 사용자 로컬 PC 또는 Basys3의 원격 제어·설치는 수행하지 않았다.

## 1. 실습별 결과

| 실습 | 작성 결과 | 검증 완료 범위 | 미검증 범위 |
|---|---|---|---|
| 12.1 AXI IP SoC 연결 | HTML 실습, 기존 IP 패키징/Block Design/Address Editor 상세 절차 | P2-12 기존 IP의 RTL/AXI 단위 시뮬레이션 PASS | 실제 Vivado 프로젝트 IP Packager, 주소/BD 연결, Synthesis, Timing, XSA |
| 12.2 ULN2003 연결 | HTML 실습, JC1~JC4 후보 XDC, 별도 5V 배선 점검표 | Digilent 공식 JC 핀명·핀번호 문헌 대조 | 실제 핀 점유 상태, 3.3V 입력 호환, 전원·배선 측정 |
| 12.3 정·역회전·스텝 수 | HTML 실습, Vitis C 보드 스모크 프로그램 | P2-12 RTL/AXI 테스트의 논리적 정/역·스텝 카운트 PASS | 실제 Vitis BSP/ELF, UART 응답, 모터 회전 및 각도 실측 |
| 12.4 가감속 확장 | HTML 실습, 신규 RTL 코어, 별도 AXI v1.1, C 계산 함수, Verilog TB, Vitis 예시 | **HOST_C / RTL_SIM / AXI_SIM 모두 PASS** | 합성·자원/타이밍, 신버전 BD 통합, 실물 가감속 및 탈조 확인 |

## 2. 실제 실행 증거

- 12장 원본 회귀: [GitHub Actions #42935110974](https://github.com/Yuul-Jung/amd_soc/actions/runs/42935110974) — Host, Full/Half 정·역, AXI 정상/오류.
- 12.4 가감속 신기능: [GitHub Actions #42937205860](https://github.com/Yuul-Jung/amd_soc/actions/runs/42937205860) — `P2_12_4_HOST_RAMP_LOGIC PASS`, `P2_12_4_RAMP_FWD PASS`, `P2_12_4_RAMP_REV PASS`, `P2_12_4_STOP PASS`, `P2_12_4_INVALID_CONFIG PASS`, `P2_12_4_AXI_RAMP_BASIC PASS`, `P2_12_4_AXI_STOP PASS`, `P2_12_4_AXI_ERROR_RESP PASS`, `P2_12_4_AXI_STEPPER PASS`.
- 12.4 overflow-safe period 비교 수정 후: [GitHub Actions #42938368784](https://github.com/Yuul-Jung/amd_soc/actions/runs/42938368784) — 변경된 RTL을 포함한 CI 성공.

GitHub Actions 러너는 Ubuntu 24.04 + GCC + Icarus Verilog 12.0 / vvp를 사용했다. **UVM은 설치·실행하지 않았으며 UVM_PASS가 아니다.**

## 3. 최초 실패 및 수정

1. 초회 12.4 RTL 테스트는 `tb_stepper_ramp_core.v:77 stop state`에서 실패. 테스트벤치가 `stop_pulse`를 클록 상승 에지 전에 내린 것이 원인으로, STOP을 상승 에지까지 유지하도록 테스트벤치 수정. 원본 12장 RTL 변경 없음.
2. 호스트 C 가감속 설정 시험에서 정수로 나누어 떨어지지 않는 DELTA 값을 성공으로 예상한 검증 사례를 수정. 실제 함수는 유효하지 않은 구성을 거부한다.
3. 가감속 RTL의 `cruise_period + delta_period` 등 중간 비교 연산의 overflow 위험을 제거하기 위해 포화 판단을 차이 연산으로 변경 (`e1769b0a39b8fe9811e1f4528faa048782ee37a5`), CI 재통과.
4. 수정한 파일은 신규 12.4 RTL·TB·C 및 신규 학습 문서에 한정한다. 기존 `stepper_core.v`, `p2_12_axi_stepper_v1_0.v`, 제2부 01~10장 및 보존 XPR 미변경.

## 4. 주요 설계 계약

- Top은 보드 핀 연결용 Shell이며 기능·판정 로직 없음.
- 12.4 AXI IP는 `p2_12_axi_stepper_v1_1.v`, ID `0x000C0002`이며 원본 v1.0을 덮어쓰지 않는다.
- 새 Register Map: 0x20 CRUISE_PERIOD, 0x24 DELTA_PERIOD, 0x28 RAMP_STEPS, 0x2C ACTIVE_PERIOD(읽기 전용).
- 펄스 주기 기준으로 가속·감속하며 물리적으로 정확한 선형 가속도나 실제 스텝 누락 방지를 보증하지 않는다.
- Host 계산 함수는 시작/정속 주기의 차이가 `ramp_steps`로 나누어떨어지는지 검증한다. AXI를 통한 임의 쓰기 값 전체의 유효성 검증이나 하드웨어 운동 안정성 검증은 아직 완료되지 않았다.
- JC1..JC4 후보 핀: K17, M18, N17, P18. 실제 기존 11장 서보/다른 Pmod와 충돌 여부를 확인하기 전 사용 확정하지 않는다.
- ULN2003 모터 전원: 외부 안정화 5V + Basys3 공통 GND. FPGA 5V 직접 인가 금지.
- 실제 보드에서 관찰한 `STEPS_DONE`은 논리 구동 이벤트 수이지 출력축 각도 계측값이 아니다.

## 5. 최종 점검 상태

- STATIC: 신규 코드·문서 구조 점검 완료(실제 Vivado 정적 검사는 미실시).
- HOST_C: **PASS** (12.4)
- RTL_SIM: **PASS** (12장 고정 주기 + 12.4 가감속)
- AXI_SIM: **PASS** (12장 원본 IP + 12.4 확장 IP 단위)
- VIVADO_SYNTH_TIMING: **NOT_RUN**
- VITIS_TARGET: **NOT_RUN**
- BOARD: **NOT_RUN**
- WEB_RENDER: **NOT_RUN** (HTML GitHub 저장은 확인, 브라우저 시각 렌더 검사는 미실시)
- UVM: **NOT_RUN**

**판정:** 12.1~12.4 실습자료·코드 작성은 완료. 12.4 HOST/RTL/AXI 단위 검증까지 완료. 실물 및 Vivado/Vitis Gate는 남아 있다.

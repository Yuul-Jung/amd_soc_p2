# 제2부 12장 28BYJ-48 + ULN2003 — 시뮬레이션 검증 기록

- 검증일: 2026-11-11 (KST)
- 검토 브랜치: `work/part02-second-half-20261110`
- 근거: [실행 #42935110974](https://github.com/Yuul-Jung/amd_soc/actions/runs/42935110974)
- 실행 커밋: `ec02f1f04fc2b18c178a442076611abfdbb666d5`
- 실행 환경: GitHub Actions `ubuntu-24.04`, `gcc`, `iverilog` 12.0, `vvp`.
- 해당 CI는 원격 GitHub Runner에서 도구를 설치/실행한 결과이며 사용자의 로컬 Ubuntu에 설치한 것이 아님.

## 1. 실제 결과

| 검증 Gate | 결과 | 실행 증거 |
|---|---|---|
| HOST_C | **PASS** | `P2_12_HOST_STEPPER_LOGIC PASS` |
| RTL_SIM | **PASS** | `HALF_FORWARD PASS`, `HALF_REVERSE PASS`, `FULL_FORWARD PASS`, `FULL_REVERSE PASS` |
| RTL_SIM 오류/정지 | **PASS** | `BUSY_REJECT_STOP PASS`, `INVALID_CONFIG PASS`, `P2_12_RTL_STEPPER_CORE PASS` |
| AXI_SIM (신규 P2-12 IP 단위) | **PASS** | `P2_12_AXI_BASIC PASS`, `P2_12_AXI_INVALID_CONFIG PASS`, `P2_12_AXI_STOP PASS`, `P2_12_AXI_ERROR_RESP PASS`, `P2_12_AXI_STEPPER PASS` |
| 11장 기존 회귀 | **PASS** | P2-11 독립 GitHub Actions 별도 성공 |
| 합성 / 타이밍 | **NOT_RUN** | Vivado 실제 프로젝트 필요 |
| Vitis 타깃 C / BSP / ELF | **NOT_RUN** | 실제 XSA/BSP·MicroBlaze V 타깃 필요 |
| Basys3 + ULN2003 + 28BYJ-48 실물 | **NOT_RUN** | 물리 배선/계측 필요 |
| UVM | **NOT_RUN** | 본 장은 self-checking Verilog TB 사용 |
| GitHub Pages HTML 실물 렌더링 | **NOT_RUN** | 브라우저 표시 및 공개정보 노출 점검 필요 |

## 2. 최초 실패 및 수정 이력

- 최초 12장 RTL 실행 [#42934354460](https://github.com/Yuul-Jung/amd_soc/actions/runs/42934354460)은 `tb_stepper_core.v:53 done/idle release`에서 실패.
- 원인: RTL 설계는 DONE을 한 클록 유지한 후 코일을 0으로 해제하는데, TB가 마지막 스텝 출력 직후 다음 클록이 오기 전에 코일 해제를 검사함.
- 조치: **테스트벤치의 점검 시점만 수정** (`c33d1d3d747bbb26f3cbeef92a3605de7780b2aa`). 해당 문제로 `stepper_core.v`를 임의 변경하지 않음.
- 이후 CORE RTL 및 신규 AXI 레지스터 테스트가 통과. 신규 AXI4-Lite IP의 START/STOP/STATUS/오류 응답은 실제 Icarus 시뮬레이션에서 검증.
- 최초 성공 증거 커밋을 이후 배포자료 추가 작업과 구별하여 기록함.

## 3. 모듈별 검증 범위

### RTL 코어

- 8상 Half-step과 4상 Full-step 코일 순서, 정·역회전.
- START 시 동작 설정 래치 및 스텝 수 누적.
- Busy 상태의 중복 START 거부, STOP 즉시 출력 마스킹 및 동기 상태 정지.
- 0 step과 최소 스텝 주기 미만의 요청 거부.
- 완료 후 자동 코일 해제.

### AXI4-Lite Slave

- 분리 도착하는 AW/W 주소·데이터 핸드셰이크, WSTRB 부분 쓰기.
- ID, MIN_STEP_TICKS, 상태, 스텝 수, 제어 설정 읽기.
- START 명령, 완료/오류 sticky, STOP, 비정상 설정·금지 주소 SLVERR.

### 호스트 C

- 50MHz/100MHz에서 ms→tick 변환, 정/역·Full/Half 설정 비트 생성.
- 0 step, 짧은/긴 주기, 잘못된 설정 및 null pointer 거부.
- **해당 C 단위 테스트는 실제 Vitis/AMD BSP 빌드가 아님**. `stepper_axi.c` 타깃 코드는 별도 검증 필요.

## 4. 미완성·주의

1. **가감속 프로파일 미구현**: 현 단계는 설정된 동일 기간의 스텝을 반복. 고속 구동 시 탈조 가능. 향후 감속/가속 FSM을 별도 확장.
2. **절대 위치 미검증**: 스텝 카운트는 코일 여자 이벤트이며 기계적 각도/위치 추정. 28BYJ-48 변형의 감속비 편차, 백래시 및 실물 부하를 반영하지 못함.
3. **새 SoC 전체 연결 미검증**: 04장 PWM·07장 L298N과 P2-12 신규 IP를 합친 Vivado Block Design, 주소 편성, XDC, 인터럽트 및 실제 Vitis UART 명령은 향후 통합 시험 필요.
4. **5V 전원 안전**: 모터는 ULN2003으로 드라이브, FPGA는 3.3V 제어 신호만 출력. 실제 입력 임계값과 모듈 회로 및 접지/전원 배선 확인 필요.
5. `stepper_axi_start`에 사용한 `Xil_Out32`는 AXI BRESP 오류를 C 반환값으로 전달하지 않음. 하드웨어 최소 주기와 STATUS 등을 추가 확인한 뒤 통합.

## 5. 근거 출처

- [28BYJ-48+ULN2003 회전·배선 참고](https://docs.circuit.rocks/motors/28byj-48/)
- [2상 Full-step 순서 참고](https://learn.advaspire.io/arduino/level-3/ARD-L03-12-28byj48-and-uln2003)
- 프로젝트 공통 기준: `Yuul-Jung/soc`의 `CURRICULUM.md`, `MIGRATION.md`, `VALIDATION.md`, `COLLABORATION.md`.

**검증 결론:** P2-12는 C 계산/HOST + RTL Core + 신규 AXI Slave 시뮬레이션 PASS 상태. 실제 하드웨어 동작 완료 아님.

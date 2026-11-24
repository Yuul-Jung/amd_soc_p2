# 제2부 20장 — 실제 기존 RTL 재사용 종합 과제 검증 보고서

- 날짜: 2026-11-11 KST
- 관리 기준: `Yuul-Jung/soc`의 `CURRICULUM.md`, `MIGRATION.md`, `VALIDATION.md`, `COLLABORATION.md` 최신 파일 및 SHA 확인 후 개발.
- 자료 저장소/브랜치: `Yuul-Jung/amd_soc` / `work/part02-second-half-20261110`
- 최초 세 모듈 결합 실행: [GitHub Actions #42955042239](https://github.com/Yuul-Jung/amd_soc/actions/runs/42955042239) PASS.
- BME/RTC 시나리오 추가 후 재검증: **[GitHub Actions #42955226763](https://github.com/Yuul-Jung/amd_soc/actions/runs/42955226763) PASS**.
- 재검증 커밋: `a5d5cd666d80b0d52c4c513eecbe1c9cf2a75dd6`.
- 환경: GitHub-hosted `ubuntu-24.04`, Icarus Verilog/vvp.
- 사용자 로컬 Ubuntu에 시뮬레이터 설치·Vivado 합성·실제 Basys3 보드 연결은 하지 않음.

## 1. 무엇을 실제로 통합했는가

단순 동일 명칭 복사본이 아니라, 실제 이전 장의 RTL 소스를 파일 경로로 직접 컴파일하여 인스턴스화한 증거:

| 기존 장 | 실제 RTL 원본 | 인스턴스/역할 | 기존 파일 수정 |
|---|---|---|---|
| **P2-12.4** | `part02/chapters/P2_12_Lesson/rtl/stepper_ramp_core.v` | `soc20_integrated_core.u_motor`; 28BYJ-48 가감속 모터 논리 | 없음 |
| **P2-18** | `part02/chapters/P2_18_Lesson/rtl/pir_irq_controller.v` | `soc20_integrated_core.u_pir`; HC-SR501 2FF+IRQ | 없음 |
| **P2-19** | `part02/chapters/P2_19_Lesson/rtl/environment_policy.v` | `soc20_integrated_core.u_env`; 센서 우선순위·경보·표시 | 없음 |
| **P2-20 신규** | `part02/chapters/P2_20_Lesson/rtl/soc20_safety_supervisor.v` | `soc20_integrated_core.u_safety`; 데이터 유효기간·출력 차단·명시적 재가동 | 신규 |
| **P2-20 신규** | `part02/chapters/P2_20_Lesson/rtl/soc20_integrated_core.v` | 위 네 기능 모듈 연결 | 신규 |

Top Shell, Pin/XDC, Vivado Block Design, AXI Interconnect, MicroBlaze V CPU 및 I/O 표준은 이번 시뮬레이션에 포함하지 않음.

## 2. 실제 실행된 self-checking 테스트

| 검증 항목 | 결과 | CI 출력 |
|---|---|---|
| Reset 기본 모터 안전 차단·무허가 Start 거부 | **RTL_SIM PASS** | `P2_20_DEFAULT_SAFE_INTERLOCK_PASS` |
| **기존 12.4 원본 stepper**의 실제 코일 변화·스텝 진행 | **RTL_SIM PASS** | `P2_20_EXISTING_STEPPER_INTEGRATION_PASS` |
| **기존 18장 원본 PIR**의 Pending/IRQ 이후 Motor Stop 및 Coil Off | **RTL_SIM PASS** | `P2_20_PIR_IRQ_MOTOR_STOP_PASS` |
| PIR ACK 이후 모터 자동 재가동 금지 | **RTL_SIM PASS** | `P2_20_LATCHED_FAULT_NO_AUTO_RESTART_PASS` |
| Clear Fault → Explicit ARM → 별도 Motor Start | **RTL_SIM PASS** | `P2_20_MANUAL_REARM_PASS` |
| Sensor Valid 갱신 중단으로 Sample Age 만료 시 모터 차단 | **RTL_SIM PASS** | `P2_20_STALE_SENSOR_FAIL_SAFE_PASS` |
| 신선한 샘플만 들어와도 Fault 자동 해제 금지 | **RTL_SIM PASS** | `P2_20_FRESH_SAMPLE_DOES_NOT_AUTO_REARM_PASS` |
| **기존 19장 원본 환경 정책**의 BME(가상 보정값) 우선 및 RTC 표시 | **RTL_SIM PASS** | `P2_20_EXISTING_POLICY_BME_RTC_PASS` |
| 제20장 세 기존 RTL + 신규 Supervisor 통합 | **RTL_SIM PASS** | `P2_20_INTEGRATED_SOC_RTL PASS` |

테스트 파라미터: `PIR_WARMUP_CYCLES=5`, `MAX_AGE_CYCLES=55`, `MOTOR_MIN_STEP_CYCLES=3` 등 축소하여 빠르게 이벤트 논리를 확인했으며, 실제 60초 Warm-up·100MHz에서의 긴 시간 안정성·하드웨어 안전 등은 검증하지 않음.

## 3. 실패 이력 및 조치

- BME/RTC 추가 회귀 실행 [#42955151641](https://github.com/Yuul-Jung/amd_soc/actions/runs/42955151641)은 시뮬레이션이 아니라 테스트벤치 **컴파일 실패**: `display_page`, `display_source`라는 잘못된 로컬 신호 식별자 참조.
- 테스트벤치의 실제 wire 이름 `page`, `source`에 일치하도록 수정. 기존 생산 RTL/모듈 변경 없음.
- 실행 [#42955226763](https://github.com/Yuul-Jung/amd_soc/actions/runs/42955226763)에서 전체 PASS 재확인.

## 4. 설계 안전 규칙과 제한

1. CRC/Checksum/OSF를 **상류 모듈이 이미 검증한 Valid**만 신뢰한다는 계약. TB는 Valid를 직접 주입한다. 실제 센서 검증 경로 연결은 NOT_RUN.
2. 모터를 허용하려면 `fresh && !fault_latched && !alarm_active && armed`가 동시에 만족되어야 한다. 모터 Start는 `actuator_permit`가 1일 때만 전달된다.
3. PIR Pending·고온·고습 경보 시 `actuator_permit`가 LOW가 되고 `motor_stop || !actuator_permit`가 활성화되어 모터 Coil이 LOW로 강제 출력된다.
4. Sample Age 기준은 새 유효 센서값으로 재설정되며, 지정 시간 내 샘플이 없으면 Fresh=0으로 떨어져 즉시 모터 출력이 차단된다. 실제 원본 센서 드라이버는 이 입력의 Valid 생성 책임.
5. Fault Clearing 또는 PIR IRQ ACK **자체로는 자동 모터 재시작이 불가능**. 명시적으로 Fault Clear 후 ARM/Start가 필요하다.
6. **Safety certification 부재**: 본 설계는 교육용 위험 회피 정책일 뿐 비상정지, 산업 설비 보호 기능, 전기적으로 Fail-safe인 안전 장치가 아니다.
7. 샘플 Source 선별은 19장 정책이 수행하고, 신선도 감시는 현재 모든 온도 소스의 Valid OR를 기준으로 한다. 샘플별 품질·센서별 Age/Timeout·BME 보정 성공·측정 시각 일치·상류 Status 오류까지 추적하는 정밀한 Data Valid Contract는 미구현.
8. 12장 stepper coil의 실제 ULN2003/28BYJ-48 전원/핀 분리, CLK, XDC, 외부 PWM/servo 및 릴레이 연결도 미실시.

## 5. 반드시 분리할 미완료 통합 범위

| 구성 요소 | 상태 |
|---|---|
| 12.4 stepper + 18 PIR + 19 environment_policy **실제 RTL 결합** | **PASS** |
| 13장 MFRC522 RFID 실제 태그 UID·SPI 처리 | **미구현/NOT_RUN** |
| 14장 LCD1602/2004 실제 I²C 문자 송신 | **미구현/NOT_RUN** |
| 16장 DS3231 실제 I²C PHY/Repeated-START | **미구현/NOT_RUN** |
| 19장 BME280 Bosch 보정 계수·Compensation | **미구현/NOT_RUN** |
| 14/16/19장 I²C 공용 버스 마스터·중재 | **미구현/NOT_RUN** |
| 11장 SG90 및 12장 ULN2003의 실제 보드 동시 출력 | **NOT_RUN** |
| MicroBlaze V Address Editor·AXI IP Interconnect·IRQ 컨트롤러 | **미구현/NOT_RUN** |
| Vitis 타깃 BSP/ELF·UART Command Parser/Response | **NOT_RUN** |
| Vivado Synth/Implementation/Timing·XDC 충돌 | **보류/NOT_RUN** |
| Basys3 실제 센서·액추에이터 및 전원/전압 | **보류/NOT_RUN** |
| UVM | **NOT_RUN** |
| HTML Browser Render | **NOT_RUN** (GitHub 링크·코드 작성과 구분) |

## 6. 후속 정합 조건

- 전체 11~20장 소스/레지스터/핀 소유권 매트릭스, 3.3V 핀 호환성·외부 전원·기존 성공 XPR 보존.
- **I²C read/write/repeated-start 공유 마스터** 구현 후 LCD/RTC/BME280의 0x27/0x68/0x76 또는 0x77 장치 간 동시성·타임아웃/버스 오류 검증.
- BME280 보정 완료 값 Valid 확인과 환경 정책의 Sensor Age/Quality 계약 정밀화.
- UART/IRQ/CPU AXI4-Lite 통합·LED/FND 의미 관리·액추에이터 안전 정책 검증.
- 실제 Vivado 합성/Timing, Vitis, Basys3 실물 시험은 사용자가 보류 해제한 뒤 독립 Gate로 수행.

**최종 판정:** P2-20 기존 3개 장의 재사용 RTL과 신규 Safety Supervisor를 결합한 **제한된 통합 RTL_SIM PASS**. 전체 제2부 20장 기능이 모두 연결된 Full SoC 또는 실물 성공이 아님.

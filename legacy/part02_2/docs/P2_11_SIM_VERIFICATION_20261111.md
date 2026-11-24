# P2-11 SG90 PWM — 실제 Host C / RTL 시뮬레이션 검증

- 기준일: 2026-11-11 (KST)
- 저장소: `Yuul-Jung/amd_soc`
- 브랜치: `work/part02-second-half-20261110` (검토용, `main` 유지)
- 마지막 **증거 확보 실행**: [GitHub Actions Run #42933313146](https://github.com/Yuul-Jung/amd_soc/actions/runs/42933313146)
- 실행 커밋: `9b0a48a966923fe3e97e9cff7d2164913f2ca5ce`
- 러너: GitHub-hosted `ubuntu-24.04`, `iverilog` 12.0 (Icarus Verilog), `gcc`

## 1. 실제 실행 로그

| Gate | 실행 스크립트 또는 모듈 | 결과 | 실제 로그의 증거 |
|---|---|---|---|
| HOST_C | `part02/chapters/P2_11_Lesson/tests/run_host_tests.sh` | **PASS** | `P2_11_HOST_SERVO_LOGIC PASS`, `P2_11_HOST_SERVO_COMMAND PASS` |
| RTL_SIM (11장) | `part02/chapters/P2_11_Lesson/tests/run_rtl_tests.sh` | **PASS** | `P2_11_RTL_PWM_REUSE PASS` |
| RTL_SIM (04장 원본 PWM) | `part02/chapters/P2_04_Lesson_20261106/tests/run_rtl_tests.sh` / `tb_pwm_core.v` | **PASS** | `RTL_SIM_pwm_core PASS` |
| AXI_SIM (04장 기존 IP) | 동일 스크립트 / `tb_p2_04_axi_pwm.v` | **PASS** | `RTL_SIM_p2_04_axi_pwm PASS` |
| AXI_SIM (11장 실제 새 IP 인스턴스) | 미작성·미실행 | **NOT_RUN** | 기존 IP의 단위 회귀로 신규 인스턴스 연결/주소를 증명할 수 없음 |
| Vivado Synthesis / Implementation / Timing | 미실행 | **NOT_RUN** | GitHub runner에 Vivado 프로젝트/라이선스/보드 없음 |
| Vitis 실제 BSP / XSA / ELF | 미실행 | **NOT_RUN** | 타깃 플랫폼 빌드 수행하지 않음 |
| Basys3 SG90 실제 PWM 파형 / 모터 회전 | 미실행 | **NOT_RUN** | 실물 보드 미연결 |
| UVM | 미실행 | **NOT_RUN** | 11장 기본 검증은 Icarus Verilog 기반 자가검증 TB를 채택 |

GitHub Actions가 시작 시 `sudo apt-get update && sudo apt-get install -y iverilog`을 수행해 **원격 Ubuntu 러너**에 설치했다. 이는 사용자의 로컬 Ubuntu PC에 설치한 것이 아니다.

## 2. 확인된 오류와 필요한 수정 범위

### 2.1 신규 11장 TB 구문 오류

- 최초 실행 [#42932990099](https://github.com/Yuul-Jung/amd_soc/actions/runs/42932990099): `tests/tb_servo_pwm_reuse.v:1: syntax error`
- 원인: `timescale` 지시어 바로 앞의 불필요한 `\\` 문자.
- 조치: 신규 TB에서 잘못된 한 문자를 삭제 (`1c90bf5e479ff3f1620602ae2f71486f739e64eb`).
- 결과: 11장 자체 RTL TB **PASS**.

### 2.2 기존 04장 AXI 회귀 TB의 조기 판정

- 11장 테스트가 PASS한 뒤 기존 04장 AXI TB에서 `FATAL: tests/tb_p2_04_axi_pwm.v:90: active period`가 발생.
- 04장 RTL `pwm_core`는 `RESET_PERIOD=100000`이고 `pending` 설정은 **PWM 주기 경계**에 반영된다. 기존 TB는 `APPLY` 후 `repeat(22)`만 기다려 실제 첫 주기 경계 전에 ACTIVE_PERIOD를 확인했다.
- 조치: 검토용 브랜치의 **04장 테스트벤치만** 실제 `active_period` 전환을 기다리도록 변경, timeout 증가, 100%/0% duty 적용 완료도 기다리도록 변경.
- 수정 커밋: `9b0a48a966923fe3e97e9cff7d2164913f2ca5ce`.
- **04장 RTL/AXI IP 본체는 수정하지 않음.**
- 이후 Run #42933313146에서 `RTL_SIM_p2_04_axi_pwm PASS` 확인.
- `tb_pwm_core.v`의 `$display` 형식에 기존 `unknown format` 경고가 있으나 PASS/FAIL 결정에 영향을 주지 않는 표시 경고이며 본 작업에서는 수정하지 않음.

## 3. 검증 범위와 유의점

1. 신규 `servo_logic.c`의 100MHz 기준 0/90/180° → 20ms 프레임·1/1.5/2ms 펄스폭 정수 변환을 HOST_C에서 검사했다.
2. `servo_command.c`의 `SERVO 0`, `SERVO 90`, `SERVO 180`, `SERVO OFF`, 비정상 문자열 검증을 HOST_C에서 검사했다.
3. `tb_servo_pwm_reuse.v`는 주기를 200 tick으로 압축해 기존 `pwm_core`의 10/15/20 tick HIGH 출력을 확인한다. **실제 100MHz/20ms 파형의 보드 계측은 아니다.**
4. P2-04 AXI 슬레이브 테스트는 AW/W 도착 순서, WSTRB, Backpressure, 오류 응답 등의 기존 기능을 검증한다. 제11장 BD에 추가할 두 번째 AXI 인스턴스의 유일 주소·출력 소유권은 별도 검증해야 한다.
5. P2-10 UART/C 명령 파서와 11장 독립 명령 파서의 **실제 통합**은 미구현/미검증이다.
6. XDC 사용자 핀·별도 5V 서보 전원·공통 접지·3.3V 신호 인식·서보 안전 각도는 보드 단계에서 확인한다.

## 4. 다음 검증 게이트

- 신규 P2-11 실제 Block Design/XSA/BSP 준비 후 **AXI 주소 독립성 및 UART SERVO 명령 통합**을 검증한다.
- Vivado 합성/타이밍과 보드 실물 SG90 90° 중립부터 순차 검증한다.
- 현재의 HOST_C/RTL_SIM PASS를 Vivado 또는 BOARD PASS로 승격하지 않는다.

**공개 전 점검:** 로그에서 로컬 경로/계정/토큰이 담긴 원본 GUI·설정 이미지는 무검토 상태로 배포하지 않는다. CI 링크의 공개 범위는 저장소 권한을 따른다.

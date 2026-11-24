# 제2부 11장 — SG90 서보 모터 AXI PWM 제어

> **검증 단계:** 2026-11-11 GitHub Actions #42933313146에서 HOST_C, 신규 PWM RTL_SIM 및 기존 P2-04 AXI_SIM PASS. 신규 SoC 통합 AXI, Vivado, Vitis, Basys3는 NOT_RUN.
>
> **기존 자료 변경:** 제2부 01~10장 원본 파일 수정 없음.

## 실행 문서

- [11장 전체 따라하기 HTML](P2_11_Study_Guide.html)
- [기존 04장 PWM IP 및 RTL](../P2_04_Lesson_20261106/README.md)
- [제2부 11~20장 테크트리](../../docs/P2_11_20_ROADMAP.md)
- [실제 Icarus 시뮬레이션 검증 기록](../../docs/P2_11_SIM_VERIFICATION_20261111.md)
- [GitHub Actions 실행 로그](https://github.com/Yuul-Jung/amd_soc/actions/runs/42933313146)

## 새 파일

| 파일 | 역할 |
|---|---|
| `sw/servo_logic.c/.h` | 각도(0~180°) → 20ms PWM Period/Duty 변환, 보드 비종속 |
| `sw/servo_axi.c/.h` | P2-04 PWM IP Register Map 그대로 재사용 |
| `sw/servo_command.c/.h` | 독립 SERVO 0~180 / SERVO OFF UART 명령 파싱 |
| `tests/test_servo_logic.c` | 0/90/180도와 50/100MHz 계산·오류 입력 시험 |
| `tests/test_servo_command.c` | UART 문자열 파싱 및 비정상 입력 시험 |
| `tests/tb_servo_pwm_reuse.v` | 수정 없는 P2-04 `pwm_core` 축척된 펄스폭 검사 |
| `tests/run_host_tests.sh` | gcc 호스트 테스트 |
| `tests/run_rtl_tests.sh` | iverilog/vvp 테스트, 없으면 NOT_RUN |
| `P2_11_Study_Guide.html` | 회로 연결·AXI 사용·전체 코드·검증 기준 |

## 설계 기준

- 보드: Basys3, SG90 서보 모터 + **외부 5V 전원**, 공통 GND.
- IP: 기존 `p2_04_axi_pwm_v1_0`를 **별도 AXI Slave 인스턴스**로 추가한다. 기존 PWM LED1 인스턴스를 절대 재목적화하지 않는다.
- AXI 클록: 예제 100MHz. **실제 Block Design 클록 확인 후** C의 `clock_hz` 인자로 전달.
- PWM: 20ms 프레임, HIGH 1~2ms 교육용 구간; 90도 초기 중심.
- Register Map: 0x00 PERIOD_CFG, 0x04 DUTY_CFG, 0x08 CONTROL_CFG, 0x0C APPLY, 0x10 STATUS, 0x14 ACTIVE_PERIOD, 0x18 ACTIVE_DUTY, 0x1C IP_ID.
- 추가 IP의 베이스 주소는 Address Editor/XSA/BSP 확인으로만 확정. `servo_axi_set_angle(baseaddr, clock_hz, angle)` 호출 전에 실제 하드웨어 주소를 주입.
- 출력 `servo_pwm_o`는 신규 IP `pwm_led_o`를 Make External 후 상위 Top Shell에 단순 연결. 여유 Pmod 핀은 실제 XDC 검사 후 지정.
- Top에는 동작 기능·산술·조건식·상태머신을 추가하지 않는다.

## 실행

```bash
cd part02/chapters/P2_11_Lesson
bash tests/run_host_tests.sh
bash tests/run_rtl_tests.sh
```

**실행 증거:** GitHub Actions #42933313146에서 P2-11 HOST_C·RTL_SIM, P2-04 AXI_SIM PASS. P2-11 신규 AXI 인스턴스 통합·Vivado·Vitis·실물 검증은 NOT_RUN.

## 확인할 위험과 미완료 작업

1. 기존 통합 설계에 서보 전용 AXI PWM IP를 추가한 뒤 Validate Design, Synthesis, Timing, Bitstream/XSA, Vitis/실물 확인 필요.
2. 독립 SERVO 명령 파서는 구현했으나 제2부 10장 RUN/MODE/Cmd Parser에 실제 등록하는 작업은 **아직 미구현**. 현재 제공된 C는 재사용 가능한 함수 레벨이다.
3. 변경된 Address Editor에서 모든 기존 장치 주소가 유지되는지 확인.
4. 보유 SG90 호환품에 따라 0/180도에서 스톨 가능하므로 중립 90도부터 무부하 시험.
5. 현재 RTL 테스트벤치는 기본 PWM Core의 파형만 검증하며, **신규 AXI IP의 버스 통합 검증은 미실시**.


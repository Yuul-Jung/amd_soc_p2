# 제2부 16장 — DS3231 I²C RTC(실시간 시계)

> 기준일: 2026-11-11. **HOST_C 및 I²C 트랜잭션 시퀀서 RTL_SIM PASS**.
>
> 사용자 결정: Vivado 합성·Implementation·Timing, Vitis 타깃, RTC 실물 시험 **보류**. 물리 I²C Read Master 및 AXI IP는 현재 **미구현**.

## 자료

- [제16장 HTML 전체 학습안내서](P2_16_Study_Guide_v01.html)
- [실제 HOST_C/RTL_SIM 검증 보고서](../../docs/P2_16_SIM_VERIFICATION_20261111.md)
- [실제 자동 시험 PASS #42945777999](https://github.com/Yuul-Jung/amd_soc/actions/runs/42945777999)
- [Analog Devices DS3231 공식 데이터시트](https://www.analog.com/media/en/technical-documentation/data-sheets/DS3231.pdf)

## 소스 구성

| 파일 | 역할 |
|---|---|
| `sw/ds3231_time.h/.c` | DS3231 레지스터 0x00~06 BCD → 날짜·시간, 12/24h·윤년·Century 및 OSF 오류 검증 |
| `rtl/ds3231_burst_sequencer.v` | I²C START→Write addr→0x00→Repeated START→Read 7Byte→STOP 명령 시퀀서 |
| `tests/test_ds3231_time.c` | C 가상 RTC 레지스터 모델·시계·달력·OSF·오류 테스트 |
| `tests/tb_ds3231_burst_sequencer.v` | RTL I²C 하위 엔진 가짜 응답 기반 반복 START/ACK/NACK 및 오류 테스트 |
| `tests/run_host_tests.sh` | GCC C 단위시험 |
| `tests/run_rtl_tests.sh` | Icarus Verilog RTL 시뮬레이션 |
| `P2_16_Study_Guide_v01.html` | 한글 배포용, 전체 소스/구조도/검증 기준 |

## 실제 기능 범위

### DS3231 I²C Burst Read

```text
START
  → 0xD0 (slave 0x68 + Write)
  → 0x00 (seconds register pointer)
  → REPEATED START
  → 0xD1 (slave 0x68 + Read)
  → seven timekeeping bytes (first six ACK, final NACK)
  → STOP
```

현재 `ds3231_burst_sequencer`는 **명령 단위 인터페이스를 갖춘 Sequencer**이며 I²C SDA/SCL의 실제 출력과 Slave ACK 읽기·Clock Stretching·전기적 연결은 **미구현**이다. 제14장 `i2c_write_byte_master`는 단일 바이트 쓰기 전용이므로 실제 DS3231 읽기에 그대로 사용하면 안 된다.

### Clock/Calendar Registers

- 0x00 Seconds, 0x01 Minutes, 0x02 Hours (12/24-hour)
- 0x03 Day of Week (1~7, 요일 숫자의 의미는 사용자가 설정)
- 0x04 Date, 0x05 Month/Century, 0x06 Year (00~99)
- 0x0F Status, bit7 OSF(Oscillator Stop Flag: 시계 발진 중단 가능성). **OSF가 1이면 읽은 시각을 신뢰하지 않음**.
- BCD에서 십진수로 변환하고, 월별 일수·윤년·2100년·12h AM/PM 범위를 검사한다.
- 센서가 어떤 연도에 실제로 초기화되었는지는 확인할 수 없다. `2000..2199` 표현은 Century 비트 해석을 위한 교육용 기준이다.

## 테스트 실행

```bash
# 저장소 루트 기준
bash part02/chapters/P2_16_Lesson/tests/run_host_tests.sh
bash part02/chapters/P2_16_Lesson/tests/run_rtl_tests.sh
```

GitHub Actions `ubuntu-24.04` 러너에 Icarus Verilog를 설치해 테스트했다. 사용자의 Ubuntu PC에 설치한 것은 아니다.

## 검증 게이트

| Gate | 판정 |
|---|---|
| HOST_C | **PASS** |
| RTL_SIM (트랜잭션 명령 Sequencer) | **PASS** |
| RTL_SIM (SDA/SCL 물리 I²C Master) | **NOT_RUN / 미구현** |
| AXI_SIM | **NOT_RUN / 미구현** |
| Vivado Synthesis/Timing | **보류** |
| Vitis Target, Basys3 RTC 실물 | **보류** |
| UVM | **NOT_RUN** |
| HTML Browser Render | **NOT_RUN** |

기존 제2부 01~15장 RTL/IP/XPR을 수정하지 않는다. `main`은 유지하고 이 저장소의 검토 브랜치에만 반영한다.

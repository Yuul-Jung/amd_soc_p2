# 제2부 16장 DS3231 I²C RTC — HOST_C / RTL_SIM 실제 검증 기록

- 기준일: 2026-11-11 (KST)
- 기준 저장소: `Yuul-Jung/soc`의 CURRICULUM.md, MIGRATION.md, VALIDATION.md, COLLABORATION.md
- 구현 저장소: `Yuul-Jung/amd_soc`, 검토 브랜치 `work/part02-second-half-20261110`
- 실행 증거: [GitHub Actions #42945777999](https://github.com/Yuul-Jung/amd_soc/actions/runs/42945777999)
- 테스트 커밋: `a5f22d9007b56d02c3da312790801cdf344cd49e`
- 실행 환경: Ubuntu 24.04 원격 GitHub Actions runner, GCC, Icarus Verilog + vvp.
- 사용자 PC·Vivado·Vitis·실물 RTC 보드에서 실행한 테스트가 아님.

## 1. 실제 시험 결과

| 시험 | 상태 | 자동 실행 로그 |
|---|---|---|
| DS3231 레지스터 0x00~0x06 7바이트 읽기 콜백, BCD 24h 변환 | **HOST_C PASS** | `P2_16_RTC_BURST_BCD_24H_PASS` |
| DS3231 12시간제 AM/PM 변환 | **HOST_C PASS** | `P2_16_RTC_12H_AM_PM_PASS` |
| 윤년·월별 날짜 유효성 | **HOST_C PASS** | `P2_16_RTC_LEAP_CALENDAR_PASS` |
| Century 비트와 2100년 윤년 예외 | **HOST_C PASS** | `P2_16_RTC_CENTURY_2100_PASS` |
| BCD 숫자 오류·60초·요일 오류 | **HOST_C PASS** | `P2_16_RTC_INVALID_DATA_REJECT_PASS` |
| OSF(발진 정지 플래그)·버스 콜백 오류 | **HOST_C PASS** | `P2_16_RTC_OSF_BUS_ERROR_PASS` |
| C 전체 | **HOST_C PASS** | `P2_16_HOST_RTC_TESTS_PASS` |
| RTL I²C Transaction 계획: START, D0, 00, repeated START, D1, READ ACK×6/NACK×1, STOP | **RTL_SIM PASS** | `P2_16_RTC_I2C_BURST_SEQUENCE_PASS` |
| RTL 버스 오류 시 부분 수신 자료 미공개 | **RTL_SIM PASS** | `P2_16_RTC_I2C_ERROR_REJECT_PASS` |
| RTL 전체 | **RTL_SIM PASS** | `P2_16_RTC_BURST_RTL PASS` |
| 실제 SDA/SCL PHY Transaction Engine/Clock Stretching | **NOT_RUN / 미구현** | RTL Sequencer는 전기적 I²C 파형을 직접 생성하지 않는다 |
| AXI4-Lite IP + MicroBlaze V 전체 통합 | **NOT_RUN / 미구현** | 추후 확장 |
| Vivado 합성·Implementation·Timing | **보류** | 사용자 요청 |
| Vitis BSP·ELF / Basys3 + DS3231 실물 | **보류** | 사용자 요청 |
| UVM | **NOT_RUN** | 자가검증 Verilog TB + C 호스트 테스트 적용 |
| HTML 실제 브라우저 검증 | **NOT_RUN** | 소스 저장·링크 정적 검사는 별도 |

## 2. 첫 테스트 실패와 수정

- [최초 실행 #42945627645](https://github.com/Yuul-Jung/amd_soc/actions/runs/42945627645)에서 C 검증은 PASS했으나, RTL 테스트벤치가 응답 시점을 잘못 처리하여 `TIMEOUT` 발생.
- 원인: 가짜 I²C 명령 수신측의 ready/response 핸드셰이크가 상승 에지 샘플링과 일치하지 않아 다음 명령으로 진행하지 못했다.
- 테스트벤치만 수정: 명령 수락을 상승 에지에서 검사하고 이후 반주기 동안 응답을 유지하도록 변경.
- 수정 커밋: `a5f22d9007b56d02c3da312790801cdf344cd49e`.
- 이후 실행 #42945777999에서 HOST_C 및 RTL_SIM 전체 PASS 확인. 해당 수정 과정에서 기존 제14장 I²C RTL을 변경하지 않았음.

## 3. 기술·전기적 제한

- DS3231은 공식 I²C 7-bit 주소 `0x68` 사용. 읽기 시 장치 쓰기주소 `0xD0` → 시작 레지스터 포인터 `0x00` → Repeated START → 읽기주소 `0xD1` → 7바이트를 연속으로 읽고 마지막 바이트 후 NACK.
- 0x00초, 0x01분, 0x02시, 0x03요일(1~7 사용자 정의), 0x04일, 0x05월/세기, 0x06년; BCD 형식.
- 시간 신뢰성: `StatusReg(0x0F)`의 OSF(bit7)=1이면 발진 중단 가능성을 의미하므로 읽기 결과를 신뢰하지 않는다. C helper는 시각 burst 읽기 전후 OSF를 검사하고, **OSF 플래그를 자동 지우지 않는다.**
- 12/24시간제, 오전/오후, 2100년 Century 비트, 윤년(2100은 윤년이 아님)을 독립 C 테스트에서 확인.
- 현재 RTL `ds3231_burst_sequencer.v`는 **I²C PHY의 START/WRITE/RESTART/READ/STOP 명령을 계획하는 Command Sequencer**다. SCL/SDA 실제 타이밍·버스 복구·ACK/NACK 물리 처리는 후속 재사용 I²C read/write engine이 필요하다.
- `bus_rsp_error`이면 RTL에서 부분 `raw_bcd` 값을 공개하지 않는다. 단, 물리 I²C 버스 STOP/회복 처리는 별도 PHY 하위 모듈의 의무이다.
- 14장 I²C write-only Master를 그대로 재사용하면 DS3231의 반복 START/Read 연속전송을 수행할 수 없다. 동일한 IP로 성공했다고 보고하지 않는다.
- DS3231 모듈의 VCC/SDA/SCL 풀업 전압을 실물 확인하기 전 Basys3 3.3V I/O와 직접 연결하지 않는다. 일부 모듈은 5V와 백업 배터리 충전 회로를 포함할 수 있다.

## 4. 다음 개발 작업

1. I²C Write/Read/Repeated-START/ACK/Clock-Stretching을 지원하는 보드 독립 RTL 버스 Master 확장.
2. 16장 버스트 Sequencer와 신규 I²C Master를 연결한 디지털 통합 RTL_SIM 및 SCL/SDA 파형 검증.
3. BCD/OSF 검증 뒤 DateTime을 FND/LCD1602에 표시하는 재사용 Display Controller 추가.
4. 실제 SoC AXI IP/합성/Vitis/보드 검증은 사용자 보류 지시가 해제된 후 수행.

## 5. 출처

- [Analog Devices DS3231 공식 제품·데이터시트](https://www.analog.com/en/products/ds3231.html)
- [DS3231 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/DS3231.pdf): Timekeeping registers, I²C Interface, status/OSF, Century, 12/24-hour.
- [NXP UM10204 I²C-bus specification](https://www.nxp.com/docs/en/user-guide/UM10204.pdf): START/STOP, repeated START, ACK/NACK.

**결론:** C 레지스터 스냅샷 해석·오류 검증 및 RTL 명령 Sequencer **HOST_C / RTL_SIM PASS**. 실제 I²C PHY, AXI SoC, Vivado, Vitis, 실물 DS3231은 **미검증**.

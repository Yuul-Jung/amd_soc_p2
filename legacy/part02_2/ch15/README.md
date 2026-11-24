# 제2부 15장 — DS18B20 1-Wire 디지털 온도 센서

> 개발 단계: 1-Wire 리셋·Presence·Read/Write 슬롯, 단일 외부전원 DS18B20 온도 변환 및 Scratchpad(9바이트) CRC 검증 구현.
>
> 사용자 결정: **Vivado 합성·타이밍, Vitis 타깃, 실물 DS18B20 검증은 보류**. 실제 GitHub Actions Icarus Verilog RTL 시뮬레이션만 PASS로 판정한다.

## 교육자료

- [제15장 전체 HTML 학습안내서](P2_15_Study_Guide_v01.html)
- [제15장 실제 실행 검증 보고서](../../docs/P2_15_SIM_VERIFICATION_20261111.md)
- [GitHub Actions 자동 검증](https://github.com/Yuul-Jung/amd_soc/actions/workflows/p2-15-ds18b20-verification.yml)
- [DS18B20 공식 데이터시트 — Analog Devices](https://www.analog.com/media/en/technical-documentation/data-sheets/DS18B20.pdf)

## 독립 모듈과 파일

| 파일 | 역할 |
|---|---|
| `rtl/onewire_slot_master.v` | Reset/Presence, Read/Write 1bit, µs 타이밍 생성, DQ Open-drain LOW 제어 |
| `rtl/ds18b20_controller.v` | 단일 센서 온도 변환·스크래치패드 9바이트·CRC8 검사 |
| `rtl/ds18b20_open_drain_io.v` | Vivado 전용 Xilinx IOBUF 물리 DQ 연결, 시뮬레이션 제외 |
| `tests/tb_ds18b20_controller.v` | 양수/음수 온도·CRC 오류·센서 미응답·명령 순서 자가검증 |
| `tests/run_rtl_tests.sh` | Icarus RTL 시뮬레이션 |
| `P2_15_Study_Guide_v01.html` | 한글 배포용 전체 코드 및 따라하기 실습 |

## 전송 규칙

```text
Reset(480us LOW) → Presence
  → Skip ROM 0xCC → Convert T 0x44
  → 750ms 대기 (12-bit resolution)
Reset(480us LOW) → Presence
  → Skip ROM 0xCC → Read Scratchpad 0xBE
  → 9 Byte LSB-first Read → CRC8 검증
  → CRC PASS일 때 temperature_raw 갱신
```

- 1-Wire 명령과 데이터는 **LSB-first**. SPI/I²C의 MSB-first 개념을 혼동하지 않는다.
- `temperature_raw`는 signed 16bit, 단위 **1/16°C (0.0625°C)**. 0x0191 → +25.0625°C; 0xFF5E → −10.125°C.
- CRC-8: polynomial `x^8 + x^5 + x^4 + 1`, LSB-first 구현에서는 XOR `8'h8C`.
- 실제 센서가 9비트를 선택한 경우 변환 시간은 다르나 본 코드는 기본 12-bit 변환 최대 750ms로 고정.
- 외부전원 공급 3선식 VDD/GND/DQ 한 장치만 지원. ROM Search/Match, 다중 장치, 기생전원 강한 풀업 미지원.
- `CLK_HZ`는 1 MHz의 정수배로 설정. 100MHz 기준 기본값이며 현행 Vivado 실제 IP Clock을 확인해야 한다.
- `start_pulse`는 IDLE에서만 처리하고 동작 중 중복 요청은 무시.

## 시뮬레이션 실행

```bash
# 저장소 루트 기준
bash part02/chapters/P2_15_Lesson/tests/run_rtl_tests.sh
```

테스트벤치는 출력 DQ와 가상의 센서 응답으로 동작한다. 시간 축은 `CLK_HZ=1MHz`, `CONVERT_WAIT_US=20`으로 축소해 실행하므로 실제 750ms 전체 시간이 실험된 것은 아니다.

## 실제 연결/전기 안전 (실행 보류)

- DS18B20 **3.3V VDD**, **GND**, **DQ** 연결.
- DQ에 외부 **약 4.7 kΩ 풀업을 3.3V로** 연결.
- Basys3 FPGA I/O에 5V 입력 금지.
- `ds18b20_open_drain_io.v`는 IOBUF T의 High-Z만 사용하여 외부에 HIGH를 강제로 출력하지 않음.
- 센서 DQ 실제 핀 및 XDC는 기존 주변장치 핀과 충돌 여부를 확인한 후 지정.
- 하드웨어 `IOBUF`와 전기적 rise time, 실제 750ms 완료는 미검증.

## 검증 범위

| Gate | 상태 |
|---|---|
| RTL_SIM | PASS (GitHub Actions 링크 및 검증 보고서 참조) |
| HOST_C | NOT_RUN / 별도 계산 보조 프로그램 미구현 |
| AXI_SIM | NOT_RUN / AXI IP 미구현 |
| SYNTH_TIMING | 보류 |
| VITIS_TARGET | 보류 |
| BOARD | 보류 |
| UVM | NOT_RUN |
| WEB_RENDER | NOT_RUN (GitHub 파일 저장과 실제 렌더링 구분) |

기존 제2부 01~14장 RTL·HDL/HTML과 보존 XPR, `main` 브랜치 변경 없음.

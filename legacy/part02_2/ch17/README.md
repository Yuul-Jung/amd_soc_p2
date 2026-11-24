# 제2부 17장 — DHT22(AM2302) 온습도 펄스폭 통신

> 2026-11-11 기준: **RTL_SIM PASS** (GitHub Actions) · Vivado 합성/Timing, Vitis 대상, AXI IP, 실물 보드, UVM은 **NOT_RUN/보류**.
>
> 본 장은 **DHT22 고유 단일선 펄스폭 프로토콜**이다. 제15장의 Maxim/Dallas DS18B20 1-Wire Reset/ROM/CRC 프로토콜과 호환되지 않는다.

## 배포 자료 및 증거

- [제17장 전체 HTML 학습안내서](P2_17_Study_Guide_v01.html)
- [제17장 실제 시뮬레이션 검증 보고서](../../docs/P2_17_SIM_VERIFICATION_20261111.md)
- [GitHub Actions RTL 시뮬레이션 PASS](https://github.com/Yuul-Jung/amd_soc/actions/runs/42947985483)
- [Aosong AM2302 공식 기술자료](https://www.aosong.com/uploadfiles/2025/04/20250417105409216.pdf)

## 주요 파일

| 파일 | 내용 |
|---|---|
| `rtl/dht22_controller.v` | START LOW, 응답 80/80µs, 40비트 MSB-first 데이터, 펄스폭 구분, 체크섬, 음수 온도, 측정 간격 제한 |
| `rtl/dht22_open_drain_io.v` | Xilinx IOBUF 기반 Open-drain/High-Z DQ 경계; **Icarus 휴대용 시뮬레이션에는 미포함** |
| `tests/tb_dht22_controller.v` | 모의 DHT22의 정확한 데이터/비트 펄스 송신, 양·음 온도, 체크섬 오류, 무응답, 비정상 펄스, cooldown 검사 |
| `tests/run_rtl_tests.sh` | Icarus Verilog 컴파일·실행 |
| `P2_17_Study_Guide_v01.html` | 한글 강의/실습 문서와 전체 RTL·TB, 계층형 구조도 |

## 명령 및 전기적 프로토콜

```text
FPGA START: DQ LOW >= 1ms → DQ 해제/풀업 HIGH
    ↓
DHT22 응답: 80us LOW + 80us HIGH
    ↓
40bit data: [RH_H][RH_L][TEMP_H][TEMP_L][CHECKSUM]
    비트당 약 50us LOW + 0:26~28us HIGH / 1:약70us HIGH
    ↓
CHECKSUM: (RH_H+RH_L+TEMP_H+TEMP_L) mod 256
    ↓
정상 데이터면 공개 출력 갱신 / 오류면 이전 유효 값 유지
```

- 40비트는 MSB(최상위 비트)부터 받는다. DS18B20은 LSB-first이므로 혼동 금지.
- 상대습도 `humidity_tenths`는 0.1%RH 단위(658 → 65.8%RH).
- 온도 `temperature_tenths`는 0.1°C 단위, 최상위 비트는 **부호**이며 나머지 15비트는 크기. 0x8065 → -10.1°C (2의 보수 부호 표현이 아님).
- `BIT_THRESHOLD_US=45`로 HIGH가 45µs 이상이면 1, 미만이면 0으로 판별. 비정상적으로 짧거나 긴 펄스는 오류 거부.
- 기본 FPGA 시작 LOW 1.2ms; 100MHz 기준 내부 1µs tick = 100클록.
- 2단 DQ 입력 동기화. 실제 입력 노이즈/메타안정성·배선 지터 등은 추가 검증 필요.
- `MIN_INTERVAL_US=2000000` (2초) 쿨다운은 이전 시도 종료부터 계산하는 보수적인 제한. 전원 투입 직후 최소 안정화 2초는 외부 시스템 시작 제어 책임이며 RTL은 하드리셋 직후 시작을 자동으로 차단하지 않는다.
- DHT22 단일 센서만 지원하며 데이터 폴링 중 재시작을 무시한다.

## 전원과 DQ 연결 (실행 보류)

- DHT22 VCC는 실제 판매 모듈·전압 표기를 확인한 후 **3.3V 구동과 3.3V DQ 풀업** 사용을 우선 검토.
- DQ 외부 풀업 약 4.7kΩ, 공통 GND; 적절한 전류/배선/상승시간 확인.
- 5V 풀업이나 5V 신호를 Basys3 FPGA 3.3V I/O에 직접 연결하지 않음.
- 실제 DQ FPGA 핀·XDC는 01~16장의 포트 점유를 확인한 후 선정.
- Xilinx `IOBUF` 모듈은 별도 Vivado 합성 대상이며 본 CI에서는 컴파일하지 않음.

## 테스트 방법

```bash
# 저장소 루트에서 실행
bash part02/chapters/P2_17_Lesson/tests/run_rtl_tests.sh
```

실제 GitHub Actions 원격 Ubuntu에서 `iverilog` / `vvp`로 테스트했다. **사용자 PC에는 설치하지 않음.** 테스트벤치의 시스템 클록은 1MHz로 축소했으며 기본 실습 RTL 파라미터는 100MHz다.

## 독립 검증 게이트

| Gate | 현재 판정 |
|---|---|
| RTL_SIM | **PASS** (펄스, 데이터, 온습도, 오류, 쿨다운) |
| HOST_C | **NOT_RUN** |
| AXI_SIM / MicroBlaze V | **미구현/NOT_RUN** |
| SYNTH_TIMING | **사용자 지시로 보류** |
| VITIS_TARGET | **사용자 지시로 보류** |
| BOARD / 실측 | **사용자 지시로 보류** |
| UVM | **NOT_RUN** |
| HTML_BROWSER_RENDER | **NOT_RUN** |

기존 01~16장 RTL/IP/HTML/XPR과 `main` 브랜치를 유지한다.

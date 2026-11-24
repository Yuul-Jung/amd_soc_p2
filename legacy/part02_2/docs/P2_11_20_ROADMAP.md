# 제2부 후반부 11~20장 — 개발 편성안

> 2026-11-10 사용자 결정 반영 · 설계 계획이며 검증 완료 기록이 아님.
> 기준: `amd_soc` main `8f2b8748bb5cd305f0f2ab94640d2823c46fd19f`.
> 공통 기준: `Yuul-Jung/soc`의 CURRICULUM.md, MIGRATION.md, VALIDATION.md, COLLABORATION.md.

## 1. 확정된 편성 원칙

1. 별도 **Vivado/Vitis 연결·검증 장**은 만들지 않는다. 각 실습에서 상시 검증한다.
2. 제1부에서 다룬 **IP Catalog, IP Integrator, AXI IP 사용법**을 별도 장으로 반복하지 않는다.
3. 제1부에서 다루지 않은 **DSP IP(DSP48, Multiplier, MAC)**는 제3부 NPU/가속기 실습에서 학습한다.
4. 제2부 후반부는 **P2-11 SG90 서보**, **P2-12 28BYJ-48 유니폴러 스테핑 모터 + ULN2003**의 액추에이터 순서로 시작한다.
5. 기존 제2부 01~10장 및 제1부 성공 프로젝트, RTL/C, 레지스터·핀 소유권은 변경 없이 보존한다.

## 2. P2-11~20 학습 테크트리 (2026-11-10 최신 제안)

| 장 | 주제 | 대표 실습 모듈 | 주요 구현 |
|---|---|---|---|
| **11** | 서보 모터 위치 제어 | SG90 | 서보 PWM, 각도/펄스폭, AXI 레지스터 |
| **12** | 유니폴러 스테핑 모터 | **28BYJ-48(5V) + ULN2003** | 4상 여자 시퀀스, Full/Half Step, 방향, 속도, 목표 스텝 수, 가감속 |
| **13** | SPI + RFID | RC522 | SPI Master, UID 읽기, UART 상태 표시 |
| **14** | I²C 캐릭터 LCD | LCD1602/2004 + PCF8574 | I²C Master, LCD 문자 출력 |
| **15** | 1-Wire 온도 | DS18B20 | Presence, Read/Write Slot, CRC |
| **16** | I²C RTC | DS3231 | 시간·날짜 읽기, LCD 표시 |
| **17** | 온습도 센서 | DHT22 | 고유 단일선 프로토콜, Pulse Timing, Checksum |
| **18** | 인체감지 | HC-SR501 PIR | 입력 동기화·이벤트·경보 |
| **19** | 복합 환경 제어 | BME280 등 기존/신규 센서 | I²C 공용 버스, 이벤트·표시·제어 우선순위 |
| **20** | 종합 SoC | RFID·LCD·RTC·센서·액추에이터 | 누적 기능 및 실물 검증 |

> 추가 종합 프로젝트: `Audio Visual SoC` — 기존 노션의 PCM5102A I²S, UART PCM 음원 전송 자산을 보존·재사용하며 BRAM, MAX7219를 별도 프로젝트에서 통합한다.
>
> **12장 전기 안전**: 모터의 5V 코일은 FPGA 핀이 아니라 ULN2003 드라이버로 구동한다. ULN2003 IN1~IN4의 3.3V 로직 수용 여부를 실제 모듈 회로/규격으로 확인하고, 별도 모터 전원과 Basys3 공통 GND를 사용한다. 28BYJ-48 제조·감속비 편차가 있으므로 출력축 절대각도는 표기 스텝 수만으로 검증 완료로 판단하지 않는다. 모터 역회전 시 스텝 시퀀스 반대 순서, 목표 스텝·가감속·정지의 RTL/TB 경계값을 검증한다.

## 3. 공통 설계·검증 원칙

- Top은 보드 핀·wire·module instance·단순 연결만 담당하고, 기능은 보드 비종속 Core/Controller로 분리한다.
- 독립 RTL Core → self-checking Testbench → 필요할 때 AXI4-Lite Register Map/Wrapper → MicroBlaze V/Vitis C → 실제 Basys3 순으로 검증한다.
- 실제 XSA/BSP가 생성한 BaseAddr·IRQ 식별자를 사용한다. 예제 값을 하드웨어 주소의 정답으로 단정하지 않는다.
- 기존 LED0/1/2/14/15, FND 표시 정책, BTNC Reset, 모터 제어 소유권을 보존한다.
- 전기 안전은 SPI/I²C/1-Wire 모듈별 3.3V 입출력 허용범위, 오픈드레인과 풀업 전압, 외부 전원 및 핀 배치 확인을 포함한다.
- 장마다 STATIC, HOST_C, RTL_SIM, AXI_SIM, SYNTH_TIMING, VITIS_TARGET, BOARD, WEB 상태를 각각 기록한다. 미실시 항목은 PASS로 적지 않는다.
- GitHub에 HTML·RTL·TB·C 전체 소스, 실행 증거, 구조도, 검증표를 장별로 보관한다. 실제 확인 전에는 설계 초안으로 표기한다.

## 4. 다음 실행

**P2-11 서보 모터**부터 시작하고, 바로 다음 **P2-12 28BYJ-48 + ULN2003**을 독립 RTL·AXI 응용으로 진행한다. 기존 모터 제어 IP를 손상시키지 않으며 실제 GPIO 핀·XDC·전원 구성은 구현 및 실물 검증 때 확정한다.

참조: `part02/docs/P2_01_10_Integration_Audit.md`, `part02/docs/P2_01_10_Function_Matrix.md`.

# 제2부 10장 — 사용자 AXI IP 라이브러리 사양서

버전: 1.0 · 기준: 제2부 01~09장 소스 · 대상 Vivado/Vitis: 2024.2

## 1. 목적과 적용 범위

01~07장의 사용자 AXI IP와 독립 RTL Core를 재사용 가능한 라이브러리로 구성합니다. AMD 제공 IP와 애플리케이션 소프트웨어는 사용자 제작 IP와 구분합니다.

| 출처 | IP/모듈 | 재사용 단위 |
|---|---|---|
| P2-01 | `p2_01_axi_led` | AXI4-Lite LED0 제어 예제 IP (Vivado Wizard 생성 소스 기반) |
| P2-02 | `p2_02_axi_fnd_v1_0`, `fnd_scan_controller` | 4자리 BCD FND 표시 IP |
| P2-03 | `p2_03_axi_buttons_v1_0`, `button_event_core` | 버튼 Short/Long 이벤트+IRQ IP |
| P2-04 | `p2_04_axi_pwm_v1_0`, `pwm_core` | 프로그래머블 PWM IP |
| P2-05 | `p2_05_axi_cds_v1_0`, `cds_digital_core`, `auto_light_controller` | 디지털 조도 검출 및 자동 게이트 |
| P2-06 | `p2_06_axi_sonic_v1_0`, `hc_sr04_core` | 초음파 거리 측정 IP |
| P2-07 | `p2_07_axi_motor_v1_0`, `motor_controller` | 모터 명령/상태 및 안전 정지 IP |
| P2-08 | `xadc_wiz_0` (AMD 제공 IP) | **자체 IP가 아닌 외부 의존성**. AMD 생성물 재배포 조건을 별도로 확인 |
| P2-09 | `p2_09_mode_logic` (소프트웨어) | IP가 아닌 애플리케이션·SW 예제 |

## 2. 공통 AXI4-Lite 버스 계약

- 슬레이브 인터페이스: 32-bit AXI4-Lite, 단일 클록 도메인, Active-Low `ARESETN`.
- AXI AW(쓰기 주소)와 W(쓰기 데이터)는 독립 핸드셰이크합니다. B 응답 대기 중에는 두 번째 쓰기 거래를 수락하지 않습니다.
- 읽기 RDATA/RRESP는 RVALID 동안 RREADY가 수락할 때까지 유지합니다.
- 정렬되지 않은 주소·미정의 주소의 반응은 **개별 RTL 규약을 확인해 지정**합니다.
- `WSTRB`에 의한 바이트 쓰기 범위 및 읽기 전용 레지스터에 대한 쓰기 동작은 IP별 표에 따릅니다.
- 실제 `BASEADDR`는 사용자의 SoC Address Editor에서 할당되므로 **IP 사양서에 고정 주소를 적지 않습니다**.
- 인터럽트 IP는 `IRQ` 극성, 마스크, Pending 해제 순서를 별도로 명세합니다.

## 3. IP별 레지스터 계약 (RTL 기준)

### 3.1 P2-01 AXI LED

| Offset | 이름 | 내용 |
|---|---|---|
| `0x00` | REG0 | `slv_reg0[0]`이 `led_o`로 출력. 0=OFF, 1=ON |

기본 Vivado 4레지스터 Wizard 템플릿을 수정하는 교육용 IP이므로 REG1~3의 읽기·쓰기 계약은 실제 생성 및 수정된 RTL에서 확정합니다. 패키징 시 생성 템플릿을 동봉하고 포트 `led_o` 추가 여부를 재확인합니다.

### 3.2 P2-02 AXI FND

| Offset | 이름 | 접근 및 의미 |
|---|---|---|
| `0x00` | DISP_VALUE / REG0 | RW · 하위 16비트 packed BCD, 왼쪽부터 4자리; Reset 0 |
| `0x04` | DISP_CTRL / REG1 | RW · bit0 표시 허용; Reset 0 |
| `0x08` | REG2 | 예약 · 읽기 0, 쓰기 SLVERR |
| `0x0C` | REG3 | 예약 · 읽기 0, 쓰기 SLVERR |

`fnd_scan_controller`: `display_bcd[15:0]`, `display_enable`, `seg[6:0]`, `an[3:0]`, `dp`. 출력은 Active-Low이며 `an[0]`이 가장 오른쪽 자리입니다. `TICKS_PER_DIGIT`는 실제 클록에 따라 조절합니다.

### 3.3 P2-03 AXI Buttons

| Offset | 이름 | 접근 및 의미 |
|---|---|---|
| `0x00` | PENDING | R/W1C · [7:0] 이벤트 비트, 이벤트 SET 우선 |
| `0x04` | ENABLE | RW · [7:0] IRQ 마스크, Reset 0 |
| `0x08` | PRESSED | RO · [3:0] 안정화 버튼 상태 |
| `0x0C` | ID | RO · `0x00030001` |
| `0x10` | COALESCED | R/W1C · 이미 Pending인 이벤트의 중복 발생 비트 |

`irq`는 레벨 신호이며 `PENDING & ENABLE`이 0이 될 때 해제됩니다. W1C(1을 기록하면 지움)와 동시에 새 이벤트가 발생하면 이벤트 SET이 우선입니다. 5초 Long 판정은 `button_event_core`의 클록 파라미터에 의존합니다.

### 3.4 P2-04 AXI PWM

| Offset | 이름 | 접근 및 의미 |
|---|---|---|
| `0x00` | PERIOD_CFG | RW · 요청 주기 카운트 |
| `0x04` | DUTY_CFG | RW · 요청 HIGH 카운트 |
| `0x08` | CONTROL_CFG | RW · bit0 Enable, bit1 Polarity |
| `0x0C` | APPLY | 쓰기 명령 · 새 설정 적용 요청; 읽기 0 |
| `0x10` | STATUS | RO · bit0 Pending, bit8 Active Enable, bit9 Active Polarity |
| `0x14` | ACTIVE_PERIOD | RO · 현재 적용된 주기 |
| `0x18` | ACTIVE_DUTY | RO · 현재 적용된 듀티 |
| `0x1C` | ID | RO · 구현 RTL 상수와 대조 |

설정값 적용은 `pwm_core`에서 주기 경계에 갱신하여 도중의 펄스 왜곡을 막습니다.

### 3.5 P2-05 AXI CdS

| Offset | 이름 | 접근 및 의미 |
|---|---|---|
| `0x00` | CONTROL | RW · bit0 AUTO_ENABLE, bit1 DARK_WHEN_LOW (기본 1) |
| `0x04` | STATUS | RO · 센서 RAW_SYNC, DARK, VALID, AUTO_GATE 상태 |
| `0x08` | ID | RO · `0x00050001` |
| `0x0C` | FILTER_CYCLES | RO · 안정화 필터 클록 수 |

외부 센서 DO의 HIGH 전압이 FPGA I/O 범위를 초과하지 않도록 모듈 전원과 출력 극성을 확인합니다. `cds_digital_core`의 센서 입력은 별도 동기화 경로를 거칩니다.

### 3.6 P2-06 AXI HC-SR04

| Offset | 이름 | 접근 및 의미 |
|---|---|---|
| `0x00` | CONTROL | RW · bit0 AUTO, bit1 START W1P(쓰기 1 펄스), bit2 WARN_EN (Reset 1) |
| `0x04` | STATUS | RO · BUSY, VALID, TIMEOUT, RANGE_ERROR, WARN_LED, UNSAFE, AUTO, WARN_EN, READY |
| `0x08` | DIST_CM | RO · 측정 거리(cm) |
| `0x0C` | ECHO_US | RO · ECHO High 시간(µs) |
| `0x10` | WARN_CM | RW · 경고 임계값 1~400 |
| `0x14` | SEQUENCE | RO · 측정 횟수 |
| `0x18` | ID | RO · `0x00060001` |
| `0x1C` | CLK_HZ | RO · 코어 클록 주파수 |

HC-SR04 ECHO는 5V이므로 3.3V FPGA 입력 전에 전압 변환이 필요합니다. 거리 불능·타임아웃 때의 UNSAFE 정책은 모터 연계 전에 확인합니다.

### 3.7 P2-07 AXI Motor

| Offset | 이름 | 접근 및 의미 |
|---|---|---|
| `0x00` | CMD | RW · 0 STOP, 1 FWD, 2 REV |
| `0x04` | STATUS | RO · 제어기 안전/차단/동작 상태 |
| `0x08` | ID | RO · `0x00070001` |
| `0x0C` | DEADTIME_CYCLES | RO · 방향 전환 대기 클록 수 |
| `0x10` | FRESH_CYCLES | RO · 초음파 정보 유효시간 판정 클록 수 |
| `0x14` | CLK_HZ | RO · 코어 클록 주파수 |

모터 제어의 안전 조건은 CPU가 아니라 `motor_controller` RTL에 구현합니다. FPGA 핀을 모터 전원과 직접 연결해서는 안 됩니다.

## 4. 배포물의 필수 구성

```text
ip-library/
  README.md
  LICENSE                 ← 저작권·배포 조건 확정 후
  ip/
    p2_02_axi_fnd/
      component.xml       ← Vivado IP Packager 출력
      hdl/                ← 실제 패키징 소스
      ...
  docs/
    P2_10_IP_LIBRARY_SPEC.md
  examples/
    basys3_microblaze_v/  ← 외부 설치 예시
  tests/
    rtl/                  ← 자동 판정 테스트
```

`component.xml`과 `hdl/`은 Vivado IP Packager 출력물을 사용합니다. 사용자가 개발한 RTL과 AMD 제공 IP 생성물을 혼합해 재배포하지 않습니다.

## 5. 버전과 공개 범위

1. IP의 모듈 포트, 데이터 폭, 리셋·클록, `WSTRB`, 잘못된 주소, IRQ 동작을 명세합니다.
2. 기존 누적 SoC 밖의 **새 최소 프로젝트**에서 IP를 단독 인스턴스화합니다.
3. 라이브러리 릴리스에는 코드, 문서, 라이선스와 재사용 예제를 포함합니다.
4. 공개 전 로컬 경로, 개인 아이디, 토큰, 계정 정보와 GUI 스크린샷의 내부 정보를 제거합니다.

**공식 참조:** AMD UG1118 (Vivado IP Packaging) 및 AXI4-Lite 관련 AMD 문서, Digilent Basys3 Reference Manual, AMD UG480 (XADC).

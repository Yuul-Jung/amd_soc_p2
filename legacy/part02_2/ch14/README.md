# 제2부 14장 — I²C PCF8574 LCD1602/2004 문자 출력

> **현재 상태:** 신규 I²C 단일 바이트 Write RTL과 PCF8574의 LCD 초기화/HELLO 시퀀스 작성. GitHub Actions Icarus Verilog self-checking RTL_SIM 결과를 별도 확인한다.
>
> **사용자 결정:** Vivado 합성·타이밍, Vitis 타깃 및 실제 Basys3/LCD 실물 검증 **보류**. 본 자료의 장별 완료는 주장하지 않는다.

## 실행 파일

- [제14장 전체 HTML 강의·실습안내서](P2_14_Study_Guide_v02.html)
- [14장 C/RTL·전기 안전 검증 기록](../../docs/P2_14_SIM_VERIFICATION_20261111.md)
- [GitHub Actions I²C/LCD 검증](https://github.com/Yuul-Jung/amd_soc/actions/workflows/p2-14-lcd-i2c-verification.yml)
- [NXP PCF8574/PCF8574A 공식 PDF](https://www.nxp.com/docs/en/data-sheet/PCF8574_PCF8574A.pdf)
- [Hitachi HD44780U 4-bit LCD 초기화 참고](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf)

## 파일 분리

| 파일 | 역할 |
|---|---|
| `rtl/i2c_write_byte_master.v` | 7-bit I²C 주소 + Write + 1바이트, SDA/SCL 오픈드레인 제어, ACK/NACK, STOP |
| `rtl/lcd_pcf8574_hello.v` | LCD 4비트 초기화, EN 토글, `HELLO` 출력용 시퀀서 |
| `rtl/lcd_i2c_hello_system.v` | 위 두 기능 모듈 인스턴스 연결, 보드 비종속 |
| `rtl/i2c_open_drain_io.v` | Xilinx IOBUF를 쓰는 물리적 SDA/SCL 경계 모듈; **Icarus portable RTL_SIM 제외** |
| `tests/tb_lcd_i2c_hello_system.v` | 가짜 PCF8574 ACK로 72바이트 트랜잭션 내용·순서 자체검증 |
| `tests/tb_i2c_write_nack.v` | I²C 대상 없는 NACK·STOP 복귀 검사 |
| `tests/run_rtl_tests.sh` | Icarus 컴파일·실행 |

## 인터페이스

### 기본 트랜잭션

```text
START → [7-bit address + Write=0] → ACK → [8-bit PCF8574 port] → ACK → STOP
```

- `cmd_valid/cmd_ready`로 단일 바이트 명령을 받음.
- `done_pulse/nack_pulse`는 트랜잭션 종료 시 1클록 펄스.
- `scl_drive_low`, `sda_drive_low`는 **0 출력 핀 자체가 아님**. 1일 때 IOBUF를 LOW 출력, 0일 때 High-Z 해제하도록 설계.
- 외부 I²C 풀업을 **Basys3 호환 3.3V**에 연결해야 한다. 풀업이 5V인 백팩을 직접 연결하지 않는다.
- `CLK_DIV=400`이면 100MHz 기준 전송 데이터 SCL은 약 83kHz (low 2×400, high 1×400 시스템 클록)로 PCF8574 100kHz Standard-mode 범위 안. 실제 클록 변경 시 다시 계산.
- Clock Stretching(클록 스트레칭), Multi-master Arbitration(멀티마스터 중재), Bus Recovery(버스 복구), I²C Read(읽기)는 **미지원**.

### PCF8574 Backpack 일반 핀맵 (현물 확인 전 가정)

```text
P7..P4 → LCD D7..D4
P3 → LED Backlight
P2 → LCD E
P1 → LCD RW = 0
P0 → LCD RS
```

다른 배선의 백팩은 전용 매핑이 필요하다. 기본 7비트 주소 `0x27`은 예시이며 0x3F 또는 다른 주소는 실제 부품에 따라 다르다.

### LCD 4bit 초기화 시퀀스

- 전원 후 기본 50ms 대기
- nibble `0x3` 3회, `0x2` 1회 (첫 0x3 후 5ms, 다음 단계마다 200us 기본 간격)
- `0x28` Function Set → `0x0C` Display ON → `0x06` Entry Mode
- `0x01` Clear (기본 2ms 대기) → `0x80` 첫줄 주소 → ASCII `HELLO`
- 하나의 LCD nibble을 PCF8574 E=LOW→HIGH→LOW의 **3회 I²C 쓰기**로 전송
- 전체 72회 I²C 바이트 쓰기. 핀맵·지연·전원 조건이 실제 LCD에 유효한지는 보드에서 확인.

## 실행

```bash
# 저장소 루트에서 실행
bash part02/chapters/P2_14_Lesson/tests/run_rtl_tests.sh
```

GitHub Actions는 원격 Ubuntu runner에서 Icarus Verilog를 설치해 테스트한다. **사용자 로컬 Ubuntu에 설치된 것은 아니다.**

## 실제 SoC 통합 보류 항목

1. Vivado Packager/Block Design AXI/Clock/Reset/Address Editor (현재 예제는 단순 RTL Stream 입력이며 AXI IP는 미작성).
2. `i2c_open_drain_io`의 IOBUF 포함 합성/IOSTANDARD 및 SDA/SCL 전기 안전.
3. 3.3V-5V I²C 레벨 시프터와 백팩 Pull-up 전압 확인.
4. Vitis/CPU에서 문자를 갱신하는 Custom AXI-Lite Register Map 및 DDRAM 주소 제어.
5. 1602 2행/2004 4행 출력 위치·글자 표시·실물 I²C ACK 확인.

**기존 제2부 01~13장, 기존 성공 Vivado 프로젝트, `main` 브랜치 변경 없음.**

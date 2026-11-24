# 제2부 14장 I²C + LCD1602/2004 — 실제 시뮬레이션 검증 보고서

- 검증일: 2026-11-11 KST
- 저장소: `Yuul-Jung/amd_soc`, 검토 브랜치 `work/part02-second-half-20261110`
- 검증 기준: `Yuul-Jung/soc`의 CURRICULUM.md, MIGRATION.md, VALIDATION.md, COLLABORATION.md.
- 실제 실행 증거: [GitHub Actions #42943389314](https://github.com/Yuul-Jung/amd_soc/actions/runs/42943389314)
- 실행 커밋: `7e27359b5055d6ece43d3878eb82502b9909f999`
- 원격 환경: `ubuntu-24.04`, Icarus Verilog 12.0 / vvp.
- 사용자 PC와 Basys3에 접속하여 도구 설치·Vivado 실행·실물 연결을 수행한 것은 아니다.

## 1. 검증 결과

| Gate | 상태 | 재현 근거 |
|---|---|---|
| RTL_SIM I²C Master | **PASS** | `P2_14_I2C_72_PCF8574_BYTES_PASS` |
| RTL_SIM HD44780 LCD 초기화/HELLO | **PASS** | `P2_14_LCD_HELLO_SEQUENCE_PASS` |
| RTL_SIM ACK 미응답/NACK 및 STOP | **PASS** | `P2_14_I2C_NACK_HANDLING_PASS` |
| IO_BUF Synth/Timing | **보류/NOT_RUN** | 실제 Vivado 프로젝트에서 IOBUF 사용·제약·합성 증거 없음 |
| AXI_SIM | **NOT_RUN** | 14장 현재는 보드 독립 스트림·시퀀서, CPU AXI IP 미구현 |
| VITIS_TARGET | **보류/NOT_RUN** | 실제 XSA/BSP/ELF 미검증 |
| BOARD | **보류/NOT_RUN** | 실제 LCD, PCF8574, 풀업 전압, 화면 출력 미검증 |
| UVM | **NOT_RUN** | 현재 테스트는 self-checking Verilog TB |
| WEB_RENDER | **NOT_RUN** | HTML GitHub 저장 가능성 및 상대 경로 정합과 실제 브라우저 렌더/시각 검사는 구분 |

## 2. 시험 범위

### 2.1 I²C bus model

- SDA/SCL은 0/High-Z 형태의 오픈드레인 제어 신호로 모델링.
- START → 7-bit slave address + W → 1 byte output → STOP 확인.
- PCF8574 주소 `0x27`, 전송 시 주소 바이트 `0x4E` 사용.
- 가짜 PCF8574가 9번째 비트에 ACK를 표시하는 테스트벤치에서
  정상 데이터 전송 72회를 검증.
- ACK 없는 경우 9개 SCL(주소 8비트 + ACK 슬롯)만 수행하고
  데이터 바이트를 시작하지 않고 STOP을 발생시키며 오류를 보고.
- `CLK_DIV=400`의 설계상 예제(100MHz) SCL은 약 83kHz.
- **Clock Stretching, Arbitration, I²C Read 및 hung-bus recovery는 구현하지 않았다.**

### 2.2 LCD model

- LCD 제어 배치 가정: `{D7..D4, BL, E, RW, RS}`.
- LCD 4비트 초기화 nibble `0x3,0x3,0x3,0x2` + `0x28,0x0C,0x06,0x01,0x80`.
- `HELLO` 문자 데이터 5개.
- 니블 1개당 E=LOW → HIGH → LOW 패턴으로 PCF8574에 3회 쓰기.
- 4개 초기 단일 니블 12회 + 10개 완전 바이트 60회 → **총 72회 I²C Write**.
- 가짜 PCF8574의 ACK 및 트랜잭션 캡처가 있는 `tb_lcd_i2c_hello_system.v`가 예상 시퀀스를 비교.
- 실제 HD44780의 내부 명령 수행·Busy Flag·LCD 표시·음영·백라이트 전압을 실제로 테스트한 것은 아님.
- 기본 `POWERUP_WAIT=50ms`, 첫 초기 니블 후 5ms, 나머지 초기 니블 후 200us, Clear 후 2ms 대기.
- 짧은 TB 파라미터는 시뮬레이션 속도를 위한 축척이며 실물 설정에 사용하지 않는다.

## 3. 초회 실패 및 수정

- 단순 NACK 검사 이후 '주소 ACK 실패 시 데이터 바이트는 보내지 않고 STOP해야 한다'는 규칙을 새로 적용.
- 테스트벤치 처음에는 STOP 단계의 SCL을 데이터 클록으로 잘못 카운트하여 [실행 #42943281897](https://github.com/Yuul-Jung/amd_soc/actions/runs/42943281897)이 실패.
- 실물 RTL은 주소 NACK 후 STOP으로 처리했으며, TB의 SCL 카운트는 START/STOP과 별도로 데이터/ACK 구간 상승 에지만 세도록 교정.
- [재실행 #42943389314](https://github.com/Yuul-Jung/amd_soc/actions/runs/42943389314)에서 LCD 72회, HELLO, NACK 3항목 PASS.
- 기존 제2부 01~13장 RTL·Vivado 프로젝트에는 변경을 가하지 않음.

## 4. 실제 하드웨어 안전 및 제한

- NXP PCF8574/74A는 100kHz 표준 I²C 장치. 7-bit 주소는 실제 A0/A1/A2 보드 회로에 따라 변함.
- PCF8574 백팩을 5V로 구동하면 SDA/SCL 풀업도 5V가 될 수 있음.
  Basys3 3.3V 신호 핀에 5V를 직접 인가하지 말 것.
- 백팩의 RW/E/RS/BL 결선은 제조사에 따라 다를 수 있음.
- XDC 핀과 전압 변환기 결선은 실제 현재 Basys3 포트 점유 상황을 확인해야 확정 가능.
- `i2c_open_drain_io.v`는 Xilinx IOBUF 합성용 경계이며 현재 Icarus 테스트에는 포함하지 않음.
- 실물에 출력되는 문자 성공·AXI CPU 제어 가능성·UART 제어는 모두 **미확인**.

## 5. 근거

- [NXP PCF8574/PCF8574A datasheet](https://www.nxp.com/docs/en/data-sheet/PCF8574_PCF8574A.pdf): 100 kHz standard mode, supply and 7-bit address pins.
- [HD44780U 4-bit initialization](https://cdn-shop.adafruit.com/datasheets/HD44780.pdf): 3·3·3·2 초기화, 4.1 ms/100 us 및 Clear 명령 대기.
- [I²C-bus specification NXP UM10204](https://www.nxp.com/docs/en/user-guide/UM10204.pdf): open-drain SDA/SCL, Start/Stop/ACK.

**결론:** 제14장 I²C Master 및 LCD `HELLO` 시퀀스 RTL_SIM PASS. AXI·Vivado·Vitis·BOARD·UVM은 미검증 또는 사용자 요청에 따라 보류한다.

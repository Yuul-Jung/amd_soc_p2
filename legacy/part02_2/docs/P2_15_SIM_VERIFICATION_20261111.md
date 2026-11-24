# P2-15 DS18B20 1-Wire — RTL 시뮬레이션 검증 기록

- 기준일: 2026-11-11 (KST)
- 저장소: `Yuul-Jung/amd_soc`, 작업 브랜치 `work/part02-second-half-20261110`
- 공통 기준: `Yuul-Jung/soc` CURRICULUM.md / MIGRATION.md / VALIDATION.md / COLLABORATION.md.
- 실행 증거: [GitHub Actions Run #42944748136](https://github.com/Yuul-Jung/amd_soc/actions/runs/42944748136)
- 해당 실행 커밋: `7df6cc61a190e80e020afcee236c292f99d5db5e`
- 도구: GitHub-hosted Ubuntu 24.04, Icarus Verilog 12.0 + vvp.
- 사용자 PC에는 설치하지 않았으며 Vivado/Vitis/실물 연결은 수행하지 않았음.

## 1. 실제 출력 로그와 판정

| Gate / 시험 | 상태 | 실행 로그 |
|---|---|---|
| 1-Wire Reset / Presence, 명령 순서 CC·44·CC·BE | **RTL_SIM PASS** | `P2_15_DS18B20_POSITIVE_CRC_COMMAND_PASS` |
| Signed 양수 데이터 0x0191 (+25.0625°C) | **RTL_SIM PASS** | `P2_15_DS18B20_POSITIVE_CRC_COMMAND_PASS` |
| Signed 음수 데이터 0xFF5E (−10.125°C) | **RTL_SIM PASS** | `P2_15_DS18B20_NEGATIVE_TEMP_PASS` |
| 9번째 Scratchpad CRC 오류 및 온도 갱신 차단 | **RTL_SIM PASS** | `P2_15_DS18B20_CRC_REJECT_PASS` |
| Presence 없는 센서 | **RTL_SIM PASS** | `P2_15_DS18B20_NO_PRESENCE_PASS` |
| 전체 컨트롤러 검증 | **RTL_SIM PASS** | `P2_15_DS18B20_CONTROLLER_RTL PASS` |
| AXI_SIM / CPU 연결 | **NOT_RUN** | AXI 인터페이스 미구현 |
| Vivado Synthesis/Timing | **보류** | 사용자 요청에 따라 미실행 |
| Vitis Target BSP/ELF | **보류** | 사용자 요청에 따라 미실행 |
| Basys3 + DS18B20 실물 | **보류** | 센서/DQ/3.3V 전원/온도 실측 미실행 |
| UVM | **NOT_RUN** | 일반 Verilog Self-checking TB 사용 |
| WEB_RENDER | **NOT_RUN** | GitHub에 HTML 저장, 브라우저 렌더링 미수행 |

## 2. RTL 검증 범위

### DS18B20 슬롯 엔진

- 시스템 클록 `CLK_HZ`에서 µs 단위 타이밍 산출; 기본 100MHz.
- Reset LOW 480µs, Presence 샘플 시점 Reset 해제 후 약 70µs.
- Write 1: 6µs LOW / 64µs 해제; Write 0: 60µs LOW / 10µs 해제.
- Read: 6µs LOW / 9µs 해제 후 샘플, 나머지 55µs 해제.
- DQ를 HIGH로 직접 구동하지 않고 외부 3.3V 풀업이 공급하는 HIGH를 사용.
- 소프트웨어 UART나 SPI와 무관한 독립 RTL로 설계.

### DS18B20 컨트롤러

```text
RESET/PRESENCE → CC(Skip ROM) → 44(Convert T)
→ 12-bit 변환 시간 750ms 대기
→ RESET/PRESENCE → CC → BE(Read Scratchpad)
→ 9-byte(72-bit) read → CRC8 check → signed 16-bit raw
```

- One-wire 명령/데이터 모두 LSB-first.
- 온도 해상도 1/16°C; 2's complement signed 16-bit.
- CRC8 0x8C (reflected), scratchpad 처음 8바이트 계산 후 9번째 바이트와 비교.
- 변경 사항: 비정상 CRC일 때 사용자가 읽는 `temperature_raw` 값이 갱신되지 않도록 검사 통과 시만 등록.
- 12bit 변환 대기 750ms는 설계 기본 파라미터. TB는 속도를 위해 20µs로 축소했으므로 **물리적 750ms 시간 정확도를 실측했다고 주장하지 않음**.

## 3. 제한 및 위험

1. 모의 DS18B20 slave는 Reset/Presence·read bit의 디지털 정상/오류 응답만 제공한다. 아날로그 상승시간, 배선 길이, 센서의 실제 conversion latency, strong pullup 등을 모델링하지 않았다.
2. 외부전원 3선식 센서 1개만 지원. 2선식 Parasite Power(기생전원), ROM Match/Search, 다중 센서, 9/10/11bit 변환 설정 및 정밀한 타이밍 편차 검증은 구현 범위 밖이다.
3. 새 IP의 AXI4-Lite 제어와 기존 01~14장 CPU Address Editor/Top 입출력 통합은 미구현/미검증.
4. 실제 사용 시 3.3V VDD/GND, DQ에 약 4.7kΩ 3.3V 풀업을 사용한다. FPGA I/O 5V 직접 입력 금지. XDC는 기존 포트 점유 및 보드 전기 조건 확인 후 확정.
5. 빈 명령, 오류 반복, 대형 클록 범위 등 고급 스트레스·UVM 검증은 미실시. RTL_SIM PASS는 선택한 테스트 케이스에 한정.

## 4. 공식 기술 근거

- [Analog Devices DS18B20 Datasheet](https://www.analog.com/media/en/technical-documentation/data-sheets/DS18B20.pdf)
  - Timing Diagram (Reset, Presence, Read/Write Slots)
  - ROM Commands: Skip ROM (0xCC)
  - Function Commands: Convert T (0x44), Read Scratchpad (0xBE)
  - 12-bit 750ms max conversion
  - 9-byte Scratchpad, CRC8, temperature LSB 0.0625°C

**결론:** DS18B20 1-Wire Controller의 디지털 기능 **RTL_SIM PASS**, Vivado/Vitis/BOARD는 사용자 요청에 따라 보류. `main` 및 기존 제2부 01~14장 소스 변경 없음.

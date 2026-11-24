# 제2부 17장 DHT22/AM2302 단일선 펄스폭 통신 — 검증 보고서

- 검증일: 2026-11-11(KST)
- 공통 관리문서: `Yuul-Jung/soc`의 CURRICULUM.md, MIGRATION.md, VALIDATION.md, COLLABORATION.md (최신 파일/커밋 확인 후 개발)
- 자료 저장소: `Yuul-Jung/amd_soc`, 독립 검토 브랜치 `work/part02-second-half-20261110`
- **실제 RTL_SIM 증거:** [GitHub Actions 실행 #42947985483](https://github.com/Yuul-Jung/amd_soc/actions/runs/42947985483) · 커밋 `98873c11328b0f0071e6580b5ff87e8b8e55ed0a`
- 실행 환경: GitHub-hosted Ubuntu 24.04 + Icarus Verilog/vvp (원격).
- 사용자 Ubuntu에 도구 설치/기존 Vivado 프로젝트 접속/실물 센서 접속 **없음**.

## 1. 실제 검증 결과

| 검증 항목 | 상태 | 실제 CI 로그 |
|---|---|---|
| DHT22 40비트 MSB-first 응답·프레임 처리 | **RTL_SIM PASS** | `P2_17_DHT22_POSITIVE_40BIT_PASS` |
| 정상 상대습도 65.8%RH / 온도 +23.4°C | **RTL_SIM PASS** | `P2_17_DHT22_POSITIVE_40BIT_PASS` |
| 최소 측정 간격 2초 쿨다운 정책 | **RTL_SIM PASS** | `P2_17_DHT22_COOLDOWN_PASS` |
| 부호-크기 방식 온도 −10.1°C 판별 | **RTL_SIM PASS** | `P2_17_DHT22_NEGATIVE_TEMP_PASS` |
| 체크섬 불일치 시 이전 유효 온습도 유지 | **RTL_SIM PASS** | `P2_17_DHT22_CHECKSUM_REJECT_PASS` |
| 무응답·시작 LOW 후 센서 응답 지연 제한 | **RTL_SIM PASS** | `P2_17_DHT22_NO_RESPONSE_PASS` |
| 지나치게 짧은 데이터 HIGH 펄스 검출 | **RTL_SIM PASS** | `P2_17_DHT22_PULSE_WIDTH_REJECT_PASS` |
| 전체 | **RTL_SIM PASS** | `P2_17_DHT22_CONTROLLER_RTL PASS` |
| AXI4-Lite IP/SoC 통합 | **NOT_RUN/미구현** | 별도 파생 확장 필요 |
| Vivado Synthesis/Implementation/Timing | **보류** | 사용자 지시 |
| Vitis BSP/ELF 실제 타깃 | **보류** | 사용자 지시 |
| Basys3 + DHT22 온습도 실물 | **보류** | 사용자 지시 |
| UVM | **NOT_RUN** | self-checking Verilog TB 채택 |
| HTML Browser Render | **NOT_RUN** | GitHub 저장과 시각 렌더링을 구분 |

## 2. 실제 프로토콜·설계 계약

- 센서 DHT22(AM2302)의 단일선 펄스폭 프로토콜은 DS18B20의 Dallas/Maxim 1-Wire ROM 명령 체계와 다른 독립 전송 규격.
- HOST START: DQ 1.2ms LOW → 해제(Hi-Z) → 풀업 HIGH.
- SENSOR RESPONSE: 약 80µs LOW → 80µs HIGH.
- 40비트 MSB-first: `RH_H/RH_L/TEMP_H/TEMP_L/CHECKSUM`.
- 각 비트: 약 50µs LOW 다음 0→약 26~28µs HIGH, 1→약 70µs HIGH.
- 체크섬: 처음 4바이트의 합, 하위 8비트와 마지막 다섯 번째 바이트를 비교.
- 온도: 16비트 부호+크기(sign-magnitude), 하위 15비트/10은 °C, bit15=1 음수. **2의 보수로 해석하면 오답.**
- 습도: 16비트 unsigned, 10으로 나눈 값이 %RH. 제어 출력은 0.1단위 정수값으로 유지해 나눗셈 합성 필요를 제거.
- 기본 샘플링 제한: 측정 요청 완료/오류 뒤 추가 2초 대기; 전원인가 직후 안정화 2초는 외부 시작 정책 책임.
- DQ 입력은 2단 동기화 플립플롭을 사용, 시간 측정은 단일 FPGA 클록에서 1µs tick으로 수행.
- 신호값 이상·체크섬 불일치·무응답 오류에서는 최근 정상 온습도 레지스터를 갱신하지 않는다.

## 3. 테스트벤치 조건과 한계

- 테스트벤치 시스템 클록 `CLK_HZ=1MHz`로 축소, 1µs = 1tick. 실제 설계 기본값 `CLK_HZ=100MHz`.
- Fake DHT22는 host start LOW 해제 후 30µs 뒤 응답하고 비트 HIGH 28µs/70µs와 LOW 50µs를 발생시킴.
- 정상값, 음수, 체크섬 오류, 완전 무응답, 짧은 HIGH 펄스, 쿨다운 동안 재요청 거부를 검사.
- 실제 상승시간·전압 레벨·정전기·전원노이즈·clock jitter·메타안정성의 아날로그 특성을 검증하지 않았음.
- 기본 100MHz 실제 RTL 타이밍, 모든 허용 공차 구간 경계값, 복수 센서 또는 긴 배선은 아직 시뮬레이션/실물 검증되지 않음.
- DHT22 모듈 3.3V 구동·적절한 외부 풀업·공통 GND를 배선 전에 반드시 확인하고, Basys3 I/O 5V 인가 금지.

## 4. 출처

- [Aosong/ASAIR AM2302 Technical Manual (공식 PDF)](https://www.aosong.com/uploadfiles/2025/04/20250417105409216.pdf), One-wire communication protocol and timing, 40-bit data format, minimum sampling interval and checksum.
- [DigiKey에 수록된 Aosong AM2302 데이터시트](https://www.digikey.in/htmldatasheets/production/1801448/0/0/1/am2302.pdf).

**결론:** 제17장 RTL 펄스폭 통신/온습도 변환/오류 처리 범위는 **Icarus RTL_SIM PASS**. Vivado·Vitis·BOARD·AXI/UVM 검증을 대체하지 않는다.

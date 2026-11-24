# 제2부 19장 — BME280·복합 환경 제어 및 이벤트 우선순위

> 2026-11-11 기준. 사용자 요청에 따라 **Vivado 합성·Implementation·타이밍·Vitis·실물 검증은 보류**.
> 테스트 완료 범위는 `environment_policy` 단위 RTL 및 `bme280_probe` 모의 I²C 레지스터 C 검사다.

## 학습 자료

- [19장 HTML 전체 실습안내서](P2_19_Study_Guide_v01.html)
- [19장 HOST_C / RTL_SIM 검증 보고서](../../docs/P2_19_SIM_VERIFICATION_20261111.md)
- [19장 GitHub Actions](https://github.com/Yuul-Jung/amd_soc/actions/workflows/p2-19-environment-verification.yml)
- [Bosch BME280 공식 데이터시트](https://www.bosch-sensortec.com/media/boschsensortec/downloads/datasheets/bst-bme280-ds002.pdf)
- [Bosch 공식 BME280 SensorAPI](https://github.com/boschsensortec/BME280_SensorAPI)

## 전체 계층

```text
[기존 센서별 독립 Controller]                 [신규/후속]
DHT22 → (temperature_tenths, humidity_tenths, valid)
DS18B20 → (temperature_raw, valid)
DS3231 RTC → (hour, minute, valid)  ─────────────┐
PIR IRQ Controller → (event_pending) ────────────┤
BME280 → Bosch API 보정(실제 통합 미구현) ───────┤
                                                ▼
                                  environment_policy.v
                                  ├ 온도 데이터 우선순위
                                  │  BME280 > DHT22 > DS18B20
                                  ├ 습도: BME280 > DHT22
                                  ├ 이벤트: PIR > 고온 > 고습
                                  ├ display_page 0~4 / display_value
                                  └ display_valid / display_source
                                                ▼
                             기존 FND/LCD Controller 입력 어댑터 (미구현)
                             MicroBlaze V AXI4-Lite 통합 (미구현)
```

**중요**: 위 다이어그램의 기존 센서 연결은 논리적 인터페이스 계약이다. 실제 Top/BD에서 기존 IP들을 동시에 연결하고 검증했다는 의미가 아니다.

## 코드 파일

| 파일 | 주요 역할 |
|---|---|
| `rtl/environment_policy.v` | 센서 샘플 저장, 온도/습도 소스 우선순위, PIR>고온>고습 경보, 표시 페이지 0~4 |
| `sw/bme280_probe.c/.h` | Bosch BME280 7bit 주소 0x76/0x77, Chip-ID 0xD0→0x60, 0xF7..0xFE Raw ADC 8byte Read |
| `tests/tb_environment_policy.v` | 우선순위/장치 누락/오류 fallback/표시/RTC/PIR/경보 자동 판정 |
| `tests/test_bme280_probe.c` | BME280/BMP280 구별, 압력·온도·습도 raw bit extraction, I²C 오류 검사 |
| `tests/run_rtl_tests.sh` | Icarus Verilog RTL_SIM |
| `tests/run_host_tests.sh` | GCC 호스트 C 단위 검증 |

## 단위와 표시 규약

| 데이터 출처 | 입력 단위 | 출력/변환 |
|---|---|---|
| DHT22 `dht_temp_tenths` | 0.1 °C | 그대로 유지 |
| DHT22 `dht_hum_tenths` | 0.1 %RH | 그대로 유지 |
| DS18B20 `ds_temp_raw` | 1/16 °C | 정수 `raw * 10 /16` (소수 절삭) |
| BME280 `bme_temp_centi` | 0.01 °C **보정 완료값만** | /10 |
| BME280 `bme_hum_milli` | 0.001 %RH **보정 완료값만** | /100 |
| BME280 `bme_pressure_pa` | Pa **보정 완료값만** | Pa 유지 |
| RTC `rtc_hour/minute` | 24h 시/분 | HHMM 형태의 정수 |
| PIR `pir_event_pending` | Sticky 1bit | 0/1 |

- **BME280 Raw ADC 값은 실제 온도·습도·기압이 아니다.** 각 기기의 Factory Calibration 데이터를 추출한 뒤 Bosch SensorAPI 보정함수를 통해 물리량으로 바꿔야 한다. 본 장의 `bme280_probe.c`는 레지스터 ID 확인과 Raw ADC 값 추출만 하며 보정은 미구현.
- `environment_policy`는 신뢰 가능한 상류 샘플의 보정 완료값만 받는다는 계약. 각 Controller에서 CRC/Checksum/OSF 등 검증을 통과한 후에만 `*_valid`를 보낸다.
- 현재 RTL은 샘플 수신 후 무기한 보관한다. 자동 Sample Age/Timeout(데이터 신선도 관리)는 미구현이며 실제 제어 시스템에는 별도 추가가 필요하다.
- BME280/DHT22/DS18B20 센서 동시 측정의 시간 동기화는 미구현. 업데이트는 각각 독립.
- 경보는 데모용 고정 비교: 30.0°C 이상, 80.0%RH 이상, PIR Pending 중 하나. 별도 팬·모터 등 액추에이터 제어 출력은 없음.

## 실제 테스트 명령

```bash
# 저장소 루트에서 실행
bash part02/chapters/P2_19_Lesson/tests/run_host_tests.sh
bash part02/chapters/P2_19_Lesson/tests/run_rtl_tests.sh
```

GitHub-hosted Ubuntu runner에 `gcc`와 `iverilog`를 사용한다. **사용자 PC에 설치한 것이 아니다.**

## 검증 Gate

| 분류 | 현황 |
|---|---|
| HOST_C BME280 모의 장치 Chip-ID/Raw8 | 실행 결과는 Actions 로그 및 검증 보고서 확인 |
| RTL_SIM 복합 환경 Policy | 실행 결과는 Actions 로그 및 검증 보고서 확인 |
| AXI_SIM 실제 복합 SoC 통합 | NOT_RUN / 미구현 |
| I²C BME280·DS3231·LCD 공용 버스 중재 | NOT_RUN / 미구현 |
| Bosch BME280 Calibration/Compensation | NOT_RUN / 미구현 |
| Vivado Synthesis/Timing | 보류 |
| Vitis Target/Basys3 Board | 보류 |
| UVM | NOT_RUN |
| HTML Browser Render | NOT_RUN |

기존 01~18장 RTL·C/HTML·성공 Vivado XPR 및 `main`은 변경하지 않고 작업 브랜치로만 저장한다.

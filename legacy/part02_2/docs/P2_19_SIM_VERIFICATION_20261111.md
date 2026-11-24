# 제2부 제19장 BME280 + 복합 환경 제어 — 실제 검증 보고서

- 날짜: 2026-11-11 (KST)
- 공통 기준: `Yuul-Jung/soc`의 CURRICULUM.md, MIGRATION.md, VALIDATION.md, COLLABORATION.md (작업 시작 시 최신 SHA 재확인)
- 구현: `Yuul-Jung/amd_soc`, `work/part02-second-half-20261110`
- **실제 실행 증거:** [GitHub Actions #42952532274](https://github.com/Yuul-Jung/amd_soc/actions/runs/42952532274)
- 테스트 실행 커밋: `2d658f7134a020037d43de184dd2c9154abe9b40`
- 실행 환경: GitHub-hosted Ubuntu 24.04, GCC + Icarus Verilog/vvp.
- 사용자 PC와 Basys3에서 Vivado/Vitis/보드 실행한 것 아님.

## 1. PASS 확인 항목 (실제 CI 출력)

| 범위 | 테스트 | 결과 |
|---|---|---|
| HOST_C | BME280 ID=0x60·BMP280 ID=0x58 거부 | **PASS** — `P2_19_BME280_ID_BMP280_REJECT_PASS` |
| HOST_C | 0xF7~0xFE 8바이트 압력 20bit·온도 20bit·습도 16bit Raw 추출 | **PASS** — `P2_19_BME280_RAW8_DECODER_PASS` |
| HOST_C | I²C Reader 호출 오류 | **PASS** — `P2_19_BME280_BUS_ERROR_PASS` |
| HOST_C | BME280 C 전체 | **PASS** — `P2_19_BME280_HOST_C_PASS` |
| RTL_SIM | 리셋 시 유효 샘플 미존재 | **PASS** — `P2_19_ENV_RESET_NO_STALE_DATA_PASS` |
| RTL_SIM | DS18B20 1/16°C → 0.1°C 표시로 fallback | **PASS** — `P2_19_ENV_DS18B20_FALLBACK_PASS` |
| RTL_SIM | DHT22 입력과 고온 알람·페이지 순환 | **PASS** — `P2_19_ENV_DHT_THRESHOLD_AND_PAGE_ROTATION_PASS` |
| RTL_SIM | 고습 알람 | **PASS** — `P2_19_ENV_HUMIDITY_ALARM_PASS` |
| RTL_SIM | 우선순위 BME280→DHT22→DS18B20, BME 보정값 가정 | **PASS** — `P2_19_ENV_BME280_OPTIONAL_PRIORITY_PASS` |
| RTL_SIM | 물리범위 오류 BME 입력 시 DHT 선택 복귀 | **PASS** — `P2_19_ENV_INVALID_BME_FALLBACK_PASS` |
| RTL_SIM | RTC HHMM 디스플레이 상태 | **PASS** — `P2_19_ENV_RTC_DISPLAY_PASS` |
| RTL_SIM | PIR Pending이 온도·습도보다 우선 | **PASS** — `P2_19_ENV_PIR_ALARM_PRIORITY_PASS` |
| RTL_SIM | 데이터 갱신 카운터 | **PASS** — `P2_19_ENV_UPDATE_ACCOUNTING_PASS` |
| RTL_SIM | 환경 정책 종합 | **PASS** — `P2_19_ENVIRONMENT_POLICY_RTL PASS` |

## 2. BME280 기능 계약과 한계

- Bosch BME280 공식 7-bit 주소: `0x76` 또는 `0x77`; 칩 ID 레지스터 `0xD0`의 정상값 `0x60`.
- BMP280은 별도 센서로 칩 ID `0x58`인 경우 BME280으로 처리하지 않는다.
- 0xF7..0xFE 원시 ADC Data Burst 8바이트 (압력 20bit + 온도 20bit + 습도 16bit)를 C 함수에서 해독.
- **원시 ADC가 실제 단위는 아님**. `Bosch BME280_SensorAPI`의 온습도·기압 보정, 트리밍 계수 읽기 및 전력 모드/oversampling 초기화는 미구현.
- `environment_policy.v`의 `bme_temp_centi`(0.01°C), `bme_hum_milli`(0.001%RH), `bme_pressure_pa`(Pa)는 상류에서 이미 보정한 가상 입력을 사용한 단위시험이다.
- 실제 BME280→I²C Master→C 보정→정규화→RTL 입력 전체 통합은 **NOT_RUN**.

## 3. 복합 정책 계약

```text
DHT22 valid · DS18B20 valid · BME280 compensated valid
        + RTC HH:MM valid + PIR event_pending
                  ↓
       environment_policy.v
        ├ Temperature Source: BME > DHT > DS
        ├ Humidity Source:    BME > DHT
        ├ Alarm:              PIR > HOT(>=30°C) > HUM(>=80%RH)
        └ Display Page:       0 TEMP / 1 HUM / 2 PRESS /
                              3 RTC / 4 PIR
```

- 유효 범위 검사 후 선택하며 Valid 샘플의 내부 래치 보존. 새로운 샘플이 없는 출력 페이지는 `display_valid=0`.
- 샘플 갱신 횟수는 각 Update Cycle의 논리 카운터이며 센서 측정 횟수의 절대적인 기록을 의미하지 않는다.
- `accepted_updates`는 한 클록에 여러 소스가 동시에 유효해도 한 번 증가.
- `alarm_reason`은 대표 알람 원인 하나만 출력한다. 사용자 안전·설비 자동제어용 최종 보호기능은 아님.
- 현재 **Data Age/Timeout, Fail-safe, 센서 간 교차 상관성 검사, 센서별 동기 샘플 보장, 주기 제한, 액추에이터 출력**은 미구현.
- 14장 I²C LCD와 16장 DS3231 RTC, 신규 BME280의 **공용 I²C 버스 중재는 미구현**. 실제 통합 성공으로 표시 금지.
- 기존 LCD/FND 표시 Controller 입력 Adapter 및 AXI4-Lite Slave는 미구현.

## 4. 검증 Gate

| Gate | 상태 |
|---|---|
| HOST_C (BME280 모의 레지스터) | **PASS** |
| RTL_SIM (독립 환경 정책) | **PASS** |
| AXI_SIM (공용 SoC) | **NOT_RUN/미구현** |
| BME280 Calibration/Compensation | **NOT_RUN/미구현** |
| Shared I²C arbitration | **NOT_RUN/미구현** |
| Vivado Synthesis/Timing | **사용자 요청으로 보류** |
| Vitis BSP/ELF / Basys3 Board | **사용자 요청으로 보류** |
| UVM | **NOT_RUN** |
| WEB_RENDER | **NOT_RUN** (HTML 저장/상대 경로 정적 검사와 구분) |

## 5. 공식 근거

- [Bosch Sensortec BME280 데이터시트](https://www.bosch-sensortec.com/media/boschsensortec/downloads/datasheets/bst-bme280-ds002.pdf)
- [Bosch BME280 SensorAPI](https://github.com/boschsensortec/BME280_SensorAPI)
- [BME280 공식 레지스터 헤더](https://github.com/boschsensortec/BME280_SensorAPI/blob/master/bme280_defs.h)

**판정:** 제19장 환경 정책 단위 RTL 및 BME280 ID/Raw C 검증 **PASS**. 종합 복합 SoC 통합 및 실측 성공으로 보고하지 않는다.

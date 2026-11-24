# 제2부 20장 — 복합 환경·PIR·스테핑 모터 종합 SoC 실습

> **검증 범위:** 12.4장 `stepper_ramp_core.v`, 18장 `pir_irq_controller.v`, 19장 `environment_policy.v` 실제 RTL 소스를 그대로 인스턴스화하고, 20장 신규 `soc20_safety_supervisor.v`를 연결한 디지털 통합 **RTL_SIM**.
>
> **미검증:** 13장 RFID, 14장 LCD, 16장 I²C RTC, 19장 BME280 물리 버스와 AXI CPU 통합, Vivado 합성/타이밍, Vitis 실제 타깃, Basys3 실물 센서·모터, UVM. 사용자 요청에 따라 후자 검증은 보류.

## 교육자료

- [제20장 전체 HTML 배포용 학습안내서](P2_20_Study_Guide_v01.html)
- [실제 RTL 통합 검증 보고서](../../docs/P2_20_SIM_VERIFICATION_20261111.md)
- [P2-20 GitHub Actions 테스트](https://github.com/Yuul-Jung/amd_soc/actions/workflows/p2-20-capstone-verification.yml)
- [제2부 11~20장 테크트리](../../docs/P2_11_20_ROADMAP.md)

## 실제 통합된 RTL 원본

| 모듈 | 경로 | 통합 상태 |
|---|---|---|
| 기존 12.4장 가감속 스텝 모터 | `../P2_12_Lesson/rtl/stepper_ramp_core.v` | **직접 인스턴스** |
| 기존 18장 PIR 입력·Sticky IRQ | `../P2_18_Lesson/rtl/pir_irq_controller.v` | **직접 인스턴스** |
| 기존 19장 복합 센서 선택·표시 정책 | `../P2_19_Lesson/rtl/environment_policy.v` | **직접 인스턴스** |
| 신규 데이터 신선도·수동 재가동 차단 | `rtl/soc20_safety_supervisor.v` | 신규 |
| 신규 세 모듈 결합 Core | `rtl/soc20_integrated_core.v` | 신규 |
| 전체 자가검증 TB | `tests/tb_soc20_integrated_core.v` | 신규 |

기존 12.4/18/19장 소스를 복사·수정하지 않고 **컴파일 파일 경로로 그대로 참조**한다. 합성 가능성·실제 IRQ/AXI 연결까지 검증한 것이 아니다.

## 데이터·제어 흐름

```text
외부 장치의 디코딩/CRC/OSF 검증된 sensor_valid
      ├── DS18B20 온도 raw 1/16°C
      ├── DHT22 온도·습도 0.1°C / 0.1%RH
      ├── BME280 이미 보정된 값(가상 샘플; 실제 보정 미구현)
      └── DS3231 RTC 검증된 24h 시·분
             │
             ▼
      environment_policy.v ─── display_page/value/source
             │                  (LCD/FND 표시 인코더 미연결)
             └ alarm_reason: PIR > 고온 > 고습
                   │
PIR pin → pir_irq_controller.v ── Pending·IRQ (CPU IRQ 미연결)
                   │
                   ▼
      soc20_safety_supervisor.v
        Freshness MAX_AGE_CYCLES
        Fault Latched / Explicit Arm Required
                   │
                   ▼
          actuator_permit
                │   ├ False → motor start 차단
                │   └ False → motor stop 강제, coil_o 0
                ▼
      stepper_ramp_core.v (12.4장 원본)
                ▼
       motor_coil[3:0] (논리 출력만, 실제 ULN2003 미연결)
```

## Fail-safe 데모 정책

1. 초기에는 `actuator_permit=0`, 모터 시작 요청은 차단.
2. CRC/Checksum 검증을 마친 유효한 온도 샘플의 `valid` 입력으로 Freshness 갱신.
3. `actuator_arm`을 명시적으로 받은 경우에만 스텝 모터 허용.
4. PIR Pending, 고온(30.0°C 이상), 고습(80.0%RH 이상) 발생 시 모터 허용 즉시 해제, 정지 입력 활성화.
5. 지정 유효기간 `MAX_AGE_CYCLES` 동안 새 온도 샘플이 없으면 데이터 만료로 정지.
6. 오류/경보 해제만으로 자동 재시작 금지. **Fault Clear → 새 Arm → 별도 Motor Start**가 필요하다.
7. 이 Fail-safe는 **교육용 인터록**이며 산업 안전 인증 기능은 아니다. 리셋 이후 대기, 경보 이력 저장, 위험도 평가, 이중화 및 전기적인 안전정지는 구현되지 않았다.

**중요:** 이 시험의 Valid는 테스트벤치가 발생시키는 이미 검증된 샘플로 가정한다. 실제 기존 센서 상류 IP의 Valid 연결과 BME280 보정, 오류 상태까지 자동으로 처리하지는 않는다. 온도센서 없는 경우 새 샘플이 수신되지 않는 것으로만 인식한다.

## 테스트 실행

```bash
# 저장소 루트에서 실행
bash part02/chapters/P2_20_Lesson/tests/run_rtl_tests.sh
```

GitHub Actions는 별도 Ubuntu 24.04 러너에서 Icarus Verilog를 설치해 시뮬레이션한다. 사용자 개인 PC에서 테스트·도구 설치를 수행한 것이 아니다.

## 통합 검증 Gate

| Gate | 판정 |
|---|---|
| RTL_SIM: 실제 기존 12.4 + 18 + 19 RTL 모듈 통합 | Actions 실행 PASS 기준 |
| 새 Supervisor RTL_SIM | Actions 실행 PASS 기준 |
| HOST_C | NOT_RUN — 신규 C 드라이버 미작성 |
| AXI_SIM / AXI Interconnect / Interrupt Controller | NOT_RUN — 실제 BD 결합 미구현 |
| SPI RFID / I²C LCD·RTC·BME280 실제 트랜잭션 | NOT_RUN / 미구현 |
| SYNTH_TIMING | 사용자 요청 보류 |
| VITIS_TARGET/BOARD | 사용자 요청 보류 |
| UVM | NOT_RUN |
| HTML Browser Render | NOT_RUN |

기존 성공 프로젝트 `~/soc/hw/soc_hw.xpr`, 제2부 01~19장 소스와 `main`은 그대로 유지한다.

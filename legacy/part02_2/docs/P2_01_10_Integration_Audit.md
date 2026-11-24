# 제2부 01~10장 통합 적대적 검증 보고서

검증 기준일: 2026-11-06  
검증 대상: 기존 10개 장별 ZIP을 풀어 동일 파일·HTML 링크·C 호스트 시험·공용 소스를 대조한 **교재·C 모의 검증**  
GitHub 공통 기준: `Yuul-Jung/soc` `main` `e374824c32d68156f2f86805b6303f19413267cc`; `CURRICULUM.md`, `MIGRATION.md`, `VALIDATION.md`, `COLLABORATION.md`  
실물/합성/Vitis 실제 검증: **하지 않음**.

## 1. 전체 판정

| 범위 | 실제 결과 | 해석 |
|---|---|---|
| 장별 ZIP | **10/10 무결성 PASS**, ZIP 내부 총 537개 파일 | 파일 손상·패키지 내부 불일치 미발견 |
| HTML 로컬 링크/앵커 | **795건 검사, 깨진 링크 0건** | 외부 URL 동작 및 시각 레이아웃은 대상 아님 |
| HTML ID 중복 | 0건 | 파서 기반 정적 검사 |
| 공용 C/RTL 변경 | 03→10장 인접 쌍에서 기존 동일 경로 소스 **143개 일치**, 무단 수정 0건 | 변경된 이름이나 별도 복제본을 의미하지 않음 |
| C 호스트 시험 | **01~10장 10/10 스크립트 정상 종료** | GCC/모의 BSP; 실제 FPGA 아님 |
| FPGA RTL_SIM / AXI_SIM | 미실시 | 이 실행 환경에 `iverilog`/`verilator` 미설치 |
| 합성/타이밍/DRC | 미실시 | Vivado 실행하지 않음 |
| 실제 Vitis BSP/ELF | 미실시 | 테스트 스텁은 대상 BSP가 아님 |
| Basys3/외부 센서/모터 | 미실시 | 물리적 동작·전기안전 PASS 아님 |
| 브라우저 레이아웃 | 미완료 | 로컬 링크 검사와 구분 |
| GitHub 반영/게시 | 미실시 | 로컬 감사본만 제공 |

## 2. 발견한 문제와 조치

| ID | 중요도 | 실제 근거 | 처리 |
|---|---|---|---|
| I-01 | **P0** | 01~08장 C에서 제1부 LED14 UART 표시·LED15 Timer heartbeat 구현 누락. 09~10장 C는 복원 코드 있음. | 기능 보존 완료로 선언하지 않음. 04·05장 과장된 설명 **수정**. 실습 전 소프트웨어 회귀 범위 결정 필요 |
| I-02 | **P0** | 01~10장 실제 Vivado BD/AXI IP/Wrapper/주소는 각 장의 목표만 작성된 상태. 제2부 01장 신규 XPR은 사용자 제시로 확인, AXI 신규 RTL은 아직 실제 구현 미확인. | 현재 장별 모든 FPGA/보드 게이트 **미실시** 유지 |
| I-03 | **P0** | 07~10장 모터 보호는 RTL 코드·계약으로만 존재, 현장 전기적 시험과 독립 RTL/AXI 시뮬레이션 없음. | 위험 상황 자동보호를 검증한 안전장치라고 주장하지 않음. 모터/전원 연결은 정지·제어 출력 검증 후 진행 |
| I-04 | **P1** | 08장 배포 HTML에 `~` 절대경로 2곳 발견. | 통합 배포본에서 사용자 계정이 없는 GUI 홈 폴더 탐색 경로로 **수정**. 정적 문자 검색 재검사 |
| I-05 | **P1** | 03장 버튼 이벤트는 8비트 PENDING 비트맵으로 이벤트 다중 발생 시 합쳐질 수 있음. `COALESCED`는 손실 표시이지 개별 이벤트 수 저장소가 아님. | 이벤트 손실 없는 보장을 하지 않고 측정·경계 테스트 요구 |
| I-06 | **P1** | 08~10장 XADC `ADC READ`는 저장 레지스터 값 읽기이며 신규 변환 완료 확인이 없음. | 최신 측정값 보장 금지; 모터 안전 판단에 XADC 사용하지 않음 |
| I-07 | **P1** | UART 명령은 문자열+Enter로 설계되었으나 제1부 원본 C는 단일 문자 방식을 사용함. | 신규 제2부 코드를 문자열 명령 규격으로 유지. 09장 LED14는 명령 완료 활동 표시이지 기존 `'1'/'0'` 직접 제어와 동등하지 않음 |
| I-08 | **P1** | 09/10장 SDT 다중 인터럽트 등록은 AMD 2024.2 `XSetupInterruptSystem()` 공식 구현과 구조상 비교되지만 실제 프로젝트 BSP에서 IRQ 라우팅/동작 증거 없음. | BSP/Interrupt ID/Parent/Clock/Timer 구현을 보드에서 검증하기 전 PASS 금지 |
| I-09 | **P1** | 실제 HTML 데스크톱/모바일 화면 전체 검증 누락, 자동 생성 GUI 캡처는 교육용 확인이 아님. | 배포 직전 실제 화면 확인 필요 |

## 3. 장별 소프트웨어 기능 상태

| 장 | 새로운 과제 | LED14/15 C 동작 | 현 판정 |
|---|---|---|---|
| 01 | 사용자 AXI LED IP | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 02 | FND 4자리 표시 | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 03 | 방향 버튼 Short/Long·IRQ | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 04 | 범용 PWM 밝기 제어 | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 05 | 디지털 CdS 자동 조명 | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 06 | HC-SR04 거리 측정 | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 07 | DC 모터 보호·제어 | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 08 | XADC 측정·PWM 반영 | 미이식(배선과 구분) | 교육자료 초안, 하드웨어 미검증 |
| 09 | UART·IRQ·운전 모드 통합 | 09장부터 새 통합 코드 존재 | 교육자료 초안, 하드웨어 미검증 |
| 10 | 안전 상태 기반 종합제어 | 10장 통합 코드 존재 | 교육자료 초안, 하드웨어 미검증 |

## 4. 실제 수행한 호스트 시험

```text
01: 문자열 명령·입력 예외 HOST 테스트 12/12 PASS / Mock BSP 컴파일 PASS
02: LED/FND 문자열·선행 0 HOST 테스트 12/12 PASS / Mock BSP 컴파일 PASS
03: HOST_LOGIC PASS / 29 assertions / SDT·Classic stub syntax PASS
04: HOST_LOGIC PASS / 45 assertions / SDT·Classic stub syntax PASS
05: HOST_CDS_REGRESSION PASS / 45 assertions / SDT·Classic stub syntax PASS
06: HOST_SONIC PASS / 35 assertions + CDS 45 / SDT·Classic stub syntax PASS
07: MOTOR_PARSER PASS / 23 assertions / SDT·Classic stub syntax PASS
08: ADC_MATH PASS / 12,307 assertions / SDT·Classic stub syntax PASS
09: MODE/POLICY PASS / 62 assertions + INTEGRATION 30 / SDT·Classic stub syntax PASS
10: CAPSTONE/POLICY PASS / 76 assertions + INTEGRATION 31 / SDT·Classic stub syntax PASS
```

이 테스트는 실제 `xparameters.h` 주소, IP 하드웨어, 인터럽트 배선, 외부 아날로그/모터 안전성을 검증하지 않는다. `logs/`에 01~10장 실제 재실행 결과를 기록한다.

## 5. 최종 실습 전 필수 게이트

1. 01장 실제 사용자 IP RTL 생성, 신규 프로젝트 내부 파일 독립성, Address Editor·Wrapper 확인.
2. 01~07장 순서대로 Core/AXI TB 실행 → BD Validate → Synthesis/Timing → XSA/Vitis BSP/ELF → 보드 기능별 기록.
3. 03장 인터럽트 누락·5초 Short/Long·버튼 동시 입력·W1C 동시 이벤트·COALESCED 반례 실행.
4. 04장 PWM 0/100, 주기 경계 갱신, 극성, 05장 CdS 필터/Auto, 06장 HC-SR04 Timeout·5V ECHO 레벨변환 확인.
5. 07장 L298N 실사용 회로와 전원·ENA 풀다운·Deadtime·TRIP·센서 Freshness를 모터 분리 단계부터 검증.
6. 08장 XADC 0~1V 아날로그·실제 Wizard 구성·채널·차동 입력을 확인. 전압 미측정 시 접속 금지.
7. 09장 기존 LED14/15 및 버튼/Timer 복수 IRQ 실제 동작 확보; 이전 01~08장 기능 누락 여부 기록.
8. 10장 종합 상태·오류/재시작·RUN 명령 검증. 실제 안전인증/긴급정지 기능이라는 표현 금지.
9. HTML 실제 브라우저·화면 캡처 개인정보·이미지 메타데이터 점검 후 게시 여부 결정.

## 6. 조치 원칙

- 기존 01~10장 원본 ZIP과 사용자 PC의 성공 프로젝트는 **수정하지 않음**.
- 이 통합 검토본은 04·05·08장 배포 HTML의 확인된 오기만 직접 수정한 별도 버전이다.
- RTL/C 전체 코드의 검증 근거 없이 구조적 개선을 일괄 적용하거나 PASS를 만들어내지 않음.
- 01~10장의 통합 실물 검증은 아직 실행하지 않았으며, 본 보고서 자체는 승인을 뜻하지 않음.

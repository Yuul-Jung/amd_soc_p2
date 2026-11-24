# 제2부 05~08장 외부 하드웨어 명세

## 장별 준비물

| 장 | 추가 외부 하드웨어 | 확정에 필요한 사양 |
|---|---|---|
| 05 | 비교기 포함 CdS 디지털 DO 모듈, 점퍼선 | 제조사·모델, 핀 순서, VCC 범위, 소비전류, DO 출력 방식·전압, 명암 극성, 감도 조절 방법 |
| 06 | HC-SR04 계열 초음파 모듈, ECHO 레벨 변환 회로, 센서 전원 | 정확한 모델, 공급전압·전류, TRIG 입력 임계값, ECHO 출력전압, 변환 회로 사양 |
| 07 | L298N 계열 드라이버 모듈, DC 모터, 별도 모터 전원 | 모듈 회로·점퍼, 입력 논리 정격, 모터 정격전압·정지전류, 드라이버 허용전류·방열 조건, 전원 용량 |
| 08 | 가변저항 등 아날로그 신호원, 입력 분압 회로 | 저항값·허용오차, 공급전압, 출력 범위, XADC 단자 실측전압 |

기존 기능을 유지하는 누적 실습이므로 이전 장의 부품도 사용한다.
09장은 기존 하드웨어 통합, 10장은 IP 라이브러리 정리 범위이며 추가 외부 부품 필요 여부는 최종 과제 구성에 따른다.

## 신호 연결표

| 장 | RTL 신호 / 기능 | Basys3 커넥터 | FPGA 핀 | 외부 연결 |
|---|---|---|---|---|
| 05 | `cds_digital` | JA1 | J1 | CdS DO. AO 미사용 |
| 06 | `sonic_trig` | JA2 | L2 | 센서 TRIG |
| 06 | `sonic_echo` | JA3 | J2 | 센서 ECHO → 레벨 변환 → FPGA |
| 07 | `motor_in1` | JB1 | A14 | 드라이버 IN1 |
| 07 | `motor_in2` | JB2 | A16 | 드라이버 IN2 |
| 07 | `motor_ena` | JB3 | B15 | 드라이버 ENA |
| 08 | `vauxp6` | JXADC1 | J3 | 범위를 제한한 아날로그 신호 |
| 08 | `vauxn6` | JXADC7 | K3 | GND 기준 단극성 구성의 아날로그 GND |

일반 Pmod의 5·11번은 GND, 6·12번은 3.3V 전원이다. 센서 VCC는 실제 모듈 정격에 따라 별도로 확정한다.
신호 접지는 보드와 외부 회로가 공유한다. 디지털 신호는 현재 XDC의 LVCMOS33 기준을 따른다.
5V DO/ECHO를 FPGA에 직접 연결하지 않는다. 모터 전력은 별도 전원에서 공급한다.
ENA 점퍼·외부 풀다운·드라이버 로직 전원은 실제 모듈 회로를 확인해 확정한다.
08장 교재는 단극성 VAUX6 차동 입력을 0~1.0V로 제한한다. Pmod의 3.3V 디지털 신호 기준과 구분한다.
XADC의 공통모드·절대최대 정격과 최종 입력 회로는 UG480 및 보드 회로도를 함께 대조한다.

## 05장 연결 절차

1. 실제 CdS 모듈 모델명·핀 배열·전원 연결을 기록한다. 기판의 표시 LED와 DO 출력의 관계를 확인한다.
2. DO를 FPGA에서 분리한 상태에서, 모듈 GND 기준으로 밝을 때와 가렸을 때 DO 전압을 각각 측정한다.
3. DO 출력 방식과 풀업 전압을 확인하고, FPGA 입력과 호환되는 전압인지 판정한다.
4. 전원을 끄고 DO → JA1, 공통 GND, 커넥터 방향을 확인한다.
5. 연결 후 `CDS READ`의 RAW가 실제 명암에 따라 바뀌는지 먼저 확인하고 `CDS POL LOW/HIGH`를 설정한다.
6. `PWM 50`, `AUTO ON`에서 밝을 때 소등·어두울 때 점등을 반복 확인한다.

## 참고 문서

- [Digilent Basys3 매뉴얼](https://reference.digilentinc.com/_media/reference/programmable-logic/basys-3/basys3_rm.pdf), 17~18쪽: Pmod 전원·접지·핀 배치와 JXADC.
- [Digilent 공식 Master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc).
- [AMD UG480](https://docs.amd.com/v/u/en-US/ug480_7Series_XADC): XADC 입력 조건 최종 대조용.
- [06장 추가 XDC](../part02/chapters/P2_06_Lesson_20261106/rtl/sonic_jumper_only.xdc).
- [07장 하드웨어 계약](../part02/chapters/P2_07_Lesson_20261106/docs/07_hardware_contract.md).
- [08장 하드웨어 계약](../part02/chapters/P2_08_Lesson_20261106/docs/08_hardware_contract.md).

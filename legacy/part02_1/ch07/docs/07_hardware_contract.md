# P2-07 하드웨어 계약

## 실행 기준
- 출발: 06장 **실제 완성 프로젝트** 복제. 06장 HTML/ZIP 제작만으로 XPR이 존재한다고 가정하지 않는다.
- 06장 소스는 변경하지 않으며 `reuse/p2_06`의 독립 사본에서만 포트 3개 추가.
- Top은 Shell only: wire, instance, 고정 bit connection만 허용.
- 신규 motor AXI IP의 `S00_AXI`는 **기존 06장과 같은 AXI 클록/리셋**에 연결.

## SONIC→MOTOR 안전 포트
| SONIC 복제본 출력 | 07장 모터 입력 | 의미 |
|---|---|---|
| `sonic_auto_o` | `sonic_auto_i` | 주기 측정 허용 여부 |
| `sonic_done_o` | `sonic_done_i` | 측정 완료 1클록 펄스 |
| `sonic_valid_o` | `sonic_valid_i` | 최근 완료 결과 유효 여부 |
| `sonic_unsafe_o` | `sonic_unsafe_i` | 유효하지 않음 또는 임계 거리 이내, WARN_EN과 독립 |

`sonic_alert_o`는 LED2 전용으로 남는다. `WARN OFF`는 모터 안전을 해제하지 않는다.

## 신규 07장 Motor AXI 레지스터(32비트 데이터, byte offsets)
| Offset | 항목 | 접근 | 설명 |
|---|---|---|---|
| 0x00 | CMD | R/W | 0=STOP, 1=FWD, 2=REV. STOP write clears TRIP; invalid command returns SLVERR |
| 0x04 | STATUS | R | bit0 EN, 1 FWD, 2 REV, 3 TRIP, 4 DEADTIME, 5 SAFE, 6 FRESH, 7 AUTO, 8 REQ_NONZERO, 9 BLOCKED |
| 0x08 | ID | R | 0x00070001 |
| 0x0C | DEADTIME | R | minimum off-time cycles when leaving active drive |
| 0x10 | FRESHNESS | R | maximum duration from last valid sonar DONE |
| 0x14 | CLK_HZ | R | AXI clock used for motor controller |

## 모터 출력을 구동하는 조건
`sonic_auto_i && fresh_count>0 && sonic_valid_i && !sonic_unsafe_i && !trip_latched && requested_dir!=STOP`.
- `sonic_unsafe_i`가 1이면 ENA는 클록을 기다리지 않고 조합 경로에서 0.
- 유효 신호 없는 부팅, 측정 중지, Timeout, 샘플 250 ms 초과 시 ENA 0.
- RUN→STOP/반전에서 정지 기간을 두어 빠른 역방향 변경을 억제.
- TRIP 후 자동 재가동 금지. `MOTOR STOP`로 해제하고 새 `MOTOR FWD/REV` 필요.
- 소프트웨어의 안전 판정은 편의/응답 메시지이며 최종 구동 여부는 RTL이 결정.

## 물리 연결 / 보드 핀
- JB1 A14 → IN1, JB2 A16 → IN2, JB3 B15 → ENA (XDC LVCMOS33)
- ENA 연결 전 하드웨어 점퍼 제거/풀다운, 드라이버 5V 로직 공급과 외부 모터 전원 확인.
- FPGA Pmod 전원에서 DC 모터를 직접 구동하지 않는다.
- HC-SR04 5V ECHO를 Basys3 입력에 직접 연결하지 않는다.
- 모터 차단 후 기계적 관성으로 즉각 정지하지 않을 수 있다. 인명 안전용 아님.

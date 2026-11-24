# 통합 감사본 변경 이력

작성일: 2026-11-06

## 최소 수정 원칙
- 01~10장 소스 C/Verilog, 테스트벤치, 공용 라이브러리는 변경하지 않음.
- 04·05장의 과장된 기능 보존 설명과 08장 절대경로 2곳만 교정.
- 원본 각 장 ZIP과 사용자 PC Vivado/Vitis 프로젝트는 변경하지 않음.

## 실제 문서 수정
- P2-04: 하드웨어 배선과 C 기능의 구분. `이전: LED14 UART, LED15 Timer 계통 유지` → `수정: LED14/15 GPIO 배선 유지 · C 표시 기능은 09장 통합 대상`
- P2-04: 04장 미이식 기능 명시. `이전: LED14 UART와 LED15 Timer 경로를 그대로 둔다.` → `수정: LED14/15의 기존 GPIO 배선은 유지하지만, 이 장 C 프로그램에는 UART 표시·Timer heartbeat 처리가 없다.`
- P2-04: 검증 항목을 실제 지원 범위로 수정. `이전: LED14·LED15과 FND, 버튼 IRQ의 기존 출력이 유지되어야 한다.` → `수정: FND와 버튼 IRQ 기능 및 LED14/15 GPIO 배선을 확인한다. LED14·LED15 소프트웨어 표시 동작은 이 장에서 지원하지 않으며 09장 통합 대상이다.`
- P2-05: 05장 출력 기능 과대 표시 제거. `이전: LED14 UART · LED15 Timer 유지` → `수정: LED14/15 GPIO 배선만 유지 · 소프트웨어 표시는 09장부터 구현`
- P2-05: 05장 실습 불가능한 검사항목 제거. `이전: LED14/15, <code>STATUS</code>를 모두 시험한다.` → `수정: <code>STATUS</code>를 시험한다. LED14/15 GPIO 배선은 확인하되, 이 장 C 프로그램에 없는 UART 표시·Timer heartbeat의 기능 검증은 09장 이후에 진행한다.`
- P2-08: 개인계정 포함 절대경로 익명화. `이전: ~/soc/hw/soc_ip_design_07/soc_ip_design_07.xpr` → `수정: Home → soc → hw → soc_ip_design_07 → soc_ip_design_07.xpr`
- P2-08: 개인계정 포함 절대경로 익명화. `이전: ~/soc/hw/` → `수정: Home → soc → hw/`

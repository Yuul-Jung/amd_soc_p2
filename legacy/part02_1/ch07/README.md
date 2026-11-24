# 제2부 07장 — DC Motor + SONIC Safety Interlock

- 메인 교재: [P2_07_Study_Guide.html](P2_07_Study_Guide.html)
- C 전체 해설: [P2_07_C_Explained.html](P2_07_C_Explained.html)
- RTL 전체 해설: [P2_07_RTL_Explained.html](P2_07_RTL_Explained.html)
- 독립 설계 계약: [07_hardware_contract.md](docs/07_hardware_contract.md)

## UART 명령
`MOTOR FWD`, `MOTOR REV`, `MOTOR STOP`, `MOTOR STATUS` (모두 Enter 실행). 기존 SONIC/WARN/LED/DISP/PWM/AUTO/CDS/STATUS 문자열 명령 유지.

## 폴더
- `rtl/`: 07장 motor controller / AXI slave / IP top / Basys3 Top / JB XDC
- `sw/`: 07장 `main_p2_07.c`, 독립 파서, 03~06장의 기존 C 보조 파일
- `reuse/`: 02~06장 RTL 재사용. 06장 AXI 포트 변경은 여기 **사본**에만 반영.
- `tests/`: C 호스트 테스트, RTL/AXI 테스트벤치와 실행 스크립트
- `assets/`: 구조도/명령 흐름 (SVG, PNG, Mermaid, DOT)

## PC에서 사전 확인
- 해당 단계 GUI가 실제 Vivado 2024.2/패키지 생성 화면과 일치하는지 대조
- 사용자가 01~06장 실제 구현을 끝내고 올바른 최신 XSA를 준비한 뒤 07장 실행
- `xparameters.h`와 인터럽트 설정에 맞추어 C의 P2_01~P2_07_BASEADDR 및 `P2_03_BTN_INTR_*` 정의
- LED14 UART/LED15 Timer 동작은 09장 통합 애플리케이션에서 추가

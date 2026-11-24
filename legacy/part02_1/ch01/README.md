# 제2부 01장 · 사용자 AXI4-Lite LED 제어 — 따라하기 패키지

## 시작점
- 기준 프로젝트: `soc11_user_top` — 수정하지 않음.
- **다음 작업:** 신규 프로젝트를 열어 `p2_01_axi_led` Wizard IP 생성. IP 생성 전에는 사용자 Top 신규 파일을 적용하지 않음.
- UART: `LED ON`, `LED OFF`, `STATUS` + Enter.

## 읽는 순서
1. `P2_01_Study_Guide.html` — 전체 따라하기 실습 절차.
3. `P2_01_main.c` / `P2_01_C_Explained.html` — 실제 C 코드와 구문 해설.

## 실습 범위
- AXI IP 생성, LED0 연결, 문자열 명령 처리, 독립 테스트를 순서대로 수행한다.
- 실제 Address Editor와 새 XSA/BSP의 주소를 사용한다.

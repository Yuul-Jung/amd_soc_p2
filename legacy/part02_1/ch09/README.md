# 제2부 09장 — UART/IRQ + MODE AUTO/MANUAL 통합

- [09장 따라하기 학습안내서](P2_09_Study_Guide.html)
- [C 전체 소스·해설](P2_09_C_Explained.html)
- [기존 RTL·인터럽트 해설](P2_09_RTL_Explained.html)
- [09장 메인 C](sw/main_p2_09.c)
- [09장 MODE/IRQ 파서](sw/p2_09_mode_logic.c)
- [09장 하드웨어 계약](docs/09_hardware_contract.md)
- [호스트 테스트 스크립트](tests/run_host_tests.sh)

기존 01~08장 기능을 유지하면서 `MODE AUTO`, `MODE MANUAL`, `MODE STATUS`, `IRQ STATUS` 및 기존 `STATUS` 필드를 확장한다. 제1부 11장 LED14/15 **의미를 그대로 복원한 게 아니며**, 문자열 명령 활동 표시와 Timer IRQ heartbeat로 재정의한다.

**주의**: 모의 BSP 빌드는 실제 Vitis 2024.2 BSP 빌드가 아니다. XPR/BD/Bitstream/XSA/ELF는 실습에서 새로 생성한다. `reference/main_p2_08.c`를 Vitis의 컴파일 대상에 넣지 않는다.

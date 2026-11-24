# 제2부 08장 — XADC Wizard AXI4-Lite + PWM LED1

- [따라하기 학습안내서](P2_08_Study_Guide.html)
- [C 전체 소스 해설](P2_08_C_Explained.html)
- [Top·RTL/AXI 전체 해설](P2_08_RTL_Explained.html)
- [C 메인](sw/main_p2_08.c)
- [ADC 변환/문자열 처리 모듈](sw/p2_08_adc_logic.c)
- [Top](rtl/basys3_soc11_top_p2_08.v)
- [계약](docs/08_hardware_contract.md)

UART 새 명령: `ADC READ`, `ADC PWM`. 후자는 **1회 Duty 설정**이며 센서의 연속 자동 추종 기능이 아닙니다.

`reuse/`는 07장 이전 RTL 그대로 복사한 참고 원본입니다. `sw/`에 03~07장 독립 C 로직이 모두 포함되며, 빌드시 이전 `main_p2_07.c`는 제외합니다.

**실제 AXI 주소·새 XADC Wizard 생성 RTL 및 Wrapper 포트 이름은 Vivado에서 확인해야 합니다.** Host mock BSP 테스트 성공은 실물 동작을 의미하지 않습니다.

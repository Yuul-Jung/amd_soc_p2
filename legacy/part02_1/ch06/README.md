# P2-06 — HC-SR04 distance + AXI4-Lite + FND / LED2

## 바로 열기
- `P2_06_Study_Guide.html` : 22단계 따라하기 교재
- `P2_06_C_Explained.html` : C 전체 코드·해설
- `P2_06_RTL_Explained.html` : RTL 전체 코드·해설

## 재사용 소스
- `sw/` : P2-03~05 응용 로직 유지, P2-06 main/parser 추가
- `reuse/` : 기존 P2-02 FND, P2-03 button, P2-04 PWM, P2-05 CdS RTL
- `rtl/` : P2-06 HC-SR04 Core, AXI Slave, IP Top, Basys3 Top, incremental XDC
- `tests/` : C Host 모의 및 Verilog 테스트벤치
- `assets/` : Graphviz SVG/PNG, Mermaid(.mmd) 원본

## 시작 프로젝트
01~05장 실습을 완료한 뒤 05장 프로젝트를 복제하여 06장 작업을 시작한다.

## 안전
HC-SR04 ECHO는 5V 출력일 수 있으며 Basys3 JA3으로 직접 연결 금지.
TRIG 3.3V 수용 여부는 실제 센서 모듈을 확인.

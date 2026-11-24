# Basys3 + MicroBlaze V SoC — 제2부 05장

**시작:** `P2_05_Study_Guide.html` (오프라인 브라우저로 열기)

## 과제
- CdS 디지털 DO(JA1 J1) → 2FF + 20ms 필터 → AUTO/수동 모드 게이트 → 기존 LED1 PWM.
- 이전 명령 `LED ON/OFF`, `DISP 1234`, `DISP OFF`, `PWM 0..100`, `STATUS` 보존.
- 신규 명령 `AUTO ON`, `AUTO OFF`, `CDS READ`, `CDS POL LOW`, `CDS POL HIGH`.
- P2-04 기본 active-high PWM에만 적용. 다른 polarity는 새 설계 계약 필요.

## 구성
- `P2_05_Study_Guide.html`: 제1부 07장 스타일 따라하기 절차.
- `P2_05_C_Explained.html`: AMD u8/u32/API·명령 및 전체 코드 풀이.
- `P2_05_RTL_Explained.html`: Core/AXI/Gate/Top 전체 소스와 해설.
- `sw/`: Vitis main + 05장 파서 및 03/04장 보존 파일.
- `rtl/`: 05장 신규 Core/Gate/AXI/Top/XDC 및 04장 PWM 원본.
- `reuse/`: 이전 02장 FND/03장 버튼 RTL 보존 참고.
- `tests/`: host C, Mock SDT/Classic 구문, Verilog TB.

## 독립 확인
```bash
bash tests/run_host_tests.sh  # GCC + 모의 BSP, 실제 Vitis 빌드 아님
bash tests/run_rtl_tests.sh   # iverilog/vvp 없으면 NOT_RUN
python3 tests/verify_package.py
```

**실제 Vivado/Vitis/Basys3는 수행하지 않음.** 실제 입력 모듈의 3.3V/DO 극성 및 신규 Wrapper 출력은 후속 실습에서 확인한다. 원본 성공 프로젝트는 수정하지 않았다.

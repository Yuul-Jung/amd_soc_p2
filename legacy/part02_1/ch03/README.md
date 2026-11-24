# 제2부 03장 — 방향 버튼 Short/Long + AXI4-Lite IRQ + FND

**시작 파일:** `P2_03_Study_Guide.html`

## 학습자료·코드

| 파일 | 용도 |
|---|---|
| `P2_03_Study_Guide.html` | 16단계 따라하기, 설계 개념, 실습 결과 |
| `P2_03_C_Explained.html` | AMD API, 자료형, ISR, C 전체 소스, 값 추적 |
| `P2_03_RTL_Explained.html` | 버튼 Core, AXI Slave, Top 전체 소스·해설 |
| `sw/main_p2_03.c` | 실제 Vitis C 애플리케이션; BSP 입력 미설정 시 컴파일 차단 |
| `sw/p2_03_logic.c/.h` | PC/SoC 공용 버튼 매핑, BCD, 문자열 파싱 |
| `rtl/button_event_core.v` | 4개 버튼 2FF/디바운스/5초 LONG 생성 |
| `rtl/p2_03_axi_buttons_v1_0.v` | IP Top: 버튼 Core + AXI Slave |
| `rtl/p2_03_axi_buttons_v1_0_S00_AXI.v` | 5개 레지스터, W1C, COALESCED, IRQ |
| `rtl/basys3_soc11_top_p2_03.v` | 순수 배선형 사용자 Top (Wrapper 재생성 후 적용) |
| `rtl/basys3_buttons_only.xdc` | Basys3 방향 버튼 4개 핀 |
| `tests/*` | PC C, RTL/AXI 독립 테스트 및 스텁 |

## 보존·선행 관계

- 기존 성공 원본 `soc11_user_top`은 수정하지 않는다.
- `soc_ip_design_01`(LED) 및 `soc_ip_design_02`(FND)를 완료한 뒤 `soc_ip_design_03`에 복제하여 추가한다.
- 01·02장 IP를 대체하지 않으며 03장 코드는 그 주소/기능을 재사용한다.
- 기존 UART 명령: `LED ON`, `LED OFF`, `DISP 1234`, `DISP 0050`, `DISP OFF`, `STATUS`.
- BTNC(U18)는 기존 Reset으로 유지; 4개 방향 버튼만 이벤트 입력.

## UART 및 버튼 동작

| 버튼 | SHORT | LONG(5초) |
|---|---|---|
| U | VALUE +1 | VALUE +100 |
| D | VALUE -1 | VALUE -100 |
| L | VALUE/EVENTS 전환 | VALUE 0000 초기화 |
| R | FND ON/OFF | 전체 초기화 + FND ON |

숫자 범위 0000~9999(순환), FND의 네 자릿수는 천/백/십/일.
`EVENTS`는 프로그램이 처리한 버튼 이벤트 수이며, 실제 하드웨어의 이벤트 합침이 발생한 경우 전부 복구되지 않는다.

## 테스트 실행

```bash
# 이 패키지 폴더에서만 실행한다 (사용자 PC Vivado 프로젝트 수정 없음)
bash tests/run_host_tests.sh
bash tests/run_rtl_tests.sh
```

- C Host Logic과 Mock BSP SDT/Classic 구문을 확인한다.
- RTL/AXI 테스트는 iverilog/vvp 또는 Vivado Simulator에서 실행한다.
- 개인 경로·토큰·계정 캡처는 패키지에 포함하지 않는다.

## 실제 실행 때 바꿀 설정

1. `S00_AXI_ACLK` 실측 주파수를 확인하고 20ms, 5초의 카운트를 재산정.
2. Vivado IP Packager 생성 파일/외부 포트/Bus Metadata를 이 예제와 대조.
3. 실제 Address Editor, 새 XSA와 BSP로 01/02/03 IP Base Address 채우기.
4. SDT `P2_03_BTN_INTR_ID`, `P2_03_BTN_INTR_PARENT`를 실제 생성 코드에서 확인.
5. Timer와 버튼 IRQ 모두 기존 AXI INTC에 연결되고 CPU 쪽 경로는 중복되지 않는지 확인.
6. 01·02장 기존 LED/FND/UART 기능이 유지되는지 확인.

# 제2부 04장 — AXI4-Lite PWM LED1

**시작 파일:** `P2_04_Study_Guide.html` (오프라인 브라우저로 열기)

## 배포 자료

| 파일 | 용도 |
|---|---|
| `P2_04_Study_Guide.html` | 17단계 독립 따라하기 학습안내서 |
| `P2_04_C_Explained.html` | 전체 C 소스·u8/u32/AMD API·계산 해설 |
| `P2_04_RTL_Explained.html` | PWM Core / AXI Slave / IP Top / Board Top 전체 풀이 |
| `sw/main_p2_04.c` | 기존 P2-03 명령·IRQ를 유지한 Vitis 진입 C 소스 |
| `sw/p2_04_pwm_logic.c/.h` | 독립 UART PWM Parser + Duty 계산 |
| `sw/p2_03_logic.c/.h` | 03장 사용자 모듈의 원본 그대로 재사용 |
| `rtl/pwm_core.v` | 보드 독립 PWM Core |
| `rtl/p2_04_axi_pwm_v1_0*.v` | AXI4-Lite 사용자 IP 및 AXI Slave |
| `rtl/basys3_soc11_top_p2_04.v` | LED0·LED1·기존 GPIO의 단일 출력 소유권 |
| `tests/tb_*.v` | 0/50/100%, 주기 경계 및 AXI 프로토콜 테스트벤치 |
| `tests/run_host_tests.sh` | 호스트 C 단위 테스트 + SDT/Classic Mock BSP 구문 점검 |
| `tests/run_rtl_tests.sh` | iverilog/vvp가 있을 때만 실제 RTL 실행, 없으면 NOT_RUN |

## 명령

```
LED ON
LED OFF
DISP 1234
DISP 0050
DISP OFF
PWM 0
PWM 50
PWM 100
STATUS
```

`PWM 0..100`은 **LED1**에만 적용됩니다. LED0은 01장 AXI IP가 담당합니다.
LED14/15는 기존 UART/Timer 흐름을 유지합니다.

## 독립 실행 테스트 (Vivado 원본 프로젝트 수정 없음)

```bash
bash tests/run_host_tests.sh
bash tests/run_rtl_tests.sh
python3 tests/verify_package.py
```

## 후속 실제 실습에서 필수 확인
- P2-03 프로젝트를 복제한 신규 `soc_ip_design_04`에만 작업.
- IP Packager 생성 RTL/Port/AXI Address Width(최소 6비트) 및 Output Products 확인.
- `soc11_integration_wrapper`에 P2-04 `pwm_led1` 외부 포트 생성 확인.
- `s00_axi_aclk` 실제 속도 및 출력 LED1 E19 XDC 1회 배정 확인.
- 4개의 기존 IP Base 주소와 버튼 IRQ ID/Parent를 새 XSA/BSP에서 확인.

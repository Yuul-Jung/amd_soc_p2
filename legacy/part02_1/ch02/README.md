# P2-02 · AXI4-Lite 사용자 IP 기반 Basys3 내장 FND 4자리 제어

- 학습안내서: `P2_02_Study_Guide.html` (첫 번째로 열기)
- C 풀이: `P2_02_C_Explained.html`
- RTL 풀이: `P2_02_AXI_Explained.html`
- 실행용 C: `sw/main_p2_02.c` (실제 주소 설정 전에는 의도적으로 컴파일 실패)
- RTL: `rtl/fnd_scan_controller.v`, `rtl/p2_02_axi_fnd_v1_0.v`, `rtl/p2_02_axi_fnd_v1_0_S00_AXI.v`
- 보드 Top: `rtl/basys3_soc11_top_p2_02.v` (BD가 새 포트 생성한 뒤 반영)
- XDC 추가분: `rtl/basys3_fnd_only.xdc` (원본 제약 파일 덮어쓰기 금지)
- FND Core + AXI TB: `tests/*.v`, `tests/run_rtl_tests.sh`
- Host C mock: `python3 tests/verify_host.py`

## 프로젝트 적용

- 배포물은 IP Packager 프로젝트나 XPR/XSA/ELF/Bitstream을 포함하지 않는다.
- `USER_IP_BASEADDR`와 `FND_IP_BASEADDR`는 새 BSP의 값으로 설정한다.

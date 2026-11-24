# 제2부 13장 — SPI RC522 RFID 통신

> 기준일 2026-11-11. **현재 완료: SPI Mode0 레지스터 읽기/쓰기 RTL 시뮬레이션, VersionReg 프로브 RTL 시뮬레이션.**
> 실제 RFID UID 수집, AXI4-Lite 통합, Vivado, Vitis 및 Basys3 실물은 **미실행/미구현**, 보류된 합성 및 실물 검증을 수행하지 않음.

## 학습안내서

- [제13장 HTML 본문 및 전체 RTL/테스트벤치](P2_13_Study_Guide_v02.html)
- [제2부 후반부 테크트리](../../docs/P2_11_20_ROADMAP.md)
- [제13장 GitHub Actions](https://github.com/Yuul-Jung/amd_soc/actions/workflows/p2-13-spi-verification.yml)
- [13장 실제 C/RTL 검증 보고서](../../docs/P2_13_SIM_VERIFICATION_20261111.md)
- [NXP 공식 MFRC522 데이터시트](https://www.nxp.com/docs/en/data-sheet/MFRC522.pdf)

## 설계 계층

```text
PC UART / MicroBlaze V (후속 AXI 연결)
             |
      Version Probe
      mfrc522_version_probe.v
             |
       SPI Register Master
       mfrc522_spi_master.v
             |
      SCK/MOSI/MISO/NSS
             |
       MFRC522 RC522 보드
```

- `mfrc522_spi_master.v`: SPI mode0, 16비트 단일 레지스터 Read/Write, `CLK_DIV`로 출력 SCK 주파수 결정, `cmd_valid/cmd_ready` 및 `rsp_valid` 핸드셰이크.
- `mfrc522_version_probe.v`: VersionReg(0x37) 읽기 명령을 한 번 생성하고 응답 8비트를 저장.
- `mfrc522_version_system.v`: 독립 모듈 2개 조합, 특정 FPGA 핀 및 Top에 종속되지 않음.
- `tb_mfrc522_spi_master.v`: MOSI 16비트, NSS 범위, 가짜 MISO 데이터 수신 확인.
- `tb_mfrc522_version_system.v`: 전체 VersionReg 프로브 경로를 가짜 칩 응답 0x92로 시뮬레이션.

## 공식 MFRC522 프로토콜 근거

- SPI는 SCK 유휴 LOW, 상승 에지에서 입력을 수신하며 MSB부터 전송한다.
- 첫 주소 바이트는 `{read, addr[5:0], 1'b0}`이다.
- `VersionReg` 주소 0x37 읽기에서 MOSI `EE 00` → 두 번째 바이트 MISO를 결과로 취급.
- VersionReg 공식 버전 값 0x91/0x92를 참고하되, 이 값은 **RFID 카드 UID가 아니라 리더기 칩 버전**이다.
- VCC·I/O 3.3V 호환 및 실제 RST, 포트 할당은 보드 사용 전 확인한다.

## 후속 실제 RFID 기능

1. 13.1 SPI Master, Testbench: 작성·검증
2. 13.2 VersionReg / 레지스터 통신: RTL/모의 슬레이브 테스트 검증
3. 13.3 REQA/ATQA, 충돌 없는 4바이트 UID 및 BCC: **호스트 C + 가짜 MFRC522 모델 구현/검증**. 소프트 리셋·실제 칩 초기화·7/10바이트 UID·충돌 복구·카드 SELECT는 미구현
4. 13.4 AXI4-Lite IP, MicroBlaze V/Vitis, 실제 UID UART 출력: **미구현**

## 검증

```bash
cd part02/chapters/P2_13_Lesson
bash tests/run_rtl_tests.sh
bash tests/run_host_tests.sh
```

실행 도구 `iverilog`, `vvp`가 있어야 한다. GitHub Actions는 runner에 설치해 실제 실행한다. 사용자 PC에 직접 설치한 것은 아니다.

HOST_C: **PASS (가짜 칩 REQA/UID4 모의 검사)**; RTL_SIM: **PASS** ([실행 로그](https://github.com/Yuul-Jung/amd_soc/actions/runs/42941268865)); AXI_SIM: NOT_RUN; SYNTH_TIMING: 보류; VITIS_TARGET: 보류; BOARD: 보류; WEB_RENDER: 미실행; UVM: NOT_RUN.

제2부 01~12장과 `main` 브랜치는 변경하지 않았다.

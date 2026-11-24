# 제2부 13장 SPI + RC522 RFID — 실행 검증 기록

- 기준일: 2026-11-11 KST
- 저장소: `Yuul-Jung/amd_soc`
- 브랜치: `work/part02-second-half-20261110` (main·기존 01~12장 보존)
- 실증 기준 GitHub Actions: [#42941757544](https://github.com/Yuul-Jung/amd_soc/actions/runs/42941757544)
- 실행 커밋: `185c4ccfd6b3e644be852a10a360a82f967f409f`
- 환경: GitHub-hosted ubuntu-24.04, gcc, Icarus Verilog 12.0.
- **사용자 로컬 Ubuntu에 시뮬레이터를 설치하거나 Vivado를 실행하지 않음.**

## 1. 결과

| 범위 | 상태 | 실행 로그 |
|---|---|---|
| HOST_C REQA → ATQA → CL1 AntiCollision | **PASS** | `P2_13_UID4_MOCK_REQA_ANTICOLL_PASS` |
| HOST_C BCC 오류 거부 | **PASS** | `P2_13_UID4_MOCK_BCC_REJECT_PASS` |
| HOST_C Cascade Tag 0x88 거부 | **PASS** | `P2_13_UID4_MOCK_CASCADE_REJECT_PASS` |
| HOST_C 무응답 타임아웃 거부 | **PASS** | `P2_13_UID4_MOCK_TIMEOUT_PASS` |
| HOST_C 요약 | **PASS** | `P2_13_UID4_C_HOST_PASS` |
| RTL_SIM 0x37 VersionReg 읽기 | **PASS** | `P2_13_SPI_VERSION_REGISTER_READ PASS` |
| RTL_SIM 레지스터 쓰기 | **PASS** | `P2_13_SPI_REGISTER_WRITE PASS` |
| RTL_SIM SPI Mode0 Master | **PASS** | `P2_13_SPI_MASTER_RTL PASS` |
| RTL_SIM 상위 Version Probe | **PASS** | `P2_13_VERSION_PROBE_SYSTEM PASS` |
| MFRC522 실제 카드 UID | **NOT_RUN** | 가상 SPI·C 모의 레지스터 장치만 사용함 |
| 실제 AXI4-Lite/IP Interconnect | **NOT_RUN** | 신규 AXI IP 미구현 |
| Vivado Synthesis/Timing | **보류** | 사용자 요청 |
| Vitis BSP/ELF/FPGA 보드 | **보류** | 사용자 요청 |
| UVM | **NOT_RUN** | 현재 Verilog self-checking TB와 Host C 검사 채택 |
| HTML 브라우저 시각 검증 | **NOT_RUN** | 저장/정적 링크 검사는 별도로 가능 |

## 2. 설계 계약

- SPI는 Mode0, 16비트 1레지스터 트랜잭션, MSB 우선, `{read, six-bit address, zero}` 첫 바이트.
- `VersionReg=0x37` 읽기 명령 MOSI는 `0xEE 0x00`. 모의 MFRC522 응답 0x92 수신, **실물 버전 검증은 하지 않음**.
- 리더 칩 버전 정보와 RFID 카드 UID를 구분한다.
- C 호스트 드라이버는 등록된 `read/write` 콜백으로 REQA/ATQA, CL1 UID4, BCC 검사를 수행한다. **선행 RFID 리더 초기화 및 안테나 구동은 포함하지 않는다.**
- 무선 충돌 처리, 7/10바이트 UID, SELECT 및 카드 인증 구현은 후속 작업. UID 단독 값을 출입 보안용 인증으로 사용하지 않는다.
- 13장 처음부터 끝까지 실제 합성/실물 시험은 사용자 승인 없이 진행하지 않는다.

## 3. 공식·교차 근거

- NXP [MFRC522 데이터시트](https://www.nxp.com/docs/en/data-sheet/MFRC522.pdf): SPI 핀·Mode0, Address Byte, 레지스터·버전.
- [Arduino MFRC522v2 공식 프로젝트 소스](https://github.com/OSSLibraries/Arduino_MFRC522v2): MFRC522 레지스터 이름/주소 및 PICC 관련 명령 대조.
- 프로젝트 공통 승인 문서: `Yuul-Jung/soc` `CURRICULUM.md`, `MIGRATION.md`, `VALIDATION.md`, `COLLABORATION.md`.

**검증 결론:** 신규 13장 SPI 레지스터 통신 RTL + C의 제한된 UID4 모의칩 검증 PASS. 실물 RFID 인식 완료가 아니며 SoC 통합 미검증.

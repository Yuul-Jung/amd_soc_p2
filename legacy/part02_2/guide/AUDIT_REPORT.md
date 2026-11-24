# 제2부 11~20장 HTML 학습안내서 · 적대적 검증 및 보완 결과

**점검일:** 2026-11-16 KST

**검토 기준:** `Yuul-Jung/rule_md` @ `38f7b0a6513bbd23dc4d70798ef3c65541c412ae`의 `web/education-html/STANDARD.md`, `INTEGRATION.md`, `fpga-soc/MBV_SOC_rules.md`.

**공통 프로젝트 기준:** `Yuul-Jung/soc`의 `CURRICULUM.md`, `MIGRATION.md`, `VALIDATION.md`, `COLLABORATION.md` 최신 파일/커밋 재확인. 수정 저장소 `Yuul-Jung/amd_soc`, 분리 작업 브랜치 `work/part02-second-half-20261110`. 기존 성공 RTL/XPR 및 `main` 변경 없음.

## 1. 검사 범위 및 실제 확인

| 항목 | 판정 | 실행·근거 |
|---|---|---|
| INDEX 표지·테크트리 1개 | 정적 확인 | `index.html`, 11~20장 링크 |
| 장별 교육용 HTML 10개 | 정적 확인 | `ch11_*_v05.html` ~ `ch20_*_v05.html` |
| 12.1~12.4 파생 실습 HTML 4개 | 정적 확인 | `labs/P2_12_1_Lab_v06.html` ~ `P2_12_4_Lab_v06.html` |
| 12장 XDC·C 부속 소스 3개 | 복사 원문 대조 대상 | `labs/12_2_jc_candidate.xdc`, `12_3_board_smoke.c`, `12_4_ramp_vitis_example.c` |
| 기존 장별 HTML 71개 `<pre>` 코드블록 | **원문 일치 PASS** | GitHub 연결 소스와 11~20장 전체 직접 재대조 |
| 기존 12.1~12.4 코드블록 11개 | **원문 일치 PASS** | 기존 v04와 신규 배포 v06 원문 비교 |
| HTML 15개 내부 파일·앵커 링크 | **점검 범위에서 누락 0** | 현재 Git Tree와 장·표지·12.x 페이지 상대 링크 대조 |
| 코드 복사·메뉴 실제 UI 동작 | **미검증** | JS 개선했으나 실브라우저 클릭 시험 미실행 |
| 데스크톱·모바일 화면 실제 렌더링 | **미검증** | Chromium 각 폭별 실화면 캡처/육안 검증 미실행 |
| GitHub Pages URL 게시·접속 | **미검증** | 브랜치에 파일을 저장한 것이 Pages 게시 완료를 의미하지 않음 |
| Vivado·Vitis·실물·UVM | **보류/미실행** | 기존 사용자 검증 보류 지시 유지 |

### 이번 수정의 실제 내용

1. 표지에서 **기존 원본 저장소 내부 폴더**로 향하던 12.1~12.4 링크를 통합 교재 내부 `labs/`로 바꾸고, 필요한 XDC·C 파일도 함께 복사했다.
2. 11~20장 본문의 장간 이동을 **통합 교재 최신 HTML**로 바꾸고, 원본 README/검증 보고서를 참조하는 링크는 GitHub 원본 파일로 구분했다. 테크트리 링크는 내부 INDEX로 통일했다.
3. 하위 `labs/`에서도 왼쪽 메뉴의 INDEX·장별 링크에 상위 경로가 적용되도록 `site.js`를 수정했다.
4. 코드 복사는 보안 컨텍스트에서 Clipboard API가 거부되는 경우를 고려해 대체 복사 방식과 실패 안내를 추가했다.
5. 모바일에서 긴 표/코드/제목의 가로 넘침과 낮은 대비의 메타문자 가독성을 보강했다.
6. `tests/check_html.py`에서 **옛 버전 잔존, 중복 ID, 내부 앵커, CSS/JS/그림 파일, URL 탈출, 민감한 문자열, 장별 탐색 manifest, 원본 코드 일치, 12.x 부속 소스 원문**을 검사하도록 강화했다.
7. 전용 GitHub Actions는 PR 변경 범위 전체를 검사하도록 경로 규칙을 보완하고 중복 실행 취소 및 Python/Node 문법 검사 단계를 추가했다.

## 2. 위험도별 기술 검토 — 변경하지 않은 기존 RTL 포함

| 위험도 | 발견·기술적 쟁점 | 현재 처리 |
|---|---|---|
| **높음** | 20장의 `soc20_integrated_core.v`는 `sample_valid(dht_valid||ds_valid||bme_valid)`을 사용한다. 단순 Valid가 들어올 때 **선택된 실제 센서값의 물리적 범위 및 품질과 관계없이** 신선도 타이머가 갱신될 수 있어 부적절한 값이 반복되면 데이터 만료 차단을 우회할 위험이 있다. | **미해결·실물 적용 금지.** 학생용 INDEX에 한계를 명시. 실제 하드웨어 제어 전에 센서별 Range/Quality/Age 검사 및 반례 TB 추가 필수. 기존 성공 RTL은 검증 없이 수정하지 않음. 추적: [Issue #3](https://github.com/Yuul-Jung/amd_soc/issues/3) |
| **높음** | 제20장의 안전 차단은 교육용 논리 인터록이며, 모터 전원 차단·비상 정지·고장 이중화가 없다. | 학생용 설명에서 산업 안전 장치로 표현하지 않으며 실제 모터 연결 전 별도 안전 회로 필수 |
| **높음** | 14장 I²C LCD 쓰기 전용 마스터와 16장 DS3231 읽기 명령 시퀀서는 전체 I²C Read/Repeated-START 하드웨어 경로가 아니다. | PHY/공용 버스/IP/CPU 연결 미구현 유지; 실제 시계 값 읽기 PASS로 표시 금지 |
| **높음** | 19장 BME280 Chip-ID/Raw8 비트 분리는 검증했지만 Bosch 보정 계수·Compensation 구현이 없다. | 테스트 BME 값은 **보정 완료로 가정한 가상 입력**임을 유지; 실제 기압·습도·온도 실측 미검증 |
| **중간** | 13장 RFID 제한형 UID4 모의는 실제 카드 UID/보안 인증과 다르다. | 원본 설명의 모의/실물 범위를 그대로 구분; Full RFID 성공 표현 금지 |
| **중간** | 12장 배포용 JC XDC는 **후보**이며 기존 핀 소유권/3.3V I/O·외부 5V 모터 전원에 대한 물리 검증이 없다. | 실물 연결·핀 확정 보류. 사용자 XPR 변경 없음 |
| **중간** | 동일한 책장 사진은 공개 `rule_md`의 원본 URL에서 불러오며 IBM 웹 폰트도 외부 접속이 필요하다. | 온라인 표준과 동일, 오프라인 이미지 부재 가능; 배포 직전 실제 로딩·오프라인 표시 검사 필요 |
| **중간** | 학생용 페이지에 GitHub의 **비공개 작업 저장소**를 가리키는 일부 원본·검증 상세 링크가 남아 있다. | GitHub 로그인이 없는 일반 방문객은 열지 못할 수 있음. 공개 Pages 게시 전 외부 자료 공개 범위를 검토하거나 공개 가능한 별도 자료로 대체 |

## 3. 자동 검증 상태 — PASS 여부 구분

과거 [GitHub Actions #43045479756](https://github.com/Yuul-Jung/amd_soc/actions/runs/43045479756), 이번 재검토 중 실행된 [#43737510650](https://github.com/Yuul-Jung/amd_soc/actions/runs/43737510650), [#43737709160](https://github.com/Yuul-Jung/amd_soc/actions/runs/43737709160)는 **conclusion: failure**이다. 연결된 API가 제공하는 Job에는 `steps:null`만 있고 Job 로그 다운로드는 `BlobNotFound` 오류가 발생했다. 따라서 **CI 실패 원인을 Python 검사 실패 또는 GitHub 러너 인프라 문제 중 하나로 단정할 근거가 없다**. GitHub Actions PASS로 보고하지 않는다.

이번에 `.github/workflows/p2-11-20-guide-verification.yml`을 변경해 전체 콘텐츠 변화를 감시하도록 수정했다. **새 CI 실행 결과를 확인하기 전에는 정적 대조 PASS와 Actions PASS를 혼동하지 않는다.**

현재 직접 확인한 원본 코드 82블록 일치 및 상대 링크 점검 누락 0은 **GitHub에서 파일 내용을 직접 읽어 수행한 정적 검사**이며, 별도의 브라우저 검증·GitHub-hosted Runner 성공을 의미하지 않는다.

## 4. Pull Request 병합 위험

작업 PR [#2](https://github.com/Yuul-Jung/amd_soc/pull/2)는 **Draft 상태**다. 2026-11-16 조회 시 `mergeable=false`, `mergeable_state=dirty`였다. `main`은 다른 작업에 의해 기존 PR의 기준 커밋 이후 이동했으며, 기존 성공 프로젝트를 보호하기 위해 **자동 병합·강제 재베이스를 시도하지 않았다**. 병합 전 충돌 파일별 수동 검토가 필요하다.

## 5. 출판 전 필수 Gate

1. GitHub Actions 새 검사 실행 **실제 PASS** 또는 로컬에서 `python3 tests/check_html.py`, `node --check assets/site.js` 성공 로그 확보.
2. 실브라우저에서 1920·1366·1024·768·390·320px 화면의 표·SVG·코드, 모바일 메뉴, 키보드 탐색·Escape, 코드 복사 실제 동작 검증.
3. 새 통합 HTML 15개 및 12.x C/XDC 부속 3개를 같은 디렉터리 구조로 게시하여 INDEX→모든 장/파생 실습 접속 검사.
4. 공개 사이트로 게시할 경우 비공개 GitHub 소스·검증 로그 링크 노출 정책 확인 및 불필요한 계정/로컬 경로/토큰/이미지 메타데이터 정리.
5. 20장 센서 유효기간의 **품질·물리 범위 검증 결함**을 별도 RTL·TB 과제로 해결하고 나서 실물 모터 구동 Gate 검토.
6. 현재 Vivado·Vitis·Basys3 합성·실물 시험은 기존 사용자 지시대로 보류.

**판정:** 11~20장 교육용 HTML의 구조·링크·코드 보존·실습 패키징은 정적 검토와 보완을 수행했다. GitHub Actions, 실제 브라우저 렌더링, 전체 MicroBlaze V SoC 통합 및 실물 성공은 **미통과/미검증으로 별도 관리**한다.

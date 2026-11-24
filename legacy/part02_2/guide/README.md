# 제2부 11~20장 · 통합 HTML 학습안내서

- **표지/목차/전체 테크트리:** [index.html](index.html)
- **장별 최신 결과물:** `ch11_*_v05.html` ~ `ch20_*_v05.html` (10개)
- **12.1~12.4 파생 실습:** `labs/P2_12_1_Lab_v06.html` ~ `labs/P2_12_4_Lab_v06.html` (4개) + 원본 복사 부속 XDC·C 소스 3개
- **공통 디자인:** `assets/site.css`, `assets/site.js`
- **강의 구성:** 필요성 → 구조 → 신호/데이터 → 실제 RTL·C 전체 소스 → 따라하기 → 결과 판정
- **자동 정적 검사:** `tests/check_html.py`
- **적대적 검증:** [AUDIT_REPORT.md](AUDIT_REPORT.md)

## 적용 규칙

[Yuul-Jung/rule_md 교육용 HTML 표준](https://github.com/Yuul-Jung/rule_md/blob/38f7b0a6513bbd23dc4d70798ef3c65541c412ae/web/education-html/STANDARD.md)

- 동일한 책장 사진 배너(공개 `rule_md`의 원본 이미지를 직접 참조), 좌측 전체 장/절 탐색, 모바일 슬라이딩 메뉴.
- `IBM Plex Sans KR` 및 `IBM Plex Mono`, 표준 #F1F2EE 배경, 보라색 강조.
- 이전/다음 장, INDEX 복귀, 키보드 접근, Escape로 모바일 메뉴 닫기, 코드 복사.
- **원본 HTML·Verilog·C 코드·테스트벤치 원문은 기존 chapter 폴더에 보존**. 변경된 파일은 이 독립된 교재 출력 폴더에만 저장.
- 장별 결과물은 `_v05.html`, 12.1~12.4 실습 결과물은 `_v06.html`만 출력 폴더에 보관; 원래 교재와 Git 이력은 삭제하지 않음.
- `index.html`은 고정 진입점으로 유지.

## Github Pages 게시 참고

현재 브랜치 자료는 GitHub 저장소에 저장된 상태이며 **GitHub Pages 실제 배포·브라우저 화면 렌더링 검증이 완료되었다는 의미는 아님**. 게시 전에 `index.html`, `assets/`, 10개 장 HTML, `labs/`의 파생 실습 및 XDC·C 파일까지 같은 상대 경로 구조로 배포해야 한다. 원본/검증 보고서를 참조하는 비공개 GitHub 링크는 일반 방문객에게 열리지 않을 수 있어 공개 범위를 먼저 확인한다.

웹 이미지와 외부 IBM Plex 웹 폰트는 네트워크 사용이 제한된 오프라인 환경에서 불러오지 못할 수 있다. 기본 시스템 글꼴 및 배경색은 유지된다.

## 로컬에서 정적 검증

```bash
# 저장소 루트에서 실행
python3 part02/chapters/P2_11_20_Guide/tests/check_html.py

# 시스템에 Node.js가 있다면 탐색 JS 문법 검사
node --check part02/chapters/P2_11_20_Guide/assets/site.js
```

GitHub Actions workflow: `.github/workflows/p2-11-20-guide-verification.yml`.

**2026-11-16 상태:** 이전 GitHub Actions HTML 검사 실행에서 `failure`가 확인되었으며, 연결된 작업 로그를 복원하지 못했다. 새 검증 스크립트/워크플로의 PASS를 확인하기 전까지 **정적 수동 대조 결과와 CI 성공을 구분**한다. 자세한 실패 이력과 병합 충돌은 `AUDIT_REPORT.md` 참조.

## 검증 판정 기준

- **PASS:** 실제 실행된 유효한 CI 로그가 있고 소스 정합성 확인.
- **미검증:** 실제 브라우저·Vivado 합성·Vitis 타깃/보드 시험 없음.
- **미구현:** 장별 RTL/AXI/RTC/BME280/공용 I²C 일부 기능이 존재하지 않는 경우.

제20장 **실제 통합 RTL_SIM PASS**는 12.4, 18, 19장의 기존 RTL을 참조한 제한 범위에 한정하며 제2부 전체 Full SoC의 성공으로 해석하지 않는다.

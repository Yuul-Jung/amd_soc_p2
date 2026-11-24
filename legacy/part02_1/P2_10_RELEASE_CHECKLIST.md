# 제2부 10장 — IP 배포 준비 체크리스트

## 포트·사양
- [ ] IP 이름·버전·기능 요약·라이선스 결정
- [ ] AXI4-Lite 32비트·Clock·Reset·주소 정렬·WSTRB 동작 명세
- [ ] 각 IP의 파라미터, 외부 입력/출력, IRQ 극성, 레지스터 맵 확인
- [ ] 보드 종속 핀(XDC)과 IP 내부 RTL 분리
- [ ] 실제 `component.xml`에 RTL 파일과 Port/Bus Interface가 모두 등록
- [ ] AMD 제공 IP/XADC 생성물의 재배포 가능 범위 확인

## 배포
- [ ] 개인/계정/토큰/내부 경로·이미지 노출 점검
- [ ] 사용법·샘플 프로젝트·FAQ 준비
- [ ] LICENSE와 버전 태그 확정
- [ ] 릴리스 ZIP 생성 후 압축 해제·동일 환경 외부 재현
- [ ] GitHub Release 배포 및 파일 링크 검사

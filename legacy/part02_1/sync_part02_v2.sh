#!/usr/bin/env bash
# 제2부 01~10장 교재·SVG·사양서를 GitHub 원본 그대로 로컬에 복사합니다.
set -euo pipefail

REPO="https://github.com/Yuul-Jung/amd_soc.git"
DEST="${HOME}/soc/part02_v2"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# private GitHub 저장소에 접근 가능한 Git 인증이 필요합니다.
git clone --quiet --depth 1 --filter=blob:none --sparse "$REPO" "$TMP_DIR/amd_soc"
git -C "$TMP_DIR/amd_soc" sparse-checkout set part02_v2

# 기존 hw/soc*.xpr은 수정하지 않고, 자료 폴더만 생성·갱신합니다.
mkdir -p "$DEST"
cp -a "$TMP_DIR/amd_soc/part02_v2/." "$DEST/"

printf '동기화 완료: %s\n' "$DEST"
printf 'HTML 목차: %s/index.html\n' "$DEST"
find "$DEST" -maxdepth 2 -type f | wc -l

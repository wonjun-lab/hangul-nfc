#!/bin/sh
#
# uninstall.sh — nfd2nfc 완전 제거 (= nfd2nfc uninstall)
#
#   ./uninstall.sh
#
# Finder 우클릭 메뉴·자동 감시·설정·로그와 CLI(직접 설치본, Homebrew 설치본)를 모두 지운다.
#
set -eu

MARK='^# nfd2nfc — macOS 한글 파일명'
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || HERE=$(pwd)

# 제거 로직은 CLI 안에 있다. 예전 버전 CLI엔 uninstall이 없으므로 이 저장소 사본을 먼저 쓴다.
CLI=""
for c in "$HERE/nfd2nfc" "$(command -v nfd2nfc 2>/dev/null || true)" \
         /opt/homebrew/bin/nfd2nfc /usr/local/bin/nfd2nfc "$HOME/.local/bin/nfd2nfc"; do
    if [ -n "$c" ] && [ -f "$c" ] && grep -q "$MARK" "$c" 2>/dev/null && grep -q "^sub uninstall_main" "$c"; then CLI=$c; break; fi
done
if [ -z "$CLI" ]; then
    echo "설치된 nfd2nfc가 없습니다."
    exit 0
fi
exec /usr/bin/perl "$CLI" uninstall "$@"

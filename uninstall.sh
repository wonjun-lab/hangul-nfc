#!/bin/sh
#
# uninstall.sh — hangul-nfc 완전 제거 (= hangul-nfc uninstall)
#
#   ./uninstall.sh
#
# Finder 우클릭 메뉴·자동 감시·설정·로그와 CLI(직접 설치본, Homebrew 설치본)를 모두 지운다.
#
set -eu

MARK='^# hangul-nfc — macOS 한글 파일명'
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || HERE=$(pwd)

# 제거 로직은 CLI 안에 있다. 예전 버전 CLI엔 uninstall이 없으므로 이 저장소 사본을 먼저 쓴다.
CLI=""
for c in "$HERE/hangul-nfc" "$(command -v hangul-nfc 2>/dev/null || true)" \
         /opt/homebrew/bin/hangul-nfc /usr/local/bin/hangul-nfc "$HOME/.local/bin/hangul-nfc"; do
    if [ -n "$c" ] && [ -f "$c" ] && grep -q "$MARK" "$c" 2>/dev/null && grep -q "^sub uninstall_main" "$c"; then CLI=$c; break; fi
done
if [ -z "$CLI" ]; then
    # CLI가 이미 없어도 install.sh가 ~/.zprofile에 넣은 PATH 블록은 남아 있을 수 있다(CLI의 uninstall이 평소 지움).
    PROFILE="$HOME/.zprofile"
    if grep -qF '# >>> hangul-nfc PATH >>>' "$PROFILE" 2>/dev/null; then
        # sed -i는 파일을 새로 만들어 심링크(dotfiles 관리 등)를 깨므로, 걸러서 제자리에 다시 쓴다.
        TMPF=$(mktemp)
        sed '/^# >>> hangul-nfc PATH >>>$/,/^# <<< hangul-nfc PATH <<<$/d' "$PROFILE" > "$TMPF" && cat "$TMPF" > "$PROFILE"
        rm -f "$TMPF"
        echo "✓ ~/.zprofile에서 hangul-nfc PATH 설정 제거"
    fi
    echo "설치된 hangul-nfc가 없습니다."
    exit 0
fi
exec /usr/bin/perl "$CLI" uninstall "$@"

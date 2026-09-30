#!/bin/sh
#
# install.sh — nfd2nfc 설치 (한 줄로 끝)
#
#   ./install.sh                  # Homebrew가 있으면 brew로, 없으면 ~/.local/bin에 설치
#   ./install.sh --from-source    # 이 저장소의 nfd2nfc를 그대로 ~/.local/bin에 설치(개발용)
#   curl -fsSL https://raw.githubusercontent.com/wonjun-lab/nfd2nfc/main/install.sh | sh
#
# 설치 뒤 `nfd2nfc setup`으로 Finder 우클릭 메뉴까지 만든다.
# 업데이트: nfd2nfc update · 상태 점검: nfd2nfc doctor · 제거: nfd2nfc uninstall
#
set -eu

REPO=wonjun-lab/nfd2nfc
MARK='^# nfd2nfc — macOS 한글 파일명'
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || HERE=$(pwd)
FROM_SOURCE=0
for a in "$@"; do
    case "$a" in
        --from-source) FROM_SOURCE=1 ;;
        *) echo "알 수 없는 옵션: $a" >&2; exit 2 ;;
    esac
done

echo "▸ nfd2nfc 설치를 시작합니다."

# 1.1.x 이하의 install.sh는 Homebrew 경로(/opt/homebrew/bin 등)에 일반 파일을 뒀다. 이 사본은
# 이후 brew install의 링크 단계와 충돌하므로 치운다 — 우리 스크립트인 일반 파일만(심링크는 brew 것).
for f in /opt/homebrew/bin/nfd2nfc /usr/local/bin/nfd2nfc; do
    if [ -f "$f" ] && [ ! -L "$f" ] && grep -q "$MARK" "$f" 2>/dev/null; then
        rm -f "$f" && echo "  ✓ 예전 설치본 정리: $f"
    fi
done

BREW=""
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then BREW=$b; break; fi
done
[ -n "$BREW" ] || BREW=$(command -v brew 2>/dev/null || true)

if [ "$FROM_SOURCE" = 0 ] && [ -n "$BREW" ]; then
    # Homebrew가 있으면 brew로 관리한다 — 업데이트(brew upgrade / nfd2nfc update)와 제거가 한 경로로 된다.
    echo "  • Homebrew로 설치합니다"
    if "$BREW" list --formula nfd2nfc >/dev/null 2>&1; then
        "$BREW" upgrade nfd2nfc || true
    else
        "$BREW" install wonjun-lab/tap/nfd2nfc
    fi
    CLI="$("$BREW" --prefix)/bin/nfd2nfc"
    # 예전에 직접 설치한 사본이 PATH에서 brew 설치본을 가리지 않게 치운다.
    OLD="$HOME/.local/bin/nfd2nfc"
    if [ -f "$OLD" ] && grep -q "$MARK" "$OLD" 2>/dev/null; then rm -f "$OLD" && echo "  ✓ 예전 설치본 정리: $OLD"; fi
else
    SRC="$HERE/nfd2nfc"
    if [ ! -f "$SRC" ] || ! grep -q "$MARK" "$SRC" 2>/dev/null; then
        # 저장소 밖(curl | sh)에서 실행됨 → 최신 릴리스의 스크립트를 받는다.
        TAG=$(curl -fsS -m 10 "https://api.github.com/repos/$REPO/releases/latest" \
              | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
        [ -n "$TAG" ] || { echo "오류: 최신 버전을 확인할 수 없습니다(네트워크 확인)" >&2; exit 1; }
        SRC=$(mktemp)
        trap 'rm -f "$SRC"' EXIT
        curl -fsSL -m 30 -o "$SRC" "https://raw.githubusercontent.com/$REPO/$TAG/nfd2nfc"
        grep -q "$MARK" "$SRC" || { echo "오류: 받은 파일이 nfd2nfc가 아닙니다" >&2; exit 1; }
    fi
    # Homebrew 경로에는 쓰지 않는다(brew와 충돌). 사용자 영역에 두고 PATH는 setup이 안내한다.
    BIN="$HOME/.local/bin"
    mkdir -p "$BIN"
    install -m 0755 "$SRC" "$BIN/nfd2nfc"
    CLI="$BIN/nfd2nfc"
    echo "  ✓ CLI 설치: $CLI"
fi

echo
"$CLI" setup

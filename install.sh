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

# `curl | sh` 로 실행하면 sh가 이 스크립트를 표준입력에서 읽는다. 중간의 brew 등이 표준입력을 읽으면
# 남은 스크립트를 먹어 버려 뒤(setup)가 조용히 실행되지 않는다(실측). 그래서 전체를 함수로 감싸
# 끝까지 읽은 뒤 실행하고, 외부 명령의 표준입력도 끊는다.
main() {
REPO=wonjun-lab/nfd2nfc
MARK='^# nfd2nfc — macOS 한글 파일명'
# curl | sh 로 실행되면 $0은 "sh"라 파일이 아니다 — 그때는 저장소 사본을 찾지 않는다(현재 폴더의 옛 사본 오인 방지).
HERE=""
if [ -f "$0" ]; then HERE=$(cd "$(dirname "$0")" && pwd); fi
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
    # homebrew/core에 이름이 같은 다른 도구(elgar328/nfd2nfc, Rust)가 있다. 그게 깔려 있으면 같은 명령 이름
    # (bin/nfd2nfc)을 두고 충돌하므로, 무엇을 할지 사용자가 정하도록 멈춘다.
    BREW_BIN="$("$BREW" --prefix)/bin/nfd2nfc"
    if [ -e "$BREW_BIN" ] && ! grep -q "$MARK" "$BREW_BIN" 2>/dev/null; then
        echo "오류: 이름이 같은 다른 프로그램이 이미 설치돼 있습니다: $BREW_BIN" >&2
        echo "  (homebrew/core의 nfd2nfc — 다른 개발자의 Rust 도구로 보입니다)" >&2
        echo "  • 그 도구를 안 쓴다면:   brew uninstall nfd2nfc  후 다시 실행" >&2
        echo "  • 둘 다 쓰려면:          ./install.sh --from-source  (~/.local/bin 에 설치, 전체 경로로 실행)" >&2
        exit 1
    fi
    if "$BREW" list --formula wonjun-lab/tap/nfd2nfc >/dev/null 2>&1; then
        "$BREW" upgrade wonjun-lab/tap/nfd2nfc </dev/null || true
    else
        "$BREW" install wonjun-lab/tap/nfd2nfc </dev/null
    fi
    CLI="$("$BREW" --prefix)/bin/nfd2nfc"
    # 예전에 직접 설치한 사본이 PATH에서 brew 설치본을 가리지 않게 치운다.
    OLD="$HOME/.local/bin/nfd2nfc"
    if [ -f "$OLD" ] && grep -q "$MARK" "$OLD" 2>/dev/null; then rm -f "$OLD" && echo "  ✓ 예전 설치본 정리: $OLD"; fi
else
    SRC="${HERE:+$HERE/}nfd2nfc"
    if [ -z "$HERE" ] || [ ! -f "$SRC" ] || ! grep -q "$MARK" "$SRC" 2>/dev/null; then
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
# setup은 1.2.0부터 있다. 릴리스·tap 반영 전에 옛 버전이 설치됐다면 파일 경로로 오인하지 않게 확인한다.
if grep -q "^sub setup_main" "$CLI" 2>/dev/null; then
    "$CLI" setup </dev/null
else
    echo "CLI는 설치됐지만 이 버전($("$CLI" --version))은 Finder 메뉴 자동 설치(setup)를 지원하지 않습니다."
    echo "  잠시 뒤 다시 실행하거나, Releases의 nfd2nfc-quick-action.zip 으로 메뉴를 설치하세요."
fi
}

main "$@"

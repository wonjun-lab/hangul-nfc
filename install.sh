#!/bin/sh
#
# install.sh — hangul-nfc 설치 (한 줄로 끝)
#
#   ./install.sh                  # Homebrew가 있으면 brew로, 없으면 ~/.local/bin에 설치
#   ./install.sh --from-source    # 이 저장소의 hangul-nfc를 그대로 ~/.local/bin에 설치(개발용)
#   curl -fsSL https://raw.githubusercontent.com/wonjun-lab/hangul-nfc/main/install.sh | sh
#
# 설치 뒤 `hangul-nfc setup`으로 Finder 우클릭 메뉴까지 만든다.
# 업데이트: hangul-nfc update · 상태 점검: hangul-nfc doctor · 제거: hangul-nfc uninstall
#
set -eu

# `curl | sh` 로 실행하면 sh가 이 스크립트를 표준입력에서 읽는다. 중간의 brew 등이 표준입력을 읽으면
# 남은 스크립트를 먹어 버려 뒤(setup)가 조용히 실행되지 않는다(실측). 그래서 전체를 함수로 감싸
# 끝까지 읽은 뒤 실행하고, 외부 명령의 표준입력도 끊는다.
main() {
REPO=wonjun-lab/hangul-nfc
MARK='^# hangul-nfc — macOS 한글 파일명'
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

echo "▸ hangul-nfc 설치를 시작합니다."

# 예전 이름(nfd2nfc)의 CLI·메뉴·자동 감시는 새 CLI 설치에 성공한 뒤 아래 setup이 옮기고 치운다
# (먼저 지웠다가 설치가 실패하면 예전 것도 새 것도 없는 상태가 된다).

BREW=""
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$b" ]; then BREW=$b; break; fi
done
[ -n "$BREW" ] || BREW=$(command -v brew 2>/dev/null || true)

if [ "$FROM_SOURCE" = 0 ] && [ -n "$BREW" ]; then
    # Homebrew가 있으면 brew로 관리한다 — 업데이트(brew upgrade / hangul-nfc update)와 제거가 한 경로로 된다.
    echo "  • Homebrew로 설치합니다"
    # 같은 명령 이름(bin/hangul-nfc)을 쓰는 다른 프로그램이 이미 있으면 덮어쓰지 않고 멈춘다.
    BREW_BIN="$("$BREW" --prefix)/bin/hangul-nfc"
    if [ -e "$BREW_BIN" ] && ! grep -q "$MARK" "$BREW_BIN" 2>/dev/null; then
        echo "오류: 이름이 같은 다른 프로그램이 이미 설치돼 있습니다: $BREW_BIN" >&2
        echo "  그 프로그램을 정리한 뒤 다시 실행하거나, ./install.sh --from-source 로 ~/.local/bin 에 설치하세요." >&2
        exit 1
    fi
    if "$BREW" list --formula wonjun-lab/tap/hangul-nfc >/dev/null 2>&1; then
        "$BREW" upgrade wonjun-lab/tap/hangul-nfc </dev/null || true
    else
        "$BREW" install wonjun-lab/tap/hangul-nfc </dev/null
    fi
    CLI="$("$BREW" --prefix)/bin/hangul-nfc"
    # 예전에 직접 설치한 사본이 PATH에서 brew 설치본을 가리지 않게 치운다.
    OLD="$HOME/.local/bin/hangul-nfc"
    if [ -f "$OLD" ] && grep -q "$MARK" "$OLD" 2>/dev/null; then rm -f "$OLD" && echo "  ✓ 예전 설치본 정리: $OLD"; fi
else
    SRC="${HERE:+$HERE/}hangul-nfc"
    if [ -z "$HERE" ] || [ ! -f "$SRC" ] || ! grep -q "$MARK" "$SRC" 2>/dev/null; then
        # 저장소 밖(curl | sh)에서 실행됨 → 최신 릴리스의 스크립트를 받는다.
        TAG=$(curl -fsS -m 10 "https://api.github.com/repos/$REPO/releases/latest" \
              | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
        [ -n "$TAG" ] || { echo "오류: 최신 버전을 확인할 수 없습니다(네트워크 확인)" >&2; exit 1; }
        SRC=$(mktemp)
        trap 'rm -f "$SRC"' EXIT
        curl -fsSL -m 30 -o "$SRC" "https://raw.githubusercontent.com/$REPO/$TAG/hangul-nfc"
        grep -q "$MARK" "$SRC" || { echo "오류: 받은 파일이 hangul-nfc가 아닙니다" >&2; exit 1; }
    fi
    # Homebrew 경로에는 쓰지 않는다(brew와 충돌). 사용자 영역에 두고 PATH는 setup이 안내한다.
    BIN="$HOME/.local/bin"
    mkdir -p "$BIN"
    install -m 0755 "$SRC" "$BIN/hangul-nfc"
    CLI="$BIN/hangul-nfc"
    echo "  ✓ CLI 설치: $CLI"
fi

echo
# setup은 1.2.0부터 있다. 릴리스·tap 반영 전에 옛 버전이 설치됐다면 파일 경로로 오인하지 않게 확인한다.
if grep -q "^sub setup_main" "$CLI" 2>/dev/null; then
    "$CLI" setup </dev/null
else
    echo "CLI는 설치됐지만 이 버전($("$CLI" --version))은 Finder 메뉴 자동 설치(setup)를 지원하지 않습니다."
    echo "  잠시 뒤 다시 실행하거나, Releases의 hangul-nfc-quick-action.zip 으로 메뉴를 설치하세요."
fi
}

main "$@"

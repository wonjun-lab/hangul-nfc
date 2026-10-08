#!/bin/sh
#
# install.sh — hangul-nfc 설치 (한 줄로 끝)
#
#   ./install.sh                  # ~/.local/bin에 설치(저장소 안이면 이 사본, 아니면 최신 릴리스)
#   ./install.sh --from-source    # 위와 같다(Homebrew로 설치하던 때의 개발용 옵션 — 호환용으로 남김)
#   curl -fsSL https://raw.githubusercontent.com/wonjun-lab/hangul-nfc/main/install.sh | sh
#
# 설치 뒤 `hangul-nfc setup`으로 Finder 우클릭 메뉴까지 만든다.
# 예전에 Homebrew로 설치했다면(2.0.x까지) ~/.local/bin으로 옮기고 Homebrew 설치본·tap을 정리한다.
# 업데이트: hangul-nfc update · 상태 점검: hangul-nfc doctor · 제거: hangul-nfc uninstall
#
set -eu

# `curl | sh` 로 실행하면 sh가 이 스크립트를 표준입력에서 읽는다. 중간의 brew 등이 표준입력을 읽으면
# 남은 스크립트를 먹어 버려 뒤(setup)가 조용히 실행되지 않는다(실측). 그래서 전체를 함수로 감싸
# 끝까지 읽은 뒤 실행하고, 외부 명령의 표준입력도 끊는다.
main() {
REPO=wonjun-lab/hangul-nfc
TAP=wonjun-lab/tap                              # 2.0.x까지의 Homebrew tap — 저장소는 없어졌다
MARK='^# hangul-nfc — macOS 한글 파일명'
LEGACY_MARK='^# nfd2nfc — macOS 한글 파일명'   # 1.x 때 이름(nfd2nfc) 설치본 식별
PATH_MARK_BEGIN='# >>> hangul-nfc PATH >>>'     # ~/.zprofile 블록 표식 — hangul-nfc의 path_mark_begin/end와 같아야 한다
PATH_MARK_END='# <<< hangul-nfc PATH <<<'
NEED_NEW_WINDOW=0
MIGRATED=0
# curl | sh 로 실행되면 $0은 "sh"라 파일이 아니다 — 그때는 저장소 사본을 찾지 않는다(현재 폴더의 옛 사본 오인 방지).
HERE=""
if [ -f "$0" ]; then HERE=$(cd "$(dirname "$0")" && pwd); fi
for a in "$@"; do
    case "$a" in
        --from-source) ;;
        *) echo "알 수 없는 옵션: $a" >&2; exit 2 ;;
    esac
done

echo "▸ hangul-nfc 설치를 시작합니다."

# 예전 이름(nfd2nfc)의 CLI·메뉴·자동 감시와 Homebrew 설치본은 새 CLI 설치에 성공한 뒤 옮기고 치운다
# (먼저 지웠다가 설치가 실패하면 예전 것도 새 것도 없는 상태가 된다).

# ── 1) CLI: 항상 사용자 영역(~/.local/bin)에 둔다 ──
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
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
install -m 0755 "$SRC" "$BIN/hangul-nfc"
CLI="$BIN/hangul-nfc"
echo "  ✓ CLI 설치: $CLI"
# macOS 기본 PATH엔 ~/.local/bin이 없어 'hangul-nfc'를 못 찾는다. ~/.zprofile에 표식으로 감싼 블록을
# 한 번만 더한다(다시 실행해도 중복 없음). 제거(hangul-nfc uninstall)가 이 블록만 지운다.
case ":$PATH:" in
    *":$BIN:"*) ;;
    *)
        PROFILE="$HOME/.zprofile"
        if ! grep -qF "$PATH_MARK_BEGIN" "$PROFILE" 2>/dev/null; then
            # shellcheck disable=SC2016  # $HOME·$PATH는 로그인할 때 펼쳐지도록 그대로 적는다
            printf '\n%s\nexport PATH="$HOME/.local/bin:$PATH"\n%s\n' "$PATH_MARK_BEGIN" "$PATH_MARK_END" >> "$PROFILE"
            echo "  ✓ PATH 설정 추가: ~/.zprofile"
        fi
        NEED_NEW_WINDOW=1
        ;;
esac

# ── 2) Homebrew 설치본(2.0.x까지) → ~/.local/bin으로 이전 ──
# Homebrew 배포는 2.1.0에서 끝났고 tap 저장소도 없어졌다(tap이 남은 Mac에서는 brew update·upgrade가 실패한다).
# 순서: brew uninstall → (3) setup. setup을 새 CLI로 돌리므로 Finder 메뉴는 ~/.local/bin을 먼저 부르고,
# 자동 감시(launchd plist)도 새 CLI를 부르도록 다시 쓴다. 지운 Homebrew 경로가 메뉴·감시에 남지 않는다.
# HANGUL_NFC_BREW로 brew 경로를 바꿀 수 있다(빈 값 = brew 없음) — 테스트가 실제 Homebrew를 건드리지 않게.
if [ "${HANGUL_NFC_BREW+x}" = x ]; then
    BREW=$HANGUL_NFC_BREW
else
    BREW=""
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$b" ]; then BREW=$b; break; fi
    done
    [ -n "$BREW" ] || BREW=$(command -v brew 2>/dev/null || true)
fi
[ -z "$BREW" ] || [ -x "$BREW" ] || BREW=""
BREW_KEGS=""
BREW_FAIL=0
if [ -n "$BREW" ]; then
    PREFIX=$("$BREW" --prefix </dev/null 2>/dev/null || true)
    # Cellar 이름만으론 모른다(nfd2nfc는 homebrew/core의 다른 도구와 이름이 겹쳤다) — 내용이 우리 스크립트인지 본다.
    if [ -n "$PREFIX" ] && [ -d "$PREFIX/Cellar/hangul-nfc" ] && grep -rqs "$MARK" "$PREFIX/Cellar/hangul-nfc"; then
        BREW_KEGS="hangul-nfc"
    fi
    if [ -n "$PREFIX" ] && [ -d "$PREFIX/Cellar/nfd2nfc" ] && grep -rqs "$LEGACY_MARK" "$PREFIX/Cellar/nfd2nfc"; then
        BREW_KEGS="${BREW_KEGS:+$BREW_KEGS }nfd2nfc"
    fi
fi
# 새 CLI가 이전을 맡을 수 있을 때만 지운다 — 릴리스 반영 전의 옛 버전이면 setup이 자동 감시를 옮기지 못해
# 지운 Homebrew 경로를 부르는 채로 남는다.
if [ -n "$BREW_KEGS" ] && ! grep -q "^sub watch_plist_program" "$CLI" 2>/dev/null; then
    echo "  ! Homebrew 설치본($BREW_KEGS)이 있지만 받은 버전이 이전을 지원하지 않습니다 — 잠시 뒤 다시 실행하세요"
    BREW_KEGS=""
    BREW_FAIL=1
fi
if [ -n "$BREW_KEGS" ]; then
    MIGRATED=1
    echo "  • Homebrew 배포는 2.1.0에서 끝났습니다 — Homebrew 설치본을 ~/.local/bin으로 옮깁니다"
    for k in $BREW_KEGS; do
        if "$BREW" uninstall --formula "$k" </dev/null >/dev/null; then
            echo "  ✓ Homebrew 설치본 제거: $k (brew uninstall)"
        else
            echo "  ! Homebrew 설치본을 지우지 못했습니다 — 직접 실행하세요: brew uninstall $k"
            BREW_FAIL=1
        fi
    done
fi
# tap이 남아 있으면 정리한다. 다른 formula(codex-swap 등)가 그 tap에서 설치돼 있으면 untap 하지 않고 안내만 한다.
if [ -n "$BREW" ] && [ "$BREW_FAIL" = 0 ]; then
    REPO_DIR=$("$BREW" --repository </dev/null 2>/dev/null || true)
    if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR/Library/Taps/wonjun-lab/homebrew-tap" ]; then
        OTHERS=$("$BREW" list --formula --full-name </dev/null 2>/dev/null | sed -n "s|^$TAP/||p" | tr '\n' ' ' | sed 's/ *$//')
        if [ -z "$OTHERS" ]; then
            if "$BREW" untap "$TAP" </dev/null >/dev/null; then echo "  ✓ Homebrew 탭 정리: brew untap $TAP"; fi
        else
            NOTE=""
            case " $OTHERS " in *" codex-swap "*) NOTE=" (codex-swap은 자체 curl 설치 스크립트로 다시 설치하세요)" ;; esac
            echo "  · Homebrew 탭 $TAP 은 곧 없어집니다 — 남은 것도 옮기세요: brew uninstall $OTHERS && brew untap $TAP$NOTE"
        fi
    fi
fi

# ── 3) Finder 메뉴·자동 감시를 새 CLI로 ──
echo
# setup은 1.2.0부터 있다. 릴리스 반영 전에 옛 버전이 설치됐다면 파일 경로로 오인하지 않게 확인한다.
if grep -q "^sub setup_main" "$CLI" 2>/dev/null; then
    "$CLI" setup </dev/null
else
    echo "CLI는 설치됐지만 이 버전($("$CLI" --version))은 Finder 메뉴 자동 설치(setup)를 지원하지 않습니다."
    echo "  잠시 뒤 다시 실행하거나, Releases의 hangul-nfc-quick-action.zip 으로 메뉴를 설치하세요."
fi
if [ "$MIGRATED" = 1 ]; then
    echo
    echo "✓ Homebrew에서 옮기기 완료 — 앞으로 업데이트는 'hangul-nfc update' 입니다."
fi
# 마지막 줄로 다시 알린다 — 이 창은 PATH가 바뀌기 전이라 'hangul-nfc'를 아직 못 찾는다.
if [ "$NEED_NEW_WINDOW" = 1 ]; then
    echo
    echo "! 'hangul-nfc' 명령은 새 터미널 창부터 쓸 수 있습니다(~/.zprofile에 PATH 추가됨)."
    echo "  지금 이 창에서는 전체 경로로 실행하세요: $CLI"
elif [ "$MIGRATED" = 1 ]; then
    # 이 창의 셸이 지운 Homebrew 경로를 기억하고 있을 수 있다.
    echo "  이 창에서 'hangul-nfc'를 못 찾으면 'hash -r' 하거나 새 터미널 창을 여세요."
fi
}

main "$@"

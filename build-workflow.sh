#!/bin/sh
#
# build-workflow.sh — `nfd2nfc` 스크립트로부터 Finder Quick Action(.workflow)을 생성한다.
#
# 배포 zip용 Quick Action은 설치된 CLI가 있으면 그것을 호출하고, 없으면 내장한 `nfd2nfc` 사본으로 실행한다.
# 즉 스크립트가 유일한 원본(single source of truth)이며, 이 빌더가 항상 동기화한다.
#
# 사용법:
#   ./build-workflow.sh                 # 저장소 루트에 .workflow 빌드 후 zip 재생성
#   . ./build-workflow.sh; build_workflow_bundle <대상.workflow 경로>   # 함수만 사용
#
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT_SRC="$HERE/nfd2nfc"
WORKFLOW_NAME="NFC로 이름 정리"

# build_workflow_bundle <bundle_path>
# 주어진 경로에 완전한 .workflow 번들을 만든다. 생성기는 CLI(`nfd2nfc quick-action build`) 안에 있어
# `nfd2nfc setup`(설치된 CLI를 호출하는 메뉴)과 배포 zip(독립 실행본)이 같은 코드를 쓴다.
build_workflow_bundle() {
    /usr/bin/perl "$SCRIPT_SRC" quick-action build "$1"
}

# 직접 실행될 때만 저장소에 .workflow 빌드 후 zip 재생성한다.
# source되면(install.sh가 함수 재사용 / 대화형 셸에서 함수만 사용) 이 블록을 건너뛴다.
# sourced 판별: bash·sh는 BASH_SOURCE≠$0, zsh는 ZSH_EVAL_CONTEXT가 ':file'로 끝남.
# (이전엔 $0 basename만 봐서 zsh `. ./build-workflow.sh` 시 오발 → 의도치 않은 빌드+삭제가 일어났다.)
bw_sourced=1
# shellcheck disable=SC3028,SC2128
if [ -n "${BASH_SOURCE:-}" ]; then
    [ "${BASH_SOURCE}" = "$0" ] && bw_sourced=0
elif [ -n "${ZSH_EVAL_CONTEXT:-}" ]; then
    case "$ZSH_EVAL_CONTEXT" in *:file) bw_sourced=1 ;; *) bw_sourced=0 ;; esac
else
    [ "${0##*/}" = "build-workflow.sh" ] && bw_sourced=0
fi
if [ "$bw_sourced" = 0 ]; then
    BUNDLE="$HERE/$WORKFLOW_NAME.workflow"
    build_workflow_bundle "$BUNDLE"
    # plist 유효성 검사
    /usr/bin/plutil -lint "$BUNDLE/Contents/document.wflow" >/dev/null
    /usr/bin/plutil -lint "$BUNDLE/Contents/Info.plist" >/dev/null
    # zip 재생성
    ( cd "$HERE" && rm -f "$WORKFLOW_NAME.workflow.zip" \
        && /usr/bin/zip -r -q "$WORKFLOW_NAME.workflow.zip" "$WORKFLOW_NAME.workflow" )
    rm -rf "$BUNDLE"
    echo "빌드 완료: $WORKFLOW_NAME.workflow.zip"
fi

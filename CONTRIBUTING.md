# 기여 가이드

## 개발

`hangul-nfc`(perl)가 단일 원본입니다. Finder 메뉴 생성(`hangul-nfc quick-action build`·`setup`)·설치 관리(`doctor`·`update`·`uninstall`)도 이 파일 안에 있고, 셸 스크립트는 얇은 진입점입니다.

- 코어 수정: `hangul-nfc`
- 배포 zip 생성: `./build-workflow.sh` (→ `NFC로 이름 정리.workflow.zip`, 내부적으로 `hangul-nfc quick-action build`)
- 설치/제거: `./install.sh --from-source`(이 저장소 사본을 `~/.local/bin`에 설치해 시험), `./uninstall.sh`

## 테스트

```sh
./test.sh        # 통합 테스트 (macOS 전용 — APFS 정규화 비구분 동작에 의존)
shellcheck install.sh uninstall.sh build-workflow.sh test.sh
perl -c hangul-nfc
```

CI(`.github/workflows/ci.yml`)가 macOS에서 위를 자동 실행합니다.

## 릴리스 절차

1. `hangul-nfc`의 `$VERSION`과 `CHANGELOG.md`를 새 버전으로 갱신, 커밋.
2. 태그 푸시: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. `release.yml`이 Quick Action zip을 빌드해 GitHub Release에 첨부.
   한 줄 설치(`install.sh`)와 `hangul-nfc update`는 최신 릴리스를 받으므로 따로 갱신할 곳은 없습니다
   (Homebrew 배포는 2.1.0에서 끝났습니다).

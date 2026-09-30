# Changelog

이 프로젝트의 주요 변경 사항을 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/),
버전은 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

## [Unreleased]

## [2.0.0] - 2026-10-01

### Changed — 이름 변경: nfd2nfc → hangul-nfc (BREAKING)
- homebrew/core에 이름이 같은 다른 도구(elgar328/nfd2nfc, Rust)가 있어, `brew install nfd2nfc`가 엉뚱한 도구를 설치하고 두 도구가 같은 명령 이름(`bin/nfd2nfc`)을 두고 충돌했다. 도구·명령·저장소(`wonjun-lab/hangul-nfc`, 예전 주소는 자동 연결)·Homebrew formula·자동 감시 LaunchAgent 이름(`com.wonjun-lab.hangul-nfc.watch`)·설정/로그 경로·환경변수(`HANGUL_NFC_*`)·릴리스 자산(`hangul-nfc-quick-action.zip`)을 모두 `hangul-nfc`로 바꿨다. 쓰는 법(옵션·하위 명령)은 같다.

### Added — 예전 이름에서 이전
- **Homebrew**: tap의 `formula_renames.json`으로 `brew upgrade`가 설치된 nfd2nfc를 hangul-nfc로 옮긴다.
- **`hangul-nfc setup`**이 예전 흔적을 옮기고 치운다 — 예전 자동 감시 폴더(사라진·보호 위치 폴더는 제외)를 새 목록으로 옮겨 다시 켜고, 사라진 `nfd2nfc` 명령을 부르던 예전 에이전트·설정·로그와 직접 설치한 예전 CLI를 지운다(Homebrew 설치본은 `brew upgrade`에 맡김).
- **`hangul-nfc doctor`**가 예전 이름의 흔적을 찾아 조치를 안내하고, **`uninstall`**은 예전 흔적까지 지운다.
- `install.sh`는 예전 이름으로 직접 설치한 사본을 치운 뒤 설치하고 `setup`으로 이전을 마친다.

### Fixed
- **`curl … | sh` 한 줄 설치에서 Finder 메뉴 설치(`setup`)가 조용히 빠지던 문제** — sh가 스크립트를 표준입력에서 읽는데 `brew install`이 남은 스크립트를 표준입력에서 먹어 버렸다(실측: brew 설치는 됐지만 메뉴 없음). 스크립트 전체를 `main()` 함수로 감싸 끝까지 읽은 뒤 실행하고, brew·setup의 표준입력을 끊었다. `install.sh`는 main 브랜치에서 바로 배포되므로 머지 즉시 반영.

## [1.2.0] - 2026-10-01

설치·사용·업데이트·제거 전 과정을 사용자 관점에서 다시 설계했다.

### Added
- **`nfd2nfc setup`** — Finder 우클릭 메뉴를 어떤 설치 경로(Homebrew·install.sh·수동)에서든 한 명령으로 설치. brew 사용자도 zip을 따로 받을 필요가 없다.
- **`nfd2nfc doctor`** — CLI 위치·설치 방식·PATH·메뉴 방식·자동 감시(폴더별 상태, 최근 실행)·새 버전을 점검하고 문제마다 해결 명령을 안내(문제 있으면 종료 코드 1).
- **`nfd2nfc update`** — Homebrew 설치본은 `brew upgrade`로 위임하고, 직접 설치본은 릴리스의 스크립트를 받아 **문법·버전을 검증한 뒤에만** 교체(끊긴 다운로드·오류 페이지로 망가지지 않음). git 사본은 `git pull` 안내.
- **`nfd2nfc uninstall`** — 메뉴·자동 감시(LaunchAgent)·설정·로그와 CLI(직접 설치본 삭제, Homebrew 설치본은 `brew uninstall`)까지 한 번에. 표준 위치 밖의 사본(저장소 등)과 남의 파일은 건드리지 않는다. `--keep-cli` 지원.
- `install.sh` 한 줄 설치: `curl -fsSL …/install.sh | sh` (저장소 없이도 최신 릴리스를 받아 설치).

### Changed
- **Finder 메뉴가 설치된 CLI를 호출** — 예전엔 스크립트 사본을 메뉴에 박아 두어 `brew upgrade` 후에도 메뉴는 옛 버전으로 돌았다. 이제 CLI만 업데이트하면 메뉴도 최신이다(CLI가 없을 때만 내장 사본 사용). 생성기는 CLI 안(`nfd2nfc quick-action build`)으로 옮겨 `setup`과 배포 zip이 같은 코드를 쓴다.
- **`install.sh`는 Homebrew 우선** — brew가 있으면 brew로 설치(업데이트·제거가 한 경로), 없으면 `~/.local/bin`. **Homebrew 경로(`/opt/homebrew/bin` 등)엔 더 이상 파일을 쓰지 않는다**(이후 `brew install`의 링크 충돌 원인). 1.1.x가 그곳에 둔 사본은 자동 정리. `--from-source`로 저장소 사본 설치(개발용).
- `uninstall.sh`는 `nfd2nfc uninstall`의 얇은 진입점 — Apple Silicon에서 `/opt/homebrew/bin`의 CLI가 남던 문제와 자동 감시 에이전트가 남던 문제 해소.
- 도움말(`-h`)과 영문 README가 모든 하위 명령을 안내.
- Homebrew formula: `caveats`가 `setup`/`doctor`/`uninstall`을 안내, `test`가 실제 NFD→NFC 변환을 디스크 바이트로 검증.

### Fixed
- **자동 감시가 다운로드·데스크탑·문서 등에서 조용히 실패하던 문제** — macOS 개인정보 보호(TCC)가 백그라운드 프로그램의 접근을 막아(`Operation not permitted`, launchd 에이전트로 실측) README의 대표 예시(`watch add ~/Downloads`)가 등록 직후 1회만 동작하고 이후 아무 일도 하지 않았다. 서명 안 된 도구는 권한 창도 띄울 수 없음을 확인(osacompile·JXA 앱 번들, launchd·open, 목적 문자열, 위치 조합 모두 권한 창 없이 무기한 대기 — macOS 26.6). 그래서:
  - 보호 위치(다운로드·데스크탑·문서·iCloud Drive·클라우드 저장소·외장/네트워크 볼륨)와 그 상위 폴더(홈 등)는 `watch add`에서 거부하고 대안(Finder 메뉴·CLI)을 안내.
  - 예전 버전에서 등록된 보호 폴더, 실행 중 권한이 막힌 폴더는 감시에서 자동 해제하고 알림(조용한 실패 제거).
- `watch list`가 launchctl 내부 출력을 흘리고, 첫 `watch add`가 `Unload failed` 오류를 출력하던 문제 — `bootstrap`/`bootout`/`print`로 바꾸고 출력을 숨김.

## [1.1.1] - 2026-10-01

### Fixed (SMB·NAS 실측 후속 — Synology DSM 7.4)
- **SMB(`smbfs`) 볼륨을 NFD 강제 형식으로 인식** — 실측 결과 macOS SMB 클라이언트는 이름을 조합형으로 보내 서버엔 NFC로 저장되고, 읽을 때는 항상 NFD로 보여 준다. 1.1.0은 안전망으로 "변경 불가"를 판정했지만 실행마다 헛 rename 1회를 했고 문구도 부정확했다. 이제 rename을 시도하지 않고, `watch add`도 SMB 폴더 등록을 거부한다.
- 볼륨 형식 판정을 **대상 경로의 가장 긴 마운트 지점 접두어**로 변경 — 다른 마운트를 stat하지 않아 끊긴 SMB·NFS 마운트가 있어도 멈추지 않는다. 마운트 지점 비교는 NFC로 맞춰 한글 볼륨 이름(mount 출력은 NFD)에서도 정확하다.
- 경고 문구를 형식별 실측 동작에 맞게 정정(HFS+: 디스크가 NFD / exFAT·FAT: 디스크는 조합형 / SMB: 서버는 조합형, 서버에 NFD로 저장된 이름은 서버에서 정리 / 미상: 중립 문구).

### Added
- README: NAS에 NFD 바이트로 저장된 이름(rsync·scp 등으로 옮긴 파일)은 Mac에서 SMB로 **열 수도 바꿀 수도 없음**을 명시하고, NAS에서 직접 정리하는 `python3` 스크립트 제공(Synology DSM엔 perl이 없음; 호환 한자 보존 규칙 동일). DSM 7.4에서 정리 후 Mac에서 정상으로 열리는 것까지 확인.

## [1.1.0] - 2026-10-01

### Fixed (볼륨 형식·문자 보존·자동 감시 진단 후속)
- **HFS+·exFAT·FAT 볼륨에서 거짓 "변경" 보고** — macOS에서 이 형식들의 파일명은 항상 NFD다(HFS+는 디스크에 NFD로 저장, exFAT·FAT은 디스크엔 조합형 UTF-16이지만 읽을 때 NFD로 제공 — 디스크 이미지 바이트로 실측). rename이 성공해도 NFD로 보이는데 매 실행 "N개 변경"으로 세고 종료 코드 0을 냈다(FAT에선 `._` 파일 rename 실패도 발생). 볼륨 형식(mount 테이블)으로 미리 감지해 rename을 시도하지 않고 `N개 변경 불가(볼륨이 NFD 강제)`로 보고·종료 코드 1. 형식 목록에 없는 볼륨은 볼륨당 첫 rename 직후 readdir로 실제 이름을 확인하는 안전망으로 같은 판정. mount 테이블 조회는 해당 형식 마운트만 stat해 끊긴 네트워크 마운트에서 멈추지 않는다.
- **자동 감시 무한 재실행** — 위 헛 rename도 디렉토리 변경 이벤트(kqueue `NOTE_WRITE`)를 일으켜, 그런 볼륨의 폴더를 등록하면 launchd가 10초마다 재실행하며 "N개 정리" 알림을 반복했다. rename 미시도로 해소하고, `watch add`가 NFD 강제 볼륨 폴더 등록을 거부(형식 목록 밖 볼륨은 등록 전 1회 정리 결과로 판정). 빈 폴더로 등록된 뒤 NFD가 유입돼 실행 중에 드러난 경우엔 그 폴더를 감시 목록에서 **자동 해제**하고 한 번 알린다(판정이 프로세스마다 잊혀 매 실행 헛 rename 1회가 반복되던 잔여 루프 차단).
- README 수동 폴백(Automator) 스크립트도 같은 방식으로 — 결합만 수행(호환 한자 보존) + NFD 강제 볼륨 판정·`변경 불가` 집계.
- `disk_real_path`가 바이트가 정확히 같은 항목을 먼저 고르도록 — 정규화-구분 볼륨에서 정규화만 같은 다른 항목을 잘못 고르지 않게.
- **호환 한자·기호가 다른 글자로 바뀌던 문제** — NFC는 호환 한자(`樂` U+F914 → U+6A02)나 `Ω`(U+2126 → U+03A9) 같은 singleton을 바꿔 "보이는 글자는 그대로"라는 약속을 어겼다. 분해 없이 결합만 하도록(`compose(reorder())`) 바꿔 쪼개진 자모 등만 합친다.
- **Homebrew 설치 시 `brew upgrade` 후 자동 감시가 조용히 멈추던 문제** — LaunchAgent plist에 심링크를 푼 `Cellar/<버전>/` 경로가 박혔다. 심링크를 유지한 절대경로를 사용.
- **하위 폴더에 새로 생긴 파일을 자동 감시가 놓치던 문제** — launchd `WatchPaths`는 등록 폴더 자신의 변경만 감지한다. `StartInterval`(1시간) 전체 점검을 추가하고 README에 반응 범위를 명시.

### Added (자동 감시)
- `nfd2nfc watch add/remove/list/on/off` — launchd `WatchPaths`로 등록 폴더를 감시해 NFD 파일 유입 시 자동으로 NFC 정리. 등록 시 즉시 1회 정리, 하위 폴더 포함, 변경 있을 때만 알림. 의존성 0(perl + launchd), 옵트인. 무한루프는 idempotent + `ThrottleInterval` 10초로 차단. 설정 `~/Library/Application Support/nfd2nfc/`, 로그 `~/Library/Logs/nfd2nfc-watch.log`.

### Changed (형식/FS 검토 후속)
- `--force`가 실제로 **다른 항목을 덮어쓸 때 경고**를 출력(`덮어씀(기존 항목 영구 삭제)`) — loud opt-in. 충돌은 정규화-구분 FS에서만 발생하므로 macOS 기본 볼륨에선 무영향.
- README에 **"바꾸는 범위" 섹션** 추가 — 파일 내용·형식 무관, **압축 파일 내부 엔트리명은 스코프 밖**(zip/tar/hwpx/docx), `.app` 번들 서명 주의, `--force` 데이터 손실은 정규화-구분 볼륨 한정임을 명시.
- 통합 테스트: 압축 파일 내부 엔트리명·내용 불변(스코프 한계 회귀 가드).

### Fixed (안정성/스트레스 테스트 후속)
- **셸 glob/탭완성이 인자를 NFC로 정규화하면 변환이 누락되던 문제** — macOS 기본 셸 zsh는 `nfd2nfc *.hwp`에서 파일명을 NFC로 넘겨, 디스크가 NFD인데도 "이미 정규화됨"으로 스킵했다. 최상위 인자를 부모 readdir로 **디스크 실제 저장명**으로 바꿔(`disk_real_path`) 셸 정규화와 무관하게 동작.
- 같은 디스크 항목을 NFD/NFC **다른 철자로 중복 지정**하면 `%seen` 키가 raw 바이트라 dedup이 실패해 카운트 부풀림·이중 rename이 일어나던 문제(디스크 실제명 기준으로 해소).
- NFC로 저장된 파일에 NFD 인자를 주면 실제 변화 없이 "1개 변경"으로 세던 거짓 카운트.
- 아주 깊은 트리에서 Perl `Deep recursion` 경고가 stderr로 새던 문제(`no warnings 'recursion'`).
- `opendir` 실패(권한 없는 하위)·빈/슬래시뿐인 인자도 부분 실패로 집계해 종료 코드 1에 반영.
- `--force`와 `--skip`을 함께 지정하면 우선순위를 경고로 안내(`--skip` 죽은 변수 해소).
- `--help`에 `-`로 시작하는 파일명은 `--` 뒤에 두라는 팁 추가.

### Added
- `-q`/`--quiet` — 요약 출력을 생략하는 조용한 모드(경고·에러는 stderr 유지). cron·스크립트용.
- `-f`/`--force` — 이름 충돌 시 덮어쓰기(기본은 안전하게 건너뜀). `--skip`은 기본값의 명시적 별칭.
- Quick Action에 `--notify` 추가 — 우클릭 정리 후 완료 토스트(변경/0변경 모두 피드백) + Finder reveal 병행.
- Homebrew formula `caveats` — CLI만 설치되며 Finder 우클릭 메뉴는 Releases에서 별도 설치임을 안내.
- 단문자 옵션 묶음 지원(`-nv` == `-n -v`) — `Getopt::Long`의 `bundling`.
- 존재하지 않는 입력 경로에 대한 경고(오타 등 조용한 무시 방지).
- `NFD2NFC_NO_GUI=1` 환경변수 — `--notify`/`--reveal`의 osascript 호출을 건너뜀(테스트·CI용).
- 통합 테스트: 종료 코드, inode 자기오인 방지(1.0.0 회귀 가드), 옵션 묶음, 중복 입력 dedup, `--quiet`, `--force` 케이스.

### Changed
- 변환 실패·충돌 스킵·존재하지 않는 입력이 있으면 **종료 코드 1**로 종료(이전엔 항상 0이라 자동화가 실패를 감지 못함). Quick Action은 영향 없음.
- `install.sh`: CLI 설치 위치를 **이미 PATH에 있는 쓰기 가능 표준 위치**(Apple Silicon `/opt/homebrew/bin`, Intel `/usr/local/bin`) 우선 선택 — Apple Silicon에서 설치 직후 바로 실행되도록. PATH 미포함 시 안내 강화.
- `install.sh`: Finder 새로고침을 `killall`(강제 종료) 대신 graceful quit으로 — 진행 중인 Finder 작업 보호.
- `release.yml`: 릴리스 생성 폴백을 '이미 존재' 케이스로 한정(`create`의 진짜 실패가 `upload`로 가려지지 않게).

### Fixed
- `test.sh` 픽스처가 `use utf8` 없이 한글 리터럴을 latin-1로 오인해 **라틴 분해문자 NFD**를 만들던 문제 — 진짜 한글 자모(U+11xx) NFD로 수정. 도구의 핵심 목적인 한글 자모 결합을 실제로 검증하게 됨.
- 같은 경로를 중복 지정하면 변경 카운트가 부풀려지고 같은 파일을 두 번 rename 시도하던 문제(경로 중복 제거).
- `test.sh`가 `--reveal` 포함 Quick Action 명령을 실행해 **실제 Finder를 띄우던 부작용** 제거(헤드리스 CI AppleEvent 타임아웃 위험 포함). `NFD2NFC_NO_GUI`로 차단.
- `test.sh` `--no-recurse` 단언이 약해(트리 전체 `count>=1`) 옵션이 깨져도 통과하던 false pass — 폴더 자신 NFC/내부 미처리를 분리 단언.
- `test.sh`가 리포 루트의 빌드 산출물(`.workflow.zip`)을 매 실행 덮어쓰던 문제 — 함수 모드로 임시 디렉토리에 빌드.
- `build-workflow.sh`: heredoc 종료 sentinel이 스크립트 본문에 출현하면 임베드가 조용히 깨지던 취약점 — 사전 검사(`grep -qxF`)로 차단.
- `build-workflow.sh`: zsh에서 `. ./build-workflow.sh`로 source 시 직접실행 가드가 오발해 의도치 않게 zip 빌드+번들 삭제하던 문제 — `BASH_SOURCE`/`ZSH_EVAL_CONTEXT` 기반 판별.
- Quick Action 명령에 빈 선택 가드(`[ "$#" -gt 0 ] || exit 0`)와 종료코드 0 래핑 — Automator가 빈 입력/부분 실패를 오류로 표시하지 않게.
- `install.sh` BIN_DIR 선택의 도달 불가능한 `elif` 죽은 코드 정리.
- README 영문 사용법 한 줄에 누락됐던 `--reveal`/`-h` 추가.

[2.0.0]: https://github.com/wonjun-lab/hangul-nfc/releases/tag/v2.0.0
[1.2.0]: https://github.com/wonjun-lab/hangul-nfc/releases/tag/v1.2.0
[1.1.1]: https://github.com/wonjun-lab/hangul-nfc/releases/tag/v1.1.1
[1.1.0]: https://github.com/wonjun-lab/hangul-nfc/releases/tag/v1.1.0

## [1.0.1] - 2026-06-01

### Changed
- Finder 통합을 **서비스 → 빠른 동작(Quick Action)**으로 승격 — 우클릭 시
  "빠른 동작" 하위 메뉴에 표시되도록 `serviceApplicationBundleID`를 비우고
  `NSRequiredContext`(Finder 제한)를 제거.
- `install.sh` 가 설치 후 Finder를 재시작해, 새 빠른 동작이 우클릭 메뉴에 즉시 표시됨.

### Fixed
- `-v`(verbose)가 `-V`(version)로 오인되던 회귀 — `Getopt::Long`의 기본
  대소문자 무시 때문. `no_ignore_case`로 구분.

[1.0.1]: https://github.com/wonjun-lab/hangul-nfc/releases/tag/v1.0.1

## [1.0.0] - 2026-06-01

### Added
- 한 줄 설치 `install.sh` (Finder 우클릭 메뉴 + CLI 동시 설치) 및 `uninstall.sh`.
- Quick Action 빌더 `build-workflow.sh` — `nfd2nfc` 본문을 임베드하는 단일 원본 구조.
- `--version` / `-V` 플래그.
- 통합 테스트 `test.sh` 및 GitHub Actions CI/릴리스 워크플로.
- Homebrew formula.

### Fixed
- **핵심 버그**: macOS 정규화 비구분 파일시스템에서 충돌 검사(`-e`)가 NFD 파일을
  자기 자신과 충돌로 오인해 모든 변환을 건너뛰던 문제. inode 비교로 교체.

[1.0.0]: https://github.com/wonjun-lab/hangul-nfc/releases/tag/v1.0.0

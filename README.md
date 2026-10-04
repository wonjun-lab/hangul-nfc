<div align="center">

<img src="https://api.iconify.design/ph/translate-bold.svg?color=%236E7DF2&width=80" width="80" alt="" />

# hangul-nfc

### macOS 한글 파일명 자소분리, 우클릭 한 번으로 해결

`안녕.txt` 가 `ㅇㅏㄴㄴㅕㅇ.txt` 로 깨지는 문제 — 추가 설치 없이 macOS 기본 도구만으로 정리합니다.

<br>

[![CI](https://img.shields.io/github/actions/workflow/status/wonjun-lab/hangul-nfc/ci.yml?branch=main&style=flat-square&logo=github&label=CI)](https://github.com/wonjun-lab/hangul-nfc/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/wonjun-lab/hangul-nfc?style=flat-square&logo=github&label=release)](https://github.com/wonjun-lab/hangul-nfc/releases/latest)
[![macOS](https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white)](#)
[![Homebrew](https://img.shields.io/badge/Homebrew-tap-FBB040?style=flat-square&logo=homebrew&logoColor=white)](https://github.com/wonjun-lab/homebrew-tap)
[![zero deps](https://img.shields.io/badge/zero_deps-Perl-39457E?style=flat-square&logo=perl&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-6E7DF2?style=flat-square)](LICENSE)

</div>

---

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/features-dark.svg" />
  <img alt="의존성 0 · Finder 우클릭 · CLI 명령 · 폴더 일괄 · 안전" src="assets/features-light.svg" width="840" />
</picture>

</div>

---

## <img src="https://api.iconify.design/ph/warning-bold.svg?color=%236E7DF2&width=24" width="24" /> 무슨 문제냐면

Mac에서는 Finder 등 많은 앱이 한글 파일명을 자모 단위로 **쪼갠 형태**(NFD, 분해형)로 만들고, 디스크(APFS)는 받은 형태 그대로 보관합니다. 반면 윈도우·리눅스·대부분의 웹은 글자를 **합쳐서**(NFC, 조합형) 다룹니다. 화면에선 똑같이 `안녕.txt` 로 보이지만 내부 바이트가 다릅니다.

문제는 **업로드할 때** 드러납니다. 브라우저(특히 Chrome)는 파일명을 **디스크에 저장된 형태 그대로** 서버에 보냅니다 — 따로 정규화하지 않습니다. 그래서 NFD로 저장된 맥 파일은 자모가 흩어진 채 서버에 도착합니다.

```text
맥에서 만든 파일  →  디스크엔 NFD  →  브라우저가 NFD 그대로 전송  →  서버에서 ㅈㅏㅁㅗ 분리
```

<div align="center">

| 내 Mac에서는 | 윈도우 · 웹 업로드에서는 |
| :---: | :---: |
| `보고서.hwp` ✅ | `ㅂㅗㄱㅗㅅㅓ.hwp` ❌ |
| `안녕 사진들/` ✅ | `ㅇㅏㄴㄴㅕㅇ ㅅㅏㅈㅣㄴㄷㅡㄹ/` ❌ |

</div>

> **윈도우에서 올릴 땐 멀쩡한 이유** — 윈도우가 만든 파일명은 처음부터 NFC라서입니다. 그래서 **Dropbox·iCloud 같은 동기화 폴더**엔 맥에서 만든 NFD 파일이 계속 섞여 쌓입니다. 한 번 정리해도 새로 유입될 수 있으니, 가끔 한 번씩 폴더째 정리해 주는 게 좋습니다.

**hangul-nfc** 는 파일·폴더 이름을 NFC로 바꿔 이 문제를 없앱니다. 보이는 글자는 그대로 두고 내부 인코딩만 정규화하므로 안전합니다.

---

## <img src="https://api.iconify.design/ph/download-simple-bold.svg?color=%236E7DF2&width=24" width="24" /> 설치

### <img src="https://api.iconify.design/ph/terminal-window-bold.svg?color=%236E7DF2&width=20" width="20" /> 한 줄 설치 — 권장

```sh
curl -fsSL https://raw.githubusercontent.com/wonjun-lab/hangul-nfc/main/install.sh | sh
```

Homebrew가 있으면 brew로, 없으면 `~/.local/bin` 에 설치하고 Finder 우클릭 메뉴까지 한 번에 설치합니다. brew 없이 설치했다면 `hangul-nfc` 명령은 **새 터미널 창부터** 쓸 수 있습니다(PATH를 `~/.zprofile` 에 자동으로 추가). 예전 이름(`nfd2nfc`)으로 설치했다면 이것만 다시 실행하면 옮겨집니다([자세히](#nfd2nfc에서-옮겨-오기)).

### <img src="https://api.iconify.design/simple-icons/homebrew.svg?color=%236E7DF2&width=20" width="20" /> Homebrew로 직접

```sh
brew install wonjun-lab/tap/hangul-nfc
hangul-nfc setup        # Finder 우클릭 메뉴 설치 (처음 한 번)
```

### <img src="https://api.iconify.design/ph/cursor-click-bold.svg?color=%236E7DF2&width=20" width="20" /> 터미널 없이 — Finder 메뉴만

1. [**Releases**](https://github.com/wonjun-lab/hangul-nfc/releases/latest) 에서 `hangul-nfc-quick-action.zip` 을 내려받아 압축을 풉니다.
2. 나온 `NFC로 이름 정리.workflow` 를 더블클릭 → *“빠른 동작을 설치하시겠습니까?”* 에서 **설치**.
3. 끝! 이제 파일·폴더를 우클릭 → **빠른 동작 → NFC로 이름 정리**.

> 브라우저로 받은 파일이어도 보안 경고 없이 설치 창이 바로 뜹니다(macOS 26에서 확인). 이 방식은 자동 업데이트가 없으니, 새 버전은 zip을 다시 받아 설치하세요. 지울 때는 Finder에서 **이동 → 폴더로 이동**(⇧⌘G)에 `~/Library/Services` 를 입력하고 `NFC로 이름 정리.workflow` 를 휴지통으로 옮기면 됩니다.

---

## <img src="https://api.iconify.design/ph/play-circle-bold.svg?color=%236E7DF2&width=24" width="24" /> 사용법

**Finder에서** — 파일이나 폴더(여러 개 동시 선택도 가능)에서 우클릭 → **빠른 동작 → NFC로 이름 정리**. 폴더를 고르면 그 안쪽까지 한 번에 정리하고, 끝나면 알림이 뜹니다.

> 💡 **압축해서 보낼 땐 압축하기 전에** 폴더를 먼저 정리하세요(우클릭 → **NFC로 이름 정리** → 그다음 **압축하기**). 그러면 zip 안의 이름도 정상이라 윈도우에서 풀어도 깨지지 않습니다.

**터미널에서** —

```sh
hangul-nfc ~/Downloads/내폴더            # 폴더 안 전체 정리 (하위 포함)
hangul-nfc --dry-run ~/Desktop/*.hwp     # 바꾸기 전에 미리보기
hangul-nfc -v 보고서.pdf 자료.xlsx        # 여러 파일 + 변경 내역 출력
```

| 명령 | 하는 일 |
| --- | --- |
| `hangul-nfc setup` | Finder 우클릭 메뉴 설치 (처음 한 번). 메뉴는 설치된 CLI를 부르므로 업데이트하면 함께 최신이 됩니다(메뉴 형식이 바뀐 버전이면 `doctor` 가 다시 실행하라고 알려 줌) |
| `hangul-nfc doctor` | 설치·메뉴·자동 감시·새 버전 여부를 한눈에 점검하고, 문제마다 해결 명령을 알려 줍니다 |
| `hangul-nfc update` | 최신 버전으로 업데이트 (Homebrew 설치면 `brew upgrade` 로 위임) |
| `hangul-nfc uninstall` | 메뉴·자동 감시·설정·로그·CLI까지 한 번에 제거 (`--keep-cli` 로 CLI는 남김) |
| `hangul-nfc watch …` | 폴더 자동 정리 (아래 참고) |

| 옵션 | 설명 |
| --- | --- |
| `-n`, `--dry-run` | 실제로 바꾸지 않고 무엇이 바뀔지 미리보기 (바뀌기 전 이름은 `ㅈㅏㄹㅛ.pdf` 처럼 쪼개진 모양 그대로 보여 줌) |
| `--no-recurse` | 지정한 항목만 처리 (하위 폴더 안 들어감) |
| `--notify` | 완료 후 macOS 알림 |
| `--reveal` | 완료 후 Finder에서 결과 보여주기 |
| `-q`, `--quiet` | 조용히 실행 (요약 출력 생략, 경고·에러만) |
| `-f`, `--force` | 이름 충돌 시 덮어쓰기 — 거의 쓸 일 없음, [아래 참고](#scope) |
| `--skip` | 이름 충돌 시 건너뛰기 (기본) |
| `-v`, `--verbose` | 변경 내역을 한 줄씩 출력 |
| `-V`, `--version` | 버전 출력 |
| `-h`, `--help` | 도움말 |

---

## <img src="https://api.iconify.design/ph/arrows-clockwise-bold.svg?color=%236E7DF2&width=24" width="24" /> 업데이트 · 점검 · 제거

```sh
hangul-nfc update       # 최신으로 (Homebrew 설치면 brew upgrade hangul-nfc 와 같음)
hangul-nfc doctor       # 뭔가 이상하면 먼저 이것부터
hangul-nfc uninstall    # 흔적 없이 제거 (저장소에서 ./uninstall.sh 도 같음)
```

- Finder 메뉴는 설치된 CLI를 호출하므로 **CLI만 업데이트하면 메뉴도 자동으로 최신**입니다. 단 메뉴 형식이 바뀐 버전으로 올렸을 땐 `hangul-nfc setup` 을 한 번 다시 실행해야 합니다 — 1.1.x 이하에서 만든 메뉴, 그리고 2.0.2 이하에서 만든 메뉴(빠른 동작에 안 뜸)가 그렇습니다. 업데이트 뒤 `hangul-nfc doctor` 를 돌리면 필요할 때만 알려 줍니다.
- `brew uninstall` 만 하면 메뉴·자동 감시가 남습니다. **`hangul-nfc uninstall` 을 쓰세요** — Homebrew 설치본이면 마지막에 `brew uninstall` 까지 해 줍니다.

<a id="troubleshooting"></a>

### <img src="https://api.iconify.design/ph/wrench-bold.svg?color=%236E7DF2&width=20" width="20" /> 문제 해결

| 증상 | 해결 |
| --- | --- |
| 우클릭 → **빠른 동작**에 *NFC로 이름 정리*가 없다 | ① 터미널에서 `hangul-nfc doctor` — 원인과 해결 명령을 알려 줍니다. ② 우클릭 → **빠른 동작 → 사용자화…** 에서 *NFC로 이름 정리*가 켜져 있는지 확인하세요. ③ 2.0.2 이하 zip으로 설치한 메뉴는 빠른 동작에 안 뜹니다 — 최신 zip을 다시 받아 설치하거나 `hangul-nfc setup` 을 실행하세요. |
| 설치하는 중 Finder 창이 닫혔다 다시 열렸다 | 정상입니다. 새 메뉴를 바로 보이게 하려고 `setup` 이 Finder를 한 번 다시 띄웁니다. |
| `hangul-nfc: command not found` | brew 없이 설치했다면 **새 터미널 창**을 여세요. 지금 창에서 바로 쓰려면 `~/.local/bin/hangul-nfc` 처럼 전체 경로로 실행합니다. |
| 완료 알림이 안 뜬다 | 알림은 *스크립트 편집기* 이름으로 옵니다. **시스템 설정 → 알림 → 스크립트 편집기** 에서 알림을 허용하세요. 허용돼 있는데도 안 뜨면 **집중 모드**(방해금지·업무 등) 때문입니다 — 알림은 배너 없이 **알림 센터**(메뉴 막대의 시계 클릭)로만 갑니다. 바로 보이게 하려면 **시스템 설정 → 집중 모드 → (사용 중인 모드) → 허용된 앱**에 *스크립트 편집기*를 추가하세요. 집중 모드는 같은 Apple 계정의 기기끼리 공유되므로 다른 기기에서 켠 모드일 수도 있습니다. |
| 단축키로 실행하고 싶다 | **시스템 설정 → 키보드 → 키보드 단축키… → 서비스 → 파일 및 폴더 → NFC로 이름 정리** 에 단축키를 지정하면, Finder에서 고른 뒤 단축키 한 번으로 정리됩니다. |
| 알림에 `N개 변경 불가(볼륨이 NFD 강제)` | USB 메모리(exFAT)·NAS(SMB) 등은 이 Mac에서 이름을 고칠 수 없습니다. 내장 디스크로 복사한 뒤 정리하세요([자세히](#scope)). |
| 알림에 `N개 열 수 없음` | 권한이 없어 읽지 못한 폴더가 있다는 뜻입니다. 터미널에서 같은 폴더로 `hangul-nfc -v` 를 실행하면 어느 폴더인지 보입니다. |

<a id="nfd2nfc에서-옮겨-오기"></a>

<details>
<summary><b>nfd2nfc에서 옮겨 오기</b> (1.x 사용자만)</summary>

<br>

1.x 때 이름은 `nfd2nfc` 였습니다. homebrew/core에 이름이 같은 다른 도구가 있어 2.0부터 `hangul-nfc` 로 바꿨습니다. 명령 이름만 바뀌고 쓰는 법은 같습니다.

**설치 방법과 상관없이 한 줄 설치를 다시 실행하면 끝납니다.**

```sh
curl -fsSL https://raw.githubusercontent.com/wonjun-lab/hangul-nfc/main/install.sh | sh
```

Homebrew 설치본은 새 이름으로 옮기고(`brew migrate`) 최신으로 올린 뒤, `hangul-nfc setup` 이 Finder 메뉴·자동 감시 폴더·설정을 새 이름으로 옮기고 예전 흔적을 정리합니다.

- ⚠️ **`brew upgrade` 만으로는 옮겨지지 않습니다.** Homebrew의 탭 신뢰 정책 때문에 이름이 바뀐 formula는 조용히 건너뜁니다(실측). 직접 하려면:
  ```sh
  brew trust --formula wonjun-lab/tap/hangul-nfc && brew migrate hangul-nfc && brew upgrade hangul-nfc
  hangul-nfc setup
  ```
- ⚠️ 예전 버전의 `nfd2nfc update`·`nfd2nfc doctor` 로는 2.0을 찾지 못합니다(이름이 바뀌어 "확인 실패"처럼 보입니다). 위 방법으로 옮겨 오세요.
- 옮기기 전까지도 예전 `nfd2nfc` 1.2.0은 그대로 동작합니다(메뉴·자동 감시 포함).
- 남은 게 있는지는 `hangul-nfc doctor` 가 알려 줍니다(예전 이름의 흔적도 찾아냅니다).
- 예전 GitHub 주소(`wonjun-lab/nfd2nfc`)는 웹·git 에서 새 주소로 자동 연결됩니다.

</details>

---

## <img src="https://api.iconify.design/ph/eye-bold.svg?color=%236E7DF2&width=24" width="24" /> 자동 감시 — 폴더를 알아서 정리

자주 NFD 파일이 들어오는 **작업 폴더**를 등록해 두면, 새 파일이 생길 때마다 백그라운드에서 자동으로 정리합니다. macOS 기본 `launchd`만 쓰며(의존성 0), 변경이 있을 때만 조용히 알립니다.

```sh
hangul-nfc watch add ~/작업 ~/Pictures/스크린샷   # 등록 + 즉시 1회 정리
hangul-nfc watch list                            # 등록 폴더·상태 보기
hangul-nfc watch off                             # 중지 (다시 로그인해도 꺼진 채 유지)
hangul-nfc watch on                              # 재개
hangul-nfc watch remove ~/작업                    # 해제
```

> ⚠️ **다운로드·데스크탑·문서·iCloud Drive·Dropbox/Google Drive(클라우드 저장소)·외장/네트워크 볼륨은 등록할 수 없습니다.** macOS가 이 위치들을 백그라운드 프로그램으로부터 보호하기 때문입니다(개인정보 보호). 서명된 정식 앱이 아닌 도구는 권한 요청 창조차 띄울 수 없어, 등록해도 **조용히 아무 일도 안 일어납니다**(macOS 26에서 실측). 그래서 hangul-nfc는 등록 단계에서 막고 대안을 안내하며, 예전 버전에서 등록해 둔 보호 폴더는 자동으로 해제하고 알립니다. 이런 폴더는 **Finder 우클릭 메뉴**나 **`hangul-nfc ~/Downloads`** 로 정리하세요.

- 처음 등록하면 macOS가 *“'hangul-nfc' 앱은 백그라운드에서 실행될 수 있습니다”* 알림을 띄웁니다. 자동 감시가 켜졌다는 뜻이니 그대로 두면 됩니다(끄려면 `hangul-nfc watch off`).
- 등록 폴더는 **하위까지** 정리합니다. 이미 정상인 이름은 건드리지 않으므로 반복 실행돼도 안전합니다.
- 즉시 반응하는 건 **등록 폴더 바로 아래**에 생긴 변화입니다(`launchd` 한계). 하위 폴더 안에 새로 생긴 파일은 **1시간마다 도는 전체 점검**에서 정리됩니다.
- HFS+·exFAT·FAT 볼륨과 SMB(NAS 공유 폴더)의 폴더도 등록할 수 없습니다(아래 **바꾸는 범위** 참고).
- 정리할 수 없게 된 폴더(권한·볼륨 문제)나 지워진 폴더는 조용히 실패하지 않고 감시에서 빠지며 알림이 뜹니다(빼낸 외장 디스크 안의 폴더는 다시 꽂을 때까지 그대로 둡니다). 상태는 `hangul-nfc doctor` 로 확인하세요.
- `/`·홈 폴더처럼 보호 폴더를 품은 상위 폴더는 등록할 수 없습니다 — 그 아래 작업 폴더를 골라 등록하세요.
- 로그: `~/Library/Logs/hangul-nfc-watch.log` · 설정: `~/Library/Application Support/hangul-nfc/`

---

## <img src="https://api.iconify.design/ph/shield-check-bold.svg?color=%236E7DF2&width=24" width="24" /> 안전한가요?

네. 보수적으로, 되돌릴 일이 없게 동작합니다.

- 화면에 보이는 글자는 그대로 — 쪼개진 자모 등을 합치기만 합니다. 표준 NFC 변환과 달리 호환 한자(`樂` U+F914 등)나 `Ω`(U+2126) 같은 문자를 다른 코드포인트로 바꾸지 않습니다.
- 이미 정상(NFC)인 파일은 손대지 않습니다.
- 여러 번 실행해도 안전합니다(idempotent). 바꿀 게 없으면 아무 일도 일어나지 않습니다.
- 깊은 폴더부터 처리해, 폴더 이름을 바꿔도 하위 경로가 어긋나지 않습니다.
- 심볼릭 링크를 따라 들어가지 않습니다(링크 자신의 이름만 정리). 터미널에서 `링크/` 처럼 끝에 `/` 를 붙여 직접 지정할 때만 대상 폴더를 정리합니다.
- 앱 번들·패키지(`.app`·`.photoslibrary`·`.pages` 등)는 이름만 정리하고 안으로 들어가지 않습니다 — 내부 이름을 바꾸면 코드서명이 깨질 수 있어서입니다. 상위 폴더를 정리할 때 `~/Library` 안으로도 들어가지 않습니다(앱 데이터 보호).
- 권한이 없어 못 읽거나 못 바꾸는 항목은 건너뛰고 알립니다(종료 코드 1).
- **Dropbox·iCloud 등 동기화 폴더에서도 안전** — 이름만 바꾸므로(메타데이터만 변경), 클라우드 전용(아직 안 받은) 파일을 통째로 내려받지 않습니다.

> 💡 **왜 단순 비교가 아니라 inode를 보냐면** — macOS 파일시스템(APFS·HFS+)은 정규형을 구분하지 않아, NFD 파일을 NFC 이름으로 조회해도 “이미 있다”고 나옵니다. 그래서 hangul-nfc는 단순 존재 검사 대신 inode를 비교해, 정말로 다른 파일이 그 이름을 차지한 경우에만 건너뜁니다.

---

<a id="scope"></a>

## <img src="https://api.iconify.design/ph/info-bold.svg?color=%236E7DF2&width=24" width="24" /> 바꾸는 범위 — 알아두면 좋은 점

hangul-nfc는 **파일·폴더 이름만** NFC로 바꿉니다. 그래서:

- **파일 내용은 건드리지 않습니다.** 확장자·형식(`png`·`jpg`·`pdf`·`hwp`·`docx`·`xlsx` 등)과 무관하게, 이름만 정규화하고 내용·형식은 그대로 둡니다.
- **압축 파일 안의 이름은 바꾸지 않습니다.** `zip`·`tar`, 그리고 내부가 압축인 `hwpx`·`docx` 같은 파일은 **파일 자체 이름만** 정규화됩니다. 압축 안에 든 한글 파일명이 NFD라면 다른 OS에서 풀 때 여전히 깨집니다 — 내부까지 고치려면 **macOS에서 풀어 정규화한 뒤 다시 압축**하세요.
- **HFS+·exFAT·FAT·SMB(NAS 공유 폴더) 볼륨에선 바꿀 수 없습니다.** HFS+는 파일명을 디스크에 NFD로 강제 저장하고, exFAT·FAT(USB 메모리 등)과 SMB는 디스크(서버)엔 조합형으로 저장하지만 macOS가 항상 NFD로 보여 줍니다 — 그래서 윈도우·NAS에서 직접 보면 정상이어도, **이 Mac에서 웹에 올리면 여전히 깨집니다.** hangul-nfc는 이런 볼륨을 감지해 손대지 않고 `N개 변경 불가(볼륨이 NFD 강제)`로 알립니다(종료 코드 1). 올릴 파일은 **APFS 볼륨(내장 디스크 등)으로 복사한 뒤** 정리하세요.
- **NAS에 NFD로 올라간 이름은 NAS에서 정리하세요.** rsync·scp 등으로 Mac에서 NAS로 옮긴 파일은 NAS 디스크에 NFD 그대로 저장될 수 있습니다. 이런 파일은 Mac에서 SMB로 목록엔 보여도 **열리지 않고 이름도 바꿀 수 없습니다**(실측: Synology DSM 7). 아래 스크립트를 NAS에서 실행하면 정리되고, 그 뒤엔 Mac에서도 정상으로 열립니다.
- **`--force`는 거의 쓸 일이 없습니다.** macOS 기본 볼륨(APFS·HFS+)에선 NFD와 NFC가 같은 파일이라 이름 충돌이 생기지 않습니다. `--force`는 정규형을 구분하는 일부 외장·네트워크 볼륨에서만 의미가 있고, 그곳에선 같은 이름의 **다른 파일을 영구히 덮어쓰므로**(복구 불가) 주의하세요. 기본값(충돌 시 건너뜀)을 권장합니다.

<details>
<summary>NAS(Linux·Synology)에서 직접 정리하는 스크립트</summary>

<br>

Synology DSM엔 perl이 없어 기본 `python3`(3.8+)용으로 제공합니다. hangul-nfc와 같은 규칙(쪼개진 자모만 합치고 호환 한자 등은 보존, 깊은 곳부터, 같은 이름이 있으면 건너뜀)으로 동작합니다. NAS에 SSH로 접속해 아래를 `nas-nfc.py` 로 저장한 뒤 실행하세요.

```sh
python3 nas-nfc.py -n /volume1/공유폴더   # 미리보기
python3 nas-nfc.py /volume1/공유폴더      # 실제 변경
```

```python
import os, sys, unicodedata as ud
def fix(s):  # 쪼개진 자모만 합친다 — NFC가 바꾸는 호환 한자·Ω 등은 그대로
    out, seg = [], ""
    for ch in s:
        if ud.normalize("NFC", ch) != ch:
            out += [ud.normalize("NFC", seg), ch]; seg = ""
        else:
            seg += ch
    return "".join(out) + ud.normalize("NFC", seg)
dry = sys.argv[1:2] == ["-n"]
n = 0
for top in sys.argv[1 + dry:]:
    for d, subs, files in os.walk(top, topdown=False):
        for name in subs + files:
            new = fix(name)
            if new == name or name == "@eaDir":
                continue
            if os.path.lexists(os.path.join(d, new)):
                print("건너뜀(같은 이름 존재):", os.path.join(d, name)); continue
            print(("[미리보기] " if dry else "변경: ") + os.path.join(d, name))
            if not dry:
                os.rename(os.path.join(d, name), os.path.join(d, new))
            n += 1
print(("미리보기: %d개 변경 예정" if dry else "완료: %d개 변경") % n)
```

</details>

---

## <img src="https://api.iconify.design/ph/hard-drives-bold.svg?color=%236E7DF2&width=24" width="24" /> 근본 해결 (서버를 직접 운영한다면)

받는 서버를 직접 운영한다면, 업로드 시점에 서버에서 정규화하는 것이 가장 완전합니다.

```python
import unicodedata
filename = unicodedata.normalize("NFC", filename)
```

hangul-nfc는 그게 불가능한, **올리는 쪽 사용자**를 위한 처방입니다.

---

## <img src="https://api.iconify.design/ph/git-pull-request-bold.svg?color=%236E7DF2&width=24" width="24" /> 기여 · 개발

테스트·릴리스 절차는 [CONTRIBUTING.md](CONTRIBUTING.md) 를, 변경 이력은 [CHANGELOG.md](CHANGELOG.md) 를 참고하세요.

```sh
./test.sh        # 통합 테스트 (macOS 전용)
```

---

## <img src="https://api.iconify.design/ph/globe-bold.svg?color=%236E7DF2&width=24" width="24" /> English

**hangul-nfc** fixes macOS NFD filenames — Korean names like `안녕.txt` that appear as
`ㅇㅏㄴㄴㅕㅇ.txt` on Windows or web uploads — by normalizing files and folders to NFC.
Zero dependencies; it uses the `perl` that already ships with macOS. The visible
characters stay the same; only the underlying Unicode form is normalized.

> Formerly **nfd2nfc** (renamed in 2.0). To migrate, re-run the one-liner below — a plain
> `brew upgrade` does not migrate it.

| Install | How |
| --- | --- |
| <img src="https://api.iconify.design/ph/terminal-window-bold.svg?color=%236E7DF2&width=18" width="18" align="center" /> One-liner (recommended — uses Homebrew if present, installs the Finder Quick Action) | `curl -fsSL https://raw.githubusercontent.com/wonjun-lab/hangul-nfc/main/install.sh \| sh` |
| <img src="https://api.iconify.design/simple-icons/homebrew.svg?color=%236E7DF2&width=18" width="18" align="center" /> Homebrew | `brew install wonjun-lab/tap/hangul-nfc && hangul-nfc setup` |
| <img src="https://api.iconify.design/ph/cursor-click-bold.svg?color=%236E7DF2&width=18" width="18" align="center" /> Finder only (no terminal) | Download `hangul-nfc-quick-action.zip` from [Releases](https://github.com/wonjun-lab/hangul-nfc/releases/latest), unzip, double-click `NFC로 이름 정리.workflow` |

```
hangul-nfc [--dry-run] [--no-recurse] [--notify] [--reveal] [-q] [-f|--skip] [-v] [-V] [-h] <paths…>
hangul-nfc setup        # install the Finder Quick Action (it calls the installed CLI, so updates carry over)
hangul-nfc doctor       # check install, Quick Action, auto-watch and updates — with a fix for each problem
hangul-nfc update       # update (delegates to `brew upgrade` for Homebrew installs)
hangul-nfc uninstall    # remove everything: Quick Action, auto-watch, settings, logs and the CLI
hangul-nfc watch add|remove|list|on|off <folders…>   # auto-normalize folders in the background
```

Auto-watch cannot cover Downloads, Desktop, Documents, iCloud Drive, cloud-storage folders
(Dropbox, Google Drive…) or external/network volumes: macOS privacy protection (TCC) blocks
background access there, and unsigned tools cannot even ask for permission. hangul-nfc refuses
those folders up front and points you to the Finder Quick Action or the CLI instead.

Safe by design: already-NFC files are left untouched, clashes with genuinely different
files are skipped, app bundles and other packages are never entered (so code signatures stay
intact), and re-running is idempotent. If the Quick Action doesn't show up, run
`hangul-nfc doctor` or see [문제 해결](#troubleshooting).

---

<div align="center">

<img src="https://api.iconify.design/ph/scales-bold.svg?color=%236E7DF2&width=20" width="20" /><br>
<sub><a href="LICENSE">MIT License</a> · macOS 한글 파일명 NFD→NFC 정리</sub>

</div>

<div align="center">

<img src="https://api.iconify.design/ph/translate-bold.svg?color=%236E7DF2&width=80" width="80" alt="" />

# nfd2nfc

### macOS 한글 파일명 자소분리, 우클릭 한 번으로 해결

`안녕.txt` 가 `ㅇㅏㄴㄴㅕㅇ.txt` 로 깨지는 문제 — 추가 설치 없이 macOS 기본 도구만으로 정리합니다.

<br>

[![CI](https://img.shields.io/github/actions/workflow/status/wonjun-lab/nfd2nfc/ci.yml?branch=main&style=flat-square&logo=github&label=CI)](https://github.com/wonjun-lab/nfd2nfc/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/wonjun-lab/nfd2nfc?style=flat-square&logo=github&label=release)](https://github.com/wonjun-lab/nfd2nfc/releases/latest)
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

macOS는 한글 파일명을 자모 단위로 **쪼개서**(NFD, 분해형) 저장합니다. 반면 윈도우·리눅스·대부분의 웹은 글자를 **합쳐서**(NFC, 조합형) 다룹니다. 화면에선 똑같이 `안녕.txt` 로 보이지만 내부 바이트가 다릅니다.

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

**nfd2nfc** 는 파일·폴더 이름을 NFC로 바꿔 이 문제를 없앱니다. 보이는 글자는 그대로 두고 내부 인코딩만 정규화하므로 안전합니다.

---

## <img src="https://api.iconify.design/ph/download-simple-bold.svg?color=%236E7DF2&width=24" width="24" /> 설치

세 가지 방법 중 **하나만** 고르면 됩니다.

### <img src="https://api.iconify.design/simple-icons/homebrew.svg?color=%236E7DF2&width=20" width="20" /> Homebrew — CLI 명령만 쓸 때

```sh
brew install wonjun-lab/tap/nfd2nfc
```

`nfd2nfc` 터미널 명령이 설치됩니다.

### <img src="https://api.iconify.design/ph/cursor-click-bold.svg?color=%236E7DF2&width=20" width="20" /> Finder 우클릭 메뉴 — 터미널을 안 쓸 때

1. [**Releases**](https://github.com/wonjun-lab/nfd2nfc/releases/latest) 에서 `nfd2nfc-quick-action.zip` 을 내려받아 압축을 풉니다.
2. 나온 `NFC로 이름 정리.workflow` 를 더블클릭 → *“빠른 동작을 설치하시겠습니까?”* 에서 **설치**.
3. 끝! 이제 파일·폴더를 우클릭 → **빠른 동작 → NFC로 이름 정리**.

> 더블클릭이 보안으로 막히면 파일을 **우클릭 → 열기** 로 한 번만 실행하세요.

### <img src="https://api.iconify.design/ph/terminal-window-bold.svg?color=%236E7DF2&width=20" width="20" /> 한 줄 설치 — 우클릭 메뉴 + CLI 명령을 한 번에

```sh
git clone https://github.com/wonjun-lab/nfd2nfc.git
cd nfd2nfc
./install.sh
```

Finder 우클릭 메뉴와 `nfd2nfc` 명령이 함께 설치됩니다. 제거는 `./uninstall.sh`.

---

## <img src="https://api.iconify.design/ph/play-circle-bold.svg?color=%236E7DF2&width=24" width="24" /> 사용법

**Finder에서** — 파일이나 폴더(여러 개 동시 선택도 가능)에서 우클릭 → **빠른 동작 → NFC로 이름 정리**. 폴더를 고르면 그 안쪽까지 한 번에 정리하고, 끝나면 알림이 뜹니다.

**터미널에서** —

```sh
nfd2nfc ~/Downloads/내폴더            # 폴더 안 전체 정리 (하위 포함)
nfd2nfc --dry-run ~/Desktop/*.hwp     # 바꾸기 전에 미리보기
nfd2nfc --notify ~/사진들              # 끝나면 알림 표시
nfd2nfc -v 보고서.pdf 자료.xlsx        # 여러 파일 + 변경 내역 출력
```

| 옵션 | 설명 |
| --- | --- |
| `-n`, `--dry-run` | 실제로 바꾸지 않고 무엇이 바뀔지 미리보기 |
| `--no-recurse` | 지정한 항목만 처리 (하위 폴더 안 들어감) |
| `--notify` | 완료 후 macOS 알림 |
| `--reveal` | 완료 후 Finder에서 결과 보여주기 |
| `-q`, `--quiet` | 조용히 실행 (요약 출력 생략, 경고·에러만) |
| `-f`, `--force` | 이름 충돌 시 덮어쓰기 (기본은 건너뜀) |
| `--skip` | 이름 충돌 시 건너뛰기 (기본) |
| `-v`, `--verbose` | 변경 내역을 한 줄씩 출력 |
| `-V`, `--version` | 버전 출력 |
| `-h`, `--help` | 도움말 |

---

## <img src="https://api.iconify.design/ph/eye-bold.svg?color=%236E7DF2&width=24" width="24" /> 자동 감시 — 폴더를 알아서 정리

자주 NFD 파일이 들어오는 폴더(다운로드·Dropbox 등)를 등록해 두면, 새 파일이 생길 때마다 백그라운드에서 자동으로 NFC로 정리합니다. macOS 기본 `launchd`만 쓰며(의존성 0), 변경이 있을 때만 조용히 알립니다.

```sh
nfd2nfc watch add ~/Downloads ~/Dropbox   # 등록 + 즉시 1회 정리
nfd2nfc watch list                        # 등록 폴더·상태 보기
nfd2nfc watch off                         # 잠시 중지
nfd2nfc watch on                          # 재개
nfd2nfc watch remove ~/Dropbox            # 해제
```

- 등록 폴더는 **하위까지** 정리합니다. 무한루프 없이(idempotent + 10초 간격) 안전하게 동작합니다.
- 즉시 반응하는 건 **등록 폴더 바로 아래**에 생긴 변화입니다(`launchd` 한계). 하위 폴더 안에 새로 생긴 파일은 **1시간마다 도는 전체 점검**에서 정리됩니다 — 자주 쓰는 하위 폴더가 있으면 그 폴더도 함께 등록하세요.
- HFS+·exFAT·FAT 볼륨(외장 드라이브 등)의 폴더는 등록할 수 없습니다(아래 **바꾸는 범위** 참고).
- 로그: `~/Library/Logs/nfd2nfc-watch.log` · 설정: `~/Library/Application Support/nfd2nfc/`
- 켜고 끄기는 로그인 세션 단위로 유지됩니다(launchd LaunchAgent).

---

## <img src="https://api.iconify.design/ph/shield-check-bold.svg?color=%236E7DF2&width=24" width="24" /> 안전한가요?

네. 보수적으로, 되돌릴 일이 없게 동작합니다.

- 화면에 보이는 글자는 그대로 — 쪼개진 자모 등을 합치기만 합니다. 표준 NFC 변환과 달리 호환 한자(`樂` U+F914 등)나 `Ω`(U+2126) 같은 문자를 다른 코드포인트로 바꾸지 않습니다.
- 이미 정상(NFC)인 파일은 손대지 않습니다.
- 여러 번 실행해도 안전합니다(idempotent). 바꿀 게 없으면 아무 일도 일어나지 않습니다.
- 깊은 폴더부터 처리해, 폴더 이름을 바꿔도 하위 경로가 어긋나지 않습니다.
- 심볼릭 링크를 따라 들어가지 않습니다.
- 권한이 없어 못 읽거나 못 바꾸는 항목은 건너뛰고 알립니다(종료 코드 1).
- **Dropbox·iCloud 등 동기화 폴더에서도 안전** — 이름만 바꾸므로(메타데이터만 변경), 클라우드 전용(아직 안 받은) 파일을 통째로 내려받지 않습니다.

> 💡 **왜 단순 비교가 아니라 inode를 보냐면** — macOS 파일시스템(APFS·HFS+)은 정규형을 구분하지 않아, NFD 파일을 NFC 이름으로 조회해도 “이미 있다”고 나옵니다. 그래서 nfd2nfc는 단순 존재 검사 대신 inode를 비교해, 정말로 다른 파일이 그 이름을 차지한 경우에만 건너뜁니다.

---

## <img src="https://api.iconify.design/ph/info-bold.svg?color=%236E7DF2&width=24" width="24" /> 바꾸는 범위 — 알아두면 좋은 점

nfd2nfc는 **파일·폴더 이름만** NFC로 바꿉니다. 그래서:

- **파일 내용은 건드리지 않습니다.** 확장자·형식(`png`·`jpg`·`pdf`·`hwp`·`docx`·`xlsx` 등)과 무관하게, 이름만 정규화하고 내용·형식은 그대로 둡니다.
- **압축 파일 안의 이름은 바꾸지 않습니다.** `zip`·`tar`, 그리고 내부가 압축인 `hwpx`·`docx` 같은 파일은 **파일 자체 이름만** 정규화됩니다. 압축 안에 든 한글 파일명이 NFD라면 다른 OS에서 풀 때 여전히 깨집니다 — 내부까지 고치려면 **macOS에서 풀어 정규화한 뒤 다시 압축**하세요.
- **앱 번들(`.app`)은 피하세요.** macOS는 `.app`을 폴더로 다뤄, 통째로 정리하면 내부까지 들어갑니다. 보통은 무해하지만 **코드서명된 앱은 서명이 무효화**될 수 있습니다.
- **HFS+·exFAT·FAT 볼륨에선 바꿀 수 없습니다.** HFS+는 파일명을 디스크에 NFD로 강제 저장하고, exFAT·FAT(USB 메모리 등)은 디스크엔 조합형으로 저장하지만 macOS가 항상 NFD로 보여 줍니다 — 그래서 윈도우에 직접 꽂으면 정상이어도, **이 Mac에서 웹에 올리면 여전히 깨집니다.** nfd2nfc는 이런 볼륨을 감지해 손대지 않고 `N개 변경 불가(볼륨이 NFD 강제)`로 알립니다(종료 코드 1). 올릴 파일은 **APFS 볼륨(내장 디스크 등)으로 복사한 뒤** 정리하세요.
- **`--force`는 거의 쓸 일이 없습니다.** macOS 기본 볼륨(APFS·HFS+)에선 NFD와 NFC가 같은 파일이라 이름 충돌이 생기지 않습니다. `--force`는 정규형을 구분하는 일부 외장·네트워크 볼륨에서만 의미가 있고, 그곳에선 같은 이름의 **다른 파일을 영구히 덮어쓰므로**(복구 불가) 주의하세요. 기본값(충돌 시 건너뜀)을 권장합니다.

---

## <img src="https://api.iconify.design/ph/hard-drives-bold.svg?color=%236E7DF2&width=24" width="24" /> 근본 해결 (서버를 직접 운영한다면)

받는 서버를 직접 운영한다면, 업로드 시점에 서버에서 정규화하는 것이 가장 완전합니다.

```python
import unicodedata
filename = unicodedata.normalize("NFC", filename)
```

nfd2nfc는 그게 불가능한, **올리는 쪽 사용자**를 위한 처방입니다.

---

<details>
<summary><img src="https://api.iconify.design/ph/wrench-bold.svg?color=%236E7DF2&width=18" width="18" /> &nbsp;Quick Action을 직접 만들기 (수동 폴백)</summary>

<br>

`install.sh` 나 zip을 쓸 수 없을 때, Automator로 직접 만들 수 있습니다.

**Automator** → 새 문서 → **빠른 동작** → *받는 입력:* **파일 또는 폴더**, *위치:* **Finder.app** →
**셸 스크립트 실행** 추가 → *셸:* `/bin/zsh`, *입력 전달:* **인수로** → 아래를 붙여넣고
이름을 `NFC로 이름 정리` 로 저장합니다.

```sh
/usr/bin/perl -e 'use strict; use warnings;
use Unicode::Normalize qw(compose reorder);
use Encode qw(decode_utf8 encode_utf8);
my @t;
sub col {
  my $p = shift; $p =~ s{/+$}{}; return if $p eq "";
  push @t, $p;
  if (-d $p && !-l $p && opendir(my $d, $p)) {
    my @e = readdir($d); closedir($d);
    for my $x (@e) { next if $x eq "." || $x eq ".."; col("$p/$x"); }
  }
}
col($_) for @ARGV;
my ($c, $s, $x, %ok, %bad) = (0, 0, 0);
for my $p (sort { ($b =~ tr{/}{}) <=> ($a =~ tr{/}{}) } @t) {
  my $i = rindex($p, "/");
  my $dir  = $i == -1 ? "" : substr($p, 0, $i + 1);
  my $base = $i == -1 ? $p : substr($p, $i + 1);
  my $u = eval { my $cp = $base; decode_utf8($cp, Encode::FB_CROAK) };
  next unless defined $u;
  # 쪼개진 자모만 합친다(NFC와 달리 호환 한자 등은 그대로 둔다).
  my $nb = encode_utf8(compose(reorder($u)));
  next if $nb eq $base;
  my $new = $dir . $nb;
  my @cur = lstat($p);
  if (@cur && $bad{$cur[0]}) { $x++; next; }
  # APFS는 정규화 비구분 → NFC 이름도 자기 자신으로 잡힌다.
  # inode를 비교해 "진짜 다른 파일"이 있을 때만 건너뛴다.
  my @tgt = lstat($new);
  if (@tgt && (!@cur || $tgt[0] != $cur[0] || $tgt[1] != $cur[1])) { $s++; next; }
  next unless rename($p, $new);
  # HFS+·exFAT·FAT은 이름을 NFD로 되돌린다 → 볼륨마다 첫 변경만 실제로 바뀌었는지 확인.
  if (!@cur || $ok{$cur[0]}) { $c++; next; }
  opendir(my $d, $dir eq "" ? "." : $dir) or next;
  my $hit = grep { $_ eq $nb } readdir($d); closedir($d);
  if ($hit) { $ok{$cur[0]} = 1; $c++; } else { $bad{$cur[0]} = 1; $x++; }
}
my $msg = "이름 정리 완료: ${c}개 변경" . ($s ? ", ${s}개 건너뜀" : "")
        . ($x ? ", ${x}개 변경 불가(볼륨이 NFD 강제)" : "");
system("/usr/bin/osascript", "-e",
       "display notification \"$msg\" with title \"NFC 이름 정리\"");' "$@"
```

> 배포되는 `nfd2nfc-quick-action.zip` 은 `build-workflow.sh` 가 `nfd2nfc` 본문을 그대로 임베드해 자동 생성합니다. 스크립트를 고치면 `./build-workflow.sh` 로 다시 만드세요.

</details>

---

## <img src="https://api.iconify.design/ph/git-pull-request-bold.svg?color=%236E7DF2&width=24" width="24" /> 기여 · 개발

테스트·릴리스 절차는 [CONTRIBUTING.md](CONTRIBUTING.md) 를, 변경 이력은 [CHANGELOG.md](CHANGELOG.md) 를 참고하세요.

```sh
./test.sh        # 통합 테스트 (macOS 전용)
```

---

## <img src="https://api.iconify.design/ph/globe-bold.svg?color=%236E7DF2&width=24" width="24" /> English

**nfd2nfc** fixes macOS NFD filenames — Korean names like `안녕.txt` that appear as
`ㅇㅏㄴㄴㅕㅇ.txt` on Windows or web uploads — by normalizing files and folders to NFC.
Zero dependencies; it uses the `perl` that already ships with macOS. The visible
characters stay the same; only the underlying Unicode form is normalized.

| Install | How |
| --- | --- |
| <img src="https://api.iconify.design/simple-icons/homebrew.svg?color=%236E7DF2&width=18" width="18" align="center" /> Homebrew (CLI) | `brew install wonjun-lab/tap/nfd2nfc` |
| <img src="https://api.iconify.design/ph/cursor-click-bold.svg?color=%236E7DF2&width=18" width="18" align="center" /> Finder only (no terminal) | Download `nfd2nfc-quick-action.zip` from [Releases](https://github.com/wonjun-lab/nfd2nfc/releases/latest), unzip, double-click `NFC로 이름 정리.workflow` |
| <img src="https://api.iconify.design/ph/terminal-window-bold.svg?color=%236E7DF2&width=18" width="18" align="center" /> CLI + Finder Quick Action | `git clone … && cd nfd2nfc && ./install.sh` |

```
nfd2nfc [--dry-run] [--no-recurse] [--notify] [--reveal] [-q] [-f] [-v] [-V] [-h] <paths…>
```

Safe by design: already-NFC files are left untouched, clashes with genuinely different
files are skipped, and re-running is idempotent.

---

<div align="center">

<img src="https://api.iconify.design/ph/scales-bold.svg?color=%236E7DF2&width=20" width="20" /><br>
<sub><a href="LICENSE">MIT License</a> · macOS 한글 파일명 NFD→NFC 정리</sub>

</div>

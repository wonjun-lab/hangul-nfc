#!/usr/bin/env bash
# test.sh — hangul-nfc 통합 테스트 (macOS/APFS 전용)
# 정규화 비구분 FS 동작에 의존하므로 반드시 macOS에서 실행.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
HANGUL_NFC="$HERE/hangul-nfc"
PASS=0
FAIL=0

# 테스트 중 osascript(Finder/알림) 부작용·AppleEvent 타임아웃을 차단한다.
# (Quick Action 명령은 항상 --reveal을 포함하므로 이 가드가 없으면 Finder가 튀어나오고
#  헤드리스 CI에서는 AppleEvent가 120초 타임아웃 날 수 있다.)
export HANGUL_NFC_NO_GUI=1
# 실제 Homebrew를 절대 부르지 않는다(빈 값 = brew 없음). install.sh·CLI는 이 값이 있으면 /opt/homebrew 등을
# 찾지 않는다 — 없으면 이 머신의 실제 Homebrew 설치본을 brew uninstall 할 수 있다. brew 경로는 아래 스텁으로만 시험한다.
export HANGUL_NFC_BREW=""

ok() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
ng() { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

# 디렉토리 아래 NFD로 남은 항목 수 출력(시작 디렉토리 자신은 제외)
count_nfd() {
    /usr/bin/perl -CSDA -MFile::Find -e '
        use Unicode::Normalize qw(NFC); use Encode qw(decode_utf8);
        my $n = 0;
        find(sub {
            return if $_ eq ".";
            my $u = eval { my $c = $_; decode_utf8($c, Encode::FB_CROAK) };
            return unless defined $u;
            $n++ if NFC($u) ne $u;
        }, $ARGV[0]);
        print $n;
    ' "$1"
}

# 단일 경로의 basename이 NFC면 exit 0, 아니면 exit 1 (디렉토리 비재귀)
is_nfc_base() {
    /usr/bin/perl -e '
        use Unicode::Normalize qw(NFC); use Encode qw(decode_utf8);
        my $p = $ARGV[0]; $p =~ s{/+$}{};
        my $i = rindex($p, "/"); my $b = $i < 0 ? $p : substr($p, $i + 1);
        my $u = eval { my $c = $b; decode_utf8($c, Encode::FB_CROAK) };
        exit((defined $u && NFC($u) eq $u) ? 0 : 1);
    ' "$1"
}

# t10 등에서 최상위 첫 (디렉토리|파일) 항목 경로를 출력
first_entry() {  # first_entry <base> <d|f>
    /usr/bin/perl -e '
        opendir(my $d, $ARGV[0]) or exit 0;
        for (sort readdir $d) {
            next if /^\.\.?$/;
            my $p = "$ARGV[0]/$_";
            if ($ARGV[1] eq "d") { next unless -d $p } else { next unless -f $p }
            print $p; last;
        }
    ' "$1" "$2"
}

# 표준 NFD 픽스처: <dir>/보고서.hwp, <dir>/하위폴더/사진.jpg
# use utf8: 소스의 한글 리터럴을 진짜 한글 코드포인트로 인식해야 한글 자모(U+11xx) NFD가
# 만들어진다. 빼면 UTF-8 바이트를 latin-1로 오인해 라틴 분해문자 NFD를 테스트하게 된다.
make_fixture() {
    base="$1"
    mkdir -p "$base"
    /usr/bin/perl -e '
        use utf8;
        use Unicode::Normalize qw(NFD); use Encode qw(encode_utf8);
        my $b = $ARGV[0];
        open(my $f, ">", "$b/" . encode_utf8(NFD("보고서.hwp"))) or die "$!"; close $f;
        my $d = "$b/" . encode_utf8(NFD("하위폴더")); mkdir $d or die "$!";
        open($f, ">", "$d/" . encode_utf8(NFD("사진.jpg"))) or die "$!"; close $f;
    ' "$base"
}

TMP=$(mktemp -d)
trap 'hdiutil detach -quiet "$TMP/hfsmnt" >/dev/null 2>&1; rm -rf "$TMP"' EXIT

echo "== hangul-nfc 통합 테스트 =="

# [1] 기본 변환: 중첩 포함 전부 NFC
make_fixture "$TMP/t1"
/usr/bin/perl "$HANGUL_NFC" "$TMP/t1" >/dev/null 2>&1
if [ "$(count_nfd "$TMP/t1")" -eq 0 ]; then ok "기본 변환(중첩 포함) 전부 NFC"; else ng "기본 변환 실패"; fi

# [2] idempotent: 재실행 0개 변경
out=$(/usr/bin/perl "$HANGUL_NFC" "$TMP/t1" 2>&1)
if echo "$out" | grep -q "0개 변경"; then ok "idempotent 재실행 0개 변경"; else ng "idempotent 실패: $out"; fi

# [3] dry-run: 변경 없음
make_fixture "$TMP/t3"
/usr/bin/perl "$HANGUL_NFC" --dry-run "$TMP/t3" >/dev/null 2>&1
if [ "$(count_nfd "$TMP/t3")" -eq 3 ]; then ok "dry-run은 실제 변경 안 함"; else ng "dry-run이 파일을 변경함"; fi

# [4] --no-recurse: 지정한 폴더 자신은 NFC로, 그 내부(사진.jpg)는 미처리로 남는다.
#     약한 단언(트리 전체 count>=1)은 옵션이 깨져도 통과하므로, 두 측면을 분리 단언한다.
make_fixture "$TMP/t4"
sub=$(first_entry "$TMP/t4" d)
if [ -z "$sub" ] || [ ! -d "$sub" ]; then
    ng "[4] 픽스처 하위폴더 탐색 실패(빈 경로)"
else
    /usr/bin/perl "$HANGUL_NFC" --no-recurse "$sub" >/dev/null 2>&1
    # 변환 후 하위폴더는 NFC명으로 바뀌므로 부모에서 다시 찾는다.
    subnfc=$(first_entry "$TMP/t4" d)
    inside_nfd=$(count_nfd "$subnfc")
    if is_nfc_base "$subnfc"; then base_ok=1; else base_ok=0; fi
    if [ "$base_ok" -eq 1 ] && [ "$inside_nfd" -eq 1 ]; then
        ok "--no-recurse: 폴더 자신만 NFC, 내부(사진.jpg) 미처리"
    else
        ng "--no-recurse 이상: 폴더basename NFC=$base_ok, 내부 NFD수=$inside_nfd (기대 1,1)"
    fi
fi

# [5] 심볼릭 링크 미추적
mkdir -p "$TMP/t5"
/usr/bin/perl -e '
    use utf8;
    use Unicode::Normalize qw(NFD); use Encode qw(encode_utf8);
    my $b = $ARGV[0];
    my $real = "$b/" . encode_utf8(NFD("실제폴더")); mkdir $real;
    symlink($real, "$b/" . encode_utf8(NFD("링크"))) or die "$!";
' "$TMP/t5"
/usr/bin/perl "$HANGUL_NFC" "$TMP/t5" >/dev/null 2>&1
link_count=$(/usr/bin/perl -e 'my$n=0;opendir(my$d,$ARGV[0]);for(readdir$d){next if/^\.\.?$/;$n++ if -l "$ARGV[0]/$_"}print$n' "$TMP/t5")
if [ "$link_count" -eq 1 ] && [ "$(count_nfd "$TMP/t5")" -eq 0 ]; then ok "심볼릭 링크 미추적 + 이름만 정규화"; else ng "심볼릭 링크 처리 이상"; fi

# [6] 생성된 Quick Action 명령 실행. 리포 루트 산출물을 건드리지 않게 함수 모드로 $TMP에 빌드한다.
# shellcheck source=build-workflow.sh
# 후보를 비워 내장 사본 경로를 확정적으로 검증(개발 머신에 설치본이 있어도 그것을 부르지 않게)
# shellcheck disable=SC2030  # 서브셸 안에서만 비우는 게 의도
( export HANGUL_NFC_CLI_CANDIDATES=""; . "$HERE/build-workflow.sh"; build_workflow_bundle "$TMP/qa.workflow" ) >/dev/null 2>&1
DOC="$TMP/qa.workflow/Contents/document.wflow"
if [ ! -f "$DOC" ]; then
    ng "[6] Quick Action 빌드 실패(document.wflow 없음)"
else
    /usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/qa_cmd.sh" "$DOC"
    make_fixture "$TMP/t6"
    /usr/bin/perl -e '
        my @a; opendir(my $d, $ARGV[1]); for (readdir $d) { next if /^\.\.?$/; push @a, "$ARGV[1]/$_" } closedir $d;
        system("/bin/zsh", $ARGV[0], @a);
    ' "$TMP/qa_cmd.sh" "$TMP/t6"
    if [ "$(count_nfd "$TMP/t6")" -eq 0 ]; then ok "Quick Action 명령 실행 변환 성공"; else ng "Quick Action 명령 변환 실패"; fi
fi

# [7] 종료 코드: 정상 변환은 0, 존재하지 않는 입력은 비0(자동화가 부분 실패를 감지 가능)
make_fixture "$TMP/t7"
/usr/bin/perl "$HANGUL_NFC" "$TMP/t7" >/dev/null 2>&1; rc_ok=$?
/usr/bin/perl "$HANGUL_NFC" "$TMP/없는경로_xyz" >/dev/null 2>&1; rc_missing=$?
if [ "$rc_ok" -eq 0 ] && [ "$rc_missing" -ne 0 ]; then ok "종료 코드: 정상 0 / 실패 비0"; else ng "종료 코드 이상: 정상=$rc_ok 실패=$rc_missing"; fi

# [8] inode 비교가 자기 자신을 충돌로 오인하지 않음 (1.0.0 핵심 버그의 회귀 가드).
#     '진짜 다른 inode가 NFC명을 점유'한 충돌은 APFS 정규화 비구분 특성상 단일 볼륨에서
#     재현 불가하므로, 그 반대(자기 자신 오인으로 전부 건너뛰는 회귀)를 막는다.
make_fixture "$TMP/t8"
err=$(/usr/bin/perl "$HANGUL_NFC" "$TMP/t8" 2>&1 >/dev/null)
if [ "$(count_nfd "$TMP/t8")" -eq 0 ] && ! printf '%s' "$err" | grep -q "건너뜀"; then
    ok "inode 자기오인 없음(전부 변환, 건너뜀 경고 0)"
else
    ng "inode 자기오인 의심(건너뜀 경고: $err)"
fi

# [9] 단문자 옵션 묶음(-nv == -n -v): dry-run+verbose로 동작하되 실제 변경은 없어야 함
make_fixture "$TMP/t9"
out=$(/usr/bin/perl "$HANGUL_NFC" -nv "$TMP/t9" 2>&1)
if echo "$out" | grep -q "미리보기" && [ "$(count_nfd "$TMP/t9")" -eq 3 ]; then ok "-nv 묶음(dry-run+verbose)"; else ng "-nv 묶음 이상: $out"; fi

# [10] 중복 입력은 한 번만 처리(카운트 부풀림·이중 rename 없음)
make_fixture "$TMP/t10"
f=$(first_entry "$TMP/t10" f)
out=$(/usr/bin/perl "$HANGUL_NFC" --no-recurse "$f" "$f" 2>&1)
if echo "$out" | grep -q "1개 변경"; then ok "중복 입력 dedup(1개 변경)"; else ng "중복 입력 dedup 실패: $out"; fi

# [11] --quiet: 요약 출력을 억제(stdout 비움)하되 변환은 정상 수행
make_fixture "$TMP/t11"
qout=$(/usr/bin/perl "$HANGUL_NFC" --quiet "$TMP/t11" 2>/dev/null)
if [ -z "$qout" ] && [ "$(count_nfd "$TMP/t11")" -eq 0 ]; then ok "--quiet: 무출력 + 변환 수행"; else ng "--quiet 이상(out=[$qout])"; fi

# [12] --force: 충돌 검사를 우회해도 일반 변환을 정상 수행하고 건너뜀 경고가 없어야 함.
#      (진짜 다른 inode가 NFC명을 점유한 충돌은 APFS 정규화 비구분 특성상 단일 볼륨에서 재현 불가)
make_fixture "$TMP/t12"
ferr=$(/usr/bin/perl "$HANGUL_NFC" --force "$TMP/t12" 2>&1 >/dev/null)
if [ "$(count_nfd "$TMP/t12")" -eq 0 ] && [ -z "$ferr" ]; then ok "--force: 정상 변환 + 경고 없음"; else ng "--force 이상(err=[$ferr])"; fi

# [13] 셸(zsh glob/탭완성)이 NFC로 정규화한 인자로도 디스크 NFD를 변환 (disk_real_path).
#      셸이 인자를 NFC로 넘기면 인자 basename은 NFC지만 디스크 엔트리는 NFD다.
D13="$TMP/t13"; mkdir -p "$D13"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  open(my$f,">",$ARGV[0]."/".encode_utf8(NFD("계약서.pdf")));close$f;' "$D13"
nfc_arg="$D13/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("계약서.pdf"))')"
/usr/bin/perl "$HANGUL_NFC" "$nfc_arg" >/dev/null 2>&1
if [ "$(count_nfd "$D13")" -eq 0 ]; then ok "NFC 인자(셸 정규화)로도 디스크 NFD 변환"; else ng "disk_real_path 실패(NFC 인자 변환 누락)"; fi

# [14] NFC로 저장된 디스크 파일에 NFD 철자 인자 → 실제 변화 없으므로 '0개 변경'(거짓 카운트 방지)
D14="$TMP/t14"; mkdir -p "$D14"
printf x > "$D14/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("문서.txt"))')"
nfd_arg="$D14/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);print encode_utf8(NFD("문서.txt"))')"
out14=$(/usr/bin/perl "$HANGUL_NFC" "$nfd_arg" 2>&1)
if echo "$out14" | grep -q "0개 변경"; then ok "NFC 디스크 + NFD 인자 → 거짓 카운트 없음"; else ng "거짓 카운트: $out14"; fi

# [15] 같은 디스크 항목을 NFD/NFC 다른 철자로 중복 지정 → 카운트 부풀림·이중 처리 없음
D15="$TMP/t15"; mkdir -p "$D15"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  my$d=$ARGV[0];my$s="$d/".encode_utf8(NFD("폴더"));mkdir $s;
  open(my$f,">","$s/".encode_utf8(NFD("파일.txt")));close$f;' "$D15"
nfc_dir="$D15/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("폴더"))')"
base15=$(/usr/bin/perl "$HANGUL_NFC" -n "$D15" 2>&1 | tail -1)
dup15=$(/usr/bin/perl "$HANGUL_NFC" -n "$D15" "$nfc_dir" 2>&1 | tail -1)
if [ "$base15" = "$dup15" ]; then ok "NFD/NFC 철자 중복 입력 dedup(카운트 안 부풀림)"; else ng "dedup 실패: base=[$base15] dup=[$dup15]"; fi

# [16] 압축 파일의 '내부' 엔트리명은 스코프 밖 — 외부 파일명만 정규화되고 내부·내용은 불변(한계 회귀 가드)
D16="$TMP/t16"; mkdir -p "$D16"
( cd "$D16" || exit
  inner=$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);print encode_utf8(NFD("안.txt"))')
  printf x > "$inner"
  arc=$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);print encode_utf8(NFD("자료.zip"))')
  zip -q "$arc" "$inner" && rm -f "$inner" )
entry_bytes() { /usr/bin/python3 -c '
import zipfile,glob,sys
z=glob.glob(sys.argv[1]+"/*.zip")[0]
i=zipfile.ZipFile(z).infolist()[0]
raw=i.filename.encode("utf-8") if (i.flag_bits & 0x800) else i.filename.encode("cp437")
print(raw.hex())' "$1"; }
before16=$(entry_bytes "$D16"); md5b16=$(md5 -q "$D16"/*.zip)
/usr/bin/perl "$HANGUL_NFC" -q "$D16"
after16=$(entry_bytes "$D16"); md5a16=$(md5 -q "$D16"/*.zip)
if [ "$before16" = "$after16" ] && [ "$md5b16" = "$md5a16" ]; then ok "압축 내부 엔트리명·내용 불변(스코프 밖)"; else ng "압축 내부 변함: name ${before16}→${after16}"; fi

# [17] 호환 한자(U+F914 樂)·기호(U+2126 Ω)는 그대로 두고 분리된 한글 자모만 결합한다.
#      NFC는 이들을 통합 한자(U+6A02)·그리스 문자(U+03A9)로 바꿔 '보이는 글자'를 바꾼다.
D17="$TMP/t17"; mkdir -p "$D17"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  open(my$f,">",$ARGV[0]."/".encode_utf8("\x{F914}\x{2126}".NFD("보고서").".txt"));close$f;' "$D17"
/usr/bin/perl "$HANGUL_NFC" -q "$D17"
cps17=$(/usr/bin/perl -e 'use Encode qw(decode_utf8);opendir(my$d,$ARGV[0]);
  for(grep{!/^\./}readdir$d){print join(" ",map{sprintf"%04X",ord}split//,decode_utf8($_))}' "$D17")
if [ "$cps17" = "F914 2126 BCF4 ACE0 C11C 002E 0074 0078 0074" ]; then ok "호환 한자·기호 보존 + 한글 자모 결합"; else ng "호환 문자 변형/미결합: ${cps17}"; fi

# [18] 파일명을 NFD로 강제 저장하는 볼륨(HFS+)에서는 바꿀 수 없으므로 '변경'으로 세지 않고
#      rename도 시도하지 않는다(헛 rename이 디렉토리 변경 이벤트를 일으켜 watch를 무한 재실행시킴).
HFS_IMG="$TMP/hfs.dmg"; HFS_MNT="$TMP/hfsmnt"; mkdir -p "$HFS_MNT"
if hdiutil create -quiet -size 8m -fs HFS+ -volname nfdtest "$HFS_IMG" >/dev/null 2>&1 \
   && hdiutil attach -quiet -nobrowse -mountpoint "$HFS_MNT" "$HFS_IMG" >/dev/null 2>&1; then
    mknfd_in() { /usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);open(my$f,">",$ARGV[0]."/".encode_utf8(NFD($ARGV[1])));close$f;' "$1" "$2"; }
    mkdir -p "$HFS_MNT/w"; mknfd_in "$HFS_MNT/w" "보고서.hwp"
    mt_b=$(stat -f %m "$HFS_MNT/w"); sleep 1
    out18=$(/usr/bin/perl "$HANGUL_NFC" "$HFS_MNT/w" 2>&1); rc18=$?
    mt_a=$(stat -f %m "$HFS_MNT/w")
    if echo "$out18" | grep -q "완료: 0개 변경" && echo "$out18" | grep -q "NFD" && [ "$rc18" -ne 0 ] && [ "$mt_b" = "$mt_a" ]; then
        ok "NFD 강제 볼륨(HFS+): 거짓 '변경' 없음·rename 미시도·비0 종료"
    else ng "NFD 강제 볼륨 처리 이상: rc=${rc18} mtime ${mt_b}→${mt_a} out=[${out18}]"; fi
    # watch add도 그런 볼륨의 폴더는 거부한다(등록되면 무의미한 재실행만 반복).
    WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH"
    HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$HFS_MNT/w" >/dev/null 2>&1; rcw=$?
    nw=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c "$HFS_MNT")
    if [ "$rcw" -ne 0 ] && [ "$nw" -eq 0 ]; then ok "watch add: NFD 강제 볼륨 폴더 거부"; else ng "watch add가 NFD 강제 볼륨을 등록함: rc=$rcw n=$nw"; fi
    # 형식 목록에 없는 NFD 강제 볼륨(SMB 등) 모사: 형식 목록을 비운 사본은 rename 후 확인으로만 판정한다.
    # 빈 폴더로 등록(add 확인 통과) → 나중에 NFD 유입 → __run이 판정 후 감시에서 빼야 하고,
    # 다음 __run은 rename을 안 해 폴더를 건드리지 않아야 한다(아니면 WatchPaths 무한 재실행).
    NOFT="$TMP/hangul-nfc-noftype"; sed 's/hfs|exfat|msdos/__none__/' "$HANGUL_NFC" > "$NOFT"; chmod +x "$NOFT"
    WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$HFS_MNT/u"
    HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 "$NOFT" watch add "$HFS_MNT/u" >/dev/null 2>&1
    mknfd_in "$HFS_MNT/u" "보고서.hwp"
    HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 "$NOFT" watch __run >/dev/null 2>&1
    nu=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c "$HFS_MNT")
    mu_b=$(stat -f %m "$HFS_MNT/u"); sleep 1
    HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 "$NOFT" watch __run >/dev/null 2>&1
    mu_a=$(stat -f %m "$HFS_MNT/u")
    if [ "$nu" -eq 0 ] && [ "$mu_b" = "$mu_a" ]; then ok "watch __run: 미지 NFD 강제 볼륨 폴더 자동 해제(재실행 루프 차단)"; else ng "미지 NFD 강제 볼륨 루프: 목록=${nu} mtime ${mu_b}→${mu_a}"; fi
    hdiutil detach -quiet "$HFS_MNT" >/dev/null 2>&1
else
    printf '  - HFS+ 이미지 생성/마운트 불가 — [18] 건너뜀\n'
fi

# NFD 파일 만들기(폴더 안) / NFC·NFD 철자 출력
mkfile_nfd() { /usr/bin/perl -e 'use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8 decode_utf8);open(my$f,">",$ARGV[0]."/".encode_utf8(NFD(decode_utf8($ARGV[1])))) or die "$!";close$f;' "$1" "$2"; }
mkdir_nfd() { /usr/bin/perl -e 'use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8 decode_utf8);mkdir($ARGV[0]."/".encode_utf8(NFD(decode_utf8($ARGV[1])))) or die "$!";' "$1" "$2"; }
nfd_of() { /usr/bin/perl -e 'use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8 decode_utf8);print encode_utf8(NFD(decode_utf8($ARGV[0])))' "$1"; }

# [19] 패키지(.app·Info.plist 번들)와 ~/Library는 상위 폴더를 정리할 때 안으로 들어가지 않는다(이름만 정리).
#      ~/Library를 직접 지정하면 정리하고, 패키지를 직접 지정해도 이름만 정리한다.
P19="$TMP/t19"; H19="$P19/home"; mkdir -p "$H19/Library"
mkdir_nfd "$H19/Library" "설정"; mkfile_nfd "$H19/Library/설정" "앱데이터.plist"
mkdir_nfd "$H19" "계산기.app"; mkdir -p "$H19/계산기.app/Contents"; mkfile_nfd "$H19/계산기.app/Contents" "리소스.txt"
mkdir_nfd "$H19" "문서.abc"; mkdir -p "$H19/문서.abc/Contents"; : > "$H19/문서.abc/Contents/Info.plist"; mkfile_nfd "$H19/문서.abc" "속.txt"
mkfile_nfd "$H19" "보통.txt"
out19=$(HOME="$H19" /usr/bin/perl "$HANGUL_NFC" -v "$H19" 2>&1)
lib_left=$(count_nfd "$H19/Library"); app_in=$(count_nfd "$H19/계산기.app"); abc_in=$(count_nfd "$H19/문서.abc")
if is_nfc_base "$(ls -d "$H19"/*.app)" && is_nfc_base "$(ls -d "$H19"/*.abc)" && [ "$app_in" -eq 1 ] && [ "$abc_in" -eq 1 ] && [ "$lib_left" -eq 2 ] \
   && is_nfc_base "$(ls "$H19"/*.txt)" && echo "$out19" | grep -q "패키지 내부는 건드리지 않음" && echo "$out19" | grep -q "Library 내부는 건드리지 않음"; then
    HOME="$H19" /usr/bin/perl "$HANGUL_NFC" -q "$H19/Library"
    mkdir_nfd "$P19" "도구.app"; mkfile_nfd "$P19/도구.app" "안.txt"
    /usr/bin/perl "$HANGUL_NFC" -q "$P19/$(nfd_of 도구.app)"
    if [ "$(count_nfd "$H19/Library")" -eq 0 ] && is_nfc_base "$(ls -d "$P19"/*.app)" && [ "$(count_nfd "$P19/도구.app")" -eq 1 ]; then
        ok "패키지·~/Library 내부는 하위 탐색에서 제외(이름만 정리), 직접 지정한 ~/Library는 정리"
    else ng "직접 지정한 ~/Library·패키지 처리 이상: lib=$(count_nfd "$H19/Library")"; fi
else ng "패키지·~/Library 제외 이상: lib=$lib_left app=$app_in abc=$abc_in out=[$out19]"; fi

# [20] 열 수 없는 폴더·없는 경로도 요약에 나온다(앞머리 '완료: N개 변경'은 watch가 파싱하므로 유지)
D20="$TMP/t20"; mkdir -p "$D20/잠김"; mkfile_nfd "$D20" "자료.txt"; chmod 000 "$D20/잠김"
o20n=$(/usr/bin/perl "$HANGUL_NFC" -n "$D20" "$TMP/없는_20" 2>/dev/null | tail -n 1)
o20=$(/usr/bin/perl "$HANGUL_NFC" "$D20" 2>/dev/null); rc20=$?
chmod 755 "$D20/잠김"
if [ "$o20n" = "미리보기: 1개 변경 예정, 2개 열 수 없음" ] && [ "$o20" = "완료: 1개 변경, 1개 열 수 없음" ] && [ "$rc20" -ne 0 ]; then
    ok "요약: 열 수 없는 폴더·없는 경로 개수 표시(미리보기·실제)"
else ng "열 수 없음 요약 이상: [$o20n] [$o20] rc=$rc20"; fi

# [21] 끝에 슬래시를 붙인 폴더 심링크(link/)는 따라가 대상을 정리하고, 슬래시 없이 주면 링크 이름만 정리한다
D21="$TMP/t21"; mkdir -p "$D21"; mkdir_nfd "$D21" "실제"; mkfile_nfd "$D21/$(nfd_of 실제)" "안.txt"
ln -s "$D21/$(nfd_of 실제)" "$D21/$(nfd_of 링크)"
/usr/bin/perl "$HANGUL_NFC" -q "$D21/$(nfd_of 링크)/"
in21=$(count_nfd "$D21/실제"); link21=$(is_nfc_base "$(find "$D21" -type l)" && echo nfc || echo nfd)
mkfile_nfd "$D21/실제" "둘.txt"
/usr/bin/perl "$HANGUL_NFC" -q "$D21/링크"
in21b=$(count_nfd "$D21/실제"); link21b=$(is_nfc_base "$(find "$D21" -type l)" && echo nfc || echo nfd)
if [ "$in21" -eq 0 ] && [ "$link21" = nfd ] && [ "$in21b" -eq 1 ] && [ "$link21b" = nfc ] && [ -L "$D21/링크" ]; then
    ok "심링크 인자: 'link/'는 대상 폴더 정리, 'link'는 링크 이름만"
else ng "심링크 인자 처리 이상: 슬래시=($in21,$link21) 없음=($in21b,$link21b)"; fi

# [22] 같은 항목을 다르게 적은 인자(T/ T/. ./T \$PWD/T)는 한 번만 센다
D22="$TMP/t22"; mkdir -p "$D22/T"; mkfile_nfd "$D22/T" "문서.txt"
o22=$(cd "$D22" && /usr/bin/perl "$HANGUL_NFC" -n T/ T/. ./T "$D22/T" 2>&1 | tail -n 1)
if [ "$o22" = "미리보기: 1개 변경 예정" ]; then ok "같은 항목의 다른 표기(T/ · T/. · ./T · 절대경로) 중복 처리 없음"; else ng "다른 표기 중복 처리: $o22"; fi

# [23] 같은 폴더의 파일 수천 개를 인자로 줘도 빠르다(예전엔 인자마다 폴더 전체를 읽어 O(n²) — 3000개에 7초)
D23="$TMP/t23"; mkdir -p "$D23"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);for(1..3000){open(my$f,">",$ARGV[0]."/".encode_utf8(NFD("자료$_.txt")))or die;close$f}' "$D23"
now() { /usr/bin/perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
s23=$(now); o23=$(/usr/bin/perl "$HANGUL_NFC" "$D23"/* 2>&1 | tail -n 1); e23=$(now)
secs23=$(/usr/bin/perl -e 'printf "%.2f", $ARGV[1] - $ARGV[0]' "$s23" "$e23")
if [ "$o23" = "완료: 3000개 변경" ] && /usr/bin/perl -e 'exit($ARGV[0] < 3 ? 0 : 1)' "$secs23"; then ok "파일 3000개 인자: ${secs23}초(폴더 목록 캐시)"; else ng "파일 3000개 인자 처리 이상/느림: ${secs23}초 [$o23]"; fi

# [24] 미리보기·-v 출력은 바꾸기 전 이름의 분리된 자모를 호환 자모로 보여 준다(터미널이 NFD를 합쳐 그려 구분이 안 됨)
D24="$TMP/t24"; mkdir -p "$D24"; mkfile_nfd "$D24" "자료.pdf"; mkfile_nfd "$D24" "한글.txt"
o24n=$(/usr/bin/perl "$HANGUL_NFC" -n "$D24" 2>&1)
o24v=$(/usr/bin/perl "$HANGUL_NFC" -v "$D24" 2>&1)
if echo "$o24n" | grep -qxF "[미리보기] $D24/ㅈㅏㄹㅛ.pdf  →  $D24/자료.pdf" && echo "$o24n" | grep -qF "/ㅎㅏㄴㄱㅡㄹ.txt  →  " \
   && echo "$o24v" | grep -qxF "변경: $D24/ㅈㅏㄹㅛ.pdf  →  $D24/자료.pdf" && [ "$(count_nfd "$D24")" -eq 0 ]; then
    ok "미리보기·-v: 바꾸기 전 이름을 호환 자모로 표시(ㅈㅏㄹㅛ.pdf → 자료.pdf)"
else ng "자모 표시 이상: [$o24n] [$o24v]"; fi

# ── watch(자동 감시) 케이스 — HOME=$TMP/home 격리, launchctl은 환경변수로 건너뜀 ──
mknfd_in() { /usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);open(my$f,">",$ARGV[0]."/".encode_utf8(NFD($ARGV[1])));close$f;' "$1" "$2"; }

# [w1] 알 수 없는 watch 하위명령 → usage + 비0
wout=$(HOME="$TMP/home" /usr/bin/perl "$HANGUL_NFC" watch bogus 2>&1); wrc=$?
if echo "$wout" | grep -q "watch" && [ "$wrc" -ne 0 ]; then ok "watch usage(잘못된 하위명령)"; else ng "watch usage 이상: $wout"; fi

# [w2] add → list 절대경로 dedup, remove로 제거
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wf1" "$TMP/wf2"
wa1=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/wf1" "$TMP/wf1" 2>/dev/null)
wa2=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/wf2" 2>/dev/null)
# 첫 등록에만 macOS '백그라운드 활동' 알림을 미리 안내한다.
if echo "$wa1" | grep -q "백그라운드에서 실행될 수 있습니다" && ! echo "$wa2" | grep -q "백그라운드"; then ok "watch add: 첫 등록에만 백그라운드 알림 안내"; else ng "백그라운드 안내 이상: [$wa1] [$wa2]"; fi
n=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c "$TMP/wf")
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch remove "$TMP/wf1" >/dev/null 2>&1
n2=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c "$TMP/wf")
if [ "$n" -eq 2 ] && [ "$n2" -eq 1 ]; then ok "watch add/list/remove 목록 관리"; else ng "watch 목록 이상: n=$n n2=$n2"; fi

# [w3] plist 생성 + plutil 유효성
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wp1"
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/wp1" >/dev/null 2>&1
PL="$WH/Library/LaunchAgents/com.wonjun-lab.hangul-nfc.watch.plist"
if [ -f "$PL" ] && /usr/bin/plutil -lint "$PL" >/dev/null 2>&1 && grep -q "$TMP/wp1" "$PL"; then ok "watch plist 생성·유효성"; else ng "watch plist 이상"; fi
# WatchPaths는 하위 폴더 변경을 못 잡으므로 주기 스윕(StartInterval)으로 보완한다.
if /usr/bin/plutil -extract StartInterval raw "$PL" 2>/dev/null | grep -Eq '^[0-9]+$'; then ok "watch plist 주기 스윕(StartInterval)"; else ng "watch plist에 StartInterval 없음"; fi

# [w3b] Homebrew처럼 심링크로 실행해도 plist엔 심링크 경로가 박혀야 한다.
#       (실체 경로 Cellar/<버전>/…가 박히면 brew upgrade·cleanup 후 감시가 조용히 멈춤)
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wp2" "$TMP/brew/Cellar/1.0/bin" "$TMP/brew/bin"
cp "$HANGUL_NFC" "$TMP/brew/Cellar/1.0/bin/hangul-nfc"; ln -s ../Cellar/1.0/bin/hangul-nfc "$TMP/brew/bin/hangul-nfc"
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 "$TMP/brew/bin/hangul-nfc" watch add "$TMP/wp2" >/dev/null 2>&1
prog=$(/usr/bin/plutil -extract ProgramArguments.0 raw "$PL" 2>/dev/null)
if [ "$prog" = "$TMP/brew/bin/hangul-nfc" ]; then ok "watch plist: 심링크(버전 무관) 경로 유지"; else ng "watch plist 실행 경로가 버전 경로: $prog"; fi

# [w4] on/off 상태 메시지(실제 launchctl은 게이트)
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wo1"
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/wo1" >/dev/null 2>&1
offm=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch off 2>&1)
onm=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch on 2>&1)
if echo "$offm" | grep -q "중지" && echo "$onm" | grep -q "재개"; then ok "watch on/off 상태"; else ng "watch on/off 이상: $offm / $onm"; fi

# [w5] __run이 등록 폴더 전체 정리(add 즉시 1회) + 로그, 재실행 0개(무한루프 가드)
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH"
RA="$TMP/wr1"; RB="$TMP/wr2"; mkdir -p "$RA" "$RB"
mknfd_in "$RA" "보고서.hwp"; mknfd_in "$RB" "사진.jpg"
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$RA" "$RB" >/dev/null 2>&1
left=$(( $(count_nfd "$RA") + $(count_nfd "$RB") ))
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch __run >/dev/null 2>&1
log_ok=$(grep -c "run:" "$WH/Library/Logs/hangul-nfc-watch.log" 2>/dev/null || echo 0)
if [ "$left" -eq 0 ] && [ "${log_ok:-0}" -ge 1 ]; then ok "watch __run 정리 + 로그(무한루프 가드)"; else ng "watch __run 이상: left=$left log=$log_ok"; fi

# [w6] 등록 폴더가 사라져도 __run이 깨지지 않고 살아있는 폴더만 정리
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH"
GA="$TMP/wg1"; GB="$TMP/wg2"; mkdir -p "$GA" "$GB"
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$GA" "$GB" >/dev/null 2>&1
rm -rf "$GB"
mknfd_in "$GA" "새.txt"
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch __run >/dev/null 2>&1; rcrun=$?
if [ "$rcrun" -eq 0 ] && [ "$(count_nfd "$GA")" -eq 0 ]; then ok "watch __run 미존재 폴더 견고성"; else ng "watch __run 견고성 이상: rc=$rcrun"; fi
# 사라진 폴더는 감시에서 자동으로 빼고 기록한다. doctor는 그 전까지 지금 빼는 명령을 함께 보여 준다.
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH"; GC="$TMP/wg3"; GD="$TMP/wg4"; mkdir -p "$GC" "$GD"
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$GC" "$GD" >/dev/null 2>&1
rm -rf "$GD"
dg=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 HANGUL_NFC_NO_NETWORK=1 /usr/bin/perl "$HANGUL_NFC" doctor 2>&1)
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch __run >/dev/null 2>&1
ng6=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c '•')
if echo "$dg" | grep -q "✗ 폴더 없음" && echo "$dg" | grep -q "hangul-nfc watch remove '.*wg4'" && [ "$ng6" -eq 1 ] \
   && grep -q "자동 해제(폴더 없음): .*wg4" "$WH/Library/Logs/hangul-nfc-watch.log" && ! grep -q wg4 "$WH/Library/LaunchAgents/com.wonjun-lab.hangul-nfc.watch.plist"; then
    ok "watch: 사라진 폴더는 __run이 자동 해제·기록(plist 갱신), doctor는 빼는 명령 안내"
else ng "사라진 폴더 처리 이상: 목록=$ng6 doctor=[$dg]"; fi

# [w7] watch off는 plist까지 지워 다음 로그인에 저절로 켜지지 않는다. 목록은 남고 doctor가 켜는 명령을 안내, on이 되살린다.
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wo2"
PLW="$WH/Library/LaunchAgents/com.wonjun-lab.hangul-nfc.watch.plist"
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/wo2" >/dev/null 2>&1
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch off >/dev/null 2>&1
off_pl=$([ -f "$PLW" ] && echo 있음 || echo 없음)
do7=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 HANGUL_NFC_NO_NETWORK=1 /usr/bin/perl "$HANGUL_NFC" doctor 2>&1)
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch on >/dev/null 2>&1
if [ "$off_pl" = 없음 ] && echo "$do7" | grep -q "자동 감시: 중지 · 폴더 1개 → hangul-nfc watch on" && [ -f "$PLW" ] && grep -q "$TMP/wo2" "$PLW"; then
    ok "watch off: plist 제거(재로그인 시 재활성 방지) · doctor '중지 → watch on' · on으로 복구"
else ng "watch off/on 이상: off후 plist=$off_pl doctor=[$do7]"; fi

# [w8] 루트(/)와 데이터 볼륨 펌링크(/System/Volumes/Data/…) 경로로도 보호 폴더를 등록할 수 없다.
#      안전장치: 판정이 깨져도 실제로 /를 정리하지 않게 정리 단계를 가짜로 바꾼 사본으로 실행한다.
STUB="$TMP/hangul-nfc-stubclean"
sed 's/^sub watch_clean_dir {$/sub watch_clean_dir { return "완료: 0개 변경\\n";/' "$HANGUL_NFC" > "$STUB"; chmod +x "$STUB"
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH/Downloads"; RWH=$(cd "$WH" && pwd -P)
if grep -q '^sub watch_clean_dir { return' "$STUB"; then
    e8=$(HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 "$STUB" watch add / 2>&1); r8a=$?
    HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 "$STUB" watch add /System/Volumes/Data >/dev/null 2>&1; r8b=$?
    HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 "$STUB" watch add "/System/Volumes/Data$RWH/Downloads" >/dev/null 2>&1; r8c=$?
    n8=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c '•')
    if [ "$r8a" -ne 0 ] && [ "$r8b" -ne 0 ] && [ "$r8c" -ne 0 ] && [ "$n8" -eq 0 ] && echo "$e8" | grep -q "상위 폴더"; then
        ok "watch add: 루트(/)·/System/Volumes/Data 펌링크 경로의 보호 폴더 거부"
    else ng "루트/펌링크 보호 이상: rc=$r8a/$r8b/$r8c n=$n8"; fi
else ng "[w8] 정리 단계 스텁 생성 실패(watch_clean_dir 정의 형식 변경?)"; fi

# [w9] 같은 폴더의 NFD·NFC 철자는 한 항목, 어느 철자로든 remove 된다. 등록 안 된 폴더 remove·인자 없는 add는 비0.
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/w9"; mkdir_nfd "$TMP/w9" "감시폴더"
W9D="$TMP/w9/$(nfd_of 감시폴더)"; W9C="$TMP/w9/감시폴더"
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$W9D" >/dev/null 2>&1
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$W9C" >/dev/null 2>&1
n9=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c '•')
e9=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch remove "$TMP/wf_none" 2>&1); r9a=$?
HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch remove "$W9D" >/dev/null 2>&1; r9b=$?
n9b=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c '•')
u9=$(HOME="$WH" HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add 2>&1); r9c=$?
if [ "$n9" -eq 1 ] && [ "$r9a" -ne 0 ] && echo "$e9" | grep -q "등록되지 않은 폴더" && [ "$r9b" -eq 0 ] && [ "$n9b" -eq 0 ] \
   && [ "$r9c" -ne 0 ] && echo "$u9" | grep -q "사용법: hangul-nfc watch add"; then
    ok "watch: NFD/NFC 철자 한 항목·어느 철자로든 remove, 미등록 remove·빈 add는 비0"
else ng "watch 목록 정규화 이상: n=${n9}→${n9b} remove미등록=$r9a remove=$r9b 빈add=$r9c"; fi

# [w10] 이름이 공백으로 끝나는 폴더도 감시된다(목록을 읽을 때 끝 공백까지 지우던 문제)
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/w10/끝공백 "
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/w10/끝공백 " >/dev/null 2>&1
mknfd_in "$TMP/w10/끝공백 " "새파일.txt"
HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$HANGUL_NFC" watch __run >/dev/null 2>&1
n10=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c '끝공백 $')
if [ "$(count_nfd "$TMP/w10")" -eq 0 ] && [ "$n10" -eq 1 ]; then ok "watch: 이름이 공백으로 끝나는 폴더 감시"; else ng "끝 공백 폴더 감시 이상: 목록=$n10 NFD=$(count_nfd "$TMP/w10")"; fi

# [w11] 처음 정리를 실행하지 못하면(실행 권한 없음 등) 등록 성공이라 하지 않는다
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/w11/bin" "$TMP/w11/d"
cp "$HANGUL_NFC" "$TMP/w11/bin/hangul-nfc"; chmod 644 "$TMP/w11/bin/hangul-nfc"
e11=$(HOME="$WH" HANGUL_NFC_NO_GUI=1 HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$TMP/w11/bin/hangul-nfc" watch add "$TMP/w11/d" 2>&1); r11=$?
if [ "$r11" -ne 0 ] && echo "$e11" | grep -q "처음 정리를 실행하지 못했습니다" && ! echo "$e11" | grep -q "감시 등록:" \
   && [ ! -f "$WH/Library/LaunchAgents/com.wonjun-lab.hangul-nfc.watch.plist" ]; then
    ok "watch add: 처음 정리 실행 실패 시 등록하지 않고 오류·비0"
else ng "watch add 실행 실패 처리 이상: rc=$r11 [$e11]"; fi

# ── 설치·사용·업데이트 흐름 (HOME 격리, GUI·launchctl·네트워크·외부 명령 차단) ──
export HANGUL_NFC_WATCH_NO_LAUNCHCTL=1 HANGUL_NFC_NO_NETWORK=1 HANGUL_NFC_DRY_EXTERNAL=1
# CLI 후보를 격리 경로로 — 테스트가 /opt/homebrew/bin 등 실제 설치본을 지우거나 부르지 않게
# shellcheck disable=SC2031  # 위 [6]의 서브셸 값과 무관하게 여기서 새로 정한다
export HANGUL_NFC_CLI_CANDIDATES="$TMP/uhome/.local/bin/hangul-nfc:$TMP/ubrew/bin/hangul-nfc"
export HANGUL_NFC_LEGACY_CANDIDATES="$TMP/uhome/.local/bin/nfd2nfc:$TMP/ubrew/bin/nfd2nfc"   # 예전 이름 설치본도 격리

# [u1] 보호 폴더(다운로드·클라우드 저장소)와 그 상위(홈)는 watch 등록 거부 + 대안 안내, 일반 폴더는 등록
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/Downloads" "$WH/Library/CloudStorage/Dropbox" "$TMP/u1ok"
e1=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch add "$WH/Downloads" 2>&1); r1=$?
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch add "$WH/Library/CloudStorage/Dropbox" >/dev/null 2>&1; r2=$?
e3=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch add "$WH" 2>&1); r3=$?
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/u1ok" >/dev/null 2>&1; r4=$?
nl=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c '•')
if [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && [ "$r3" -ne 0 ] && [ "$r4" -eq 0 ] && [ "$nl" -eq 1 ] \
   && echo "$e1" | grep -q "빠른 동작" && echo "$e3" | grep -q "상위 폴더"; then
    ok "watch: macOS 보호 폴더·그 상위는 거부(대안 안내), 일반 폴더는 등록"
else ng "watch 보호 폴더 처리 이상: r=$r1/$r2/$r3/$r4 n=$nl"; fi

# [u2] 예전 버전이 등록해 둔 보호 폴더는 __run이 조용히 실패하지 않고 감시에서 빼고 기록한다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/Downloads" "$TMP/u2ok"
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch add "$TMP/u2ok" >/dev/null 2>&1
( cd "$WH" && pwd -P ) | sed 's|$|/Downloads|' >> "$WH/Library/Application Support/hangul-nfc/folders.list"
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch __run >/dev/null 2>&1
nl=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch list 2>/dev/null | grep -c '•')
if [ "$nl" -eq 1 ] && grep -q "자동 해제" "$WH/Library/Logs/hangul-nfc-watch.log"; then ok "watch __run: 예전에 등록된 보호 폴더 자동 해제·기록"
else ng "보호 폴더 자동 해제 안 됨: n=$nl"; fi

# [u3] setup이 만든 Finder 메뉴는 설치된 CLI를 호출한다 → CLI만 바꿔도(업데이트) 메뉴가 따라온다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/ucli"
cp "$HANGUL_NFC" "$TMP/ucli/hangul-nfc"; chmod +x "$TMP/ucli/hangul-nfc"
HOME="$WH" "$TMP/ucli/hangul-nfc" setup >/dev/null 2>&1; rs=$?
QA="$WH/Library/Services/NFC로 이름 정리.workflow"
printf '#!/bin/sh\n# hangul-nfc-quick-action: v2\necho called > "%s"\n' "$TMP/ucli/marker" > "$TMP/ucli/hangul-nfc"   # '업데이트된' 우리 CLI 흉내(표식 포함)
/usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/u3.sh" "$QA/Contents/document.wflow" 2>/dev/null
HOME="$WH" /bin/zsh "$TMP/u3.sh" "$TMP/ucli" >/dev/null 2>&1
if [ "$rs" -eq 0 ] && /usr/bin/plutil -lint "$QA/Contents/Info.plist" >/dev/null 2>&1 && [ -f "$TMP/ucli/marker" ]; then
    ok "setup: Finder 메뉴 설치 + 메뉴가 설치된 CLI를 호출(업데이트 자동 반영)"
else ng "setup/메뉴 CLI 호출 이상: rc=$rs"; fi

# [u4] doctor: 정상 설치는 0, 예전 방식 메뉴·새 버전은 안내와 함께 비0
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" setup >/dev/null 2>&1
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" doctor >/dev/null 2>&1; d1=$?
d2o=$(HOME="$WH" HANGUL_NFC_LATEST_VERSION=99.0.0 /usr/bin/perl "$HANGUL_NFC" doctor 2>&1); d2=$?
sed -i '' '/hangul-nfc-quick-action: v2/d' "$WH/Library/Services/NFC로 이름 정리.workflow/Contents/document.wflow"
d3o=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" doctor 2>&1); d3=$?
if [ "$d1" -eq 0 ] && [ "$d2" -ne 0 ] && echo "$d2o" | grep -q "hangul-nfc update" && [ "$d3" -ne 0 ] && echo "$d3o" | grep -q "예전 방식"; then
    ok "doctor: 정상 0 · 새 버전/예전 메뉴는 조치 안내 + 비0"
else ng "doctor 이상: $d1/$d2/$d3"; fi

# [u4b] 메뉴는 Finder 대상이어야 '빠른 동작'에 뜬다. 2.0.2 이하 형식(대상 없음)은 doctor가 잡는다.
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" setup >/dev/null 2>&1
QI="$WH/Library/Services/NFC로 이름 정리.workflow/Contents/Info.plist"
ctx=$(/usr/bin/plutil -extract "NSServices.0.NSRequiredContext.NSApplicationIdentifier" raw -o - "$QI" 2>/dev/null)
wctx=$(/usr/bin/plutil -extract "workflowMetaData.serviceApplicationBundleID" raw -o - "${QI%Info.plist}document.wflow" 2>/dev/null)
/usr/bin/plutil -remove "NSServices.0.NSRequiredContext" "$QI"
d4o=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" doctor 2>&1); d4=$?
if [ "$ctx" = "com.apple.finder" ] && [ "$wctx" = "com.apple.finder" ] && [ "$d4" -ne 0 ] && echo "$d4o" | grep -q "빠른 동작"; then
    ok "setup: 메뉴를 Finder 대상으로 생성 · 예전 형식은 doctor가 안내"
else ng "Finder 대상 메뉴 이상: ctx=$ctx wctx=$wctx d4=$d4"; fi

# [u5] update(직접 설치본): 받은 파일을 검증해 교체, 깨진 파일이면 원본 유지
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/.local/bin" "$TMP/uup"
cp "$HANGUL_NFC" "$WH/.local/bin/hangul-nfc"; chmod +x "$WH/.local/bin/hangul-nfc"
# shellcheck disable=SC2016  # sed 식 안의 $VERSION은 perl 변수(셸 확장 아님)
sed 's/^our \$VERSION = ".*";/our $VERSION = "99.0.0";/' "$HANGUL_NFC" > "$TMP/uup/good-99.0.0"
printf '<html>404</html>\n' > "$TMP/uup/bad-99.0.0"
HOME="$WH" HANGUL_NFC_LATEST_VERSION=99.0.0 HANGUL_NFC_UPDATE_URL="file://$TMP/uup/bad-%s" "$WH/.local/bin/hangul-nfc" update >/dev/null 2>&1; ub=$?
vb=$("$WH/.local/bin/hangul-nfc" --version)
HOME="$WH" HANGUL_NFC_LATEST_VERSION=99.0.0 HANGUL_NFC_UPDATE_URL="file://$TMP/uup/good-%s" "$WH/.local/bin/hangul-nfc" update >/dev/null 2>&1; ug=$?
vg=$("$WH/.local/bin/hangul-nfc" --version)
if [ "$ub" -ne 0 ] && [ "$vb" != "hangul-nfc 99.0.0" ] && [ "$ug" -eq 0 ] && [ "$vg" = "hangul-nfc 99.0.0" ]; then
    ok "update: 검증 실패 시 원본 유지, 정상 파일로 교체"
else ng "update 이상: bad rc=$ub ($vb) good rc=$ug ($vg)"; fi

# 가짜 Homebrew: $TMP/ubrew 를 prefix·저장소로 쓰는 brew 스텁. 받은 인자를 brew.log에 적고,
# list는 installed 파일을, uninstall·untap은 Cellar·tap 폴더를 지워 흉내 낸다. 실제 Homebrew는 건드리지 않는다.
# mk_brew <tap에서 설치된 formula 이름...> — hangul-nfc가 있으면 Cellar에 우리 스크립트(2.0.4)를 둔다.
mk_brew() {
    B="$TMP/ubrew"; rm -rf "$B"; mkdir -p "$B/bin" "$B/Library/Taps/wonjun-lab/homebrew-tap"; : > "$B/installed"
    cat > "$B/bin/brew" <<'STUB'
#!/bin/sh
R=$(cd "$(dirname "$0")/.." && pwd)
echo "$*" >> "$R/brew.log"
for last in "$@"; do :; done
case "$1" in
    --prefix|--repository) echo "$R" ;;
    list) cat "$R/installed" ;;
    uninstall) rm -rf "${R:?}/Cellar/$last" "$R/bin/$last"; grep -v "/$last\$" "$R/installed" > "$R/i.tmp"; mv "$R/i.tmp" "$R/installed" ;;
    untap) rm -rf "$R/Library/Taps/wonjun-lab" ;;
esac
STUB
    chmod +x "$B/bin/brew"
    for f in "$@"; do
        echo "wonjun-lab/tap/$f" >> "$B/installed"
        if [ "$f" = hangul-nfc ]; then
            mkdir -p "$B/Cellar/hangul-nfc/2.0.4/bin"
            cp "$HANGUL_NFC" "$B/Cellar/hangul-nfc/2.0.4/bin/hangul-nfc"
            ln -sf ../Cellar/hangul-nfc/2.0.4/bin/hangul-nfc "$B/bin/hangul-nfc"
        fi
    done
}

# [u6] update(Homebrew 설치본): brew upgrade를 부르지 않고(tap이 없어졌다) 한 줄 설치(install.sh)를 받아 실행해 옮긴다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"; mk_brew hangul-nfc
uo=$(HOME="$WH" HANGUL_NFC_BREW="$TMP/ubrew/bin/brew" HANGUL_NFC_LATEST_VERSION=99.0.0 \
     HANGUL_NFC_INSTALL_URL="file://${HANGUL_NFC%/*}/install.sh" "$TMP/ubrew/bin/hangul-nfc" update 2>&1); u6=$?
if [ "$u6" -eq 0 ] && ! grep -q upgrade "$TMP/ubrew/brew.log" 2>/dev/null \
   && echo "$uo" | grep -q "Homebrew 배포는 2.1.0에서 끝났습니다" && echo "$uo" | grep -q "\[실행 예정\] /bin/sh .*/install.sh"; then
    ok "update: Homebrew 설치본은 brew upgrade 대신 한 줄 설치로 이전"
else ng "update Homebrew 이전 이상: rc=$u6 brew=[$(cat "$TMP/ubrew/brew.log" 2>/dev/null)] [$uo]"; fi

# [u6b] doctor: Homebrew 설치본이면 배포 종료와 고칠 명령을 알린다. tap만 남았으면 untap 안내,
#       같은 tap의 다른 formula(codex-swap)가 남아 있으면 untap을 권하지 않는다.
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"; mk_brew hangul-nfc
d6a=$(HOME="$WH" HANGUL_NFC_BREW="$TMP/ubrew/bin/brew" "$TMP/ubrew/bin/hangul-nfc" doctor 2>&1); r6a=$?
mk_brew
d6b=$(HOME="$WH" HANGUL_NFC_BREW="$TMP/ubrew/bin/brew" /usr/bin/perl "$HANGUL_NFC" doctor 2>&1); r6b=$?
mk_brew codex-swap
d6c=$(HOME="$WH" HANGUL_NFC_BREW="$TMP/ubrew/bin/brew" /usr/bin/perl "$HANGUL_NFC" doctor 2>&1)
if [ "$r6a" -ne 0 ] && echo "$d6a" | grep -q "! Homebrew 배포는 2.1.0에서 끝났습니다 → hangul-nfc update" \
   && echo "$d6a" | grep -qF "curl -fsSL https://raw.githubusercontent.com/wonjun-lab/hangul-nfc/main/install.sh | sh" \
   && [ "$r6b" -ne 0 ] && echo "$d6b" | grep -q "→ brew untap wonjun-lab/tap" && ! echo "$d6c" | grep -q "untap"; then
    ok "doctor: Homebrew 설치본은 배포 종료·한 줄 설치 안내, 빈 tap은 untap 안내(다른 formula 있으면 안 함)"
else ng "doctor Homebrew 안내 이상: rc=$r6a/$r6b [$d6a] [$d6b] [$d6c]"; fi

# [u7] uninstall: 메뉴·감시·설정·로그와 표준 위치의 직접 설치 CLI를 지우고, 남의 파일·저장소 사본은 둔다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/.local/bin" "$TMP/u7w"
cp "$HANGUL_NFC" "$WH/.local/bin/hangul-nfc"; chmod +x "$WH/.local/bin/hangul-nfc"
HOME="$WH" "$WH/.local/bin/hangul-nfc" setup >/dev/null 2>&1
HOME="$WH" "$WH/.local/bin/hangul-nfc" watch add "$TMP/u7w" >/dev/null 2>&1
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" uninstall >/dev/null 2>&1; ru=$?
left=$(find "$WH/Library" "$WH/.local/bin" -name '*hangul-nfc*' -o -name 'NFC로 이름 정리.workflow' 2>/dev/null | wc -l | tr -d ' ')
if [ "$ru" -eq 0 ] && [ "$left" -eq 0 ] && [ -f "$HANGUL_NFC" ]; then ok "uninstall: 메뉴·감시·설정·로그·CLI 제거, 저장소 사본은 보존"
else ng "uninstall 잔여물 ${left}개(rc=$ru)"; fi

# [u8] 도움말이 모든 하위 명령을 안내
hout=$(/usr/bin/perl "$HANGUL_NFC" -h 2>&1)
if echo "$hout" | grep -q "setup" && echo "$hout" | grep -q "doctor" && echo "$hout" | grep -q "update" \
   && echo "$hout" | grep -q "uninstall" && echo "$hout" | grep -q "watch"; then ok "도움말: setup·doctor·update·uninstall·watch 안내"
else ng "도움말에 하위 명령 누락"; fi
# [u8b] install.sh는 `curl | sh`(표준입력으로 읽힘)에서도 끝까지 실행되도록 전체가 함수로 감싸여 있어야 한다.
#       (감싸지 않으면 brew가 남은 스크립트를 표준입력에서 먹어 setup이 조용히 빠진다 — 실측)
INST="${HANGUL_NFC%/*}/install.sh"
last_line=$(grep -v "^[[:space:]]*$" "$INST" | tail -n 1)
if [ "$last_line" = 'main "$@"' ] && grep -q "^main() {" "$INST"; then ok "install.sh: curl | sh 안전(전체를 main 함수로 감쌈)"
else ng "install.sh가 main 함수로 감싸여 있지 않음(마지막 줄: $last_line)"; fi

# [u9] 하위 명령의 -h·모르는 인자는 아무것도 하지 않는다(uninstall --help가 실제로 지우면 안 됨)
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" setup >/dev/null 2>&1
QA="$WH/Library/Services/NFC로 이름 정리.workflow"
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" uninstall --help >/dev/null 2>&1; h1=$?
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" uninstall -n >/dev/null 2>&1; h2=$?
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" setup --bogus >/dev/null 2>&1; h3=$?
if [ "$h1" -eq 0 ] && [ "$h2" -ne 0 ] && [ "$h3" -ne 0 ] && [ -d "$QA" ]; then ok "하위 명령 -h·모르는 인자: 사용법만 출력, 아무것도 지우지 않음"
else ng "하위 명령 인자 처리 이상: $h1/$h2/$h3 메뉴=$([ -d "$QA" ] && echo 있음 || echo 지워짐)"; fi

# [u10] quick-action build는 .workflow 번들이 아닌 경로를 지우지 않는다
mkdir -p "$TMP/u10dir" "$TMP/u10fake.workflow"; : > "$TMP/u10dir/keep"; : > "$TMP/u10fake.workflow/keep"
/usr/bin/perl "$HANGUL_NFC" quick-action build "$TMP/u10dir" >/dev/null 2>&1; q1=$?
/usr/bin/perl "$HANGUL_NFC" quick-action build "$TMP/u10fake.workflow" >/dev/null 2>&1; q2=$?
if [ "$q1" -ne 0 ] && [ "$q2" -ne 0 ] && [ -f "$TMP/u10dir/keep" ] && [ -f "$TMP/u10fake.workflow/keep" ]; then ok "quick-action build: 번들 아닌 경로는 거부(삭제 안 함)"
else ng "quick-action build 경로 보호 실패: $q1/$q2"; fi

# [u11] 메뉴는 같은 이름의 다른 프로그램(homebrew/core의 동명 도구 등)을 부르지 않고 내장 사본으로 처리
mkdir -p "$TMP/u11/bin"; printf '#!/bin/sh\necho foreign > "%s"\n' "$TMP/u11/called" > "$TMP/u11/bin/hangul-nfc"; chmod +x "$TMP/u11/bin/hangul-nfc"
( export HANGUL_NFC_CLI_CANDIDATES="$TMP/u11/bin/hangul-nfc"; /usr/bin/perl "$HANGUL_NFC" quick-action build "$TMP/u11/qa.workflow" ) >/dev/null 2>&1
/usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/u11/cmd.sh" "$TMP/u11/qa.workflow/Contents/document.wflow" 2>/dev/null
make_fixture "$TMP/u11/t"
/bin/zsh "$TMP/u11/cmd.sh" "$TMP/u11/t" >/dev/null 2>&1
if [ ! -f "$TMP/u11/called" ] && [ "$(count_nfd "$TMP/u11/t")" -eq 0 ]; then ok "메뉴: 동명의 다른 프로그램은 건너뛰고 내장 사본으로 정리"
else ng "메뉴가 다른 프로그램을 호출했거나 정리 실패"; fi

# [u12] uninstall은 Homebrew로 설치된 동명의 다른 도구를 brew uninstall 하지 않는다
WH="$TMP/uhome"; rm -rf "$WH" "$TMP/ubrew"; mkdir -p "$WH" "$TMP/ubrew/Cellar/hangul-nfc/2.1.0/bin" "$TMP/ubrew/bin"
printf '#!/bin/sh\necho rust-tool\n' > "$TMP/ubrew/Cellar/hangul-nfc/2.1.0/bin/hangul-nfc"; chmod +x "$TMP/ubrew/Cellar/hangul-nfc/2.1.0/bin/hangul-nfc"
ln -sf ../Cellar/hangul-nfc/2.1.0/bin/hangul-nfc "$TMP/ubrew/bin/hangul-nfc"
uo12=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" uninstall 2>&1)
if ! echo "$uo12" | grep -q "Homebrew\|brew uninstall\|실행 예정" &&[ -x "$TMP/ubrew/Cellar/hangul-nfc/2.1.0/bin/hangul-nfc" ]; then ok "uninstall: Homebrew의 동명 다른 도구는 건드리지 않음"
else ng "uninstall이 동명의 다른 도구를 지우려 함: $uo12"; fi

# [u13] 보호 폴더 판정은 대소문자를 가리지 않는다(APFS 기본: ~/downloads == ~/Downloads)
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/Downloads"
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" watch add "$WH/downloads" >/dev/null 2>&1; rc13=$?
if [ "$rc13" -ne 0 ]; then ok "watch: 대소문자만 다른 보호 폴더(~/downloads)도 거부"; else ng "소문자 downloads 가 등록됨"; fi

# [u14] Homebrew 없는 설치(~/.local/bin)는 ~/.zprofile에 표식 블록으로 PATH를 한 번만 더하고, 새 창·전체 경로를 안내한다.
#       doctor·setup은 구체적인 한 줄 명령을 보여 주고, uninstall은 그 블록만 지운다(다른 내용은 보존).
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"; printf 'export FOO=1\n' > "$WH/.zprofile"
d14a=$(HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin /usr/bin/perl "$HANGUL_NFC" doctor 2>&1)
i14a=$(HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh "$INST" --from-source 2>&1); ri14=$?
HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh "$INST" --from-source >/dev/null 2>&1
nb14=$(grep -c '^# >>> hangul-nfc PATH >>>$' "$WH/.zprofile")
# shellcheck disable=SC2016  # 블록에 적힌 그대로($HOME 미확장)를 찾는다
pl14=$(grep -c '^export PATH="$HOME/.local/bin:$PATH"$' "$WH/.zprofile")
d14b=$(HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin "$WH/.local/bin/hangul-nfc" doctor 2>&1)
HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin "$WH/.local/bin/hangul-nfc" uninstall >/dev/null 2>&1
if [ "$ri14" -eq 0 ] && [ "$nb14" -eq 1 ] && [ "$pl14" -eq 1 ] \
   && echo "$i14a" | grep -q "새 터미널 창" && echo "$i14a" | grep -qF "전체 경로로 실행하세요: $WH/.local/bin/hangul-nfc" \
   && echo "$d14a" | grep -qF "echo 'export PATH=" && ! echo "$d14a" | grep -q "setup이 추가 방법을 안내" \
   && echo "$d14b" | grep -qF ".zprofile에 PATH를 추가해 두었습니다" \
   && ! grep -q "hangul-nfc PATH" "$WH/.zprofile" && grep -qx 'export FOO=1' "$WH/.zprofile" && [ ! -e "$WH/.local/bin/hangul-nfc" ]; then
    ok "install.sh: ~/.zprofile PATH 블록(1회)·새 창/전체 경로 안내, doctor 한 줄 명령, uninstall이 블록만 제거"
else ng "PATH 블록 처리 이상: rc=$ri14 블록=$nb14 줄=$pl14 zprofile=[$(cat "$WH/.zprofile")]"; fi

# [u15] Homebrew 설치본(2.0.x) 이전: install.sh가 ~/.local/bin에 설치 → brew uninstall → untap(tap에 남은 게 없을 때)
#       → setup. 그 뒤 Finder 메뉴는 ~/.local/bin CLI를 먼저 부르고, 자동 감시 plist도 그 CLI를 부른다.
WH="$TMP/uhome"; rm -rf "$WH" "$TMP/u15w"; mkdir -p "$WH" "$TMP/u15w"; mk_brew hangul-nfc
HOME="$WH" "$TMP/ubrew/bin/hangul-nfc" setup >/dev/null 2>&1                    # Homebrew CLI가 만든 메뉴·감시(이전 전 상태)
HOME="$WH" "$TMP/ubrew/bin/hangul-nfc" watch add "$TMP/u15w" >/dev/null 2>&1
WP="$WH/Library/LaunchAgents/com.wonjun-lab.hangul-nfc.watch.plist"
p15a=$(/usr/bin/plutil -extract "ProgramArguments.0" raw -o - "$WP" 2>/dev/null)
i15=$(HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin HANGUL_NFC_BREW="$TMP/ubrew/bin/brew" /bin/sh "$INST" 2>&1); r15=$?
p15b=$(/usr/bin/plutil -extract "ProgramArguments.0" raw -o - "$WP" 2>/dev/null)
/usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/u15.sh" \
    "$WH/Library/Services/NFC로 이름 정리.workflow/Contents/document.wflow" 2>/dev/null
# shellcheck disable=SC2016  # 메뉴 스크립트에 적힌 그대로("$HOME" 미확장)를 찾는다
first15=$(grep -m1 '^for c in' "$TMP/u15.sh" | grep -c '^for c in "$HOME"'"'"'/.local/bin/hangul-nfc'"'")
if [ "$r15" -eq 0 ] && [ "$p15a" = "$TMP/ubrew/bin/hangul-nfc" ] && [ "$p15b" = "$WH/.local/bin/hangul-nfc" ] && [ "$first15" -eq 1 ] \
   && grep -qx "uninstall --formula hangul-nfc" "$TMP/ubrew/brew.log" && grep -qx "untap wonjun-lab/tap" "$TMP/ubrew/brew.log" \
   && [ ! -e "$TMP/ubrew/Cellar/hangul-nfc" ] && [ -x "$WH/.local/bin/hangul-nfc" ] \
   && echo "$i15" | grep -q "Homebrew 배포는 2.1.0에서 끝났습니다" && echo "$i15" | grep -q "✓ Homebrew 탭 정리: brew untap wonjun-lab/tap" \
   && echo "$i15" | grep -q "자동 감시가 이 CLI를 부르도록 갱신"; then
    ok "install.sh: Homebrew 설치본 이전(brew uninstall·untap) + 메뉴·자동 감시가 ~/.local/bin CLI를 부름"
else ng "Homebrew 이전 이상: rc=$r15 plist=$p15a→$p15b 메뉴첫후보=$first15 brew=[$(tr '\n' ';' < "$TMP/ubrew/brew.log")] [$i15]"; fi

# [u16] 같은 tap의 다른 formula(codex-swap)가 남아 있으면 untap 하지 않고 정리 명령만 안내한다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"; mk_brew hangul-nfc codex-swap
i16=$(HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin HANGUL_NFC_BREW="$TMP/ubrew/bin/brew" /bin/sh "$INST" 2>&1); r16=$?
if [ "$r16" -eq 0 ] && grep -qx "uninstall --formula hangul-nfc" "$TMP/ubrew/brew.log" && ! grep -q "^untap" "$TMP/ubrew/brew.log" \
   && [ -d "$TMP/ubrew/Library/Taps/wonjun-lab/homebrew-tap" ] \
   && echo "$i16" | grep -qF "brew uninstall codex-swap && brew untap wonjun-lab/tap" && echo "$i16" | grep -q "codex-swap은 자체 curl 설치"; then
    ok "install.sh: tap에 다른 formula(codex-swap)가 있으면 untap 안 함 + 정리 명령 안내"
else ng "codex-swap 남은 tap 처리 이상: rc=$r16 brew=[$(tr '\n' ';' < "$TMP/ubrew/brew.log")] [$i16]"; fi

# [u17] Homebrew 설치본이 없으면 brew uninstall·untap을 부르지 않는다(tap도 없는 일반 Homebrew 사용자)
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"; mk_brew; rm -rf "$TMP/ubrew/Library/Taps"
HOME="$WH" PATH=/usr/bin:/bin:/usr/sbin:/sbin HANGUL_NFC_BREW="$TMP/ubrew/bin/brew" /bin/sh "$INST" >/dev/null 2>&1; r17=$?
if [ "$r17" -eq 0 ] && ! grep -q "^uninstall\|^untap\|^install\|^upgrade" "$TMP/ubrew/brew.log"; then ok "install.sh: Homebrew 설치본이 없으면 brew를 바꾸지 않음"
else ng "Homebrew 없는 이전 이상: rc=$r17 brew=[$(tr '\n' ';' < "$TMP/ubrew/brew.log")]"; fi
# ── 예전 이름(nfd2nfc, 1.x)에서 이전 ──
# 예전 사용자 상태를 격리 HOME에 재현: 예전 에이전트·설정(감시 폴더 3개: 정상·사라짐·보호 위치)·로그·직접 설치 CLI
mk_legacy() {
    WH="$TMP/uhome"; rm -rf "$WH" "$TMP/mig"; mkdir -p "$WH/Library/LaunchAgents" "$WH/Library/Application Support/nfd2nfc" \
        "$WH/Library/Logs" "$WH/.local/bin" "$WH/Downloads" "$TMP/mig/ok"
    printf '<plist/>\n' > "$WH/Library/LaunchAgents/com.wonjun-lab.nfd2nfc.watch.plist"
    ( cd "$TMP/mig/ok" && pwd -P; echo "$TMP/mig/gone"; cd "$WH/Downloads" && pwd -P ) > "$WH/Library/Application Support/nfd2nfc/folders.list"
    echo "[old] run" > "$WH/Library/Logs/nfd2nfc-watch.log"
    printf '#!/usr/bin/perl\n#\n# nfd2nfc — macOS 한글 파일명 자소분리(NFD) → 정상(NFC) 변환기\n' > "$WH/.local/bin/nfd2nfc"
}

# [m1] doctor는 예전 흔적을 알리고(비0), setup은 감시 폴더(옮길 수 있는 것만)를 옮기고 예전 흔적을 모두 치운다
mk_legacy
dm_before=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" doctor 2>&1); db=$?
sm=$(HOME="$WH" /usr/bin/perl "$HANGUL_NFC" setup 2>&1)
moved=$(cat "$WH/Library/Application Support/hangul-nfc/folders.list" 2>/dev/null)
okdir=$(cd "$TMP/mig/ok" && pwd -P)
leftover=$(find "$WH" -name '*nfd2nfc*' 2>/dev/null | wc -l | tr -d ' ')
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" doctor >/dev/null 2>&1; da=$?
if [ "$db" -ne 0 ] && echo "$dm_before" | grep -q "예전 이름(nfd2nfc)" && [ "$moved" = "$okdir" ] && [ "$leftover" -eq 0 ] && [ "$da" -eq 0 ] \
   && [ -d "$WH/Library/Services/NFC로 이름 정리.workflow" ] \
   && [ "$(echo "$sm" | grep -c "자동 감시에서 제외")" -eq 2 ]; then
    ok "이전: doctor가 예전 흔적 안내 → setup이 감시 폴더 이전(유효한 것만)·예전 흔적 정리·메뉴 설치"
else ng "이전 이상: doctor전=$db 후=$da 옮긴목록=[$moved] 잔여=$leftover"; fi

# [m2] uninstall은 예전 이름의 흔적까지 지운다
mk_legacy
HOME="$WH" /usr/bin/perl "$HANGUL_NFC" uninstall >/dev/null 2>&1
leftover=$(find "$WH" -name '*nfd2nfc*' 2>/dev/null | wc -l | tr -d ' ')
if [ "$leftover" -eq 0 ]; then ok "uninstall: 예전 이름(nfd2nfc)의 에이전트·설정·로그·CLI까지 제거"; else ng "uninstall 후 예전 흔적 ${leftover}개"; fi
unset HANGUL_NFC_WATCH_NO_LAUNCHCTL HANGUL_NFC_NO_NETWORK HANGUL_NFC_DRY_EXTERNAL HANGUL_NFC_CLI_CANDIDATES HANGUL_NFC_LEGACY_CANDIDATES

# [버전] --version 출력 형식
ver_out=$(/usr/bin/perl "$HANGUL_NFC" --version 2>&1)
if echo "$ver_out" | grep -Eq '^hangul-nfc [0-9]+\.[0-9]+\.[0-9]+$'; then ok "--version 출력 형식"; else ng "--version 형식 이상: $ver_out"; fi
# -V 단축 일치
v2=$(/usr/bin/perl "$HANGUL_NFC" -V 2>&1)
if [ "$v2" = "$ver_out" ]; then ok "-V 단축 일치"; else ng "-V 불일치: $v2"; fi
# 회귀 방지: 소문자 -v 는 verbose여야 하며 version으로 새면 안 됨
make_fixture "$TMP/tv"
vout=$(/usr/bin/perl "$HANGUL_NFC" -v "$TMP/tv" 2>&1)
if echo "$vout" | grep -q "변경:" && [ "$(count_nfd "$TMP/tv")" -eq 0 ]; then ok "-v 는 verbose(변환 수행)"; else ng "-v 가 verbose로 동작 안 함: $vout"; fi

echo "----"
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]

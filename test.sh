#!/usr/bin/env bash
# test.sh — nfd2nfc 통합 테스트 (macOS/APFS 전용)
# 정규화 비구분 FS 동작에 의존하므로 반드시 macOS에서 실행.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
NFD2NFC="$HERE/nfd2nfc"
PASS=0
FAIL=0

# 테스트 중 osascript(Finder/알림) 부작용·AppleEvent 타임아웃을 차단한다.
# (Quick Action 명령은 항상 --reveal을 포함하므로 이 가드가 없으면 Finder가 튀어나오고
#  헤드리스 CI에서는 AppleEvent가 120초 타임아웃 날 수 있다.)
export NFD2NFC_NO_GUI=1

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

echo "== nfd2nfc 통합 테스트 =="

# [1] 기본 변환: 중첩 포함 전부 NFC
make_fixture "$TMP/t1"
/usr/bin/perl "$NFD2NFC" "$TMP/t1" >/dev/null 2>&1
if [ "$(count_nfd "$TMP/t1")" -eq 0 ]; then ok "기본 변환(중첩 포함) 전부 NFC"; else ng "기본 변환 실패"; fi

# [2] idempotent: 재실행 0개 변경
out=$(/usr/bin/perl "$NFD2NFC" "$TMP/t1" 2>&1)
if echo "$out" | grep -q "0개 변경"; then ok "idempotent 재실행 0개 변경"; else ng "idempotent 실패: $out"; fi

# [3] dry-run: 변경 없음
make_fixture "$TMP/t3"
/usr/bin/perl "$NFD2NFC" --dry-run "$TMP/t3" >/dev/null 2>&1
if [ "$(count_nfd "$TMP/t3")" -eq 3 ]; then ok "dry-run은 실제 변경 안 함"; else ng "dry-run이 파일을 변경함"; fi

# [4] --no-recurse: 지정한 폴더 자신은 NFC로, 그 내부(사진.jpg)는 미처리로 남는다.
#     약한 단언(트리 전체 count>=1)은 옵션이 깨져도 통과하므로, 두 측면을 분리 단언한다.
make_fixture "$TMP/t4"
sub=$(first_entry "$TMP/t4" d)
if [ -z "$sub" ] || [ ! -d "$sub" ]; then
    ng "[4] 픽스처 하위폴더 탐색 실패(빈 경로)"
else
    /usr/bin/perl "$NFD2NFC" --no-recurse "$sub" >/dev/null 2>&1
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
/usr/bin/perl "$NFD2NFC" "$TMP/t5" >/dev/null 2>&1
link_count=$(/usr/bin/perl -e 'my$n=0;opendir(my$d,$ARGV[0]);for(readdir$d){next if/^\.\.?$/;$n++ if -l "$ARGV[0]/$_"}print$n' "$TMP/t5")
if [ "$link_count" -eq 1 ] && [ "$(count_nfd "$TMP/t5")" -eq 0 ]; then ok "심볼릭 링크 미추적 + 이름만 정규화"; else ng "심볼릭 링크 처리 이상"; fi

# [6] 생성된 Quick Action 명령 실행. 리포 루트 산출물을 건드리지 않게 함수 모드로 $TMP에 빌드한다.
# shellcheck source=build-workflow.sh
# 후보를 비워 내장 사본 경로를 확정적으로 검증(개발 머신에 설치본이 있어도 그것을 부르지 않게)
# shellcheck disable=SC2030  # 서브셸 안에서만 비우는 게 의도
( export NFD2NFC_CLI_CANDIDATES=""; . "$HERE/build-workflow.sh"; build_workflow_bundle "$TMP/qa.workflow" ) >/dev/null 2>&1
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
/usr/bin/perl "$NFD2NFC" "$TMP/t7" >/dev/null 2>&1; rc_ok=$?
/usr/bin/perl "$NFD2NFC" "$TMP/없는경로_xyz" >/dev/null 2>&1; rc_missing=$?
if [ "$rc_ok" -eq 0 ] && [ "$rc_missing" -ne 0 ]; then ok "종료 코드: 정상 0 / 실패 비0"; else ng "종료 코드 이상: 정상=$rc_ok 실패=$rc_missing"; fi

# [8] inode 비교가 자기 자신을 충돌로 오인하지 않음 (1.0.0 핵심 버그의 회귀 가드).
#     '진짜 다른 inode가 NFC명을 점유'한 충돌은 APFS 정규화 비구분 특성상 단일 볼륨에서
#     재현 불가하므로, 그 반대(자기 자신 오인으로 전부 건너뛰는 회귀)를 막는다.
make_fixture "$TMP/t8"
err=$(/usr/bin/perl "$NFD2NFC" "$TMP/t8" 2>&1 >/dev/null)
if [ "$(count_nfd "$TMP/t8")" -eq 0 ] && ! printf '%s' "$err" | grep -q "건너뜀"; then
    ok "inode 자기오인 없음(전부 변환, 건너뜀 경고 0)"
else
    ng "inode 자기오인 의심(건너뜀 경고: $err)"
fi

# [9] 단문자 옵션 묶음(-nv == -n -v): dry-run+verbose로 동작하되 실제 변경은 없어야 함
make_fixture "$TMP/t9"
out=$(/usr/bin/perl "$NFD2NFC" -nv "$TMP/t9" 2>&1)
if echo "$out" | grep -q "미리보기" && [ "$(count_nfd "$TMP/t9")" -eq 3 ]; then ok "-nv 묶음(dry-run+verbose)"; else ng "-nv 묶음 이상: $out"; fi

# [10] 중복 입력은 한 번만 처리(카운트 부풀림·이중 rename 없음)
make_fixture "$TMP/t10"
f=$(first_entry "$TMP/t10" f)
out=$(/usr/bin/perl "$NFD2NFC" --no-recurse "$f" "$f" 2>&1)
if echo "$out" | grep -q "1개 변경"; then ok "중복 입력 dedup(1개 변경)"; else ng "중복 입력 dedup 실패: $out"; fi

# [11] --quiet: 요약 출력을 억제(stdout 비움)하되 변환은 정상 수행
make_fixture "$TMP/t11"
qout=$(/usr/bin/perl "$NFD2NFC" --quiet "$TMP/t11" 2>/dev/null)
if [ -z "$qout" ] && [ "$(count_nfd "$TMP/t11")" -eq 0 ]; then ok "--quiet: 무출력 + 변환 수행"; else ng "--quiet 이상(out=[$qout])"; fi

# [12] --force: 충돌 검사를 우회해도 일반 변환을 정상 수행하고 건너뜀 경고가 없어야 함.
#      (진짜 다른 inode가 NFC명을 점유한 충돌은 APFS 정규화 비구분 특성상 단일 볼륨에서 재현 불가)
make_fixture "$TMP/t12"
ferr=$(/usr/bin/perl "$NFD2NFC" --force "$TMP/t12" 2>&1 >/dev/null)
if [ "$(count_nfd "$TMP/t12")" -eq 0 ] && [ -z "$ferr" ]; then ok "--force: 정상 변환 + 경고 없음"; else ng "--force 이상(err=[$ferr])"; fi

# [13] 셸(zsh glob/탭완성)이 NFC로 정규화한 인자로도 디스크 NFD를 변환 (disk_real_path).
#      셸이 인자를 NFC로 넘기면 인자 basename은 NFC지만 디스크 엔트리는 NFD다.
D13="$TMP/t13"; mkdir -p "$D13"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  open(my$f,">",$ARGV[0]."/".encode_utf8(NFD("계약서.pdf")));close$f;' "$D13"
nfc_arg="$D13/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("계약서.pdf"))')"
/usr/bin/perl "$NFD2NFC" "$nfc_arg" >/dev/null 2>&1
if [ "$(count_nfd "$D13")" -eq 0 ]; then ok "NFC 인자(셸 정규화)로도 디스크 NFD 변환"; else ng "disk_real_path 실패(NFC 인자 변환 누락)"; fi

# [14] NFC로 저장된 디스크 파일에 NFD 철자 인자 → 실제 변화 없으므로 '0개 변경'(거짓 카운트 방지)
D14="$TMP/t14"; mkdir -p "$D14"
printf x > "$D14/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("문서.txt"))')"
nfd_arg="$D14/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);print encode_utf8(NFD("문서.txt"))')"
out14=$(/usr/bin/perl "$NFD2NFC" "$nfd_arg" 2>&1)
if echo "$out14" | grep -q "0개 변경"; then ok "NFC 디스크 + NFD 인자 → 거짓 카운트 없음"; else ng "거짓 카운트: $out14"; fi

# [15] 같은 디스크 항목을 NFD/NFC 다른 철자로 중복 지정 → 카운트 부풀림·이중 처리 없음
D15="$TMP/t15"; mkdir -p "$D15"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  my$d=$ARGV[0];my$s="$d/".encode_utf8(NFD("폴더"));mkdir $s;
  open(my$f,">","$s/".encode_utf8(NFD("파일.txt")));close$f;' "$D15"
nfc_dir="$D15/$(/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFC);use Encode qw(encode_utf8);print encode_utf8(NFC("폴더"))')"
base15=$(/usr/bin/perl "$NFD2NFC" -n "$D15" 2>&1 | tail -1)
dup15=$(/usr/bin/perl "$NFD2NFC" -n "$D15" "$nfc_dir" 2>&1 | tail -1)
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
/usr/bin/perl "$NFD2NFC" -q "$D16"
after16=$(entry_bytes "$D16"); md5a16=$(md5 -q "$D16"/*.zip)
if [ "$before16" = "$after16" ] && [ "$md5b16" = "$md5a16" ]; then ok "압축 내부 엔트리명·내용 불변(스코프 밖)"; else ng "압축 내부 변함: name $before16→$after16"; fi

# [17] 호환 한자(U+F914 樂)·기호(U+2126 Ω)는 그대로 두고 분리된 한글 자모만 결합한다.
#      NFC는 이들을 통합 한자(U+6A02)·그리스 문자(U+03A9)로 바꿔 '보이는 글자'를 바꾼다.
D17="$TMP/t17"; mkdir -p "$D17"
/usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);
  open(my$f,">",$ARGV[0]."/".encode_utf8("\x{F914}\x{2126}".NFD("보고서").".txt"));close$f;' "$D17"
/usr/bin/perl "$NFD2NFC" -q "$D17"
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
    out18=$(/usr/bin/perl "$NFD2NFC" "$HFS_MNT/w" 2>&1); rc18=$?
    mt_a=$(stat -f %m "$HFS_MNT/w")
    if echo "$out18" | grep -q "완료: 0개 변경" && echo "$out18" | grep -q "NFD" && [ "$rc18" -ne 0 ] && [ "$mt_b" = "$mt_a" ]; then
        ok "NFD 강제 볼륨(HFS+): 거짓 '변경' 없음·rename 미시도·비0 종료"
    else ng "NFD 강제 볼륨 처리 이상: rc=${rc18} mtime ${mt_b}→${mt_a} out=[${out18}]"; fi
    # watch add도 그런 볼륨의 폴더는 거부한다(등록되면 무의미한 재실행만 반복).
    WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH"
    HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch add "$HFS_MNT/w" >/dev/null 2>&1; rcw=$?
    nw=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch list 2>/dev/null | grep -c "$HFS_MNT")
    if [ "$rcw" -ne 0 ] && [ "$nw" -eq 0 ]; then ok "watch add: NFD 강제 볼륨 폴더 거부"; else ng "watch add가 NFD 강제 볼륨을 등록함: rc=$rcw n=$nw"; fi
    # 형식 목록에 없는 NFD 강제 볼륨(SMB 등) 모사: 형식 목록을 비운 사본은 rename 후 확인으로만 판정한다.
    # 빈 폴더로 등록(add 확인 통과) → 나중에 NFD 유입 → __run이 판정 후 감시에서 빼야 하고,
    # 다음 __run은 rename을 안 해 폴더를 건드리지 않아야 한다(아니면 WatchPaths 무한 재실행).
    NOFT="$TMP/nfd2nfc-noftype"; sed 's/hfs|exfat|msdos/__none__/' "$NFD2NFC" > "$NOFT"; chmod +x "$NOFT"
    WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$HFS_MNT/u"
    HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 "$NOFT" watch add "$HFS_MNT/u" >/dev/null 2>&1
    mknfd_in "$HFS_MNT/u" "보고서.hwp"
    HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 "$NOFT" watch __run >/dev/null 2>&1
    nu=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch list 2>/dev/null | grep -c "$HFS_MNT")
    mu_b=$(stat -f %m "$HFS_MNT/u"); sleep 1
    HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 "$NOFT" watch __run >/dev/null 2>&1
    mu_a=$(stat -f %m "$HFS_MNT/u")
    if [ "$nu" -eq 0 ] && [ "$mu_b" = "$mu_a" ]; then ok "watch __run: 미지 NFD 강제 볼륨 폴더 자동 해제(재실행 루프 차단)"; else ng "미지 NFD 강제 볼륨 루프: 목록=${nu} mtime ${mu_b}→${mu_a}"; fi
    hdiutil detach -quiet "$HFS_MNT" >/dev/null 2>&1
else
    printf '  - HFS+ 이미지 생성/마운트 불가 — [18] 건너뜀\n'
fi

# ── watch(자동 감시) 케이스 — HOME=$TMP/home 격리, launchctl은 환경변수로 건너뜀 ──
mknfd_in() { /usr/bin/perl -e 'use utf8;use Unicode::Normalize qw(NFD);use Encode qw(encode_utf8);open(my$f,">",$ARGV[0]."/".encode_utf8(NFD($ARGV[1])));close$f;' "$1" "$2"; }

# [w1] 알 수 없는 watch 하위명령 → usage + 비0
wout=$(HOME="$TMP/home" /usr/bin/perl "$NFD2NFC" watch bogus 2>&1); wrc=$?
if echo "$wout" | grep -q "watch" && [ "$wrc" -ne 0 ]; then ok "watch usage(잘못된 하위명령)"; else ng "watch usage 이상: $wout"; fi

# [w2] add → list 절대경로 dedup, remove로 제거
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wf1" "$TMP/wf2"
HOME="$WH" NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch add "$TMP/wf1" "$TMP/wf1" "$TMP/wf2" >/dev/null 2>&1
n=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch list 2>/dev/null | grep -c "$TMP/wf")
HOME="$WH" NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch remove "$TMP/wf1" >/dev/null 2>&1
n2=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch list 2>/dev/null | grep -c "$TMP/wf")
if [ "$n" -eq 2 ] && [ "$n2" -eq 1 ]; then ok "watch add/list/remove 목록 관리"; else ng "watch 목록 이상: n=$n n2=$n2"; fi

# [w3] plist 생성 + plutil 유효성
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wp1"
HOME="$WH" NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch add "$TMP/wp1" >/dev/null 2>&1
PL="$WH/Library/LaunchAgents/com.wonjun-lab.nfd2nfc.watch.plist"
if [ -f "$PL" ] && /usr/bin/plutil -lint "$PL" >/dev/null 2>&1 && grep -q "$TMP/wp1" "$PL"; then ok "watch plist 생성·유효성"; else ng "watch plist 이상"; fi
# WatchPaths는 하위 폴더 변경을 못 잡으므로 주기 스윕(StartInterval)으로 보완한다.
if /usr/bin/plutil -extract StartInterval raw "$PL" 2>/dev/null | grep -Eq '^[0-9]+$'; then ok "watch plist 주기 스윕(StartInterval)"; else ng "watch plist에 StartInterval 없음"; fi

# [w3b] Homebrew처럼 심링크로 실행해도 plist엔 심링크 경로가 박혀야 한다.
#       (실체 경로 Cellar/<버전>/…가 박히면 brew upgrade·cleanup 후 감시가 조용히 멈춤)
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wp2" "$TMP/brew/Cellar/1.0/bin" "$TMP/brew/bin"
cp "$NFD2NFC" "$TMP/brew/Cellar/1.0/bin/nfd2nfc"; ln -s ../Cellar/1.0/bin/nfd2nfc "$TMP/brew/bin/nfd2nfc"
HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 "$TMP/brew/bin/nfd2nfc" watch add "$TMP/wp2" >/dev/null 2>&1
prog=$(/usr/bin/plutil -extract ProgramArguments.0 raw "$PL" 2>/dev/null)
if [ "$prog" = "$TMP/brew/bin/nfd2nfc" ]; then ok "watch plist: 심링크(버전 무관) 경로 유지"; else ng "watch plist 실행 경로가 버전 경로: $prog"; fi

# [w4] on/off 상태 메시지(실제 launchctl은 게이트)
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/wo1"
HOME="$WH" NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch add "$TMP/wo1" >/dev/null 2>&1
offm=$(HOME="$WH" NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch off 2>&1)
onm=$(HOME="$WH" NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch on 2>&1)
if echo "$offm" | grep -q "중지" && echo "$onm" | grep -q "재개"; then ok "watch on/off 상태"; else ng "watch on/off 이상: $offm / $onm"; fi

# [w5] __run이 등록 폴더 전체 정리(add 즉시 1회) + 로그, 재실행 0개(무한루프 가드)
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH"
RA="$TMP/wr1"; RB="$TMP/wr2"; mkdir -p "$RA" "$RB"
mknfd_in "$RA" "보고서.hwp"; mknfd_in "$RB" "사진.jpg"
HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch add "$RA" "$RB" >/dev/null 2>&1
left=$(( $(count_nfd "$RA") + $(count_nfd "$RB") ))
HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch __run >/dev/null 2>&1
log_ok=$(grep -c "run:" "$WH/Library/Logs/nfd2nfc-watch.log" 2>/dev/null || echo 0)
if [ "$left" -eq 0 ] && [ "${log_ok:-0}" -ge 1 ]; then ok "watch __run 정리 + 로그(무한루프 가드)"; else ng "watch __run 이상: left=$left log=$log_ok"; fi

# [w6] 등록 폴더가 사라져도 __run이 깨지지 않고 살아있는 폴더만 정리
WH="$TMP/home"; rm -rf "$WH"; mkdir -p "$WH"
GA="$TMP/wg1"; GB="$TMP/wg2"; mkdir -p "$GA" "$GB"
HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch add "$GA" "$GB" >/dev/null 2>&1
rm -rf "$GB"
mknfd_in "$GA" "새.txt"
HOME="$WH" NFD2NFC_NO_GUI=1 NFD2NFC_WATCH_NO_LAUNCHCTL=1 /usr/bin/perl "$NFD2NFC" watch __run >/dev/null 2>&1; rcrun=$?
if [ "$rcrun" -eq 0 ] && [ "$(count_nfd "$GA")" -eq 0 ]; then ok "watch __run 미존재 폴더 견고성"; else ng "watch __run 견고성 이상: rc=$rcrun"; fi

# ── 설치·사용·업데이트 흐름 (HOME 격리, GUI·launchctl·네트워크·외부 명령 차단) ──
export NFD2NFC_WATCH_NO_LAUNCHCTL=1 NFD2NFC_NO_NETWORK=1 NFD2NFC_DRY_EXTERNAL=1
# CLI 후보를 격리 경로로 — 테스트가 /opt/homebrew/bin 등 실제 설치본을 지우거나 부르지 않게
# shellcheck disable=SC2031  # 위 [6]의 서브셸 값과 무관하게 여기서 새로 정한다
export NFD2NFC_CLI_CANDIDATES="$TMP/uhome/.local/bin/nfd2nfc:$TMP/ubrew/bin/nfd2nfc"

# [u1] 보호 폴더(다운로드·클라우드 저장소)와 그 상위(홈)는 watch 등록 거부 + 대안 안내, 일반 폴더는 등록
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/Downloads" "$WH/Library/CloudStorage/Dropbox" "$TMP/u1ok"
e1=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch add "$WH/Downloads" 2>&1); r1=$?
HOME="$WH" /usr/bin/perl "$NFD2NFC" watch add "$WH/Library/CloudStorage/Dropbox" >/dev/null 2>&1; r2=$?
e3=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch add "$WH" 2>&1); r3=$?
HOME="$WH" /usr/bin/perl "$NFD2NFC" watch add "$TMP/u1ok" >/dev/null 2>&1; r4=$?
nl=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch list 2>/dev/null | grep -c '•')
if [ "$r1" -ne 0 ] && [ "$r2" -ne 0 ] && [ "$r3" -ne 0 ] && [ "$r4" -eq 0 ] && [ "$nl" -eq 1 ] \
   && echo "$e1" | grep -q "빠른 동작" && echo "$e3" | grep -q "상위 폴더"; then
    ok "watch: macOS 보호 폴더·그 상위는 거부(대안 안내), 일반 폴더는 등록"
else ng "watch 보호 폴더 처리 이상: r=$r1/$r2/$r3/$r4 n=$nl"; fi

# [u2] 예전 버전이 등록해 둔 보호 폴더는 __run이 조용히 실패하지 않고 감시에서 빼고 기록한다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/Downloads" "$TMP/u2ok"
HOME="$WH" /usr/bin/perl "$NFD2NFC" watch add "$TMP/u2ok" >/dev/null 2>&1
( cd "$WH" && pwd -P ) | sed 's|$|/Downloads|' >> "$WH/Library/Application Support/nfd2nfc/folders.list"
HOME="$WH" /usr/bin/perl "$NFD2NFC" watch __run >/dev/null 2>&1
nl=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" watch list 2>/dev/null | grep -c '•')
if [ "$nl" -eq 1 ] && grep -q "자동 해제" "$WH/Library/Logs/nfd2nfc-watch.log"; then ok "watch __run: 예전에 등록된 보호 폴더 자동 해제·기록"
else ng "보호 폴더 자동 해제 안 됨: n=$nl"; fi

# [u3] setup이 만든 Finder 메뉴는 설치된 CLI를 호출한다 → CLI만 바꿔도(업데이트) 메뉴가 따라온다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/ucli"
cp "$NFD2NFC" "$TMP/ucli/nfd2nfc"; chmod +x "$TMP/ucli/nfd2nfc"
HOME="$WH" "$TMP/ucli/nfd2nfc" setup >/dev/null 2>&1; rs=$?
QA="$WH/Library/Services/NFC로 이름 정리.workflow"
printf '#!/bin/sh\n# nfd2nfc-quick-action: v2\necho called > "%s"\n' "$TMP/ucli/marker" > "$TMP/ucli/nfd2nfc"   # '업데이트된' 우리 CLI 흉내(표식 포함)
/usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/u3.sh" "$QA/Contents/document.wflow" 2>/dev/null
HOME="$WH" /bin/zsh "$TMP/u3.sh" "$TMP/ucli" >/dev/null 2>&1
if [ "$rs" -eq 0 ] && /usr/bin/plutil -lint "$QA/Contents/Info.plist" >/dev/null 2>&1 && [ -f "$TMP/ucli/marker" ]; then
    ok "setup: Finder 메뉴 설치 + 메뉴가 설치된 CLI를 호출(업데이트 자동 반영)"
else ng "setup/메뉴 CLI 호출 이상: rc=$rs"; fi

# [u4] doctor: 정상 설치는 0, 예전 방식 메뉴·새 버전은 안내와 함께 비0
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"
HOME="$WH" /usr/bin/perl "$NFD2NFC" setup >/dev/null 2>&1
HOME="$WH" /usr/bin/perl "$NFD2NFC" doctor >/dev/null 2>&1; d1=$?
d2o=$(HOME="$WH" NFD2NFC_LATEST_VERSION=99.0.0 /usr/bin/perl "$NFD2NFC" doctor 2>&1); d2=$?
sed -i '' '/nfd2nfc-quick-action: v2/d' "$WH/Library/Services/NFC로 이름 정리.workflow/Contents/document.wflow"
d3o=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" doctor 2>&1); d3=$?
if [ "$d1" -eq 0 ] && [ "$d2" -ne 0 ] && echo "$d2o" | grep -q "nfd2nfc update" && [ "$d3" -ne 0 ] && echo "$d3o" | grep -q "예전 방식"; then
    ok "doctor: 정상 0 · 새 버전/예전 메뉴는 조치 안내 + 비0"
else ng "doctor 이상: $d1/$d2/$d3"; fi

# [u5] update(직접 설치본): 받은 파일을 검증해 교체, 깨진 파일이면 원본 유지
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/.local/bin" "$TMP/uup"
cp "$NFD2NFC" "$WH/.local/bin/nfd2nfc"; chmod +x "$WH/.local/bin/nfd2nfc"
# shellcheck disable=SC2016  # sed 식 안의 $VERSION은 perl 변수(셸 확장 아님)
sed 's/^our \$VERSION = ".*";/our $VERSION = "99.0.0";/' "$NFD2NFC" > "$TMP/uup/good-99.0.0"
printf '<html>404</html>\n' > "$TMP/uup/bad-99.0.0"
HOME="$WH" NFD2NFC_LATEST_VERSION=99.0.0 NFD2NFC_UPDATE_URL="file://$TMP/uup/bad-%s" "$WH/.local/bin/nfd2nfc" update >/dev/null 2>&1; ub=$?
vb=$("$WH/.local/bin/nfd2nfc" --version)
HOME="$WH" NFD2NFC_LATEST_VERSION=99.0.0 NFD2NFC_UPDATE_URL="file://$TMP/uup/good-%s" "$WH/.local/bin/nfd2nfc" update >/dev/null 2>&1; ug=$?
vg=$("$WH/.local/bin/nfd2nfc" --version)
if [ "$ub" -ne 0 ] && [ "$vb" != "nfd2nfc 99.0.0" ] && [ "$ug" -eq 0 ] && [ "$vg" = "nfd2nfc 99.0.0" ]; then
    ok "update: 검증 실패 시 원본 유지, 정상 파일로 교체"
else ng "update 이상: bad rc=$ub ($vb) good rc=$ug ($vg)"; fi

# [u6] update(Homebrew 설치본): brew upgrade로 위임
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH" "$TMP/ubrew/Cellar/nfd2nfc/1.0/bin" "$TMP/ubrew/bin"
cp "$NFD2NFC" "$TMP/ubrew/Cellar/nfd2nfc/1.0/bin/nfd2nfc"; ln -sf ../Cellar/nfd2nfc/1.0/bin/nfd2nfc "$TMP/ubrew/bin/nfd2nfc"
uo=$(HOME="$WH" NFD2NFC_LATEST_VERSION=99.0.0 "$TMP/ubrew/bin/nfd2nfc" update 2>&1)
if echo "$uo" | grep -q "upgrade wonjun-lab/tap/nfd2nfc"; then ok "update: Homebrew 설치본은 brew upgrade로 위임"
elif ! command -v brew >/dev/null 2>&1; then printf '  - brew 없음 — [u6] 건너뜀\n'
else ng "update brew 위임 이상: $uo"; fi

# [u7] uninstall: 메뉴·감시·설정·로그와 표준 위치의 직접 설치 CLI를 지우고, 남의 파일·저장소 사본은 둔다
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/.local/bin" "$TMP/u7w"
cp "$NFD2NFC" "$WH/.local/bin/nfd2nfc"; chmod +x "$WH/.local/bin/nfd2nfc"
HOME="$WH" "$WH/.local/bin/nfd2nfc" setup >/dev/null 2>&1
HOME="$WH" "$WH/.local/bin/nfd2nfc" watch add "$TMP/u7w" >/dev/null 2>&1
HOME="$WH" /usr/bin/perl "$NFD2NFC" uninstall >/dev/null 2>&1; ru=$?
left=$(find "$WH/Library" "$WH/.local/bin" -name '*nfd2nfc*' -o -name 'NFC로 이름 정리.workflow' 2>/dev/null | wc -l | tr -d ' ')
if [ "$ru" -eq 0 ] && [ "$left" -eq 0 ] && [ -f "$NFD2NFC" ]; then ok "uninstall: 메뉴·감시·설정·로그·CLI 제거, 저장소 사본은 보존"
else ng "uninstall 잔여물 ${left}개(rc=$ru)"; fi

# [u8] 도움말이 모든 하위 명령을 안내
hout=$(/usr/bin/perl "$NFD2NFC" -h 2>&1)
if echo "$hout" | grep -q "setup" && echo "$hout" | grep -q "doctor" && echo "$hout" | grep -q "update" \
   && echo "$hout" | grep -q "uninstall" && echo "$hout" | grep -q "watch"; then ok "도움말: setup·doctor·update·uninstall·watch 안내"
else ng "도움말에 하위 명령 누락"; fi
# [u8b] install.sh는 `curl | sh`(표준입력으로 읽힘)에서도 끝까지 실행되도록 전체가 함수로 감싸여 있어야 한다.
#       (감싸지 않으면 brew가 남은 스크립트를 표준입력에서 먹어 setup이 조용히 빠진다 — 실측)
INST="${NFD2NFC%/*}/install.sh"
last_line=$(grep -v "^[[:space:]]*$" "$INST" | tail -n 1)
if [ "$last_line" = 'main "$@"' ] && grep -q "^main() {" "$INST"; then ok "install.sh: curl | sh 안전(전체를 main 함수로 감쌈)"
else ng "install.sh가 main 함수로 감싸여 있지 않음(마지막 줄: $last_line)"; fi

# [u9] 하위 명령의 -h·모르는 인자는 아무것도 하지 않는다(uninstall --help가 실제로 지우면 안 됨)
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH"
HOME="$WH" /usr/bin/perl "$NFD2NFC" setup >/dev/null 2>&1
QA="$WH/Library/Services/NFC로 이름 정리.workflow"
HOME="$WH" /usr/bin/perl "$NFD2NFC" uninstall --help >/dev/null 2>&1; h1=$?
HOME="$WH" /usr/bin/perl "$NFD2NFC" uninstall -n >/dev/null 2>&1; h2=$?
HOME="$WH" /usr/bin/perl "$NFD2NFC" setup --bogus >/dev/null 2>&1; h3=$?
if [ "$h1" -eq 0 ] && [ "$h2" -ne 0 ] && [ "$h3" -ne 0 ] && [ -d "$QA" ]; then ok "하위 명령 -h·모르는 인자: 사용법만 출력, 아무것도 지우지 않음"
else ng "하위 명령 인자 처리 이상: $h1/$h2/$h3 메뉴=$([ -d "$QA" ] && echo 있음 || echo 지워짐)"; fi

# [u10] quick-action build는 .workflow 번들이 아닌 경로를 지우지 않는다
mkdir -p "$TMP/u10dir" "$TMP/u10fake.workflow"; : > "$TMP/u10dir/keep"; : > "$TMP/u10fake.workflow/keep"
/usr/bin/perl "$NFD2NFC" quick-action build "$TMP/u10dir" >/dev/null 2>&1; q1=$?
/usr/bin/perl "$NFD2NFC" quick-action build "$TMP/u10fake.workflow" >/dev/null 2>&1; q2=$?
if [ "$q1" -ne 0 ] && [ "$q2" -ne 0 ] && [ -f "$TMP/u10dir/keep" ] && [ -f "$TMP/u10fake.workflow/keep" ]; then ok "quick-action build: 번들 아닌 경로는 거부(삭제 안 함)"
else ng "quick-action build 경로 보호 실패: $q1/$q2"; fi

# [u11] 메뉴는 같은 이름의 다른 프로그램(homebrew/core의 동명 도구 등)을 부르지 않고 내장 사본으로 처리
mkdir -p "$TMP/u11/bin"; printf '#!/bin/sh\necho foreign > "%s"\n' "$TMP/u11/called" > "$TMP/u11/bin/nfd2nfc"; chmod +x "$TMP/u11/bin/nfd2nfc"
( export NFD2NFC_CLI_CANDIDATES="$TMP/u11/bin/nfd2nfc"; /usr/bin/perl "$NFD2NFC" quick-action build "$TMP/u11/qa.workflow" ) >/dev/null 2>&1
/usr/bin/plutil -extract "actions.0.action.ActionParameters.COMMAND_STRING" raw -o "$TMP/u11/cmd.sh" "$TMP/u11/qa.workflow/Contents/document.wflow" 2>/dev/null
make_fixture "$TMP/u11/t"
/bin/zsh "$TMP/u11/cmd.sh" "$TMP/u11/t" >/dev/null 2>&1
if [ ! -f "$TMP/u11/called" ] && [ "$(count_nfd "$TMP/u11/t")" -eq 0 ]; then ok "메뉴: 동명의 다른 프로그램은 건너뛰고 내장 사본으로 정리"
else ng "메뉴가 다른 프로그램을 호출했거나 정리 실패"; fi

# [u12] uninstall은 Homebrew로 설치된 동명의 다른 도구를 brew uninstall 하지 않는다
WH="$TMP/uhome"; rm -rf "$WH" "$TMP/ubrew"; mkdir -p "$WH" "$TMP/ubrew/Cellar/nfd2nfc/2.1.0/bin" "$TMP/ubrew/bin"
printf '#!/bin/sh\necho rust-tool\n' > "$TMP/ubrew/Cellar/nfd2nfc/2.1.0/bin/nfd2nfc"; chmod +x "$TMP/ubrew/Cellar/nfd2nfc/2.1.0/bin/nfd2nfc"
ln -sf ../Cellar/nfd2nfc/2.1.0/bin/nfd2nfc "$TMP/ubrew/bin/nfd2nfc"
uo12=$(HOME="$WH" /usr/bin/perl "$NFD2NFC" uninstall 2>&1)
if ! echo "$uo12" | grep -q "brew\|실행 예정" && [ -x "$TMP/ubrew/Cellar/nfd2nfc/2.1.0/bin/nfd2nfc" ]; then ok "uninstall: Homebrew의 동명 다른 도구는 건드리지 않음"
else ng "uninstall이 동명의 다른 도구를 지우려 함: $uo12"; fi

# [u13] 보호 폴더 판정은 대소문자를 가리지 않는다(APFS 기본: ~/downloads == ~/Downloads)
WH="$TMP/uhome"; rm -rf "$WH"; mkdir -p "$WH/Downloads"
HOME="$WH" /usr/bin/perl "$NFD2NFC" watch add "$WH/downloads" >/dev/null 2>&1; rc13=$?
if [ "$rc13" -ne 0 ]; then ok "watch: 대소문자만 다른 보호 폴더(~/downloads)도 거부"; else ng "소문자 downloads 가 등록됨"; fi
unset NFD2NFC_WATCH_NO_LAUNCHCTL NFD2NFC_NO_NETWORK NFD2NFC_DRY_EXTERNAL NFD2NFC_CLI_CANDIDATES

# [버전] --version 출력 형식
ver_out=$(/usr/bin/perl "$NFD2NFC" --version 2>&1)
if echo "$ver_out" | grep -Eq '^nfd2nfc [0-9]+\.[0-9]+\.[0-9]+$'; then ok "--version 출력 형식"; else ng "--version 형식 이상: $ver_out"; fi
# -V 단축 일치
v2=$(/usr/bin/perl "$NFD2NFC" -V 2>&1)
if [ "$v2" = "$ver_out" ]; then ok "-V 단축 일치"; else ng "-V 불일치: $v2"; fi
# 회귀 방지: 소문자 -v 는 verbose여야 하며 version으로 새면 안 됨
make_fixture "$TMP/tv"
vout=$(/usr/bin/perl "$NFD2NFC" -v "$TMP/tv" 2>&1)
if echo "$vout" | grep -q "변경:" && [ "$(count_nfd "$TMP/tv")" -eq 0 ]; then ok "-v 는 verbose(변환 수행)"; else ng "-v 가 verbose로 동작 안 함: $vout"; fi

echo "----"
echo "통과 $PASS / 실패 $FAIL"
[ "$FAIL" -eq 0 ]

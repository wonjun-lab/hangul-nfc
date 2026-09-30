class HangulNfc < Formula
  desc "Fix macOS NFD Korean filenames by normalizing to NFC"
  homepage "https://github.com/wonjun-lab/hangul-nfc"
  url "https://github.com/wonjun-lab/hangul-nfc/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "a291ac4cb68f2dca532cd57a753ee99a124b7a4a856a3ab411b1d52859c02753"
  license "MIT"

  def install
    bin.install "hangul-nfc"
  end

  def caveats
    <<~EOS
      Finder 우클릭 메뉴(빠른 동작 "NFC로 이름 정리")는 한 번만 실행해 설치하세요:
        hangul-nfc setup
      메뉴는 설치된 CLI를 호출하므로 brew upgrade 하면 함께 최신이 됩니다.

      예전 이름 nfd2nfc에서 옮겨 왔다면 위 setup을 꼭 한 번 실행하세요 —
      메뉴·자동 감시 폴더·설정을 새 이름으로 옮기고 예전 흔적을 정리합니다.

      상태 점검: hangul-nfc doctor
      완전 제거: hangul-nfc uninstall  (메뉴·자동 감시·설정까지 지운 뒤 brew uninstall)
    EOS
  end

  test do
    assert_equal "hangul-nfc #{version}\n", shell_output("#{bin}/hangul-nfc --version")
    # 자모가 분리된(NFD) 이름이 조합형(NFC)으로 바뀌는지 — 디스크의 실제 바이트로 확인
    (testpath/"t").mkpath
    touch testpath/"t"/"\u1107\u1169\u1100\u1169.txt"
    system bin/"hangul-nfc", "-q", testpath/"t"
    assert_equal ["\uBCF4\uACE0.txt"], Dir.children(testpath/"t")
  end
end

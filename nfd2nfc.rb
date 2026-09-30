class Nfd2nfc < Formula
  desc "Fix macOS NFD Korean filenames by normalizing to NFC"
  homepage "https://github.com/wonjun-lab/nfd2nfc"
  url "https://github.com/wonjun-lab/nfd2nfc/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "a291ac4cb68f2dca532cd57a753ee99a124b7a4a856a3ab411b1d52859c02753"
  license "MIT"

  def install
    bin.install "nfd2nfc"
  end

  def caveats
    <<~EOS
      Finder 우클릭 메뉴(빠른 동작 "NFC로 이름 정리")는 한 번만 실행해 설치하세요:
        nfd2nfc setup
      메뉴는 설치된 CLI를 호출하므로 brew upgrade 하면 함께 최신이 됩니다.

      상태 점검: nfd2nfc doctor
      완전 제거: nfd2nfc uninstall  (메뉴·자동 감시·설정까지 지운 뒤 brew uninstall)
    EOS
  end

  test do
    assert_equal "nfd2nfc #{version}\n", shell_output("#{bin}/nfd2nfc --version")
    # 자모가 분리된(NFD) 이름이 조합형(NFC)으로 바뀌는지 — 디스크의 실제 바이트로 확인
    (testpath/"t").mkpath
    touch testpath/"t"/"\u1107\u1169\u1100\u1169.txt"
    system bin/"nfd2nfc", "-q", testpath/"t"
    assert_equal ["\uBCF4\uACE0.txt"], Dir.children(testpath/"t")
  end
end

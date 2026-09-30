class Nfd2nfc < Formula
  desc "Fix macOS NFD Korean filenames by normalizing to NFC"
  homepage "https://github.com/wonjun-lab/nfd2nfc"
  url "https://github.com/wonjun-lab/nfd2nfc/archive/refs/tags/v1.1.1.tar.gz"
  sha256 "0ccb71e48cb4f560c3cb8bdab501491b7c38b0aaefaa7a38b8b914e6d4da05f0"
  license "MIT"

  def install
    bin.install "nfd2nfc"
  end

  def caveats
    <<~EOS
      CLI(`nfd2nfc`)만 설치됩니다.
      Finder 우클릭 메뉴(빠른 동작 "NFC로 이름 정리")가 필요하면
      Releases에서 nfd2nfc-quick-action.zip을 받아 설치하세요:
        https://github.com/wonjun-lab/nfd2nfc/releases/latest
    EOS
  end

  test do
    assert_match "nfd2nfc", shell_output("#{bin}/nfd2nfc --version")
  end
end

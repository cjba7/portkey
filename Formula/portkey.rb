class Portkey < Formula
  desc "System-wide port registry for developers running multiple projects"
  homepage "https://github.com/cjba7/portkey"
  url "https://github.com/cjba7/portkey/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "f58b42bf0a32dd2136c4e8aeebab95c4c5b58d5705947e656f95d58fdeeeba8b"
  license "MIT"

  depends_on "direnv" => :recommended

  def install
    bin.install "bin/portkey"
    lib.install Dir["lib/*"]
  end

  def post_install
    ohai <<~EOS

        ____   ___  ____ _____ _  _________   __
       |  _ \\ / _ \\|  _ \\_   _| |/ / ____\\ \\ / /
       | |_) | | | | |_) || | | ' /|  _|  \\ V /
       |  __/| |_| |  _ < | | | . \\| |___  | |
       |_|    \\___/|_| \\_\\|_| |_|\\_\\_____| |_|

      Run `portkey init` to get started.

    EOS
  end

  test do
    assert_match "portkey #{version}", shell_output("#{bin}/portkey --version")
  end
end

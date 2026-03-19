class Portkey < Formula
  desc "System-wide port registry for developers running multiple projects"
  homepage "https://github.com/cjba7/portkey"
  url "https://github.com/cjba7/portkey/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "e8a01851799fa76d29511ec88143f24c79235a078377cc1957e363b48e2839c3"
  license "MIT"

  depends_on "direnv" => :recommended

  def install
    bin.install "bin/portkey"
    lib.install Dir["lib/*"]
  end

  def post_install
    puts
    puts "  ____   ___  ____ _____ _  _________   __"
    puts " |  _ \\ / _ \\|  _ \\_   _| |/ / ____\\ \\ / /"
    puts " | |_) | | | | |_) || | | ' /|  _|  \\ V /"
    puts " |  __/| |_| |  _ < | | | . \\| |___  | |"
    puts " |_|    \\___/|_| \\_\\|_| |_|\\_\\_____| |_|"
    puts
    puts " Run `portkey init` to get started."
    puts
  end

  test do
    assert_match "portkey #{version}", shell_output("#{bin}/portkey --version")
  end
end

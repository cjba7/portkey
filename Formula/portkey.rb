class Portkey < Formula
  desc "System-wide port registry for developers running multiple projects"
  homepage "https://github.com/cjba7/portkey"
  url "https://github.com/cjba7/portkey/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "9a6bdc65835422a53351381d16f74bbd39b3825614242e5479262a53a602cea1"
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

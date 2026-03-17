# frozen_string_literal: true

require_relative "test_helper"

class PortCheckerTest < Minitest::Test
  SAMPLE_LSOF_OUTPUT = <<~OUTPUT
    COMMAND   PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    ruby    12345   user   10u  IPv4 0x1234567890abcdef      0t0  TCP *:3000 (LISTEN)
    postgres 6789   user    5u  IPv4 0xabcdef1234567890      0t0  TCP 127.0.0.1:5432 (LISTEN)
    redis   11111   user    6u  IPv6 0x1111111111111111      0t0  TCP [::1]:6379 (LISTEN)
  OUTPUT

  def test_parse_lsof_output_extracts_ports
    ports = Portkey::PortChecker.parse_lsof_output(SAMPLE_LSOF_OUTPUT)

    assert_includes ports, 3000
    assert_includes ports, 5432
    assert_includes ports, 6379
    assert_equal 3, ports.size
  end

  def test_parse_lsof_output_handles_empty
    ports = Portkey::PortChecker.parse_lsof_output("")
    assert_empty ports
  end

  def test_parse_lsof_output_handles_header_only
    ports = Portkey::PortChecker.parse_lsof_output(
      "COMMAND   PID   USER   FD   TYPE   DEVICE SIZE/OFF NODE NAME\n"
    )
    assert_empty ports
  end

  def test_parse_lsof_output_handles_malformed_lines
    output = <<~OUTPUT
      COMMAND   PID   USER   FD   TYPE   DEVICE SIZE/OFF NODE NAME
      some garbage line without ports
      ruby    12345   user   10u  IPv4 0x123   0t0  TCP *:8080 (LISTEN)
    OUTPUT

    ports = Portkey::PortChecker.parse_lsof_output(output)
    assert_includes ports, 8080
    assert_equal 1, ports.size
  end

  def test_parse_proc_net_tcp
    # Simulated /proc/net/tcp content
    # Port 3000 = 0BB8, Port 5432 = 1538, State 0A = LISTEN
    content = <<~PROC
        sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode
         0: 00000000:0BB8 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 12345
         1: 0100007F:1538 00000000:0000 0A 00000000:00000000 00:00000000 00000000     0        0 12346
         2: 0100007F:1539 0100007F:0BB8 01 00000000:00000000 00:00000000 00000000     0        0 12347
    PROC

    ports = Portkey::PortChecker.parse_proc_net_tcp(content)
    assert_includes ports, 3000
    assert_includes ports, 5432
    refute_includes ports, 5433  # State 01 = ESTABLISHED, not LISTEN
    assert_equal 2, ports.size
  end

  def test_check_ports_returns_structured_results
    # Stub bound_ports for this test
    Portkey::PortChecker.stub(:bound_ports, Set.new([3000, 5432])) do
      results = Portkey::PortChecker.check_ports([3000, 5432, 6379])

      assert_equal 3, results.size
      assert_equal true, results[0][:bound]
      assert_equal true, results[1][:bound]
      assert_equal false, results[2][:bound]
    end
  end

  def test_port_bound_returns_boolean
    Portkey::PortChecker.stub(:bound_ports, Set.new([3000])) do
      assert Portkey::PortChecker.port_bound?(3000)
      refute Portkey::PortChecker.port_bound?(9999)
    end
  end
end

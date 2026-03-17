# frozen_string_literal: true

require "open3"
require "set"

module Portkey
  module PortChecker
    module_function

    def bound_ports
      output = lsof_output
      if output
        parse_lsof_output(output)
      elsif File.exist?("/proc/net/tcp")
        parse_proc_net_tcp(File.read("/proc/net/tcp"))
      else
        Set.new
      end
    end

    def port_bound?(port)
      bound_ports.include?(port)
    end

    def check_ports(ports)
      currently_bound = bound_ports
      ports.map do |port|
        { port: port, bound: currently_bound.include?(port) }
      end
    end

    def parse_lsof_output(output)
      ports = Set.new
      output.each_line do |line|
        next if line.start_with?("COMMAND")

        # NAME column contains entries like "*:6379" or "127.0.0.1:5432"
        if line =~ /:(\d+)\s/
          ports.add($1.to_i)
        end
      end
      ports
    end

    def parse_proc_net_tcp(content)
      ports = Set.new
      content.each_line do |line|
        next if line.strip.start_with?("sl")

        # Format: "sl local_address ..." where local_address is "HEX_IP:HEX_PORT"
        fields = line.strip.split
        next unless fields[1]

        hex_port = fields[1].split(":").last
        state = fields[3]
        # State 0A = LISTEN
        if state == "0A" && hex_port
          ports.add(hex_port.to_i(16))
        end
      end
      ports
    end

    def lsof_output
      stdout, _status = Open3.capture2("lsof", "-iTCP", "-sTCP:LISTEN", "-P", "-n")
      stdout.empty? ? nil : stdout
    rescue Errno::ENOENT
      nil
    end
  end
end

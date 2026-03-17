# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "portkey"

module TestHelpers
  def with_temp_config
    Dir.mktmpdir("portkey-test") do |dir|
      config_path = File.join(dir, "portkey.yml")
      config = Portkey::Config.new(config_path: config_path)
      yield config, dir
    end
  end

  def with_temp_project_dir
    Dir.mktmpdir("portkey-project") do |dir|
      yield dir
    end
  end

  # A stub for PortChecker that returns a fixed set of bound ports
  class StubPortChecker
    def initialize(bound = [])
      @bound = Set.new(bound)
    end

    def bound_ports
      @bound
    end

    def port_bound?(port)
      @bound.include?(port)
    end
  end
end

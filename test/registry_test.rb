# frozen_string_literal: true

require_relative "test_helper"

class RegistryTest < Minitest::Test
  include TestHelpers

  def test_first_project_gets_base_ports
    with_temp_config do |config, _dir|
      config.save("projects" => {})
      registry = Portkey::Registry.new(config: config, port_checker: StubPortChecker.new)

      ports = registry.assign_ports
      assert_equal 3000, ports["app"]
      assert_equal 5432, ports["postgres"]
      assert_equal 6379, ports["redis"]
    end
  end

  def test_second_project_gets_incremented_ports
    with_temp_config do |config, _dir|
      config.save("projects" => {
        "first" => { "path" => "/tmp/first", "app" => 3000, "postgres" => 5432, "redis" => 6379 }
      })
      registry = Portkey::Registry.new(config: config, port_checker: StubPortChecker.new)

      ports = registry.assign_ports
      assert_equal 3010, ports["app"]
      assert_equal 5442, ports["postgres"]
      assert_equal 6389, ports["redis"]
    end
  end

  def test_third_project_increments_again
    with_temp_config do |config, _dir|
      config.save("projects" => {
        "first" => { "app" => 3000, "postgres" => 5432, "redis" => 6379 },
        "second" => { "app" => 3010, "postgres" => 5442, "redis" => 6389 }
      })
      registry = Portkey::Registry.new(config: config, port_checker: StubPortChecker.new)

      ports = registry.assign_ports
      assert_equal 3020, ports["app"]
      assert_equal 5452, ports["postgres"]
      assert_equal 6399, ports["redis"]
    end
  end

  def test_skips_ports_already_bound
    with_temp_config do |config, _dir|
      config.save("projects" => {})
      # Port 3000 is bound on the system
      checker = StubPortChecker.new([3000])
      registry = Portkey::Registry.new(config: config, port_checker: checker)

      ports = registry.assign_ports
      assert_equal 3010, ports["app"]
      # postgres and redis unaffected since 3000 doesn't conflict with their base
      assert_equal 5432, ports["postgres"]
      assert_equal 6379, ports["redis"]
    end
  end

  def test_skips_both_assigned_and_bound_ports
    with_temp_config do |config, _dir|
      config.save("projects" => {
        "first" => { "app" => 3000, "postgres" => 5432, "redis" => 6379 }
      })
      # Port 3010 is also bound
      checker = StubPortChecker.new([3010])
      registry = Portkey::Registry.new(config: config, port_checker: checker)

      ports = registry.assign_ports
      assert_equal 3020, ports["app"]  # skipped 3000 (assigned) and 3010 (bound)
      assert_equal 5442, ports["postgres"]
      assert_equal 6389, ports["redis"]
    end
  end

  def test_all_assigned_ports_collects_from_all_projects
    with_temp_config do |config, _dir|
      config.save("projects" => {
        "a" => { "path" => "/tmp/a", "app" => 3000, "postgres" => 5432 },
        "b" => { "path" => "/tmp/b", "app" => 3010, "redis" => 6379 }
      })
      registry = Portkey::Registry.new(config: config, port_checker: StubPortChecker.new)

      assigned = registry.all_assigned_ports
      assert_includes assigned, 3000
      assert_includes assigned, 3010
      assert_includes assigned, 5432
      assert_includes assigned, 6379
      refute_includes assigned, "/tmp/a"  # paths excluded
    end
  end

  def test_conflicts_detects_duplicate_ports
    with_temp_config do |config, _dir|
      config.save("projects" => {
        "a" => { "app" => 3000 },
        "b" => { "app" => 3000 }
      })
      registry = Portkey::Registry.new(config: config, port_checker: StubPortChecker.new)

      conflicts = registry.conflicts
      assert_equal 1, conflicts.size
      assert_equal "b", conflicts[0][:project]
      assert_equal 3000, conflicts[0][:port]
    end
  end

  def test_conflicts_empty_when_no_duplicates
    with_temp_config do |config, _dir|
      config.save("projects" => {
        "a" => { "app" => 3000 },
        "b" => { "app" => 3010 }
      })
      registry = Portkey::Registry.new(config: config, port_checker: StubPortChecker.new)

      assert_empty registry.conflicts
    end
  end
end

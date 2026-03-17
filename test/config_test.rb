# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  include TestHelpers

  def test_load_returns_empty_projects_when_file_missing
    with_temp_config do |config, _dir|
      data = config.load
      assert_equal({ "projects" => {} }, data)
    end
  end

  def test_load_reads_valid_yaml
    with_temp_config do |config, _dir|
      File.write(config.config_path, <<~YAML)
        projects:
          myapp:
            path: ~/code/myapp
            app: 3000
            postgres: 5432
      YAML

      data = config.load
      assert_equal 3000, data["projects"]["myapp"]["app"]
      assert_equal 5432, data["projects"]["myapp"]["postgres"]
    end
  end

  def test_load_raises_on_malformed_yaml
    with_temp_config do |config, _dir|
      File.write(config.config_path, "{{invalid yaml")

      assert_raises(Portkey::Error) { config.load }
    end
  end

  def test_load_raises_on_non_hash_root
    with_temp_config do |config, _dir|
      File.write(config.config_path, "- just\n- a\n- list\n")

      assert_raises(Portkey::Error) { config.load }
    end
  end

  def test_load_raises_on_non_hash_projects
    with_temp_config do |config, _dir|
      File.write(config.config_path, "projects:\n  - not a hash\n")

      assert_raises(Portkey::Error) { config.load }
    end
  end

  def test_save_and_load_roundtrip
    with_temp_config do |config, _dir|
      data = {
        "projects" => {
          "myapp" => { "path" => "~/code/myapp", "app" => 3000 }
        }
      }
      config.save(data)
      loaded = config.load
      assert_equal data, loaded
    end
  end

  def test_projects_returns_project_hash
    with_temp_config do |config, _dir|
      config.save("projects" => { "foo" => { "app" => 3000 } })
      assert_equal({ "foo" => { "app" => 3000 } }, config.projects)
    end
  end

  def test_project_returns_single_project
    with_temp_config do |config, _dir|
      config.save("projects" => { "foo" => { "app" => 3000 } })
      assert_equal({ "app" => 3000 }, config.project("foo"))
    end
  end

  def test_project_returns_nil_for_unknown
    with_temp_config do |config, _dir|
      config.save("projects" => {})
      assert_nil config.project("nonexistent")
    end
  end

  def test_add_project_persists
    with_temp_config do |config, _dir|
      config.save("projects" => {})
      config.add_project("myapp", { "path" => "/tmp", "app" => 3000 })

      loaded = config.load
      assert_equal 3000, loaded["projects"]["myapp"]["app"]
    end
  end

  def test_add_project_does_not_overwrite_existing
    with_temp_config do |config, _dir|
      config.save("projects" => { "myapp" => { "app" => 3000 } })

      assert_raises(Portkey::Error) do
        config.add_project("myapp", { "app" => 9999 })
      end

      # Original value preserved
      assert_equal 3000, config.project("myapp")["app"]
    end
  end

  def test_remove_project
    with_temp_config do |config, _dir|
      config.save("projects" => { "myapp" => { "app" => 3000 } })
      config.remove_project("myapp")

      assert_empty config.projects
    end
  end

  def test_remove_nonexistent_project_raises
    with_temp_config do |config, _dir|
      config.save("projects" => {})

      assert_raises(Portkey::Error) do
        config.remove_project("ghost")
      end
    end
  end

  def test_init_config_creates_file_with_default_mode
    with_temp_config do |config, _dir|
      config.init_config
      assert File.exist?(config.config_path)
      content = File.read(config.config_path)
      assert_includes content, "projects:"
      assert_includes content, "mode: envrc"
      assert_includes content, "# Example:"
    end
  end

  def test_init_config_with_dotenv_mode
    with_temp_config do |config, _dir|
      config.init_config(mode: "dotenv")
      content = File.read(config.config_path)
      assert_includes content, "mode: dotenv"
    end
  end

  def test_init_config_with_both_mode
    with_temp_config do |config, _dir|
      config.init_config(mode: "both")
      content = File.read(config.config_path)
      assert_includes content, "mode: both"
    end
  end

  def test_init_config_rejects_invalid_mode
    with_temp_config do |config, _dir|
      assert_raises(Portkey::Error) { config.init_config(mode: "invalid") }
    end
  end

  def test_init_config_raises_if_exists
    with_temp_config do |config, _dir|
      File.write(config.config_path, "projects: {}")

      assert_raises(Portkey::Error) { config.init_config }
    end
  end

  def test_mode_defaults_to_envrc
    with_temp_config do |config, _dir|
      config.save("projects" => {})
      assert_equal "envrc", config.mode
    end
  end

  def test_mode_reads_from_config
    with_temp_config do |config, _dir|
      config.save("mode" => "dotenv", "projects" => {})
      assert_equal "dotenv", config.mode
    end
  end

  def test_mode_defaults_on_invalid_value
    with_temp_config do |config, _dir|
      config.save("mode" => "garbage", "projects" => {})
      assert_equal "envrc", config.mode
    end
  end
end

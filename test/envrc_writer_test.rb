# frozen_string_literal: true

require_relative "test_helper"

class EnvrcWriterTest < Minitest::Test
  include TestHelpers

  # env_key mapping

  def test_env_key_uses_uppercased_name
    assert_equal "APP_PORT", Portkey::EnvrcWriter.env_key("app")
    assert_equal "POSTGRES_PORT", Portkey::EnvrcWriter.env_key("postgres")
    assert_equal "REDIS_PORT", Portkey::EnvrcWriter.env_key("redis")
    assert_equal "MEMCACHED_PORT", Portkey::EnvrcWriter.env_key("memcached")
    assert_equal "OTHER_PORT", Portkey::EnvrcWriter.env_key("other")
  end

  # merge_content

  def test_merge_replaces_existing_key
    existing = "export APP_PORT=9999\nexport OTHER=hello\n"
    entries = { "APP_PORT" => "export APP_PORT=3000" }

    result = Portkey::EnvrcWriter.merge_content(existing, entries, export: true)

    assert_includes result, "export APP_PORT=3000"
    assert_includes result, "export OTHER=hello"
    refute_includes result, "9999"
  end

  def test_merge_appends_new_key
    existing = "export OTHER=hello\n"
    entries = { "APP_PORT" => "export APP_PORT=3000" }

    result = Portkey::EnvrcWriter.merge_content(existing, entries, export: true)

    assert_includes result, "export OTHER=hello"
    assert_includes result, "export APP_PORT=3000"
  end

  def test_merge_replaces_and_appends
    existing = "export APP_PORT=9999\n"
    entries = {
      "APP_PORT" => "export APP_PORT=3000",
      "DB_PORT" => "export DB_PORT=5432"
    }

    result = Portkey::EnvrcWriter.merge_content(existing, entries, export: true)

    assert_includes result, "export APP_PORT=3000"
    assert_includes result, "export DB_PORT=5432"
    refute_includes result, "9999"
  end

  def test_merge_handles_empty_file
    entries = { "APP_PORT" => "export APP_PORT=3000" }
    result = Portkey::EnvrcWriter.merge_content("", entries, export: true)

    assert_includes result, "export APP_PORT=3000"
  end

  def test_merge_dotenv_format
    existing = "APP_PORT=9999\nOTHER=hello\n"
    entries = { "APP_PORT" => "APP_PORT=3000" }

    result = Portkey::EnvrcWriter.merge_content(existing, entries, export: false)

    assert_includes result, "APP_PORT=3000"
    assert_includes result, "OTHER=hello"
    refute_includes result, "9999"
  end

  def test_merge_no_duplicate_keys
    existing = "export APP_PORT=9999\nexport DB_PORT=5432\n"
    entries = {
      "APP_PORT" => "export APP_PORT=3000",
      "DB_PORT" => "export DB_PORT=5442"
    }

    result = Portkey::EnvrcWriter.merge_content(existing, entries, export: true)

    assert_equal 1, result.scan("APP_PORT").count
    assert_equal 1, result.scan("DB_PORT").count
  end

  # write preserves existing content

  def test_write_preserves_existing_content
    with_temp_project_dir do |dir|
      envrc_path = File.join(dir, ".envrc")
      File.write(envrc_path, "export MY_CUSTOM_VAR=hello\n")

      data = { "path" => dir, "app" => 3000 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      content = File.read(envrc_path)
      assert_includes content, "export MY_CUSTOM_VAR=hello"
      assert_includes content, "export APP_PORT=3000"
    end
  end

  def test_write_replaces_existing_port_key
    with_temp_project_dir do |dir|
      envrc_path = File.join(dir, ".envrc")
      File.write(envrc_path, "export APP_PORT=9999\nexport MY_VAR=keep\n")

      data = { "path" => dir, "app" => 3000 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      content = File.read(envrc_path)
      assert_includes content, "export APP_PORT=3000"
      assert_includes content, "export MY_VAR=keep"
      refute_includes content, "9999"
    end
  end

  def test_write_updates_on_reapply
    with_temp_project_dir do |dir|
      data = { "path" => dir, "app" => 3000 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      data = { "path" => dir, "app" => 3010, "redis" => 6389 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      content = File.read(File.join(dir, ".envrc"))
      assert_includes content, "export APP_PORT=3010"
      assert_includes content, "export REDIS_PORT=6389"
      refute_includes content, "3000"
      assert_equal 1, content.scan("APP_PORT").count
    end
  end

  # write with modes

  def test_write_envrc_mode_creates_envrc_file
    with_temp_project_dir do |dir|
      data = { "path" => dir, "app" => 3000, "postgres" => 5432 }
      written = Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      assert_equal [File.join(dir, ".envrc")], written
      assert File.exist?(File.join(dir, ".envrc"))
      refute File.exist?(File.join(dir, ".env"))
    end
  end

  def test_write_dotenv_mode_creates_env_file
    with_temp_project_dir do |dir|
      data = { "path" => dir, "app" => 3000 }
      written = Portkey::EnvrcWriter.write("testapp", data, mode: "dotenv", run_direnv: false)

      assert_equal [File.join(dir, ".env")], written
      assert File.exist?(File.join(dir, ".env"))
      refute File.exist?(File.join(dir, ".envrc"))

      content = File.read(File.join(dir, ".env"))
      assert_includes content, "APP_PORT=3000"
      refute_includes content, "export "
    end
  end

  def test_write_both_mode_creates_both_files
    with_temp_project_dir do |dir|
      data = { "path" => dir, "app" => 3000 }
      written = Portkey::EnvrcWriter.write("testapp", data, mode: "both", run_direnv: false)

      assert_equal 2, written.size
      assert File.exist?(File.join(dir, ".envrc"))
      assert File.exist?(File.join(dir, ".env"))
    end
  end

  def test_write_raises_if_no_path
    assert_raises(Portkey::Error) do
      Portkey::EnvrcWriter.write("testapp", { "app" => 3000 }, run_direnv: false)
    end
  end

  def test_write_raises_if_directory_missing
    assert_raises(Portkey::Error) do
      Portkey::EnvrcWriter.write("testapp", { "path" => "/nonexistent/path", "app" => 3000 }, run_direnv: false)
    end
  end

  def test_direnv_allow_failure_does_not_crash
    with_temp_project_dir do |dir|
      data = { "path" => dir, "app" => 3000 }
      written = Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: true)
      assert File.exist?(written.first)
    end
  end
end

# frozen_string_literal: true

require_relative "test_helper"

class EnvrcWriterTest < Minitest::Test
  include TestHelpers

  # env_key mapping

  def test_env_key_postgres_maps_to_db_port
    assert_equal "DB_PORT", Portkey::EnvrcWriter.env_key("postgres")
  end

  def test_env_key_postgresql_maps_to_db_port
    assert_equal "DB_PORT", Portkey::EnvrcWriter.env_key("postgresql")
  end

  def test_env_key_app_maps_to_app_port
    assert_equal "APP_PORT", Portkey::EnvrcWriter.env_key("app")
  end

  def test_env_key_redis_maps_to_redis_port
    assert_equal "REDIS_PORT", Portkey::EnvrcWriter.env_key("redis")
  end

  def test_env_key_custom_service
    assert_equal "MEMCACHED_PORT", Portkey::EnvrcWriter.env_key("memcached")
    assert_equal "OTHER_PORT", Portkey::EnvrcWriter.env_key("other")
  end

  # generate_block

  def test_generate_block_envrc_format
    data = { "path" => "/tmp", "app" => 3000, "postgres" => 5432 }
    block = Portkey::EnvrcWriter.generate_block("myapp", data, export: true)

    assert_includes block, "# BEGIN portkey"
    assert_includes block, "# END portkey"
    assert_includes block, "export APP_PORT=3000"
    assert_includes block, "export DB_PORT=5432"
    assert_includes block, "# Project: myapp"
  end

  def test_generate_block_dotenv_format
    data = { "path" => "/tmp", "app" => 3000, "postgres" => 5432 }
    block = Portkey::EnvrcWriter.generate_block("myapp", data, export: false)

    assert_includes block, "APP_PORT=3000"
    assert_includes block, "DB_PORT=5432"
    refute_includes block, "export "
  end

  def test_generate_block_skips_path_key
    data = { "path" => "/tmp/myapp", "app" => 3000 }
    block = Portkey::EnvrcWriter.generate_block("myapp", data, export: true)

    refute_includes block, "/tmp/myapp"
    refute_includes block, "export PATH"
  end

  # key deduplication

  def test_generate_block_deduplicates_keys
    data = { "path" => "/tmp", "postgres" => 5432, "pg" => 9999 }
    block = Portkey::EnvrcWriter.generate_block("myapp", data, export: true)

    assert_includes block, "export DB_PORT=5432"
    refute_includes block, "9999"
    assert_equal 1, block.scan("DB_PORT").count
  end

  # merge_into_file — preserves existing content

  def test_write_preserves_existing_content_in_envrc
    with_temp_project_dir do |dir|
      envrc_path = File.join(dir, ".envrc")
      File.write(envrc_path, "export MY_CUSTOM_VAR=hello\nexport ANOTHER=world\n")

      data = { "path" => dir, "app" => 3000 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      content = File.read(envrc_path)
      assert_includes content, "export MY_CUSTOM_VAR=hello"
      assert_includes content, "export ANOTHER=world"
      assert_includes content, "export APP_PORT=3000"
      assert_includes content, "# BEGIN portkey"
      assert_includes content, "# END portkey"
    end
  end

  def test_write_preserves_existing_content_in_dotenv
    with_temp_project_dir do |dir|
      env_path = File.join(dir, ".env")
      File.write(env_path, "MY_CUSTOM_VAR=hello\n")

      data = { "path" => dir, "app" => 3000 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "dotenv", run_direnv: false)

      content = File.read(env_path)
      assert_includes content, "MY_CUSTOM_VAR=hello"
      assert_includes content, "APP_PORT=3000"
    end
  end

  def test_write_replaces_existing_portkey_block
    with_temp_project_dir do |dir|
      envrc_path = File.join(dir, ".envrc")
      File.write(envrc_path, <<~ENVRC)
        export MY_VAR=keep
        # BEGIN portkey
        # Project: testapp — managed by portkey, do not edit
        export APP_PORT=9999
        # END portkey
        export OTHER_VAR=also_keep
      ENVRC

      data = { "path" => dir, "app" => 3000, "redis" => 6379 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      content = File.read(envrc_path)
      assert_includes content, "export MY_VAR=keep"
      assert_includes content, "export OTHER_VAR=also_keep"
      assert_includes content, "export APP_PORT=3000"
      assert_includes content, "export REDIS_PORT=6379"
      refute_includes content, "9999"
      assert_equal 1, content.scan("# BEGIN portkey").count
    end
  end

  def test_write_updates_portkey_block_on_reapply
    with_temp_project_dir do |dir|
      data = { "path" => dir, "app" => 3000 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      # Re-apply with different ports
      data = { "path" => dir, "app" => 3010, "redis" => 6389 }
      Portkey::EnvrcWriter.write("testapp", data, mode: "envrc", run_direnv: false)

      content = File.read(File.join(dir, ".envrc"))
      assert_includes content, "export APP_PORT=3010"
      assert_includes content, "export REDIS_PORT=6389"
      refute_includes content, "3000"
      assert_equal 1, content.scan("# BEGIN portkey").count
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

      content = File.read(File.join(dir, ".envrc"))
      assert_includes content, "export APP_PORT=3000"
    end
  end

  def test_write_dotenv_mode_creates_env_file
    with_temp_project_dir do |dir|
      data = { "path" => dir, "app" => 3000, "postgres" => 5432 }
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

      envrc = File.read(File.join(dir, ".envrc"))
      dotenv = File.read(File.join(dir, ".env"))
      assert_includes envrc, "export APP_PORT=3000"
      assert_includes dotenv, "APP_PORT=3000"
      refute_includes dotenv, "export "
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

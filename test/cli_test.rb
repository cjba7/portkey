# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "json"

class CLITest < Minitest::Test
  include TestHelpers

  Result = Struct.new(:stdout, :stderr, :exit_status)

  def with_cli_env
    Dir.mktmpdir("portkey-cli") do |home|
      @config_path = File.join(home, "portkey.yml")
      yield home
    end
  end

  def make_dir(home, name)
    dir = File.join(home, name)
    FileUtils.mkdir_p(dir)
    dir
  end

  # Run the CLI against the temp config, optionally chdir'd into `dir` and fed
  # `stdin`. Captures stdout/stderr and exit status.
  def run_cli(args, dir: nil, stdin: "")
    out = StringIO.new
    err = StringIO.new
    cli = Portkey::CLI.new(
      args,
      config_path: @config_path,
      stdout: out,
      stderr: err,
      stdin: StringIO.new(stdin)
    )
    status = 0
    begin
      if dir
        Dir.chdir(dir) { cli.run }
      else
        cli.run
      end
    rescue SystemExit => e
      status = e.status
    end
    Result.new(out.string, err.string, status)
  end

  def config
    Portkey::Config.new(config_path: @config_path)
  end

  # add

  def test_add_auto_assigns_colour
    with_cli_env do |home|
      project = make_dir(home, "project")
      res = run_cli(["add", "myapp", "--services", "app"], dir: project)

      assert_equal 0, res.exit_status
      assert Portkey::Colours.valid?(config.project("myapp")["colour"])
      assert_match(/colour\s+#/, res.stdout)
    end
  end

  def test_add_honours_colour_flag
    with_cli_env do |home|
      project = make_dir(home, "project")
      res = run_cli(["add", "myapp", "--services", "app", "--colour", "#10B981"], dir: project)

      assert_equal 0, res.exit_status
      assert_equal "#10b981", config.project("myapp")["colour"]
    end
  end

  def test_add_rejects_invalid_colour_flag
    with_cli_env do |home|
      project = make_dir(home, "project")
      res = run_cli(["add", "myapp", "--colour", "banana"], dir: project)

      assert_equal 1, res.exit_status
      assert_match(/--colour/, res.stderr)
      assert_nil config.project("myapp")
    end
  end

  def test_add_avoids_reusing_a_colour
    with_cli_env do |home|
      run_cli(["add", "alpha", "--services", "app"], dir: make_dir(home, "a"))
      run_cli(["add", "beta", "--services", "app"], dir: make_dir(home, "b"))

      refute_equal config.project("alpha")["colour"], config.project("beta")["colour"]
    end
  end

  def test_list_shows_colour
    with_cli_env do |home|
      project = make_dir(home, "project")
      run_cli(["add", "myapp", "--services", "app", "--colour", "#4f46e5"], dir: project)

      assert_match(/colour\s+#4f46e5/, run_cli(["list"]).stdout)
    end
  end

  # colours

  def test_colours_lists_all_projects
    with_cli_env do |home|
      run_cli(["add", "alpha", "--services", "app", "--colour", "#4f46e5"], dir: make_dir(home, "a"))
      res = run_cli(["colours"])

      assert_equal 0, res.exit_status
      assert_match(/alpha\s+#4f46e5/, res.stdout)
    end
  end

  def test_colours_shows_one_project
    with_cli_env do |home|
      run_cli(["add", "alpha", "--services", "app", "--colour", "#4f46e5"], dir: make_dir(home, "a"))

      assert_match(/alpha: #4f46e5/, run_cli(["colours", "alpha"]).stdout)
    end
  end

  def test_colours_sets_a_project_colour
    with_cli_env do |home|
      run_cli(["add", "alpha", "--services", "app"], dir: make_dir(home, "a"))
      res = run_cli(["colours", "alpha", "#EF4444"])

      assert_equal 0, res.exit_status
      assert_match(/Set alpha colour to #ef4444/, res.stdout)
      assert_equal "#ef4444", config.project("alpha")["colour"]
    end
  end

  def test_colours_rejects_invalid_colour
    with_cli_env do |home|
      run_cli(["add", "alpha", "--services", "app"], dir: make_dir(home, "a"))
      res = run_cli(["colours", "alpha", "notacolour"])

      assert_equal 1, res.exit_status
      assert_match(/Invalid colour/, res.stderr)
    end
  end

  def test_colours_unknown_project
    with_cli_env do |_home|
      res = run_cli(["colours", "ghost", "#ef4444"])

      assert_equal 1, res.exit_status
      assert_match(/not found/, res.stderr)
    end
  end

  # resolve

  def test_resolve_prints_rgb_and_label_for_match
    with_cli_env do |home|
      project = make_dir(home, "project")
      run_cli(["add", "myapp", "--services", "app", "--colour", "#4f46e5"], dir: project)

      res = run_cli(["resolve", project])
      assert_equal "79 70 229 project", res.stdout.strip
    end
  end

  def test_resolve_prints_nothing_for_no_match
    with_cli_env do |home|
      make_dir(home, "project")
      run_cli(["add", "myapp", "--services", "app"], dir: make_dir(home, "project"))

      assert_equal "", run_cli(["resolve", "/nowhere/else"]).stdout.strip
    end
  end

  # statusline

  def test_statusline_renders_badge_and_dir
    with_cli_env do |home|
      project = make_dir(home, "project")
      run_cli(["add", "myapp", "--services", "app", "--colour", "#4f46e5"], dir: project)

      json = JSON.generate(
        "workspace" => { "current_dir" => project },
        "model" => { "display_name" => "Opus 4.8" },
        "context_window" => { "used_percentage" => 42.7 }
      )
      res = run_cli(["statusline"], stdin: json)
      visible = res.stdout.gsub(/\e\[[0-9;]*m/, "")

      assert_includes res.stdout, "48;2;79;70;229" # truecolour badge background
      assert_includes visible, "project"
      assert_includes visible, "Opus 4.8"
      assert_includes visible, "43%"
    end
  end

  def test_statusline_survives_garbage_input
    with_cli_env do |_home|
      res = run_cli(["statusline"], stdin: "not json")
      assert_equal 0, res.exit_status
    end
  end

  # shell-init

  def test_shell_init_prints_zsh_hook
    with_cli_env do |_home|
      res = run_cli(["shell-init", "zsh"])
      assert_includes res.stdout, "add-zsh-hook chpwd"
      assert_includes res.stdout, "portkey resolve"
    end
  end

  def test_shell_init_prints_bash_hook
    with_cli_env do |_home|
      res = run_cli(["shell-init", "bash"])
      assert_includes res.stdout, "PROMPT_COMMAND"
    end
  end

  def test_shell_init_rejects_unknown_shell
    with_cli_env do |_home|
      res = run_cli(["shell-init", "fish"])
      assert_equal 1, res.exit_status
    end
  end

  # setup

  def test_setup_wires_rc_and_statusline
    with_cli_env do |home|
      with_home(home) do
        File.write(File.join(home, ".zshrc"), "# existing\n")
        res = run_cli(["setup", "zsh"])

        assert_equal 0, res.exit_status

        rc = File.read(File.join(home, ".zshrc"))
        assert_includes rc, "# existing"
        assert_includes rc, Portkey::CLI::SETUP_BEGIN
        assert_includes rc, "command -v portkey" # guarded so an old/missing portkey can't break startup
        assert_includes rc, "portkey shell-init zsh"

        settings = JSON.parse(File.read(File.join(home, ".claude", "settings.json")))
        assert_equal "portkey statusline", settings.dig("statusLine", "command")
      end
    end
  end

  def test_setup_is_idempotent
    with_cli_env do |home|
      with_home(home) do
        run_cli(["setup", "zsh"])
        first = File.read(File.join(home, ".zshrc"))
        run_cli(["setup", "zsh"])
        second = File.read(File.join(home, ".zshrc"))

        assert_equal first, second
        assert_equal 1, second.scan(Portkey::CLI::SETUP_BEGIN).count
      end
    end
  end

  def test_setup_preserves_other_settings_keys
    with_cli_env do |home|
      with_home(home) do
        FileUtils.mkdir_p(File.join(home, ".claude"))
        File.write(File.join(home, ".claude", "settings.json"), JSON.generate("theme" => "dark"))
        run_cli(["setup", "zsh"])

        settings = JSON.parse(File.read(File.join(home, ".claude", "settings.json")))
        assert_equal "dark", settings["theme"]
        assert_equal "portkey statusline", settings.dig("statusLine", "command")
      end
    end
  end

  def test_setup_errors_on_invalid_settings_json
    with_cli_env do |home|
      with_home(home) do
        FileUtils.mkdir_p(File.join(home, ".claude"))
        File.write(File.join(home, ".claude", "settings.json"), "{not json")
        res = run_cli(["setup", "zsh"])

        assert_equal 1, res.exit_status
        assert_match(/not valid JSON/, res.stderr)
      end
    end
  end

  # remove

  def test_remove_deletes_project
    with_cli_env do |home|
      run_cli(["add", "alpha", "--services", "app"], dir: make_dir(home, "a"))
      res = run_cli(["remove", "alpha"])

      assert_equal 0, res.exit_status
      assert_nil config.project("alpha")
    end
  end

  private

  def with_home(home)
    original = ENV["HOME"]
    ENV["HOME"] = home
    yield
  ensure
    ENV["HOME"] = original
  end
end

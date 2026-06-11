# frozen_string_literal: true

require "optparse"
require "json"
require "fileutils"

module Portkey
  class CLI
    SETUP_BEGIN = "# >>> portkey >>>"
    SETUP_END = "# <<< portkey <<<"

    def initialize(argv, config_path: nil, stdout: $stdout, stderr: $stderr, stdin: $stdin)
      @argv = argv.dup
      @config_path = config_path
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
    end

    def run
      command = @argv.shift

      case command
      when "init"        then cmd_init
      when "list"        then cmd_list
      when "add"         then cmd_add
      when "remove"      then cmd_remove
      when "apply"       then cmd_apply
      when "show"        then cmd_show
      when "check"       then cmd_check
      when "status"      then cmd_status
      when "colours"     then cmd_colours
      when "resolve"     then cmd_resolve
      when "statusline"  then cmd_statusline
      when "shell-init"  then cmd_shell_init
      when "setup"       then cmd_setup
      when "doctor"      then cmd_doctor
      when "--version", "-v"
        @stdout.puts "portkey #{Portkey::VERSION}"
      when "--help", "-h", nil
        print_help
      else
        @stderr.puts "Unknown command: #{command}"
        print_help
        exit 1
      end
    rescue Portkey::Error => e
      @stderr.puts "Error: #{e.message}"
      exit 1
    end

    private

    def config
      @config ||= if @config_path
        Config.new(config_path: @config_path)
      else
        Config.new
      end
    end

    def cmd_init
      @stdout.puts "Select output mode:"
      @stdout.puts "  1. dotenv — write .env files (default)"
      @stdout.puts "  2. envrc  — write .envrc files for direnv"
      @stdout.puts "  3. both   — write both .envrc and .env files"
      @stdout.print "Choice [1]: "

      choice = @stdin.gets&.strip
      mode = case choice
      when "2", "envrc" then "envrc"
      when "3", "both"  then "both"
      else "dotenv"
      end

      config.init_config(mode: mode)
      @stdout.puts "Created #{config.config_path} (mode: #{mode})"
      @stdout.puts "Edit this file to add your projects, or run `portkey add <name>`."
      @stdout.puts "Run `portkey setup` to enable per-project tab colours and the Claude Code badge."
    end

    def cmd_list
      projects = config.projects
      if projects.empty?
        @stdout.puts "No projects registered. Run `portkey add <name>` to get started."
        return
      end

      projects.each do |name, data|
        @stdout.puts name
        data.each do |key, value|
          next if Portkey::RESERVED_KEYS.include?(key)
          @stdout.puts "  #{key.ljust(12)} #{value}"
        end
        path = data["path"]
        @stdout.puts "  #{"path".ljust(12)} #{path}" if path
        @stdout.puts "  #{"mode".ljust(12)} #{config.mode_for(name)}"
        colour = data["colour"]
        @stdout.puts "  #{"colour".ljust(12)} #{colour}" if colour
        @stdout.puts ""
      end
    end

    def cmd_add
      name = @argv.shift
      unless name
        @stderr.puts "Usage: portkey add <name> [--services app,postgres,redis,...] [--colour #hex]"
        exit 1
      end

      services = nil
      if (idx = @argv.index("--services"))
        services = @argv[idx + 1]&.split(",")&.map(&:strip)
        unless services && !services.empty?
          @stderr.puts "Usage: --services app,postgres,redis,..."
          exit 1
        end
      end

      colour = nil
      if (idx = @argv.index("--colour"))
        colour = Colours.normalise(@argv[idx + 1])
        unless colour
          @stderr.puts "Usage: --colour #hex (e.g. --colour #4f46e5)"
          exit 1
        end
      end
      colour ||= Colours.assign(name, taken: assigned_colours)

      registry = Registry.new(config: config)
      ports = if services
        registry.assign_ports(services: services)
      else
        registry.assign_ports
      end
      attrs = { "path" => Dir.pwd, "colour" => colour }.merge(ports)

      config.add_project(name, attrs)
      @stdout.puts "Added project '#{name}':"
      ports.each do |service, port|
        @stdout.puts "  #{service.ljust(12)} #{port}"
      end
      @stdout.puts "  #{"colour".ljust(12)} #{colour}"

      written = EnvrcWriter.write(name, config.project(name), mode: config.mode_for(name))
      written.each { |p| @stdout.puts "Wrote #{p}" }
    end

    def cmd_remove
      name = @argv.shift
      unless name
        @stderr.puts "Usage: portkey remove <name>"
        exit 1
      end

      config.remove_project(name)
      @stdout.puts "Removed project '#{name}'"
    end

    def cmd_show
      name = @argv.shift
      unless name
        @stderr.puts "Usage: portkey show <name> [--export]"
        exit 1
      end

      data = config.project(name)
      unless data
        raise Portkey::Error, "Project '#{name}' not found"
      end

      export = @argv.include?("--export")
      entries = EnvrcWriter.port_entries(data, export: export)
      entries.each_value { |line| @stdout.puts line }
    end

    def cmd_apply
      if @argv.include?("--all")
        projects = config.projects
        if projects.empty?
          @stdout.puts "No projects registered."
          return
        end

        projects.each do |name, data|
          written = EnvrcWriter.write(name, data, mode: config.mode_for(name))
          written.each { |p| @stdout.puts "Wrote #{p}" }
        end
      else
        name = @argv.shift
        unless name
          @stderr.puts "Usage: portkey apply <name> or portkey apply --all"
          exit 1
        end

        data = config.project(name)
        unless data
          raise Portkey::Error, "Project '#{name}' not found"
        end

        written = EnvrcWriter.write(name, data, mode: config.mode_for(name))
        written.each { |p| @stdout.puts "Wrote #{p}" }
      end
    end

    def cmd_check
      projects = config.projects
      if projects.empty?
        @stdout.puts "No projects registered."
        return
      end

      registry = Registry.new(config: config)
      port_conflicts = registry.conflicts
      bound = PortChecker.bound_ports

      has_issues = false

      unless port_conflicts.empty?
        has_issues = true
        @stdout.puts "Port conflicts between projects:"
        port_conflicts.each do |c|
          @stdout.puts "  Port #{c[:port]}: #{c[:project]}/#{c[:service]} conflicts with #{c[:conflict_with]}"
        end
        @stdout.puts ""
      end

      projects.each do |name, data|
        data.each do |key, value|
          next if Portkey::RESERVED_KEYS.include?(key)
          next unless value.is_a?(Integer)

          if bound.include?(value)
            has_issues = true
            @stdout.puts "  #{name}/#{key} port #{value} is currently in use"
          end
        end
      end

      if has_issues
        exit 2
      else
        @stdout.puts "No port conflicts found."
      end
    end

    def cmd_status
      projects = config.projects
      if projects.empty?
        @stdout.puts "No projects registered."
        return
      end

      bound = PortChecker.bound_ports
      tty = @stdout.respond_to?(:tty?) && @stdout.tty?

      projects.each do |name, data|
        @stdout.puts name
        data.each do |key, value|
          next if Portkey::RESERVED_KEYS.include?(key)
          next unless value.is_a?(Integer)

          in_use = bound.include?(value)
          status = if tty
            in_use ? "\e[31min use\e[0m" : "\e[32mfree\e[0m"
          else
            in_use ? "in use" : "free"
          end

          @stdout.puts "  #{key.ljust(12)} #{value.to_s.ljust(8)} #{status}"
        end
        @stdout.puts ""
      end
    end

    # Manage per-project colours. With no arguments, lists every project's
    # colour. With a name, shows it; with a name and value, sets it.
    def cmd_colours
      name = @argv.shift

      unless name
        projects = config.projects
        if projects.empty?
          @stdout.puts "No projects registered."
          return
        end
        projects.each do |n, data|
          next unless data.is_a?(Hash)
          @stdout.puts "  #{n.ljust(16)} #{data["colour"] || "(none)"}"
        end
        return
      end

      new_colour = @argv.shift
      unless new_colour
        data = config.project(name)
        raise Portkey::Error, "Project '#{name}' not found" unless data

        current = data["colour"]
        @stdout.puts(current ? "#{name}: #{current}" : "#{name}: (no colour set)")
        return
      end

      normalised = Colours.normalise(new_colour)
      unless normalised
        raise Portkey::Error, "Invalid colour '#{new_colour}'. Use hex like #4f46e5."
      end

      config.set_project_value(name, "colour", normalised)
      @stdout.puts "Set #{name} colour to #{normalised}"
    end

    # Print the colour for a directory (default: cwd) as "R G B label", or
    # nothing if no project matches. Used by the shell hook and status line.
    def cmd_resolve
      dir = @argv.shift || Dir.pwd
      match = Colours.resolve(dir, config.projects)
      return unless match

      rgb, label = match
      @stdout.puts "#{rgb.join(" ")} #{label}"
    end

    # Render the Claude Code status line: a colour badge for the matched
    # project, the current directory, model, and context usage. Reads the
    # session JSON on stdin. Never raises — a broken status line is worse than
    # a plain one.
    def cmd_statusline
      data = begin
        JSON.parse(@stdin.read)
      rescue StandardError
        {}
      end

      cwd = data.dig("workspace", "current_dir") || data["cwd"]
      cwd = Dir.pwd if cwd.nil? || cwd.empty?
      model = data.dig("model", "display_name")
      ctx = data.dig("context_window", "used_percentage")

      match = Colours.resolve(cwd, config.projects)

      esc = "\e"
      reset = "#{esc}[0m"
      dim = "#{esc}[2m"
      bold = "#{esc}[1m"

      out = +""
      if match
        (r, g, b), label = match
        out << "#{esc}[48;2;#{r};#{g};#{b}m#{esc}[38;2;255;255;255m #{label} #{reset} "
      end
      out << "#{bold}#{File.basename(cwd)}#{reset}"
      out << "  #{dim}·#{reset}  #{model}" if model && !model.empty?
      out << "  #{dim}·#{reset}  #{ctx.round}%" if ctx.is_a?(Numeric)

      @stdout.print out
    rescue StandardError
      # Last-resort guard: emit nothing rather than break the status line.
    end

    # Print shell code that tints the iTerm2 tab on every directory change by
    # calling `portkey resolve`. Intended for `eval "$(portkey shell-init zsh)"`.
    def cmd_shell_init
      shell = @argv.shift || "zsh"
      case shell
      when "zsh"  then @stdout.puts ZSH_INIT
      when "bash" then @stdout.puts BASH_INIT
      else
        @stderr.puts "Usage: portkey shell-init [zsh|bash]"
        exit 1
      end
    end

    # Wire the shell hook and the Claude Code status line into the user's
    # environment, idempotently and with backups.
    def cmd_setup
      shell = @argv.find { |a| !a.start_with?("-") }
      shell = File.basename(ENV["SHELL"].to_s) unless %w[zsh bash].include?(shell)
      shell = "zsh" unless %w[zsh bash].include?(shell)

      setup_shell(shell)
      setup_statusline

      @stdout.puts ""
      @stdout.puts "Done. Restart your shell (or `source` your rc) to start colouring tabs."
      @stdout.puts "Assign colours with `portkey add <name>` or `portkey colours <name> <#hex>`."
    end

    def cmd_doctor
      projects = config.projects
      issues = []

      unless File.exist?(config.config_path)
        issues << "Config file not found at #{config.config_path}. Run `portkey init`."
        issues.each { |i| @stdout.puts "  #{i}" }
        exit 1
      end

      needs_direnv = projects.any? { |name, _| %w[envrc both].include?(config.mode_for(name)) }
      if needs_direnv
        direnv_found = system("which direnv > /dev/null 2>&1")
        issues << "direnv not found in PATH (needed for envrc/both mode)" unless direnv_found
      end

      projects.each do |name, data|
        path = data["path"]
        unless path
          issues << "#{name}: no path defined"
          next
        end

        expanded = File.expand_path(path)
        unless Dir.exist?(expanded)
          issues << "#{name}: directory not found at #{expanded}"
          next
        end

        mode = config.mode_for(name)
        expected_entries = EnvrcWriter.port_entries(data, export: true)

        if %w[envrc both].include?(mode)
          envrc_path = File.join(expanded, ".envrc")
          if File.exist?(envrc_path)
            content = File.read(envrc_path)
            expected_entries.each do |key, line|
              unless content.include?(line)
                issues << "#{name}: .envrc is out of date (#{key} mismatch). Run `portkey apply #{name}`."
                break
              end
            end
          else
            issues << "#{name}: .envrc not found. Run `portkey apply #{name}`."
          end
        end

        if %w[dotenv both].include?(mode)
          env_path = File.join(expanded, ".env")
          dotenv_entries = EnvrcWriter.port_entries(data, export: false)
          if File.exist?(env_path)
            content = File.read(env_path)
            dotenv_entries.each do |key, line|
              unless content.include?(line)
                issues << "#{name}: .env is out of date (#{key} mismatch). Run `portkey apply #{name}`."
                break
              end
            end
          else
            issues << "#{name}: .env not found. Run `portkey apply #{name}`."
          end
        end
      end

      if issues.empty?
        @stdout.puts "All good. #{projects.size} project#{"s" unless projects.size == 1} checked."
      else
        issues.each { |i| @stdout.puts "  #{i}" }
        exit 1
      end
    end

    def print_help
      @stdout.puts <<~HELP
        Usage: portkey <command> [options]

        Commands:
          init              Generate ~/.portkey.yml (prompts for output mode)
          list              List all projects and their assigned ports
          add <name>        Add current directory as a project with auto-assigned ports
          remove <name>     Remove a project from the registry
          show <name>       Print env vars for a project (use --export for shell format)
          apply <name>      Write env file(s) into the project's directory
          apply --all       Write env file(s) into all registered project directories
          check             Scan all registered ports for conflicts
          status            Show which registered ports are in use vs free
          doctor            Check config, paths, and env files are in sync

        Tab colours & Claude Code badge:
          setup             Wire the shell hook and Claude Code status line into your env
          colours           List project colours
          colours <name> <#hex>  Set a project's tab/badge colour
          resolve [dir]     Print "R G B label" for a directory (used by the hook)
          statusline        Render the Claude Code status line (reads session JSON)
          shell-init <zsh|bash>  Print the tab-colour shell hook for eval

        Options:
          --version, -v     Show version
          --help, -h        Show this help
      HELP
    end

    # --- helpers ---

    # Colours already in use across projects, so add can avoid handing out a
    # tint that's taken.
    def assigned_colours
      config.projects.values.filter_map { |d| d["colour"] if d.is_a?(Hash) }
    end

    def setup_shell(shell)
      rc = File.expand_path(shell == "bash" ? "~/.bashrc" : "~/.zshrc")
      # Guarded so a missing or older portkey can't break shell startup: the
      # eval only runs when `portkey shell-init` actually succeeds.
      block = <<~SH
        #{SETUP_BEGIN}
        if command -v portkey >/dev/null 2>&1; then
          _portkey_init="$(portkey shell-init #{shell} 2>/dev/null)" && eval "$_portkey_init"
          unset _portkey_init
        fi
        #{SETUP_END}
      SH
      existing = File.exist?(rc) ? File.read(rc) : ""

      if existing.include?(SETUP_BEGIN)
        updated = existing.sub(/#{Regexp.escape(SETUP_BEGIN)}.*?#{Regexp.escape(SETUP_END)}\n?/m, block)
        if updated == existing
          @stdout.puts "#{rc} already wired up"
        else
          backup(rc)
          File.write(rc, updated)
          @stdout.puts "Updated portkey block in #{rc}"
        end
      else
        backup(rc) if File.exist?(rc)
        prefix = existing.empty? || existing.end_with?("\n") ? "" : "\n"
        File.write(rc, "#{existing}#{prefix}\n#{block}")
        @stdout.puts "Added portkey block to #{rc}"
      end
    end

    def setup_statusline
      settings = File.expand_path("~/.claude/settings.json")
      data = if File.exist?(settings)
        begin
          JSON.parse(File.read(settings))
        rescue JSON::ParserError
          raise Portkey::Error, "#{settings} is not valid JSON; fix or move it, then re-run setup."
        end
      else
        {}
      end

      desired = { "type" => "command", "command" => "portkey statusline" }
      if data["statusLine"] == desired
        @stdout.puts "#{settings} already configured"
        return
      end

      backup(settings)
      data["statusLine"] = desired
      FileUtils.mkdir_p(File.dirname(settings))
      File.write(settings, "#{JSON.pretty_generate(data)}\n")
      @stdout.puts "Set Claude Code statusLine in #{settings}"
    end

    def backup(path)
      return unless File.exist?(path)

      FileUtils.cp(path, "#{path}.portkey-bak")
    end

    ZSH_INIT = <<~'ZSH'
      # portkey — per-directory iTerm2 tab colour (driven by ~/.portkey.yml).
      _portkey_tabcolour() {
        [[ "$TERM_PROGRAM" == "iTerm.app" ]] || return
        local out R G B
        out="$(portkey resolve 2>/dev/null)"
        if [[ -n "$out" ]]; then
          read -r R G B _ <<< "$out"
          printf '\033]6;1;bg;red;brightness;%d\a'   "$R"
          printf '\033]6;1;bg;green;brightness;%d\a' "$G"
          printf '\033]6;1;bg;blue;brightness;%d\a'  "$B"
        else
          printf '\033]6;1;bg;*;default\a'
        fi
      }
      autoload -U add-zsh-hook
      add-zsh-hook chpwd _portkey_tabcolour
      _portkey_tabcolour
    ZSH

    BASH_INIT = <<~'BASH'
      # portkey — per-directory iTerm2 tab colour (driven by ~/.portkey.yml).
      _portkey_tabcolour() {
        [ "$TERM_PROGRAM" = "iTerm.app" ] || return
        [ "$PWD" = "$_PORTKEY_LAST_PWD" ] && return
        _PORTKEY_LAST_PWD="$PWD"
        local out R G B
        out="$(portkey resolve 2>/dev/null)"
        if [ -n "$out" ]; then
          read -r R G B _ <<< "$out"
          printf '\033]6;1;bg;red;brightness;%d\a'   "$R"
          printf '\033]6;1;bg;green;brightness;%d\a' "$G"
          printf '\033]6;1;bg;blue;brightness;%d\a'  "$B"
        else
          printf '\033]6;1;bg;*;default\a'
        fi
      }
      case "$PROMPT_COMMAND" in
        *_portkey_tabcolour*) ;;
        *) PROMPT_COMMAND="_portkey_tabcolour${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
      esac
    BASH
  end
end

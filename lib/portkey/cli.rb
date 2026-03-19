# frozen_string_literal: true

require "optparse"

module Portkey
  class CLI
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
      when "init"    then cmd_init
      when "list"    then cmd_list
      when "add"     then cmd_add
      when "remove"  then cmd_remove
      when "apply"   then cmd_apply
      when "show"    then cmd_show
      when "check"   then cmd_check
      when "status"  then cmd_status
      when "doctor"  then cmd_doctor
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
          next if key == "path" || key == "mode"
          @stdout.puts "  #{key.ljust(12)} #{value}"
        end
        path = data["path"]
        @stdout.puts "  #{"path".ljust(12)} #{path}" if path
        @stdout.puts "  #{"mode".ljust(12)} #{config.mode_for(name)}"
        @stdout.puts ""
      end
    end

    def cmd_add
      name = @argv.shift
      unless name
        @stderr.puts "Usage: portkey add <name> [--services app,postgres,redis,...]"
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

      registry = Registry.new(config: config)
      ports = if services
        registry.assign_ports(services: services)
      else
        registry.assign_ports
      end
      attrs = { "path" => Dir.pwd }.merge(ports)

      config.add_project(name, attrs)
      @stdout.puts "Added project '#{name}':"
      ports.each do |service, port|
        @stdout.puts "  #{service.ljust(12)} #{port}"
      end

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

      # Check for inter-project conflicts
      unless port_conflicts.empty?
        has_issues = true
        @stdout.puts "Port conflicts between projects:"
        port_conflicts.each do |c|
          @stdout.puts "  Port #{c[:port]}: #{c[:project]}/#{c[:service]} conflicts with #{c[:conflict_with]}"
        end
        @stdout.puts ""
      end

      # Check for conflicts with currently bound ports
      projects.each do |name, data|
        data.each do |key, value|
          next if key == "path" || key == "mode"
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
          next if key == "path" || key == "mode"
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

    def cmd_doctor
      projects = config.projects
      issues = []

      # Check config file exists
      unless File.exist?(config.config_path)
        issues << "Config file not found at #{config.config_path}. Run `portkey init`."
        issues.each { |i| @stdout.puts "  #{i}" }
        exit 1
      end

      # Check direnv if any project uses envrc mode
      needs_direnv = projects.any? { |name, _| %w[envrc both].include?(config.mode_for(name)) }
      if needs_direnv
        direnv_found = system("which direnv > /dev/null 2>&1")
        issues << "direnv not found in PATH (needed for envrc/both mode)" unless direnv_found
      end

      # Check each project
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

        # Check env files are up to date
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

        Options:
          --version, -v     Show version
          --help, -h        Show this help
      HELP
    end
  end
end

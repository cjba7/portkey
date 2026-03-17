# frozen_string_literal: true

require "open3"

module Portkey
  module EnvrcWriter
    SERVICE_KEY_MAP = {
      "postgres" => "DB_PORT",
      "postgresql" => "DB_PORT",
      "pg" => "DB_PORT"
    }.freeze

    module_function

    def env_key(service_name)
      SERVICE_KEY_MAP.fetch(service_name, "#{service_name.upcase}_PORT")
    end

    def port_entries(project_data, export: true)
      entries = {}
      project_data.each do |key, value|
        next if key == "path"
        next unless value.is_a?(Integer)

        k = env_key(key)
        next if entries.key?(k)

        entries[k] = if export
          "export #{k}=#{value}"
        else
          "#{k}=#{value}"
        end
      end
      entries
    end

    def merge_content(existing_content, entries, export: true)
      remaining = entries.dup
      prefix = export ? "export " : ""

      lines = existing_content.lines.map do |line|
        stripped = line.chomp
        matched = remaining.detect do |key, _|
          stripped.match?(/\A#{Regexp.escape(prefix)}#{Regexp.escape(key)}=/)
        end

        if matched
          key, new_line = matched
          remaining.delete(key)
          "#{new_line}\n"
        else
          line
        end
      end

      # Append any keys that weren't already in the file
      unless remaining.empty?
        lines << "\n" if lines.any? && !lines.last.end_with?("\n")
        remaining.each_value do |new_line|
          lines << "#{new_line}\n"
        end
      end

      lines.join
    end

    def write(project_name, project_data, mode: "envrc", run_direnv: true)
      path = project_data["path"]
      raise Portkey::Error, "No path defined for project '#{project_name}'" unless path

      expanded = File.expand_path(path)
      unless Dir.exist?(expanded)
        raise Portkey::Error, "Project directory does not exist: #{expanded}"
      end

      written = []

      if mode == "envrc" || mode == "both"
        envrc_path = File.join(expanded, ".envrc")
        entries = port_entries(project_data, export: true)
        existing = File.exist?(envrc_path) ? File.read(envrc_path) : ""
        File.write(envrc_path, merge_content(existing, entries, export: true))
        direnv_allow(expanded) if run_direnv
        written << envrc_path
      end

      if mode == "dotenv" || mode == "both"
        dotenv_path = File.join(expanded, ".env")
        entries = port_entries(project_data, export: false)
        existing = File.exist?(dotenv_path) ? File.read(dotenv_path) : ""
        File.write(dotenv_path, merge_content(existing, entries, export: false))
        written << dotenv_path
      end

      written
    end

    def direnv_allow(dir)
      Open3.capture2("direnv", "allow", chdir: dir)
    rescue Errno::ENOENT
      warn "Warning: direnv not found. Run `direnv allow` manually in #{dir}"
    end
  end
end

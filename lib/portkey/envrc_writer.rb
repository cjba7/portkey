# frozen_string_literal: true

require "open3"

module Portkey
  module EnvrcWriter
    SERVICE_KEY_MAP = {
      "postgres" => "DB_PORT",
      "postgresql" => "DB_PORT",
      "pg" => "DB_PORT"
    }.freeze

    BEGIN_MARKER = "# BEGIN portkey"
    END_MARKER = "# END portkey"

    module_function

    def env_key(service_name)
      SERVICE_KEY_MAP.fetch(service_name, "#{service_name.upcase}_PORT")
    end

    def port_lines(project_name, project_data, export: true)
      lines = []
      seen = {}
      project_data.each do |key, value|
        next if key == "path"
        next unless value.is_a?(Integer)

        k = env_key(key)
        next if seen.key?(k)
        seen[k] = true

        lines << if export
          "export #{k}=#{value}"
        else
          "#{k}=#{value}"
        end
      end
      lines
    end

    def generate_block(project_name, project_data, export: true)
      lines = [BEGIN_MARKER]
      lines << "# Project: #{project_name} — managed by portkey, do not edit"
      lines.concat(port_lines(project_name, project_data, export: export))
      lines << END_MARKER
      lines.join("\n") + "\n"
    end

    def merge_into_file(filepath, project_name, project_data, export: true)
      block = generate_block(project_name, project_data, export: export)

      if File.exist?(filepath)
        content = File.read(filepath)
        if content.include?(BEGIN_MARKER) && content.include?(END_MARKER)
          # Replace existing portkey block
          updated = content.sub(
            /#{Regexp.escape(BEGIN_MARKER)}.*?#{Regexp.escape(END_MARKER)}\n?/m,
            block
          )
          File.write(filepath, updated)
        else
          # Append portkey block
          content += "\n" unless content.end_with?("\n") || content.empty?
          File.write(filepath, content + "\n" + block)
        end
      else
        File.write(filepath, block)
      end
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
        merge_into_file(envrc_path, project_name, project_data, export: true)
        direnv_allow(expanded) if run_direnv
        written << envrc_path
      end

      if mode == "dotenv" || mode == "both"
        dotenv_path = File.join(expanded, ".env")
        merge_into_file(dotenv_path, project_name, project_data, export: false)
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

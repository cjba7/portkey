# frozen_string_literal: true

require "yaml"
require "fileutils"

module Portkey
  class Config
    VALID_MODES = %w[envrc dotenv both].freeze

    attr_reader :config_path

    def initialize(config_path: File.expand_path("~/.portkey.yml"))
      @config_path = config_path
    end

    def load
      return { "projects" => {} } unless File.exist?(@config_path)

      data = YAML.safe_load(File.read(@config_path), permitted_classes: []) || {}
      validate!(data)
      data
    rescue Psych::SyntaxError => e
      raise Portkey::Error, "Malformed YAML in #{@config_path}: #{e.message}"
    end

    def save(data)
      FileUtils.mkdir_p(File.dirname(@config_path))
      File.write(@config_path, YAML.dump(data))
    end

    def mode
      m = load["mode"]
      VALID_MODES.include?(m) ? m : "dotenv"
    end

    def projects
      load["projects"] || {}
    end

    def project(name)
      projects[name]
    end

    def add_project(name, attrs)
      data = load
      if data["projects"].key?(name)
        raise Portkey::Error, "Project '#{name}' already exists"
      end

      data["projects"][name] = attrs
      save(data)
    end

    def remove_project(name)
      data = load
      unless data["projects"].key?(name)
        raise Portkey::Error, "Project '#{name}' not found"
      end

      data["projects"].delete(name)
      save(data)
    end

    def init_config(mode: "dotenv")
      if File.exist?(@config_path)
        raise Portkey::Error, "Config already exists at #{@config_path}"
      end

      unless VALID_MODES.include?(mode)
        raise Portkey::Error, "Invalid mode '#{mode}'. Must be one of: #{VALID_MODES.join(", ")}"
      end

      FileUtils.mkdir_p(File.dirname(@config_path))
      File.write(@config_path, init_template(mode))
    end

    private

    def validate!(data)
      unless data.is_a?(Hash)
        raise Portkey::Error, "Config must be a YAML mapping"
      end

      if data.key?("projects") && !data["projects"].is_a?(Hash)
        raise Portkey::Error, "'projects' must be a mapping"
      end
    end

    def init_template(mode)
      <<~YAML
        # ~/.portkey.yml — portkey port registry
        #
        # Each project gets a block of ports for its services.
        # Run `portkey add <name>` to auto-assign ports, or edit this file manually.
        #
        # mode: dotenv  — write .env files (default)
        # mode: envrc   — write .envrc files (for direnv)
        # mode: both    — write both .envrc and .env files

        mode: #{mode}

        # Example:
        #
        # projects:
        #   myapp:
        #     path: ~/code/myapp
        #     app: 3000
        #     postgres: 5432
        #     redis: 6379
        #
        #   otherapp:
        #     path: ~/code/otherapp
        #     app: 3010
        #     postgres: 5442
        #     redis: 6389

        projects: {}
      YAML
    end
  end
end

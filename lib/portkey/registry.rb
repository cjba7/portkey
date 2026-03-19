# frozen_string_literal: true

require "set"

module Portkey
  class Registry
    BASE_PORTS = {
      "app" => 3000,
      "postgres" => 5432,
      "redis" => 6379
    }.freeze

    PORT_INCREMENT = 10

    def initialize(config:, port_checker: PortChecker)
      @config = config
      @port_checker = port_checker
    end

    def assign_ports(services: BASE_PORTS.keys)
      assigned = all_assigned_ports
      bound = @port_checker.bound_ports

      services.each_with_object({}) do |service, result|
        base = BASE_PORTS.fetch(service, 8000)
        port = base
        while assigned.include?(port) || bound.include?(port)
          port += PORT_INCREMENT
        end
        result[service] = port
        assigned.add(port)
      end
    end

    def all_assigned_ports
      ports = Set.new
      @config.projects.each_value do |proj|
        proj.each do |key, value|
          next if key == "path" || key == "mode"
          ports.add(value) if value.is_a?(Integer)
        end
      end
      ports
    end

    def conflicts
      results = []
      seen = {}

      @config.projects.each do |project_name, proj|
        proj.each do |key, value|
          next if key == "path" || key == "mode"
          next unless value.is_a?(Integer)

          if seen.key?(value)
            results << {
              project: project_name,
              service: key,
              port: value,
              conflict_with: seen[value]
            }
          else
            seen[value] = "#{project_name}/#{key}"
          end
        end
      end

      results
    end
  end
end

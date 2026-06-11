# frozen_string_literal: true

module Portkey
  VERSION = "1.1.0"

  class Error < StandardError; end

  # Keys in a project's hash that are metadata, not service ports. Everything
  # else maps a service name to a port number.
  RESERVED_KEYS = %w[path mode colour].freeze
end

require_relative "portkey/config"
require_relative "portkey/port_checker"
require_relative "portkey/registry"
require_relative "portkey/envrc_writer"
require_relative "portkey/colours"
require_relative "portkey/cli"

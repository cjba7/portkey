# frozen_string_literal: true

require_relative "lib/portkey"

Gem::Specification.new do |spec|
  spec.name = "portkey"
  spec.version = Portkey::VERSION
  spec.authors = ["cjba7"]
  spec.summary = "System-wide port registry for developers running multiple projects"
  spec.description = "portkey reads a central ~/.portkey.yml config and injects port assignments as environment variables via direnv, so each project gets stable, non-conflicting ports."
  spec.homepage = "https://github.com/cjba7/portkey"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb", "bin/*"]
  spec.bindir = "bin"
  spec.executables = ["portkey"]

  spec.add_development_dependency "minitest", "~> 5.0"
end

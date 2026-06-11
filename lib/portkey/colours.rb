# frozen_string_literal: true

module Portkey
  # Per-project colours that drive the iTerm2 tab tint and the Claude Code
  # status-line badge. Portkey is the single source of truth: a colour is
  # stored per project in ~/.portkey.yml (as hex). Shell integrations call
  # `portkey resolve` to look up the colour for a directory, so there is no
  # separate rules file to keep in sync.
  module Colours
    module_function

    # A spread of distinct, pleasant colours (Tailwind-ish 500/600). Stored as
    # canonical lowercase hex so they compare equal to normalised values.
    PALETTE = %w[
      #4f46e5 #10b981 #f59e0b #f43f5e #0ea5e9 #8b5cf6 #14b8a6
      #f97316 #ec4899 #84cc16 #06b6d4 #d946ef #3b82f6 #ef4444
    ].freeze

    # Pick a stable colour for a project name, skipping any already in use so
    # two projects don't share a tint when the palette has room. Deterministic:
    # the same name with the same `taken` set always yields the same colour.
    def assign(name, taken: [])
      used = taken.map { |c| normalise(c) }.compact
      start = stable_index(name.to_s, PALETTE.size)
      PALETTE.size.times do |i|
        colour = PALETTE[(start + i) % PALETTE.size]
        return colour unless used.include?(colour)
      end
      PALETTE[start] # palette exhausted — reuse the preferred slot
    end

    # Normalise any accepted colour form to canonical "#rrggbb" (lowercase), or
    # nil if it isn't a valid colour. Accepts "#rgb", "#rrggbb", bare hex, and
    # an "R G B" triple (0–255 each).
    def normalise(colour)
      return nil unless colour.is_a?(String)

      s = colour.strip
      if (m = s.match(/\A(\d{1,3})\s+(\d{1,3})\s+(\d{1,3})\z/))
        rgb = m.captures.map(&:to_i)
        return nil if rgb.any? { |v| v > 255 }

        return format("#%02x%02x%02x", *rgb)
      end

      hex = s.sub(/\A#/, "")
      hex = hex.chars.map { |c| c * 2 }.join if hex.length == 3
      return nil unless hex.match?(/\A[0-9a-fA-F]{6}\z/)

      "##{hex.downcase}"
    end

    def valid?(colour)
      !normalise(colour).nil?
    end

    # "#4f46e5" -> [79, 70, 229]; nil for invalid input.
    def to_rgb(colour)
      n = normalise(colour)
      return nil unless n

      hex = n.delete_prefix("#")
      [hex[0, 2], hex[2, 2], hex[4, 2]].map { |h| h.to_i(16) }
    end

    # Find the colour for a directory: the project whose path is the longest
    # prefix of `dir` and which has a valid colour. Returns [[r, g, b], label]
    # (label is the matched project directory's basename), or nil if nothing
    # matches. Both paths are expanded so `~` and symlinks compare correctly.
    def resolve(dir, projects)
      target = canonical(dir).chomp("/")
      best = nil
      best_len = -1

      (projects || {}).each_value do |data|
        next unless data.is_a?(Hash)

        path = data["path"]
        rgb = to_rgb(data["colour"])
        next unless path && rgb

        prefix = canonical(path).chomp("/")
        next unless target == prefix || target.start_with?("#{prefix}/")
        next unless prefix.length > best_len

        best_len = prefix.length
        best = [rgb, File.basename(prefix)]
      end

      best
    end

    # Resolve a path to its real (symlink-followed) absolute form when it
    # exists, so e.g. /var and /private/var compare equal on macOS. Falls back
    # to plain expansion for paths that don't exist (e.g. a stale project dir).
    def canonical(path)
      File.realpath(path.to_s)
    rescue StandardError
      File.expand_path(path.to_s)
    end

    # A deterministic (process-independent) hash → palette index. Ruby's
    # String#hash is per-process randomised, so roll a small stable one.
    def stable_index(str, size)
      h = str.each_byte.reduce(0) { |acc, b| (acc * 31 + b) % 4_294_967_296 }
      h % size
    end
  end
end

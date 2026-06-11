# frozen_string_literal: true

require_relative "test_helper"

class ColoursTest < Minitest::Test
  include TestHelpers

  # normalise

  def test_normalise_accepts_six_digit_hex
    assert_equal "#4f46e5", Portkey::Colours.normalise("#4f46e5")
    assert_equal "#4f46e5", Portkey::Colours.normalise("#4F46E5")
    assert_equal "#4f46e5", Portkey::Colours.normalise("4F46E5")
    assert_equal "#10b981", Portkey::Colours.normalise("  #10b981  ")
  end

  def test_normalise_expands_three_digit_hex
    assert_equal "#aabbcc", Portkey::Colours.normalise("#abc")
    assert_equal "#ffffff", Portkey::Colours.normalise("fff")
  end

  def test_normalise_accepts_rgb_triple
    assert_equal "#4f46e5", Portkey::Colours.normalise("79 70 229")
    assert_equal "#10b981", Portkey::Colours.normalise("16 185 129")
    assert_equal "#000000", Portkey::Colours.normalise("0 0 0")
  end

  def test_normalise_rejects_invalid
    assert_nil Portkey::Colours.normalise(nil)
    assert_nil Portkey::Colours.normalise("")
    assert_nil Portkey::Colours.normalise("nope")
    assert_nil Portkey::Colours.normalise("#12")
    assert_nil Portkey::Colours.normalise("#12345")
    assert_nil Portkey::Colours.normalise("#xyzxyz")
    assert_nil Portkey::Colours.normalise("300 0 0")
    assert_nil Portkey::Colours.normalise(12345)
  end

  def test_valid
    assert Portkey::Colours.valid?("#4f46e5")
    refute Portkey::Colours.valid?("banana")
  end

  # to_rgb

  def test_to_rgb
    assert_equal [79, 70, 229], Portkey::Colours.to_rgb("#4f46e5")
    assert_equal [16, 185, 129], Portkey::Colours.to_rgb("16 185 129")
    assert_equal [255, 255, 255], Portkey::Colours.to_rgb("#fff")
    assert_nil Portkey::Colours.to_rgb("garbage")
  end

  # assign

  def test_assign_returns_a_palette_colour
    assert_includes Portkey::Colours::PALETTE, Portkey::Colours.assign("myapp")
  end

  def test_assign_is_deterministic_across_calls
    assert_equal Portkey::Colours.assign("myapp"), Portkey::Colours.assign("myapp")
  end

  def test_assign_differs_by_name
    refute_equal Portkey::Colours.assign("alpha"), Portkey::Colours.assign("zeta")
  end

  def test_assign_avoids_taken_colours
    preferred = Portkey::Colours.assign("myapp")
    alternative = Portkey::Colours.assign("myapp", taken: [preferred])

    refute_equal preferred, alternative
    assert_includes Portkey::Colours::PALETTE, alternative
  end

  def test_assign_normalises_taken_input
    preferred = Portkey::Colours.assign("myapp")
    rgb = Portkey::Colours.to_rgb(preferred).join(" ")

    refute_equal preferred, Portkey::Colours.assign("myapp", taken: [rgb])
  end

  def test_assign_falls_back_when_palette_exhausted
    assert_includes Portkey::Colours::PALETTE, Portkey::Colours.assign("myapp", taken: Portkey::Colours::PALETTE)
  end

  # resolve

  def test_resolve_matches_exact_and_descendant_paths
    projects = { "a" => { "path" => "/code/app", "colour" => "#4f46e5" } }

    assert_equal [[79, 70, 229], "app"], Portkey::Colours.resolve("/code/app", projects)
    assert_equal [[79, 70, 229], "app"], Portkey::Colours.resolve("/code/app/sub/dir", projects)
  end

  def test_resolve_returns_nil_for_no_match
    projects = { "a" => { "path" => "/code/app", "colour" => "#4f46e5" } }

    assert_nil Portkey::Colours.resolve("/elsewhere", projects)
    # boundary: a sibling sharing a string prefix must not match
    assert_nil Portkey::Colours.resolve("/code/application", projects)
  end

  def test_resolve_longest_prefix_wins
    projects = {
      "outer" => { "path" => "/code", "colour" => "#4f46e5" },
      "inner" => { "path" => "/code/app", "colour" => "#10b981" }
    }

    assert_equal [[79, 70, 229], "code"], Portkey::Colours.resolve("/code/other", projects)
    assert_equal [[16, 185, 129], "app"], Portkey::Colours.resolve("/code/app/x", projects)
  end

  def test_resolve_skips_projects_without_colour_or_path
    projects = {
      "no_colour" => { "path" => "/code/app", "app" => 3000 },
      "no_path" => { "colour" => "#4f46e5" }
    }

    assert_nil Portkey::Colours.resolve("/code/app", projects)
  end

  def test_resolve_expands_tilde_in_project_path
    projects = { "home" => { "path" => "~/work/app", "colour" => "#4f46e5" } }
    target = File.expand_path("~/work/app/deep")

    assert_equal [[79, 70, 229], "app"], Portkey::Colours.resolve(target, projects)
  end

  def test_resolve_handles_empty_projects
    assert_nil Portkey::Colours.resolve("/anywhere", {})
    assert_nil Portkey::Colours.resolve("/anywhere", nil)
  end
end

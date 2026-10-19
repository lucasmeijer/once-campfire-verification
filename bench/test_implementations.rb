require "minitest/autorun"
require_relative "comparison_support"

class ImplementationsTest < Minitest::Test
  # BenchmarkSupport's `run` would replace Minitest's.
  def implementations(*arguments) = Object.new.extend(BenchmarkSupport).implementations(*arguments)

  def test_known_apps_keep_their_images_and_sources
    rails, rust, bun = implementations(%w[rails rust express-bun], {}, "/w")
    assert_equal ["once-campfire:app", "/w/once-campfire", "rails"], [rails.image, rails.source, rails.kind]
    assert_equal ["campfire-rust:app", "/w/once-campfire-rust", nil], [rust.image, rust.source, rust.topology]
    assert_equal ["once-campfire-express:bun", "/w/once-campfire-express", "express"], [bun.image, bun.source, bun.kind]
    go, = implementations(%w[go], { "GO_IMAGE" => "go:test", "GO_SOURCE" => "/src/go" }, "/w")
    assert_equal ["go:test", "/src/go"], [go.image, go.source]
  end

  def test_an_unknown_app_needs_its_image
    error = assert_raises(RuntimeError) { implementations(%w[rust zig], {}, "/w") }
    assert_includes error.message, "set ZIG_IMAGE"
    error = assert_raises(RuntimeError) { implementations(%w[rsut], { "RUST_IMAGE" => "campfire-rust:app" }, "/w") }
    assert_includes error.message, "set RSUT_IMAGE"
  end

  def test_an_unknown_app_with_an_image_is_benchmarked_as_itself
    env = { "ZIG_IMAGE" => "campfire-zig:app", "ZIG_TOPOLOGY" => '{"processes":1,"jobs":"in-process"}' }
    zig, = implementations(%w[zig], env, "/w")
    assert_equal ["zig", "campfire-zig:app", "/w/once-campfire-zig"], [zig.kind, zig.image, zig.source]
    assert_equal({ "processes" => 1, "jobs" => "in-process" }, zig.topology)
    plain, = implementations(%w[my-port], { "MY_PORT_IMAGE" => "mine:1" }, "/w")
    assert_equal({}, plain.topology)
  end

  def test_names_and_topologies_are_checked
    assert_raises(RuntimeError) { implementations([], {}, "/w") }
    assert_raises(RuntimeError) { implementations(%w[go go], {}, "/w") }
    assert_raises(RuntimeError) { implementations(["Bad Name"], { "BAD NAME_IMAGE" => "x" }, "/w") }
    assert_raises(RuntimeError) { implementations(%w[zig], { "ZIG_IMAGE" => "x", "ZIG_TOPOLOGY" => "[1]" }, "/w") }
    assert_raises(RuntimeError) { implementations(%w[zig], { "ZIG_IMAGE" => "x", "ZIG_TOPOLOGY" => "null" }, "/w") }
  end
end

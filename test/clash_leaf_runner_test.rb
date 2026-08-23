# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "yaml"
require_relative "../leaf_runner/command"

class ClashLeafRunnerTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  WRAPPER = File.join(ROOT, "bin", "test-clash-leaf")

  def test_cached_remote_subscription_is_resolved_without_using_the_active_profile
    Dir.mktmpdir("ip-quality-subscription-") do |directory|
      write_clash_verge_fixture(directory)
      catalog = IpQuality::SubscriptionCatalog.new(app_root: directory)
      source = catalog.source_for(catalog.entries.fetch(0))
      profile = IpQuality::ClashLeafProfile.new(source)

      assert_equal "cached remote subscription \"Fixture Remote\" (read-only snapshot)", source.description
      assert_equal %w[TransportLeaf TargetLeaf], profile.leaf_names
      refute_includes source.description, "https://"
    end
  end

  def test_default_flow_selects_subscription_then_leaf_without_repeating_the_leaf_count
    Dir.mktmpdir("ip-quality-subscription-select-") do |directory|
      write_clash_verge_fixture(directory)
      stdout = StringIO.new
      stderr = StringIO.new
      command = IpQuality::ClashLeafCommand.new(
        stdout: stdout,
        stderr: stderr,
        stdin: StringIO.new("1\n2\n"),
        app_root: directory
      )

      exit_code = command.run([])

      assert_equal 0, exit_code
      assert_includes stdout.string, "Cached remote subscriptions:"
      assert_includes stdout.string, "Available inline leaves"
      assert_includes stdout.string, "exact leaf: TargetLeaf"
      refute_match(/\d+ inline leaves/, stdout.string)
      assert_empty stderr.string
    end
  end

  def test_renderer_keeps_only_the_exact_leaf_and_recursive_dialer_dependencies
    source = IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", fixture_document)
    profile = IpQuality::ClashLeafProfile.new(source)
    rendered = YAML.safe_load(profile.render("TargetLeaf", mixed_port: 45_678), aliases: true)

    assert_equal 45_678, rendered.fetch("mixed-port")
    assert_equal false, rendered.fetch("allow-lan")
    assert_equal "127.0.0.1", rendered.fetch("bind-address")
    assert_equal %w[TransportLeaf TargetLeaf], rendered.fetch("proxies").map { |entry| entry.fetch("name") }
    assert_equal "fixture-secret-placeholder", rendered.fetch("proxies").last.fetch("password")
    assert_equal ["TargetLeaf"], rendered.fetch("proxy-groups").first.fetch("proxies")
    assert_equal false, rendered.dig("profile", "store-selected")
    refute rendered.key?("external-controller")
    refute rendered.key?("tun")
    refute rendered.key?("proxy-providers")
  end

  def test_renderer_rejects_group_dependencies_and_non_exact_names
    document = fixture_document
    document["proxies"].last["dialer-proxy"] = "FixtureGroup"
    profile = IpQuality::ClashLeafProfile.new(
      IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", document)
    )

    error = assert_raises(IpQuality::ClashLeafProfile::Error) do
      profile.render("TargetLeaf", mixed_port: 45_678)
    end
    assert_includes error.message, "depends on proxy group"
    assert_raises(IpQuality::ClashLeafProfile::Error) do
      profile.render("FixtureGroup", mixed_port: 45_678)
    end
  end

  def test_duplicate_leaf_names_are_rejected
    document = fixture_document
    document["proxies"] << document["proxies"].last.dup

    error = assert_raises(IpQuality::ClashLeafProfile::Error) do
      IpQuality::ClashLeafProfile.new(
        IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", document)
      )
    end
    assert_includes error.message, "duplicate leaf proxy name"
  end

  def test_leaf_names_cannot_shadow_mihomo_builtins
    document = fixture_document
    document["proxies"].first["name"] = "DIRECT"

    error = assert_raises(IpQuality::ClashLeafProfile::Error) do
      IpQuality::ClashLeafProfile.new(
        IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", document)
      )
    end
    assert_includes error.message, "collides with Mihomo builtin"
  end

  def test_safe_snapshot_rejects_symlinks_and_hard_links
    Dir.mktmpdir("ip-quality-safe-snapshot-") do |directory|
      original = File.join(directory, "profile.yaml")
      File.write(original, "proxies: []\n")
      File.chmod(0o600, original)

      symlink = File.join(directory, "symlink.yaml")
      File.symlink(original, symlink)
      symlink_error = assert_raises(IpQuality::SafeSnapshot::Error) do
        IpQuality::SafeSnapshot.read(symlink)
      end
      assert_equal :symlink, symlink_error.reason

      hard_link = File.join(directory, "hard-link.yaml")
      File.link(original, hard_link)
      hard_link_error = assert_raises(IpQuality::SafeSnapshot::Error) do
        IpQuality::SafeSnapshot.read(original)
      end
      assert_equal :hard_link, hard_link_error.reason
    end
  end

  def test_unconfirmed_command_prints_a_plan_without_starting_mihomo
    Dir.mktmpdir("ip-quality-leaf-plan-") do |directory|
      profile_path = File.join(directory, "profile.yaml")
      write_private_yaml(profile_path, fixture_document)
      stdout = StringIO.new
      stderr = StringIO.new
      command = IpQuality::ClashLeafCommand.new(
        stdout: stdout,
        stderr: stderr,
        stdin: StringIO.new
      )

      exit_code = command.run(["--profile", profile_path, "--leaf", "TargetLeaf", "-4"])

      assert_equal 0, exit_code
      assert_includes stdout.string, "no network access has occurred"
      assert_includes stdout.string, "live Clash profile/selection: read only and unchanged"
      assert_includes stdout.string, "Ping0"
      assert_empty stderr.string
    end
  end

  def test_entrypoint_is_a_thin_zsh_wrapper_and_all_runtime_code_is_source_auditable
    wrapper = File.binread(WRAPPER)
    sources = Dir.glob(File.join(ROOT, "{bin,leaf_runner,lib,providers,report}", "**", "*"))
      .select { |path| File.file?(path) }
      .map { |path| File.binread(path) }
      .join("\n")

    assert wrapper.start_with?("#!/bin/zsh\n")
    assert_includes wrapper, "/usr/bin/ruby --disable-gems"
    refute_match(/\/bin\/bash|BASH_REMATCH|\bshopt\b|\bmapfile\b/, sources)
    refute_includes sources, "external-controller"
    refute_includes sources, "secret:"
  end

  private

  def fixture_document
    {
      "mixed-port" => 7_897,
      "external-controller" => "127.0.0.1:9090",
      "tun" => { "enable" => true },
      "proxy-providers" => { "unused" => { "url" => "https://provider.test.invalid" } },
      "proxies" => [
        {
          "name" => "TransportLeaf",
          "type" => "socks5",
          "server" => "transport.test.invalid",
          "port" => 1_080
        },
        {
          "name" => "TargetLeaf",
          "type" => "ss",
          "server" => "target.test.invalid",
          "port" => 8_443,
          "cipher" => "aes-128-gcm",
          "password" => "fixture-secret-placeholder",
          "dialer-proxy" => "TransportLeaf"
        }
      ],
      "proxy-groups" => [
        {
          "name" => "FixtureGroup",
          "type" => "select",
          "proxies" => ["TargetLeaf"]
        }
      ],
      "rules" => ["MATCH,FixtureGroup"]
    }
  end

  def write_private_yaml(path, document)
    File.write(path, YAML.dump(document))
    File.chmod(0o600, path)
  end

  def write_clash_verge_fixture(directory)
    profiles_directory = File.join(directory, "profiles")
    Dir.mkdir(profiles_directory, 0o700)
    write_private_yaml(File.join(profiles_directory, "remote.yaml"), fixture_document)
    write_private_yaml(File.join(profiles_directory, "active-local.yaml"), { "proxies" => [] })
    write_private_yaml(
      File.join(directory, "profiles.yaml"),
      {
        "current" => "fixture-active-local",
        "items" => [
          {
            "uid" => "fixture-active-local",
            "name" => "Active Local",
            "file" => "active-local.yaml",
            "type" => "local"
          },
          {
            "uid" => "fixture-remote",
            "name" => "Fixture Remote",
            "file" => "remote.yaml",
            "type" => "remote",
            "url" => "https://secret-subscription.test.invalid/token"
          }
        ]
      }
    )
  end
end

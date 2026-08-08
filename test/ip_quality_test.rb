# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "json"

class IpQualityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SCRIPT = File.join(ROOT, "ip-quality.zsh")
  DNSBL = File.join(ROOT, "ref", "dnsbl.list")
  ISO3166 = File.join(ROOT, "ref", "iso3166.json")

  BANNED_SOURCE_PATTERNS = {
    bash_runtime: /(^|[^A-Za-z0-9_])bash([^A-Za-z0-9_]|$)/i,
    bash_match_array: /BASH_REMATCH/,
    bash_shell_option: /\bshopt\b/,
    bash_mapfile: /\bmapfile\b/,
    dynamic_eval: /\beval\s/,
    remote_shell_pipe: /curl[^\n]*(?:\|\s*(?:sh|zsh)|<\((?:sh|zsh))/i,
    telemetry: /hits\.xykt\.de/i,
    report_upload: /upload\.check\.place/i,
    remote_reference: /(?:raw\.githubusercontent\.com|cdn\.jsdelivr\.net|rawgithub)/i,
    package_installer: /(?:brew\s+install|apt-get\s+install|dnf\s+install|yum\s+install|pacman\s+-S|apk\s+add|xbps-install)/i,
    background_disown: /\bdisown\b/,
    return_trap: /trap[^\n]*RETURN/,
    cookie_bundle: /ref\/cookies\.txt/,
    bundled_cookie_header: /curl_safe[^\n]+(?:\s-b\s|Cookie:)/i,
    embedded_authorization_header: /authorization:/i,
    dynamic_api_key_scrape: /apiKey=/
  }.freeze

  def test_default_is_a_no_network_disclosure_plan
    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_includes stdout, "no network access has occurred"
    assert_includes stdout, "scope: full"
    assert_includes stdout, "telemetry/report upload/remote code: disabled"
    assert_includes stdout, "--confirm-network-lookup"
    assert_empty stderr
  end

  def test_each_scope_has_a_bounded_plan
    {
      "reputation" => "reputation sources:",
      "dnsbl" => "DNSBL sources:",
      "media-ai" => "media/AI sources:",
      "mail" => "mail sources:"
    }.each do |scope, marker|
      stdout, stderr, status = run_script("--scope", scope)

      assert status.success?, "scope=#{scope}: #{stderr}"
      assert_includes stdout, "scope: #{scope}"
      assert_includes stdout, marker
      assert_empty stderr
    end
  end

  def test_explicit_plan_still_prevents_network_after_confirmation
    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--plan",
      "--scope",
      "full"
    )

    assert status.success?, stderr
    assert_includes stdout, "no network access has occurred"
    assert_empty stderr
  end

  def test_offline_self_test_covers_zsh_validators_and_dnsbl_aggregation
    stdout, stderr, status = run_script("--self-test")

    assert status.success?, stderr
    assert_match(/SELF-TEST OK: zsh runtime, validators, and \d+ DNSBL entries/, stdout)
    assert_empty stderr
  end

  def test_concurrency_is_hard_bounded
    %w[0 51 nope].each do |value|
      _stdout, stderr, status = run_script("--scope", "dnsbl", "--dnsbl-concurrency", value)

      assert_equal 64, status.exitstatus, "value=#{value}"
      assert_includes stderr, "must be an integer from 1 through 50"
    end

    stdout, stderr, status = run_script("--scope", "dnsbl", "--dnsbl-concurrency", "50")
    assert status.success?, stderr
    assert_includes stdout, "DNSBL concurrency cap: 50"
  end

  def test_removed_upstream_mutation_and_remote_execution_flags_are_rejected
    %w[-xhttp://127.0.0.1:1 -y -M].each do |flag|
      _stdout, stderr, status = run_script(flag)

      assert_equal 64, status.exitstatus, "flag=#{flag}"
      assert_includes stderr, "disabled"
    end
  end

  def test_live_gate_rejects_incompatible_family_and_unsafe_interface_before_lookup
    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "dnsbl",
      "-6"
    )
    assert_equal 61, status.exitstatus
    assert_includes stdout, "DNSBL"
    assert_empty stderr

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "-i",
      "en0 --proxy http://example.invalid"
    )
    assert_equal 7, status.exitstatus
    assert_includes stdout, "指定的网卡"
    assert_empty stderr
  end

  def test_source_is_zsh_native_and_contains_no_removed_runtime_paths
    source = File.binread(SCRIPT)

    assert source.start_with?("#!/bin/zsh\n")
    assert_includes source, "--confirm-network-lookup"
    assert_includes source, "typeset -A"
    assert_includes source, "/bin/zsh -fc"
    assert_includes source, 'command curl -q "$@"'
    assert_includes source, '${ipqs[score]:-null}'
    BANNED_SOURCE_PATTERNS.each do |name, pattern|
      refute_match pattern, source, "#{name} unexpectedly remains"
    end
  end

  def test_vendored_references_are_regular_local_data_without_cookie_state
    [DNSBL, ISO3166].each do |path|
      assert File.file?(path), "missing reference: #{path}"
      refute File.symlink?(path), "symlinked reference: #{path}"
      refute_includes File.binread(path), "\0", "binary reference: #{path}"
    end

    refute File.exist?(File.join(ROOT, "ref", "cookies.txt"))
    refute File.exist?(File.join(ROOT, "ref", "iata-icao.csv"))
    zones = File.readlines(DNSBL, chomp: true)
    assert_operator zones.length, :>=, 100
    assert_equal zones.uniq, zones
    assert zones.all? { |zone| zone.match?(/\A[A-Za-z0-9._-]+\z/) }
    countries = JSON.parse(File.read(ISO3166))
    assert_operator countries.length, :>=, 200
    assert countries.all? { |country| country.key?("alpha-2") && country.key?("name") }
  end

  def test_provenance_license_and_provider_disclosure_are_present
    upstream = File.read(File.join(ROOT, "UPSTREAM.md"))
    providers = File.read(File.join(ROOT, "PROVIDERS.md"))
    license = File.read(File.join(ROOT, "LICENSE"))

    assert_includes upstream, "b59787d9832ab163cdf93c10759000ed4ba76cb0"
    assert_includes upstream, "760c1d7c44da4c904662ab37591c409ac58371fa2439a77e091f2c23c83251c8"
    assert_includes upstream, "cookies.txt"
    assert_includes providers, "Upstream relay"
    assert_includes providers, "Unknown"
    assert_includes license, "GNU AFFERO GENERAL PUBLIC LICENSE"
  end

  def test_directory_has_no_nested_git_metadata_or_opaque_binary
    refute Dir.exist?(File.join(ROOT, ".git"))

    Dir.glob(File.join(ROOT, "**", "*"), File::FNM_DOTMATCH).each do |path|
      next unless File.file?(path)

      refute_includes File.binread(path), "\0", "NUL byte in #{path}"
    end
  end

  private

  def run_script(*arguments)
    Open3.capture3("/bin/zsh", "-f", SCRIPT, *arguments)
  end
end

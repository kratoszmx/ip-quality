# frozen_string_literal: true

require_relative "support/reporter_test_case"

class RepositoryTest < ReporterTestCase
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
    bundled_cookie_header: /curl[^\n]+(?:\s-b\s|Cookie:)/i,
    embedded_authorization_header: /authorization:/i,
    dynamic_api_key_scrape: /apiKey=/
  }.freeze

  def test_source_is_zsh_native_and_contains_no_removed_runtime_paths
    source = File.binread(SCRIPT)

    assert source.start_with?("#!/bin/zsh\n")
    assert_includes source, "--confirm-network-lookup"
    assert_includes source, "typeset -A"
    assert_includes source, "/bin/zsh -fc"
    refute_match(/^curl_safe\(\)/, source)
    commands = source.lines.reject { |line| line.lstrip.start_with?("#", "local -a required=") }.grep(/\bcurl\s/)
    assert commands.all? { |line| line.match?(/\bcurl -q\s/) }, "curl must ignore user curlrc"
    assert_includes source, 'curl -q "$@" --config -'
    refute_match(/dbip\[score\]\s*=/, source)
    refute_includes source, "shead[command]"
    refute_includes source, "factor_updates"
    refute_match(/jq\s+"\$head_updates/, source)
    BANNED_SOURCE_PATTERNS.each do |name, pattern|
      refute_match pattern, source, "#{name} unexpectedly remains"
    end
  end

  def test_vendored_references_are_regular_local_data_without_cookie_state
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
    assert_includes providers, "Ping0"
    assert_includes providers, "public `/geo`"
    assert_includes providers, "invent a band from local thresholds"
    ["IpScore", "IPLeak", "Whoer", "Wave Broadband", "GreyNoise", "VirusTotal"].each do |candidate|
      assert_includes providers, candidate
    end
    assert_includes license, "GNU AFFERO GENERAL PUBLIC LICENSE"
  end

  def test_project_sources_are_regular_text_without_nested_git_metadata
    refute File.exist?(File.join(ROOT, "README.md"))

    # User reports, private credentials, and caches are not repository sources.
    # Limit traversal before reading any contents, including ignored files.
    paths = Dir.glob(File.join(ROOT, "{bin,common,leaf_runner,providers,report,ref,scripts,test}", "**", "*"), File::FNM_DOTMATCH)
    paths.concat(Dir.glob(File.join(ROOT, "*.md")))
    paths << File.join(ROOT, "LICENSE")
    paths.each do |path|
      refute_equal ".git", File.basename(path), "nested Git metadata: #{path}"
      refute File.symlink?(path), "symlinked source: #{path}"
      next unless File.file?(path)

      refute_includes File.binread(path), "\0", "NUL byte in #{path}"
    end
  end

  def test_obsolete_local_remote_wrapper_is_absent
    refute File.exist?(File.join(ROOT, "scripts", "git-receive-pack-usb-clean"))
  end
end

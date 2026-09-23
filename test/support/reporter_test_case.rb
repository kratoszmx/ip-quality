# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "json"
require "tmpdir"
require "fileutils"

# Shared paths and offline reporter-process fixtures; no provider-specific state.
class ReporterTestCase < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, "bin", "ip-quality")
  DNSBL = File.join(ROOT, "ref", "dnsbl.list")
  ISO3166 = File.join(ROOT, "ref", "iso3166.json")
  COMMON_PROVIDER_LIBRARY = File.join(ROOT, "common", "provider_values.zsh")
  TERMINAL_LIBRARY = File.join(ROOT, "common", "terminal.zsh")
  CREDENTIALS_LIBRARY = File.join(ROOT, "providers", "credentials.zsh")
  IPREGISTRY_LIBRARY = File.join(ROOT, "providers", "ipregistry.zsh")
  IPAPI_LIBRARY = File.join(ROOT, "providers", "ipapi.zsh")
  IPWHOIS_LIBRARY = File.join(ROOT, "providers", "ipwhois.zsh")
  CLOUDFLARE_LIBRARY = File.join(ROOT, "providers", "cloudflare.zsh")
  IPQUALITYSCORE_LIBRARY = File.join(ROOT, "providers", "ipqualityscore.zsh")
  PING0_LIBRARY = File.join(ROOT, "providers", "ping0.zsh")
  RIPESTAT_LIBRARY = File.join(ROOT, "providers", "ripestat.zsh")
  INTERNETDB_LIBRARY = File.join(ROOT, "providers", "shodan_internetdb.zsh")
  REPUTATION_REPORT = File.join(ROOT, "report", "reputation.zsh")
  PING0_GEO_FIXTURE = File.join(ROOT, "test", "fixtures", "ping0", "public-geo.txt")
  PING0_CHALLENGE_FIXTURE = File.join(ROOT, "test", "fixtures", "ping0", "challenge.html")
  RIPESTAT_FIXTURE = File.join(ROOT, "test", "fixtures", "ripestat", "network-info.json")
  INTERNETDB_FIXTURE = File.join(ROOT, "test", "fixtures", "shodan", "internetdb.json")
  INTERNETDB_NO_INFORMATION_FIXTURE = File.join(ROOT, "test", "fixtures", "shodan", "no-information.json")
  IPQUALITYSCORE_CREDITS_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "insufficient-credits.json")
  IPQUALITYSCORE_USAGE_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "usage.json")
  IPREGISTRY_FIXTURE = File.join(ROOT, "test", "fixtures", "ipregistry", "ip-intelligence.json")
  IPAPI_FIXTURE = File.join(ROOT, "test", "fixtures", "ipapi", "valid.json")
  IPAPI_ANONYMOUS_FIXTURE = File.join(ROOT, "test", "fixtures", "ipapi", "anonymous.json")
  IPAPI_MALFORMED_FIXTURE = File.join(ROOT, "test", "fixtures", "ipapi", "malformed.json")
  IPAPI_RATE_LIMIT_FIXTURE = File.join(ROOT, "test", "fixtures", "ipapi", "rate-limited.json")
  IPWHOIS_FIXTURE = File.join(ROOT, "test", "fixtures", "ipwhois", "valid.json")
  IPWHOIS_MISMATCH_FIXTURE = File.join(ROOT, "test", "fixtures", "ipwhois", "mismatch.json")
  CLOUDFLARE_FIXTURE = File.join(ROOT, "test", "fixtures", "cloudflare", "valid.json")
  CLOUDFLARE_EMPTY_FIXTURE = File.join(ROOT, "test", "fixtures", "cloudflare", "empty.json")
  CLOUDFLARE_INVALID_RISK_FIXTURE = File.join(ROOT, "test", "fixtures", "cloudflare", "invalid-risk-type.json")
  IPQUALITYSCORE_OFFICIAL_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "official.json")
  CHECK_PLACE_CLOUDFLARE_FIXTURE = File.join(ROOT, "test", "fixtures", "check_place", "cloudflare-blocked.html")

  def teardown
    FileUtils.remove_entry(@reporter_workspace) if @reporter_workspace
    super
  end

  private

  # Extract only the named top-level functions, without executing CLI startup.
  # This avoids coupling a probe to the order of neighbouring functions.
  def reporter_functions(*names)
    source = File.read(SCRIPT, encoding: "UTF-8")
    names.map do |name|
      source[/^#{Regexp.escape(name)}\(\)\{\n.*?^\}\n(?=\n*(?:[A-Za-z_]\w*\(\)\{|\z))/m] ||
        raise("missing reporter function: #{name}")
    end.join("\n")
  end

  def reporter_workspace
    return @reporter_workspace if @reporter_workspace

    @reporter_workspace = Dir.mktmpdir("ipquality-offline-")
    # Copy explicit runtime inputs only: never traverse project secrets/reports.
    %w[bin/ip-quality common/*.zsh common/*.jq providers/*.zsh report/*.zsh ref/*].each do |pattern|
      Dir.glob(File.join(ROOT, pattern)).each do |source|
        destination = File.join(@reporter_workspace, source.delete_prefix(ROOT + "/"))
        FileUtils.mkdir_p(File.dirname(destination))
        FileUtils.cp(source, destination)
      end
    end
    FileUtils.mkdir_p(File.join(@reporter_workspace, "config"))
    FileUtils.mkdir_p(File.join(@reporter_workspace, "commands"))
    %w[curl dig nslookup nc ssh].each do |command|
      write_fake_command(command, <<~'ZSH')
        print -r -- "${0:t}" >> "$IPQUALITY_TEST_NETWORK_ATTEMPTS"
        print -ru2 -- "unexpected network command in offline test: ${0:t}"
        exit 97
      ZSH
    end
    @reporter_workspace
  end

  def write_fake_command(name, body)
    path = File.join(reporter_workspace, "commands", name)
    File.write(path, "#!/bin/zsh -f\n" + body)
    File.chmod(0o700, path)
    path
  end

  def run_script(*arguments, env: {})
    workspace = reporter_workspace
    attempts = File.join(workspace, "network-attempts")
    environment = {
      "PATH" => "#{workspace}/commands:#{ENV.fetch('PATH')}",
      "XDG_CONFIG_HOME" => File.join(workspace, "config"),
      "IPQUALITY_TEST_NETWORK_ATTEMPTS" => attempts
    }.merge(env)
    result = Open3.capture3(environment, "/bin/zsh", "-f",
                            File.join(workspace, "bin", "ip-quality"), *arguments)
    refute File.exist?(attempts), "reporter attempted an unstubbed network command"
    result
  end
end

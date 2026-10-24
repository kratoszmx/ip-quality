# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "json"
require "tmpdir"
require "fileutils"
require "stringio"
require_relative "utf8_locale"
load File.expand_path("../../bin/ip-quality-route", __dir__) unless defined?(IpQuality::RouteCommand)

# Shared paths and offline reporter/runner fixtures; no provider-specific state.
class ReporterTestCase < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, "bin", "ip-quality")
  RUNNER = File.join(ROOT, "bin", "ip-quality-route")
  REPORTER_SOURCES = [SCRIPT, *Dir.glob(File.join(ROOT, "{common,providers,report}", "*.zsh")).sort].freeze
  DNSBL = File.join(ROOT, "ref", "dnsbl.list")
  ISO3166 = File.join(ROOT, "ref", "iso3166.json")
  COMMON_PROVIDER_LIBRARY = File.join(ROOT, "common", "provider_values.zsh")
  COMMON_HTTP_LIBRARY = File.join(ROOT, "common", "http_request.zsh")
  TERMINAL_LIBRARY = File.join(ROOT, "common", "terminal.zsh")
  REPORT_TABLE_LIBRARY = File.join(ROOT, "report", "table.zsh")
  REPUTATION_REPORT = File.join(ROOT, "report", "reputation.zsh")
  QUERY_ROUTE_LIBRARY = File.join(ROOT, "providers", "query_route.zsh")
  IPQS_FIXTURE = File.join(ROOT, "test", "fixtures", "ipqualityscore", "official.json")
  # Unset every proxy variable the reporter honours, for direct-route cases.
  NO_PROXY_ENV = %w[HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy
                    IPQUALITY_ISOLATED_EGRESS].to_h { |name| [name, nil] }.freeze

  def setup
    super
    @reporter_workspace = nil
  end

  def teardown
    FileUtils.remove_entry(@reporter_workspace) if @reporter_workspace
    super
  end

  private

  def provider_library(name)
    File.join(ROOT, "providers", "#{name}.zsh")
  end

  def fixture_path(name)
    File.join(ROOT, "test", "fixtures", name)
  end

  def fixture_json(name)
    JSON.parse(File.read(fixture_path(name)))
  end

  # Run a zsh probe with positional arguments; returns [stdout, stderr, status].
  def zsh(probe, *arguments, **options)
    Open3.capture3("/bin/zsh", "-f", "-c", probe, "probe", *arguments, **options)
  end

  # Run a probe that must succeed silently and return its stdout.
  def zsh!(probe, *arguments, **options)
    stdout, stderr, status = zsh(probe, *arguments, **options)
    assert status.success?, stderr
    assert_empty stderr
    stdout
  end

  # Extract named top-level functions from the reporter or its modules, without
  # executing CLI startup or coupling a probe to the defining file.
  def reporter_functions(*names)
    sources = REPORTER_SOURCES.map do |path|
      File.read(path, encoding: "UTF-8").split(/^# Sourcing loads definitions only/, 2).first
    end
    names.map do |name|
      pattern = /^#{Regexp.escape(name)}\(\)\{\n.*?^\}\n(?=\n*(?:[A-Za-z_]\w*\(\)\{|\z))/m
      sources.map { |source| source[pattern] }.compact.first ||
        raise("missing reporter function: #{name}")
    end.join("\n")
  end

  def reporter_workspace
    return @reporter_workspace if @reporter_workspace

    @reporter_workspace = Dir.mktmpdir("ipquality-offline-")
    # Copy explicit runtime inputs only: never traverse project secrets/reports.
    %w[bin/ip-quality common/*.zsh common/*.jq providers/*.zsh providers/*.tsv report/*.zsh ref/*].each do |pattern|
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

  # A workspace-private IPQS key, so official IPQS paths run without real secrets.
  def write_ipqs_key
    FileUtils.mkdir_p(File.join(reporter_workspace, "secrets"))
    File.write(File.join(reporter_workspace, "secrets", "ipqs"), "fixturekey123", perm: 0o600)
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

  # Run the route command in-process; returns [exit code, stdout, stderr]. The
  # default app root is absent, so no case reads the real Clash Verge cache.
  def run_route(arguments, stdin: "", app_root: File.join(Dir.tmpdir, "ipquality-absent-clash"), **options)
    stdout = StringIO.new
    stderr = StringIO.new
    command = IpQuality::RouteCommand.new(stdout: stdout, stderr: stderr, stdin: StringIO.new(stdin),
                                          app_root: app_root, **options)
    [command.run(arguments), stdout.string, stderr.string]
  end

  def with_environment(overrides)
    previous = overrides.each_key.to_h { |key| [key, ENV.key?(key) ? ENV[key] : :missing] }
    overrides.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      value == :missing ? ENV.delete(key) : ENV[key] = value
    end
  end
end

# frozen_string_literal: true

require "English"
require "optparse"
require_relative "clash_leaf_profile"
require_relative "isolated_mihomo_session"

module IpQuality
  class ClashLeafCommand
    EX_USAGE = 64
    EX_NOINPUT = 66
    EX_UNAVAILABLE = 69
    EX_SOFTWARE = 70
    REPORTER = File.expand_path("../ip-quality.zsh", __dir__).freeze

    def initialize(stdout: $stdout, stderr: $stderr, stdin: $stdin)
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
      @profile_path = nil
      @mihomo_path = IsolatedMihomoSession::DEFAULT_MIHOMO
      @leaf_name = nil
      @select = false
      @list = false
      @confirmed = false
      @config_test_only = false
      @help_requested = false
      @report_arguments = []
      @family = nil
    end

    def run(arguments)
      parser = option_parser
      parser.parse!(arguments)
      raise OptionParser::InvalidOption, arguments.join(" ") unless arguments.empty?
      if @help_requested
        @stdout.puts parser
        return 0
      end

      validate_option_combinations!
      source = load_source
      profile = ClashLeafProfile.new(source)

      if @list
        print_leaf_list(profile.leaf_names)
        return 0
      end

      selected = @select ? select_leaf(profile.leaf_names) : @leaf_name
      ensure_exact_leaf!(profile, selected)

      unless @confirmed || @config_test_only
        print_plan(source, selected)
        return 0
      end

      session = IsolatedMihomoSession.new(
        profile,
        selected,
        mihomo_path: @mihomo_path
      )
      if @config_test_only
        session.configuration_test
        @stdout.puts "CONFIG TEST OK: exact leaf #{selected.inspect} renders as an isolated loopback-only Mihomo profile."
        return 0
      end

      run_live_report(session, source, selected)
    rescue OptionParser::ParseError => error
      @stderr.puts "ERROR: #{error.message}"
      @stderr.puts parser
      EX_USAGE
    rescue ClashLeafProfile::Error, SafeSnapshot::Error => error
      @stderr.puts "ERROR: #{error.message}"
      EX_NOINPUT
    rescue IsolatedMihomoSession::Error => error
      @stderr.puts "ERROR: #{error.message}"
      EX_UNAVAILABLE
    rescue Interrupt
      @stderr.puts "Interrupted; isolated Mihomo cleanup completed."
      130
    rescue StandardError => error
      @stderr.puts "ERROR: isolated leaf runner failed safely (#{error.class})."
      EX_SOFTWARE
    end

    private

    def option_parser
      OptionParser.new do |options|
        options.banner = <<~BANNER
          Usage:
            test-clash-leaf --list-leaves [--profile PATH]
            test-clash-leaf --select --confirm-network-lookup [-4|-6] [-f] [-j]
            test-clash-leaf --leaf NAME --config-test-only [--profile PATH]

          The current Clash profile is read only. A selected leaf is copied into a
          temporary 127.0.0.1-only Mihomo process; the live subscription and current
          Clash selection are never changed.
        BANNER
        options.on("--list-leaves", "List exact inline leaf names without network access") { @list = true }
        options.on("--select", "Choose one exact leaf from an interactive numbered list") { @select = true }
        options.on("--leaf NAME", "Select one exact leaf name non-interactively") { |value| @leaf_name = value }
        options.on("--profile PATH", "Use an explicit local profile instead of the active Clash Verge profile") { |value| @profile_path = value }
        options.on("--mihomo PATH", "Use an explicit local Mihomo executable") { |value| @mihomo_path = value }
        options.on("--config-test-only", "Render and run Mihomo -t only; start no listener and make no lookup") { @config_test_only = true }
        options.on("--confirm-network-lookup", "Authorize the isolated reputation lookup") { @confirmed = true }
        options.on("-4", "Test IPv4 only") { choose_family("-4") }
        options.on("-6", "Test IPv6 only") { choose_family("-6") }
        options.on("-f", "Show the full tested IP in the local report") { @report_arguments << "-f" }
        options.on("-j", "Write JSON report to stdout") { @report_arguments << "-j" }
        options.on("-E", "Use English report labels") { @report_arguments << "-E" }
        options.on("-l LANGUAGE", "Use reporter language: cn, en, jp, es, de, fr, ru, or pt") do |value|
          allowed = %w[cn en jp es de fr ru pt]
          raise OptionParser::InvalidArgument, "unsupported language" unless allowed.include?(value.downcase)

          @report_arguments.concat(["-l", value.downcase])
        end
        options.on("-o PATH", "Create a new local report file (existing paths are rejected)") do |value|
          @report_arguments.concat(["-o", value])
        end
        options.on("-h", "--help", "Show this help") do
          @help_requested = true
        end
      end
    end

    def validate_option_combinations!
      selectors = [@list, @select, !@leaf_name.nil?].count(true)
      raise OptionParser::InvalidArgument, "choose exactly one of --list-leaves, --select, or --leaf" unless selectors == 1
      if @list && (@confirmed || @config_test_only || !@report_arguments.empty? || @family)
        raise OptionParser::InvalidArgument, "--list-leaves cannot be combined with lookup or report options"
      end
      if @confirmed && @config_test_only
        raise OptionParser::InvalidArgument, "--config-test-only and --confirm-network-lookup are mutually exclusive"
      end
    end

    def choose_family(value)
      if @family && @family != value
        raise OptionParser::InvalidArgument, "-4 and -6 are mutually exclusive"
      end
      @family = value
    end

    def load_source
      if @profile_path
        ClashLeafProfile.from_file(@profile_path)
      else
        ClashLeafProfile.from_active_clash_verge
      end
    end

    def print_leaf_list(names)
      raise ClashLeafProfile::Error, "the selected profile has no inline leaf proxies" if names.empty?

      names.each_with_index { |name, index| @stdout.printf("%3d  %s\n", index + 1, name) }
      @stdout.puts "#{names.length} inline leaves; proxy groups and DIRECT/REJECT are excluded."
    end

    def select_leaf(names)
      raise ClashLeafProfile::Error, "the selected profile has no inline leaf proxies" if names.empty?

      print_leaf_list(names)
      @stdout.print "Select one leaf number: "
      @stdout.flush
      answer = @stdin.gets
      raise OptionParser::InvalidArgument, "no leaf selection was entered" unless answer

      stripped = answer.strip
      unless stripped.match?(/\A[0-9]+\z/) && stripped.to_i.between?(1, names.length)
        raise OptionParser::InvalidArgument, "leaf selection must be a listed number"
      end
      names.fetch(stripped.to_i - 1)
    end

    def ensure_exact_leaf!(profile, selected)
      unless selected && profile.leaf_names.include?(selected)
        raise ClashLeafProfile::Error, "the requested name is not one exact inline leaf"
      end
    end

    def print_plan(source, selected)
      @stdout.puts "Isolated Clash leaf plan (no network access has occurred)"
      @stdout.puts "  source: #{source.description}"
      @stdout.puts "  exact leaf: #{selected}"
      @stdout.puts "  live Clash profile/selection: read only and unchanged"
      @stdout.puts "  runtime: temporary Mihomo bound only to 127.0.0.1 on a random port"
      @stdout.puts "  reporter scope: reputation only (HTTP(S) requests forced through the isolated leaf)"
      @stdout.puts "  Ping0: official public geo/ASN/organization observation; public endpoint has no risk score"
      @stdout.puts "  start gate: add --confirm-network-lookup"
    end

    def run_live_report(session, source, selected)
      @stderr.puts "[leaf-runner] Read-only source: #{source.description}"
      @stderr.puts "[leaf-runner] Starting isolated loopback Mihomo for exact leaf #{selected.inspect}"
      result = nil
      session.with_running do |running|
        @stderr.puts "[leaf-runner] Listener ownership verified at 127.0.0.1:#{running.port}"
        command = [
          "/bin/zsh",
          "-f",
          REPORTER,
          "--confirm-network-lookup",
          "--scope",
          "reputation"
        ]
        command << @family if @family
        command.concat(@report_arguments)
        system(running.proxy_environment, *command)
        result = $CHILD_STATUS
      end
      @stderr.puts "[leaf-runner] Isolated Mihomo stopped; live Clash state was not changed."
      return 0 if result && result.success?

      result && result.exitstatus ? result.exitstatus : 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  exit(IpQuality::ClashLeafCommand.new.run(ARGV))
end

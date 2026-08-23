# frozen_string_literal: true

require "English"
require "optparse"
require_relative "profile"
require_relative "subscription_catalog"
require_relative "isolated_mihomo_session"

module IpQuality
  class ClashLeafCommand
    EX_USAGE = 64
    EX_NOINPUT = 66
    EX_UNAVAILABLE = 69
    EX_SOFTWARE = 70
    REPORTER = File.expand_path("../ip-quality.zsh", __dir__).freeze

    def initialize(stdout: $stdout, stderr: $stderr, stdin: $stdin, app_root: SubscriptionCatalog::DEFAULT_APP_ROOT)
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
      @app_root = app_root
      @profile_path = nil
      @mihomo_path = IsolatedMihomoSession::DEFAULT_MIHOMO
      @subscription_name = nil
      @leaf_name = nil
      @list_subscriptions = false
      @list_leaves = false
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
      if @list_subscriptions
        print_subscription_list(subscription_catalog.entries)
        return 0
      end

      source = load_source
      profile = ClashLeafProfile.new(source)

      if @list_leaves
        print_leaf_list(profile.leaf_names)
        return 0
      end

      selected = @leaf_name || select_leaf(profile.leaf_names)
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

      run_live_report(session)
    rescue OptionParser::ParseError => error
      @stderr.puts "ERROR: #{error.message}"
      @stderr.puts parser
      EX_USAGE
    rescue ClashLeafProfile::Error, SubscriptionCatalog::Error, SafeSnapshot::Error => error
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
            test-clash-leaf --confirm-network-lookup [-4|-6] [-f] [-j]
            test-clash-leaf --list-subscriptions
            test-clash-leaf --subscription NAME --list-leaves
            test-clash-leaf --profile PATH --leaf NAME --config-test-only

          By default, choose one cached remote Clash Verge subscription and then one
          exact inline leaf. The active profile is never used or changed. The leaf is
          copied into a temporary 127.0.0.1-only Mihomo process.
        BANNER
        options.on("--list-subscriptions", "List cached remote subscription names without network access") { @list_subscriptions = true }
        options.on("--list-leaves", "List exact inline leaf names without network access") { @list_leaves = true }
        options.on("--select", "Compatibility flag; interactive selection is now the default") { nil }
        options.on("--subscription NAME", "Select one cached remote subscription by exact display name") { |value| @subscription_name = value }
        options.on("--leaf NAME", "Select one exact leaf name non-interactively") { |value| @leaf_name = value }
        options.on("--profile PATH", "Use an explicit local profile instead of a cached subscription") { |value| @profile_path = value }
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
      if @profile_path && @subscription_name
        raise OptionParser::InvalidArgument, "--profile and --subscription are mutually exclusive"
      end
      if @list_subscriptions && (@profile_path || @subscription_name || @leaf_name || @list_leaves || @confirmed || @config_test_only || !@report_arguments.empty? || @family)
        raise OptionParser::InvalidArgument, "--list-subscriptions cannot be combined with source, leaf, lookup, or report options"
      end
      if @list_leaves && (@leaf_name || @confirmed || @config_test_only || !@report_arguments.empty? || @family)
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
      return ClashLeafProfile.from_file(@profile_path) if @profile_path

      catalog = subscription_catalog
      entry = @subscription_name ? catalog.find_exact(@subscription_name) : select_subscription(catalog.entries)
      catalog.source_for(entry)
    end

    def subscription_catalog
      @subscription_catalog ||= SubscriptionCatalog.new(app_root: @app_root)
    end

    def print_subscription_list(entries)
      @stdout.puts "Cached remote subscriptions:"
      entries.each_with_index { |entry, index| @stdout.printf("%3d  %s\n", index + 1, entry.name) }
    end

    def select_subscription(entries)
      print_subscription_list(entries)
      @stdout.print "Select one subscription number: "
      @stdout.flush
      entries.fetch(read_selection(entries.length, "subscription"))
    end

    def print_leaf_list(names)
      raise ClashLeafProfile::Error, "the selected profile has no inline leaf proxies" if names.empty?

      @stdout.puts "Available inline leaves (groups and built-ins excluded):"
      names.each_with_index { |name, index| @stdout.printf("%3d  %s\n", index + 1, name) }
    end

    def select_leaf(names)
      raise ClashLeafProfile::Error, "the selected profile has no inline leaf proxies" if names.empty?

      print_leaf_list(names)
      @stdout.print "Select one leaf number: "
      @stdout.flush
      names.fetch(read_selection(names.length, "leaf"))
    end

    def read_selection(length, label)
      answer = @stdin.gets
      raise OptionParser::InvalidArgument, "no #{label} selection was entered" unless answer

      stripped = answer.strip
      unless stripped.match?(/\A[0-9]+\z/) && stripped.to_i.between?(1, length)
        raise OptionParser::InvalidArgument, "#{label} selection must be a listed number"
      end
      stripped.to_i - 1
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
      @stdout.puts "  RIPEstat: official routed-prefix/origin-ASN context; not a risk score"
      @stdout.puts "  Shodan InternetDB: official IPv4 exposure context; not a risk score"
      @stdout.puts "  start gate: add --confirm-network-lookup"
    end

    def run_live_report(session)
      @stderr.puts "[leaf-runner] Testing the selected cached-subscription leaf through isolated loopback Mihomo."
      result = nil
      session.with_running do |running|
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
      @stderr.puts "[leaf-runner] Isolated Mihomo stopped; live Clash state was unchanged."
      return 0 if result && result.success?

      result && result.exitstatus ? result.exitstatus : 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  exit(IpQuality::ClashLeafCommand.new.run(ARGV))
end

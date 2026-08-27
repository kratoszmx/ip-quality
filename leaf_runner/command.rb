# frozen_string_literal: true

require "optparse"
require "ipaddr"
require_relative "network_environment"
require_relative "profile"
require_relative "subscription_catalog"
require_relative "isolated_mihomo_session"

module IpQuality
  class ClashLeafCommand
    EX_USAGE = 64
    EX_NOINPUT = 66
    EX_UNAVAILABLE = 69
    EX_SOFTWARE = 70
    REPORTER = File.expand_path("../bin/ip-quality", __dir__).freeze
    CLEANUP_SIGNALS = %w[HUP TERM].freeze
    REPORTER_STOP_TIMEOUT_SECONDS = 3

    def initialize(
      stdout: $stdout,
      stderr: $stderr,
      stdin: $stdin,
      app_root: SubscriptionCatalog::DEFAULT_APP_ROOT,
      reporter_path: REPORTER
    )
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
      @app_root = app_root
      @reporter_path = reporter_path
      @profile_path = nil
      @mihomo_path = IsolatedMihomoSession::DEFAULT_MIHOMO
      @subscription_name = nil
      @leaf_name = nil
      @list_subscriptions = false
      @list_leaves = false
      @direct = false
      @specific_ip = nil
      @route_scope = "reputation"
      @confirmed = false
      @config_test_only = false
      @mihomo_explicit = false
      @help_requested = false
      @report_arguments = []
      @family = nil
      @previous_signal_handlers = {}
    end

    def run(arguments)
      parser = option_parser
      install_cleanup_signal_handlers
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

      if @direct
        configure_comprehensive_direct_route!
        return run_direct_route
      end

      source = load_selected_source
      if source == :direct
        configure_comprehensive_direct_route!
        return run_direct_route
      end
      if source == :specific_ip
        @specific_ip = select_specific_ip
        return run_direct_route
      end

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
      @stderr.puts "Interrupted; child-process cleanup completed."
      130
    rescue StandardError => error
      @stderr.puts "ERROR: route runner failed safely (#{error.class})."
      EX_SOFTWARE
    ensure
      restore_cleanup_signal_handlers
    end

    private

    def option_parser
      OptionParser.new do |options|
        options.banner = <<~BANNER
          Usage:
            test-clash-leaf --confirm-network-lookup [-4|-6] [-f] [-j]
            test-clash-leaf --direct --confirm-network-lookup [-4|-6] [-f] [-j]
            test-clash-leaf --list-subscriptions
            test-clash-leaf --subscription NAME --list-leaves
            test-clash-leaf --profile PATH --leaf NAME --config-test-only

          By default, choose one comprehensive direct report or one cached remote
          Clash Verge subscription. The menu also accepts one specific public
          target IP. A subscription route then asks for one exact inline leaf.
          The direct report combines reputation, media/AI, mail connectivity, and
          DNSBL observations over the current system IPv4 route. Specific-IP
          lookups remain reputation-only. Direct and specific-IP lookups remove
          proxy environment variables. A leaf is copied into a temporary
          127.0.0.1-only Mihomo process. The active Clash profile is never used or
          changed.
        BANNER
        options.on("--list-subscriptions", "List cached remote subscription names without network access") { @list_subscriptions = true }
        options.on("--list-leaves", "List exact inline leaf names without network access") { @list_leaves = true }
        options.on("--select", "Compatibility flag; interactive selection is now the default") { nil }
        options.on("--direct", "Run the comprehensive report over the current system IPv4 route") { @direct = true }
        options.on("--subscription NAME", "Select one cached remote subscription by exact display name") { |value| @subscription_name = value }
        options.on("--leaf NAME", "Select one exact leaf name non-interactively") { |value| @leaf_name = value }
        options.on("--profile PATH", "Use an explicit local profile instead of a cached subscription") { |value| @profile_path = value }
        options.on("--mihomo PATH", "Use an explicit local Mihomo executable") do |value|
          @mihomo_path = value
          @mihomo_explicit = true
        end
        options.on("--config-test-only", "Render and run Mihomo -t only; start no listener and make no lookup") { @config_test_only = true }
        options.on("--confirm-network-lookup", "Authorize the selected route's live reputation lookup") { @confirmed = true }
        options.on("-4", "Test IPv4 only") { choose_family("-4") }
        options.on("-6", "Test IPv6 only") { choose_family("-6") }
        options.on("-f", "Show the full tested IP in the local report") { @report_arguments << "-f" }
        options.on("-j", "Write JSON report to stdout") { @report_arguments << "-j" }
        options.on("-E", "Use English report labels") { @report_arguments << "-E" }
        options.on("-l LANGUAGE", "Use reporter language: cn or en") do |value|
          allowed = %w[cn en]
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
      if @direct && (@profile_path || @subscription_name || @leaf_name || @list_leaves || @config_test_only || @mihomo_explicit)
        raise OptionParser::InvalidArgument, "--direct cannot be combined with subscription, leaf, profile, Mihomo, or config-test options"
      end
      if @list_subscriptions && (@direct || @profile_path || @subscription_name || @leaf_name || @list_leaves || @confirmed || @config_test_only || @mihomo_explicit || !@report_arguments.empty? || @family)
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

    def load_selected_source
      return ClashLeafProfile.from_file(@profile_path) if @profile_path

      catalog = subscription_catalog
      entry = if @subscription_name
                catalog.find_exact(@subscription_name)
              elsif combined_route_selection?
                select_route(catalog.entries)
              else
                select_subscription(catalog.entries)
              end
      return entry if %i[direct specific_ip].include?(entry)

      catalog.source_for(entry)
    end

    def combined_route_selection?
      !@leaf_name && !@list_leaves && !@config_test_only && !@mihomo_explicit
    end

    def subscription_catalog
      @subscription_catalog ||= SubscriptionCatalog.new(app_root: @app_root)
    end

    def print_subscription_list(entries)
      @stdout.puts "Cached remote subscriptions:"
      entries.each_with_index { |entry, index| @stdout.printf("%3d  %s\n", index + 1, entry.name) }
    end

    def print_route_list(entries)
      @stdout.puts "Available test routes:"
      @stdout.puts "  1  Direct comprehensive report (reputation + media/AI + mail + DNSBL; system IPv4 route)"
      @stdout.puts "  2  Specific IP lookup (enter one public target; current system route)"
      entries.each_with_index do |entry, index|
        @stdout.printf("%3d  Cached subscription: %s\n", index + 3, entry.name)
      end
    end

    def select_route(entries)
      print_route_list(entries)
      @stdout.print "Select one route number: "
      @stdout.flush
      selected = read_selection(entries.length + 2, "route")
      return :direct if selected.zero?
      return :specific_ip if selected == 1

      entries.fetch(selected - 2)
    end

    def select_specific_ip
      @stdout.print "Enter one public IP address to inspect: "
      @stdout.flush
      answer = @stdin.gets
      raise OptionParser::InvalidArgument, "no specific IP was entered" unless answer

      candidate = answer.strip
      unless candidate.bytesize.between?(2, 64) && candidate.match?(/\A[0-9A-Fa-f:.]+\z/)
        raise OptionParser::InvalidArgument, "specific IP must be one valid public address"
      end
      address = IPAddr.new(candidate)
      if (@family == "-4" && !address.ipv4?) || (@family == "-6" && !address.ipv6?)
        raise OptionParser::InvalidArgument, "specific IP conflicts with the selected address family"
      end
      address.to_s
    rescue IPAddr::InvalidAddressError
      raise OptionParser::InvalidArgument, "specific IP must be one valid public address"
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

    def print_direct_plan
      if @specific_ip
        @stdout.puts "Specific IP lookup plan (no network access has occurred)"
        @stdout.puts "  target: #{@specific_ip}"
        @stdout.puts "  route: current system route with inherited proxy environment removed"
        @stdout.puts "  runtime: reporter only; no temporary Mihomo process"
        @stdout.puts "  reporter scope: reputation only; providers receive the explicit target"
        @stdout.puts "  Ping0: skipped because its public /geo endpoint reports only the caller's egress"
        @stdout.puts "  start gate: add --confirm-network-lookup"
        return
      end
      @stdout.puts "Comprehensive direct route plan (no network access has occurred)"
      @stdout.puts "  route: current system IPv4 route with inherited proxy environment removed"
      @stdout.puts "  live Clash profile/selection: read only and unchanged"
      @stdout.puts "  runtime: reporter only; no temporary Mihomo process"
      @stdout.puts "  reporter scope: reputation + media/AI + mail connectivity + DNSBL"
      @stdout.puts "  mail: outbound TCP/25 and public MX greeting probes"
      @stdout.puts "  DNSBL: every vendored zone is queried with bounded concurrency"
      @stdout.puts "  measurement boundary: current system route only; no subscription leaf is claimed"
      @stdout.puts "  note: an active system-level VPN or TUN can still influence the system route"
      @stdout.puts "  start gate: add --confirm-network-lookup"
    end

    def configure_comprehensive_direct_route!
      raise OptionParser::InvalidArgument, "the comprehensive direct report requires IPv4" if @family == "-6"

      @family ||= "-4"
      @route_scope = "full"
    end

    def run_direct_route
      unless @confirmed
        print_direct_plan
        return 0
      end

      if @specific_ip
        @stderr.puts "[route-runner] Inspecting specific IP #{@specific_ip} through provider target parameters over the current system route; no Mihomo process is started."
      else
        @stderr.puts "[route-runner] Testing the comprehensive direct report through the current system IPv4 route; no Mihomo process is started."
      end
      result = run_reporter(NetworkEnvironment.without_proxy_variables, reporter_command)
      if @specific_ip
        @stderr.puts "[route-runner] Specific-IP report finished; live Clash state was unchanged."
      else
        @stderr.puts "[route-runner] Comprehensive direct report finished; live Clash state was unchanged."
      end
      return 0 if result.success?

      result.exitstatus || 1
    end

    def run_live_report(session)
      @stderr.puts "[leaf-runner] Testing the selected cached-subscription leaf through isolated loopback Mihomo."
      result = nil
      session.with_running do |running|
        result = run_reporter(running.proxy_environment, reporter_command)
      end
      @stderr.puts "[leaf-runner] Isolated Mihomo stopped; live Clash state was unchanged."
      return 0 if result && result.success?

      result && result.exitstatus ? result.exitstatus : 1
    end

    def reporter_command
      command = [
        "/bin/zsh",
        "-f",
        @reporter_path,
        "--confirm-network-lookup",
        "--scope",
        @route_scope
      ]
      command << @family if @family
      command.concat(@report_arguments)
      command << @specific_ip if @specific_ip
      command
    end

    def install_cleanup_signal_handlers
      CLEANUP_SIGNALS.each do |signal_name|
        @previous_signal_handlers[signal_name] = Signal.trap(signal_name) do
          raise Interrupt, "SIG#{signal_name}"
        end
      end
    end

    def restore_cleanup_signal_handlers
      @previous_signal_handlers.each do |signal_name, handler|
        Signal.trap(signal_name, handler)
      end
      @previous_signal_handlers.clear
    end

    def run_reporter(environment, command)
      pid = Process.spawn(environment, *command, pgroup: true)
      _waited_pid, status = Process.wait2(pid)
      pid = nil
      status
    ensure
      terminate_reporter_process_group(pid) if pid
    end

    def terminate_reporter_process_group(pid)
      begin
        Process.kill("TERM", -pid)
      rescue Errno::ESRCH
        Process.waitpid(pid)
        return
      end
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + REPORTER_STOP_TIMEOUT_SECONDS
      loop do
        waited = Process.waitpid2(pid, Process::WNOHANG)
        return if waited
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.05
      end

      Process.kill("KILL", -pid)
      Process.waitpid(pid)
    rescue Errno::ECHILD, Errno::ESRCH
      nil
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  exit(IpQuality::ClashLeafCommand.new.run(ARGV))
end

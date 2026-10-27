# frozen_string_literal: true

require_relative "../runner/safe_snapshot"
require_relative "../runner/text"
require_relative "support/reporter_test_case"
require "minitest/mock"
require "timeout"
require "yaml"

class RouteRunnerTest < ReporterTestCase
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
      code, stdout, stderr = run_route([], stdin: "4\n2\n", app_root: directory)

      assert_equal 0, code
      ["Available test routes:", "Direct IP reputation report", "Specific IP lookup",
       "Cached subscription: Fixture Remote", "Available inline leaves", "exact leaf: TargetLeaf",
       "one direct IPv4 fallback queries the same leaf IP", "both route outcomes remain visible",
       "same provider also sees the system-route egress"].each { |text| assert_includes stdout, text }
      refute_match(/\d+ inline leaves/, stdout)
      assert_empty stderr
    end
  end

  def test_direct_plans_need_no_clash_cache_and_start_no_mihomo
    Dir.mktmpdir("ip-quality-direct-select-") do |directory|
      write_clash_verge_fixture(directory)
      code, stdout, stderr = run_route([], stdin: "1\n", app_root: directory)
      assert_equal 0, code
      ["Available test routes:", "Direct reputation route plan", "reputation only",
       "no temporary Mihomo process"].each { |text| assert_includes stdout, text }
      refute_includes stdout, "Available inline leaves"
      assert_empty stderr
    end

    code, stdout, stderr = run_route(["--direct", "-4"])
    assert_equal 0, code
    ["Direct reputation route plan", "current system route", "system-level VPN or TUN"].each do |text|
      assert_includes stdout, text
    end
    refute_match(/media\/AI|DNSBL/, stdout)
    assert_empty stderr
  end

  def test_live_direct_and_specific_ip_routes_clear_proxies_and_forward_report_options
    Dir.mktmpdir("ip-quality-direct-live-") do |directory|
      write_clash_verge_fixture(directory)
      fake_reporter = File.join(directory, "fake-reporter")
      arguments_file = File.join(directory, "arguments.txt")
      File.write(fake_reporter, <<~'ZSH')
        [[ -z "${HTTP_PROXY+x}${https_proxy+x}${No_PrOxY+x}" ]] || exit 71
        print -r -- "$@" > "$IPQUALITY_TEST_ARGUMENTS_FILE"
      ZSH
      File.chmod(0o700, fake_reporter)
      # [arguments, menu input, forwarded reporter arguments, stdout and stderr markers]
      cases = [
        [%w[--direct --confirm-network-lookup -4 -j], "", "--confirm-network-lookup --scope reputation -4 -j",
         [], ["no Mihomo process is started", "live Clash state was unchanged"]],
        [%w[--confirm-network-lookup -f], "1\n", "--confirm-network-lookup --scope reputation -4 -f",
         ["Direct IP reputation report"], ["current system IPv4 route", "Direct reputation report finished"]],
        [%w[--confirm-network-lookup -4 -f], "2\n12.217.32.68\n",
         "--confirm-network-lookup --scope reputation -4 -f 12.217.32.68",
         ["Specific IP lookup", "Enter one public IP address"],
         ["Inspecting specific IP 12.217.32.68", "Specific-IP report finished"]]
      ]
      proxies = {"HTTP_PROXY" => "http://127.0.0.1:1", "https_proxy" => "http://127.0.0.1:2",
                 "No_PrOxY" => "fixture.invalid", "IPQUALITY_TEST_ARGUMENTS_FILE" => arguments_file}
      cases.each do |arguments, stdin, forwarded, menu, progress|
        code, stdout, stderr = with_environment(proxies) do
          run_route(arguments, stdin: stdin, app_root: directory, reporter_path: fake_reporter)
        end
        assert_equal 0, code, stderr
        assert_equal "#{forwarded}\n", File.read(arguments_file)
        menu.each { |text| assert_includes stdout, text }
        progress.each { |text| assert_includes stderr, text }
        refute_includes stdout, "Available inline leaves"
        assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"))
      end
      assert_includes run_route(["-6"], stdin: "1\n", app_root: directory, reporter_path: fake_reporter)[1], "IPv6 route"
    end
  end

  def test_usage_errors_stop_before_any_lookup
    Dir.mktmpdir("ip-quality-specific-ip-reject-") do |directory|
      write_clash_verge_fixture(directory)
      code, _stdout, stderr = run_route([], stdin: "2\nnot-an-ip\n", app_root: directory)
      assert_equal IpQuality::RouteCommand::EX_USAGE, code
      assert_includes stderr, "specific IP must be one valid public address"
      code, _stdout, stderr = run_route(["-4"], stdin: "2\n2001:db8::1\n", app_root: directory)
      assert_equal IpQuality::RouteCommand::EX_USAGE, code
      assert_includes stderr, "conflicts with the selected address family"
    end
    {
      %w[--direct --leaf TargetLeaf] => "--direct cannot be combined",
      %w[--profile p.yaml --subscription s] => "--profile and --subscription are mutually exclusive",
      %w[--list-subscriptions -4] => "--list-subscriptions cannot be combined",
      %w[--subscription s --list-leaves --leaf TargetLeaf] => "--list-leaves cannot be combined",
      %w[--profile p.yaml --leaf TargetLeaf --config-test-only --confirm-network-lookup] => "mutually exclusive",
      %w[-4 -6] => "-4 and -6 are mutually exclusive",
      %w[--select --direct] => "--select",
      %w[-l jp] => "unsupported language"
    }.each do |arguments, message|
      code, stdout, stderr = run_route(arguments)
      assert_equal IpQuality::RouteCommand::EX_USAGE, code, arguments.join(" ")
      assert_includes stderr, message
      assert_empty stdout
    end
  end

  def test_non_interactive_listing_and_leaf_plans_use_exact_cached_names
    Dir.mktmpdir("ip-quality-cli-") do |directory|
      write_clash_verge_fixture(directory)
      code, stdout, stderr = run_route(["--list-subscriptions"], app_root: directory)
      assert_equal [0, "Cached remote subscriptions:\n  1  Fixture Remote\n", ""], [code, stdout.rstrip + "\n", stderr]
      code, stdout, = run_route(["--subscription", "Fixture Remote", "--list-leaves"], app_root: directory)
      assert_equal 0, code
      assert_match(/1  TransportLeaf\n  2  TargetLeaf/, stdout)
      code, stdout, = run_route(["--subscription", "Fixture Remote", "--leaf", "TargetLeaf", "-4"], app_root: directory)
      assert_equal 0, code
      ["no network access has occurred", 'source: cached remote subscription "Fixture Remote"',
       "exact leaf: TargetLeaf", "start gate: add --confirm-network-lookup"].each { |text| assert_includes stdout, text }
      {
        ["--subscription", "Missing", "--list-leaves"] => "no cached remote subscription has that exact name",
        ["--subscription", "Fixture Remote", "--leaf", "Target", "-4"] => "not one exact inline leaf"
      }.each do |arguments, message|
        code, stdout, stderr = run_route(arguments, app_root: directory)
        assert_equal IpQuality::RouteCommand::EX_NOINPUT, code, arguments.join(" ")
        assert_includes stderr, message
        assert_empty stdout
      end
    end
  end

  def test_config_test_only_runs_mihomo_check_without_listener_or_reporter
    Dir.mktmpdir("ip-quality-config-test-") do |directory|
      profile_path = File.join(directory, "profile.yaml")
      write_private_yaml(profile_path, fixture_document)
      arguments_file = File.join(directory, "mihomo-arguments")
      fake_mihomo = File.join(directory, "fake-mihomo")
      File.write(fake_mihomo, "#!/bin/zsh\nprint -r -- \"$@\" > #{arguments_file}\n", perm: 0o700)
      reporter = File.join(directory, "reporter-must-not-run")
      constructor = IpQuality::IsolatedMihomoSession.method(:new)
      factory = ->(*arguments, **options) { constructor.call(*arguments, **options.merge(temp_parent: directory)) }
      code, stdout, stderr = IpQuality::IsolatedMihomoSession.stub(:new, factory) do
        run_route(["--profile", profile_path, "--leaf", "TargetLeaf", "--mihomo", fake_mihomo, "--config-test-only"],
          reporter_path: reporter)
      end
      assert_equal 0, code, stderr
      assert_includes stdout, 'CONFIG TEST OK: exact leaf "TargetLeaf"'
      assert_match(/(?:\A|\s)-t(?:\s|\z)/, File.read(arguments_file))
      assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"), File::FNM_DOTMATCH)
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

  def test_leaf_names_must_be_unique_printable_and_distinct_from_mihomo_builtins
    duplicate = fixture_document
    duplicate["proxies"] << duplicate["proxies"].last.dup
    builtin = fixture_document
    builtin["proxies"].first["name"] = "DIRECT"
    cases = [[duplicate, "duplicate leaf proxy name"], [builtin, "collides with Mihomo builtin"]]
    ["bad\nname", "葉" * 171].each do |name|
      document = fixture_document
      document["proxies"].first["name"] = name
      cases << [document, "bounded, printable name"]

      # Subscription names share the same printable byte limit.
      Dir.mktmpdir("ip-quality-subscription-name-") do |directory|
        write_clash_verge_fixture(directory)
        registry_path = File.join(directory, "profiles.yaml")
        registry = YAML.safe_load(File.read(registry_path))
        registry.fetch("items").last["name"] = name
        write_private_yaml(registry_path, registry)
        error = assert_raises(IpQuality::SubscriptionCatalog::Error) do
          IpQuality::SubscriptionCatalog.new(app_root: directory)
        end
        assert_includes error.message, "metadata is malformed"
      end
    end
    cases.each do |document, message|
      error = assert_raises(IpQuality::ClashLeafProfile::Error) do
        IpQuality::ClashLeafProfile.new(IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", document))
      end
      assert_includes error.message, message
    end
  end

  def test_unconfirmed_command_prints_a_plan_without_starting_mihomo
    Dir.mktmpdir("ip-quality-leaf-plan-") do |directory|
      profile_path = File.join(directory, "profile.yaml")
      write_private_yaml(profile_path, fixture_document)
      code, stdout, stderr = run_route(["--profile", profile_path, "--leaf", "TargetLeaf", "-4"])

      assert_equal 0, code
      assert_includes stdout, "no network access has occurred"
      assert_includes stdout, "live Clash profile/selection: read only and unchanged"
      assert_includes stdout, "Ping0"
      assert_empty stderr
    end
  end

  def test_profile_parser_rejects_recursive_aliases_and_non_mapping_roots
    Dir.mktmpdir("ip-quality-profile-parse-") do |directory|
      {
        "recursive.yaml" => "proxies: &loop [*loop]\n",
        "non-mapping.yaml" => "- not-a-profile\n"
      }.each do |filename, contents|
        path = File.join(directory, filename)
        File.write(path, contents)
        File.chmod(0o600, path)

        error = assert_raises(IpQuality::ClashLeafProfile::Error) do
          IpQuality::ClashLeafProfile.from_file(path)
        end
        assert_match(/recursive YAML aliases|root must be a YAML mapping/, error.message)
      end
    end
  end

  def test_configuration_workspace_is_removed_after_success_and_failure
    Dir.mktmpdir("ip-quality-cleanup-") do |directory|
      assert leaf_session(directory, exit_code: 0).configuration_test
      assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"))

      assert_raises(IpQuality::IsolatedMihomoSession::Error) do
        leaf_session(directory, exit_code: 9).configuration_test
      end
      assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"))
    end
  end

  def test_next_runtime_scavenges_dead_owned_workspace_without_touching_live_owner
    Dir.mktmpdir("ip-quality-stale-cleanup-") do |directory|
      dead_pid = 2_147_483_647
      dead_pid -= 1 while process_alive?(dead_pid)
      stale_workspace = File.join(directory, "ip-quality-leaf-#{dead_pid}-abandoned")
      live_workspace = File.join(directory, "ip-quality-leaf-#{Process.pid}-active")
      [stale_workspace, live_workspace].each do |workspace|
        Dir.mkdir(workspace, 0o700)
        File.write(File.join(workspace, ".ipquality-owner-pid"), "#{File.basename(workspace).split('-')[3]}\n")
        File.chmod(0o600, File.join(workspace, ".ipquality-owner-pid"))
      end

      assert leaf_session(directory, exit_code: 0).configuration_test
      refute Dir.exist?(stale_workspace)
      assert Dir.exist?(live_workspace)
    end
  end

  def test_confirmed_exact_leaf_report_uses_only_the_isolated_loopback_proxy
    Dir.mktmpdir("ip-quality-leaf-isolation-") do |directory|
      profile_path = File.join(directory, "profile.yaml")
      fake_mihomo = File.join(directory, "fake-mihomo")
      fake_reporter = File.join(directory, "fake-reporter")
      mihomo_pid_file = File.join(directory, "mihomo.pid")
      reporter_pid_file = File.join(directory, "reporter.pid")
      config_path_file = File.join(directory, "config-path.txt")
      arguments_file = File.join(directory, "arguments.txt")
      write_private_yaml(profile_path, fixture_document)
      write_loopback_fake_mihomo(fake_mihomo)
      File.write(fake_reporter, <<~'ZSH')
        #!/bin/zsh
        emulate -LR zsh
        endpoint="${HTTP_PROXY-}"
        [[ "$endpoint" == http://127.0.0.1:<1-65535> ]] || exit 71
        [[ "$ALL_PROXY" == "$endpoint" && "$HTTPS_PROXY" == "$endpoint" ]] || exit 72
        [[ "$all_proxy" == "$endpoint" && "$http_proxy" == "$endpoint" && "$https_proxy" == "$endpoint" ]] || exit 73
        [[ "${HtTp_PrOxY+x}${No_PrOxY+x}${no_proxy+x}" == "" ]] || exit 74
        [[ "$IPQUALITY_ISOLATED_EGRESS" == 1 ]] || exit 75
        print -r -- $$ > "$IPQUALITY_TEST_REPORTER_PID_FILE"
        print -r -- "$@" > "$IPQUALITY_TEST_ARGUMENTS_FILE"
      ZSH
      File.chmod(0o700, fake_reporter)

      environment = {
        "HTTP_PROXY" => "http://inherited.test.invalid:1",
        "https_proxy" => "http://inherited.test.invalid:2",
        "HtTp_PrOxY" => "http://inherited.test.invalid:3",
        "No_PrOxY" => "inherited.test.invalid",
        "no_proxy" => "inherited.test.invalid",
        "IPQUALITY_TEST_TEMP_PARENT" => directory,
        "IPQUALITY_TEST_PROFILE" => profile_path,
        "IPQUALITY_TEST_MIHOMO" => fake_mihomo,
        "IPQUALITY_TEST_REPORTER" => fake_reporter,
        "IPQUALITY_TEST_MIHOMO_PID_FILE" => mihomo_pid_file,
        "IPQUALITY_TEST_REPORTER_PID_FILE" => reporter_pid_file,
        "IPQUALITY_TEST_MIHOMO_CONFIG_FILE" => config_path_file,
        "IPQUALITY_TEST_ARGUMENTS_FILE" => arguments_file
      }
      begin
        stdout, stderr, status = Open3.capture3(
          environment, "/usr/bin/ruby", "-e", isolated_runner_program
        )

        assert status.success?, stderr
        assert_empty stdout
        assert_equal "--confirm-network-lookup --scope reputation -4\n", File.read(arguments_file)
        assert File.file?(reporter_pid_file)
        assert File.file?(mihomo_pid_file)
        refute process_alive?(Integer(File.read(reporter_pid_file)))
        refute process_alive?(Integer(File.read(mihomo_pid_file)))
        assert_removed_private_workspace(directory, config_path_file)
        assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"), File::FNM_DOTMATCH)
        assert_includes stderr, "Isolated Mihomo stopped"
      ensure
        stop_test_child_from_pid_file(reporter_pid_file)
        stop_test_child_from_pid_file(mihomo_pid_file)
      end
    end
  end

  def test_sigterm_stops_reporter_and_mihomo_then_removes_private_workspace
    Dir.mktmpdir("ip-quality-signal-cleanup-") do |directory|
      profile_path = File.join(directory, "profile.yaml")
      fake_mihomo = File.join(directory, "fake-mihomo")
      fake_reporter = File.join(directory, "fake-reporter")
      mihomo_pid_file = File.join(directory, "mihomo.pid")
      reporter_pid_file = File.join(directory, "reporter.pid")
      config_path_file = File.join(directory, "config-path.txt")
      write_private_yaml(profile_path, fixture_document)

      write_loopback_fake_mihomo(fake_mihomo)

      File.write(fake_reporter, <<~'ZSH')
        #!/bin/zsh
        print -r -- $$ > "$IPQUALITY_TEST_REPORTER_PID_FILE"
        while true; do
          /bin/sleep 1
        done
      ZSH
      File.chmod(0o700, fake_reporter)

      environment = {
        "IPQUALITY_TEST_PROFILE" => profile_path,
        "IPQUALITY_TEST_MIHOMO" => fake_mihomo,
        "IPQUALITY_TEST_REPORTER" => fake_reporter,
        "IPQUALITY_TEST_MIHOMO_PID_FILE" => mihomo_pid_file,
        "IPQUALITY_TEST_REPORTER_PID_FILE" => reporter_pid_file,
        "IPQUALITY_TEST_MIHOMO_CONFIG_FILE" => config_path_file,
        "IPQUALITY_TEST_TEMP_PARENT" => directory
      }
      runner_pid = Process.spawn(
        environment,
        "/usr/bin/ruby",
        "-e",
        isolated_runner_program,
        out: File::NULL,
        err: File::NULL
      )

      begin
        Timeout.timeout(15) do
          until File.file?(mihomo_pid_file) && File.file?(reporter_pid_file) &&
                !Dir.glob(File.join(directory, "ip-quality-leaf-*"), File::FNM_DOTMATCH).empty?
            sleep 0.05
          end
        end
        Process.kill("TERM", runner_pid)
        _waited_pid, status = Timeout.timeout(15, Timeout::Error, "runner did not exit within 15 seconds after TERM") do
          Process.wait2(runner_pid)
        end
        runner_pid = nil

        assert_equal 130, status.exitstatus
        Timeout.timeout(5) do
          until Dir.glob(File.join(directory, "ip-quality-leaf-*"), File::FNM_DOTMATCH).empty? &&
                !process_alive?(Integer(File.read(mihomo_pid_file))) &&
                !process_alive?(Integer(File.read(reporter_pid_file)))
            sleep 0.05
          end
        end
        assert_removed_private_workspace(directory, config_path_file)
      ensure
        if runner_pid && process_alive?(runner_pid)
          Process.kill("KILL", runner_pid)
          Process.waitpid(runner_pid)
        end
        stop_test_child_from_pid_file(reporter_pid_file)
        stop_test_child_from_pid_file(mihomo_pid_file)
      end
    end
  end

  def test_executable_entrypoint_resolves_libraries_outside_the_worktree
    Dir.mktmpdir("ip-quality-entrypoint-") do |directory|
      stdout, stderr, status = Open3.capture3(
        { "HOME" => directory }, RUNNER, "--direct", chdir: directory
      )
      assert status.success?, stderr
      assert_includes stdout, "no network access has occurred"
      assert_includes stdout, "current system IPv4 route"
      assert_empty stderr

      stdout, stderr, status = Open3.capture3(
        "/usr/bin/ruby", "--disable-gems", RUNNER, "--help", chdir: directory
      )
      assert status.success?, stderr
      assert_includes stdout, "--confirm-network-lookup"
      assert_empty stderr
    end
  end

  def test_non_ascii_leaf_names_match_under_a_posix_caller_locale
    Dir.mktmpdir("ip-quality-leaf-locale-") do |directory|
      document = fixture_document
      document["proxies"][1]["name"] = "香港 01"
      document["proxy-groups"][0]["proxies"] = ["香港 01"]
      profile_path = File.join(directory, "profile.yaml")
      write_private_yaml(profile_path, document)
      environment = { "HOME" => directory, "LANG" => nil, "LC_ALL" => "C", "LC_CTYPE" => nil }

      stdout, stderr, status = Open3.capture3(
        environment, RUNNER, "--profile", profile_path, "--leaf", "香港 01", "-4", chdir: directory
      )

      assert status.success?, stderr
      assert_includes stdout, "no network access has occurred"
    end
  end

  def test_runner_plans_disclose_the_reporter_source_catalog
    code, stdout, = run_route(["--sources", "dbip,ping0,ripestat"], stdin: "2\n8.8.8.8\n")
    assert_equal 0, code
    assert_includes stdout, "    DB-IP: not applicable to an explicit target"
    assert_includes stdout, "    Ping0: not applicable to an explicit target"
    assert_includes stdout, "    RIPEstat: routed prefix and origin ASN"
    refute_includes stdout, "IPQS:"

    code, stdout, = run_route(["--direct", "--sources", "independent"])
    assert_equal 0, code
    assert_includes stdout, "    DB-IP: visitor-egress demo; daily-limit errors get one same-route IPv4 public detail-page read in temporary hidden Chrome"
    refute_includes stdout, "Scamalytics"
  end

  def test_printable_text_checks_bytes_encoding_and_control_characters
    assert IpQuality::Text.printable?("香港 Leaf")
    assert IpQuality::Text.printable?("葉" * 170)
    refute IpQuality::Text.printable?("葉" * 171)
    assert IpQuality::Text.printable?("abc", max_bytes: 3)
    refute IpQuality::Text.printable?("abcd", max_bytes: 3)
    [nil, 123, "", "leaf\n", "leaf\t", "leaf\0", "\e[31mleaf", "bad\xFF"].each do |value|
      refute IpQuality::Text.printable?(value), value.inspect
    end
  end

  def test_snapshot_read_enforces_size_links_and_verify_only_keeps_file_policy
    Dir.mktmpdir("ip-quality-common-snapshot-") do |directory|
      path = File.join(directory, "fixture")
      File.write(path, "abcd")
      File.chmod(0o600, path)
      snapshot = IpQuality::SafeSnapshot.read(path, max_bytes: 4)
      assert_equal "abcd", snapshot.bytes
      assert snapshot.bytes.frozen?
      assert IpQuality::SafeSnapshot.same?(snapshot, IpQuality::SafeSnapshot.read(path))
      error = assert_raises(IpQuality::SafeSnapshot::Error) do
        IpQuality::SafeSnapshot.read(path, max_bytes: 3)
      end
      assert_equal :too_large, error.reason

      File.chmod(0o700, path)
      error = assert_raises(IpQuality::SafeSnapshot::Error) { IpQuality::SafeSnapshot.read(path) }
      assert_equal :unsafe_mode, error.reason
      verified = IpQuality::SafeSnapshot.read(path, allowed_modes: [0o700], max_bytes: nil)
      assert_nil verified.bytes
      assert_equal 0o700, verified.stat.mode & 0o777

      symlink = File.join(directory, "symlink")
      File.symlink(path, symlink)
      error = assert_raises(IpQuality::SafeSnapshot::Error) do
        IpQuality::SafeSnapshot.read(symlink, allowed_modes: [0o700], max_bytes: nil)
      end
      assert_equal :symlink, error.reason
      File.link(path, File.join(directory, "hard-link"))
      error = assert_raises(IpQuality::SafeSnapshot::Error) do
        IpQuality::SafeSnapshot.read(path, allowed_modes: [0o700], max_bytes: nil)
      end
      assert_equal :hard_link, error.reason

      File.rename(path, File.join(directory, "previous"))
      File.write(path, "abcd")
      File.chmod(0o600, path)
      refute IpQuality::SafeSnapshot.same?(snapshot, IpQuality::SafeSnapshot.read(path))
    end
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

  # A real session whose fake Mihomo `-t` check exits with the given code.
  def leaf_session(directory, exit_code:)
    fake_mihomo = File.join(directory, "fake-mihomo")
    File.write(fake_mihomo, "#!/bin/zsh\nexit #{exit_code}\n")
    File.chmod(0o700, fake_mihomo)
    profile = IpQuality::ClashLeafProfile.new(
      IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", fixture_document)
    )
    IpQuality::IsolatedMihomoSession.new(profile, "TargetLeaf", mihomo_path: fake_mihomo, temp_parent: directory)
  end

  def write_private_yaml(path, document)
    File.write(path, YAML.dump(document))
    File.chmod(0o600, path)
  end

  def isolated_runner_program
    <<~RUBY
      require "minitest/mock"
      load #{RUNNER.inspect}
      # TMPDIR alone cannot override the production preferred workspace.
      # Keep the real session lifecycle, injecting only its existing temp_parent.
      constructor = IpQuality::IsolatedMihomoSession.method(:new)
      factory = lambda do |*arguments, **options|
        constructor.call(*arguments, **options.merge(temp_parent: ENV.fetch("IPQUALITY_TEST_TEMP_PARENT")))
      end
      IpQuality::IsolatedMihomoSession.stub(:new, factory) do
        command = IpQuality::RouteCommand.new(
          reporter_path: ENV.fetch("IPQUALITY_TEST_REPORTER")
        )
        exit(command.run([
          "--profile", ENV.fetch("IPQUALITY_TEST_PROFILE"),
          "--leaf", "TargetLeaf",
          "--mihomo", ENV.fetch("IPQUALITY_TEST_MIHOMO"),
          "--confirm-network-lookup", "-4"
        ]))
      end
    RUBY
  end

  def assert_removed_private_workspace(directory, config_path_file)
    workspace = File.dirname(File.read(config_path_file).strip)
    assert_equal File.realpath(directory), File.realpath(File.dirname(workspace))
    refute File.exist?(workspace), "the workspace actually used by Mihomo must be removed"
  end

  def write_loopback_fake_mihomo(path)
    File.write(path, <<~'ZSH')
      #!/bin/zsh
      emulate -LR zsh
      typeset config=''
      typeset test_only=0
      while (( $# > 0 )); do
        case "$1" in
          -f) config="$2"; shift 2 ;;
          -t) test_only=1; shift ;;
          *) shift ;;
        esac
      done
      print -r -- "$config" > "$IPQUALITY_TEST_MIHOMO_CONFIG_FILE"
      (( test_only == 1 )) && exit 0
      typeset port=''
      while IFS= read -r line; do
        [[ "$line" == 'mixed-port: '* ]] && port="${line#mixed-port: }"
      done < "$config"
      [[ "$port" == <1-65535> ]] || exit 64
      exec /usr/bin/ruby -rsocket -e '
        File.write(ENV.fetch("IPQUALITY_TEST_MIHOMO_PID_FILE"), Process.pid.to_s)
        Signal.trap("TERM") { exit }
        Signal.trap("HUP") { exit }
        TCPServer.new("127.0.0.1", Integer(ARGV.fetch(0)))
        sleep
      ' "$port"
    ZSH
    File.chmod(0o700, path)
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

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def stop_test_child_from_pid_file(path)
    return unless File.file?(path)

    pid = Integer(File.read(path), 10)
    return unless process_alive?(pid)

    Process.kill("TERM", pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    until !process_alive?(pid) || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.05
    end
    Process.kill("KILL", pid) if process_alive?(pid)
  rescue ArgumentError, Errno::ESRCH, Errno::EPERM
    nil
  end
end

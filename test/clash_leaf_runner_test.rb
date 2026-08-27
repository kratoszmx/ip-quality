# frozen_string_literal: true

require "minitest/autorun"
require "stringio"
require "tmpdir"
require "timeout"
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
        stdin: StringIO.new("4\n2\n"),
        app_root: directory
      )

      exit_code = command.run([])

      assert_equal 0, exit_code
      assert_includes stdout.string, "Available test routes:"
      assert_includes stdout.string, "Direct connection"
      assert_includes stdout.string, "Specific IP lookup"
      assert_includes stdout.string, "Direct mail connectivity + DNSBL"
      assert_includes stdout.string, "Cached subscription: Fixture Remote"
      assert_includes stdout.string, "Available inline leaves"
      assert_includes stdout.string, "exact leaf: TargetLeaf"
      refute_match(/\d+ inline leaves/, stdout.string)
      assert_empty stderr.string
    end
  end

  def test_default_route_selector_can_choose_direct_without_loading_a_leaf
    Dir.mktmpdir("ip-quality-direct-select-") do |directory|
      write_clash_verge_fixture(directory)
      stdout = StringIO.new
      stderr = StringIO.new
      command = IpQuality::ClashLeafCommand.new(
        stdout: stdout,
        stderr: stderr,
        stdin: StringIO.new("1\n"),
        app_root: directory
      )

      exit_code = command.run([])

      assert_equal 0, exit_code
      assert_includes stdout.string, "Available test routes:"
      assert_includes stdout.string, "Direct route plan"
      assert_includes stdout.string, "no temporary Mihomo process"
      refute_includes stdout.string, "Available inline leaves"
      assert_empty stderr.string
    end
  end

  def test_explicit_direct_plan_does_not_require_a_clash_cache
    Dir.mktmpdir("ip-quality-direct-plan-") do |directory|
      stdout = StringIO.new
      stderr = StringIO.new
      command = IpQuality::ClashLeafCommand.new(
        stdout: stdout,
        stderr: stderr,
        app_root: File.join(directory, "missing-clash-cache")
      )

      exit_code = command.run(["--direct", "-4"])

      assert_equal 0, exit_code
      assert_includes stdout.string, "Direct route plan"
      assert_includes stdout.string, "current system route"
      assert_includes stdout.string, "system-level VPN or TUN"
      assert_empty stderr.string
    end
  end

  def test_direct_live_report_unsets_proxy_environment_and_forwards_report_options
    Dir.mktmpdir("ip-quality-direct-live-") do |directory|
      fake_reporter = File.join(directory, "fake-reporter")
      arguments_file = File.join(directory, "arguments.txt")
      File.write(fake_reporter, <<~'ZSH')
        [[ -z "${HTTP_PROXY+x}${https_proxy+x}${No_PrOxY+x}" ]] || exit 71
        print -r -- "$@" > "$IPQUALITY_TEST_ARGUMENTS_FILE"
      ZSH
      File.chmod(0o700, fake_reporter)
      stdout = StringIO.new
      stderr = StringIO.new
      command = IpQuality::ClashLeafCommand.new(
        stdout: stdout,
        stderr: stderr,
        app_root: File.join(directory, "missing-clash-cache"),
        reporter_path: fake_reporter
      )

      exit_code = with_environment(
        "HTTP_PROXY" => "http://127.0.0.1:1",
        "https_proxy" => "http://127.0.0.1:2",
        "No_PrOxY" => "fixture.invalid",
        "IPQUALITY_TEST_ARGUMENTS_FILE" => arguments_file
      ) do
        command.run(["--direct", "--confirm-network-lookup", "-4", "-j"])
      end

      assert_equal 0, exit_code
      assert_equal "--confirm-network-lookup --scope reputation -4 -j\n", File.read(arguments_file)
      assert_empty stdout.string
      assert_includes stderr.string, "no Mihomo process is started"
      assert_includes stderr.string, "live Clash state was unchanged"
      assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"))
    end
  end

  def test_specific_ip_menu_uses_provider_target_parameters_without_starting_mihomo
    Dir.mktmpdir("ip-quality-specific-ip-") do |directory|
      write_clash_verge_fixture(directory)
      fake_reporter = File.join(directory, "fake-reporter")
      arguments_file = File.join(directory, "arguments.txt")
      File.write(fake_reporter, <<~'ZSH')
        [[ -z "${HTTP_PROXY+x}${https_proxy+x}${No_PrOxY+x}" ]] || exit 71
        print -r -- "$@" > "$IPQUALITY_TEST_ARGUMENTS_FILE"
      ZSH
      File.chmod(0o700, fake_reporter)
      stdout = StringIO.new
      stderr = StringIO.new
      command = IpQuality::ClashLeafCommand.new(
        stdout: stdout,
        stderr: stderr,
        stdin: StringIO.new("2\n12.217.32.68\n"),
        app_root: directory,
        reporter_path: fake_reporter
      )

      exit_code = with_environment(
        "HTTP_PROXY" => "http://127.0.0.1:1",
        "https_proxy" => "http://127.0.0.1:2",
        "No_PrOxY" => "fixture.invalid",
        "IPQUALITY_TEST_ARGUMENTS_FILE" => arguments_file
      ) do
        command.run(["--confirm-network-lookup", "-4", "-f"])
      end

      assert_equal 0, exit_code
      assert_equal "--confirm-network-lookup --scope reputation -4 -f 12.217.32.68\n", File.read(arguments_file)
      assert_includes stdout.string, "Specific IP lookup"
      assert_includes stdout.string, "Enter one public IP address"
      refute_includes stdout.string, "Available inline leaves"
      assert_includes stderr.string, "Inspecting specific IP 12.217.32.68"
      assert_includes stderr.string, "Specific-IP report finished"
      assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"))
    end
  end

  def test_direct_mail_dnsbl_menu_is_ipv4_system_route_only
    Dir.mktmpdir("ip-quality-direct-mail-dnsbl-") do |directory|
      write_clash_verge_fixture(directory)
      fake_reporter = File.join(directory, "fake-reporter")
      arguments_file = File.join(directory, "arguments.txt")
      File.write(fake_reporter, <<~'ZSH')
        [[ -z "${HTTP_PROXY+x}${https_proxy+x}${No_PrOxY+x}" ]] || exit 71
        print -r -- "$@" > "$IPQUALITY_TEST_ARGUMENTS_FILE"
      ZSH
      File.chmod(0o700, fake_reporter)
      stdout = StringIO.new
      stderr = StringIO.new
      command = IpQuality::ClashLeafCommand.new(
        stdout: stdout,
        stderr: stderr,
        stdin: StringIO.new("3\n"),
        app_root: directory,
        reporter_path: fake_reporter
      )

      exit_code = with_environment(
        "HTTP_PROXY" => "http://127.0.0.1:1",
        "https_proxy" => "http://127.0.0.1:2",
        "No_PrOxY" => "fixture.invalid",
        "IPQUALITY_TEST_ARGUMENTS_FILE" => arguments_file
      ) do
        command.run(["--confirm-network-lookup", "-f"])
      end

      assert_equal 0, exit_code
      assert_equal "--confirm-network-lookup --scope mail-dnsbl -4 -f\n", File.read(arguments_file)
      assert_includes stdout.string, "Direct mail connectivity + DNSBL"
      assert_includes stderr.string, "current system IPv4 route"
      assert_includes stderr.string, "Direct mail/DNSBL report finished"
      assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"))

      ipv6_stdout = StringIO.new
      ipv6_stderr = StringIO.new
      ipv6_command = IpQuality::ClashLeafCommand.new(
        stdout: ipv6_stdout,
        stderr: ipv6_stderr,
        stdin: StringIO.new("3\n"),
        app_root: directory,
        reporter_path: fake_reporter
      )
      assert_equal IpQuality::ClashLeafCommand::EX_USAGE, ipv6_command.run(["-6"])
      assert_includes ipv6_stderr.string, "require IPv4"
    end
  end

  def test_specific_ip_menu_rejects_malformed_or_family_conflicting_input_before_lookup
    Dir.mktmpdir("ip-quality-specific-ip-reject-") do |directory|
      write_clash_verge_fixture(directory)

      malformed_stdout = StringIO.new
      malformed_stderr = StringIO.new
      malformed = IpQuality::ClashLeafCommand.new(
        stdout: malformed_stdout,
        stderr: malformed_stderr,
        stdin: StringIO.new("2\nnot-an-ip\n"),
        app_root: directory
      )
      assert_equal IpQuality::ClashLeafCommand::EX_USAGE, malformed.run([])
      assert_includes malformed_stderr.string, "specific IP must be one valid public address"

      family_stdout = StringIO.new
      family_stderr = StringIO.new
      family = IpQuality::ClashLeafCommand.new(
        stdout: family_stdout,
        stderr: family_stderr,
        stdin: StringIO.new("2\n2001:db8::1\n"),
        app_root: directory
      )
      assert_equal IpQuality::ClashLeafCommand::EX_USAGE, family.run(["-4"])
      assert_includes family_stderr.string, "conflicts with the selected address family"
    end
  end

  def test_direct_rejects_leaf_only_options_before_network_access
    stdout = StringIO.new
    stderr = StringIO.new
    command = IpQuality::ClashLeafCommand.new(stdout: stdout, stderr: stderr)

    exit_code = command.run(["--direct", "--leaf", "TargetLeaf"])

    assert_equal IpQuality::ClashLeafCommand::EX_USAGE, exit_code
    assert_includes stderr.string, "--direct cannot be combined"
    assert_empty stdout.string
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

  def test_configuration_workspace_is_removed_after_success_and_failure
    Dir.mktmpdir("ip-quality-cleanup-") do |directory|
      fake_mihomo = File.join(directory, "fake-mihomo")
      profile = IpQuality::ClashLeafProfile.new(
        IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", fixture_document)
      )

      File.write(fake_mihomo, "#!/bin/zsh\nexit 0\n")
      File.chmod(0o700, fake_mihomo)
      session = IpQuality::IsolatedMihomoSession.new(
        profile,
        "TargetLeaf",
        mihomo_path: fake_mihomo,
        temp_parent: directory
      )
      assert session.configuration_test
      assert_empty Dir.glob(File.join(directory, "ip-quality-leaf-*"))

      File.write(fake_mihomo, "#!/bin/zsh\nexit 9\n")
      File.chmod(0o700, fake_mihomo)
      failing_session = IpQuality::IsolatedMihomoSession.new(
        profile,
        "TargetLeaf",
        mihomo_path: fake_mihomo,
        temp_parent: directory
      )
      assert_raises(IpQuality::IsolatedMihomoSession::Error) do
        failing_session.configuration_test
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

      fake_mihomo = File.join(directory, "fake-mihomo")
      File.write(fake_mihomo, "#!/bin/zsh\nexit 0\n")
      File.chmod(0o700, fake_mihomo)
      profile = IpQuality::ClashLeafProfile.new(
        IpQuality::ClashLeafProfile::Source.new("fixture", "fixture.yaml", fixture_document)
      )
      session = IpQuality::IsolatedMihomoSession.new(
        profile,
        "TargetLeaf",
        mihomo_path: fake_mihomo,
        temp_parent: directory
      )

      assert session.configuration_test
      refute Dir.exist?(stale_workspace)
      assert Dir.exist?(live_workspace)
    end
  end

  def test_sigterm_stops_reporter_and_mihomo_then_removes_private_workspace
    Dir.mktmpdir("ip-quality-signal-cleanup-") do |directory|
      profile_path = File.join(directory, "profile.yaml")
      fake_mihomo = File.join(directory, "fake-mihomo")
      fake_reporter = File.join(directory, "fake-reporter")
      mihomo_pid_file = File.join(directory, "mihomo.pid")
      reporter_pid_file = File.join(directory, "reporter.pid")
      write_private_yaml(profile_path, fixture_document)

      File.write(fake_mihomo, <<~'ZSH')
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
      File.chmod(0o700, fake_mihomo)

      File.write(fake_reporter, <<~'ZSH')
        #!/bin/zsh
        print -r -- $$ > "$IPQUALITY_TEST_REPORTER_PID_FILE"
        while true; do
          /bin/sleep 1
        done
      ZSH
      File.chmod(0o700, fake_reporter)

      command_library = File.join(ROOT, "leaf_runner", "command.rb")
      runner = <<~RUBY
        require #{command_library.inspect}
        command = IpQuality::ClashLeafCommand.new(
          reporter_path: ENV.fetch("IPQUALITY_TEST_REPORTER")
        )
        exit(command.run([
          "--profile", ENV.fetch("IPQUALITY_TEST_PROFILE"),
          "--leaf", "TargetLeaf",
          "--mihomo", ENV.fetch("IPQUALITY_TEST_MIHOMO"),
          "--confirm-network-lookup", "-4"
        ]))
      RUBY
      environment = {
        "IPQUALITY_TEST_PROFILE" => profile_path,
        "IPQUALITY_TEST_MIHOMO" => fake_mihomo,
        "IPQUALITY_TEST_REPORTER" => fake_reporter,
        "IPQUALITY_TEST_MIHOMO_PID_FILE" => mihomo_pid_file,
        "IPQUALITY_TEST_REPORTER_PID_FILE" => reporter_pid_file,
        "HOME" => directory,
        "TMPDIR" => directory
      }
      runner_pid = Process.spawn(
        environment,
        "/usr/bin/ruby",
        "-e",
        runner,
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
        _waited_pid, status = Process.wait2(runner_pid)
        runner_pid = nil

        assert_equal 130, status.exitstatus
        Timeout.timeout(5) do
          until Dir.glob(File.join(directory, "ip-quality-leaf-*"), File::FNM_DOTMATCH).empty? &&
                !process_alive?(Integer(File.read(mihomo_pid_file))) &&
                !process_alive?(Integer(File.read(reporter_pid_file)))
            sleep 0.05
          end
        end
      ensure
        if runner_pid && process_alive?(runner_pid)
          Process.kill("KILL", runner_pid)
          Process.waitpid(runner_pid)
        end
      end
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

  def test_leaf_runner_rejects_unimplemented_report_languages_before_network_access
    stdout = StringIO.new
    stderr = StringIO.new
    command = IpQuality::ClashLeafCommand.new(stdout: stdout, stderr: stderr)

    exit_code = command.run(["-l", "jp"])

    assert_equal IpQuality::ClashLeafCommand::EX_USAGE, exit_code
    assert_includes stderr.string, "unsupported language"
    assert_empty stdout.string
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

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
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

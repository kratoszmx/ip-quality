# frozen_string_literal: true

require_relative "support/reporter_test_case"

class IpQualityTest < ReporterTestCase
  def test_default_is_a_no_network_disclosure_plan
    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_includes stdout, "no network access has occurred"
    assert_includes stdout, "scope: full"
    assert_includes stdout, "reputation sources:"
    assert_includes stdout, "media/AI sources:"
    assert_includes stdout, "mail sources:"
    assert_includes stdout, "DNSBL sources:"
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

    stdout, stderr, status = run_script("--scope", "mail-dnsbl")
    assert status.success?, stderr
    assert_includes stdout, "scope: mail-dnsbl"
    assert_includes stdout, "mail sources:"
    assert_includes stdout, "DNSBL sources:"
    assert_empty stderr
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
    assert_match(/SELF-TEST OK: zsh runtime, validators, provider parsers, and \d+ DNSBL entries/, stdout)
    assert_empty stderr
  end

  def test_reputation_plan_discloses_ping0_public_result_and_risk_limitation
    stdout, stderr, status = run_script("--scope", "reputation")

    assert status.success?, stderr
    assert_includes stdout, "official-contract sources"
    assert_includes stdout, "configured Ipregistry/IPQS APIs"
    assert_includes stdout, "supplementary sources"
    assert_includes stdout, "Ping0"
    assert_includes stdout, "official free /geo endpoint"
    assert_includes stdout, "not a risk score"
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

  def test_dnsbl_live_path_keeps_every_zone_result_with_a_fixture_dig
    write_fake_command("dig", <<~'ZSH')
      case "$*" in
        *dnsbl-3.uceprotect.net*) print -r -- 127.0.0.2 ;;
        *bl.spamcop.net*) print -r -- 127.0.0.3 ;;
        *.b.barracudacentral.org*) exit 9 ;;
        *.vouch.dwl.spamhaus.org*) print -r -- 127.255.255.254 ;;
        *) exit 0 ;;
      esac
    ZSH
    output_path = File.join(reporter_workspace, "report.json")
    stdout, stderr, status = run_script(
      "--confirm-network-lookup", "--scope", "dnsbl",
      "--dnsbl-concurrency", "7", "-4", "-j", "-o", output_path, "12.217.32.68"
    )

    assert status.success?, stderr
    report = JSON.parse(stdout)
    assert_equal report, JSON.parse(File.read(output_path))
    assert_equal 0o600, File.stat(output_path).mode & 0o777
    refute_includes stdout, "12.217.32.68"
    dnsbl = report.dig("Mail", "DNSBlacklist")
    zones = File.readlines(DNSBL, chomp: true)
    assert_equal zones.sort, dnsbl.fetch("Results").keys.sort
    assert_equal zones.size, dnsbl.fetch("Total")
    assert_equal zones.size - 4, dnsbl.fetch("Clean")
    assert_equal 1, dnsbl.fetch("Marked")
    assert_equal 1, dnsbl.fetch("Blacklisted")
    assert_equal 2, dnsbl.fetch("Unknown")
    assert_equal "Blacklisted", dnsbl.dig("Results", "dnsbl-3.uceprotect.net")
    assert_equal "Marked", dnsbl.dig("Results", "bl.spamcop.net")
    assert_equal "Unknown", dnsbl.dig("Results", "b.barracudacentral.org")
    assert_equal "Unknown", dnsbl.dig("Results", "vouch.dwl.spamhaus.org")
    assert_includes stderr, "正在检测黑名单数据库"
  end

  def test_missing_live_dependency_stops_before_lookup_or_report_creation
    output_path = File.join(reporter_workspace, "must-not-exist.json")
    # Only the command tripwires are on PATH; jq and xargs are absent.
    stdout, stderr, status = run_script(
      "--confirm-network-lookup", "--scope", "dnsbl", "-4", "-j",
      "-o", output_path, "12.217.32.68",
      env: { "PATH" => File.join(reporter_workspace, "commands") }
    )

    assert_equal 69, status.exitstatus
    assert_includes stderr, "missing required commands: jq xargs"
    assert_empty stdout
    refute File.exist?(output_path)
  end

  def test_smtp_probe_uses_the_system_route_without_binding_the_public_nat_address
    function_source = reporter_functions("smtp_probe")

    Dir.mktmpdir("ipquality-smtp-route-test") do |directory|
      fake_nc = File.join(directory, "nc")
      arguments_file = File.join(directory, "arguments.txt")
      File.write(fake_nc, <<~'ZSH')
        #!/bin/zsh -f
        print -r -- "$@" > "$IPQUALITY_NC_ARGUMENTS_FILE"
        print -r -- "220 fixture SMTP"
      ZSH
      File.chmod(0o700, fake_nc)

      stdout, stderr, status = Open3.capture3(
        {
          "PATH" => "#{directory}:#{ENV.fetch("PATH")}",
          "IPQUALITY_NC_ARGUMENTS_FILE" => arguments_file
        },
        "/bin/zsh", "-f", "-c",
        'eval "$1"; IP=198.51.100.23; smtp_probe smtp.example 25 2',
        "smtp-system-route-test", function_source
      )

      assert status.success?, stderr
      assert_equal "-w 2 smtp.example 25\n", File.read(arguments_file)
      assert_equal "220 fixture SMTP\n", stdout
      refute_includes File.read(arguments_file), "198.51.100.23"
      assert_empty stderr
    end
  end

  def test_only_implemented_report_languages_are_advertised_and_accepted
    source = File.read(SCRIPT, encoding: "UTF-8")
    assert_includes source, "-l cn|en"
    refute_match(/cn\|en\|jp|\"jp\"\|\"es\"/, source)

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "-l",
      "jp"
    )
    assert_equal 1, status.exitstatus
    assert_includes stdout, "不支持的参数"
    assert_empty stderr
  end

  def test_removed_upstream_mutation_and_remote_execution_flags_are_rejected
    %w[-xhttp://127.0.0.1:1 -y -M].each do |flag|
      _stdout, stderr, status = run_script(flag)

      assert_equal 64, status.exitstatus, "flag=#{flag}"
      assert_includes stderr, "disabled"
    end
  end

  def test_live_gate_rejects_incompatible_family_and_unsafe_interface_before_lookup
    %w[dnsbl mail-dnsbl].each do |scope|
      stdout, stderr, status = run_script(
        "--confirm-network-lookup",
        "--scope",
        scope,
        "-6"
      )
      assert_equal 61, status.exitstatus
      assert_includes stdout, "DNSBL"
      assert_empty stderr
    end

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

  def test_explicit_public_target_is_parsed_before_network_and_restricted_to_honest_scopes
    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "full",
      "12.217.32.68"
    )
    assert_equal 62, status.exitstatus
    assert_includes stdout, "指定公网IP仅支持信誉或DNSBL范围"
    assert_empty stderr

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "-6",
      "12.217.32.68"
    )
    assert_equal 63, status.exitstatus
    assert_includes stdout, "IPv4/IPv6类型冲突"
    assert_empty stderr

    stdout, stderr, status = run_script(
      "--confirm-network-lookup",
      "--scope",
      "reputation",
      "192.168.1.10"
    )
    assert_equal 2, status.exitstatus
    assert_includes stdout, "IP地址格式错误"
    assert_empty stderr
  end
end

# frozen_string_literal: true

require_relative "support/reporter_test_case"

class IpQualityTest < ReporterTestCase
  def test_default_reputation_plan_is_network_free_and_discloses_source_limits
    stdout, stderr, status = run_script

    assert status.success?, stderr
    assert_empty stderr
    [
      "no network access has occurred", "scope: reputation", "reputation sources:",
      "telemetry/report upload/remote code: disabled",
      "one direct IPv4 fallback, querying the same target IP",
      "same provider also sees the system-route egress",
      "visitor/self demos never switch routes", "--confirm-network-lookup",
      "    DB-IP: public page + one visitor-egress lookup (must match target)",
      "    IPWHOIS: public website demo, one target lookup",
      "legacy Threat Score is retired",
      "    Ipregistry: official API, only with a configured key",
      "    Ping0: official free /geo endpoint", "not a risk score"
    ].each { |text| assert_includes stdout, text }
    ["media/AI sources:", "mail sources:", "DNSBL sources:"].each { |text| refute_includes stdout, text }
  end

  def test_each_scope_has_a_bounded_plan_and_retired_media_is_rejected
    {
      "reputation" => ["reputation sources:"],
      "dnsbl" => ["DNSBL sources:"],
      "mail" => ["mail sources:"],
      "mail-dnsbl" => ["mail sources:", "DNSBL sources:"],
      "full" => ["mail sources:", "DNSBL sources:"]
    }.each do |scope, markers|
      stdout, stderr, status = run_script("--scope", scope)
      assert status.success?, "scope=#{scope}: #{stderr}"
      assert_empty stderr
      assert_includes stdout, "scope: #{scope}"
      markers.each { |marker| assert_includes stdout, marker, scope }
      refute_includes stdout, "media/AI", scope
    end
    _stdout, stderr, status = run_script("--scope", "media-ai")
    assert_equal 64, status.exitstatus
    assert_includes stderr, "unsupported scope"
  end

  def test_explicit_plan_still_prevents_network_after_confirmation
    stdout, stderr, status = run_script("--confirm-network-lookup", "--plan", "--scope", "full")

    assert status.success?, stderr
    assert_includes stdout, "no network access has occurred"
    assert_empty stderr
  end

  def test_option_parser_accepts_getopts_clusters_and_rejects_invalid_or_removed_flags
    [%w[-4fj], %w[-len -4], %w[-l en -E], %w[-4 -- 8.8.8.8]].each do |arguments|
      stdout, stderr, status = run_script(*arguments)
      assert status.success?, "#{arguments.join(' ')}: #{stderr}"
      assert_includes stdout, "query plan"
    end
    # Removed upstream mutation/remote-execution flags fail as disabled (64);
    # unsupported scope/family/target combinations keep their own gates.
    {
      %w[-p] => 1, %w[--bogus] => 1, %w[-o] => 1, %w[-4 8.8.8.8 1.1.1.1] => 1, %w[-l jp] => 1,
      %w[--scope dnsbl -6] => 61, %w[--scope mail 8.8.8.8] => 62,
      %w[-xhttp://127.0.0.1:1] => 64, %w[-y] => 64, %w[-M] => 64
    }.each do |arguments, code|
      stdout, stderr, status = run_script(*arguments)
      assert_equal code, status.exitstatus, arguments.join(" ")
      refute_includes stdout, "query plan", arguments.join(" ")
      assert_includes stderr, "disabled" if code == 64
    end
    help, errors, result = run_script("--help")
    assert result.success?, errors
    assert_includes help, "-l cn|en"
    version, errors, result = run_script("--version")
    assert result.success?, errors
    assert_match(/\Av\d{4}-\d{2}-\d{2}-standalone\.\d+\n\z/, version)
    stdout, stderr, status = run_script("--confirm-network-lookup", "--scope", "reputation", "-l", "jp")
    assert_equal 1, status.exitstatus
    assert_includes stdout, "不支持的参数"
    assert_empty stderr
  end

  def test_address_prefix_decimal_and_dnsbl_helpers_validate_their_inputs
    probe = <<~'ZSH'
      source "$1"
      check(){ "$@" && print -rn -- 1 || print -rn -- 0; }
      check is_valid_ipv4 198.51.100.23; check is_valid_ipv4 999.51.100.23
      check is_valid_ipv6 2001:4860:4860::8888; check is_valid_ipv6 2001:::1
      check is_private_ipv4 192.168.1.1; check is_private_ipv4 8.8.8.8
      check is_private_ipv6 2001:db8::1; check is_private_ipv6 2001:4860:4860::8888
      check is_nonnegative_decimal 0.25; check is_nonnegative_decimal '0; print unsafe'
      check is_signed_decimal -33.86; check is_signed_decimal '1; print unsafe'
      print
      print -r -- "$(mask_network_prefix 198.51.100.0/24)|$(mask_network_prefix 2001:db8:1234::/48)"
      printf '%s\n' Clean Clean Blacklisted Other Unknown | summarize_dnsbl_results
      (
        query_scope=reputation requested_ip=8.8.8.8
        IPV4check=1 IPV6check=1 IPV4work=0 IPV6work=0 ERRORcode=0
        prepare_explicit_target && print -r -- "$IPV4|$IPV4work|$IPV6check"
      )
    ZSH
    assert_equal ["101010101010", "198.51.*.*/24|2001:db8:*::/48", "5 2 1 1 1", "8.8.8.8|1|0"],
      zsh!(probe, SCRIPT).lines(chomp: true)
  end

  def test_plan_discloses_only_selected_sources_and_explicit_target_limits
    stdout, stderr, status = run_script("--sources", "ripestat,shodan")
    assert status.success?, stderr
    sources = stdout[/  reputation sources:\n((?:    .*\n)+)/, 1]
    assert_equal ["    RIPEstat", "    Shodan InternetDB"], sources.lines.map { |line| line.split(":").first }
    refute_includes stdout, "IPQS"
    refute_includes stdout, "Cloudflare APIs"

    stdout, stderr, status = run_script("--sources", "dbip,ping0,ipqs", "-4", "8.8.8.8")
    assert status.success?, stderr
    assert_includes stdout, "  target: explicit IP"
    assert_includes stdout, "    DB-IP: not applicable to an explicit target (visitor egress only); no request"
    assert_includes stdout, "    Ping0: not applicable to an explicit target"
    refute_includes stdout, "visitor-egress lookup"
    assert_includes stdout, "IPQS direct fallback uses AliDNS"
  end

  def test_dms_coordinates_use_exact_degrees_minutes_and_rounded_seconds
    cases = {
      %w[37.751 -97.822] => "97°49′19″W, 37°45′4″N",
      %w[51.5074 -0.1278] => "0°7′40″W, 51°30′27″N",
      %w[37 -97] => "97°0′0″W, 37°0′0″N",
      %w[12.99999 -0.99999] => "1°0′0″W, 13°0′0″N",
      %w[0.016 0.0001] => "0°0′0″E, 0°0′58″N",
      %w[-60.4832 -172.2297] => "172°13′47″W, 60°29′0″S"
    }
    probe = 'source "$1"; shift; while (( $# ));do print -r -- "$(generate_dms "$1" "$2")"; shift 2;done'
    stdout, stderr, status = zsh(probe, SCRIPT, *cases.keys.flatten)
    assert status.success?, stderr
    assert_equal cases.values, stdout.lines(chomp: true)
  end

  def test_smtp_success_requires_a_greeting_line_not_a_220_substring
    probe = reporter_functions("smtp_greeting_received") + <<~'ZSH'
      for response in "$@";do smtp_greeting_received "$response"&&print -r -- yes||print -r -- no;done
    ZSH
    responses = [
      "220 mx.example.test ESMTP ready",
      "220-mx.example.test greeting\n220 ready",
      "nc: connectx to 2a00:1450:4220::1b port 25 (tcp) failed: Operation timed out",
      "421 4.7.0 Try again later (2201)",
      ""
    ]
    stdout, stderr, status = zsh(probe, *responses)
    assert status.success?, stderr
    assert_equal %w[yes yes no no no], stdout.split
  end

  def test_ipv6_masking_shows_three_canonical_groups_without_ambiguous_colons
    cases = {
      "2001:db8::1" => "2001:db8:0:*:*:*:*:*",
      "fe80::1%en0" => "fe80:0:0:*:*:*:*:*",
      "2001:0DB8:85a3:0000:0000:8a2e:0370:7334" => "2001:db8:85a3:*:*:*:*:*",
      "2606:4700:4700::1111" => "2606:4700:4700:*:*:*:*:*",
      "2001:db8:zz::1" => ""
    }
    probe = 'source "$1"; shift; setopt KSH_ARRAYS; for ip in "$@";do hide_ipv6 "$ip"; print -r -- "$IPhide";done'
    stdout, stderr, status = zsh(probe, SCRIPT, *cases.keys)
    assert status.success?, stderr
    assert_equal cases.values, stdout.lines(chomp: true)
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
        *.psbl.surriel.com*) print -rl -- 127.0.0.4 127.0.0.2 ;;
        *.dnsbl.dronebl.org*) print -rl -- 127.0.0.10 127.255.255.252 ;;
        *.bl.mailspike.net*) print -r -- 198.105.244.11 ;;
        *.rbl.interserver.net*) print -rl -- 127.0.0.5 127.0.0.6 ;;
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
    assert_equal zones.size - 8, dnsbl.fetch("Clean")
    assert_equal 2, dnsbl.fetch("Marked")
    assert_equal 2, dnsbl.fetch("Blacklisted")
    assert_equal 4, dnsbl.fetch("Unknown")
    assert_equal "Blacklisted", dnsbl.dig("Results", "dnsbl-3.uceprotect.net")
    assert_equal "Marked", dnsbl.dig("Results", "bl.spamcop.net")
    assert_equal "Unknown", dnsbl.dig("Results", "b.barracudacentral.org")
    assert_equal "Unknown", dnsbl.dig("Results", "vouch.dwl.spamhaus.org")
    # Multi-record answers, a zone error among codes and a hijacked NXDOMAIN.
    assert_equal "Blacklisted", dnsbl.dig("Results", "psbl.surriel.com")
    assert_equal "Unknown", dnsbl.dig("Results", "dnsbl.dronebl.org")
    assert_equal "Unknown", dnsbl.dig("Results", "bl.mailspike.net")
    assert_equal "Marked", dnsbl.dig("Results", "rbl.interserver.net")
    assert_includes stderr, "正在检测黑名单数据库"
  end

  def test_mail_live_path_discovers_a_public_egress_and_probes_each_service_mx
    # Egress discovery skips private and malformed answers before the first public IPv4.
    write_fake_command("curl", <<~'ZSH')
      case "${@[-1]}" in
        https://ipinfo.io/ip) print -rn -- 10.0.0.1 ;;
        https://ip.sb) print -rn -- not-an-ip ;;
        https://ping0.cc) print -rn -- 12.217.32.68 ;;
        *) print -r -- "${@[-1]}" >> "$IPQUALITY_TEST_NETWORK_ATTEMPTS"; exit 7 ;;
      esac
    ZSH
    write_fake_command("dig", <<~'ZSH')
      case "$*" in
        '+short MX gmail.com') print -rl -- '20 mx2.gmail.test.' '10 mx1.gmail.test.' ;;
        '+short MX 163.com') print -r -- '10 mx.163.test.' ;;
      esac
    ZSH
    write_fake_command("nc", <<~'ZSH')
      print -r -- "$3" >> "$IPQUALITY_TEST_SMTP_HOSTS"
      case "$3" in
        smtp.mailgun.org|mx1.gmail.test.) print -r -- '220 fixture ESMTP' ;;
        *) print -r -- "nc: connectx to $3 port 25 (tcp) failed: Operation timed out" ;;
      esac
    ZSH
    hosts = File.join(reporter_workspace, "smtp-hosts")
    stdout, stderr, status = run_script("--confirm-network-lookup", "--scope", "mail", "-4", "-j",
      env: {"IPQUALITY_TEST_SMTP_HOSTS" => hosts})

    assert status.success?, stderr
    report = JSON.parse(stdout)
    refute_includes stdout, "12.217.32.68"
    assert_equal "12.217.*.*", report.dig("Head", "IP")
    assert_equal true, report.dig("Mail", "Port25")
    assert_equal true, report.dig("Mail", "Gmail")
    %w[163 Outlook QQ].each { |service| assert_equal false, report.dig("Mail", service), service }
    # Only the lowest-preference MX is probed; services without MX make no SMTP call.
    assert_equal %w[smtp.mailgun.org mx1.gmail.test. mx.163.test.], File.readlines(hosts, chomp: true)
  end

  def test_each_scope_requires_only_the_commands_it_runs
    Dir.mktmpdir("ipquality-commands-") do |directory|
      %w[curl jq].each { |name| File.write(File.join(directory, name), "", perm: 0o700) }
      probe = <<~'ZSH'
        source "$1"
        PATH="$2"
        for query_scope in reputation mail dnsbl mail-dnsbl full;do
          output=$(require_dependencies 2>&1)
          code=$?
          [[ -n "$output" ]] && print -r -- "${output%%$'\n'*}"
          print -r -- "$query_scope=$code"
        done
      ZSH
      assert_equal ["reputation=0",
        "ERROR: missing required commands: dig nc", "mail=69",
        "ERROR: missing required commands: dig xargs", "dnsbl=69",
        "ERROR: missing required commands: dig nc xargs", "mail-dnsbl=69",
        "ERROR: missing required commands: dig nc xargs", "full=69"], zsh!(probe, SCRIPT, directory).lines(chomp: true)
    end
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

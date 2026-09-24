# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "open3"
require "json"
require_relative "../common/network_environment"
require_relative "../common/safe_snapshot"
require_relative "../common/text"

class CommonTest < Minitest::Test
  def test_http_envelope_preserves_transport_failures_and_clears_previous_bodies
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      for failure in 28 35 60 7 0;do
        provider_decode_http_response $'{"ok":true}\n200' 0 || exit 1
        provider_decode_http_response $'{"misleading":true}\n200' "$failure"
        print -r -- "${provider_http_response[status]}|${provider_http_response[body]}"
      done
      for wire in $'{"ok":true}\n429' $'Sorry, you have been blocked by Cloudflare\n403' $'forbidden\n403' $'body\n000' 'missing envelope';do
        provider_decode_http_response "$wire" 0 && exit 2
        print -r -- "${provider_http_response[status]}|${provider_http_response[body]}"
      done
      [[ -o KSH_ARRAYS && -o SH_WORD_SPLIT ]]
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
      "http-envelope", File.expand_path("../common/provider_values.zsh", __dir__))
    assert status.success?, stderr
    assert_empty stderr
    assert_equal ["timeout|", "tls_error|", "tls_verification_failed|", "network_error|",
      'ok|{"misleading":true}', "rate_limited|", "cloudflare_blocked|", "http_403|", "network_error|", "network_error|"], stdout.lines.map(&:strip)
  end

  def test_terminal_tables_share_independent_widths_without_report_state_or_option_changes
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT NO_CASE_MATCH
      source "$1"
      widths=$(terminal_table_widths 3 3 Name 地区 Status A $'\033[31m香港\033[0m' unknown)
      print -r -- "$widths"
      terminal_table_row "$widths" Name 地区 Status
      terminal_table_rule "$widths"
      terminal_table_row "$widths" A $'\033[31m香港\033[0m' unknown
      [[ -o KSH_ARRAYS && -o SH_WORD_SPLIT && -o NO_CASE_MATCH ]]
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
      "common-table", File.expand_path("../common/terminal.zsh", __dir__))
    assert status.success?, stderr
    assert_empty stderr
    assert_equal "4 4 7\nName | 地区 | Status \n-----+------+--------\nA    | \e[31m香港\e[0m | unknown\n", stdout
  end

  def test_terminal_tables_reject_incomplete_rows_and_invalid_widths_without_output
    probe = <<~'ZSH'
      source "$1"
      terminal_table_widths 3 0
      (( $? == 2 ))||exit 1
      terminal_table_widths 3 2 one
      (( $? == 2 ))||exit 1
      terminal_table_widths invalid 2 one two
      (( $? == 2 ))||exit 1
      terminal_table_row '3 4' one
      (( $? == 2 ))||exit 1
      terminal_table_row '3 -4' one two
      (( $? == 2 ))||exit 1
      terminal_table_rule '3 invalid'
      (( $? == 2 ))||exit 1
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
      "common-table-invalid", File.expand_path("../common/terminal.zsh", __dir__))
    assert status.success?, stderr
    assert_empty stdout
    assert_empty stderr
  end

  def test_shared_json_values_enforce_types_bounds_and_printable_text
    filter = <<~'JQ'
      include "json_values";
      {
        text: [null, "", "香港", "abc", "abcd", false, [], {}, "\u0000", "\n", "\u001b[31m", "\u007f"] | map(text_or_null(.; 3)),
        integer: [null, 0, 3, -1, 4, 1.5, "1", false, [], {}] | map(integer_or_null(.; 0; 3))
      }
    JQ
    stdout, stderr, status = Open3.capture3("jq", "-n", "-L", File.expand_path("../common", __dir__), filter)
    assert status.success?, stderr
    assert_empty stderr
    result = JSON.parse(stdout)
    assert_equal [true, true, true, true, false, false, false, false, false, false, false, false], result["text"]
    assert_equal [true, true, true, false, false, false, false, false, false, false], result["integer"]
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

  def test_proxy_overrides_clear_only_exact_case_insensitive_proxy_variables
    environment = {
      "HTTP_PROXY" => "http://fixture.invalid",
      "https_proxy" => "http://fixture.invalid",
      "AlL_pRoXy" => "socks5://fixture.invalid",
      "No_PrOxY" => "*",
      "HOME" => "/fixture/home",
      "CUSTOM_HTTP_PROXY" => "retained"
    }.freeze
    overrides = IpQuality::NetworkEnvironment.without_proxy_variables(environment)
    assert_equal %w[HTTP_PROXY https_proxy AlL_pRoXy No_PrOxY].sort, overrides.keys.sort
    assert overrides.values.all?(&:nil?)
    assert_equal "*", environment.fetch("No_PrOxY")
    assert_equal "/fixture/home", environment.fetch("HOME")
  end

  def test_snapshot_read_enforces_size_and_verify_only_keeps_file_policy
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

      File.rename(path, File.join(directory, "previous"))
      File.write(path, "abcd")
      File.chmod(0o600, path)
      refute IpQuality::SafeSnapshot.same?(snapshot, IpQuality::SafeSnapshot.read(path))
    end
  end
end

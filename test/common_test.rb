# frozen_string_literal: true

require_relative "support/reporter_test_case"
require_relative "../common/network_environment"

class CommonTest < ReporterTestCase
  def test_secret_curl_options_stay_on_stdin_and_preserve_arguments_and_exit_status
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT NO_CASE_MATCH
      curl(){ print -u2 -- unexpected-request-on-load; return 99; }
      source "$1"
      capture_dir="$2"
      curl(){
        print -rl -- "$@" > "$capture_dir/$request_kind.args"
        cat > "$capture_dir/$request_kind.config"
        print -rn -- fixture-response
        return 35
      }
      request_kind=url
      curl_with_secret_url 'https://fixture.invalid/account/fixture-secret' --proxy 'http://127.0.0.1:12345' --max-time 10
      print -r -- "|$?"
      request_kind=header
      curl_with_secret_header Authorization 'Bearer fixture-secret' 'https://fixture.invalid/lookup?ip=1.1.1.1' --noproxy '*' --max-filesize 1024
      print -r -- "|$?"
      [[ -o KSH_ARRAYS && -o SH_WORD_SPLIT && -o NO_CASE_MATCH ]]
    ZSH
    Dir.mktmpdir("ip-quality-http-request-") do |directory|
      stdout, stderr, status = zsh(probe, COMMON_HTTP_LIBRARY, directory)
      assert status.success?, stderr
      assert_empty stderr
      assert_equal "fixture-response|35\nfixture-response|35\n", stdout
      assert_equal ["-q", "--proxy", "http://127.0.0.1:12345", "--max-time", "10", "--config", "-"],
        File.readlines(File.join(directory, "url.args"), chomp: true)
      assert_equal ["-q", "--noproxy", "*", "--max-filesize", "1024", "--config", "-"],
        File.readlines(File.join(directory, "header.args"), chomp: true)
      assert_equal "url = \"https://fixture.invalid/account/fixture-secret\"\n",
        File.read(File.join(directory, "url.config"))
      assert_equal "header = \"Authorization: Bearer fixture-secret\"\nurl = \"https://fixture.invalid/lookup?ip=1.1.1.1\"\n",
        File.read(File.join(directory, "header.config"))
    end
  end

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
    stdout, stderr, status = zsh(probe, COMMON_PROVIDER_LIBRARY)
    assert status.success?, stderr
    assert_empty stderr
    assert_equal ["timeout|", "tls_error|", "tls_verification_failed|", "network_error|",
      'ok|{"misleading":true}', "rate_limited|", "cloudflare_blocked|", "http_403|", "network_error|", "network_error|"], stdout.lines.map(&:strip)
  end

  def test_json_fields_read_several_values_in_one_pass_without_shifting
    probe = <<~'ZSH'
      source "$1"
      setopt KSH_ARRAYS SH_WORD_SPLIT
      provider_json_fields "$2" '.a, .b, .c, .d, .missing' a b c d e||exit 3
      print -r -- "${provider_fields[a]}|${provider_fields[b]}|${provider_fields[c]}|${provider_fields[d]}|${provider_fields[e]}"
      provider_json_fields '{"a":[1,2]}' '.a[]' a&&exit 4
      provider_json_fields 'not json' '.a' a&&exit 5
      print -r -- "${#provider_fields}"
    ZSH
    json = JSON.generate("a" => 64_500, "b" => nil, "c" => "x\u0000y z", "d" => true)
    stdout, stderr, status = zsh(probe, COMMON_PROVIDER_LIBRARY, json)
    assert status.success?, stderr
    assert_equal "64500|null|xy z|true|null\n0\n", stdout
  end

  def test_shared_json_values_enforce_types_bounds_and_printable_text
    filter = <<~'JQ'
      include "json_values";
      {
        boolean: [null, false, true, "false", 0, [], {}] | map(boolean_or_null(.)),
        text: [null, "", "香港", "abc", "abcd", false, [], {}, "\u0000", "\n", "\u001b[31m", "\u007f"] | map(text_or_null(.; 3)),
        integer: [null, 0, 3, -1, 4, 1.5, "1", false, [], {}] | map(integer_or_null(.; 0; 3))
      }
    JQ
    stdout, stderr, status = Open3.capture3("jq", "-n", "-L", File.join(ROOT, "common"), filter)
    assert status.success?, stderr
    assert_empty stderr
    result = JSON.parse(stdout)
    assert_equal [true, true, true, false, false, false, false], result["boolean"]
    assert_equal [true, true, true, true, false, false, false, false, false, false, false, false], result["text"]
    assert_equal [true, true, true, false, false, false, false, false, false, false], result["integer"]
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

end

# frozen_string_literal: true

require_relative "support/reporter_test_case"

class CheckPlaceTest < ReporterTestCase
  def test_confirmed_block_or_rate_limit_stops_later_relay_requests_without_stale_data
    [
      [File.read(CHECK_PLACE_CLOUDFLARE_FIXTURE) + "\n403", "cloudflare_blocked"],
      ["slow down\n429", "rate_limited"]
    ].each do |wire, failure|
      stdout, stderr, status, calls = run_relay_probe(wire, <<~'ZSH')
        for query in lang=cn lang=en db=scamalytics db=abuseipdb db=ip2location db=ipdata db=ipqualityscore;do
          PROVIDER_RESPONSE_BODY='{"fraud_score":0}'
          check_place_fetch_json 4 198.51.100.23 "$query" 65536
          print -r -- "$?|$PROVIDER_RESPONSE_STATUS|$PROVIDER_RESPONSE_BODY"
        done
      ZSH
      assert status.success?, stderr
      assert_empty stderr
      assert_equal ["1|#{failure}|"] + Array.new(6, "1|skipped_relay_#{failure}|"), stdout.lines.map(&:strip)
      assert_equal ["https://ipinfo.check.place/198.51.100.23?lang=cn"], calls
    end
  end

  def test_pauses_are_bound_to_target_family_and_run_and_leave_official_sources_available
    stdout, stderr, status, calls = run_relay_probe("Sorry, you have been blocked by Cloudflare\n403", <<~'ZSH')
      check_place_fetch_json 4 198.51.100.23 lang=cn
      check_place_fetch_json 4 198.51.100.23 db=ipdata
      print -r -- "$PROVIDER_RESPONSE_STATUS"
      check_place_fetch_json 4 198.51.100.24 db=ipdata
      print -r -- "$PROVIDER_RESPONSE_STATUS"
      check_place_fetch_json 6 198.51.100.23 db=ipdata
      print -r -- "$PROVIDER_RESPONSE_STATUS"
      curl(){
        print -r -- "${@[-1]}" >> "$calls_file"
        print -rn -- $'{"success":true}\n200'
      }
      provider_fetch_public_json 4 'https://api.cloudflare.com/fixture' 65536
      print -r -- "$PROVIDER_RESPONSE_STATUS|$PROVIDER_RESPONSE_BODY"
      source "$relay_library"
      check_place_fetch_json 4 198.51.100.23 lang=cn
      print -r -- "$PROVIDER_RESPONSE_STATUS"
    ZSH
    assert status.success?, stderr
    assert_empty stderr
    assert_equal ["skipped_relay_cloudflare_blocked", "cloudflare_blocked", "cloudflare_blocked", 'ok|{"success":true}', "ok"], stdout.lines.map(&:strip)
    assert_equal 5, calls.length
    assert_equal 'https://api.cloudflare.com/fixture', calls[3]
  end

  def test_unrelated_http_transport_schema_failures_and_success_do_not_pause_the_relay
    [["forbidden\n403", 0, "http_403"], ["\n000", 28, "timeout"],
     ["not JSON\n200", 0, "invalid_response"], ['{"value":1}' + "\n200", 0, "ok"]].each do |wire, curl_exit, expected|
      stdout, stderr, status, calls = run_relay_probe(wire, <<~'ZSH', curl_exit: curl_exit)
        check_place_fetch_json 4 198.51.100.23 lang=cn
        check_place_fetch_json 4 198.51.100.23 db=scamalytics
        print -r -- "$PROVIDER_RESPONSE_STATUS"
      ZSH
      assert status.success?, stderr
      assert_empty stderr
      assert_equal "#{expected}\n", stdout
      assert_equal 2, calls.length
    end
  end

  private

  def run_relay_probe(wire, operations, curl_exit: 0)
    Dir.mktmpdir("check-place-policy-") do |directory|
      response = File.join(directory, "response")
      calls = File.join(directory, "calls")
      File.write(response, wire)
      File.write(calls, "")
      probe = <<~'ZSH'
        source "$1"
        relay_library="$2"
        source "$relay_library"
        eval "$3"
        response_file="$4" calls_file="$5" curl_exit="$6"
        curl(){
          print -r -- "${@[-1]}" >> "$calls_file"
          print -rn -- "$(<"$response_file")"
          return "$curl_exit"
        }
      ZSH
      result = Open3.capture3("/bin/zsh", "-f", "-c", probe + operations,
        "relay-policy", COMMON_PROVIDER_LIBRARY, File.join(ROOT, "providers", "check_place.zsh"),
        reporter_functions("provider_fetch_public_json"), response, calls, curl_exit.to_s)
      result + [File.readlines(calls, chomp: true)]
    end
  end
end

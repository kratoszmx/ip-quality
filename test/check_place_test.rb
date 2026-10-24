# frozen_string_literal: true

require_relative "support/reporter_test_case"

class CheckPlaceTest < ReporterTestCase
  parallelize_me!

  def test_maxmind_rejects_malformed_and_empty_observations_without_stale_fields_or_jq_errors
    [
      '{"ASN":"unavailable","City":"unavailable","Country":"unavailable"}',
      '{"ASN":[],"Country":{"IsoCode":"HK"}}',
      '{"City":{"Country":"unavailable"}}',
      '{"City":{"Location":"unavailable"},"Country":{"IsoCode":"HK"}}',
      '{"City":{"Subdivisions":"unavailable"},"Country":{"IsoCode":"HK"}}',
      '{"City":{"Subdivisions":["unavailable"]},"Country":{"IsoCode":"HK"}}',
      '{"Country":{"IsoCode":"HK","RegisteredCountry":"unavailable"}}',
      '{"ASN":{"AutonomousSystemNumber":true}}',
      '{"City":{"Latitude":true,"Longitude":0}}',
      '{"City":{"Continent":"unavailable","Name":"Example City"}}',
      '{"ASN":{"AutonomousSystemOrganization":{"error":"unavailable"}}}',
      '{"City":{"Name":"unsafe\u001btext"}}',
      '{"error":"unavailable","ASN":{"AutonomousSystemNumber":64500}}',
      '{"ASN":{},"City":{},"Country":{}}',
      '{"Country":{"IsoCode":"HK"}} {"Country":{"IsoCode":"HK"}}',
      '{}', 'null', '[]', ''
    ].each do |response|
      result = run_maxmind_probe(response, language: "cn")
      assert_equal "invalid_response", result["Status"], response
      assert_equal "ipinfo", result["Source"], response
      %w[ASN Organization City Map].each { |key| assert_equal "", result[key], response }
      assert_equal 1, result["Calls"], "invalid primary must not request a translation"
    end
  end

  def test_maxmind_preserves_valid_utf8_backslashes_zero_coordinates_and_partial_fields
    payload = JSON.parse(File.read(fixture_path("check_place/maxmind.json")))
    payload["ASN"]["AutonomousSystemOrganization"] = 'Example \\network'
    payload["City"]["Name"] = "示例城市"
    result = run_maxmind_probe(JSON.generate(payload))
    assert_equal "ok", result["Status"]
    assert_equal "maxmind", result["Source"]
    assert_equal 'Example \\network', result["Organization"]
    assert_equal "示例城市", result["City"]
    assert_equal ["0", "0"], result.values_at("Latitude", "Longitude")
    assert_includes result["Map"], "0,0"

    result = run_maxmind_probe('{"ASN":{"AutonomousSystemNumber":"64500"}}')
    assert_equal "ok", result["Status"]
    assert_equal "64500", result["ASN"]
    assert_equal "null", result["City"]
    assert_equal "null", result["Map"]
  end

  def test_maxmind_transport_failure_keeps_original_status_and_clears_stale_data
    result = run_maxmind_probe(File.read(fixture_path("check_place/maxmind.json")), primary_status: "timeout", language: "cn")
    assert_equal "timeout", result["Status"]
    assert_equal "ipinfo", result["Source"]
    assert_equal "", result["ASN"]
    assert_equal "", result["City"]
    assert_equal 1, result["Calls"]
  end

  def test_invalid_or_failed_english_translation_cannot_erase_valid_primary_observations
    payload = JSON.parse(File.read(fixture_path("check_place/maxmind.json")))
    payload["City"]["Name"] = nil
    [["ok", '{"City":"unavailable"}'], ["timeout", ""]].each do |state, response|
      result = run_maxmind_probe(JSON.generate(payload), language: "cn", backup: response, backup_status: state)
      assert_equal "ok", result["Status"]
      assert_equal "maxmind", result["Source"]
      assert_equal "64500", result["ASN"]
      assert_equal "Example Network", result["Organization"]
      assert_equal "null", result["City"]
      assert_includes result["Map"], "0,0"
      assert_equal 2, result["Calls"]
    end
  end

  def test_valid_english_translation_fills_missing_fields_without_overwriting_primary_values
    result = run_maxmind_probe('{"ASN":{"AutonomousSystemNumber":64501}}',
      language: "cn", backup: File.read(fixture_path("check_place/maxmind.json")))
    assert_equal "ok", result["Status"]
    assert_equal "64501", result["ASN"]
    assert_equal "Example Network", result["Organization"]
    assert_equal "Example City", result["City"]
    assert_equal 2, result["Calls"]
  end

  def test_invalid_maxmind_response_uses_ipinfo_in_actual_json_and_terminal_reports
    calls = File.join(reporter_workspace, "calls")
    report_path = File.join(reporter_workspace, "report.txt")
    write_fake_command("curl", <<~'ZSH')
      print -r -- "${@[-1]}" >> "$IPQUALITY_TEST_CALLS"
      case "${@[-1]}" in
      https://ipinfo.check.place/*)
        print -rn -- $'{"ASN":"unavailable","City":"unavailable","Country":"unavailable"}\n200' ;;
      https://ipinfo.io/widget/demo/*)
        print -rn -- $'{"data":{"asn":{"asn":"AS64500","name":"Example Network","type":"isp"},"country":"HK","city":"Example City","loc":"0,0"}}\n200' ;;
      *) print -r -- unexpected >> "$IPQUALITY_TEST_NETWORK_ATTEMPTS"; exit 97 ;;
      esac
    ZSH
    stdout, stderr, status = run_script("--sources", "ipinfo,maxmind", "--confirm-network-lookup",
      "-4", "-j", "-o", report_path, "1.1.1.1", env: {"IPQUALITY_TEST_CALLS" => calls})
    assert status.success?, stderr
    refute_includes stderr, "jq:"
    report = JSON.parse(stdout)
    assert_equal "invalid_response", report.dig("ProviderStatus", "CheckPlaceMaxMind")
    assert_equal "ok", report.dig("ProviderStatus", "IPinfo")
    assert_equal "IPinfo public demo widget", report.dig("Info", "Source")
    assert_equal "64500", report.dig("Info", "ASN")
    text = File.read(report_path)
    assert_includes text, "IPinfo 公开示例组件"
    assert_includes text, "Example City"
    refute_includes text, "unavailable"
    assert_equal 2, File.readlines(calls).length
  end

  def test_confirmed_block_or_rate_limit_stops_later_relay_requests_without_stale_data
    [
      [File.read(fixture_path("check_place/cloudflare-blocked.html")) + "\n403", "cloudflare_blocked"],
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

  def run_maxmind_probe(primary, backup: "{}", language: "en", primary_status: "ok", backup_status: "ok")
    probe = <<~'ZSH'
      source "$1"
      fixture_primary="$2" fixture_backup="$3" YY="$4"
      fixture_primary_status="$5" fixture_backup_status="$6"
      request_count=0
      show_progress(){ :; }
      check_place_fetch_json(){
        (( request_count += 1 ))
        if (( request_count == 1 ));then
          PROVIDER_RESPONSE_BODY="$fixture_primary" PROVIDER_RESPONSE_STATUS="$fixture_primary_status"
        else
          PROVIDER_RESPONSE_BODY="$fixture_backup" PROVIDER_RESPONSE_STATUS="$fixture_backup_status"
        fi
      }
      maxmind[asn]=999 maxmind[city]=stale maxmind[org]=stale maxmind[map]=stale
      basic_source=maxmind
      db_maxmind_relay 4 || true
      jq -cn --arg status "${maxmind[status]}" --arg source "$basic_source" \
        --arg asn "${maxmind[asn]}" --arg organization "${maxmind[org]}" \
        --arg city "${maxmind[city]}" --arg lat "${maxmind[lat]}" --arg lon "${maxmind[lon]}" \
        --arg map "${maxmind[map]}" --argjson calls "$request_count" \
        '{Status:$status,Source:$source,ASN:$asn,Organization:$organization,City:$city,Latitude:$lat,Longitude:$lon,Map:$map,Calls:$calls}'
    ZSH
    stdout, stderr, status = zsh(probe, SCRIPT, primary, backup, language, primary_status, backup_status)
    assert status.success?, stderr
    assert_empty stderr
    JSON.parse(stdout)
  end

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
      result = zsh(probe + operations, COMMON_PROVIDER_LIBRARY, provider_library("check_place"),
        reporter_functions("provider_fetch_public_json"), response, calls, curl_exit.to_s)
      result + [File.readlines(calls, chomp: true)]
    end
  end
end

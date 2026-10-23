# frozen_string_literal: true

require_relative "support/reporter_test_case"

class ScamalyticsTest < ReporterTestCase
  LIBRARY = File.join(ROOT, "providers", "scamalytics.zsh")
  FIXTURE = File.join(ROOT, "test", "fixtures", "scamalytics", "public-page.html")

  def test_public_page_is_bound_to_heading_example_and_badge_and_preserves_zero_and_false
    out, err, result = parse_page(File.read(FIXTURE))
    assert result.success?, err
    assert_empty err
    assert_equal "0|low|US|false|false|false|true|false|false\n", out
    ipv6 = File.read(FIXTURE).gsub("198.51.100.23", "2001:4860:4860::8888")
    out, err, result = parse_page(ipv6, "2001:4860:4860::8888")
    assert result.success?, err
    assert_match(/\A0\|low\|/, out)
  end

  def test_mismatch_ambiguous_values_schema_drift_and_oversize_clear_stale_data
    body = File.read(FIXTURE)
    invalid = [body.sub('<h1>198.51.100.23', '<h1>8.8.8.8'),
      body.sub('"ip":"198.51.100.23"', '"ip":"8.8.8.8"'),
      body.sub("Fraud Score: 0", "Fraud Score: 1"),
      body.gsub('"0"', '"101"').sub("Score: 0", "Score: 101"),
      body.sub('"risk":"low"', '"risk":"unknown"'),
      body + '<h1>198.51.100.23 Fraud Risk</h1>',
      body + body[/<pre.*?<\/pre>/m],
      body.sub('"is_blacklisted_external": false', '"is_blacklisted_external": "false"'),
      "<html>Just a moment...</html>", body + " " * 262_144]
    invalid.each do |page|
      out, err, result = parse_page(page)
      refute result.success?
      assert_empty out
      assert_empty err
    end
  end

  def test_missing_and_conflicting_factor_cells_are_unknown_without_losing_the_score
    body = File.read(FIXTURE)
    body = body.sub(%r{<tr><th>Web Proxy</th>.*?</tr>}, "")
      .sub('<div class="risk no">No</div>', '<div class="risk yes">No</div>')
    body += '<tr><th>Country Code</th><td>CN</td></tr>'
    body += '<tr><th>Server</th><td><div class="risk no">No</div></td></tr>'
    out, err, result = parse_page(body)
    assert result.success?, err
    assert_equal "0|low||||false||false|false\n", out
    body = body.sub('<th>Public Proxy</th><td><div class="risk no">No', '<th>Public Proxy</th><td><div class="risk yes">Yes')
    out, err, result = parse_page(body)
    assert result.success?, err
    assert_equal "true", out.split("|")[3]
  end

  def test_failed_relay_uses_one_same_route_target_page_and_records_both_outcomes
    probe = <<~'ZSH'
      source "$1"
      source "$2"
      eval "$3"
      typeset -A scamalytics sinfo
      IP=198.51.100.23
      CurlARG='--proxy http://127.0.0.1:12345'
      setopt SH_WORD_SPLIT
      show_progress(){ :; }
      check_place_fetch_json(){
        [[ "$1/$2/$3" == '4/198.51.100.23/db=scamalytics' ]]||exit 98
        PROVIDER_RESPONSE_STATUS="$relay_state" PROVIDER_RESPONSE_BODY="$relay_body"
      }
      curl(){
        print -r -- called >> "$calls_file"
        [[ "$*" == *'--proxy http://127.0.0.1:12345'* && "$*" == *'-4'* && "${@[-1]}" == 'https://scamalytics.com/ip/198.51.100.23' ]]||exit 99
        print -r -- "$(<"$page_file")"
        print -rn -- "$http"
        return "$curl_exit"
      }
      page_file="$4" calls_file="$5" relay_state="$6" relay_body="$7" http="$8" curl_exit="$9"
      scamalytics[score]=88 scamalytics[proxy]=true
      db_scamalytics 4
      print -r -- "${scamalytics[source]}|${scamalytics[status]}|${scamalytics[relay_status]}|${scamalytics[score]}|${scamalytics[proxy]}"
    ZSH
    cases = [
      ["skipped_relay_cloudflare_blocked", "", "200", 0, "ok", "0|false"],
      ["rate_limited", "", "200", 0, "ok", "0|false"],
      ["ok", '{"scamalytics":"bad schema"}', "200", 0, "ok", "0|false"],
      ["timeout", "", "000", 35, "tls_error", "|"],
      ["http_403", "", "429", 0, "rate_limited", "|"]
    ]
    Dir.mktmpdir("scamalytics-route-") do |dir|
      calls = File.join(dir, "calls")
      cases.each do |relay, body, http, curl_exit, expected, fields|
        File.write(calls, "")
        out, err, result = zsh(probe, COMMON_PROVIDER_LIBRARY, LIBRARY, reporter_functions("db_scamalytics"),
          FIXTURE, calls, relay, body, http, curl_exit.to_s)
        assert result.success?, err
        assert_empty err
        relay = "invalid_response" if relay == "ok"
        assert_equal "public_demo|#{expected}|#{relay}|#{fields}\n", out
        assert_equal ["called"], File.readlines(calls, chomp: true)
      end
    end
  end

  def test_successful_relay_does_not_make_a_public_page_request
    probe = <<~'ZSH'
      source "$1"
      eval "$2"
      typeset -A scamalytics sinfo
      IP=198.51.100.23
      show_progress(){ :; }
      check_place_fetch_json(){
        PROVIDER_RESPONSE_STATUS=ok
        PROVIDER_RESPONSE_BODY='{"scamalytics":{"scamalytics_score":7,"scamalytics_proxy":{"is_vpn":true}}}'
      }
      curl(){ print -ru2 -- unexpected; exit 99; }
      db_scamalytics 4
      print -r -- "${scamalytics[source]}|${scamalytics[status]}|${scamalytics[score]}|${scamalytics[vpn]}"
    ZSH
    out, err, result = zsh(probe, COMMON_PROVIDER_LIBRARY, reporter_functions("db_scamalytics"))
    assert result.success?, err
    assert_empty err
    assert_equal "check_place_relay|ok|7|true\n", out
  end

  private

  def parse_page(page, target = "198.51.100.23")
    probe = <<~'ZSH'
      source "$1"
      page=$(cat)
      scamalytics_parsed[score]=99
      if ! scamalytics_parse_page "$page" "$2";then
        [[ -z "${scamalytics_parsed[score]}" ]]||print -r -- stale
        exit 1
      fi
      print -r -- "${scamalytics_parsed[score]}|${scamalytics_parsed[risk]}|${scamalytics_parsed[countrycode]}|${scamalytics_parsed[proxy]}|${scamalytics_parsed[vpn]}|${scamalytics_parsed[tor]}|${scamalytics_parsed[server]}|${scamalytics_parsed[abuser]}|${scamalytics_parsed[robot]}"
    ZSH
    zsh(probe, LIBRARY, target, stdin_data: page)
  end
end

# frozen_string_literal: true
require_relative "support/reporter_test_case"

class DbipTest < ReporterTestCase
  LIBRARY = File.join(ROOT, "providers", "dbip.zsh")
  FIXTURE = File.join(ROOT, "test", "fixtures", "dbip", "free.json")

  def test_demo_contract_rejects_bad_geography_and_does_not_invent_scores
    fixture = JSON.parse(File.read(FIXTURE))
    probe = 'source "$1"; dbip_parse_response "$2" "198.51.100.23" || exit 1; print -r -- "${dbip_parsed[country_code]}|${dbip_parsed[city]}|${dbip_parsed[score]:-}|${dbip_parsed[proxy]:-}"'
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "dbip-fixture", LIBRARY, JSON.generate(fixture.merge("threatLevel" => "low", "isProxy" => false)))
    assert status.success?, stderr
    assert_equal "US|Example City||\n", stdout
    assert_empty stderr
    [[], fixture.merge("ipAddress" => "8.8.8.8"), fixture.merge("countryCode" => ["US"]), fixture.merge("city" => "\e[31m"), fixture.merge("errorCode" => "QUOTA_EXCEEDED")].each do |body|
      _, errors, result = Open3.capture3("/bin/zsh", "-f", "-c", probe, "dbip-invalid", LIBRARY, JSON.generate(body))
      refute result.success?
      assert_empty errors
    end
  end

  def test_runtime_keeps_both_demo_requests_on_route_and_stops_on_failure_or_mismatch
    probe = <<~'ZSH'
      source "$1"
      source "$6"
      eval "$2"
      typeset -A dbip sinfo sscore
      IP=198.51.100.23 ibar_step=0
      CurlARG='--proxy http://127.0.0.1:12345'
      setopt SH_WORD_SPLIT
      calls_file="$5"
      sinfo[ldatabase]=0
      show_progress_bar(){ :; }
      curl_with_secret_url(){
        print -r -- call >> "$calls_file"
        [[ "$*" == *'--proxy http://127.0.0.1:12345'* && "$*" == *'-6'* && "$*" == *'Origin: https://db-ip.com'* && "$*" == *'Referer: https://db-ip.com/'* ]] || exit 99
        if [[ "$1" == 'https://db-ip.com/api/core/' ]];then
          [[ "$scenario" == network_error ]]&&return 28
          if [[ "$scenario" == rate_limited ]];then
            print -r -- '{}'
            print -r -- 429
            return
          fi
          if [[ "$scenario" == invalid_response ]];then
            print -r -- '<html>unexpected page</html>'
          else
            print -r -- '<script data-api-key="fixture-guest-key"></script>'
          fi
        elif [[ "$1" == 'https://api.db-ip.com/v2/fixture-guest-key/self?convertCurrencies' ]];then
          if [[ "$scenario" == ip_mismatch ]];then
            print -r -- "$fixture"|jq -c '.ipAddress="8.8.8.8"'
          else
            print -r -- "$fixture"
          fi
        else
          exit 98
        fi
        print -r -- 200
      }
      fixture=$(<"$3")
      for scenario in ok rate_limited invalid_response network_error ip_mismatch;do
        : > "$calls_file"
        db_dbip 6
        calls=$(wc -l < "$calls_file")
        print -r -- "${calls// /}|${dbip[status]}|${dbip[city]:-}"
      done
    ZSH
    Dir.mktmpdir("ipquality-dbip-test-") do |directory|
      stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "dbip-runtime", LIBRARY, reporter_functions("db_dbip"), FIXTURE, "unused", File.join(directory, "calls"), COMMON_PROVIDER_LIBRARY)
      assert status.success?, stderr
      assert_equal "2|ok|Example City\n1|rate_limited|\n1|invalid_response|\n1|timeout|\n2|ip_mismatch|\n", stdout
      assert_empty stderr
    end
  end

  def test_public_guest_key_is_bounded_and_cannot_inject_a_url_or_curl_option
    probe = 'source "$1"; dbip_demo_key_from_page "$2"'
    ["a\" -K evil", "a/b", "a\nheader", "a" * 129, "short"].each do |key|
      stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "dbip-key", LIBRARY, "<script data-api-key=\"#{key}\"></script>")
      refute status.success?
      assert_empty stdout
      assert_empty stderr
    end
  end
end

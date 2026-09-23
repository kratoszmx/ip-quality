# frozen_string_literal: true
require_relative "support/reporter_test_case"

class DbipTest < ReporterTestCase
  LIBRARY = File.join(ROOT, "providers", "dbip.zsh")
  FIXTURE = File.join(ROOT, "test", "fixtures", "dbip", "free.json")

  def test_free_contract_keeps_only_geography_and_rejects_error_mismatch_and_schema_drift
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

  def test_runtime_requests_free_endpoint_once_and_keeps_failure_explicit
    probe = <<~'ZSH'
      source "$1"
      eval "$2"
      typeset -A dbip sinfo
      IP=198.51.100.23 ibar_step=0
      sinfo[ldatabase]=0
      show_progress_bar(){ :; }
      provider_fetch_public_json(){
        [[ "$1" == 4 && "$2" == 'https://api.db-ip.com/v2/free/198.51.100.23' ]] || exit 99
        ((calls+=1))
        PROVIDER_RESPONSE_STATUS="$response_status" PROVIDER_RESPONSE_BODY="$fixture"
      }
      fixture=$(<"$3")
      for response_status in ok rate_limited;do
        calls=0
        db_dbip 4
        print -r -- "$calls|${dbip[status]}|${dbip[city]:-}"
      done
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe, "dbip-runtime", LIBRARY, reporter_functions("db_dbip"), FIXTURE)
    assert status.success?, stderr
    assert_equal "1|ok|Example City\n1|rate_limited|\n", stdout
    assert_empty stderr
  end
end

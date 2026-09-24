# frozen_string_literal: true
require_relative "support/reporter_test_case"

class PublicDemoTest < ReporterTestCase
  def test_demo_parsers_preserve_labels_false_flags_and_unknown_fields
    dbip = fixture("dbip", "demo")
    whois = fixture("ipwhois", "demo")
    assert_equal "0|ok|ok|low||", parse("dbip", dbip)
    assert_equal "0|ok|ok|false|true|false|true", parse("ipwhois", whois)
    dbip.delete("threatLevel")
    whois.delete("security")
    assert_equal "0|ok|not_provided|||", parse("dbip", dbip)
    assert_equal "0|ok|not_provided||||", parse("ipwhois", whois)
    whois["security"] = { "vpn" => false }
    assert_equal "0|ok|ok||false||", parse("ipwhois", whois)
  end

  def test_http_200_demo_rate_limits_clear_previous_data_and_remain_unknown
    %w[dbip ipwhois].each do |provider|
      result = parse(provider, fixture(provider, "demo-rate-limited"))
      assert_match(/\A1\|rate_limited\|\|+\z/, result)
      refute_includes result, "false"
      refute_includes result, "low"
    end
  end

  def test_demo_parsers_reject_wrong_ip_string_booleans_and_nested_schema_drift
    dbip = fixture("dbip", "demo")
    whois = fixture("ipwhois", "demo")
    [nil, [], "not an object", { "status" => "ok", "demoInfo" => "error" },
     dbip.merge("ipAddress" => "8.8.8.8"),
     dbip.merge("threatLevel" => 0),
     dbip.merge("threatLevel" => "clean")].each do |body|
      assert_match(/\A1\|/, parse("dbip", body))
    end
    [nil, [], "not an object", whois.merge("ip" => "8.8.8.8"),
     whois.merge("security" => "premium"), whois.merge("security" => { "vpn" => "false" }),
     whois.merge("connection" => { "org" => "\e[31minjected" })].each do |body|
      assert_match(/\A1\|/, parse("ipwhois", body))
    end
  end

  def test_ipwhois_runtime_fetches_demo_once_and_clears_stale_fields
    probe = <<~'ZSH'
      setopt KSH_ARRAYS SH_WORD_SPLIT
      source "$1"
      eval "$2"
      shift 2
      typeset -A ipwhois sinfo
      IP=198.51.100.23 ibar_step=0
      sinfo[ldatabase]=0
      show_progress_bar(){ :; }
      provider_fetch_public_json(){
        [[ "$1" == 4 && "$2" == 'https://ipwhois.io/demo?ip=198.51.100.23' ]] || exit 99
        [[ "$*" == *'Origin: https://ipwhois.io'* && "$*" == *'Referer: https://ipwhois.io/'* && "$*" == *Mozilla/5.0* ]] || exit 98
        ((calls+=1))
        PROVIDER_RESPONSE_STATUS=ok PROVIDER_RESPONSE_BODY="$body"
      }
      for body in "$@";do
        calls=0
        db_ipwhois 4
        print -r -- "$?|$calls|${ipwhois[status]}|${ipwhois[risk_status]}|${ipwhois[countrycode]}|${ipwhois[asn]}|${ipwhois[org]}|${ipwhois[isp]}|${ipwhois[timezone]}|${ipwhois[proxy]}|${ipwhois[vpn]}|${ipwhois[tor]}|${ipwhois[server]}"
      done
    ZSH
    # Reuse one runtime state: absent flags, quota failures and mismatched IPs
    # must never inherit a preceding successful result.
    responses = %w[demo valid demo-rate-limited demo mismatch].map do |name|
      JSON.generate(fixture("ipwhois", name))
    end
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
      "demo-runtime", IPWHOIS_LIBRARY, reporter_functions("db_ipwhois"), *responses)
    assert status.success?, stderr
    assert_empty stderr
    demo = [0, 1, "ok", "ok", "US", 64500, "Example Network", "Example ISP", "", false, true, false, true]
    context_only = [0, 1, "ok", "not_provided", "US", 64500, "Example Network", "Example ISP", "America/Los_Angeles", "", "", "", ""]
    expected = [demo, context_only, [0, 1, "rate_limited", *Array.new(10, "")],
                demo, [0, 1, "invalid_response", *Array.new(10, "")]]
    assert_equal expected.map { |fields| fields.join("|") }, stdout.lines.map(&:chomp)
  end

  private

  def fixture(provider, name)
    JSON.parse(File.read(File.join(ROOT, "test", "fixtures", provider, "#{name}.json")))
  end

  def parse(provider, body)
    fields = provider == "dbip" ? %w[threat_level score proxy] : %w[proxy vpn tor hosting]
    values = %w[status risk_status].concat(fields).map { |key| "${#{provider}_parsed[#{key}]}" }.join("|")
    probe = "source \"$1\"; #{provider}_parsed[#{fields.first}]=stale; #{provider}_parse_response \"$2\" 198.51.100.23; print -r -- \"$?|#{values}\""
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
      "demo-parser", File.join(ROOT, "providers", "#{provider}.zsh"), JSON.generate(body))
    assert status.success?, stderr
    assert_empty stderr
    stdout.chomp
  end
end

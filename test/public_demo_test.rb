# frozen_string_literal: true
require_relative "support/reporter_test_case"

class PublicDemoTest < ReporterTestCase
  def test_demo_parsers_preserve_labels_false_flags_and_unknown_fields
    dbip = fixture("dbip", "demo")
    whois = fixture("ipwhois", "demo")
    assert_equal "0|ok|ok|low||", parse("dbip", dbip)
    assert_equal "0|ok|ok|false|true|false|true", parse("ipwhois", whois)
    dbip["demoInfo"].delete("threatLevel")
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
     { "status" => "ok", "demoInfo" => dbip["demoInfo"].merge("ipAddress" => "8.8.8.8") },
     { "status" => "ok", "demoInfo" => dbip["demoInfo"].merge("threatLevel" => 0) },
     { "status" => "ok", "demoInfo" => dbip["demoInfo"].merge("threatLevel" => "clean") }].each do |body|
      assert_match(/\A1\|/, parse("dbip", body))
    end
    [nil, [], "not an object", whois.merge("ip" => "8.8.8.8"),
     whois.merge("security" => "premium"), whois.merge("security" => { "vpn" => "false" }),
     whois.merge("connection" => { "org" => "\e[31minjected" })].each do |body|
      assert_match(/\A1\|/, parse("ipwhois", body))
    end
  end

  def test_ipwhois_runtime_selects_current_demo_once_and_clears_fields_on_rate_limit
    probe = <<~'ZSH'
      source "$1"
      eval "$2"
      typeset -A ipwhois sinfo
      IP=198.51.100.23 ibar_step=0
      sinfo[ldatabase]=0
      show_progress_bar(){ :; }
      provider_fetch_public_json(){
        [[ "$1" == 4 && "$2" == 'https://ipwhois.io/demo?ip=198.51.100.23' ]] || exit 99
        ((calls+=1))
        PROVIDER_RESPONSE_STATUS=ok PROVIDER_RESPONSE_BODY="$body"
      }
      for body in "$3" "$4";do
        calls=0
        db_ipwhois 4
        print -r -- "$calls|${ipwhois[status]}|${ipwhois[proxy]}|${ipwhois[vpn]}|${ipwhois[server]}"
      done
    ZSH
    stdout, stderr, status = Open3.capture3("/bin/zsh", "-f", "-c", probe,
      "demo-runtime", IPWHOIS_LIBRARY, reporter_functions("db_ipwhois"),
      JSON.generate(fixture("ipwhois", "demo")), JSON.generate(fixture("ipwhois", "demo-rate-limited")))
    assert status.success?, stderr
    assert_empty stderr
    assert_equal "1|ok|false|true|true\n1|rate_limited|||\n", stdout
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

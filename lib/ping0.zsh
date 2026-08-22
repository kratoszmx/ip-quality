# Pure parser for Ping0's documented public /geo response. Network access stays
# in ip-quality.zsh so this library is fixture-testable and reusable.

typeset -ga ping0_parsed=()

ping0_parse_geo(){
emulate -LR zsh
setopt KSH_ARRAYS
typeset response="$1"
typeset expected_ip="$2"
typeset normalized="${response//$'\r'/}"
typeset -a lines
typeset value

ping0_parsed=()
[[ "$normalized" == *$'\n' ]]&&normalized="${normalized%$'\n'}"
lines=("${(@f)normalized}")
(( ${#lines[@]} == 4 ))||return 1
for value in "${lines[@]}";do
[[ -n "$value" && ${#value} -le 512 && "$value" != *[[:cntrl:]]* ]]||return 1
done
[[ "${lines[0]}" == "$expected_ip" ]]||return 2
[[ "${lines[2]}" =~ '^AS[0-9]+$' ]]||return 1

ping0_parsed=("${lines[0]}" "${lines[1]}" "${lines[2]}" "${lines[3]}")
return 0
}

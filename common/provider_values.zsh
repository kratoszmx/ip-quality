# Network-free helpers shared by provider adapters in this repository.

provider_json_is_object(){
emulate -LR zsh
print -rn -- "$1"|jq -e 'type == "object"' >/dev/null 2>&1
}

provider_integer_in_range(){
emulate -LR zsh
(( $# == 3 ))||return 1
[[ "$1" == <-> && "$2" == <-> && "$3" == <-> ]]||return 1
(( $1 >= $2 && $1 <= $3 ))
}

provider_merge_boolean_signals(){
emulate -LR zsh
typeset signal
typeset saw_unknown=0
(( $# ))||return 0
for signal in "$@";do
case "$signal" in
true)print -rn -- "true"
return 0
;;
false) ;;
*)saw_unknown=1
esac
done
(( saw_unknown ))||print -rn -- "false"
}

provider_has_observation(){
emulate -LR zsh
typeset observation
for observation in "$@";do
case "${observation:l}" in
""|"null"|"unknown") ;;
*)return 0
esac
done
return 1
}

provider_http_failure_status(){
emulate -LR zsh
typeset http_code="$1"
typeset response_body="$2"
if [[ "$http_code" == "403" && "$response_body" == *"Sorry, you have been blocked"* && "$response_body" == *"Cloudflare"* ]];then
print -rn -- "cloudflare_blocked"
elif [[ "$http_code" == [0-9][0-9][0-9] && "$http_code" != "000" ]];then
print -rn -- "http_$http_code"
else
print -rn -- "network_error"
fi
}

provider_connection_type_server_flag(){
emulate -LR zsh
case "${1:l}" in
"data center")print -rn -- "true"
;;
residential|corporate|education|mobile)print -rn -- "false"
;;
esac
}

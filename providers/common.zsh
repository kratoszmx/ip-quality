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

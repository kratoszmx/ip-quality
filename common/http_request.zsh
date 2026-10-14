# Keep credential-bearing curl options on stdin, out of process arguments.
# Callers own endpoint/key validation, route selection and request budgets.
curl_with_secret_url(){
emulate -LR zsh
typeset secret_url="$1"
shift
print -r -- "url = \"$secret_url\""|curl -q "$@" --config -
}

curl_with_secret_header(){
emulate -LR zsh
typeset header_name="$1"
typeset header_value="$2"
typeset endpoint="$3"
shift 3
{
print -r -- "header = \"$header_name: $header_value\""
print -r -- "url = \"$endpoint\""
}|curl -q "$@" --config -
}

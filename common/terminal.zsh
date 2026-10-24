# Network-free terminal and report-file rendering helpers. Text work uses
# parameter expansion only, so no label starts a subprocess.

# REPLY = TEXT with literal "\033" spellings (seen in provider fixtures) decoded
# and ANSI sequences ending in m, G, K, H or F removed.
ansi_plain(){
emulate -LR zsh
setopt EXTENDED_GLOB
REPLY=${1-}
REPLY=${REPLY//\\033/$'\033'}
REPLY=${REPLY//$'\033'\[[0-9;]#[mGKHF]/}
}

clean_ansi(){
emulate -LR zsh
setopt EXTENDED_GLOB
ansi_plain "${1-}"
typeset input=$REPLY line
typeset -a lines
if [[ "${2-}" != "preserve" ]]; then
for line in "${(@f)input}";do lines+=("${${line##[[:space:]]#}%%[[:space:]]#}");done
input=${(F)lines}
input=${input%%$'\n'#}
fi
print -rn -- "$input"
}

# Progress lines go to stderr so stdout stays the report.
show_progress(){
print -ru2 -- "[ip-quality] $1"
}

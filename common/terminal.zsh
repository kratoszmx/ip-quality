# Network-free terminal and report-file rendering helpers. Text work uses
# parameter expansion only, so no label or table cell starts a subprocess.

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

# REPLY = display cells of one label after ANSI cleanup (ASCII 1, others 2).
display_width(){
emulate -LR zsh
ansi_plain "${1-}"
typeset non_ascii="${REPLY//[[:ascii:]]/}"
REPLY=$(( ${#REPLY} + ${#non_ascii} ))
}

# Cells are supplied in row order; each column grows independently.
terminal_table_widths(){
emulate -LR zsh
[[ "$1" == <-> && "$2" == <-> ]]||return 2
typeset -i minimum=$1 columns=$2 column=1
shift 2
(( columns > 0 && $# % columns == 0 ))||return 2
typeset -a widths
repeat "$columns";do widths+=("$minimum");done
typeset value
for value in "$@";do
display_width "$value"
(( REPLY > widths[column] ))&&widths[column]=$REPLY
(( column = column % columns + 1 ))
done
print -rn -- "${widths[*]}"
}

terminal_table_cell(){
emulate -LR zsh
typeset value="$1"
display_width "$value"
typeset -i padding=$(( $2 - REPLY ))
(( padding < 0 ))&&padding=0
print -rn -- "$value"
printf '%*s' "$padding" ''
}

terminal_table_row(){
emulate -LR zsh
typeset -a widths=( ${=1} )
shift
(( $# > 0 && $# == ${#widths} ))||return 2
typeset width value
for width in "${widths[@]}";do [[ "$width" == <-> ]]||return 2;done
typeset -i column=1
for value in "$@";do
(( column > 1 ))&&print -rn -- " | "
terminal_table_cell "$value" "${widths[column]}"
(( column++ ))
done
print
}

terminal_table_rule(){
emulate -LR zsh
typeset -a widths=( ${=1} )
(( ${#widths} > 0 ))||return 2
typeset width rule="" separator=""
for width in "${widths[@]}";do [[ "$width" == <-> ]]||return 2;done
for width in "${widths[@]}";do
rule+="$separator"
repeat "$width";do rule+="-";done
separator="-+-"
done
print -r -- "$rule"
}

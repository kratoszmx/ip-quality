# Report table layout: display widths, aligned cells, rows and rules, centering.
# Only report/ draws tables; ANSI cleanup comes from common/terminal.zsh.
(( ${+functions[ansi_plain]} ))||source "${${(%):-%x}:A:h:h}/common/terminal.zsh"

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

# PADDING = spaces that center TEXT within WIDTH display cells.
calc_padding(){
local input_text="$1"
local total_width=$2
display_width "$input_text"
local title_length=$REPLY
local left_padding=$(((total_width-title_length)/2))
if [[ $left_padding -gt 0 ]];then
PADDING=$(printf '%*s' $left_padding)
else
PADDING=""
fi
}

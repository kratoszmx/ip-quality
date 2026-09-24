# Network-free terminal and report-file rendering helpers.

clean_ansi(){
emulate -LR zsh
typeset input="${1-}"
typeset preserve="${2-}"
# Provider fixtures sometimes contain the printable escape spelling literally.
# A sentinel keeps command substitution from discarding layout newlines.
input=$(print -rn -- "$input" | sed $'s/\\\\033/\033/g; s/\033\\[[0-9;]*[mGKHF]//g'; print -rn -- .)
input="${input%.}"
if [[ "$preserve" != "preserve" ]]; then
input=$(print -r -- "$input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
fi
print -rn -- "$input"
}

display_width(){
emulate -LR zsh
typeset plain non_ascii
plain=$(clean_ansi "${1-}" preserve)
non_ascii="${plain//[[:ascii:]]/}"
print -rn -- $(( ${#plain} + ${#non_ascii} ))
}

# Cells are supplied in row order; each column grows independently.
terminal_table_widths(){
emulate -LR zsh
[[ "$1" == <-> && "$2" == <-> ]]||return 2
typeset -i minimum=$1 columns=$2 column=1 width
shift 2
(( columns > 0 && $# % columns == 0 ))||return 2
typeset -a widths
repeat "$columns";do widths+=("$minimum");done
typeset value
for value in "$@";do
width=$(display_width "$value")
(( width > widths[column] ))&&widths[column]=$width
(( column = column % columns + 1 ))
done
print -rn -- "${widths[*]}"
}

terminal_table_cell(){
emulate -LR zsh
typeset value="$1"
typeset -i padding=$(( $2 - $(display_width "$value") ))
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

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

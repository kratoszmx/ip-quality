# Strict, network-free loading for optional provider API credentials.
#
# The credentials file is data, never shell code. Only the names below are
# accepted, values are restricted to provider-key characters, and the file must
# be owned by the current user with no group/other permission bits.

typeset -gA provider_credentials=()
typeset -g provider_credentials_status="absent"
typeset -g provider_credentials_file=""

provider_default_credentials_file(){
emulate -LR zsh
typeset config_root
if [[ -n "${XDG_CONFIG_HOME:-}" ]];then
config_root="$XDG_CONFIG_HOME"
elif [[ -n "${HOME:-}" ]];then
config_root="$HOME/.config"
else
return 1
fi
print -rn -- "${config_root:A}/ipquality/credentials"
}

provider_api_key_is_valid(){
emulate -LR zsh
setopt EXTENDED_GLOB
typeset value="$1"
(( ${#value} >= 8 && ${#value} <= 256 ))||return 1
[[ "$value" == [A-Za-z0-9_.-]## ]]
}

provider_load_credentials(){
emulate -LR zsh
setopt EXTENDED_GLOB
typeset path="${1:-$(provider_default_credentials_file)}"
typeset line name value
typeset -A file_stat seen

provider_credentials=()
provider_credentials_status="absent"
provider_credentials_file="$path"
[[ ! -e "$path" && ! -L "$path" ]]&&return 0
[[ -f "$path" && -r "$path" && ! -L "$path" ]]||{
print -ru2 -- "ERROR: optional provider credentials must be a readable regular file, not a link: $path"
return 65
}
zmodload zsh/stat 2>/dev/null||{
print -ru2 -- "ERROR: zsh/stat is unavailable; cannot validate provider credentials safely."
return 69
}
zstat -H file_stat -- "$path" 2>/dev/null||{
print -ru2 -- "ERROR: cannot inspect optional provider credentials safely: $path"
return 65
}
(( file_stat[uid] == EUID && (file_stat[mode] & 077) == 0 ))||{
print -ru2 -- "ERROR: optional provider credentials must be owned by the current user and mode 600 or stricter: $path"
return 65
}

while IFS= read -r line || [[ -n "$line" ]];do
[[ -z "${line//[[:space:]]/}" || "$line" == [[:space:]]#\#* ]]&&continue
[[ "$line" == [A-Z0-9_]##=* ]]||{
print -ru2 -- "ERROR: invalid provider credentials file format: $path"
return 65
}
name="${line%%=*}"
value="${line#*=}"
case "$name" in
IPREGISTRY_API_KEY|DBIP_API_KEY|IPQS_API_KEY) ;;
*)
print -ru2 -- "ERROR: unsupported provider credential name in $path"
return 65
;;
esac
[[ -z "${seen[$name]:-}" ]]||{
print -ru2 -- "ERROR: duplicate provider credential name in $path"
return 65
}
provider_api_key_is_valid "$value"||{
print -ru2 -- "ERROR: invalid provider credential value in $path"
return 65
}
seen[$name]=1
provider_credentials[$name]="$value"
done < "$path"

provider_credentials_status="loaded"
return 0
}

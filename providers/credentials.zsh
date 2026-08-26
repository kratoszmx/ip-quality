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

provider_validate_private_file(){
emulate -LR zsh
typeset credential_path="$1"
typeset -A credential_stat
[[ -f "$credential_path" && -r "$credential_path" && ! -L "$credential_path" ]]||{
print -ru2 -- "ERROR: optional provider credentials must be a readable regular file, not a link: $credential_path"
return 65
}
zmodload zsh/stat 2>/dev/null||{
print -ru2 -- "ERROR: zsh/stat is unavailable; cannot validate provider credentials safely."
return 69
}
zstat -H credential_stat -- "$credential_path" 2>/dev/null||{
print -ru2 -- "ERROR: cannot inspect optional provider credentials safely: $credential_path"
return 65
}
(( credential_stat[uid] == EUID && (credential_stat[mode] & 077) == 0 ))||{
print -ru2 -- "ERROR: optional provider credentials must be owned by the current user and mode 600 or stricter: $credential_path"
return 65
}
return 0
}

provider_load_assignment_credentials(){
emulate -LR zsh
setopt EXTENDED_GLOB
typeset credential_path="$1"
typeset credential_line credential_name credential_value
typeset -A seen

provider_validate_private_file "$credential_path"||return $?

while IFS= read -r credential_line || [[ -n "$credential_line" ]];do
[[ -z "${credential_line//[[:space:]]/}" || "$credential_line" == [[:space:]]#\#* ]]&&continue
[[ "$credential_line" == [A-Z0-9_]##=* ]]||{
print -ru2 -- "ERROR: invalid provider credentials file format: $credential_path"
return 65
}
credential_name="${credential_line%%=*}"
credential_value="${credential_line#*=}"
case "$credential_name" in
IPREGISTRY_API_KEY|IPQS_API_KEY) ;;
*)
print -ru2 -- "ERROR: unsupported provider credential name in $credential_path"
return 65
;;
esac
[[ -z "${seen[$credential_name]:-}" ]]||{
print -ru2 -- "ERROR: duplicate provider credential name in $credential_path"
return 65
}
provider_api_key_is_valid "$credential_value"||{
print -ru2 -- "ERROR: invalid provider credential value in $credential_path"
return 65
}
seen[$credential_name]=1
provider_credentials[$credential_name]="$credential_value"
done < "$credential_path"
return 0
}

provider_load_named_secret(){
emulate -LR zsh
typeset credential_name="$1"
typeset credential_path="$2"
typeset credential_value

[[ ! -e "$credential_path" && ! -L "$credential_path" ]]&&return 0
provider_validate_private_file "$credential_path"||return $?
credential_value=$(<"$credential_path")
provider_api_key_is_valid "$credential_value"||{
print -ru2 -- "ERROR: invalid raw provider credential value in $credential_path"
return 65
}
provider_credentials[$credential_name]="$credential_value"
return 0
}

provider_load_credentials(){
emulate -LR zsh
typeset credential_path="${1:-$(provider_default_credentials_file)}"
typeset project_secrets_dir="${2:-}"
typeset loaded_any=0

provider_credentials=()
provider_credentials_status="absent"
provider_credentials_file="$credential_path"

if [[ -e "$credential_path" || -L "$credential_path" ]];then
provider_load_assignment_credentials "$credential_path"||return $?
loaded_any=1
fi

if [[ -n "$project_secrets_dir" && ( -e "$project_secrets_dir" || -L "$project_secrets_dir" ) ]];then
[[ -d "$project_secrets_dir" && ! -L "$project_secrets_dir" ]]||{
print -ru2 -- "ERROR: project provider secrets must be a directory, not a link: $project_secrets_dir"
return 65
}
if [[ -e "$project_secrets_dir/ipregistry" || -L "$project_secrets_dir/ipregistry" ]];then
provider_load_named_secret IPREGISTRY_API_KEY "$project_secrets_dir/ipregistry"||return $?
loaded_any=1
fi
if [[ -e "$project_secrets_dir/ipqs" || -L "$project_secrets_dir/ipqs" ]];then
provider_load_named_secret IPQS_API_KEY "$project_secrets_dir/ipqs"||return $?
loaded_any=1
fi
fi

(( loaded_any == 1 ))&&provider_credentials_status="loaded"
return 0
}

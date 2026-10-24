# Display formatting for provider coordinates, shared by the MaxMind relay and
# IPinfo basic data. Inputs are validated with the provider_values predicates.

generate_dms(){
local lat=$1
local lon=$2
if ! is_signed_decimal "$lat"||! is_signed_decimal "$lon";then
echo ""
return
fi
print -r -- "$(format_dms_coordinate "$lon" E W), $(format_dms_coordinate "$lat" N S)"
}

format_dms_coordinate(){
emulate -LR zsh
local value=$1 direction=$2 fraction=""
[[ $value == -* ]]&&{ direction=$3; value=${value#-}; }
[[ $value == *.* ]]&&fraction=${value#*.}
fraction=${(r:12::0:)fraction}
local -i seconds=$(( (10#$fraction * 3600 + 500000000000) / 1000000000000 ))
local -i degrees=$(( 10#${value%%.*} + seconds / 3600 ))
seconds=$(( seconds % 3600 ))
print -rn -- "$degrees°$(( seconds / 60 ))′$(( seconds % 60 ))″$direction"
}

# Check.Place map link; zoom follows the accuracy RADIUS in metres.
location_map_url(){
local lat=$1
local lon=$2
local radius=$3
if ! is_signed_decimal "$lat"||! is_signed_decimal "$lon"||! is_nonnegative_decimal "$radius";then
echo ""
return
fi
local zoom_level=15
if [[ $radius -gt 1000 ]];then
zoom_level=12
elif [[ $radius -gt 500 ]];then
zoom_level=13
elif [[ $radius -gt 250 ]];then
zoom_level=14
fi
echo "https://check.place/$lat,$lon,$zoom_level,$YY"
}

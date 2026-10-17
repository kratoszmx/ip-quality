# Mail scope: MX discovery and bounded SMTP banner probes on the system route.
# Derived from xykt/IPQuality. See UPSTREAM.md and LICENSE before modifying or
# redistributing this file.

get_sorted_mx_records(){
local domain=$1
dig +short MX $domain|sort -n|head -1|awk '{print $2}'
}
smtp_probe(){
local host="$1"
local port="$2"
local wait_seconds="$3"
printf 'QUIT\r\n'|nc -w "$wait_seconds" "$host" "$port" 2>&1
}
check_email_service(){
local service=$1
local port=25
local expected_response="220"
local domain=""
local host=""
local response=""
local success="false"
case $service in
"Gmail")domain="gmail.com";;
"Outlook")domain="outlook.com";;
"Yahoo")domain="yahoo.com";;
"Apple")domain="me.com";;
"MailRU")domain="mail.ru";;
"AOL")domain="aol.com";;
"GMX")domain="gmx.com";;
"MailCOM")domain="mail.com";;
"163")domain="163.com";;
"Sohu")domain="sohu.com";;
"Sina")domain="sina.com";;
"QQ")domain="qq.com";;
*)return
esac
if [[ -z $host ]];then
local mx_hosts=($(get_sorted_mx_records $domain))
for host in "${mx_hosts[@]}";do
response=$(smtp_probe "$host" "$port" 4)
smail_response[$service]=$response
if [[ $response == *"$expected_response"* ]];then
success="true"
smail[$service]="$Font_Black+$Font_Suffix$Back_Green$Font_White$Font_B$service$Font_Suffix"
smailstatus[$service]="true"
smail[remote]=1
break
fi
done
else
response=$(smtp_probe "$host" "$port" 4)
if [[ $response == *"$expected_response"* ]];then
success="true"
smail[$service]="$Font_Black+$Font_Suffix$Back_Green$Font_White$Font_B$service$Font_Suffix"
smailstatus[$service]="true"
smail[remote]=1
fi
fi
if [[ $success == "false" ]];then
smail[$service]="$Font_Black-$Font_Suffix$Back_Red$Font_White$Font_B$service$Font_Suffix"
smailstatus[$service]="false"
fi
}
check_mail(){
smail[local]=0
local response=$(smtp_probe "smtp.mailgun.org" 25 9)
[[ $response == *"220"* ]]&&smail[local]=1
smail[remote]=0
services=("Gmail" "Outlook" "Yahoo" "Apple" "QQ" "MailRU" "AOL" "GMX" "MailCOM" "163" "Sohu" "Sina")
for service in "${services[@]}";do
show_progress "${sinfo[mail]}$service"
check_email_service $service
done
}

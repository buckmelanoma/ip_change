#!/bin/sh
wemo_ip=10.0.0.60

wemo_control (){
        curl -0 -A '' \
	-X POST \
	-H 'Accept: ' \
	-H 'Content-type: text/xml; charset="utf-8"' \
	-H "SOAPACTION: \"urn:Belkin:service:basicevent:1#SetBinaryState\""  \
	--data '<?xml version="1.0" encoding="utf-8"?>
	        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" 
		 s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
	        <s:Body>
	        <u:SetBinaryState xmlns:u="urn:Belkin:service:basicevent:1">
	        <BinaryState>'$1'</BinaryState>
	        </u:SetBinaryState>
	        </s:Body>i
	        </s:Envelope>' \
	-s http://$wemo_ip:49153/upnp/control/basicevent1 > /dev/null
}

waiting_dots (){
     while true
      do
       echo -n .
       sleep 1
      done &
     sleep $1
     kill $!
     trap 'kill $!' SIGTERM
     echo
}

show_info (){
    echo -e "ip_change:  IP address:  $1"
    echo -e "ip_change:  Hostname:    $2"
    echo -e "ip_change:  MAC address: $3"
}

current_ip=$(. /lib/functions/network.sh; network_get_ipaddr ip wan; echo $ip)
current_hostname=$(uci get network.wan.hostname)
current_mac=$(ifconfig eth1.2 | grep -i HWaddr | cut -b 39-55)
echo "ip_change:  Current configuration:"
show_info $current_ip $current_hostname $current_mac

echo "ip_change:  Releasing DHCP lease on WAN"
killall -SIGUSR2 udhcpc > /dev/null

echo "ip_change:  Turning cable modem off"
wemo_control 0
echo "ip_change:  Waiting for capacitor discharge"
waiting_dots 15

echo "ip_change:  Generating new MAC address"
new_mac=8c:3b:ad:$(dd if=/dev/urandom bs=1024 count=1 2>/dev/null | md5sum | sed 's/^\(..\)\(..\)\(..\).*$/\1:\2:\3/')
echo "ip_change:  New MAC is:  $new_mac"
ifconfig eth1.2 hw ether $new_mac
echo "ip_change:  Updating UCI with new MAC"
uci set network.wan.macaddr=$new_mac
uci commit network

new_hostname=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-15};echo;)
echo "ip_change:  Updating UCI with random DHCP hostname"
uci set network.wan.hostname=$new_hostname
uci commit network

echo "ip_change:  Turning cable modem on and waiting for sync"
wemo_control 1
waiting_dots 85

echo "ip_change:  Renewing DHCP lease on WAN"
killall -SIGUSR1 udhcpc > /dev/null
waiting_dots 5

new_ip=$(. /lib/functions/network.sh; network_get_ipaddr ip wan; echo $ip)
new_mac=$(ifconfig eth1.2 | grep -i HWaddr | cut -b 39-55)
echo "ip_change:  New configuration:"
show_info $new_ip $new_hostname $new_mac

exit 0


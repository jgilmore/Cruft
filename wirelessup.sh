#sudo wlanconfig wlan0 create wlandev wifi0 wlanmode sta
sudo ifconfig wlan0 up
networks=`sudo iwlist wlan0 scan | grep ESSID`
sudo killall wpa_supplicant
echo $networks
if echo $networks | grep 'library_downstairs' ; then
	echo " found the library downstairs"
	sudo iwconfig wlan0 ESSID "library_downstairs"
#elif echo $networks | grep 'default' ; then
#	echo " found the yelling ladies"
#	sudo iwconfig wlan0 ESSID "default"
elif echo $networks | grep "Sky Ute Casino Resort" ; then
	echo "Sky Ute Casino Resort"
	sudo iwconfig wlan0 ESSID "Sky Ute Casino Resort"
elif echo $networks | grep 'library' ; then
	echo " found the library"
	sudo iwconfig wlan0 ESSID "library"
elif echo $networks | grep 'dlink' ; then
	echo " found the union hall"
	sudo iwconfig wlan0 ESSID "dlink"
elif echo $networks | grep SELF ; then
	echo "David's house"
	sudo iwconfig wlan0 ESSID "SELF"
	sudo wpa_supplicant -iwlan0 -c/etc/wpa_supplicant.conf -B
elif echo $networks | grep "VW Land" ; then
	echo "VW Land"
	sudo iwconfig wlan0 ESSID "VW Land"
	sudo wpa_supplicant -iwlan0 -c/etc/wpa_supplicant.conf -B
elif echo $networks | grep RVCSNet ; then
	echo "Andy's house"
	sudo iwconfig wlan0 ESSID "RVCSNet"
	sudo wpa_supplicant -iwlan0 -c/etc/wpa_supplicant.conf -B
elif echo $networks | grep "linksys_OW_25001" ; then
	echo alex\'s house
	sudo iwconfig wlan0 ESSID "linksys_OW_25001"
elif echo $networks | grep "linksys" ; then
	echo alex\'s house
	sudo iwconfig wlan0 ESSID "linksys"
else
	echo no known networks found?
	sudo iwconfig wlan0 ESSID any
fi
sudo ifconfig wlan0 up
sudo dhclient wlan0
#sudo iwconfig wlan0 ESSID "SELF" key 123A45B768
#sudo iwconfig wlan0 ESSID "SELF" key "123A45B768"
killall syndaemon
xrandr --output LVDS --mode 1024x768
xrandr --output LVDS --dpi 100
syndaemon -d

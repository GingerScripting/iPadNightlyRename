#!/bin/bash

#put url of jamf pro here
jssURL=

#put credentials here for a jamf user that can change iPadNames
jssUser=
jssPassword=

xpath() {
    # the xpath tool changes in Big Sur 
    if [[ $(sw_vers -buildVersion) > "20A" ]]; then
        /usr/bin/xpath -e "$@"
    else
        /usr/bin/xpath "$@"
    fi
}

deviceNumbers=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/advancedmobiledevicesearches/id/116 | xpath "//id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))

correctDeviceName(){
timeOut=$(curl -X POST -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/mobiledevicecommands/command/DeviceName/"$desiredName"/id/$device | grep -c "Timeout")
}

for device in "${deviceNumbers[@]}"; do
	deviceName=$(curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/mobiledevices/id/$device/subset/general | /usr/bin/awk -F '<display_name>|</display_name>' '{print $2}')
	realName=$(curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/mobiledevices/id/$device/subset/location | /usr/bin/awk -F '<real_name>|</real_name>' '{print $2}')
	desiredName=${realName// /.}
	if [ "$deviceName" != "$desiredName" ]; then
		echo "$(date) Mismatch found. $deviceName should be $desiredName"  >> /usr/local/rename/rename.log
		correctDeviceName
		while [ "$timeOut" -gt 0 ]; do
			echo "$(date) The request timed out. Trying again..." >> /usr/local/rename/rename.log
			sleep 5
			correctDeviceName
		done
		echo "$(date) Name changed to $desiredName" >> /usr/local/rename/rename.log
	fi
done
echo "$(date) Complete. All name changes have been processed." >> /usr/local/rename/rename.log

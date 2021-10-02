#!/bin/bash
#
# Name:    DigiNode for Pi 4 - Auto Installer
# Purpose: Install a DigiByte Node and DigiAsset Metadata server on a Pi 4 8Gb.
#          Automatic configuration at first boot.
# Author:  Matthew Cornellise @mctrivia
#          Olly Stedall @saltedlolly
#
# -------------------------------------------------------


## Set variables for colors and formatting

txtred=$(tput setaf 1) # Red
txtgrn=$(tput setaf 2) # Green
txtylw=$(tput setaf 3) # Yellow
txtblu=$(tput setaf 4) # Blue
txtpur=$(tput setaf 5) # Purple
txtcyn=$(tput setaf 6) # Cyan
txtwht=$(tput setaf 7) # White
txtrst=$(tput sgr0) # Text reset.

# tput setab [1-7] : Set a background colour using ANSI escape
# tput setb [1-7] : Set a background colour
# tput setaf [1-7] : Set a foreground colour using ANSI escape
# tput setf [1-7] : Set a foreground colour

txtbld=$(tput bold) # Set bold mode
# tput dim : turn on half-bright mode
# tput smul : begin underline mode
# tput rmul : exit underline mode
# tput rev : Turn on reverse mode
# tput smso : Enter standout mode (bold on rxvt)
# tput rmso : Exit standout mode

## Show description at launch
clear -x 
echo " ╔════════════════════════════════════════════════════════╗"
echo " ║                                                        ║"
echo " ║         ${txtbld}D I G I N O D E   I N S T A L L E R${txtrst}            ║ "
echo " ║                                                        ║"
echo " ║ Auto configure your DigiByte & DigiAsset Node for Pi 4 ║"
echo " ║                                                        ║"
echo " ╚════════════════════════════════════════════════════════╝" 
echo ""

# CHECK SYSTEM ARCHITECTURE

sysarch=$(uname -i)

echo "[{txtblu}i{txtrst}] System Architecture: $sysarch"

# CHECK FOR SUPPORTED HARDWARE

# Store device model in variable

model=$(tr -d '\0' < /proc/device-tree/model)

# Store device revision in variable

revision=$(cat /proc/cpuinfo | grep Revision | cut -d' ' -f2)

# Store total system RAM in whole Gb. Append Gb to number.

sysmem="$(free --giga | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)Gb"

# Store total system RAM in whole Mb.

sysmemmb=$(free --mega | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)

######### RASPBERRY PI DETECTION ###################################

# Attempt to detect model of Raspberry Pi being used (if any)

# Look for any mention of [Raspberry Pi] so we at least know it is a Pi 

pigen=$(tr -d '\0' < /proc/device-tree/model | cut -d ' ' -f1-2)

if [ "$pigen" = "Raspberry Pi" ]; then
  pitype="piunknown"
fi

# Look for any mention of [Raspberry Pi 5] so we can narrow it to Pi 5
# It doesn't exist yet but it may do at some point

pigen=$(tr -d '\0' < /proc/device-tree/model | cut -d ' ' -f1-3)

if [ "$pigen" = "Raspberry Pi 5" ]; then
  pitype="pi5"
fi

# Look for any mention of [Raspberry Pi 4] so we can narrow it to a Pi 4 
# even if it is a model we have not seen before

if [ "$pigen" = "Raspberry Pi 4" ]; then
  pitype="pi4"
fi

# Lookup the known models of Rasberry Pi hardware 

if [ $revision = 'd03114' ]; then #Pi 4 8Gb
     pitype="pi4"
     supported_pi="ok"
fi
if [ $revision = 'c03130' ]; then #Pi 400 4Gb
     pitype="pi4"
     supported_pi="4gb_swap"
fi
if [ $revision = 'c03112' ]; then #Pi 4 4Gb
     pitype="pi4"
     supported_pi="4gb_swap"
fi
if [ $revision = 'c03111' ]; then #Pi 4 4Gb
     pitype="pi4"
     supported_pi="4gb_swap"
fi
if [ $revision = 'b03112' ]; then #Pi 4 2Gb
     pitype="pi4"
fi
if [ $revision = 'b03111' ]; then #Pi 4 2Gb
     pitype="pi4"
fi
if [ $revision = 'a03111' ]; then #Pi 4 1Gb
     pitype="pi4"
fi
if [ $revision = 'a020d3' ]; then #Pi 3 Model B+ 1Gb
     pitype="pi3"
fi
if [ $revision = 'a22082' ]; then #Pi 3 Model B 1Gb
     pitype="pi3"
fi
if [ $revision = 'a02082' ]; then #Pi 3 Model B 1Gb
     pitype="pi3"
fi
if [ $revision = '9000C1' ]; then #Pi Zero W 512Mb
     pitype="piold"
fi
if [ $revision = '900093' ]; then #Pi Zero v1.3 512Mb
     pitype="piold"
fi
if [ $revision = '900092' ]; then #Pi Zero v1.2 512Mb
     pitype="piold"
fi
if [ $revision = 'a22042' ]; then #Pi 2 Model B v1.2 1Gb
     pitype="piold"
fi
if [ $revision = 'a21041' ]; then #Pi 2 Model B v1.1 1Gb
     pitype="piold"
fi
if [ $revision = 'a01041' ]; then #Pi 2 Model B v1.1 1Gb
     pitype="piold"
fi
if [ $revision = '0015' ]; then #Pi Model A+ 512Mb / 256Mb
     pitype="piold"
fi
if [ $revision = '0012' ]; then #Pi Model A+ 256Mb
     pitype="piold"
fi
if [ $revision = '0014' ]; then #Pi Computer Module 512Mb
     pitype="piold"
fi
if [ $revision = '0011' ]; then #Pi Compute Module 512Mb
     pitype="piold"
fi
if [ $revision = '900032' ]; then #Pi Module B+ 512Mb
     pitype="piold"
fi
if [ $revision = '0013' ]; then #Pi Module B+ 512Mb
     pitype="piold"
fi
if [ $revision = '0010' ]; then #Pi Module B+ 512Mb
     pitype="piold"
fi
if [ $revision = '000d' ]; then #Pi Module B Rev 2 512Mb
     pitype="piold"
fi
if [ $revision = '000e' ]; then #Pi Module B Rev 2 512Mb
     pitype="piold"
fi
if [ $revision = '000f' ]; then #Pi Module B Rev 2 512Mb
     pitype="piold"
fi
if [ $revision = '0007' ]; then #Pi Module A 256Mb
     pitype="piold"
fi
if [ $revision = '0008' ]; then #Pi Module A 256Mb
     pitype="piold"
fi
if [ $revision = '0009' ]; then #Pi Module A 256Mb
     pitype="piold"
fi
if [ $revision = '0004' ]; then #Pi Module B Rev 2 256Mb
     pitype="piold"
fi
if [ $revision = '0005' ]; then #Pi Module B Rev 2 256Mb
     pitype="piold"
fi
if [ $revision = '0006' ]; then #Pi Module B Rev 2 256Mb
     pitype="piold"
fi
if [ $revision = '0003' ]; then #Pi Module B Rev 1 256Mb
     pitype="piold"
fi
if [ $revision = '0002' ]; then #Pi Module B Rev 1 256Mb
     pitype="piold"
fi


# Generate Pi hardware read out

if [ "$pitype" = "pi5" ]; then
  echo "[${txtgrn}✓${txtrst}] Check for Raspberry Pi hardware"
  echo "    Detected: $model $sysmem"

elif [ "$pitype" = "pi4" ]; then
  echo "[${txtgrn}✓${txtrst}] Check for Raspberry Pi hardware"
  echo "    Detected: $model $sysmem"

elif [ "$pitype" = "pi3" ]; then
  echo "[${txtgrn}✓ ${txtrst}] Check for Raspberry Pi hardware"
  echo "    Detected: $model $sysmem"
  echo "    DigiByte Core requires a Pi 3 or later with at"
  echo "    least 1Gb of RAM. A Pi4 with 4Gb+ is recommended."
  
elif [ "$pitype" = "piold" ]; then
  echo "[${txtred}x${txtrst}] Check for Raspberry Pi hardware"
  echo "    Error: $model $sysmem is incompatible."
  echo ""
  echo "    This Raspberry Pi is too old to run DigiByte Core."
  echo "    DigiByte Core requires a Pi 3 or later with at"
  echo "    at least 1Gb of RAM. A Pi4 with 4Gb+ is recommended."
  echo ""
  exit

elif [ "$pitype" = "piunknown" ]; then
  echo "[${txtred}x${txtrst}] Check for Raspberry Pi hardware"
  echo "    Error: This Raspberry Pi model is unrecognised.  "
  echo ""
  echo "    Your Raspberry Pi model cannot be recognised by"
  echo "    this script. Please contact @saltedlolly on Twitter"
  echo "    including the following information so it can be added:"
  echo ""
  echo "    Device:   $model"
  echo "    Revision: $revision"
  echo "    Memory:   $sysmem"
  echo ""

else
  if [ $hwarch = "aarch64" ]; then
    echo "[${txtred}x${txtrst}] Check for Raspberry Pi hardware"
    echo "    Error: No Raspberry Pi detected.  "
    echo ""
    echo "    If you are using a Raspberry Pi and it has not"
    echo "    been detected by this script, please contact"
    echo "    @saltedlolly on Twitter with the following"
    echo "    information so it can be added:"
    echo ""
    echo "    Device:   $pimodel"
    echo "    Revision: $revision"
    echo "    Memory:   $sysmem" 
    echo ""
    exit
  fi
fi

# Only continue if if is a Pi 4 with at least 8Gb of RAM

if [ supported_pi="ok" ]; then
elif [ supported_pi="4gb_swap" ]; then
	# Create swap file for Pi 4 4Gb
	# Later add some stuff here for installing a swap file for 4gb Pi 4s. For now though just exit.
	# echo "[i] Creating 4Gb swap file as this model only has 4Gb RAM."
	# sudo fallocate -l 4G /swapfile
    exit
else
     echo "Unable to continue. This device is not a Raspberry Pi 4 4GB/8Gb"
	exit
fi

######################################
echo "exit script here while testing."
exit
######################################

echo "[{txtblu}i{txtrst}] Generating random RPC password."
rpcpass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)


echo ""
echo "[{txtblu}i{txtrst}] Install DigiByte Core wallet."
echo ""

#lookup latest release version on Github (need jq installed for this query)
dgb_ver_github=$(curl -sL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//')

#download and unzip latest release
wget https://github.com/DigiByte-Core/digibyte/releases/download/v"$dgb_ver_github"/digibyte-"$dgb_ver_github"-aarch64-linux-gnu.tar.gz
tar -xf digibyte-"$dgb_ver_github"-aarch64-linux-gnu.tar.gz
ln -s digibyte-"$dgb_ver_github" digibyte
rm digibyte-"$dgb_ver_github"-aarch64-linux-gnu.tar.gz

#create config file
mkdir ~/.digibyte
cat <<EOF > ~/.digibyte.conf
daemon=1
maxconnections=300
disablewallet=0
rpcuser=user
rpcpassword=$rpcpass
rpcbind=127.0.0.1
rpcport=14022
whitelist=127.0.0.1
rpcallowip=127.0.0.1
EOF

#set to start on boot
line="@reboot /home/$(whoami)/digibyte/bin/digibyted"
(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -


# Setup service file - need to figure out how to run sudo at boot

# echo ""
# echo "[{txtblu}i{txtrst}] Setup digibyted.service"
# echo ""

# cat <<EOF > /etc/systemd/system/digibyted.service
# Description=DigiByte's distributed currency daemon
# After=network.target

# [Service]
# User=digibyte
# Group=digibyte

# Type=forking
# PIDFile=/home/digibyte/.digibyte/digibyted.pid
# ExecStart=/home/digibyte/digibyte/bin/digibyted -daemon -pid=/home/digibyte/.digibyte/digibyted.pid \
# -conf=/home/digibyte/.digibyte/digibyte.conf -datadir=/home/digibyte/.digibyte -disablewallet

# Restart=always
# PrivateTmp=true
# TimeoutStopSec=60s
# TimeoutStartSec=2s
# StartLimitInterval=120s
# StartLimitBurst=5

# [Install]
# WantedBy=multi-user.target
# EOF


echo ""
echo "[{txtblu}i{txtrst}] Install IPFS daemon"
echo ""

#download and unzip

# It would be good if it automatically got the latest version - maybe it is possible to parse this: https://dist.ipfs.io/index.xml

wget https://ipfs.io/ipns/dist.ipfs.io/go-ipfs/v0.9.1/go-ipfs_v0.9.1_linux-arm64.tar.gz
tar -xvzf go-ipfs_v0.6.0_linux-arm.tar.gz
rm go-ipfs_v0.6.0_linux-arm.tar.gz

#install
cd go-ipfs
bash install.sh
ipfs init

#set to start on boot
line="@reboot /usr/local/bin/ipfs daemon"
(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -



echo ""
echo "[{txtblu}i{txtrst}] Install PM2"
echo ""
npm install -g pm2
pm2 startup



echo ""
echo "\x1b[34mInstall DigiAsset Node\x1b[0m"
echo ""

#clone repo
git clone --branch apiV3 https://github.com/digiassetX/digiasset_ipfs_metadata_server.git
cd digiasset_ipfs_metadata_server

#create config file
mkdir _config
cat <<EOF > _config/main.json
{
    "ignoreList": [
        "QmQ2C5V7WN2nQLAQz73URXauENhgTwkZwYXQE56Ymg55dV","QmQ2C5V7WN2nQLAQz73URXauENhgTwkZwYXQE56Ymg55dV","QmT7mPQPpQfA154bioJACMfYD3XBdAJ2BuBFWHkPrpVaAe","QmVUqYFvA9UEGT7vxrNWsKrRpof6YajfLcXJuSHBbLDXgK","QmWCH8fzy71C9CHc5LhuECJDM7dyW6N5QC13auS9KMNYax","QmYMiHk7zBiQ681o567MYH6AqkXGCB7RU8Rf5M4bhP4RjA","QmZxpYP6T4oQjNVJMjnVzbkFrKVGwPkGpJ4MZmuBL5qZso","QmbKUYdu1D8zwJJfBnvxf3LAJav8Sp4SNYFoz3xRM1j4hV","Qmc2ywGVoAZcpkYpETf2CVHxhmTokETMx3AiuywADbBEHY","QmdRmLoFVnEWx44NiK3VeWaz59sqV7mBQzEb8QGVuu7JXp","QmdtLCqzYNJdhJ545PxE247o6AxDmrx3YT9L5XXyddPR1M"
    ],
    "quiet":          true,
    "includeMedia":   {
        "maxSize":    1000000,
        "names":      ["icon"],
        "mimeTypes":  ["image/png","image/jpg","image/gif"],
        "paid":       "always"
    },
    "timeout":        6000000,
    "errorDelay":     600000,
    "port":           8090,
    "scanDelay":      600000,
    "sessionLife":    86400000,
    "users":          false,
    "publish":        false,
    "wallet":         {
      "user":         "user",
      "pass":         "$rpcpass",
      "host":         "127.0.0.1",
      "port":         14022
    }
}
EOF

#set pm2 to run server continuously
pm2 start index.js --name digiasset --log
pm2 save --force

# create hidden file used by DigiMon to denote that this is an "official" DigiNode install (i.e. DigiMon can assume that it knows all the file locations)
touch $HOME/digibyte/.officialdiginode


echo ""
echo "\x1b[5m\x1b[32mPlease reboot your device now to finish the install\x1b[0m"
echo ""






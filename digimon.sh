#!/bin/bash
#
# Name:    DigiNode Status Monitor
# Purpose: Monitor the status of your DigiByte Node and DigiAsset Metadata server.
#          Includes stats for the Raspberry Pi when used.
#
# Author:  Olly Stedall @saltedlolly <digibyte.help> 
# 
# Usage:   Use the official DigiNode Installer to install this script on your system. 
#
#          Alternatively clone the repo to your home folder:
#
#          cd ~
#          git clone https://github.com/saltedlolly/diginode/
#          chmod +x ~/diginode/digimon.sh
#
#          To run:
#
#          ~/diginode/digimon.sh
#
#
# Updated: October 8 2021 4:09pm GMT
#
# -------------------------------------------------------


######################################################
######### VARIABLES ##################################
######################################################

# For better maintainability, we store as much information that can change in variables
# This allows us to make a change in one place that can propagate to all instances of the variable
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions

# Set this to YES to get more verbose feedback. Very useful for debugging.
VERBOSE_MODE="YES"

# This is the command people will enter to run the install script
DGN_INSTALLER_OFFICIAL_CMD="curl http://diginode-installer.digibyte.help | bash"

#################################################
#### UPDATE THESE VALUES FROM THE INSTALLER #####
#################################################

# Set these values so the installer can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_LIGHT_RED='\e[1;31m'
COL_LIGHT_CYAN='\e[1;96m'
COL_BOLD_WHITE='\e[1;37m'
TICK="  [${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="  [${COL_LIGHT_RED}✗${COL_NC}]"
WARN="  [${COL_LIGHT_RED}!${COL_NC}]"
INFO="  [${COL_BOLD_WHITE}i${COL_NC}]"
INDENT="     "
# shellcheck disable=SC2034
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="\\r\\033[K"


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




######################################################
######### FUNCTIONS ##################################
######################################################

# Find where this script is running from, so we can make sure the diginode-installer.sh script is with it
get_script_location() {
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  DGN_SCRIPT_FOLDER="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  DGN_INSTALL_SCRIPT=$DGN_SCRIPT_FOLDER/diginode-installer.sh
  if [ "$VERBOSE_MODE" = "YES" ]; then
    printf "%b Monitor Script Location: $DGN_SCRIPT_FOLDER     [ VERBOSE MODE ]\\n" "${INFO}"
    printf "%b Install Script Location (presumed): $DGN_INSTALL_SCRIPT     [ VERBOSE MODE ]\\n" "${INFO}"
  fi
}

# PULL IN THE CONTENTS OF THE INSTALLER SCRIPT BECAUSE IT HAS FUNCTIONS WE WANT TO USE
import_installer_functions() {
    # BEFORE INPORTING THE INSTALLER FUNCTIONS, SET VARIABLE SO IT DOESN'T ACTUAL RUN THE INSTALLER
    RUN_INSTALLER="NO"
    # If the installer file exists,
    if [[ -f "$DGN_INSTALL_SCRIPT" ]]; then
        # source it
        if [ $VERBOSE_MODE = "YES" ]; then
          printf "%b Importing functions from diginode-installer.sh     [ VERBOSE MODE ]\\n" "${TICK}"
          printf "\\n"
        fi
        source "$DGN_INSTALL_SCRIPT"
    # Otherwise,
    else
        printf "\\n"
        printf "%b %bERROR: diginode-installer.sh file not found.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b The diginode-installer.sh file is required to continue.\\n" "${INDENT}"
        printf "%b It contains functions we need to run the DigiNode Status Monitor.\\n" "${INDENT}"
        printf "\\n"
        printf "%b If you have not already setup your DigiNode, please use\\n" "${INDENT}"
        printf "%b the official DigiNode installer:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   $DGN_INSTALLER_OFFICIAL_CMD\\n" "${INDENT}"
        printf "\\n"
        printf "%b Alternatively, to use 'DigiNode Status Monitor' with your existing\\n" "${INDENT}"
        printf "%b DigiByte node, clone the official repo to your home folder:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   cd ~ \\n" "${INDENT}"
        printf "%b   git clone https://github.com/saltedlolly/diginode/ \\n" "${INDENT}"
        printf "%b   chmod +x ~/diginode/digimon.sh \\n" "${INDENT}"
        printf "\\n"
        printf "%b To run it:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ~/diginode/digimon.sh\\n" "${INDENT}"
        printf "\\n"
        exit -1
    fi
}

# A simple function that clears the sreen and displays the status monitor title in a box
digimon_title_box() {
    clear -x
    echo ""
    echo " ╔════════════════════════════════════════════════════════╗"
    echo " ║                                                        ║"
    echo " ║      ${txtbld}D I G I N O D E   S T A T U S   M O N I T O R${txtrst}     ║ "
    echo " ║                                                        ║"
    echo " ║         Monitor your DigiByte & DigiAsset Node         ║"
    echo " ║                                                        ║"
    echo " ╚════════════════════════════════════════════════════════╝" 
    echo ""
}

# Show a disclaimer text during testing phase
digimon_disclaimer() {
    printf "%b %bWARNING: This script is still under active development%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b Expect bugs and for it to break things - at times it may\\n" "${INDENT}"
    printf "%b not even run. Please use for testing only until further notice.\\n" "${INDENT}"
    printf "\\n"
    read -n 1 -s -r -p "   < Press Ctrl-C to quit, or any other key to Continue. >"
}


# Check for swap file if using a device with low memory, and make sure it is large enough
swap_warning() {

    local swap_too_small
    local swap_rec_size
    local swap_current_size

    if [ "$SWAPTOTAL_HR" = "0B" ]; then
      swap_current_size="${COL_LIGHT_RED}none${COL_NC}"
    else
      swap_current_size="${COL_LIGHT_GREEN}${SWAPTOTAL_HR}b${COL_NC}"
    fi

    printf "%b System Memory:     Total RAM: %b${RAMTOTAL_HR}b%b     Total SWAP: $swap_current_size\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"

    # Check the existing swap file is large enough based on how much RAM the device has
    #
    # Note: these checks on the current swap size use the lower Kibibyte value
    # so that if the recomended swap size is 4Gb, and they enter 4 Gigabytes or 4 Gibibytes
    # the size check will come out the same for either
    if [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "6835938" ];  then
        swap_too_small="YES"
        swap_rec_size="7Gb"
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "5859375" ];  then
        swap_too_small="YES"
        swap_rec_size="6Gb"
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "4882813" ];  then
        swap_too_small="YES"
        swap_rec_size="5Gb"
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "3906250" ];  then
        swap_too_small="YES"
        swap_rec_size="4Gb"
    elif [ "$RAMTOTAL_KB" -le "5000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "2929688" ];  then
        swap_too_small="YES"
        swap_rec_size="3Gb"
    elif [ "$RAMTOTAL_KB" -le "6000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "976562" ];  then
        swap_too_small="YES"
        swap_rec_size="2Gb"

    # If there is no swap file present, calculate recomended swap file size
    elif [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        swap_not_detected="YES"
        swap_rec_size="7Gb"
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        swap_not_detected="YES"
        swap_rec_size="6Gb"
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        swap_not_detected="YES"
        swap_rec_size="5Gb"
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        swap_not_detected="YES"
        swap_rec_size="4Gb"
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        swap_not_detected="YES"
        swap_rec_size="5Gb"
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        swap_not_detected="YES"
        swap_rec_size="6Gb"
    elif [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        swap_not_detected="YES"
        swap_rec_size="7Gb"
    fi

    if [ "$swap_not_detected" = "YES" ]; then
        printf "\\n"
        printf "%b %bWARNING: No Swap file detected%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Running a DigiNode requires approximately 5Gb RAM. Since your device only\\n" "${INDENT}"
        printf "%b has ${RAMTOTAL_HR}b RAM, it is recommended to create a swap file of at least $swap_rec_size or more.\\n" "${INDENT}"
        printf "%b This will give your system at least 8Gb of total memory to work with.\\n" "${INDENT}"
        printf "%b The official DigiNode installer can configure your swap file for you.\\n" "${INDENT}"
        printf "\\n"
    fi

    if [ "$swap_too_small" = "YES" ]; then
        printf "\\n"
        printf "%b %bWARNING: Your swap file is too small%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Running a DigiNode requires approximately 5Gb RAM. Since your device only\\n" "${INDENT}"
        printf "%b has ${RAMTOTAL_HR}b RAM, it is recommended to increase your swap size to at least $swap_rec_size or more.\\n" "${INDENT}"
        printf "%b This will give your system at least 8Gb of total memory to work with.\\n" "${INDENT}"
        printf "%b The official DigiNode installer can configure your swap file for you.\\n" "${INDENT}"
        printf "\\n"
    fi
}

is_dgbnode_installed() {

    # Check for digibyte core install folder in home folder (either 'digibyte' folder itself, or a symbolic link pointing to it)

    if [ -h "$HOME/digibyte" ]; then
      echo "$TICK digibyte symbolic link found in home folder."
    else
      if [ -e "$HOME/digibyte" ]; then
        echo "$TICK digibyte folder found in home folder."
      else
        echo "$CROSS digibyte symbolic link NOT found in home folder."
        echo ""
        echo "[!] Unable to continue - please create a symbolic link in"
        echo "    your home folder pointing to the location of digibyte core."
        echo "    For example:"  
        echo "    $ cd ~"
        echo "    $ ln -s digibyte-7.17.3 digibyte" 
        echo ""
        exit
      fi
    fi

    # Check if digibyted is installed

    if [ -f "$HOME/digibyte/bin/digibyted" -a -f "$HOME/digibyte/bin/digibyte-cli" ]; then
      echo "$TICK DigiByte Core is installed - digibyted and digibyte-cli located" 
    else
      echo "$CROSS DigiByte Core is NOT installed - binaries not found "
      echo ""
      echo "[!] Unable to continue - please install DigiByte Core."
      echo ""
      echo "    The digibyted and digibyte-cli binaries must be located at:"
      echo "    ~/digibyte/bin/"
      echo ""
      exit
    fi

    # Check if digibyte core is configured to run as a service

    if [ -f "/etc/systemd/system/digibyted.service" ]; then
      echo "$TICK DigiByte daemon service is installed  - digibyted.service file located"
    else
      echo "$CROSS DigiByte daemon service is not installed  - digibyted.service file NOT found"
      echo ""
      echo "[!] DigiByte daemon needs to be configured to run as a service."
      echo "    If you already have a service file to run digibyted please"
      echo "    rename it to /etc/systemd/system/digibyted.service so that this"
      echo "    script can find it."
      echo ""
      echo "    If you have not already created a service file to run digibyted"
      echo "    this script can attempt to create one for you in systemd."
      echo ""
      read -p "    Would you like to install it now? " -n 1 -r
      echo    # (optional) move to a new line
      if [[ ! $REPLY =~ ^[Yy]$ ]]
      then
        exit 1
        echo "***install service file script here****"
      else
        exit
      fi
    fi

    # Check if digibyted service is running. Exit if it isn't.

    if [ $(systemctl is-active digibyted) = 'active' ]; then
      echo "$TICK DigiByte daemon service is running."
      digibyted_status="running"
    else
      echo "$CROSS Digibyte daemon service is NOT running."
      digibyted_status="stopped"
      echo ""
      echo "[!] Unable to continue - please start the DigiByte daemon service:"
      echo "    sudo systemctl start digibyted"
      echo ""
      exit
    fi

    # Check for .digibyte settings directory

    if [ -d "$HOME/.digibyte" ]; then
      echo "$TICK .digibyte settings folder located."
    else
      echo ""
      echo "$CROSS Unable to locate the .digibyte settings folder."
      echo "    The file should be at: $HOME/.digibyte/"
      echo ""
      exit
    fi

    # Check digibyte.conf file can be found

    if [ -f "$DGB_CONF_FILE" ]; then
      echo "$TICK digibyte.conf file located."
    else
      echo ""
      echo "$CROSS Unable to find digibyte.conf configuration file."
      echo "    The file should be at: $DGB_CONF_FILE"
      echo ""
      exit
    fi

    # Load digibyte.conf file to get variables
      echo "$INFO Importing digibyte.conf settings"
      source "$DGB_CONF_FILE"

}

# Get RPC CREDENTIALS from digibyte.conf
get_rpc_credentials() {
    if [ -f "$DGB_CONF_FILE" ]; then
      RPCUSER=$(cat $DGB_CONF_FILE | grep rpcuser | cut -d'=' -f 2)
      RPCPASSWORD=$(cat $DGB_CONF_FILE | grep rpcpassword | cut -d'=' -f 2)
      RPCPORT=$(cat $DGB_CONF_FILE | grep rpcport | cut -d'=' -f 2)
      if [ "$RPCUSER" != "" ] && [ "$RPCPASSWORD" != "" ] && [ "$RPCPORT" != "" ]; then
        RPC_CREDENTIALS_OK="YES"
        printf "%b RPC credentials found in digibyte.conf\\n" "${TICK}"
        printf "%b   Found: ${TICK} Username     ${TICK} Password     ${TICK} Port\\n" "${TICK}"
      else
        RPC_CREDENTIALS_OK="NO"
        printf "%b %bERROR: RPC credentials missing in digibyte.confb\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "${INDENT}   Found: "
        if [ $RPCUSER != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Username     "
        if [ $RPCPASSWORD != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Password     "
        if [ $RPCPORT != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Port"
        printf "\\n"
        printf "%b You need to add the missing RPC credentials to your digibyte.conf file.\\n" "${INFO}"
        printf "%b Without them your DigiAsset Node is unable to communicate with your DigiByte Node.\\n" "${INDENT}"
        printf "\\n"
        printf "Edit the digibyte.conf file:\\n" "${INDENT}"
        printf "\\n"
        printf "  nano $DGB_CONF_FILE\\n" "${INDENT}"
        printf "\\n"
        printf "Add the following:\\n" "${INDENT}"
        printf "\\n"
        printf "  rpcuser=desiredusername      # change desiredusername to something else\\n" "${INDENT}"
        printf "  rpcpassword=desiredpassword  # change desiredpassword to something else\\n" "${INDENT}"
        printf "  rpcport=14022                # best to leave this as is" "${INDENT}"
        printf "\\n"
        exit 1
      fi
    fi
}

# function to update the _config/main.json file with updated RPC credentials (if they have been changed)
update_dga_config() {
  # Only update if there are RPC get_rpc_credentials
  if [[ $RPC_CREDENTIALS_OK == "YES" ]]; then
    # need to write this one
  fi
}


# Check if this DigiNode was setup using the official install script
# (Looks for a hidden file in the 'digibyte' install directory - .officialdiginode)
check_official() {

    if [ -f "$HOME/digibyte/.officialdiginode" ] && [ -f "$HOME/digiasset_ipfs_metadata_server/.officialdiginode" ]; then
        printf "%b Official DigiNode detected\\n" "${TICK}"
        officialdgbinstall="yes"
    else
        printf "\\n"
        printf "%b %bWARNING: Official DigiNode not detected%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b It appears that this DigiNode was not setup using the DigiNode installer.\\n" "${INDENT}"
        printf "%b This script will attempt to detect your setup but may require you to make\\n" "${INDENT}"
        printf "%b manual changes to make it work. It is possible things may break.\\n" "${INDENT}"
        printf "%b For best results use the official DigiNode installer.\\n" "${INDENT}"
        printf "\\n"
    fi
}

# Check if the DigAssets Node is installed and running
is_dganode_installed() {

      #####################################################
      # Perform initial checks for required DAMS pacakges #
      #####################################################

      # Check if snapd is installed

      REQUIRED_PKG="snapd"
      PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
      if [ "" = "$PKG_OK" ]; then
          snapd_installed="no"
          startwait=yes
      else
          snapd_installed="yes"
          dga_status="snapdinstalled"
      fi

      # Check if snap core is installed

      PKG_OK=$(snap list | grep "core")
      if [ "" = "$PKG_OK" ]; then
          snapcore_installed="no"
          startwait=yes
      else
          snapcore_installed="no"
          if [ $dga_status = "snapdinstalled" ]; then
            dga_status="snapcoreinstalled"
          fi
      fi

      # Check if ipfs is installed

      PKG_OK=$(snap list | grep "ipfs")
      if [ "" = "$PKG_OK" ]; then
          ipfs_installed="no"
          startwait=yes
      else
          if [ $dga_status = "snapcoreinstalled" ]; then
            dga_status="ipfsinstalled"
          fi
          ipfs_installed="yes"
      fi

      # Check if nodejs is installed

      REQUIRED_PKG="nodejs"
      PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
      if [ "" = "$PKG_OK" ]; then
          nodejs_installed="no"
          startwait=yes
      else
          if [ $dga_status = "ipfsinstalled" ]; then
            dga_status="nodejsinstalled"
          fi
           nodejs_installed="yes"
      fi

      # Display if DAMS packages are installed


      if [ "$nodejs_installed" = "yes" ]; then 
        echo "[${txtgrn}✓${txtrst}] Required \'DigiAsset Metadata Server\' packages are installed."
        echo "    Found: [${txtgrn}✓${txtrst}] snapd   [${txtgrn}✓${txtrst}] snap core   [${txtgrn}✓${txtrst}] ipfs   [${txtgrn}✓${txtrst}] nodejs" 
      else
        echo "[${txtred}x${txtrst}] Required \'DigiAsset Metadata Server\' pacakages are NOT installed:"
        printf "    Found: ["
        if [ $snapd_installed = "yes" ]; then
          printf "${txtgrn}✓${txtrst}"
        else
          printf "${txtred}x${txtrst}"
        fi
        printf "] snapd   ["
        if [ $snapcore_installed = "yes" ]; then
          printf "${txtgrn}✓${txtrst}"
        else
          printf "${txtred}x${txtrst}"
        fi
        printf "] snap core   ["
        if [ $ipfs_installed = "yes" ]; then
          printf "${txtgrn}✓${txtrst}"
        else
          printf "${txtred}x${txtrst}"
        fi
        printf "] ipfs   ["
        if [ $nodejs_installed = "yes" ]; then
          printf "${txtgrn}✓${txtrst}"
        else
          printf "${txtred}x${txtrst}"
        fi
          printf "] nodejs"
          echo ""
          echo "     Some packages required to run the DigiAsset Metadata Server are not"
          echo "     currently installed."
          echo ""
          echo "     You can install them using the DigiNode Installer."
          echo ""
          startwait="yes"
        fi

      # Check if ipfs service is running. Required for DigiAssets server.

      # ps aux | grep ipfs

      if [ "" = "$(ps aux | grep ipfs)" ]; then
          echo "[${txtred}x${txtrst}] IPFS daemon is NOT running."
          echo ""
          echo "The IPFS daemon is required to run the DigiAsset Metadata Server."
          echo ""
          echo "You can set it up using the DigiNode Installer."
          echo ""
          ipfs_running="no"
      else
          echo "[${txtgrn}✓${txtrst}] IPFS daemon is running."
          if [ $dga_status = "nodejsinstalled" ]; then
            dga_status="ipfsrunning"
          fi
          ipfs_running="yes"
      fi


      # Check for 'digiasset_ipfs_metadata_server' index.js file

      if [ -f "$HOME/digiasset_ipfs_metadata_server/index.js" ]; then
        if [ $dga_status = "nodejsinstalled" ]; then
           dga_status="installed" 
        fi
        echo "[${txtgrn}✓${txtrst}] DigiAsset Metadata Server is installed - index.js located."
      else
          echo "[${txtred}x${txtrst}] DigiAsset Metadata Server NOT found."
          echo ""
          echo "   DigiAssets Metadata Server is not currently installed. You can install"
          echo "   it using the DigiNode Installer."
          echo ""
          startwait="yes"
      fi

      # Check if 'digiasset_ipfs_metadata_server' is running

      if [ $dga_status = "installed" ]; then
        if [! $(pgrep -f index.js) -eq "" ]; then
            dga_status="running"
            echo "[${txtgrn}✓${txtrst}] DigiAsset Metadata Server is running."
        else
            dga_status="stopped"
            echo "[${txtred}x${txtrst}] DigiAsset Metadata Server is NOT running.."
            echo ""
            startwait=yes
        fi
      fi

}

# Load the diginode.settings file if it exists. Create it if it doesn't. 
load_diginode_settings() {
    # Get saved variables from diginode.settings. Create settings file if it does not exist.
    if test -f $HOME/.digibyte/diginode.settings; then
      # import saved variables from settings file
      echo "[i] Importing diginode.settings file..."
      source $HOME/.digibyte/diginode.settings
    else
      # create diginode.settings file
      create_diginode_settings
    fi
}

## Check if avahi-daemon is installed
is_bonjour_installed() {
    REQUIRED_PKG="avahi-daemon"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
      echo "[i] avahi-daemon is not currently installed."
      echo "    It is optional, but recommended if you are using a dedicated"
      echo "    device to run your DigiNode such as a Raspberry Pi. It means"
      echo "    you can you can access it at the address $(hostname).local"
      echo "    instead of having to remember the IP address. Install it"
      echo "    with the command: sudo apt-get install avahi-daemon"
      echo ""
    else
      bonjour="installed"
      echo "$TICK avahi-daemon is installed."
      echo "    Local URL: $(hostname).local"
    fi
}

##  Check if jq package is installed
is_jq_installed() {
    REQUIRED_PKG="jq"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
      echo "$CROSS jq package is required and will be installed. "
      echo "    Required to retrieve data from the DigiAsset Metadata server."
      echo ""
      install_jq='yes'
    else
      echo "$TICK jq is installed."
    fi
}


# Check if digibyte core wallet is enabled
is_wallet_enabled() {
if [ $dga_status = "running" ]; then
    if [ -f "$HOME/.digibyte/digibyte.conf" ]; then
      walletstatus=$(cat ~/.digibyte/digibyte.conf | grep disablewallet | cut -d'=' -f 2)
      if [ walletstatus = "1" ]; then
        walletstatus="disabled"
        echo "[${txtgrn}✓${txtrst}] DigiByte Core wallet is enabled."
      else
        walletstatus="enabled"
        echo ""
        echo "[${txtred}x${txtrst}] DigiByte Core wallet is disabled."
        echo "   The DigiByte Core wallet is required if you want to create DigiAssets"
        echo "   from within the web UI. You can enable it by editing the digibyte.conf"
        echo "   file and removing the disablewallet=1 flag"
        echo ""
        startwait="yes"
      fi
    fi
  fi
}

# Install needed packages
install_required_pkgs() {
    if [ "$install_jq" = "yes" ]; then
      echo ""
      echo "[i]  Enter your password to install required packages. Press Ctrl-C to cancel."
      echo ""
      sudo apt-get --yes install jq
    fi
}


## PERFROM STARTUP CHECKS
startup() {
  
  digimon_title_box          # Clear screen and display title box
  digimon_disclaimer         # Display disclaimer warning during development. Pause for confirmation.
  get_script_location        # Find which folder this script is running in
  import_installer_functions # Import diginode-instaler.sh because it contains functions we need
  diginode_logo              # Clear screen and display title box (again)
  sys_check                  # Perform basic OS check - is this Linux? Is it 64bit?
  rpi_check                  # Look for Raspberry Pi hardware. If found, only continue if it compatible.
  swap_warning               # if this system has 4Gb or less RAM, check there is a swap drive
  check_official             # check if this is an official install
  is_dgbnode_installed       # Run checks to see if DigiByte Node is present. Exit if it isn't. Import digibyte.conf.
  get_rpc_credentials        # Get the RPC username and password from config file. Warn if not present.
  is_wallet_enabled          # Check that the DigiByte Core wallet is enabled
  is_dganode_installed       # Run checks to see if DigiAsset Node is present. Warn if it isn't.
  load_diginode_settings     # Load the diginode.settings file. Create it if it does not exist.
  is_bonjour_installed       # Check if avahi-daemon is installed
  is_jq_installed            # Check if jq is installed
  install_required_pkgs      # Install jq
}




######################################################
######### RUN SCRIPT FROM HERE #######################
######################################################

startup

exit

##############################
## OLDER NON FUNCTION CODE ###
###############################



























###################################################################################
##################  INSTALL MISSING PACKAGES ######################################
###################################################################################



# Optionally require a key press to continue, or a long 5 second pause. Otherwise wait 3 seconds before starting monitoring. 

echo ""
if [ "$STARTPAUSE" = "yes" ]; then
  read -n 1 -s -r -p "      < Press any key to continue >"
else

  if [ "$startwait" = "yes" ]; then
    echo "               < Wait for 5 seconds >"
    sleep 5
  else 
    echo "               < Wait for 3 seconds >"
    sleep 3
  fi
fi

## Show description at launch
clear -x
echo " ╔════════════════════════════════════════════════════════╗"
echo " ║                                                        ║"
echo " ║      ${txtbld}D I G I N O D E   S T A T U S   M O N I T O R${txtrst}     ║ "
echo " ║                                                        ║"
echo " ║         Monitor your DigiByte & DigiAsset Node         ║"
echo " ║                                                        ║"
echo " ╚════════════════════════════════════════════════════════╝" 
echo ""
echo "Performing start up checks:"
echo ""


###################################################################################
##################  SET STARTUP VARIABLES    ######################################
###################################################################################

# Setup loopcounter - used for debugging
loopcounter=0

# Set timenow variable with the current time
timenow=$(date)

load_diginode_settings() {
# Get saved variables from diginode.settings. Create settings file if it does not exist.
if test -f $HOME/.digibyte/diginode.settings; then
  # import saved variables from settings file
  echo "[i] Importing diginode.settings file..."
  source $HOME/.digibyte/diginode.settings
else
  # create diginode.settings file
  create_diginode_settings
fi
}

# Get base64 authentication for RPC
rpcauth=$(printf '%s:%s' "$rpcuser" "$rpcpassword" | base64)

# If this is the first time running the status monitor, set the variables that update periodically
if [ $statusmonitor_last_run="" ]; then

    echo "[i] First time running DigiMon - performing initial setup."
    echo "    Storing external and internal IP in settings file..."

    # update external IP address and save to settings file
    externalip=$(dig @resolver4.opendns.com myip.opendns.com +short)
    sed -i -e "/^externalip=/s|.*|externalip=\"$externalip\"|" $HOME/.digibyte/diginode.settings

    # update internal IP address and save to settings file
    internalip=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
    sed -i -e "/^internalip=/s|.*|internalip=\"$internalip\"|" $HOME/.digibyte/diginode.settings

    echo "    Storing timer variables in settings file..."

    # set 15 sec timer and save to settings file
    savedtime15sec="$(date)"
    sed -i -e "/^savedtime15sec=/s|.*|savedtime15sec=\"$(date)\"|" $HOME/.digibyte/diginode.settings

    # set 1 min timer and save to settings file
    savedtime1min="$(date)"
    sed -i -e "/^savedtime1min=/s|.*|savedtime1min=\"$(date)\"|" $HOME/.digibyte/diginode.settings

    # set 15 min timer and save to settings file
    savedtime15min="$(date)"
    sed -i -e "/^savedtime15min=/s|.*|savedtime15min=\"$(date)\"|" $HOME/.digibyte/diginode.settings

    # set daily timer and save to settings file
    savedtime1day="$(date)"
    sed -i -e "/^savedtime1day=/s|.*|savedtime1day=\"$(date)\"|" $HOME/.digibyte/diginode.settings

    # set weekly timer and save to settings file
    savedtime1week="$(date)"
    sed -i -e "/^savedtime1week=/s|.*|savedtime1week=\"$(date)\"|" $HOME/.digibyte/diginode.settings

    echo "    Storing DigiByte Core current version number in settings file..."  

    # check for current version number of DigiByte Core and save to settings file
    dgb_ver_local=$(~/digibyte/bin/digibyte-cli getnetworkinfo | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
    sed -i -e "/^dgb_ver_local=/s|.*|dgb_ver_local=\"$dgb_ver_local\"|" $HOME/.digibyte/diginode.settings 
    echo "    Detected: DigiByte Core v$dgb_ver_local" 


    # if digiassets server is installed, set variables
    if [ $dga_status = "running" ]; then
      echo "    Storing DigiAsset Metadata Server version number in settings file..."
      dga_ver_local=$(curl localhost:8090/api/version/list.json)
      sed -i -e '/^dga_ver_local=/s|.*|dga_ver_local="$(date)"|' $HOME/.digibyte/diginode.settings
      ipfs_ver_local=$(ipfs version | cut -d ' ' -f 3)
      sed -i -e '/^ipfs_ver_local=/s|.*|ipfs_ver_local="$ipfs_ver_local"|' $HOME/.digibyte/diginode.settings
    fi
fi


# Set DigiAsset Metadata Server version veriables (if it is has just been installed)
if [ $dga_status = "running" ] && [ $dams_first_run = ""  ]; then
    echo "[i] First time running DigiAsset Metadata Server - performing initial setup."
    echo "    Storing DigiAsset Metadata Server version number in settings file..."
    dga_ver_local=$(curl localhost:8090/api/version/list.json)
    sed -i -e '/^dga_ver_local=/s|.*|dga_ver_local="$(date)"|' $HOME/.digibyte/diginode.settings
    ipfs_ver_local=$(ipfs version | cut -d ' ' -f 3)
    sed -i -e '/^ipfs_ver_local=/s|.*|ipfs_ver_local="$(date)"|' $HOME/.digibyte/diginode.settings
    dams_first_run=$(date)
    sed -i -e '/^dams_first_run=/s|.*|dams_first_run="$(date)"|' $HOME/.digibyte/diginode.settings
fi



# Store system totals in variables
echo "[i] Looking up system RAM and disk space."
disktotal=$(df /dev/sda2 -h --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
ramtotal=$(free -m -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2 | sed 's/.$//')

# Get maxconnections from digibyte.conf
echo "[i] Looking up max connections."
if [ -f "$HOME/.digibyte/digibyte.conf" ]; then
  maxconnections=$(cat ~/.digibyte/digibyte.conf | grep maxconnections | cut -d'=' -f 2)
  if [ maxconnections = "" ]; then
    maxconnections="125"
  fi
fi

echo " ------- BEFORE ------"

# Get latest software versions and check for online updates
dgb_ver_local=$(~/digibyte/bin/digibyte-cli getnetworkinfo | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
dga_ver_local=$(curl localhost:8090/api/status.json)
ipfs_ver_local=$(ipfs version | cut -d ' ' -f 3)

echo " ------- AFTER ------"

dgb_ver_github=$(curl -sL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//')
dga_ver_github=$(curl -sL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//')


######################################################################################
############## THE LOOP STARTS HERE - ENTIRE LOOP RUNS ONCE A SECOND #################
######################################################################################

while :
do

# Optional loop counter - useful for debugging
# echo "Loop Count: $loopcounter"

# Exit status monitor if it is left running for more than 12 hours
if [ $loopcounter -gt 43200 ]; then
    echo ""
    echo "DigiNode Status Monitor quit automatically as it was left running for more than 12 hours."
    echo ""
    exit
fi

# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - HARDWARE
# ------------------------------------------------------------------------------

# Update timenow variable with current time
timenow=$(date)

temperature=$(</sys/class/thermal/thermal_zone0/temp)
diskpercent=$(df /dev/sda2 --output=pcent | tail -n +2)
diskavail=$(df /dev/sda2 -h --output=avail | tail -n +2)
diskused=$(df /dev/sda2 -h --output=used | tail -n +2)
ramused=$(free -m -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f3 | sed 's/.$//')
ramavail=$(free -m -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f6 | sed 's/.$//')
swapused=$(free -m -h | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f3)
loopcounter=$((loopcounter+1))

# Trim white space from disk variables
diskpercent=$(echo -e " \t $diskpercent \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
diskavail=$(echo -e " \t $diskavail \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
diskused=$(echo -e " \t $diskused \t " | sed 's/^[ \t]*//;s/[ \t]*$//')

# Convert temperature to Degrees C
tempc=$((temperature/1000))

# Convert temperature to Degrees F
tempf=$(((9/5) * $tempc + 32))


# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - DIGIBYTE CORE 
# ------------------------------------------------------------------------------

# Is digibyted running?
systemctl is-active --quiet digibyted && digibyted_status="running" || digibyted_status="stopped"

# Is digibyted in the process of starting up, and not ready to respond to requests?
if [ $digibyted_status = "running" ]; then
    blockcount_local=$(~/digibyte/bin/digibyte-cli getblockcount)

    if [ "$blockcount_local" != ^[0-9]+$ ]; then
      digibyted_status = "startingup"
    fi
fi


# THE REST OF THIS ONLY RUNS NOTE IF DIGIBYED IS RUNNING

if [ $digibyted_status = "running" ]; then

  # Lookup sync progress value from debug.log. Use previous saved value if no value is found.
  if [ $blocksync_progress != "synced" ]; then
    blocksync_value_saved=$(blocksync_value)
    blocksync_value=$(tail -n 1 ~/.digibyte/debug.log | cut -d' ' -f12 | cut -d'=' -f2 | sed -r 's/.{3}$//')
    if [ $blocksync_value -eq "" ]; then
       blocksync_value=$(blocksync_value_saved)
    fi
    echo "scale=2 ;$blocksync_percent*100"|bc
  fi

  # Get DigiByted Uptime
  uptime_seconds=$(./digibyte/bin/digibyte-cli uptime)
  uptime=$(eval "echo $(date -ud "@$uptime_seconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")
  dgb_ver=$(~/digibyte/bin/digibyte-cli getnetworkinfo | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)

  # Detect if the block chain is fully synced
  if [ $blocksync_percent -eq 100.00 ]; then
    blocksync_percent="100"
    blocksync_progress="synced"
  fi

  # Show port warning if connections are less than or equal to 7
  connections=$(./digibyte/bin/digibyte-cli getconnectioncount)
  if [ $connections -le 8 ]; then
    connectionsmsg="Low Connections Warning!"
  fi
  if [ $connections -ge 9 ]; then
    connectionsmsg="Maximum: $maxconnections"
  fi
fi 


# ------------------------------------------------------------------------------
#    Run once every 15 seconds (approx once every block).
#    Every 15 seconds lookup the latest block from the online block exlorer to calculate sync progress.
# ------------------------------------------------------------------------------

timedif15sec=$(printf "%s\n" $(( $(date -d "$timenow" "+%s") - $(date -d "$savedtime15sec" "+%s") )))

if [ $timedif15sec -gt 15 ]; then 

    # Check if digibyted is successfully responding to requests up yet after starting up
    if [ $digibyted_status = "startingup" ]; then
        if [[ "$blocklatest" = ^[0-9]+$ ]]
          digibyted_status = "running"
        fi
    fi
    if [ $digibyted_status = "running" ]; then
        blocklatest=$(~/digibyte/bin/digibyte-cli getblockchaininfo | grep headers | cut -d':' -f2 | sed 's/^.//;s/.$//')
    fi

    # Get current software version
    dgb_ver_local=$(~/digibyte/bin/digibyte-cli getnetworkinfo | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)

    # Compare current DigiByte Core version with Github version to know if there is a new version available
    if [ "$dgb_ver_github" -gt "$dgb_ver_local" ]; then
        update_available="yes"
        dgb_update_available="yes"
    else
        dgb_update_available="no"
    fi 

    savedtime15sec="$timenow"
fi


# ------------------------------------------------------------------------------
#    Run once every 1 minute
#    Every 15 seconds lookup the latest block from the online block exlorer to calculate sync progress.
# ------------------------------------------------------------------------------

timedif1min=$(printf "%s\n" $(( $(date -d "$timenow" "+%s") - $(date -d "$savedtime1min" "+%s") )))

  # Lookup sync progress value from debug.log. Use previous saved value if no value is found.
    blocksync_value_saved=$(blocksync_value)
    blocksync_value=$(tail -n 1 ~/.digibyte/debug.log | cut -d' ' -f12 | cut -d'=' -f2 | sed -r 's/.{3}$//')
    if [ $blocksync_value -eq "" ]; then
       blocksync_value=$(blocksync_value_saved)
    fi
    echo "scale=2 ;$blocksync_percent*100"|bc

    # If sync progress is 100.00%, make it 100%
    if [ $blocksync_percent -eq "100.00" ]; then
       blocksync_percent="100"
    fi

    # Check if sync progress is not 100%
    if [ $blocksync_percent -eq "100" ]; then
       blocksync_progress="synced"
    else
       blocksync_progress="notsynced"
    fi

    # Update local IP address if it has changed
    internalip=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
    sed -i -e '/^internalip=/s|.*|internalip="$internalip"|' $HOME/.digibyte/diginode.settings

    savedtime1min="$timenow"
fi


# ------------------------------------------------------------------------------
#    Run once every 15 minutes
#    Update the Internal & External IP
# ------------------------------------------------------------------------------

timedif15min=$(printf "%s\n" $(( $(date -d "$timenow" "+%s") - $(date -d "$savedtime15min" "+%s") )))

if [ $timedif15min -gt 300 ]; then

    # update external IP if it has changed
    externalip=$(dig @resolver4.opendns.com myip.opendns.com +short)
    sed -i -e '/^externalip=/s|.*|externalip="$externalip"|' $HOME/.digibyte/diginode.settings

    # If DigiAssets server is running, lookup local version number of DigiAssets server IP
    if [ $dga_status = "running" ]; then

      echo "need to add check for change of DGA version number" 

      dga_ver_local=$(curl localhost:8090/api/version/list.json)
      ipfs_ver_local=$(ipfs version | cut -d ' ' -f 3)
    fi


    savedtime15min="$timenow"
fi


# ------------------------------------------------------------------------------
#    Run once every 24 hours
#    Check for new version of DigiByte Core
# ------------------------------------------------------------------------------

timedif24hrs=$(printf "%s\n" $(( $(date -d "$timenow" "+%s") - $(date -d "$savedtime24hrs" "+%s") )))

if [ $timedif24hrs -gt 86400 ]; then

    # items to repeat every 24 hours go here

    # check for system updates
    IFS=';' read updates security_updates < <(/usr/lib/update-notifier/apt-check 2>&1)
        sed -i -e '/^savedtime15sec=/s|.*|savedtime15sec="$(date)"|; $HOME/.digibyte/diginode.settings


    # Check for new release of DigiByte Core on Github
    dgb_ver_github=$(curl -sL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//g')

    

    /usr/lib/update-notifier/apt-check --human-readable


    savedtime24hrs="$timenow"
fi




###################################################################
#### GENERATE NORMAL DISPLAY #############################################
###################################################################

# Double buffer output to reduce display flickering
# (output=$(clear -x;

echo '
        ____   _         _  _   __            __    
       / __ \ (_)____ _ (_)/ | / /____   ____/ /___    ╔═════════╗
      / / / // // __ `// //  |/ // __ \ / __  // _ \   ║ STATUS  ║
     / /_/ // // /_/ // // /|  // /_/ // /_/ //  __/   ║ MONITOR ║
    /_____//_/ \__, //_//_/ |_/ \____/ \__,_/ \___/    ╚═════════╝ 
              /____/                               
                       Monitor your DigiByte & DigiAssets Node 

 ╔═══════════════╦════════════════════════════════════════════════════╗'
if [ $digibyted_status = 'running' ]; then # Only display if digibyted is running
  printf " ║ CONNECTIONS   ║  " && printf "%-10s %35s %-4s\n" "$connections Nodes" "[ $connectionsmsg" "]  ║"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
  printf " ║ BLOCK HEIGHT  ║  " && printf "%-26s %19s %-4s\n" "$blocklocal Blocks" "[ Synced: $blocksyncpercent %" "]  ║"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
  printf " ║ NODE UPTIME   ║  " && printf "%-49s ║ \n" "$uptime"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
fi # end check to see of digibyted is running
if [ $digibyted_status = 'stopped' ]; then # Only display if digibyted is NOT running
  printf " ║ NODE STATUS   ║  " && printf "%-49s ║ \n" " [ DigiByte daemon service is stopepd. ]"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
fi
if [ $digibyted_status = 'startingup' ]; then # Only display if digibyted is NOT running
  printf " ║ NODE STATUS   ║  " && printf "%-49s ║ \n" " [ DigiByte daemon is starting... ]"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
fi
printf " ║ IP ADDRESSES  ║  " && printf "%-49s %-1s\n" "Internal: $internalip  External: $externalip" "║" 
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
if [ $bonjour = 'ok' ]; then # Use .local domain if available, otherwise use the IP address
printf " ║ WEB UI        ║  " && printf "%-49s %-1s\n" "http://$hostname.local:8090" "║"
else
printf " ║ WEB UI        ║  " && printf "%-49s %-1s\n" "http://$internalip:8090" "║"
fi
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ RPC ACCESS    ║  " && printf "%-49s %-1s\n" "User: $rpcusername  Pass: $rpcpassword  Port: $rpcport" "║" 
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ DIGINODE  ║  " && printf "%-26s %19s %-4s\n" "DigiByte Core v$dgb_ver_local" "[ Update Available: v$dgb_ver_github" "]  ║"
echo " ║   SOFTWARE      ╠═════════════════════════════════════════════════════╣"
printf " ║               ║  " && printf "%-49s ║ \n" "IPFS daemon v$ipfs_ver_local"
echo " ║               ╠═════════════════════════════════════════════════════╣"
printf " ║               ║  " && printf "%-49s ║ \n" "DigiAsset Metadata Server v$dga_ver_local"
echo " ╚═══════════════╩════════════════════════════════════════════════════╝"
if [ $digibyted_status = 'stopped' ]; then # Only display if digibyted is NOT running
echo "WARNING: Your DigiByte daemon service is not currently running."
echo "         To start it enter: sudo systemctl start digibyted"
fi
if [ $digibyted_status = 'startingup' ]; then # Only display if digibyted is NOT running
echo "IMPORTANT: Your DigiByte daemon service is currently in the process of starting up."
echo "           This can take up to 10 minutes. Please wait..."
fi
if [ $connections -le 10 ]; then # Only show port forwarding instructions if connection count is less or equal to 10 since it is clearly working with a higher count
echo ""
echo "  IMPORTANT: You need to forward port 12024 on your router so that"
echo "  your DigiByte node can be discovered by other nodes on the internet."
echo "  Otherwise the number of potential inbound connections is limited to 7."
echo ". For help on how to do this, visit [ https://portforward.com/ ]"
echo ""
echo "  You can verify that port 12024 is being forwarded correctly by"
echo "  visiting [ https://opennodes.digibyte.link ] and entering your"
echo "  external IP address in the form at the bottom of the page. If the"
echo "  port is open, it should find your node and display your DigiByte"
echo "  version number and approximate location."
echo ""
echo "  If you have already forwarded port 12024, monitor the connection"
echo "  count above - it should start increasing. If the number is above 8,"
echo "  this indicates that things are working correctly. This message will"
echo "  disappear when the total connections exceeds 10."
fi
if [ $update_available = "yes" ];then
echo "           Press U to install software updates now."
fi
echo ""
echo " ╔═══════════════╦════════════════════════════════════════════════════╗"
printf " ║ DEVICE      ║  " && printf "%-35s %10s %-4s\n" "$model" "[ $modelmem RAM" "]  ║"
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ DISK USAGE    ║  " && printf "%-34s %-19s\n" "$diskused of $disktotal ($diskpercent)" "[ $diskavail free ]  ║"
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ MEMORY USAGE  ║  " && printf "%-34s %-19s\n" "$ramused of $ramtotal" "[ $ramavail free ]  ║"
if [ $swaptotal != '0B' ]; then # only display the swap file status if there is one
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ SWAP USAGE    ║  " && printf "%-47s %-3s\n" "$swapused of $swaptotal"  "  ║"
fi 
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ SYSTEM TEMP   ║  " && printf "%-49s %-3s\n" "$tempc °C  /  $tempf °F" "  ║"
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ SYSTEM CLOCK  ║  " && printf "%-47s %-3s\n" "$timenow" "  ║"
echo " ╚═══════════════╩════════════════════════════════════════════════════╝"
echo ""
echo "              Press Ctrl-C to stop monitoring"
echo ""

# end output double buffer

# echo "$output"
sleep 1
done

#!/bin/bash
#
# Name:    DigiNode Status Monitor
# Purpose: Monitor the status of your DigiByte Node and DigiAsset Node.
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
#          chmod +x ~/diginode/diginode
#
#          To run:
#
#          ~/diginode/diginode
#
# -------------------------------------------------------

#####################################################
##### IMPORTANT INFORMATION #########################
#####################################################

# Please note that this script requires the diginode-installer.sh script to be with it
# in the same folder when it runs. Tne installer script contains functions and variables
# used by this one.
#
# Both the DigiNode Installer and Status Monitor scripts make use of a settings file
# located at: ~/.diginode/diginode.settings
#
# It want to make changes to folder locations etc. please edit this file.
# (e.g. To move your DigiByte data folder to an external drive.)
# 
# Note: The default location of the diginode.settings file can be changed at the top of
# the installer script, but this is not recommended.

######################################################
######### VARIABLES ##################################
######################################################

# For better maintainability, we store as much information that can change in variables
# This allows us to make a change in one place that can propagate to all instances of the variable
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions

# This variable stores the version number of this release of 'DigiNode Tools.
# When a new release is made, this number will be updated to match the release number on GitHub.
# The version number should be three numbers seperated by a period
# Do not change this version number on your local installaion or automatic upgrades may not work.
DGNT_VER_LOCAL=0.0.1

# This is the command people will enter to run the install script.
DGNT_INSTALLER_OFFICIAL_CMD="curl -sSL diginode-installer.digibyte.help | bash"

#######################################################
#### UPDATE THESE VALUES FROM THE INSTALLER FIRST #####
#######################################################

# These colour and text formatting variables are included in both scripts since they are required before installer-script.sh is sourced into this one.
# Changes to these variables should be first made in the installer script and then copied here, to help ensure the settings remain identical in both scripts.

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


######## Undocumented Flags. Shhh ########
# These are undocumented flags; 
VERBOSE_MODE=true       # Set this to true to get more verbose feedback. Very useful for debugging.
UNINSTALL=false
# Check arguments for the undocumented flags
# --dgndev (-d) will use and install the develop branch of DigiNode Tools (used during development)
for var in "$@"; do
    case "$var" in
        "--uninstall" ) UNINSTALL=true;;
        "--verboseon" ) VERBOSE_MODE=true;;
        "--verboseoff" ) VERBOSE_MODE=false;;
    esac
done




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
  DGNT_LOCATION_NOW="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  DGNT_INSTALLER_SCRIPT_NOW=$DGNT_LOCATION_NOW/diginode-installer.sh

  if [ "$VERBOSE_MODE" = true ]; then
    printf "%b Monitor Script Location: $DGNT_LOCATION_NOW\\n" "${INFO}"
    printf "%b Install Script Location (presumed): $DGNT_INSTALLER_SCRIPT_NOW\\n" "${INFO}"
  fi
}

# PULL IN THE CONTENTS OF THE INSTALLER SCRIPT BECAUSE IT HAS FUNCTIONS WE WANT TO USE
import_installer_functions() {
    # BEFORE INPORTING THE INSTALLER FUNCTIONS, SET VARIABLE SO IT DOESN'T ACTUAL RUN THE INSTALLER
    RUN_INSTALLER="NO"
    # If the installer file exists,
    if [[ -f "$DGNT_INSTALLER_SCRIPT_NOW" ]]; then
        # source it
        if [ $VERBOSE_MODE = true ]; then
          printf "%b Importing functions from diginode-installer.sh\\n" "${TICK}"
          printf "\\n"
        fi
        source "$DGNT_INSTALLER_SCRIPT_NOW"
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
        printf "%b   $DGNT_INSTALLER_OFFICIAL_CMD\\n" "${INDENT}"
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
        exit 1
    fi
}

# A simple function that clears the sreen and displays the status monitor title in a box
digimon_title_box() {
    clear -x
    tput civis
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
    printf "\\n\\n"
}


# Run checks to be sure that digibyte node is installed and running
is_dgbnode_installed() {

    # Set local variables for DigiByte Core checks
    local find_dgb_folder
    local find_dgb_binaries
    local find_dgb_data_folder
    local find_dgb_conf_file
    local find_dgb_service

    # Begin check to see that DigiByte Core is installed
    printf "%b Checking DigiByte Node...\\n" "${INFO}"

    # Check for digibyte core install folder in home folder (either 'digibyte' folder itself, or a symbolic link pointing to it)
    if [ -h "$DGB_INSTALL_LOCATION" ]; then
      find_dgb_folder="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "  %b digibyte symbolic link found in home folder.\\n" "${TICK}"
      fi
    else
      if [ -e "$DGB_INSTALL_LOCATION" ]; then
      find_dgb_folder="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "  %b digibyte folder found in home folder.\\n" "${TICK}"
      fi
      else
        printf "\\n"
        printf "  %b %bERROR: Unable to locate digibyte installation in home folder.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "  %b This script is unable to find your DigiByte Core installation folder\\n" "${INDENT}"
        printf "  %b If you have not yet installed DigiByte Core, please do so using the\\n" "${INDENT}"
        printf "  %b DigiNode Installer. Otherwise, please create a 'digibyte' symbolic link in\\n" "${INDENT}"
        printf "  %b your home folder, pointing to the location of your DigiByte Core installation:\\n" "${INDENT}"
        printf "\\n"
        printf "  %b For example:\\n" "${INDENT}"
        printf "\\n"
        printf "  %b   cd ~\\n" "${INDENT}"
        printf "  %b   ln -s digibyte-7.17.3 digibyte\\n" "${INDENT}"
        printf "\\n"
        exit 1
      fi
    fi

    # Check if digibyted is installed

    if [ -f "$DGB_DAEMON" -a -f "$DGB_CLI" ]; then
      find_dgb_binaries="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "  %b Digibyte Core Binaries located: ${TICK} digibyted ${TICK} digibyte-cli\\n" "${TICK}"
      fi
    else
        printf "\\n"
        printf "  %b %bERROR: Unable to locate DigiByte Core binaries.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "  %b This script is unable to find your DigiByte Core binaries - digibyte & digibye-cli.\\n" "${INDENT}"
        printf "  %b If you have not yet installed DigiByte Core, please do so using the\\n" "${INDENT}"
        printf "  %b DigiNode Installer. Otherwise, please create a 'digibyte' symbolic link in\\n" "${INDENT}"
        printf "  %b your home folder, pointing to the location of your DigiByte Core installation:\\n" "${INDENT}"
        printf "\\n"
        printf "  %b For example:\\n" "${INDENT}"
        printf "\\n"
        printf "  %b   cd ~\\n" "${INDENT}"
        printf "  %b   ln -s digibyte-7.17.3 digibyte\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # Check if digibyte core is configured to run as a service

    if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB_UPSTART_SERVICE_FILE" ]; then
      find_dgb_service="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "  %b DigiByte daemon service file is installed\\n" "${TICK}"
      fi
    else
        printf "  %b DigiByte daemon service file is NOT installed\\n" "${CROSS}"
        printf "\\n"
        printf "  %b %bWARNING: digibyted.service not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "  %b To ensure your DigiByte Node stays running 24/7, it is a good idea to setup\\n" "${INDENT}"
        printf "  %b DigiByte daemon to run as a service. If you already have a systemd service file\\n" "${INDENT}"
        printf "  %b to run 'digibyted', please, rename it to /etc/systemd/system/digibyted.service\\n" "${INDENT}"
        printf "  %b so that this script can find it.\\n" "${INDENT}"
        printf "\\n"
        printf "  %b If you wish to setup your DigiByte Node as a service, please use the DigiNode Installer.\\n" "${INDENT}"
        printf "\\n"
        local dgb_service_warning="yes"
    fi

    # Check for .digibyte data directory

    if [ -d "$DGB_SETTINGS_LOCATION" ]; then
      find_dgb_settings_folder="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "  %b .digibyte settings folder located\\n" "${TICK}"
      fi
    else
        printf "\\n"
        printf "  %b %bERROR: .digibyted data folder not found.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "  %b The DigiByte Core data folder contains your wallet and digibyte.conf\\n" "${INDENT}"
        printf "  %b in addition to the blockchain data itself. The folder was not found in\\n" "${INDENT}"
        printf "  %b the expected location here: $DGB_DATA_LOCATION\\n" "${INDENT}"
        printf "\\n"
        printf "\\n"
        exit 1
    fi

    # Check digibyte.conf file can be found

    if [ -f "$DGB_CONF_FILE" ]; then
      find_dgb_conf_file="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "  %b digibyte.conf file located\\n" "${TICK}"
           # Load digibyte.conf file to get variables
          printf "  %b Importing digibyte.conf\\n" "${TICK}"
          source "$DGB_CONF_FILE"
      fi
    else
        printf "\\n"
        printf "  %b %bERROR: digibyte.conf not found.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "  %b The digibyte.conf contains important configuration settings for\\n" "${INDENT}"
        printf "  %b your node. The DigiNode Installer can help you create one.\\n" "${INDENT}"
        printf "  %b The expected location is here: $DGB_CONF_FILE\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # Get maxconnections from digibyte.conf

    if [ -f "$DGB_CONF_FILE" ]; then
      maxconnections=$(cat $DGB_CONF_FILE | grep maxconnections | cut -d'=' -f 2)
      if [ "$maxconnections" = "" ]; then
        maxconnections="125"
      fi
      printf "  %b DigiByte Core max connections: $maxconnections\\n" "${INFO}"
    fi

    # Run checks to see DigiByte Core is running

    # Check if digibyte daemon is running as a service.
    if [ $(systemctl is-active digibyted) = 'active' ]; then
       if [ $VERBOSE_MODE = true ]; then
          printf "  %b DigiByte daemon is running as a service\\n" "${TICK}"
       fi
       DGB_STATUS="running"
    else
      # Check if digibyted is running (but not as a service).
      if [ "" = "$(pgrep digibyted)" ]; then
          if [ $VERBOSE_MODE = true ]; then
            printf "  %b DigiByte daemon is running\\n" "${TICK}"
            # Don't display service warning mesage if it has already been shown above
            if [ "$dgb_service_warning" = "YES" ]; then
              printf "\\n"
              printf "  %b %bWARNING: digibyted is not currently running as a service%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
              printf "  %b DigiNode Installer can help you to setup digibyted to run as a service.\\n" "${INDENT}"
              printf "  %b This ensures that your DigiByte Node starts automatically at boot and\\n" "${INDENT}"
              printf "  %b will restart automatically if it crashes for some reason. This is the preferred\\n" "${INDENT}"
              printf "  %b way to run a DigiByte Node and helps to ensure it is kept running 24/7.\\n" "${INDENT}"
              printf "\\n"
            fi
          fi
          DGB_STATUS="running"
      else
        # Finally, check if digibyte-qt
        if [ "" = "$(pgrep digibyte-qt)" ]; then
            if [ $VERBOSE_MODE = true ]; then
              printf "%b digibyte-qt is running\\n" "${TICK}"
            fi
            DGB_STATUS="running"
        # Exit if digibyted is not running
        else
          printf "\\n"
          printf "  %b %bERROR: DigiByte daemon is not running.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
          printf "  %b DigiNode Status Monitor cannot start as your DigiByte Node is not currently running.\\n" "${INDENT}"
          printf "  %b Please start digibyted and then relaunch the status monitor.\\n" "${INDENT}"
          printf "  %b DigiNode Installer can help you to setup DigiByte daemon to run as a service\\n" "${INDENT}"
          printf "  %b so that it launches automatically at boot.\\n" "${INDENT}"
          printf "\\n"
          exit 1
        fi
      fi
    fi

    # Display message if the DigiByte Node is running okay

    if [ "$find_dgb_folder" = "yes" ] && [ "$find_dgb_binaries" = "yes" ] && [ "$find_dgb_settings_folder" = "yes" ] && [ "$find_dgb_conf_file" = "yes" ] && [ "$DGB_STATUS" = "running" ]; then
        printf "  %b %bDigiByte Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    fi

    printf "\\n"

}

# Get RPC CREDENTIALS from digibyte.conf
get_dgb_rpc_credentials() {
    if [ -f "$DGB_CONF_FILE" ]; then
      RPCUSER=$(cat $DGB_CONF_FILE | grep rpcuser | cut -d'=' -f 2)
      RPCPASSWORD=$(cat $DGB_CONF_FILE | grep rpcpassword | cut -d'=' -f 2)
      RPCPORT=$(cat $DGB_CONF_FILE | grep rpcport | cut -d'=' -f 2)
      if [ "$RPCUSER" != "" ] && [ "$RPCPASSWORD" != "" ] && [ "$RPCPORT" != "" ]; then
        RPC_CREDENTIALS_OK="YES"
        printf "  %b DigiByte RPC credentials found:  ${TICK} Username ${TICK} Password ${TICK} Port\\n" "${TICK}"
      else
        RPC_CREDENTIALS_OK="NO"
        printf "  %b %bERROR: DigiByte RPC credentials are missing:%b" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        if [ "$RPCUSER" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Username     "
        if [ "$RPCPASSWORD" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Password     "
        if [ "$RPCPORT" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Port\\n"
        printf "\\n"
        printf "%b You need to add the missing DigiByte Core RPC credentials to your digibyte.conf file.\\n" "${INFO}"
        printf   "%b Without them your DigiAsset Node is unable to communicate with your DigiByte Node.\\n" "${INDENT}"
        printf "\\n"
        printf "%b Edit the digibyte.conf file:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   nano $DGB_CONF_FILE\\n" "${INDENT}"
        printf "\\n"
        printf "%b Add the following:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   rpcuser=desiredusername      # change 'desiredusername' to something else\\n" "${INDENT}"
        printf "%b   rpcpassword=desiredpassword  # change 'desiredpassword' to something else\\n" "${INDENT}"
        printf "%b   rpcport=14022                # best to leave this as is\\n" "${INDENT}"
        printf "\\n"
        exit 1
      fi
    fi
}


# Check if this DigiNode was setup using the official install script
# (Looks for a hidden file in the 'digibyte' install directory - .officialdiginode)
digibyte_check_official() {

    if [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then
        printf "%b Checking for DigiNode Tools Install of DigiByte Core: %bDETECTED%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        is_dgb_installed="yes"
    else
        printf "%b Checking for DigiNode Tools Install of DigiByte Core: %bNOT DETECTED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b DigiNode Installer was not used to install this DigiByte Node.\\n" "${INFO}"
        printf "%b This script will attempt to detect your setup but may require you to make\\n" "${INDENT}"
        printf "%b manual changes to make it work. It is possible things may break.\\n" "${INDENT}"
        printf "%b For best results use the DigiNode Installer.\\n" "${INDENT}"
        printf "\\n"
        is_dgb_installed="maybe"
    fi
}

# Check if this DigiNode was setup using the official install script
# (Looks for a hidden file in the 'digibyte' install directory - .officialdiginode)
digiasset_check_official() {

    if [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

        if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
          printf "%b Checking for DigiNode Tools Install of DigiAsset Node: %bDETECTED%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            is_dga_installed="yes"
        elif [ -d "$DGA_INSTALL_LOCATION" ]; then
            printf "%b Checking for DigiNode Tools Install of DigiAsset Node: %bNOT DETECTED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b DigiNode Installer was not used to install this DigiAsset Node.\\n" "${INFO}"
            printf "%b This script will attempt to detect your setup but may require you to make\\n" "${INDENT}"
            printf "%b manual changes to make it work. It is possible things may break.\\n" "${INDENT}"
            printf "%b For best results use the DigiNode installer.\\n" "${INDENT}"
            printf "\\n"
            is_dga_installed="maybe"
        else
            printf "%b Checking for DigiAsset Node: %bNOT INSTALLED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b A DigiAsset Node does not appear to be installed.\\n" "${INFO}"
            printf "%b You can install it using the DigiNode installer.\\n" "${INDENT}"
            printf "\\n"
            is_dga_installed="no"
        fi
    else
        if [ -d "$DGA_INSTALL_LOCATION" ]; then
            printf "%b Checking for DigiNode Tools Install of DigiAsset Node: %bNOT DETECTED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b DigiNode Installer was not used to install this DigiAsset Node.\\n" "${INFO}"
            printf "%b This script will attempt to detect your setup but may require you to make\\n" "${INDENT}"
            printf "%b manual changes to make it work. It is possible things may break.\\n" "${INDENT}"
            printf "%b For best results use the DigiNode installer.\\n" "${INDENT}"
            printf "\\n"
            is_dga_installed="maybe"
        else
            printf "%b Checking for DigiAsset Node: %bNOT INSTALLED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b A DigiAsset Node does not appear to be installed.\\n" "${INFO}"
            printf "%b You can install it using the DigiNode installer.\\n" "${INDENT}"
            printf "\\n"
            is_dga_installed="no"
        fi
    fi
}



# function to update the _config/main.json file with updated RPC credentials (if they have been changed)
# update_dga_config() {
# Only update if there are RPC get_rpc_credentials
#  if [[ $RPC_CREDENTIALS_OK == "YES" ]]; then
#    # need to write this one
#    true
#  fi
# }

# Check if the DigAssets Node is installed and running
is_dganode_installed() {

    # Begin check to see that DigiByte Core is installed
    printf "%b Checking DigiAsset Node...\\n" "${INFO}"

      ###############################################################
      # Perform initial checks for required DigiAsset Node packages #
      ###############################################################


      # Let's check if Go-IPFS is already installed
      IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)
      if [ "$IPFS_VER_LOCAL" = "" ]; then
          ipfs_installed="no"
          STARTWAIT=yes
      else
          DGA_STATUS="ipfsinstalled"
          ipfs_installed="yes"
      fi

      # Check if nodejs is installed

      REQUIRED_PKG="nodejs"
      PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
      if [ "" = "$PKG_OK" ]; then
          nodejs_installed="no"
          STARTWAIT=yes
      else
          if [ $DGA_STATUS = "ipfsinstalled" ]; then
            DGA_STATUS="nodejsinstalled"
          fi
           nodejs_installed="yes"
      fi

      # Display if DigiAsset Node packages are installed

      if [ "$nodejs_installed" = "yes" ]; then 
        printf "  %b Required DigiAsset Node packages are installed: ${TICK} Go-IPFS ${TICK} NodeJS\\n" "${TICK}"
      else
        printf "  %b Required DigiAsset Node packages are NOT installed:" "${CROSS}"
        if [ $ipfs_installed = "yes" ]; then
          printf "${TICK} Go-IPFS"
        else
          printf "${CROSS} Go-IPFS"
        fi
        if [ $nodejs_installed = "yes" ]; then
          printf "${TICK} NodeJS"
        else
          printf "${CROSS} NodeJS"
        fi
          printf "\\n"
          printf "  %b Some packages required to run the DigiAsset Node are not currently installed.\\n" "${INFO}"
          printf "  %b You can install them using the DigiNode Installer.\\n" "${INDENT}"
          printf "\\n"
          STARTWAIT="yes"
          DGA_STATUS="not_detected"
        fi

      # Check if ipfs service is running. Required for DigiAssets server.

      # ps aux | grep ipfs

      if [ "" = "$(pgrep ipfs)" ]; then
          printf "  %b IPFS daemon is NOT running%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
          printf "\\n"
          printf "  %b You can install it with the DigiNode Installer\\n" "${INFO}"
          printf "\\n"
          echo "You can set it up using the DigiNode Installer."
          printf "\\n"
          ipfs_running="no"
          DGA_STATUS="not_detected"
      else
          printf "  %b IPFS daemon is running\\n" "${TICK}"
          if [ $DGA_STATUS = "nodejsinstalled" ]; then
            DGA_STATUS="ipfsrunning"
          fi
          ipfs_running="yes"
      fi


      # Check for 'digiasset_node' index.js file

      if [ -f "$DGA_INSTALL_LOCATION/index.js" ]; then
        if [ $DGA_STATUS = "ipfsrunning" ]; then
           DGA_STATUS="installed" 
        fi
        printf "  %b DigiAsset Node software is installed.\\n" "${TICK}"
      else
          printf "  %b DigiAsset Node software cannot be found.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
          printf "\\n"
          printf "  %b DigiAsset Node software does not appear to be installed.\\n" "${INFO}"
          printf "  %b You can install it using the DigiNode Installer.\\n" "${INDENT}"
          printf "\\n"
          DGA_STATUS="not_detected"
          STARTWAIT="yes"
      fi


    # If we know DigiAsset Node is installed, let's check if it is actually running
    # First we'll see if it is running using the command: node index.js

      if [ "$DGA_STATUS" = "installed" ]; then
          IS_DGANODE_RUNNING=$(pgrep -f "node index.js")
          if [ "$IS_DGANODE_RUNNING" != "" ]; then
              DGA_STATUS="running"
              IS_DGANODE_RUNNING="YES"
              printf "  %b %bDigiAsset Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          else
              # If that didn't work, check if it is running using PM2
              IS_PM2_RUNNING=$(pm2 pid digiasset 2>/dev/null)
              # In case it has not been named, double check
              if [ "$IS_PM2_RUNNING" = "" ]; then
                  IS_PM2_RUNNING=$(pm2 pid index 2>/dev/null)
              fi

              if [ "$IS_PM2_RUNNING" = "" ]; then
                  DGA_STATUS="stopped"
                  IS_PM2_RUNNING="NO"
                  STARTWAIT=yes
                  printf "  %b DigiAsset Node Status: NOT RUNNING\\n" "${CROSS}"
              elif [ "$IS_PM2_RUNNING" = "0" ]; then
                  DGA_STATUS="stopped"
                  IS_PM2_RUNNING="NO"
                  STARTWAIT=yes
                  printf "  %b DigiAsset Node Status: NOT RUNNING  [ PM2 is stopped ]\\n" "${CROSS}"
              else
                  DGA_STATUS="running"
                  IS_PM2_RUNNING="YES"
                  printf "  %b %bDigiAsset Node Status: RUNNING%b [ PM2 is running ]\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
              fi    
          fi
      elif [ "$DGA_STATUS" = "not_detected" ]; then
          printf "  %b %bDigiAsset Node Status: NOT DETECTED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
      elif [ "$DGA_STATUS" != "" ]; then
          printf "  %b %bDigiAsset Node Status: NOT RUNNING%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
      fi

}

# Load the diginode.settings file if it exists. Create it if it doesn't. 
load_diginode_settings() {
    # Get saved variables from diginode.settings. Create settings file if it does not exist.
    if test -f $DGNT_SETTINGS_FILE; then
      # import saved variables from settings file
      printf "%b Importing diginode.settings file\\n" "${INFO}"
      source $DGNT_SETTINGS_FILE
    else
      # create diginode.settings file
      diginode_tools_create_settings
    fi
}

## Check if avahi-daemon is installed
is_avahi_installed() {

    # Begin check to see that DigiByte Core is installed
    printf "%b Checking for missing packages...\\n" "${INFO}"

    REQUIRED_PKG="avahi-daemon"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
      printf "  %b %bavahi-daemon is not currently installed.%b\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
      printf "\\n"
      printf "  %b Installing avahi-daemon is recommended if you are using a dedicated\\n" "${INFO}"
      printf "  %b device to run your DigiNode such as a Raspberry Pi. It means\\n" "${INDENT}"
      printf "  %b you can you can access it at the address $(hostname).local\\n" "${INDENT}"
      printf "  %b instead of having to remember the IP address. DigiNode Installer\\n" "${INDENT}"
      printf "  %b can set this up for for you.\\n" "${INDENT}"
      printf "\\n"
    else
      printf "  %b avahi-daemon is installed. DigiNode URL: https://$(hostname).local:8090\\n"  "${TICK}"
      IS_AVAHI_INSTALLED="YES"
    fi
}

##  Check if jq package is installed
is_jq_installed() {
    REQUIRED_PKG="jq"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
      printf "  %b jq is NOT installed.\\n"  "${CROSS}"
      printf "\\n"
      printf "  %b jq is a required package and will be installed. It is required for this\\n"  "${INFO}"
      printf "  %b script to be able to retrieve data from the DigiAsset Node.\\n"  "${INDENT}"
      install_jq='yes'
      printf "\\n"
    else
      printf "  %b jq is installed.\\n"  "${TICK}"
    fi
    printf "\\n"
}


# Check if digibyte core wallet is enabled
is_wallet_enabled() {
if [ "$DGA_STATUS" = "running" ]; then
    if [ -f "$DGB_CONF_FILE" ]; then
      WALLET_STATUS=$(cat $DGB_CONF_FILE | grep disablewallet | cut -d'=' -f 2)
      if [ "$WALLET_STATUS" = "1" ]; then
        WALLET_STATUS="disabled"
        printf "  %b %bDigiByte Wallet Status: DISABLED%b\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "  %b The DigiByte Core wallet is required if you want to create DigiAssets\\n" "${INFO}"
        printf "  %b from within the web UI. You can enable it by editing the digibyte.conf\\n" "${INDENT}"
        printf "  %b file and removing the disablewallet=1 flag.\\n" "${INDENT}"
        STARTWAIT="yes"
      else
        WALLET_STATUS="enabled"
        printf "  %b %bDigiByte Wallet Status: ENABLED%b\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      fi
    fi
  fi
  printf "\\n"
}

# Install needed packages
install_required_pkgs() {
    if [ "$install_jq" = "yes" ]; then
      printf "\\n"
      printf "%b Enter your password to install required packages. Press Ctrl-C to cancel.\n" "${INFO}"
      printf "\\n"
      sudo apt-get --yes install jq
    fi
}

# Quit message
quit_message() {
    # On quit, if there are updates available, ask the user if they want to install them
    if [ "$DGB_UPDATE_AVAILABLE" = "YES" ] || [ "$DGA_UPDATE_AVAILABLE" = "yes" ] || [ "$DGNTOOLS_UPDATE_AVAILABLE" = "yes" ] || [ "$IPFS_UPDATE_AVAILABLE" = "yes" ]; then

      # Install updates now
      clear -x
      printf "%b Updates are available for your DigiNode.\\n" "${INFO}"
      printf "\\n"
      read -p "Would you like to install them now? (Y/N)" -n 1 -r

      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        printf "%b Installing updates...\\n" "${INFO}"
        echo ""
        if [ "$DGB_UPDATE_AVAILABLE" = "YES" ]; then
          digibyte_do_install
        fi
        if [ "$IPFS_UPDATE_AVAILABLE" = "YES" ]; then
          ipfs_do_install
        fi
        if [ "$NODEJS_UPDATE_AVAILABLE" = "YES" ]; then
          nodejs_do_install
        fi
        if [ "$DGA_UPDATE_AVAILABLE" = "YES" ]; then
          dga_do_install
        fi
        if [ "$DGNTOOLS_UPDATE_AVAILABLE" = "YES" ]; then
          dgntools_do_install
        fi
      fi

      # Display donation qr code
      printf "\\n"
      donation_qrcode "Status Monitor"
      printf "\\n"

  # if there are no updates available display the donation QR code (not more than once every 15 minutes)
  elif [ "$DONATION_PLEA" = "yes" ]; then
      clear -x
      printf "\\n"
      printf "%b Thank you for using DigiNode Status Monitor.\\n" "${INFO}"
      printf "\\n"
      donation_qrcode "Status Monitor"
      printf "\\n"
      # Don't show the donation plea again for at least 15 minutes
      DONATION_PLEA="no"
  else
      clear -x
      printf "\\n"
      printf "%b Thank you for using DigiNode Status Monitor.\\n" "${INFO}"
      printf "\\n"
  fi

  # Display cursor again
  tput cnorm
}

startup_waitpause() {

# Optionally require a key press to continue, or a long 5 second pause. Otherwise wait 3 seconds before starting monitoring. 

echo ""
if [ "$STARTPAUSE" = "yes" ]; then
  read -n 1 -s -r -p "      < Press any key to continue >"
else

  if [ "$STARTWAIT" = "yes" ]; then
    echo "               < Wait for 7 seconds >"
    sleep 5
  else 
    echo "               < Wait for 4 seconds >"
    sleep 3
  fi
fi
echo ""

}

firstrun_monitor_configs() {

# If this is the first time running the status monitor, set the variables that update periodically
if [ "$DGNT_MONITOR_FIRST_RUN" = "" ]; then

    printf "%b First time running DigiNode Status Monitor. Performing initial setup...\\n" "${INFO}"

    # update external IP address and save to settings file
    str="Looking up external IP address..."
    printf "  %b %s" "${INFO}" "${str}"
    IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short)
    if [ $IP4_EXTERNAL_QUERY != "" ]; then
        IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
        sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=$IP4_EXTERNAL|" $DGNT_SETTINGS_FILE
    fi
    printf "  %b%b %s Done!\\n" "  ${OVER}" "${TICK}" "${str}"


    # update internal IP address and save to settings file
    str="Looking up internal IP address..."
    printf "  %b %s" "${INFO}" "${str}"
    IP4_INTERNAL_QUERY=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
    if [ $IP4_INTERNAL_QUERY != "" ]; then
        IP4_INTERNAL=$IP4_INTERNAL_QUERY
        sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=$IP4_INTERNAL|" $DGNT_SETTINGS_FILE
    fi
    printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    str="Setting up Status Monitor timers..."
    printf "  %b %s" "${INFO}" "${str}"
    # set 15 sec timer and save to settings file
    savedtime15sec="$(date)"
    sed -i -e "/^savedtime15sec=/s|.*|savedtime15sec=\"$(date)\"|" $DGNT_SETTINGS_FILE

    # set 1 min timer and save to settings file
    savedtime1min="$(date)"
    sed -i -e "/^savedtime1min=/s|.*|savedtime1min=\"$(date)\"|" $DGNT_SETTINGS_FILE

    # set 15 min timer and save to settings file
    savedtime15min="$(date)"
    sed -i -e "/^savedtime15min=/s|.*|savedtime15min=\"$(date)\"|" $DGNT_SETTINGS_FILE

    # set daily timer and save to settings file
    savedtime1day="$(date)"
    sed -i -e "/^savedtime1day=/s|.*|savedtime1day=\"$(date)\"|" $DGNT_SETTINGS_FILE

    # set weekly timer and save to settings file
    savedtime1week="$(date)"
    sed -i -e "/^savedtime1week=/s|.*|savedtime1week=\"$(date)\"|" $DGNT_SETTINGS_FILE
    printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"


    # check for current version number of DigiByte Core and save to settings file
    str="Looking up DigiByte Core version number..."
    printf "  %b %s" "${INFO}" "${str}"
    DGB_VER_LOCAL_QUERY=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
    if [ "$DGB_VER_LOCAL_QUERY" != "" ]; then
        DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
        sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=$DGB_VER_LOCAL|" $DGNT_SETTINGS_FILE
        printf "  %b%b %s Found: DigiByte Core v${DGB_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    else
        DGB_STATUS="startingup"
        printf "  %b%b %s ERROR: DigiByte Core is still starting up.\\n" "${OVER}" "${CROSS}" "${str}"
    fi

    # Log date of Status Monitor first run to diginode.settings
    str="Logging date of first run to diginode.settings file..."
    printf "  %b %s" "${INFO}" "${str}"
    DGNT_MONITOR_FIRST_RUN=$(date)
    sed -i -e "/^DGNT_MONITOR_FIRST_RUN=/s|.*|DGNT_MONITOR_FIRST_RUN=\"$DGNT_MONITOR_FIRST_RUN\"|" $DGNT_SETTINGS_FILE
    printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

fi

}

firstrun_dganode_configs() {

  # Set DigiAssets Node version veriables (if it is has just been installed)
  if [ "$DGA_STATUS" = "running" ] && [ "$DGA_FIRST_RUN" = ""  ]; then
      printf "%b First time running DigiAssets Node. Performing initial setup...\\n" "${INFO}"

    # Next let's try and get the minor version, which may or may not be available yet
    # If DigiAsset Node is running we can get it directly from the web server

      DGA_VER_MNR_LOCAL_QUERY=$(curl localhost:8090/api/version/list.json 2>/dev/null | jq .current | sed 's/"//g')
      if [ "$DGA_VER_MNR_LOCAL_QUERY" = "NA" ]; then
          # This is a beta so the minor version doesn't exist
          DGA_VER_MNR_LOCAL="beta"
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL|" $DGNT_SETTINGS_FILE
          printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL} beta\\n" "${OVER}" "${INFO}" "${str}"
      elif [ "$DGA_VER_MNR_LOCAL_QUERY" != "" ]; then
          DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL_QUERY
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL|" $DGNT_SETTINGS_FILE
          printf "%b%b %s DigiAsset Node v${DGA_VER_MNR_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
      else
          DGA_VER_MNR_LOCAL=""
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
      fi

      # Now we can update the main DGA_VER_LOCAL variable with the current version (major or minor depending on what was found)
      if [ "$DGA_VER_MNR_LOCAL" = "beta" ]; then
          DGA_VER_LOCAL="$DGA_VER_MAJ_LOCAL beta"  # e.g. DigiAsset Node v3 beta
      elif [ "$DGA_VER_MNR_LOCAL" = "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MAJ_LOCAL"       # e.g. DigiAsset Node v3
      elif [ "$DGA_VER_MNR_LOCAL" != "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MNR_LOCAL"       # e.g. DigiAsset Node v3.2
      fi

      str="Storing DigiAsset Node variables in settings file..."
      printf "  %b %s" "${INFO}" "${str}"
      sed -i -e '/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL="$DGA_VER_LOCAL"|' $DGNT_SETTINGS_FILE

      IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)
      sed -i -e '/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL="$IPFS_VER_LOCAL"|' $DGNT_SETTINGS_FILE

      # Get the local version number of NodeJS (this will also tell us if it is installed)
      NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')
      # Later versions use purely the 'node --version' command, (rather than nodejs)
      if [ "$NODEJS_VER_LOCAL" = "" ]; then
          NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
      fi
      sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE

      DGA_FIRST_RUN=$(date)
      sed -i -e '/^DGA_FIRST_RUN=/s|.*|DGA_FIRST_RUN="$DGA_FIRST_RUN"|' $DGNT_SETTINGS_FILE
      printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

  fi

}


pre_loop() {

  # Setup loopcounter - used for debugging
  loopcounter=0

  # Set timenow variable with the current time
  timenow=$(date)

  # Log date of Status Monitor first run to diginode.settings
  str="Logging date of this run to diginode.settings file..."
  printf "  %b %s" "${INFO}" "${str}"
  DGNT_MONITOR_LAST_RUN=$(date)
  sed -i -e "/^DGNT_MONITOR_LAST_RUN=/s|.*|DGNT_MONITOR_LAST_RUN=\"$DGNT_MONITOR_LAST_RUN\"|" $DGNT_SETTINGS_FILE
  printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

}



######################################################
######### PERFORM STARTUP CHECKS #####################
######################################################

startup_checks() {

  # Note: Some of these functions are found in the diginode-installer.sh file
  
  digimon_title_box                # Clear screen and display title box
  digimon_disclaimer               # Display disclaimer warning during development. Pause for confirmation.
  get_script_location              # Find which folder this script is running in (in case this is an unnoficial DigiNode)
  import_installer_functions       # Import diginode-installer.sh file because it contains functions we need
  diginode_tools_import_settings   # Import diginode.settings file
  diginode_logo_v3                 # Display DigiNode logo
  is_verbose_mode                  # Display a message if Verbose Mode is enabled
  sys_check                        # Perform basic OS check - is this Linux? Is it 64bit?
  rpi_check                        # Look for Raspberry Pi hardware. If found, only continue if it compatible.
  set_sys_variables                # Set various system variables once we know we are on linux
#  load_diginode_settings           # Load the diginode.settings file. Create it if it does not exist.
  diginode_tools_create_settings   # Create diginode.settings file (if it does not exist)
  swap_check                       # if this system has 4Gb or less RAM, check there is a swap drive
# install_diginode_tools           # install or upgrade the DigiNode tools scripts
  digibyte_check_official          # check if this is an official install of DigiByte Core
  is_dgbnode_installed             # Run checks to see if DigiByte Node is present. Exit if it isn't. Import digibyte.conf.
  digiasset_check_official         # check if this is an official install of DigiAsset Node
  is_dganode_installed             # Run checks to see if DigiAsset Node is present. Warn if it isn't.
  get_dgb_rpc_credentials          # Get the RPC username and password from digibyte.conf file. Warn if not present.
  is_wallet_enabled                # Check that the DigiByte Core wallet is enabled
  is_avahi_installed               # Check if avahi-daemon is installed
  is_jq_installed                  # Check if jq is installed
  install_required_pkgs            # Install jq
  firstrun_monitor_configs         # Do some configuration if this is the first time running the DigiNode Status Monitor
  firstrun_dganode_configs         # Do some configuration if this is the first time running the DigiAssets Node
  startup_waitpause                # Wait for key press or pause for a few seconds 
}




######################################################
######### RUN SCRIPT FROM HERE #######################
######################################################

startup_checks              # Performs all necessary startup checks
pre_loop                    # Run this just before starting the loop



######################################################################################
############## THE LOOP STARTS HERE - ENTIRE LOOP RUNS ONCE A SECOND #################
######################################################################################

while :
do

# Optional loop counter - useful for debugging
# echo "Loop Count: $loopcounter"

# Quit status monitor automatically based on the time set in diginode.settings
# Status Monitor will run indefinitely if the value is set to 0
if [ $SM_AUTO_QUIT -gt 0 ]; then
  if [ $loopcounter -gt 43200 ]; then
      echo ""
      echo "DigiNode Status Monitor quit automatically as it was left running for more than 12 hours."
      echo ""
      exit
  fi
fi

# Display the quit message on exit
trap quit_message EXIT

read -rsn1 input
if [ "$input" = "q" ]; then
    echo ""
    printf "%b Q Key Pressed. Exiting DigiNode Status Monitor...\\n" "${INDENT}"
    echo ""
    exit
fi



# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - HARDWARE
# ------------------------------------------------------------------------------

# Update timenow variable with current time
timenow=$(date)
loopcounter=$((loopcounter+1))

# Get current memory usage
ramused=$(free -m -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f3 | sed 's/.$//')
ramavail=$(free -m -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f6 | sed 's/.$//')
swapused=$(free -m -h | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f3)

# Get current system temp
temperature=$(cat </sys/class/thermal/thermal_zone0/temp)

# Convert temperature to Degrees C
tempc=$((temperature/1000))

# Convert temperature to Degrees F
tempf=$(((9/5) * $tempc + 32))


# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - DIGIBYTE CORE 
# ------------------------------------------------------------------------------

# Is digibyted running?
systemctl is-active --quiet digibyted && DGB_STATUS="running" || DGB_STATUS="stopped"

# Is digibyted in the process of starting up, and not ready to respond to requests?
if [ $DGB_STATUS = "running" ]; then
    BLOCKCOUNT_LOCAL=$($DGB_CLI getblockcount 2>/dev/null)

    if [ "$blockcount_local" != ^[0-9]+$ ]; then
      DGB_STATUS="startingup"
    fi
fi


# THE REST OF THIS ONLY RUNS NOTE IF DIGIBYED IS RUNNING

if [ $DGB_STATUS = "running" ]; then

  # Lookup sync progress value from debug.log. Use previous saved value if no value is found.
  if [ "$blocksync_progress" != "synced" ]; then
    blocksync_value_saved=$(blocksync_value)
    blocksync_value=$(tail -n 1 $DGB_SETTINGS_LOCATION/debug.log | cut -d' ' -f12 | cut -d'=' -f2 | sed -r 's/.{3}$//')
    if [ "$blocksync_value" -eq "" ]; then
       blocksync_value=$(blocksync_value_saved)
    fi
    echo "scale=2 ;$blocksync_percent*100"|bc
  fi

  # Get DigiByted Uptime
  uptime_seconds=$($DGB_CLI uptime 2>/dev/null)
  uptime=$(eval "echo $(date -ud "@$uptime_seconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")

  # Detect if the block chain is fully synced
  if [ "$blocksync_percent" -eq 100.00 ]; then
    blocksync_percent="100"
    blocksync_progress="synced"
  fi

  # Show port warning if connections are less than or equal to 7
  connections=$($DGB_CLI getconnectioncount 2>/dev/null)
  if [ $DGB_CONNECTIONS -le 8 ]; then
    connectionsmsg="${txtred}Low Connections Warning!${txtrst}"
  fi
  if [ $DGB_CONNECTIONS -ge 9 ]; then
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
    if [ $DGB_STATUS = "startingup" ]; then
        if [[ "$blockcount_local" = ^[0-9]+$ ]]; then
          DGB_STATUS="running"
        fi
    fi

    # Update local block count every 15 seconds (approx once per block)
    if [ $DGB_STATUS = "running" ]; then
          blockcount_local=$($DGB_CLI getblockchaininfo 2>/dev/null | grep headers | cut -d':' -f2 | sed 's/^.//;s/.$//')
    fi

    # If there is a new DigiByte Core release available, check every 15 seconds until it has been installed
    if [ $DGB_STATUS = "running" ] && [ DGB_VER_LOCAL_CHECK_FREQ = "15secs" ]; then

        # Get current software version, and write to diginode.settings
        DGB_VER_LOCAL=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
        sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=$DGB_VER_LOCAL|" $DGNT_SETTINGS_FILE

        # If DigiByte Core is up to date, switch back to checking the local version number daily
        if [ $(version $DGB_VER_LOCAL) -ge $(version $DGB_VER_RELEASE) ]; then
          DGB_VER_LOCAL_CHECK_FREQ="daily"
          sed -i -e "/^DGB_VER_LOCAL_CHECK_FREQ=/s|.*|DGB_VER_LOCAL_CHECK_FREQ=$DGB_VER_LOCAL_CHECK_FREQ|" $DGNT_SETTINGS_FILE
          DGB_UPDATE_AVAILABLE=NO
        else
          DGB_UPDATE_AVAILABLE=YES
        fi

    fi

    # Lookup disk usage, and store in diginode.settings if present
    update_disk_usage

    savedtime15sec="$timenow"
fi


# ------------------------------------------------------------------------------
#    Run once every 1 minute
#    Every 15 seconds lookup the latest block from the online block exlorer to calculate sync progress.
# ------------------------------------------------------------------------------

timedif1min=$(printf "%s\n" $(( $(date -d "$timenow" "+%s") - $(date -d "$savedtime1min" "+%s") )))

# Update DigiByte Core sync progress every minute, if it is running
if [ $DGB_STATUS = "running" ]; then

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

fi

# Update local IP address if it has changed
IP4_INTERNAL_NEW=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
if [ $IP4_INTERNAL_NEW != $IP4_INTERNAL ]; then
  IP4_INTERNAL = $IP4_INTERNAL_NEW
  sed -i -e '/^IP4_INTERNAL=/s|.*|IP4_INTERNAL="$IP4_INTERNAL_NEW"|' $DGNT_SETTINGS_FILE
fi

# Update diginode.settings with when Status Monitor last ran
DGNT_MONITOR_LAST_RUN=$(date)
sed -i -e '/^DGNT_MONITOR_LAST_RUN=/s|.*|DGNT_MONITOR_LAST_RUN="$DGNT_MONITOR_LAST_RUN"|' $DGNT_SETTINGS_FILE

savedtime1min="$timenow"


# ------------------------------------------------------------------------------
#    Run once every 15 minutes
#    Update the Internal & External IP
# ------------------------------------------------------------------------------

timedif15min=$(printf "%s\n" $(( $(date -d "$timenow" "+%s") - $(date -d "$savedtime15min" "+%s") )))

if [ $timedif15min -gt 300 ]; then

    # update external IP if it has changed
    IP4_EXTERNAL_NEW=$(dig @resolver4.opendns.com myip.opendns.com +short)
    if [ $IP4_EXTERNAL_NEW != $IP4_EXTERNAL ]; then
      IP4_EXTERNAL = $IP4_EXTERNAL_NEW
      sed -i -e '/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL="$IP4_EXTERNAL_NEW"|' $DGNT_SETTINGS_FILE
    fi

    # If DigiAssets server is running, lookup local version number of DigiAssets server IP
    if [ $DGA_STATUS = "running" ]; then

      echo "need to add check for change of DGA version number" 

    # Next let's try and get the minor version, which may or may not be available yet
    # If DigiAsset Node is running we can get it directly from the web server

      DGA_VER_MNR_LOCAL_QUERY=$(curl localhost:8090/api/version/list.json 2>/dev/null | jq .current | sed 's/"//g')
      if [ "$DGA_VER_MNR_LOCAL_QUERY" = "NA" ]; then
          # This is a beta so the minor version doesn't exist
          DGA_VER_MNR_LOCAL="beta"
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL|" $DGNT_SETTINGS_FILE
          printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL} beta\\n" "${OVER}" "${INFO}" "${str}"
      elif [ "$DGA_VER_MNR_LOCAL_QUERY" != "" ]; then
          DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL_QUERY
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL|" $DGNT_SETTINGS_FILE
          printf "%b%b %s DigiAsset Node v${DGA_VER_MNR_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
      else
          DGA_VER_MNR_LOCAL=""
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
      fi

      # Now we can update the main DGA_VER_LOCAL variable with the current version (major or minor depending on what was found)
      if [ "$DGA_VER_MNR_LOCAL" = "beta" ]; then
          DGA_VER_LOCAL="$DGA_VER_MAJ_LOCAL beta"  # e.g. DigiAsset Node v3 beta
      elif [ "$DGA_VER_MNR_LOCAL" = "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MAJ_LOCAL"       # e.g. DigiAsset Node v3
      elif [ "$DGA_VER_MNR_LOCAL" != "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MNR_LOCAL"       # e.g. DigiAsset Node v3.2
      fi

      sed -i -e '/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL="$DGA_VER_LOCAL"|' $DGNT_SETTINGS_FILE

      # Get the local version number of NodeJS (this will also tell us if it is installed)
      NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')
      # Later versions use purely the 'node --version' command, (rather than nodejs)
      if [ "$NODEJS_VER_LOCAL" = "" ]; then
          NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
      fi
      sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE

      IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)
      sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=$IPFS_VER_LOCAL|" $DGNT_SETTINGS_FILE
    fi

    # When the user quits, enable showing a donation plea (this ensures it is not shown more than once every 15 mins)
    DONATION_PLEA="yes"

    # reset 15 minute timer
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
  #  SYSTEM_SECURITY_UPDATES=$(/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 1)
  #  SYSTEM_REGULAR_UPDATES=$(/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 2)
  #  sed -i -e "/^SYSTEM_SECURITY_UPDATES=/s|.*|SYSTEM_SECURITY_UPDATES=\"$SYSTEM_SECURITY_UPDATES\"|" $DGNT_SETTINGS_FILE
  #  sed -i -e "/^SYSTEM_REGULAR_UPDATES=/s|.*|SYSTEM_REGULAR_UPDATES=\"$SYSTEM_REGULAR_UPDATES\"|" $DGNT_SETTINGS_FILE


    # Check for new release of DigiByte Core on Github
    DGB_VER_RELEASE_QUERY=$(curl -sfL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//g')
    if [ "$DGB_VER_RELEASE_QUERY" != "" ]; then
      DGB_VER_RELEASE=$DGB_VER_RELEASE_QUERY
      sed -i -e "/^DGB_VER_RELEASE=/s|.*|DGB_VER_RELEASE=$DGB_VER_RELEASE|" $DGNT_SETTINGS_FILE
    fi

    # If there is a new DigiByte Core release available, check every 15 seconds until it has been installed
    if [ "$DGB_STATUS" = "running" ] && [ "$DGB_VER_LOCAL_CHECK_FREQ" = "daily" ]; then

        # Get current software version, and write to diginode.settings
        DGB_VER_LOCAL=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
        sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=$DGB_VER_LOCAL|" $DGNT_SETTINGS_FILE

        # Compare current DigiByte Core version with Github version to know if there is a new version available
        if [ $(version $DGB_VER_LOCAL) -lt $(version $DGB_VER_RELEASE) ]; then
          DGB_VER_LOCAL_CHECK_FREQ="15secs"
          sed -i -e "/^DGB_VER_LOCAL_CHECK_FREQ=/s|.*|DGB_VER_LOCAL_CHECK_FREQ=$DGB_VER_LOCAL_CHECK_FREQ|" $DGNT_SETTINGS_FILE
          DGB_UPDATE_AVAILABLE=YES
        else
          DGB_UPDATE_AVAILABLE=NO
        fi
    fi

    # Check for new release of DigiNode Tools on Github
    DGNT_VER_RELEASE_QUERY=$(curl -sfL https://api.github.com/repos/saltedlolly/diginode/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')
      if [ "$DGNT_VER_RELEASE_QUERY" != "" ]; then
        DGNT_VER_RELEASE=$DGNT_VER_RELEASE_QUERY
        sed -i -e "/^DGNT_VER_RELEASE=/s|.*|DGNT_VER_RELEASE=$DGNT_VER_RELEASE|" $DGNT_SETTINGS_FILE
        # Check if there is an update for Go-IPFS
        if [ $(version $DGNT_VER_LOCAL) -ge $(version $DGNT_VER_RELEASE) ]; then
          DGNT_UPDATE_AVAILABLE=NO
        else
          DGNT_UPDATE_AVAILABLE=YES
        fi
    fi
    

    # Check for new release of DigiAsset Node
    DGA_VER_RELEASE_QUERY=$(curl -sfL https://versions.digiassetx.com/digiasset_node/versions.json 2>/dev/null | jq last | sed 's/"//g')
    if [ $DGA_VER_RELEASE_QUERY != "" ]
      DGA_VER_RELEASE=$DGA_VER_RELEASE_QUERY
      DGA_VER_MJR_RELEASE=$(echo $DGA_VER_RELEASE | cut -d'.' -f1)
      sed -i -e "/^DGA_VER_RELEASE=/s|.*|DGA_VER_RELEASE=$DGA_VER_RELEASE|" $DGNT_SETTINGS_FILE
      sed -i -e "/^DGA_VER_MJR_RELEASE=/s|.*|DGA_VER_MJR_RELEASE=$DGA_VER_MJR_RELEASE|" $DGNT_SETTINGS_FILE
    fi

    # If installed, get the major release directly from the api.js file
    if test -f $DGA_INSTALL_LOCATION/lib/api.js; then
      DGA_VER_MJR_LOCAL=$(cat $DGA_INSTALL_LOCATION/lib/api.js | grep "const apiVersion=" | cut -d'=' -f2 | cut -d';' -f1)
    fi
    if [ "$DGA_VER_RELEASE" != "" ]; then
        sed -i -e "/^DGA_VER_RELEASE=/s|.*|DGA_VER_RELEASE=$DGA_VER_RELEASE|" $DGNT_SETTINGS_FILE
        # Check if there is an update for Go-IPFS
        if [ $(version $DGA_VER_MJR_LOCAL) -ge $(version $DGA_VER_MJR_RELEASE) ]; then
          DGA_UPDATE_AVAILABLE=NO
        else
          DGA_UPDATE_AVAILABLE=YES
        fi
    fi

    # Check for new release of Go-IPFS
    IPFS_VER_RELEASE_QUERY=$(curl -sfL https://dist.ipfs.io/go-ipfs/versions 2>/dev/null | sed '/rc/d' | tail -n 1 | sed 's/v//g')
    if [ "$IPFS_VER_RELEASE_QUERY" != "" ]; then
        IPFS_VER_RELEASE=$IPFS_VER_RELEASE_QUERY
        sed -i -e "/^IPFS_VER_RELEASE=/s|.*|IPFS_VER_RELEASE=$IPFS_VER_RELEASE|" $DGNT_SETTINGS_FILE
        # Check if there is an update for Go-IPFS
        if [ $(version $IPFS_VER_LOCAL) -ge $(version $IPFS_VER_RELEASE) ]; then
          IPFS_UPDATE_AVAILABLE=NO
        else
          IPFS_UPDATE_AVAILABLE=YES
        fi
    fi

    # Check for new release of IPFS Updater
    IPFSU_VER_RELEASE_QUERY=$(curl -sfL https://dist.ipfs.io/ipfs-update/versions 2>/dev/null | tail -n 1 | sed 's/v//g')
    if [ "$IPFSU_VER_RELEASE_QUERY" != "" ]; then
      IPFSU_VER_RELEASE=$IPFSU_VER_RELEASE_QUERY
      sed -i -e "/^IPFSU_VER_RELEASE=/s|.*|IPFSU_VER_RELEASE=$IPFSU_VER_RELEASE|" $DGNT_SETTINGS_FILE
      # Check if there is an update for IPFS Updater
      if [ $(version $IPFSU_VER_LOCAL) -ge $(version $IPFSU_VER_RELEASE) ]; then
        IPFSU_UPDATE_AVAILABLE=NO
      else
        IPFSU_UPDATE_AVAILABLE=YES
      fi
    fi

    # reset 24 hour timer
    savedtime24hrs="$timenow"
fi




###################################################################
#### GENERATE NORMAL DISPLAY #############################################
###################################################################

# Double buffer output to reduce display flickering
# (output=$(clear -x;

echo -e "${txtbld}"
echo -e "       ____   _         _   _   __            __     "             
echo -e "      / __ \ (_)____ _ (_) / | / /____   ____/ /___  ${txtrst}╔═════════╗${txtbld}"
echo -e "     / / / // // __ '// / /  |/ // __ \ / __  // _ \ ${txtrst}║ STATUS  ║${txtbld}"
echo -e "    / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/ ${txtrst}║ MONITOR ║${txtbld}"
echo -e "   /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/  ${txtrst}╚═════════╝${txtbld}"
echo -e "              /____/                                 ${txtrst}"                         
echo '
 ╔═══════════════╦════════════════════════════════════════════════════╗'
if [ $DGB_STATUS = 'running' ]; then # Only display if digibyted is running
  printf " ║ CONNECTIONS   ║  " && printf "%-10s %35s %-4s\n" "$DGB_CONNECTIONS Nodes" "[ $connectionsmsg" "]  ║"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
  printf " ║ BLOCK HEIGHT  ║  " && printf "%-26s %19s %-4s\n" "$blocklocal Blocks" "[ Synced: $blocksyncpercent %" "]  ║"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
  printf " ║ NODE UPTIME   ║  " && printf "%-49s ║ \n" "$uptime"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
fi # end check to see of digibyted is running
if [ $DGB_STATUS = 'stopped' ]; then # Only display if digibyted is NOT running
  printf " ║ NODE STATUS   ║  " && printf "%-49s ║ \n" " [ DigiByte daemon service is stopped. ]"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
fi
if [ $DGB_STATUS = 'startingup' ]; then # Only display if digibyted is NOT running
  printf " ║ NODE STATUS   ║  " && printf "%-49s ║ \n" " [ DigiByte daemon is starting... ]"
  echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
fi
printf " ║ IP ADDRESSES  ║  " && printf "%-49s %-1s\n" "Internal: $IP4_INTERNAL  External: $IP4_EXTERNAL" "║" 
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
if [ $IS_AVAHI_INSTALLED = 'YES' ] && [ DGA_STATUS = 'running' ]; then # Use .local domain if available, otherwise use the IP address
printf " ║ WEB UI        ║  " && printf "%-49s %-1s\n" "http://$hostname.local:8090" "║"
elif [ DGA_STATUS = 'running' ]; then
printf " ║ WEB UI        ║  " && printf "%-49s %-1s\n" "http://$IP4_INTERNAL:8090" "║"
fi
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ RPC ACCESS    ║  " && printf "%-49s %-1s\n" "User: $rpcusername  Pass: $rpcpassword  Port: $rpcport" "║" 
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
if [ $DGB_UPDATE_AVAILABLE = "YES" ];then
printf " ║ DIGINODE  ║  " && printf "%-26s %19s %-4s\n" "DigiByte Core v$DGB_VER_LOCAL" "[ ${txtgrn}Update Available: v$DGB_VER_RELEASE${txtrst}" "]  ║"
else
printf " ║ DIGINODE  ║  " && printf "%-26s %19s %-4s\n" "DigiByte Core v$DGB_VER_LOCAL" "]  ║"
fi
echo " ║   SOFTWARE    ╠═════════════════════════════════════════════════════╣"
if [ $IPFS_UPDATE_AVAILABLE = "YES" ];then
printf " ║               ║  " && printf "%-26s %19s %-4s\n" "Go-IPFS v$IPFS_VER_LOCAL" "[ ${txtgrn}Update Available: v$IPFS_VER_RELEASE${txtrst}" "]  ║"
else
printf " ║               ║  " && printf "%-49s ║ \n" "Go-IPFS v$IPFS_VER_LOCAL"
fi
echo " ║               ╠═════════════════════════════════════════════════════╣"
if [ $DGA_UPDATE_AVAILABLE = "YES" ];then
printf " ║               ║  " && printf "%-49s ║ \n" "DigiAsset Node v$DGA_VER_LOCAL"
else
printf " ║               ║  " && printf "%-49s ║ \n" "DigiAsset Node v$DGA_VER_LOCAL" "[ ${txtgrn}Update Available: v$DGA_VER_RELEASE${txtrst}" "]  ║"
fi
echo " ║               ╠═════════════════════════════════════════════════════╣"
printf " ║               ║  " && printf "%-49s ║ \n" "DigiNode Tools v$DGNT_VER_LOCAL"
echo " ╚═══════════════╩════════════════════════════════════════════════════╝"
if [ $DGB_STATUS = 'stopped' ]; then # Only display if digibyted is NOT running
echo "WARNING: Your DigiByte daemon service is not currently running."
echo "         To start it enter: sudo systemctl start digibyted"
fi
if [ $DGB_STATUS = 'startingup' ]; then # Only display if digibyted is NOT running
echo "IMPORTANT: DigiByte Core is currently in the process of starting up."
echo "           This can take up to 10 minutes. Please wait..."
fi
if [ $DGB_STATUS = 'running' ] && [ $DGB_CONNECTIONS -le 10 ]; then # Only show port forwarding instructions if connection count is less or equal to 10 since it is clearly working with a higher count
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
echo ""
echo " ╔═══════════════╦════════════════════════════════════════════════════╗"
printf " ║ DEVICE      ║  " && printf "%-35s %10s %-4s\n" "$model" "[ $modelmem RAM" "]  ║"
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ DISK USAGE    ║  " && printf "%-34s %-19s\n" "${DGB_DATA_DISKUSED_HR}b of ${DGB_DATA_DISKTOTAL_HR}b ($DGB_DATA_DISKUSED_PERC)" "[ ${DGB_DATA_DISKFREE_HR}b free ]  ║"
echo " ╠═══════════════╬════════════════════════════════════════════════════╣"
printf " ║ MEMORY USAGE  ║  " && printf "%-34s %-19s\n" "$ramused of $RAMTOTAL_HR" "[ $ramavail free ]  ║"
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
echo "              Press Q to quit and stop monitoring"
echo ""

# end output double buffer

# echo "$output"
sleep 1
done

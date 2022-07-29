#!/bin/bash
#
#           Name:  DigiNode Status Monitor v0.5.3
#
#        Purpose:  Install and manage a DigiByte Node and DigiAsset Node via the linux command line.
#          
#  Compatibility:  Supports x86_86 or arm64 hardware with Ubuntu or Debian 64-bit distros.
#                  Other distros may not work at present. Please help test so that support can be added.
#                  A Raspberry Pi 4 8Gb running Ubuntu Server 64-bit is recommended.
#
#         Author:  Olly Stedall @saltedlolly
#
#        Website:  https://diginode.digibyte.help
#
#        Support:  https://t.me/+ked2VGZsLPAyN2Jk
#
#    Get Started:  curl http://diginode-setup.digibyte.help | bash  
#  
#                  Alternatively clone the repo to your home folder:
#
#                  cd ~
#                  git clone https://github.com/saltedlolly/diginode-tools/
#                  chmod +x ~/diginode-tools/diginode.sh
#
#                  To run DigiNode Status Monitor:
#
#                  ~/diginode-tools/diginode.sh      
#
# -----------------------------------------------------------------------------------------------------

#####################################################
##### IMPORTANT INFORMATION #########################
#####################################################

# Please note that this script requires the diginode-setup.sh script to be with it
# in the same folder when it runs. Tne setup script contains functions and variables
# used by this one.
#
# Both DigiNode Setup and Status Monitor scripts make use of a settings file
# located at: ~/.diginode/diginode.settings
#
# It want to make changes to folder locations etc. please edit this file.
# (e.g. To move your DigiByte data folder to an external drive.)
# 
# Note: The default location of the diginode.settings file can be changed at the top of
# the setup script, but this is not recommended.

######################################################
######### VARIABLES ##################################
######################################################

# For better maintainability, we store as much information that can change in variables
# This allows us to make a change in one place that can propagate to all instances of the variable
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions

# This variable stores the version number of this release of 'DigiNode Tools'.
# When a new release is made, this number gets updated to match the release number on GitHub.
# The version number should be three numbers seperated by a period
# Do not change this number or the mechanism for installing updates may no longer work.
DGNT_VER_LOCAL=0.5.3
# Last Updated: 2022-07-27

# This is the command people will enter to run the install script.
DGNT_SETUP_OFFICIAL_CMD="curl -sSL diginode-setup.digibyte.help | bash"

########################################################
#### UPDATE THESE VALUES FROM DIGINODE SETUP FIRST #####
########################################################

# These colour and text formatting variables are included in both scripts since they are required before diginode-setup.sh is sourced into this one.
# Changes to these variables should be first made in the setup script and then copied here, to help ensure the settings remain identical in both scripts.

# Set these values so we can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_LIGHT_RED='\e[1;31m'
COL_LIGHT_CYAN='\e[1;96m'
COL_BOLD_WHITE='\e[1;37m'
TICK="  [${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="  [${COL_LIGHT_RED}✗${COL_NC}]"
WARN="  [${COL_LIGHT_RED}!${COL_NC}]"
INFO="  [${COL_BOLD_WHITE}i${COL_NC}]"
SKIP="  [${COL_BOLD_WHITE}-${COL_NC}]"
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

txtbred=$(tput setaf 9)  # Bright Red
txtbgrn=$(tput setaf 10) # Bright Green
txtbylw=$(tput setaf 11) # Bright Yellow
txtbblu=$(tput setaf 12) # Bright Blue
txtbpur=$(tput setaf 13) # Bright Purple
txtbcyn=$(tput setaf 14) # Bright Cyan
txtbwht=$(tput setaf 15) # Bright White

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
VERBOSE_MODE=false       # Set this to true to get more verbose feedback. Very useful for debugging.
UNINSTALL=false
LOCATE_DIGIBYTE=false
# Check arguments for the undocumented flags
# --dgndev (-d) will use and install the develop branch of DigiNode Tools (used during development)
for var in "$@"; do
    case "$var" in
        "--uninstall" ) UNINSTALL=true;;
        "--verboseon" ) VERBOSE_MODE=true;;
        "--verboseoff" ) VERBOSE_MODE=false;;
        "--locatedgb" ) LOCATE_DIGIBYTE=true;;
    esac
done




######################################################
######### FUNCTIONS ##################################
######################################################

# Find where this script is running from, so we can make sure the diginode-setup.sh script is with it
get_script_location() {
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  DGNT_LOCATION_NOW="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  DGNT_SETUP_SCRIPT_NOW=$DGNT_LOCATION_NOW/diginode-setup.sh

  if [ "$VERBOSE_MODE" = true ]; then
    printf "%b Monitor Script Location: $DGNT_LOCATION_NOW\\n" "${INFO}"
    printf "%b Setup Script Location (presumed): $DGNT_SETUP_SCRIPT_NOW\\n" "${INFO}"
  fi
}

# PULL IN THE CONTENTS OF THE SETUP SCRIPT BECAUSE IT HAS FUNCTIONS WE WANT TO USE
import_setup_functions() {
    # BEFORE INPORTING THE FUNCTIONS FROM diginode-setup.sh, SET VARIABLE SO IT DOESN'T ACTUAL RUN THE SETUP SCRIPT
    RUN_SETUP="NO"
    # If the setup file exists,
    if [[ -f "$DGNT_SETUP_SCRIPT_NOW" ]]; then
        # source it
        if [ $VERBOSE_MODE = true ]; then
          printf "%b Importing functions from diginode-setup.sh\\n" "${TICK}"
          printf "\\n"
        fi
        source "$DGNT_SETUP_SCRIPT_NOW"

        # Set run location to local (this script cannot be run remotely). This variable is used when checking if the diginode.settings file needs updating.
        DGNT_RUN_LOCATION="local"

    # Otherwise,
    else
        printf "\\n"
        printf "%b %bERROR: diginode-setup.sh file not found.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b The diginode-setup.sh file is required to continue.\\n" "${INDENT}"
        printf "%b It contains functions we need to run the DigiNode Status Monitor.\\n" "${INDENT}"
        printf "\\n"
        printf "%b If you have not already setup your DigiNode, please use\\n" "${INDENT}"
        printf "%b the official DigiNode Setup script:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   $DGNT_SETUP_OFFICIAL_CMD\\n" "${INDENT}"
        printf "\\n"
        printf "%b Alternatively, to use 'DigiNode Status Monitor' with your existing\\n" "${INDENT}"
        printf "%b DigiByte node, clone the official repo to your home folder:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   cd ~ \\n" "${INDENT}"
        printf "%b   git clone https://github.com/saltedlolly/diginode/ \\n" "${INDENT}"
        printf "%b   chmod +x ~/diginode/diginode.sh \\n" "${INDENT}"
        printf "\\n"
        printf "%b To run it:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ~/diginode/diginode.sh\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi
}

# A simple function that clears the sreen and displays the status monitor title in a box
digimon_title_box() {
    clear -x
    tput civis
    tput smcup
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
    printf "%b %bWARNING: This script is currently in public beta.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b Please join the Telegram support group to report any bugs and share feeback:\\n" "${INDENT}"
    printf "%b not even run. Please use for testing only until further notice.\\n" "${INDENT}"
    printf "\\n"
    read -n 1 -s -r -p "   < Press Ctrl-C to quit, or any other key to Continue. >"
    printf "\\n\\n"
}


# This script will prompt the user to locate DigiByte core, or install it
locate_digibyte_node() {

        printf "\\n"
        printf "%b Please choose from the options below:\\n" "${INDENT}"
        printf "\\n"
        printf "%b 1. ${txtbld}Locate your existing DigiByte Node${txtrst}\\n" "${INDENT}"
        printf "%b    This will prompt you for the absolute path of your existing DigiByte Core\\n" "${INDENT}"
        printf "%b    installation folder.\\n" "${INDENT}"
        printf "\\n"
        printf "%b 2. ${txtbld}Setup a NEW DigiByte Node${txtrst}\\n" "${INDENT}"
        printf "%b    If you don't already have a DigiByte Node installed, this will launch\\n" "${INDENT}"
        printf "%b    DigiNode Setup so you can install one.\\n" "${INDENT}"
        printf "\\n"
        printf "%b 3. ${txtbld}Skip detecting a DigiByte Node${txtrst}\\n" "${INDENT}"
        printf "%b    If there is an existing DigiByte Node it not be monitored.\\n" "${INDENT}"
        printf "\\n"
        printf "%b 4. ${txtbld}EXIT${txtrst}\\n" "${INDENT}"
        printf "%b    Exit DigiNode Status Monitor.\\n" "${INDENT}"
        printf "\\n"
        read -n 1 -r -s -p "                  Please choose option 1, 2, 3 or 4: "        
        printf "\\n" 

      if [[ $REPLY =~ ^[3]$ ]]; then
        printf "\\n" 
        printf "%b Skip locating DigiByte Core install folder...\\n" "${INFO}"
        echo ""
        is_dgb_installed="no"
        DGB_STATUS="not_detected"
        SKIP_DETECTING_DIGIBYTE="YES"
      elif [[ $REPLY =~ ^[2]$ ]]; then
        printf "\\n" 
        printf "%b Running DigiNode Setup...\\n" "${INFO}"
        echo ""
        if [ "$DGNT_RUN_LOCATION" = "remote" ]; then
            exec curl -sSL diginode-setup.digibyte.help | bash -s -- --fulldiginode
        elif [ "$DGNT_RUN_LOCATION" = "local" ]; then
            ~/diginode-tools/diginode-setup.sh --fulldiginode
        fi  
        exit
      elif [[ $REPLY =~ ^[1]$ ]]; then
        printf "\\n" 
        printf "%b Prompting for absoute path of digibyte core install folder...\\n" "${INFO}"

        DGB_CORE_PATH=$(whiptail --inputbox "Please enter the absolute path of your DigiByte Core install folder.\\n\\nExample: /usr/bin/digibyted" 8 78 --title "Enter the absolute path of your DigiByte Node." 3>&1 1>&2 2>&3)
                                                                            # A trick to swap stdout and stderr.
        # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
        exitstatus=$?
        if [ $exitstatus == 0 ]; then
            printf "%b You entered the following path: $DGB_CORE_PATH\\n" "${INFO}"

            # Delete old ~/digibyte symbolic link
            if [ -h "$USER_HOME/digibyte" ]; then
                str="Deleting old 'digibyte' symbolic link from home folder..."
                printf "%b %s" "${INFO}" "${str}"
                rm $USER_HOME/digibyte
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Create new symbolic link
            str="Creating new ~/digibyte symbolic link pointing at $DGB_CORE_PATH ..."
            printf "%b %s" "${INFO}" "${str}"
            ln -s $DGB_CORE_PATH $USER_HOME/digibyte
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            printf "\\n"
            printf "%b Run DigiNode again to check your new symbolic link...\\n" "${INFO}"
            printf "\\n"
            exit
        else
            printf "%b %bYou cancelled entering the path to your DigiByte Core install folder.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b Tip: If you already have an existing DigiByte Node installed on this system, and\\n" "${INFO}"
            printf "%b would rather locate it manually, you can create a 'digibyte' symbolic link in your\\n" "${INDENT}"
            printf "%b home folder that points to the location of your existing DigiByte install folder:\\n" "${INDENT}"
            printf "\\n"
            printf "%b For example: ${txtbld}ln -s /usr/bin/digibyted ~/digibyte${txtrst}\\n" "${INDENT}"
            printf "\\n"
            exit
        fi      

      else
        printf "\\n" 
        printf "%b Tip: If you already have an existing DigiByte Node installed on this system, and\\n" "${INFO}"
        printf "%b would rather locate it manually, you can create a 'digibyte' symbolic link in your\\n" "${INDENT}"
        printf "%b home folder that points to the location of your existing DigiByte install folder:\\n" "${INDENT}"
        printf "\\n"
        printf "%b For example: ${txtbld}ln -s /usr/bin/digibyted ~/digibyte${txtrst}\\n" "${INDENT}"
        printf "\\n"
        exit
      fi
      printf "\\n"
}

# Check if this DigiNode was setup using the official install script
# (Looks for a hidden file in the 'digibyte' install directory - .officialdiginode)
digibyte_check_official() {

    printf " =============== Checking: DigiByte Node ===============================\\n\\n"
    # ==============================================================================

    if [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then
        printf "%b Checking for DigiNode Tools Install of DigiByte Node: %bDETECTED%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        is_dgb_installed="yes"
    else
        printf "%b Checking for DigiNode Tools Install of DigiByte Node: %bNOT DETECTED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b This script will attempt to detect your setup but may require you to make\\n" "${INDENT}"
        printf "%b manual changes to make it work. It is possible things may break.\\n" "${INDENT}"
        printf "%b For best results use DigiNode Tools to setup your DigiNode.\\n" "${INDENT}"
        printf "\\n"
        is_dgb_installed="maybe"
    fi

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
    printf "%b Looking for DigiByte Core...\\n" "${INFO}"
    printf "\\n"

    # Check for digibyte core install folder in home folder (either 'digibyte' folder itself, or a symbolic link pointing to it)
    if [ -h "$DGB_INSTALL_LOCATION" ]; then
      find_dgb_folder="yes"
      is_dgb_installed="maybe"
      if [ $VERBOSE_MODE = true ]; then
          printf "%b digibyte symbolic link found in home folder.\\n" "${TICK}"
      fi
    else
      if [ -e "$DGB_INSTALL_LOCATION" ]; then
      find_dgb_folder="yes"
      is_dgb_installed="maybe"
      if [ $VERBOSE_MODE = true ]; then
          printf "%b digibyte folder found in home folder.\\n" "${TICK}"
      fi
      else
        printf "\\n"
        printf "%b %bERROR: Unable to detect DigiByte Node install folder%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b This script is unable to detect your DigiByte Core installation folder\\n" "${INDENT}"
        if [ "$LOCATE_DIGIBYTE" = true ]; then
            is_dgb_installed="no"
            locate_digibyte_node
        else
            printf "\\n"
            is_dgb_installed="no"
        fi
      fi
    fi

    # Check if digibyted is installed

    if [ -f "$DGB_DAEMON" -a -f "$DGB_CLI" ]; then
      find_dgb_binaries="yes"
      is_dgb_installed="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "%b Digibyte Core Binaries located: ${TICK} digibyted ${TICK} digibyte-cli\\n" "${TICK}"
      fi
    else
        printf "%b %bERROR: Unable to locate DigiByte Core binaries.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b This script is unable to find your DigiByte Core binaries - digibyte & digibye-cli.\\n" "${INDENT}"
        if [ "$LOCATE_DIGIBYTE" = true ] && [ "$SKIP_DETECTING_DIGIBYTE" != "YES" ]; then
            is_dgb_installed="no"
            locate_digibyte_node
        else
            printf "\\n"
            is_dgb_installed="no"
        fi
    fi

    # Check if digibyte core is configured to run as a service

    if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB_UPSTART_SERVICE_FILE" ]; then
      find_dgb_service="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "%b DigiByte daemon service file is installed\\n" "${TICK}"
      fi
    else
        printf "%b %bWARNING: digibyted.service not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b To ensure your DigiByte Node stays running 24/7, it is a good idea to setup\\n" "${INDENT}"
        printf "%b DigiByte daemon to run as a service. If you already have a systemd service file\\n" "${INDENT}"
        printf "%b to run 'digibyted', you can rename it to /etc/systemd/system/digibyted.service\\n" "${INDENT}"
        printf "%b so that this script can find it. If you wish to setup your DigiByte Node to run\\n" "${INDENT}"
        printf "%b as a service, you can use DigiNode Setup.\\n" "${INDENT}"
        printf "\\n"
        local dgb_service_warning="yes"
    fi

    # Check for .digibyte data directory

    if [ -d "$DGB_SETTINGS_LOCATION" ]; then
      find_dgb_settings_folder="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "%b ~/.digibyte settings folder located\\n" "${TICK}"
      fi
    else
        printf "%b %bERROR: ~/.digibyte settings folder not found.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b The DigiByte settings folder contains your wallet and digibyte.conf\\n" "${INDENT}"
        printf "%b in addition to the blockchain data itself. The folder was not found in\\n" "${INDENT}"
        printf "%b the expected location here: $DGB_DATA_LOCATION\\n" "${INDENT}"
        printf "\\n"
    fi

    # Check digibyte.conf file can be found

    if [ -f "$DGB_CONF_FILE" ]; then
      find_dgb_conf_file="yes"
      if [ $VERBOSE_MODE = true ]; then
          printf "%b digibyte.conf file located\\n" "${TICK}"
           # Load digibyte.conf file to get variables
          printf "  %b Importing digibyte.conf\\n" "${TICK}"
          source $DGB_CONF_FILE
          printf "\\n"
      fi
    else
        printf "%b %bERROR: digibyte.conf not found.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b The digibyte.conf contains important configuration settings for\\n" "${INDENT}"
        printf "%b your node. DigiNode Setup can help you create one.\\n" "${INDENT}"
        printf "%b The expected location is here: $DGB_CONF_FILE\\n" "${INDENT}"
        printf "\\n"
        if [ "$is_dgb_installed" = "yes" ]; then
            exit 1
        fi
    fi

    # Get maxconnections from digibyte.conf

    if [ -f "$DGB_CONF_FILE" ]; then
      maxconnections=$(cat $DGB_CONF_FILE | grep maxconnections | cut -d'=' -f 2)
      if [ "$maxconnections" = "" ]; then
        maxconnections="125"
      fi
      printf "%b DigiByte Core max connections: $maxconnections\\n" "${INFO}"
      printf "\\n"
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
      if [ "" != "$(pgrep digibyted)" ]; then
          if [ $VERBOSE_MODE = true ]; then
            printf "  %b DigiByte daemon is running\\n" "${TICK}"
            # Don't display service warning mesage if it has already been shown above
            if [ "$dgb_service_warning" = "yes" ]; then
              printf "\\n"
              printf "%b %bWARNING: digibyted is not currently running as a service%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
              printf "%b DigiNode Setup can help you to setup digibyted to run as a service.\\n" "${INDENT}"
              printf "%b This ensures that your DigiByte Node starts automatically at boot and\\n" "${INDENT}"
              printf "%b will restart automatically if it crashes for some reason. This is the preferred\\n" "${INDENT}"
              printf "%b way to run a DigiByte Node and helps to ensure it is kept running 24/7.\\n" "${INDENT}"
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
          printf "%b %bERROR: DigiByte daemon is not running.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
          printf "%b DigiNode Status Monitor cannot start as your DigiByte Node is not currently running.\\n" "${INDENT}"
          printf "%b Please start digibyted and then relaunch the status monitor.\\n" "${INDENT}"
          printf "%b DigiNode Setup can help you to setup DigiByte daemon to run as a service\\n" "${INDENT}"
          printf "%b so that it launches automatically at boot.\\n" "${INDENT}"
          printf "\\n"
          exit 1
        fi
      fi
    fi

    # Tell user to reboot if the RPC username or password in digibyte.conf have recently been changed
    if [ "$DGB_STATUS" = "running" ]; then
        IS_RPC_CREDENTIALS_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Incorrect rpcuser or rpcpassword")
        if [ "$IS_RPC_CREDENTIALS_CHANGED" = "Incorrect rpcuser or rpcpassword" ]; then
            printf "\\n"
            printf "%b %bThe RPC credentials have been changed. You need to run DigiNode Setup and choose 'Update' from the menu to update your settings.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b To do this now enter: diginode-setup\\n" "${INDENT}"
            printf "\\n"
            exit
        fi
        IS_RPC_PORT_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Could not connect to the server")
        if [ "$IS_RPC_PORT_CHANGED" = "Could not connect to the server" ]; then
            printf "\\n"
            printf "%b %bThe RPC port has been changed. You need to run DigiNode Setup and choose 'Update' from the menu to update your settings.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b To do this now enter: diginode-setup\\n" "${INDENT}"
            printf "\\n"
            exit
        fi
    fi

    # Display message if the DigiByte Node is running okay

    if [ "$find_dgb_folder" = "yes" ] && [ "$find_dgb_binaries" = "yes" ] && [ "$find_dgb_settings_folder" = "yes" ] && [ "$find_dgb_conf_file" = "yes" ] && [ "$DGB_STATUS" = "running" ]; then
        printf "%b %bDigiByte Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    fi

    if [ "$is_dgb_installed" = "no" ]; then
        printf "%b %bDigiByte Node Status: NOT DETECTED%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        DGB_STATUS="not_detected"
    fi

    printf "\\n"

}


# Check if this DigiNode was setup using the official install script
# (Looks for a hidden file in the 'digibyte' install directory - .officialdiginode)
digiasset_check_official() {

    printf " =============== Checking: DigiAsset Node ===============================\\n\\n"
    # ===============================================================================

    if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        printf "%b Checking for DigiNode Tools Install of DigiAsset Node: %bDETECTED%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        is_dga_installed="yes"
    elif [ -d "$DGA_INSTALL_LOCATION" ]; then
        printf "%b Checking for DigiNode Tools Install of DigiAsset Node: %bNOT DETECTED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b DigiNode Setup was not used to install this DigiAsset Node.\\n" "${INFO}"
        printf "%b This script will attempt to detect your setup but may require you to make\\n" "${INDENT}"
        printf "%b manual changes to make it work. It is possible things may break.\\n" "${INDENT}"
        printf "%b For best results use DigiNode Setup.\\n" "${INDENT}"
        printf "\\n"
        is_dga_installed="maybe"
    else
        printf "%b Checking for DigiAsset Node: %bNOT INSTALLED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b A DigiAsset Node does not appear to be installed.\\n" "${INFO}"
        printf "%b You can install it using DigiNode Setup.\\n" "${INDENT}"
        printf "\\n"
        is_dga_installed="no"
    fi
}



# Check if the DigAssets Node is installed and running
is_dganode_installed() {

    # Begin check to see that DigiAsset Node is installed
    printf "%b Looking for DigiAsset Node...\\n" "${INFO}"
    printf "\\n"

    ###############################################################
    # Perform initial checks for required DigiAsset Node packages #
    ###############################################################

    # Check if nodejs is installed
    REQUIRED_PKG="nodejs"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
        printf "%b NodeJS is NOT installed\\n" "${CROSS}"
        nodejs_installed="no"
        STARTWAIT="yes"
    else
        printf "%b NodeJS is installed\\n" "${TICK}"
        DGA_STATUS="nodejsinstalled"
        nodejs_installed="yes"
    fi

    # Let's check if Kubo is already installed
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)
    if [ "$IPFS_VER_LOCAL" = "" ]; then
        ipfs_installed="no"
        STARTWAIT="yes"
    else
        if [ "$DGA_STATUS" = "nodejsinstalled" ]; then
            DGA_STATUS="ipfsinstalled"
        fi
        ipfs_installed="yes"
      fi

      # Display if DigiAsset Node packages are installed

      if [ "$nodejs_installed" = "yes" ]; then 
        printf "%b DigiAsset Node packages are installed: ${TICK} Kubo ${TICK} NodeJS\\n" "${TICK}"
      else
        printf "%b DigiAsset Node packages are NOT installed:" "${CROSS}"
        if [ $ipfs_installed = "yes" ]; then
          printf "${TICK} Kubo"
        else
          printf "${CROSS} Kubo"
        fi
        if [ $nodejs_installed = "yes" ]; then
          printf "${TICK} NodeJS"
        else
          printf "${CROSS} NodeJS"
        fi
          printf "\\n"
          printf "%b Some packages required to run the DigiAsset Node are not currently installed.\\n" "${INFO}"
          printf "%b You can install them using DigiNode Setup.\\n" "${INDENT}"
          printf "\\n"
          STARTWAIT="yes"
          DGA_STATUS="not_detected"
        fi

      # Check if ipfs service is running. Required for DigiAssets server.

      # ps aux | grep ipfs

      if [ "" = "$(pgrep ipfs)" ]; then
          printf "%b Kubo IPFS daemon is NOT running\\n" "${CROSS}"
          ipfs_running="no"
          DGA_STATUS="not_detected"
      else
          printf "%b Kubo IPFS daemon is running\\n" "${TICK}"
          if [ "$DGA_STATUS" = "ipfsinstalled" ]; then
            DGA_STATUS="ipfsrunning"
          fi
          ipfs_running="yes"
      fi

        # Check to see if the DigiAsset Node is running, even if IPFS isn't running or installed (this means it is likely using js-IPFS)
        if [ "$ipfs_running" = "no" ] || [ "$DGA_STATUS" = "not_detected" ]; then

            DGA_CONSOLE_QUERY=$(curl localhost:8090/api/status/console.json 2>/dev/null)
            if [ "$DGA_CONSOLE_QUERY" != "" ]; then
                ipfs_running="yes"
                DGA_STATUS="ipfsrunning"
                printf "%b js-IPFS is likely being used\\n" "${TICK}"
            fi
        fi


      # Check for 'digiasset_node' index.js file

      if [ -f "$DGA_INSTALL_LOCATION/index.js" ]; then
        if [ "$DGA_STATUS" = "ipfsrunning" ]; then
           DGA_STATUS="installed" 
        fi
        printf "%b DigiAsset Node software is installed.\\n" "${TICK}"
        printf "\\n"
      else
          printf "%b DigiAsset Node software cannot be found.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
          printf "\\n"
          printf "%b DigiAsset Node software does not appear to be installed.\\n" "${INFO}"
          printf "%b You can install it using DigiNode Setup.\\n" "${INDENT}"
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
              IS_DGANODE_RUNNING="yes"
              printf "%b %bDigiAsset Node Status: RUNNING%b [ Using 'node index.js' ]\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
                  STARTWAIT="yes"
                  printf "%b %bDigiAsset Node Status: NOT RUNNING%b [ PM2 service does not exist ]\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
              elif [ "$IS_PM2_RUNNING" = "0" ]; then
                  DGA_STATUS="stopped"
                  IS_PM2_RUNNING="NO"
                  STARTWAIT="yes"
                  printf "%b %bDigiAsset Node Status: NOT RUNNING%b [ PM2 is stopped ]\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
              else
                  DGA_STATUS="running"
                  IS_PM2_RUNNING="yes"
                  printf "%b %bDigiAsset Node Status: RUNNING%b [ PM2 is running ]\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
              fi    
          fi
      elif [ "$DGA_STATUS" = "not_detected" ]; then
          printf "%b %bDigiAsset Node Status: NOT DETECTED%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
      elif [ "$DGA_STATUS" != "" ]; then
          printf "%b %bDigiAsset Node Status: NOT RUNNING%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
      fi

      printf "\\n"

}

# Get RPC CREDENTIALS from digibyte.conf
get_dgb_rpc_credentials() {
    if [ -f "$DGB_CONF_FILE" ]; then

      RPC_USER=$(cat $DGB_CONF_FILE | grep rpcuser= | cut -d'=' -f 2)
      RPC_PASS=$(cat $DGB_CONF_FILE | grep rpcpassword= | cut -d'=' -f 2)
      RPC_PORT=$(cat $DGB_CONF_FILE | grep rpcport= | cut -d'=' -f 2)
      if [ "$RPC_USER" != "" ] && [ "$RPC_PASS" != "" ] && [ "$RPC_PORT" != "" ]; then
        RPC_CREDENTIALS_OK="yes"
        printf "%b DigiByte RPC credentials found:  ${TICK} Username ${TICK} Password ${TICK} Port\\n\\n" "${TICK}"
      else
        RPC_CREDENTIALS_OK="NO"
        printf "%b %bERROR: DigiByte RPC credentials are missing:%b" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        if [ "$RPC_USER" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Username     "
        if [ "$RPC_PASS" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Password     "
        if [ "$RPC_PORT" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Port\\n"
        printf "\\n"

        # Exit if there a missing RPC credentials and the DigiAsset Node is running
        if [ "$DGA_STATUS" = "running" ]; then
            printf "%b You need to add the missing DigiByte Core RPC credentials to your digibyte.conf file.\\n" "${INFO}"
            printf "%b Without them your DigiAsset Node is unable to communicate with your DigiByte Node.\\n" "${INDENT}"
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
    fi
}

# Query the DigiAsset Node console for the current status
update_dga_console() {

if [ "$DGA_STATUS" = "running" ]; then

    DGA_CONSOLE_QUERY=$(curl localhost:8090/api/status/console.json 2>/dev/null)

    if [ "$DGA_CONSOLE_QUERY" != "" ]; then

        DGA_CONSOLE_IPFS=$(echo "$DGA_CONSOLE_QUERY" | jq | grep IPFS: | cut -d'm' -f 2 | cut -d'\' -f 1)
        DGA_CONSOLE_WALLET=$(echo "$DGA_CONSOLE_QUERY" | jq | grep Wallet: | cut -d'm' -f 2 | cut -d'\' -f 1)
        DGA_CONSOLE_STREAM=$(echo "$DGA_CONSOLE_QUERY" | jq | grep Stream: | cut -d'm' -f 3 | cut -d'\' -f 1)
        DGA_CONSOLE_SECURITY=$(echo "$DGA_CONSOLE_QUERY" | jq | grep Security: | cut -d'm' -f 2 | cut -d'\' -f 1)

        IPFS_PORT_NUMBER=$(echo $DGA_CONSOLE_IPFS | sed 's/[^0-9]//g')

    fi

fi    

}

# Format the DigiAsset Node console data
format_dga_console() {

# Format Stream
if [ "$DGA_CONSOLE_STREAM" = "Connected" ]; then
    DGA_CONSOLE_STREAM="[✓] Stream"
else
    DGA_CONSOLE_STREAM="[✗] Stream"
fi

# Format Security
if [ "$DGA_CONSOLE_SECURITY" = "Connected" ]; then
    DGA_CONSOLE_SECURITY="[✓] Password"
else
    DGA_CONSOLE_SECURITY="[✗] Password"
fi

# Format Wallet
if [ "$DGA_CONSOLE_WALLET" = "Connected" ]; then
    DGA_CONSOLE_WALLET="[✓] Wallet"
else
    DGA_CONSOLE_WALLET="[✗] Wallet"
fi

printf "  ║ DIGIASSET NODE ║  " && printf "%-49s %-1s\n" "IPFS: $DGA_CONSOLE_IPFS" "║"
printf "  ║                ║  " && printf "%-55s %-1s\n" "$DGA_CONSOLE_WALLET   $DGA_CONSOLE_STREAM   $DGA_CONSOLE_SECURITY" "║"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"

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

    printf " =============== Checking: Dependencies =================================\\n\\n"
    # ===============================================================================

    # Begin check to see that DigiByte Core is installed
    printf "%b Checking for missing packages...\\n" "${INFO}"

    REQUIRED_PKG="avahi-daemon"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
      printf "%b %bavahi-daemon is not currently installed.%b\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
      printf "\\n"
      printf "%b Installing avahi-daemon is recommended if you are using a dedicated\\n" "${INFO}"
      printf "%b device to run your DigiNode such as a Raspberry Pi. It means\\n" "${INDENT}"
      printf "%b you can you can access it at the address ${HOSTNAME}.local\\n" "${INDENT}"
      printf "%b instead of having to remember the IP address. DigiNode Setup\\n" "${INDENT}"
      printf "%b can set this up for for you.\\n" "${INDENT}"
      printf "\\n"
    else
      printf "%b avahi-daemon is installed. DigiNode URL: http://${HOSTNAME}.local:8090\\n"  "${TICK}"
      IS_AVAHI_INSTALLED="yes"
    fi
}

##  Check if jq package is installed
is_jq_installed() {
    REQUIRED_PKG="jq"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
      printf "%b jq is NOT installed.\\n"  "${CROSS}"
      printf "\\n"
      printf "%b jq is a required package and will be installed. It is required for this\\n"  "${INFO}"
      printf "%b script to be able to retrieve data from the DigiAsset Node.\\n"  "${INDENT}"
      install_jq="yes"
      printf "\\n"
    else
      printf "%b jq is installed.\\n"  "${TICK}"
    fi
    printf "\\n"
}


# Check if digibyte core wallet is enabled
is_wallet_enabled() {

if [ "$DGB_STATUS" = "running" ]; then

    printf " =============== Checking: DigiByte Wallet ==============================\\n\\n"
    # ===============================================================================

    if [ -f "$DGB_CONF_FILE" ]; then
      WALLET_STATUS=$(cat $DGB_CONF_FILE | grep disablewallet | cut -d'=' -f 2)
      if [ "$WALLET_STATUS" = "1" ]; then
        WALLET_STATUS="disabled"
        printf "%b %bDigiByte Wallet Status: DISABLED%b\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        if [ "$DGA_STATUS" = "running" ]; then
            printf "\\n"
            printf "%b The DigiByte Core wallet is required if you want to create DigiAssets\\n" "${INFO}"
            printf "%b from within the web UI. You can enable it by editing the digibyte.conf\\n" "${INDENT}"
            printf "%b file and removing the disablewallet=1 flag.\\n" "${INDENT}"
        fi
        STARTWAIT="yes"
      else
        WALLET_STATUS="enabled"
        printf "%b %bDigiByte Wallet Status: ENABLED%b\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      fi
      printf "\\n"
    fi
fi

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

    tput sgr0
    tput rmcup

    #Set this so the backup reminder works
    NewInstall=False

    # On quit, if there are updates available, ask the user if they want to install them
    if [ "$DGB_UPDATE_AVAILABLE" = "yes" ] || [ "$DGA_UPDATE_AVAILABLE" = "yes" ] || [ "$DGNT_UPDATE_AVAILABLE" = "yes" ] || [ "$IPFS_UPDATE_AVAILABLE" = "yes" ]; then

      # Install updates now

      printf "\\n"

      # Choose a random DigiFact
      digifact_randomize

      # Display a random DigiFact
      digifact_display

      printf "  %b %bThere are software updates available for your DigiNode.%b\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      printf "\\n"
      read -n 1 -r -s -p "         Would you like to install them now? (Y/N)"
      printf "\\n"

      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        printf "%b Installing updates...\\n" "${INFO}"
        echo ""
        exec curl -sSL diginode-setup.digibyte.help | bash -s -- --unattended --statusmonitor
        updates_installed="yes"
        exit
      else
        updates_installed="no"
      fi
      printf "\\n"

      if [ "$DONATION_PLEA" = "YES" ] && [ "$updates_installed" = "no" ]; then

        #Display donation QR code
        donation_qrcode

        # Don't show the donation plea again for at least 15 minutes
        DONATION_PLEA="WAIT15"
        sed -i -e "/^DONATION_PLEA=/s|.*|DONATION_PLEA=$DONATION_PLEA|" $DGNT_SETTINGS_FILE
      fi

      #Share backup reminder
      backup_reminder

      # Display reminder that you can manually specify the location of the DigiByte install folder
      exit_locate_digibyte_reminder


  # if there are no updates available display the donation QR code (not more than once every 15 minutes)
  elif [ "$DONATION_PLEA" = "YES" ]; then
      printf "\\n"

      #Display donation QR code
      donation_qrcode

      #Share backup reminder
      backup_reminder

      # Display reminder that you can manually specify the location of the DigiByte install folder
      exit_locate_digibyte_reminder

      printf "\\n"
      # Don't show the donation plea again for at least 15 minutes
      DONATION_PLEA="WAIT15"
      sed -i -e "/^DONATION_PLEA=/s|.*|DONATION_PLEA=$DONATION_PLEA|" $DGNT_SETTINGS_FILE
  else

      # Choose a random DigiFact
      digifact_randomize

      # Display a random DigiFact
      digifact_display

      printf "\\n"

      #Share backup reminder
      backup_reminder

      # Display reminder that you can manually specify the location of the DigiByte install folder
      exit_locate_digibyte_reminder
  fi

  # Display cursor again
  tput cnorm
}

exit_locate_digibyte_reminder() {

if [ "$DGB_STATUS" = "not_detected" ]; then # Only display if digibyted is NOT running
    printf "  %b %bNote: A DigiByte Node could not be detected. %b\\n"  "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b If your system is already running a DigiByte Node you can use the --locatedgb flag\n" "${INDENT}"
    printf "%b when launching the Status Monitor to manually enter the location of the install folder.\n" "${INDENT}"
    printf "\\n"
    printf "%b To do this enter: ${txtbld}diginode --locatedgb${txtrst}\n" "${INDENT}"
    printf "\\n"          
fi


}

startup_waitpause() {

# Optionally require a key press to continue, or a long 5 second pause. Otherwise wait 3 seconds before starting monitoring. 

echo ""
if [ "$STARTPAUSE" = "yes" ]; then
  read -n 1 -s -r -p "      < Press any key to continue >"
else

  if [ "$STARTWAIT" = "yes" ]; then
    echo "               < Wait for 5 seconds >"
    sleep 5
  else 
    echo "               < Wait for 3 seconds >"
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
        sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $DGNT_SETTINGS_FILE
    fi
    printf "  %b%b %s Done!\\n" "  ${OVER}" "${TICK}" "${str}"


    # update internal IP address and save to settings file
    str="Looking up internal IP address..."
    printf "  %b %s" "${INFO}" "${str}"
    IP4_INTERNAL_QUERY=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
    if [ $IP4_INTERNAL_QUERY != "" ]; then
        IP4_INTERNAL=$IP4_INTERNAL_QUERY
        sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"$IP4_INTERNAL\"|" $DGNT_SETTINGS_FILE
    fi
    printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    str="Setting up Status Monitor timers..."
    printf "  %b %s" "${INFO}" "${str}"
    # set 15 sec timer and save to settings file
    SAVED_TIME_15SEC="$(date +%s)"
    sed -i -e "/^SAVED_TIME_15SEC=/s|.*|SAVED_TIME_15SEC=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE

    # set 1 min timer and save to settings file
    SAVED_TIME_1MIN="$(date +%s)"
    sed -i -e "/^SAVED_TIME_1MIN=/s|.*|SAVED_TIME_1MIN=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE

    # set 15 min timer and save to settings file
    SAVED_TIME_15MIN="$(date +%s)"
    sed -i -e "/^SAVED_TIME_15MIN=/s|.*|SAVED_TIME_15MIN=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE

    # set daily timer and save to settings file
    SAVED_TIME_1DAY="$(date +%s)"
    sed -i -e "/^SAVED_TIME_1DAY=/s|.*|SAVED_TIME_1DAY=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE

    # set weekly timer and save to settings file
    SAVED_TIME_1WEEK="$(date +%s)"
    sed -i -e "/^SAVED_TIME_1WEEK=/s|.*|SAVED_TIME_1WEEK=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
    printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"


    # check for current version number of DigiByte Core and save to settings file
    str="Looking up DigiByte Core version number..."
    printf "  %b %s" "${INFO}" "${str}"
    DGB_VER_LOCAL_QUERY=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
    if [ "$DGB_VER_LOCAL_QUERY" != "" ]; then
        DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
        sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "  %b%b %s Found: DigiByte Core v${DGB_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    else
        if [ $DGB_STATUS != "not_detected" ]; then
            DGB_STATUS="startingup"
            printf "  %b%b %s ERROR: DigiByte daemon is still starting up.\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi

    # Log date of Status Monitor first run to diginode.settings
    str="Logging date of first run to diginode.settings file..."
    printf "  %b %s" "${INFO}" "${str}"
    DGNT_MONITOR_FIRST_RUN=$(date)
    sed -i -e "/^DGNT_MONITOR_FIRST_RUN=/s|.*|DGNT_MONITOR_FIRST_RUN=\"$DGNT_MONITOR_FIRST_RUN\"|" $DGNT_SETTINGS_FILE
    printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # When the user quits, enable showing a donation plea
    DONATION_PLEA="YES"
    sed -i -e "/^DONATION_PLEA=/s|.*|DONATION_PLEA=$DONATION_PLEA|" $DGNT_SETTINGS_FILE

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
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=\"$DGA_VER_MNR_LOCAL\"|" $DGNT_SETTINGS_FILE
          printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL} beta\\n" "${OVER}" "${INFO}" "${str}"
      elif [ "$DGA_VER_MNR_LOCAL_QUERY" != "" ]; then
          DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL_QUERY
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=\"$DGA_VER_MNR_LOCAL\"|" $DGNT_SETTINGS_FILE
          printf "%b%b %s DigiAsset Node v${DGA_VER_MNR_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
      else
          DGA_VER_MNR_LOCAL=""
          str="Current Version:"
          printf "%b %s" "${INFO}" "${str}"
          printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
      fi

      # Now we can update the main DGA_VER_LOCAL variable with the current version (major or minor depending on what was found)
      if [ "$DGA_VER_MNR_LOCAL" = "beta" ]; then
          DGA_VER_LOCAL="$DGA_VER_MJR_LOCAL beta"  # e.g. DigiAsset Node v3 beta
      elif [ "$DGA_VER_MNR_LOCAL" = "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MJR_LOCAL"       # e.g. DigiAsset Node v3
      elif [ "$DGA_VER_MNR_LOCAL" != "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MNR_LOCAL"       # e.g. DigiAsset Node v3.2
      fi

      str="Storing DigiAsset Node variables in settings file..."
      printf "%b %s" "${INFO}" "${str}"
      sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=\"$DGA_VER_LOCAL\"|" $DGNT_SETTINGS_FILE

      IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)
      sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE

      # Get the local version number of NodeJS (this will also tell us if it is installed)
      NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')
      # Later versions use purely the 'node --version' command, (rather than nodejs)
      if [ "$NODEJS_VER_LOCAL" = "" ]; then
          NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
      fi
      sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE

      DGA_FIRST_RUN=$(date)
      sed -i -e "/^DGA_FIRST_RUN=/s|.*|DGA_FIRST_RUN=\"$DGA_FIRST_RUN\"|" $DGNT_SETTINGS_FILE
      printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

  fi

}


pre_loop() {

      # Setup loopcounter - used for debugging
      loopcounter=0

      # Set timenow variable with the current time
      TIME_NOW=$(date)
      TIME_NOW_UNIX=$(date +%s)

      # Log date of this Status Monitor run to diginode.settings
      str="Logging date of this run to diginode.settings file..."
      printf "%b %s" "${INFO}" "${str}"
      sed -i -e "/^DGNT_MONITOR_LAST_RUN=/s|.*|DGNT_MONITOR_LAST_RUN=\"$(date)\"|" $DGNT_SETTINGS_FILE
      printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

      # Is DigiByte daemon starting up?
      if [ "$DGB_STATUS" = "running" ]; then
        BLOCKCOUNT_LOCAL_QUERY=$($DGB_CLI getblockcount 2>/dev/null)
        if [ "$BLOCKCOUNT_LOCAL_QUERY" = "" ]; then
          DGB_STATUS="startingup"
        else
          BLOCKCOUNT_LOCAL=$BLOCKCOUNT_LOCAL_QUERY
          BLOCKCOUNT_FORMATTED=$(printf "%'d" $BLOCKCOUNT_LOCAL)

          # Query current version number of DigiByte Core
          DGB_VER_LOCAL_QUERY=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
          if [ "$DGB_VER_LOCAL_QUERY" != "" ]; then
            DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
            sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
          fi

        fi
      fi

      # Check if digibyted is successfully responding to requests yet while starting up. If not, get the current error.
      if [ "$DGB_STATUS" = "startingup" ]; then
          
          # Query if digibyte has finished starting up. Display error. Send success to null.
          is_dgb_live_query=$($DGB_CLI uptime 2>&1 1>/dev/null)
          if [ "$is_dgb_live_query" != "" ]; then
              DGB_ERROR_MSG=$(echo $is_dgb_live_query | cut -d ':' -f3)
          else
              DGB_STATUS="running"
          fi

      fi


      ##### CHECK FOR UPDATES BY COMPARING VERSION NUMBERS #######

      # If there is actually a local version of DigiByte Core, check for an update
      if [ "$DGB_VER_LOCAL" != "" ]; then
          if [ $(version $DGB_VER_LOCAL) -ge $(version $DGB_VER_RELEASE) ]; then
            DGB_UPDATE_AVAILABLE="no"
          else
            DGB_UPDATE_AVAILABLE="yes"
          fi
      fi

      # Check if there is an update for DigiNode Tools
      if [ $(version $DGNT_VER_LOCAL) -ge $(version $DGNT_VER_RELEASE) ]; then
        DGNT_UPDATE_AVAILABLE="no"
      else
        DGNT_UPDATE_AVAILABLE="yes"
      fi

      # If there is actually a local version of NodeJS, check for an update
      if [ "$NODEJS_VER_LOCAL" != "" ]; then
          # Check if there is an update for NodeJS
          if [ $(version $NODEJS_VER_LOCAL) -ge $(version $NODEJS_VER_RELEASE) ]; then
            NODEJS_UPDATE_AVAILABLE="no"
          else
            NODEJS_UPDATE_AVAILABLE="yes"
          fi
      fi

      # If there is actually a local version of Kubo, check for an update
      if [ "$IPFS_VER_LOCAL" != "" ]; then
          # Check if there is an update for NodeJS
          if [ $(version $IPFS_VER_LOCAL) -ge $(version $IPFS_VER_RELEASE) ]; then
            IPFS_UPDATE_AVAILABLE="no"
          else
            IPFS_UPDATE_AVAILABLE="yes"
          fi
      fi

      if [ "$DGA_VER_MJR_LOCAL" != "" ]; then

          # Check if there is an update for DigiAsset Node
          if [ $(version $DGA_VER_MJR_LOCAL) -ge $(version $DGA_VER_MJR_RELEASE) ]; then
            DGA_UPDATE_AVAILABLE="no"
          else
            DGA_UPDATE_AVAILABLE="yes"
          fi
      fi

      # If SM_DISPLAY_VALUE is to to neither YES or NO, update diginode.settings
    if [ "$SM_DISPLAY_BALANCE" != "YES" ] && [ "$SM_DISPLAY_BALANCE" != "NO" ]; then
          # Log date of this Status Monitor run to diginode.settings
          str="No value detected for displaying DigiByte wallet balance. Setting to YES..."
          printf "%b %s" "${INFO}" "${str}"
          SM_DISPLAY_BALANCE=YES
          sed -i -e "/^SM_DISPLAY_BALANCE=/s|.*|SM_DISPLAY_BALANCE=YES|" $DGNT_SETTINGS_FILE
          printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$WALLET_STATUS" = "enabled" ]; then
        # Lookup current wallet balance
        WALLET_BALANCE=$(digibyte-cli getbalance 2>/dev/null)
        # If the wallet balance is 0, then set the value to "" so it is hidden
        if [ "$WALLET_BALANCE" = "0.00000000" ]; then
            WALLET_BALANCE=""
        fi
    fi

    # Query the DigiAsset Node console
    update_dga_console

    # Choose a random DigiFact
    digifact_randomize


    # Enable the DigiByte Core port test if it seems it has never run before
    if [ "$DGB_PORT_TEST_ENABLED" != "YES" ] && [ "$DGB_PORT_TEST_ENABLED" != "NO" ]; then

        printf "\\n"
        printf "%b Enabling DigiByte Core Port Test...\n" "${INFO}"
        printf "\\n"

        DGB_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_PORT_TEST_ENABLED=/s|.*|DGB_PORT_TEST_ENABLED=\"$DGB_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
    fi

    # Enable the IPFS port test if it seems it has never run before
    if [ "$IPFS_PORT_TEST_ENABLED" != "YES" ] && [ "$IPFS_PORT_TEST_ENABLED" != "NO" ]; then

        printf "\\n"
        printf "%b Enabling IPFS Port Test...\n" "${INFO}"
        printf "\\n"

        IPFS_PORT_TEST_ENABLED="YES"
        sed -i -e "/^IPFS_PORT_TEST_ENABLED=/s|.*|IPFS_PORT_TEST_ENABLED=\"$IPFS_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
    fi

    # If the DigiByte Core port test is disabled, check if the external IP address has changed
    if [ "$DGB_PORT_TEST_ENABLED" = "NO" ]; then

        # If the External IP address has changed since the last port test was run, reset and re-enable the port test
        if [ "$DGB_PORT_TEST_EXTERNAL_IP" != "$IP4_EXTERNAL" ]; then

            printf "\\n"
            printf "%b External IP address has changed. Re-enabling DigiByte Core Port Test...\n" "${INFO}"
            printf "\\n"

            DGB_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_PORT_TEST_ENABLED=/s|.*|DGB_PORT_TEST_ENABLED=\"$DGB_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_PORT_FWD_STATUS=""
            sed -i -e "/^DGB_PORT_FWD_STATUS=/s|.*|DGB_PORT_FWD_STATUS=\"$DGB_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_PORT_TEST_PASS_DATE=""
            sed -i -e "/^DGB_PORT_TEST_PASS_DATE=/s|.*|DGB_PORT_TEST_PASS_DATE=\"$DGB_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_PORT_TEST_EXTERNAL_IP=\"$DGB_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

        fi

    fi

    # If the IPFS port test is disabled, check if the external IP address has changed
    if [ "$IPFS_PORT_TEST_ENABLED" = "NO" ]; then

        # If the External IP address has changed since the last port test was run, reset and re-enable the port test
        if [ "$IPFS_PORT_TEST_EXTERNAL_IP" != "$IP4_EXTERNAL" ]; then

            printf "\\n"
            printf "%b External IP address has changed. Re-enabling IPFS Port Test...\n" "${INFO}"
            printf "\\n"

            IPFS_PORT_TEST_ENABLED="YES"
            sed -i -e "/^IPFS_PORT_TEST_ENABLED=/s|.*|IPFS_PORT_TEST_ENABLED=\"$IPFS_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_FWD_STATUS=""
            sed -i -e "/^IPFS_PORT_FWD_STATUS=/s|.*|IPFS_PORT_FWD_STATUS=\"$IPFS_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_PASS_DATE=""
            sed -i -e "/^IPFS_PORT_TEST_PASS_DATE=/s|.*|IPFS_PORT_TEST_PASS_DATE=\"$IPFS_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^IPFS_PORT_TEST_EXTERNAL_IP=/s|.*|IPFS_PORT_TEST_EXTERNAL_IP=\"$IPFS_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_NUMBER_SAVED=""
            sed -i -e "/^IPFS_PORT_NUMBER_SAVED=/s|.*|IPFS_PORT_NUMBER_SAVED=\"$IPFS_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        # If the current IPFS port has changed since the last port test was run, reset and re-enable the port test
        elif [ "$IPFS_PORT_NUMBER" != "$IPFS_PORT_NUMBER_SAVED" ]; then

            printf "\\n"
            printf "%b IPFS port number has changed. Re-enabling IPFS Port Test...\n" "${INFO}"
            printf "\\n"

            IPFS_PORT_TEST_ENABLED="YES"
            sed -i -e "/^IPFS_PORT_TEST_ENABLED=/s|.*|IPFS_PORT_TEST_ENABLED=\"$IPFS_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_FWD_STATUS=""
            sed -i -e "/^IPFS_PORT_FWD_STATUS=/s|.*|IPFS_PORT_FWD_STATUS=\"$IPFS_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_PASS_DATE=""
            sed -i -e "/^IPFS_PORT_TEST_PASS_DATE=/s|.*|IPFS_PORT_TEST_PASS_DATE=\"$IPFS_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^IPFS_PORT_TEST_EXTERNAL_IP=/s|.*|IPFS_PORT_TEST_EXTERNAL_IP=\"$IPFS_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_NUMBER_SAVED=""
            sed -i -e "/^IPFS_PORT_NUMBER_SAVED=/s|.*|IPFS_PORT_NUMBER_SAVED=\"$IPFS_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        fi

    fi

}



######################################################################################
############## THE LOOP STARTS HERE - ENTIRE LOOP RUNS ONCE A SECOND #################
######################################################################################

status_loop() {

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


# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - HARDWARE
# ------------------------------------------------------------------------------

# Update timenow variable with current time
TIME_NOW=$(date)
TIME_NOW_UNIX=$(date +%s)
loopcounter=$((loopcounter+1))

# Get current memory usage
RAMUSED_HR=$(free --mega -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f3)
RAMAVAIL_HR=$(free --mega -h | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f6)
SWAPUSED_HR=$(free --mega -h | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f3)

# Get current system temp
temperature=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)

# Only calculate temp if a value was returned
if [ "$temperature" != "" ]; then

  # Convert temperature to Degrees C
  TEMP_C=$((temperature/1000))

  # Convert temperature to Degrees F
  TEMP_F=$(((9/5) * $TEMP_C + 32))

fi


# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - DIGIBYTE CORE 
# ------------------------------------------------------------------------------

# Check DigiByte Node provided it is actually installed
if [ $DGB_STATUS != "not_detected" ]; then

    # Is digibyted running as a service?
    systemctl is-active --quiet digibyted && DGB_STATUS="running" || DGB_STATUS="checkagain"

    # If it is not running as a service, check if digibyted is running via the command line
    if [ "$DGB_STATUS" = "checkagain" ]; then
      if [ "" != "$(pgrep digibyted)" ]; then
        DGB_STATUS="running"
      fi
    fi

    # If digibyted is not running via the command line, check if digibyte-qt is running
    if [ "$DGB_STATUS" = "checkagain" ]; then
      if [ "" != "$(pgrep digibyte-qt)" ]; then
        DGB_STATUS="running"
      else
        DGB_STATUS="stopped"
      fi
    fi

    # If we think the blockchain is running, check the blockcount
    if [ "$DGB_STATUS" = "running" ]; then

        # If the blockchain is not yet synced, get blockcount
        if [ "$BLOCKSYNC_PROGRESS" = "" ] || [ "$BLOCKSYNC_PROGRESS" = "notsynced" ]; then
          BLOCKCOUNT_LOCAL=$($DGB_CLI getblockcount 2>/dev/null)
          BLOCKCOUNT_FORMATTED=$(printf "%'d" $BLOCKCOUNT_LOCAL)

          # If we don't get a response, assume it is starting up
          if [ "$BLOCKCOUNT_LOCAL" = "" ]; then
            DGB_STATUS="startingup"
          fi
        fi
    fi

fi


# THE REST OF THIS ONLY RUNS NOTE IF DIGIBYED IS RUNNING

if [ "$DGB_STATUS" = "running" ]; then

  # This will update the blockchain sync progress every second until it is fully synced
  if [ "$BLOCKSYNC_PROGRESS" = "notsynced" ] || [ "$BLOCKSYNC_PROGRESS" = "" ]; then

    # Lookup the sync progress value from debug.log. 
    BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
 
    # Is the returned value numerical?
    re='^[0-9]+([.][0-9]+)?$'
    if ! [[ $BLOCKSYNC_VALUE_QUERY =~ $re ]] ; then
       BLOCKSYNC_VALUE_QUERY=""
    fi

    # Only update the variable, if a new value is found
    if [ "$BLOCKSYNC_VALUE_QUERY" != "" ]; then
       BLOCKSYNC_VALUE=$BLOCKSYNC_VALUE_QUERY
       sed -i -e "/^BLOCKSYNC_VALUE=/s|.*|BLOCKSYNC_VALUE=\"$BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
    fi

    # Calculate blockchain sync percentage
    BLOCKSYNC_PERC=$(echo "scale=2 ;$BLOCKSYNC_VALUE*100"|bc)

    # Round blockchain sync percentage to two decimal places
    BLOCKSYNC_PERC=$(printf "%.2f \n" $BLOCKSYNC_PERC)

    # Detect if the blockchain is fully synced
    if [ "$BLOCKSYNC_PERC" = "100.00 " ]; then
      BLOCKSYNC_PERC="100 "
      BLOCKSYNC_PROGRESS="synced"
    fi
    

  fi

  # Get DigiByted Core Uptime
  uptime_seconds=$($DGB_CLI uptime 2>/dev/null)
  uptime=$(eval "echo $(date -ud "@$uptime_seconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")

  # Show port warning if connections are less than or equal to 7
  DGB_CONNECTIONS=$($DGB_CLI getconnectioncount 2>/dev/null)
  if [ $DGB_CONNECTIONS -le 8 ]; then
    DGB_CONNECTIONS_MSG="Warning: Low Connections!"
  fi
  if [ $DGB_CONNECTIONS -ge 9 ]; then
    DGB_CONNECTIONS_MSG="Maximum: $maxconnections"
  fi
fi 


# ------------------------------------------------------------------------------
#    Run once every 15 seconds (approx once every block).
#    Every 15 seconds lookup the latest block from the online block exlorer to calculate sync progress.
# ------------------------------------------------------------------------------

TIME_DIF_15SEC=$(($TIME_NOW_UNIX-$SAVED_TIME_15SEC))

if [ $TIME_DIF_15SEC -ge 15 ]; then 

    # Check if digibyted is successfully responding to requests up yet after starting up. If not, get the error.
    if [ "$DGB_STATUS" = "startingup" ]; then
        
        # Query if digibyte has finished starting up. Display error. Send success to null.
        is_dgb_live_query=$($DGB_CLI uptime 2>&1 1>/dev/null)
        if [ "$is_dgb_live_query" != "" ]; then
            DGB_ERROR_MSG=$(echo $is_dgb_live_query | cut -d ':' -f3)
        else
            DGB_STATUS="running"
        fi

    fi

    # Update local block count every 15 seconds (approx once per block)
    # Is digibyted in the process of starting up, and not ready to respond to requests?
    if [ "$DGB_STATUS" = "running" ] && [ "$BLOCKSYNC_PROGRESS" = "synced" ]; then
        BLOCKCOUNT_LOCAL=$($DGB_CLI getblockcount 2>/dev/null)
        BLOCKCOUNT_FORMATTED=$(printf "%'d" $BLOCKCOUNT_LOCAL)
        if [ "$BLOCKCOUNT_LOCAL" = "" ]; then
          DGB_STATUS="startingup"
        fi
    fi



    # If there is a new DigiByte Core release available, check every 15 seconds until it has been installed
    if [ $DGB_STATUS = "running" ]; then

      if [ "$DGB_VER_LOCAL_CHECK_FREQ" = "" ] || [ "$DGB_VER_LOCAL_CHECK_FREQ" = "15secs" ]; then

        # Query current version number of DigiByte Core, and write to diginode.settings
        DGB_VER_LOCAL_QUERY=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
        if [ "$DGB_VER_LOCAL_QUERY" != "" ]; then
          DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
          sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        fi

        # If DigiByte Core is up to date, switch back to checking the local version number daily
        if [ $(version $DGB_VER_LOCAL) -ge $(version $DGB_VER_RELEASE) ]; then
          DGB_VER_LOCAL_CHECK_FREQ="daily"
          sed -i -e "/^DGB_VER_LOCAL_CHECK_FREQ=/s|.*|DGB_VER_LOCAL_CHECK_FREQ=\"$DGB_VER_LOCAL_CHECK_FREQ\"|" $DGNT_SETTINGS_FILE
          DGB_UPDATE_AVAILABLE="no"
        else
          DGB_UPDATE_AVAILABLE="yes"
        fi

      fi

    fi

    # Lookup disk usage, and store in diginode.settings if present
    update_disk_usage

    # Query the DigiAsset Node console
    update_dga_console

    SAVED_TIME_15SEC="$(date +%s)"
    sed -i -e "/^SAVED_TIME_15SEC=/s|.*|SAVED_TIME_15SEC=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
fi


# ------------------------------------------------------------------------------
#    Run once every 1 minute
#    Every 15 seconds lookup the latest block from the online block exlorer to calculate sync progress.
# ------------------------------------------------------------------------------

TIME_DIF_1MIN=$(($TIME_NOW_UNIX-$SAVED_TIME_1MIN))

if [ $TIME_DIF_1MIN -ge 60 ]; then

  # Update DigiByte Core sync progress every minute, if it is running
  if [ "$DGB_STATUS" = "running" ]; then

    # Lookup sync progress value from debug.log. Use previous saved value if no value is found.
    if [ "$BLOCKSYNC_PROGRESS" = "synced" ]; then

        # Query debug.log for the blockchain syn progress
        BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
     
        # Is the returned value numerical?
        re='^[0-9]+([.][0-9]+)?$'
        if ! [[ $BLOCKSYNC_VALUE_QUERY =~ $re ]] ; then
           BLOCKSYNC_VALUE_QUERY=""
        fi

        # Ok, we got a number back. Update the variable.
        if [ "$BLOCKSYNC_VALUE_QUERY" != "" ]; then
           BLOCKSYNC_VALUE=$BLOCKSYNC_VALUE_QUERY
           sed -i -e "/^BLOCKSYNC_VALUE=/s|.*|BLOCKSYNC_VALUE=\"$BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
        fi

        # Calculate blockchain sync percentage
        BLOCKSYNC_PERC=$(echo "scale=2 ;$BLOCKSYNC_VALUE*100"|bc)

        # Round blockchain sync percentage to two decimal places
        BLOCKSYNC_PERC=$(printf "%.2f \n" $BLOCKSYNC_PERC)

        # If it's at 100.00, get rid of the decimal zeros
        if [ "$BLOCKSYNC_PERC" = "100.00 " ]; then
          BLOCKSYNC_PERC="100 "
        fi

        # Check if sync progress is not 100%
        if [ "$BLOCKSYNC_PERC" = "100 " ]; then
            BLOCKSYNC_PROGRESS="synced"
            if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$WALLET_STATUS" = "enabled" ]; then
                WALLET_BALANCE=$(digibyte-cli getbalance 2>/dev/null)
                # If the wallet balance is 0, then set the value to "" so it is hidden
                if [ "$WALLET_BALANCE" = "0.00000000" ]; then
                    WALLET_BALANCE=""
                fi
            fi
        else
           BLOCKSYNC_PROGRESS="notsynced"
           WALLET_BALANCE=""
        fi
    fi
  fi

  # Choose a random DigiFact
  digifact_randomize

  # Update local IP address if it has changed
  IP4_INTERNAL_NEW=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
  if [ $IP4_INTERNAL_NEW != $IP4_INTERNAL ]; then
    IP4_INTERNAL = $IP4_INTERNAL_NEW
    sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"IP4_INTERNAL\"|" $DGNT_SETTINGS_FILE
  fi

  # Update diginode.settings with when Status Monitor last ran
  DGNT_MONITOR_LAST_RUN=$(date)
  sed -i -e "/^DGNT_MONITOR_LAST_RUN=/s|.*|DGNT_MONITOR_LAST_RUN=\"$(date)\"|" $DGNT_SETTINGS_FILE

  SAVED_TIME_1MIN="$(date +%s)"
  sed -i -e "/^SAVED_TIME_1MIN=/s|.*|SAVED_TIME_1MIN=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE

fi


# ------------------------------------------------------------------------------
#    Run once every 15 minutes
#    Update the Internal & External IP
# ------------------------------------------------------------------------------

TIME_DIF_15MIN=$(($TIME_NOW_UNIX-$SAVED_TIME_15MIN))

if [ $TIME_DIF_15MIN -ge 300 ]; then

    # update external IP if it has changed
    IP4_EXTERNAL_NEW=$(dig @resolver4.opendns.com myip.opendns.com +short)
    if [ "$IP4_EXTERNAL_NEW" != "$IP4_EXTERNAL" ]; then
      IP4_EXTERNAL=$IP4_EXTERNAL_NEW
      sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $DGNT_SETTINGS_FILE
    fi

    # If DigiAssets server is running, lookup local version number of DigiAssets server IP
    if [ "$DGA_STATUS" = "running" ]; then

      # Next let's try and get the minor version, which may or may not be available yet
      # If DigiAsset Node is running we can get it directly from the web server

      DGA_VER_MNR_LOCAL_QUERY=$(curl localhost:8090/api/version/list.json 2>/dev/null | jq .current | sed 's/"//g')
      if [ "$DGA_VER_MNR_LOCAL_QUERY" = "NA" ]; then
          # This is a beta so the minor version doesn't exist
          DGA_VER_MNR_LOCAL="beta"
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=\"$DGA_VER_MNR_LOCAL\"|" $DGNT_SETTINGS_FILE
      elif [ "$DGA_VER_MNR_LOCAL_QUERY" != "" ]; then
          DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL_QUERY
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=\"$DGA_VER_MNR_LOCAL\"|" $DGNT_SETTINGS_FILE
      else
          DGA_VER_MNR_LOCAL=""
          sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=|" $DGNT_SETTINGS_FILE
      fi

      # Now we can update the main DGA_VER_LOCAL variable with the current version (major or minor depending on what was found)
      if [ "$DGA_VER_MNR_LOCAL" = "beta" ]; then
          DGA_VER_LOCAL="$DGA_VER_MJR_LOCAL beta"  # e.g. DigiAsset Node v3 beta
          sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=\"$DGA_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
      elif [ "$DGA_VER_MNR_LOCAL" = "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MJR_LOCAL"       # e.g. DigiAsset Node v3
          sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=\"$DGA_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
      elif [ "$DGA_VER_MNR_LOCAL" != "" ]; then
          DGA_VER_LOCAL="$DGA_VER_MNR_LOCAL"       # e.g. DigiAsset Node v3.2
          sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=\"$DGA_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
      fi

      # Get the local version number of NodeJS (this will also tell us if it is installed)
      NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')
      # Later versions use purely the 'node --version' command, (rather than nodejs)
      if [ "$NODEJS_VER_LOCAL" = "" ]; then
          NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
      fi
      sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE


      IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)
      sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    fi


    # Lookup DigiNode Tools local version and branch, if any
    if [[ -f "$DGNT_MONITOR_SCRIPT" ]]; then
        dgnt_ver_local_query=$(cat $DGNT_MONITOR_SCRIPT | grep -m1 DGNT_VER_LOCAL  | cut -d'=' -f2)
        dgnt_branch_local_query=$(git -C $DGNT_LOCATION rev-parse --abbrev-ref HEAD 2>/dev/null)
    fi

    # If we get a valid version number, update the stored local version
    if [ "$dgnt_ver_local_query" != "" ]; then
        DGNT_VER_LOCAL=$dgnt_ver_local_query
        sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=\"$DGNT_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    fi

    # If we get a valid local branch, update the stored local branch
    if [ "$dgnt_branch_local_query" != "" ]; then
        # If it returns head, set it to release
        if [ "$dgnt_branch_local_query" = "HEAD" ]; then
            dgnt_branch_local_query="release"
        fi
        DGNT_BRANCH_LOCAL=$dgnt_branch_local_query
        sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"$DGNT_BRANCH_LOCAL\"|" $DGNT_SETTINGS_FILE
    fi

    # Update DigiNode Tools display variable
    if [ "$DGNT_BRANCH_LOCAL" = "release" ]; then
        DGNT_VER_LOCAL_DISPLAY="v${DGNT_VER_LOCAL}"
        sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=\"$DGNT_VER_LOCAL_DISPLAY\"|" $DGNT_SETTINGS_FILE
    elif [ "$DGNT_BRANCH_LOCAL" = "develop" ]; then
        DGNT_VER_LOCAL_DISPLAY="dev-branch"
        sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=\"$DGNT_VER_LOCAL_DISPLAY\"|" $DGNT_SETTINGS_FILE
    elif [ "$DGNT_BRANCH_LOCAL" = "main" ]; then
        DGNT_VER_LOCAL_DISPLAY="main-branch"
        sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=\"$DGNT_VER_LOCAL_DISPLAY\"|" $DGNT_SETTINGS_FILE
    fi

    # When the user quits, enable showing a donation plea (this ensures it is not shown more than once every 15 mins)
    DONATION_PLEA=YES
    sed -i -e "/^DONATION_PLEA=/s|.*|DONATION_PLEA=$DONATION_PLEA|" $DGNT_SETTINGS_FILE

    SAVED_TIME_15MIN="$(date +%s)"
    sed -i -e "/^SAVED_TIME_15MIN=/s|.*|SAVED_TIME_15MIN=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
fi


# ------------------------------------------------------------------------------
#    Run once every 24 hours
#    Check for new version of DigiByte Core
# ------------------------------------------------------------------------------

TIME_DIF_1DAY=$(($TIME_NOW_UNIX-$SAVED_TIME_1DAY))

if [ $TIME_DIF_1DAY -ge 86400 ]; then 

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
      sed -i -e "/^DGB_VER_RELEASE=/s|.*|DGB_VER_RELEASE=\"$DGB_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # If there is a new DigiByte Core release available, check every 15 seconds until it has been installed
    if [ "$DGB_STATUS" = "running" ] && [ "$DGB_VER_LOCAL_CHECK_FREQ" = "daily" ]; then

        # Get current software version, and write to diginode.settings
        DGB_VER_LOCAL=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
        sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE

        # Compare current DigiByte Core version with Github version to know if there is a new version available
        if [ $(version $DGB_VER_LOCAL) -ge $(version $DGB_VER_RELEASE) ]; then
          DGB_UPDATE_AVAILABLE="no"
        else
          DGB_VER_LOCAL_CHECK_FREQ="15secs"
          sed -i -e "/^DGB_VER_LOCAL_CHECK_FREQ=/s|.*|DGB_VER_LOCAL_CHECK_FREQ=\"$DGB_VER_LOCAL_CHECK_FREQ\"|" $DGNT_SETTINGS_FILE
          DGB_UPDATE_AVAILABLE="yes"
        fi
    fi

    # Check for new release of DigiNode Tools on Github
    dgnt_ver_release_query=$(curl -sfL https://api.github.com/repos/saltedlolly/diginode/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')
      if [ "$dgnt_ver_release_query" != "" ]; then
        DGNT_VER_RELEASE=$dgnt_ver_release_query
        sed -i -e "/^DGNT_VER_RELEASE=/s|.*|DGNT_VER_RELEASE=\"$DGNT_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
        # Check if there is an update for DigiNode Tools
        if [ $(version $DGNT_VER_LOCAL) -ge $(version $DGNT_VER_RELEASE) ]; then
          DGNT_UPDATE_AVAILABLE="no"
        else
          DGNT_UPDATE_AVAILABLE="yes"
        fi
    fi

    # Check for the latest release of NodeJS
    NODEJS_VER_RELEASE_QUERY=$(apt-cache policy nodejs | grep Candidate | cut -d' ' -f4 | cut -d'-' -f1)
    if [ "$NODEJS_VER_RELEASE_QUERY" != "" ]; then
      NODEJS_VER_RELEASE=$NODEJS_VER_RELEASE_QUERY
      sed -i -e "/^NODEJS_VER_RELEASE=/s|.*|NODEJS_VER_RELEASE=\"$NODEJS_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # If there is actually a local version of NodeJS, check for an update
    if [ "$NODEJS_VER_LOCAL" != "" ]; then
        # Check if there is an update for NodeJS
        if [ $(version $NODEJS_VER_LOCAL) -ge $(version $NODEJS_VER_RELEASE) ]; then
          NODEJS_UPDATE_AVAILABLE="no"
        else
          NODEJS_UPDATE_AVAILABLE="yes"
        fi
    fi


    # Check for new release of DigiAsset Node
    DGA_VER_RELEASE_QUERY=$(curl -sfL https://versions.digiassetx.com/digiasset_node/versions.json 2>/dev/null | jq last | sed 's/"//g')
    if [ $DGA_VER_RELEASE_QUERY != "" ]; then
      DGA_VER_RELEASE=$DGA_VER_RELEASE_QUERY
      DGA_VER_MJR_RELEASE=$(echo $DGA_VER_RELEASE | cut -d'.' -f1)
      sed -i -e "/^DGA_VER_RELEASE=/s|.*|DGA_VER_RELEASE=\"$DGA_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
      sed -i -e "/^DGA_VER_MJR_RELEASE=/s|.*|DGA_VER_MJR_RELEASE=\"$DGA_VER_MJR_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # If installed, get the major release directly from the api.js file
    if test -f $DGA_INSTALL_LOCATION/lib/api.js; then
      DGA_VER_MJR_LOCAL_QUERY=$(cat $DGA_INSTALL_LOCATION/lib/api.js | grep "const apiVersion=" | cut -d'=' -f2 | cut -d';' -f1)
      if [ $DGA_VER_MJR_LOCAL_QUERY != "" ]; then
        DGA_VER_MJR_LOCAL=$DGA_VER_MJR_LOCAL_QUERY
        sed -i -e "/^DGA_VER_MJR_LOCAL=/s|.*|DGA_VER_MJR_LOCAL=\"$DGA_VER_MJR_LOCAL\"|" $DGNT_SETTINGS_FILE
      fi
    fi

    if [ "$DGA_VER_RELEASE" != "" ]; then
        sed -i -e "/^DGA_VER_RELEASE=/s|.*|DGA_VER_RELEASE=\"$DGA_VER_RELEASE\"|" $DGNT_SETTINGS_FILE

        # If there is actually a local version, then check for an update
        if [ "$DGA_VER_MJR_LOCAL" != "" ]; then

          # Check if there is an update for DigiAsset Node
          if [ $(version $DGA_VER_MJR_LOCAL) -ge $(version $DGA_VER_MJR_RELEASE) ]; then
            DGA_UPDATE_AVAILABLE="no"
          else
            DGA_UPDATE_AVAILABLE="yes"
          fi
      fi
    fi

    # Check for new release of Kubo
    IPFS_VER_RELEASE_QUERY=$(curl -sfL https://api.github.com/repos/ipfs/kubo/releases/latest | jq -r ".tag_name" | sed 's/v//g')
    if [ "$IPFS_VER_RELEASE_QUERY" != "" ]; then
        IPFS_VER_RELEASE=$IPFS_VER_RELEASE_QUERY
        sed -i -e "/^IPFS_VER_RELEASE=/s|.*|IPFS_VER_RELEASE=\"$IPFS_VER_RELEASE\"|" $DGNT_SETTINGS_FILE

        # If there actually a local version, then check for an update
        if [ "$IPFS_VER_LOCAL" != "" ]; then

          # Check if there is an update for Go-IPFS
          if [ $(version $IPFS_VER_LOCAL) -ge $(version $IPFS_VER_RELEASE) ]; then
            IPFS_UPDATE_AVAILABLE="no"
          else
            IPFS_UPDATE_AVAILABLE="yes"
          fi
        fi
    fi



    # reset 24 hour timer
    SAVED_TIME_1DAY="$(date +%s)"
    sed -i -e "/^SAVED_TIME_1DAY=/s|.*|SAVED_TIME_1DAY=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
fi


###################################################################
#### GENERATE NORMAL DISPLAY #############################################
###################################################################

# Double buffer output to reduce display flickering
output=$(clear -x;

echo -e "${txtbld}"
echo -e "         ____   _         _   _   __            __     "             
echo -e "        / __ \ (_)____ _ (_) / | / /____   ____/ /___   ${txtrst}╔═════════╗${txtbld}"
echo -e "       / / / // // __ '// / /  |/ // __ \ / __  // _ \  ${txtrst}║ STATUS  ║${txtbld}"
echo -e "      / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/  ${txtrst}║ MONITOR ║${txtbld}"
echo -e "     /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/   ${txtrst}╚═════════╝${txtbld}"
echo -e "                /____/                                  ${txtrst}"                         
echo ""  
printf "  ╔════════════════╦════════════════════════════════════════════════════╗\\n"
if [ "$DGB_STATUS" = "running" ]; then # Only display if digibyted is running
if [ $DGB_CONNECTIONS -le 8 ]; then
printf "  ║ CONNECTIONS    ║  " && printf "%-18s %35s %-4s\n" "$DGB_CONNECTIONS Nodes" "[ ${txtbred}$DGB_CONNECTIONS_MSG${txtrst}" "]  ║"
else
printf "  ║ CONNECTIONS    ║  " && printf "%-10s %35s %-4s\n" "$DGB_CONNECTIONS Nodes" "[ $DGB_CONNECTIONS_MSG" "]  ║"
fi
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
printf "  ║ BLOCK HEIGHT   ║  " && printf "%-26s %19s %-4s\n" "$BLOCKCOUNT_FORMATTED Blocks" "[ Synced: $BLOCKSYNC_PERC%" "]  ║"
# Only display the DigiByte wallet balance if the user (a) wants it displayed AND (b) the blockchain has finished syncing AND (c) the wallet actually contains any DGB
if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$BLOCKSYNC_PERC" = "100 " ] && [ "$WALLET_BALANCE" != "" ]; then 
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
printf "  ║ WALLET BALANCE ║  " && printf "%-49s ║ \n" "$WALLET_BALANCE DGB"
fi
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
printf "  ║ NODE UPTIME    ║  " && printf "%-49s ║ \n" "$uptime"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
fi # end check to see of digibyted is running
if [ "$DGB_STATUS" = "stopped" ]; then # Only display if digibyted is NOT running
printf "  ║ DIGIBYTE NODE  ║  " && printf "%-60s ║ \n" "${txtbred}DigiByte daemon is not running.${txtrst}"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
fi
if [ "$DGB_STATUS" = "not_detected" ]; then # Only display if digibyted is NOT detected
printf "  ║ DIGIBYTE NODE  ║  " && printf "%-60s ║ \n" "${txtbred}No DigiByte Node detected.${txtrst}"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
fi
if [ "$DGB_STATUS" = "startingup" ]; then # Only display if digibyted is NOT running
printf "  ║ DIGIBYTE NODE  ║  " && printf "%-60s ║ \n" "${txtbred}DigiByte daemon is currently starting up.${txtrst}"
printf "  ║                ║  " && printf "%-14s %-33s %-2s\n" "Please wait..." "$DGB_ERROR_MSG" " ║"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
fi
printf "  ║ IP ADDRESS     ║  " && printf "%-49s %-1s\n" "Internal: $IP4_INTERNAL  External: $IP4_EXTERNAL" "║" 
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
if [ "$IS_AVAHI_INSTALLED" = "yes" ] && [ "$DGA_STATUS" = "running" ]; then # Use .local domain if available, otherwise use the IP address
printf "  ║ WEB UI         ║  " && printf "%-49s %-1s\n" "http://$HOSTNAME.local:8090" "║"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
if [ "$DGA_CONSOLE_QUERY" != "" ]; then
format_dga_console
fi
elif [ "$DGA_STATUS" = "running" ]; then
printf "  ║ WEB UI         ║  " && printf "%-49s %-1s\n" "http://$IP4_INTERNAL:8090" "║"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
if [ "$DGA_CONSOLE_QUERY" != "" ]; then
format_dga_console
fi
elif [ "$DGA_STATUS" = "stopped" ]; then
printf "  ║ DIGIASSET NODE ║  " && printf "%-60s ║ \n" "${txtbred}DigiAsset Node is not running.${txtrst}"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
elif [ "$DGA_STATUS" = "not_detected" ]; then
printf "  ║ DIGIASSET NODE ║  " && printf "%-60s ║ \n" "${txtbred}No DigiAsset Node detected.${txtrst}"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
fi
if [ -f "$DGB_CONF_FILE" ]; then
printf "  ║ RPC ACCESS     ║  " && printf "%-49s %-1s\n" "User: $RPC_USER     Port: $RPC_PORT" "║" 
printf "  ║                ║  " && printf "%-49s %-1s\n" "Pass: $RPC_PASS" "║" 
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
fi
if [ "$DGNT_UPDATE_AVAILABLE" = "yes" ]; then
printf "  ║ SOFTWARE       ║  " && printf "%-31s %27s %3s\n" "DigiNode Tools $DGNT_VER_LOCAL_DISPLAY" "${txtbgrn}Update: v$DGNT_VER_RELEASE${txtrst}" " ║"
else
printf "  ║ SOFTWARE       ║  " && printf "%-49s ║ \n" "DigiNode Tools $DGNT_VER_LOCAL_DISPLAY"
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$DGB_VER_LOCAL" != "" ]; then
    if [ "$DGB_UPDATE_AVAILABLE" = "yes" ]; then
    printf "  ║                ║  " && printf "%-31s %27s %3s\n" "DigiByte Core v$DGB_VER_LOCAL" "${txtbgrn}Update: v$DGB_VER_RELEASE${txtrst}" " ║"
    else
    printf "  ║                ║  " && printf "%-49s ║ \n" "DigiByte Core v$DGB_VER_LOCAL"
    fi
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$IPFS_VER_LOCAL" != "" ]; then
  if [ "$IPFS_UPDATE_AVAILABLE" = "yes" ]; then
    printf "  ║                ║  " && printf "%-31s %27s %3s\n" "Kubo v$IPFS_VER_LOCAL" "${txtbgrn}Update: v$IPFS_VER_RELEASE${txtrst}" " ║"
  else
    printf "  ║                ║  " && printf "%-49s ║ \n" "Kubo v$IPFS_VER_LOCAL"
  fi
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$NODEJS_VER_LOCAL" != "" ]; then
  if [ "$NODEJS_UPDATE_AVAILABLE" = "yes" ]; then
    printf "  ║                ║  " && printf "%-31s %27s %3s\n" "NodeJS v$NODEJS_VER_LOCAL" "${txtbgrn}Update: v$NODEJS_VER_RELEASE${txtrst}" " ║"
  else
    printf "  ║                ║  " && printf "%-49s ║ \n" "NodeJS v$NODEJS_VER_LOCAL"
  fi
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$DGA_VER_LOCAL" != "" ]; then
  if [ "$DGA_UPDATE_AVAILABLE" = "yes" ]; then
    printf "  ║                ║  " && printf "%-31s %27s %3s\n" "DigiAsset Node v$DGA_VER_LOCAL" "${txtbgrn}Update: v$DGA_VER_LOCAL${txtrst}" " ║"
  else
    printf "  ║                ║  " && printf "%-49s ║ \n" "DigiAsset Node v$DGA_VER_LOCAL"
  fi
fi
printf "  ╚════════════════╩════════════════════════════════════════════════════╝\\n"
if [ "$DGB_STATUS" = "stopped" ]; then # Only display if digibyted is NOT running
printf "   WARNING: Your DigiByte daemon service is not currently running.\\n"
fi
if [ "$DGB_STATUS" = "startingup" ]; then # Only display if digibyted is NOT running
printf "\\n"
printf "   NOTE: DigiByte daemon is currently in the process of starting up.\\n"
printf "         This can sometimes take 10 minutes or more. Please wait...\\n"
fi
if [ "$DGB_STATUS" = "running" ] && [ $DGB_CONNECTIONS -le 8 ]; then # Only show port forwarding instructions if connection count is less or equal to 10 since it is clearly working with a higher count
printf "\\n"
printf "   WARNING: Your current connection count is low. Have you forwarded port\\n"
printf "            12024 on your router? If yes, wait a few minutes. This message\\n"
printf "            will disappear when the total connections reaches 9 or more.\\n"
if [ "$DGB_PORT_TEST_ENABLED" = "YES" ]; then
printf "            For help with port forwarding, press ${txtbld}P${txtrst} to run a Port Test.\\n"
fi
fi
printf "\\n"
printf "  ╔════════════════╦════════════════════════════════════════════════════╗\\n"
if [ "$MODEL" != "" ]; then
printf "  ║ DEVICE         ║  " && printf "%-35s %10s %-4s\n" "$MODEL" "[ $MODELMEM RAM" "]  ║"
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
fi
if [ "$DGB_DATA_DISKUSED_PERC_CLEAN" -ge "80" ]; then # Display current disk usage percentage in red if it is 80% or over
printf "  ║ DISK USAGE     ║  " && printf "%-42s %16s %3s\n" "${DGB_DATA_DISKUSED_HR}b of ${DGB_DATA_DISKTOTAL_HR}b ( ${txtbred}$DGB_DATA_DISKUSED_PERC${txtrst} )" "[ ${DGB_DATA_DISKFREE_HR}b free ]" " ║"
else
printf "  ║ DISK USAGE     ║  " && printf "%-31s %16s %3s\n" "${DGB_DATA_DISKUSED_HR}b of ${DGB_DATA_DISKTOTAL_HR}b ( $DGB_DATA_DISKUSED_PERC )" "[ ${DGB_DATA_DISKFREE_HR}b free ]" " ║"
fi
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
printf "  ║ MEMORY USAGE   ║  " && printf "%-33s %-18s\n" "${RAMUSED_HR}b of ${RAMTOTAL_HR}b" "[ ${RAMAVAIL_HR}b free ]  ║"
if [ "$SWAPTOTAL_HR" != "0B" ] && [ "$SWAPTOTAL_HR" != "" ] && [ "$SWAPUSED_HR" != "0B" ]; then # only display the swap file status if there is one, and the current value is above 0B
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
printf "  ║ SWAP USAGE     ║  " && printf "%-47s %-3s\n" "${SWAPUSED_HR}b of ${SWAPTOTAL_HR}b"  "  ║"
fi 
if [ "$temperature" != "" ]; then
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
printf "  ║ SYSTEM TEMP    ║  " && printf "%-49s %-3s\n" "$TEMP_C °C     $TEMP_F °F" "  ║"
fi
printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
printf "  ║ SYSTEM CLOCK   ║  " && printf "%-47s %-3s\n" "$TIME_NOW" "  ║"
printf "  ╚════════════════╩════════════════════════════════════════════════════╝\\n"
printf "\\n"
# Display a random DigiFact
if [ "$DGB_STATUS" = "running" ] && [ $DGB_CONNECTIONS -ge 9 ]; then
digifact_display
fi
if [ "$DGB_STATUS" = "not_detected" ] || [ "$DGB_STATUS" = "stopped" ]; then
digifact_display
fi
if [ "$IPFS_PORT_TEST_ENABLED" = "YES" ] && [ "$DGA_CONSOLE_QUERY" != "" ] && [ "$IPFS_PORT_NUMBER" != "" ]; then
    printf "               Press ${txtbld}Q${txtrst} to Quit. Press ${txtbld}P${txtrst} to test open ports.\\n"
elif [ "$DGB_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_STATUS" = "running" ]; then
    printf "               Press ${txtbld}Q${txtrst} to Quit. Press ${txtbld}P${txtrst} to test open ports.\\n"
else
    printf "                             Press ${txtbld}Q${txtrst} to Quit.\\n"
fi
printf "\\n"

)

# end output double buffer
echo "$output"

# Display the quit message on exit
trap quit_message EXIT

# sleep 0.5
read -t 0.5 -s -n 1 input

    if [ "$IPFS_PORT_TEST_ENABLED" = "YES" ] && [ "$DGA_CONSOLE_QUERY" != "" ] && [ "$IPFS_PORT_NUMBER" != "" ]; then

        case "$input" in
            "Q")
                echo "Quit..."
                exit
                ;;
            "q")
                echo "Quit..."
                exit
                ;;
            "P")
                echo "Running Port test..."
                port_test
                ;;
            "p")
                echo "Running Port test..."
                port_test
                ;;
        esac

    elif [ "$DGB_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_STATUS" = "running" ]; then

        case "$input" in
            "Q")
                echo "Quit..."
                exit
                ;;
            "q")
                echo "Quit..."
                exit
                ;;
            "P")
                echo "Running Port test..."
                port_test
                ;;
            "p")
                echo "Running Port test..."
                port_test
                ;;
        esac

    else

        case "$input" in
            "Q")
                echo "Quit..."
                exit
                ;;
            "q")
                echo "Quit..."
                exit
                ;;
        esac

    fi



# read -rsn1 input
# if [ "$input" = "q" ]; then
#  echo ""
#  printf "%b Q Key Pressed. Exiting DigiNode Status Monitor...\\n" "${INDENT}"
#  echo ""
#  exit
# fi

done

}


# This will run the port test
port_test() {

clear -x

echo -e "${txtbld}"
echo -e "         ____   _         _   _   __            __     "             
echo -e "        / __ \ (_)____ _ (_) / | / /____   ____/ /___   ${txtrst}╔═════════╗${txtbld}"
echo -e "       / / / // // __ '// / /  |/ // __ \ / __  // _ \  ${txtrst}║ STATUS  ║${txtbld}"
echo -e "      / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/  ${txtrst}║ MONITOR ║${txtbld}"
echo -e "     /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/   ${txtrst}╚═════════╝${txtbld}"
echo -e "                /____/                                  ${txtrst}"                         
echo "" 
printf "  ╔═════════════════════════════════════════════════════════════════════╗\\n"
printf "  ║                     ABOUT PORT FORWARDING                           ║\\n"
printf "  ╠═════════════════════════════════════════════════════════════════════╣\\n"
printf "  ║ For your DigiNode to work correctly you need to open the following  ║\\n"
printf "  ║ ports on your router so the that other nodes on the Internet can    ║\\n"
printf "  ║ find it:                                                            ║\\n"
printf "  ╠═══════════════════════════╦═════════════════════════════════════════╣\\n"
printf "  ║ SOFTWARE                  ║ PORT                                    ║\\n"
printf "  ╠═══════════════════════════╬═════════════════════════════════════════╣\\n"
if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ]; then
printf "  ║ DigiByte Core             ║ 12024                                   ║\\n"
printf "  ╠═══════════════════════════╬═════════════════════════════════════════╣\\n"
fi
if [ "$DGA_STATUS" = "running" ]; then
printf "  ║ IPFS                      ║ " && printf "%-37s %-3s\n" "$IPFS_PORT_NUMBER" "  ║"
printf "  ╠═══════════════════════════╩═════════════════════════════════════════╣\\n"
fi
printf "  ║ For help, visit: " && printf "%-48s %-3s\n" "$DGBH_URL_PORTFWD" "  ║"
printf "  ╚═════════════════════════════════════════════════════════════════════╝\\n"
echo ""

echo "                         Running Port Tests..."
echo ""

PORT_TEST_DATE=$(date)


if [ "$DGB_STATUS" = "running" ] && [ "$DGB_PORT_TEST_ENABLED" = "YES" ]; then

    str="Is DigiByte Core port 12024 open? ... "
    printf "%b %s" "${INFO}" "${str}" 

    if [ $DGB_CONNECTIONS -gt 8 ]; then

        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"           
        DGB_PORT_TEST_ENABLED="NO"
        sed -i -e "/^DGB_PORT_TEST_ENABLED=/s|.*|DGB_PORT_TEST_ENABLED=\"$DGB_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
        DGB_PORT_FWD_STATUS="OPEN"
        sed -i -e "/^DGB_PORT_FWD_STATUS=/s|.*|DGB_PORT_FWD_STATUS=\"$DGB_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
        DGB_PORT_TEST_PASS_DATE=$PORT_TEST_DATE
        sed -i -e "/^DGB_PORT_TEST_PASS_DATE=/s|.*|DGB_PORT_TEST_PASS_DATE=\"$DGB_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
        DGB_PORT_TEST_EXTERNAL_IP=$IP4_EXTERNAL
        sed -i -e "/^DGB_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_PORT_TEST_EXTERNAL_IP=\"$DGB_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
        printf "\\n"
    
    else

        printf "%b%b %s POSSIBLY NOT!\\n" "${OVER}" "${CROSS}" "${str}"           
        DGB_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_PORT_TEST_ENABLED=/s|.*|DGB_PORT_TEST_ENABLED=\"$DGB_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
        DGB_PORT_FWD_STATUS="CLOSED"
        sed -i -e "/^DGB_PORT_FWD_STATUS=/s|.*|DGB_PORT_FWD_STATUS=\"$DGB_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
        DGB_PORT_TEST_PASS_DATE=""
        sed -i -e "/^DGB_PORT_TEST_PASS_DATE=/s|.*|DGB_PORT_TEST_PASS_DATE=|" $DGNT_SETTINGS_FILE
        DGB_PORT_TEST_EXTERNAL_IP=""
        sed -i -e "/^DGB_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_PORT_TEST_EXTERNAL_IP=\"$DGB_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

        printf "\\n"
        printf "%b IMPORTANT: You need to forward port 12024 on your router so that other\\n" "${INFO}"
        printf "%b DigiByte Nodes on the network can find it, otherwise the number of potential\\n" "${INDENT}"
        printf "%b inbound connections is limited to 8. For help, visit: https://portforward.com\\n" "${INDENT}"
        printf "\\n"
        printf "%b If you have already forwarded port 12024 and are still seeing this message,\\n" "${INDENT}"
        printf "%b wait a few minutes - the connection count should start gradually increasing.\\n" "${INDENT}"
        printf "%b If the number of connections is above 8, this indicates that the port is open\\n" "${INDENT}"
        printf "%b and your DigiByte Node is working correctly.\\n" "${INDENT}"
        printf "\\n"
        printf "%b To be certain that port 12024 is being forwarded correctly, visit:\\n" "${INDENT}"
        printf "%b https://opennodes.digibyte.link and enter your external IP address in the\\n" "${INDENT}"
        printf "%b form at the bottom of the page. If the port is open, it should should display\\n" "${INDENT}"
        printf "%b your DigiByte version number and approximate location.\\n" "${INDENT}"
        printf "\\n"

    fi

elif [ "$DGB_STATUS" = "startingup" ] && [ "$DGB_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is DigiByte Core port 12024 open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b Your DigiByte Node is in the process of starting up. Try again in a few minutes...\\n" "${INDENT}"
        printf "\\n"

elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is DigiByte Core port 12024 open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b Your DigiByte Node is not running.\\n" "${INDENT}"
        printf "\\n"

elif [ "$DGB_PORT_TEST_ENABLED" = "NO" ]; then

        str="Is DigiByte Core port 12024 open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b You have already passed this test.\\n" "${INDENT}"
        printf "\\n"

fi

if [ "$DGA_STATUS" = "running" ] && [ "$IPFS_PORT_TEST_ENABLED" = "YES" ]; then

    str="Is IPFS port $IPFS_PORT_NUMBER open? ... "
    printf "%b %s" "${INFO}" "${str}" 

    IPFS_PORT_TEST_QUERY=$(curl localhost:8090/api/digiassetX/ipfs/check.json 2>/dev/null)

    if [ $? -eq 0 ]; then

        if [ "$IPFS_PORT_TEST_QUERY" = "true" ]; then
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"           
            IPFS_PORT_TEST_ENABLED="NO"
            sed -i -e "/^IPFS_PORT_TEST_ENABLED=/s|.*|IPFS_PORT_TEST_ENABLED=\"$IPFS_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
            IPFS_PORT_FWD_STATUS="OPEN"
            sed -i -e "/^IPFS_PORT_FWD_STATUS=/s|.*|IPFS_PORT_FWD_STATUS=\"$IPFS_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_PASS_DATE=$PORT_TEST_DATE
            sed -i -e "/^IPFS_PORT_TEST_PASS_DATE=/s|.*|IPFS_PORT_TEST_PASS_DATE=\"$IPFS_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_EXTERNAL_IP=$IP4_EXTERNAL
            sed -i -e "/^IPFS_PORT_TEST_EXTERNAL_IP=/s|.*|IPFS_PORT_TEST_EXTERNAL_IP=\"$IPFS_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

            sed -i -e "/^IPFS_PORT_NUMBER_SAVED=/s|.*|IPFS_PORT_NUMBER_SAVED=\"$IPFS_PORT_NUMBER\"|" $DGNT_SETTINGS_FILE
            printf "\\n"
        fi

        if [ "$IPFS_PORT_TEST_QUERY" = "false" ]; then
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"           
            IPFS_PORT_TEST_ENABLED="YES"
            sed -i -e "/^IPFS_PORT_TEST_ENABLED=/s|.*|IPFS_PORT_TEST_ENABLED=\"$IPFS_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_FWD_STATUS="CLOSED"
            sed -i -e "/^IPFS_PORT_FWD_STATUS=/s|.*|IPFS_PORT_FWD_STATUS=\"$IPFS_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_PASS_DATE=""
            sed -i -e "/^IPFS_PORT_TEST_PASS_DATE=/s|.*|IPFS_PORT_TEST_PASS_DATE=|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^IPFS_PORT_TEST_EXTERNAL_IP=/s|.*|IPFS_PORT_TEST_EXTERNAL_IP=\"$IPFS_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

        fi

    else
        printf "%b%b %s ERROR! DigiAsset Node is not running!\\n" "${OVER}" "${CROSS}" "${str}" 
    fi

elif [ "$DGA_STATUS" = "stopped" ] && [ "$DGA_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is IPFS port $IPFS_PORT_NUMBER open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b Your DigiAsset Node is not running.\\n" "${INDENT}"
        printf "\\n"

elif [ "$DGA_PORT_TEST_ENABLED" = "NO" ]; then

        str="Is IPFS port $IPFS_PORT_NUMBER open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b You have already passed this test.\\n" "${INDENT}"
        printf "\\n"

fi

echo ""
echo ""
read -t 60 -n 1 -s -r -p "            < Press any key to return to the Status Monitor >"

status_loop

}


######################################################
######### PERFORM STARTUP CHECKS #####################
######################################################

startup_checks() {

  # Note: Some of these functions are found in the diginode-setup.sh file
  
  digimon_title_box                # Clear screen and display title box
# digimon_disclaimer               # Display disclaimer warning during development. Pause for confirmation.
  get_script_location              # Find which folder this script is running in (in case this is an unnoficial DigiNode)
  import_setup_functions           # Import diginode-setup.sh file because it contains functions we need
  diginode_tools_import_settings   # Import diginode.settings file
  diginode_logo_v3                 # Display DigiNode logo
  is_verbose_mode                  # Display a message if Verbose Mode is enabled
  sys_check                        # Perform basic OS check - is this Linux? Is it 64bit?
  rpi_check                        # Look for Raspberry Pi hardware. If found, only continue if it compatible.
  set_sys_variables                # Set various system variables once we know we are on linux
# load_diginode_settings           # Load the diginode.settings file. Create it if it does not exist.
  diginode_tools_create_settings   # Create diginode.settings file (if it does not exist)
  diginode_tools_update_settings   # Update the diginode.settings file if there is a new version
  swap_check                       # if this system has 4Gb or less RAM, check there is a swap drive
# install_diginode_tools           # install or upgrade the DigiNode tools scripts
  digibyte_check_official          # check if this is an official install of DigiByte Core
  is_dgbnode_installed             # Run checks to see if DigiByte Node is present. Exit if it isn't. Import digibyte.conf.
  digiasset_check_official         # check if this is an official install of DigiAsset Node
  is_dganode_installed             # Run checks to see if DigiAsset Node is present. Warn if it isn't.
  is_wallet_enabled                # Check that the DigiByte Core wallet is enabled
  get_dgb_rpc_credentials          # Get the RPC username and password from digibyte.conf file. Warn if not present.
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
status_loop                 # Run the status monitor loop



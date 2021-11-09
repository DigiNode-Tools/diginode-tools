#!/bin/bash
#
# Name:    DigiNode Installer
# Purpose: Install a DigiByte Node and DigiAsset Metadata server on a compatible linux device.
#          Script supports most Linux servers and the Raspberry Pi 3 and later.
#          A Raspberry Pi 4 8Gb running Ubuntu Server 64-bit is recommended.
#
# Author:  Olly Stedall @saltedlolly
#
# Usage:   Install with this command (from your Linux machine):
#
#          curl http://diginode-installer.digibyte.help | bash 
#
# -----------------------------------------------------------------------------------------------------

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# We do not want users to end up with a pagrtially working install, so we exit the script
# instead of continuing the installation with something broken
# set -e

# Play an error beep if it exits with an error
trap error_beep exit 1

# Function to beep on an exit 1
error_beep() {
    echo -en "\007"  
    tput cnorm 
}

# Append common folders to the PATH to ensure that all basic commands are available.
# When using "su" an incomplete PATH could be passed.
export PATH+=':/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

# Store the user in a variable
if [ -z "${USER}" ]; then
  USER="$(id -un)"
fi

# Store the user's account name amd home folder in a variable (this works regardless of whether the user is running as root or not)
if [[ "${EUID}" -eq 0 ]]; then
     USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
     USER_ACCOUNT=$SUDO_USER
else
     USER_HOME=$(getent passwd $USER | cut -d: -f6)
     USER_ACCOUNT=$USER
fi


######## VARIABLES START HERE #########
# For better maintainability, we store as much information that can change in variables
# This allows us to make a change in one place that can propagate to all instances of the variable
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions

# Set VERBOSE_MODE to YES to get more verbose feedback. Very useful for troubleshooting.
# This can be overridden when needed by the --verboseon or --verboseoff flags.
# (Note: The RUN_INSTALLER condition ensures that the VERBOSE_MODE setting only applies to this installer
# and is ignored if running the Status Monitor script - that has its own VERBOSE_MODE setting.)
if [[ "$RUN_INSTALLER" != "NO" ]] ; then
    VERBOSE_MODE=false
fi

######### IMPORTANT NOTE ###########
# Both the DigiNode Installer and Status Monitor scripts make use of a setting file
# located at ~/.digibyte/diginode.settings
# If you want to change the default folder locations, please edit this file.
# (e.g. To move your DigiByte Core data file to an external drive.)
#
# NOTE: This variable sets the default location of the diginode.settings file. 
# There should be no reason to change this, and it is unadvisable to do.
DGNT_SETTINGS_LOCATION=$USER_HOME/.digibyte
DGNT_SETTINGS_FILE=$DGNT_SETTINGS_LOCATION/diginode.settings

# This variable stores the approximate amount of space required to download the entire DigiByte blockchain
# This value needs updating periodically as the size increases
DGB_DATA_REQUIRED_HR="28Gb"
DGB_DATA_REQUIRED_KB="28000000"

# This is the URLs where the install script is hosted. This is used primarily for testing.
DGNT_VERSIONS_URL=diginode-versions.digibyte.help    # Used to query TXT record containing compatible OS'es
DGNT_INSTALLER_OFFICIAL_URL=https://diginode-installer.digibyte.help
DGNT_INSTALLER_GITHUB_LATEST_RELEASE_URL=
DGNT_INSTALLER_GIHTUB_MAIN_URL=https://raw.githubusercontent.com/saltedlolly/diginode-tools/main/diginode-installer.sh
DGNT_INSTALLER_GITHUB_DEVELOP_URL=https://raw.githubusercontent.com/saltedlolly/diginode-tools/develop/diginode-installer.sh

# This is the Github repo for the DigiAsset Node (this only needs to be changed if you with to test a new version.)
# The main branch is used by default. The dev branch is installed if the --dgadev flag is used.
DGA_GITHUB_REPO_MAIN="--depth 1 https://github.com/digiassetX/digiasset_node.git"
DGA_GITHUB_REPO_DEV="--branch apiV3 https://github.com/digiassetX/digiasset_node.git"


# These are the commands that the use pastes into the terminal to run the installer
DGNT_INSTALLER_OFFICIAL_CMD="curl $DGNT_INSTALLER_OFFICIAL_URL | bash"

# We clone (or update) the DigiNode git repository during the install. This helps to make sure that we always have the latest version of the relevant files.
DGNT_RELEASE_URL="https://github.com/saltedlolly/diginode-tools.git"

# DigiByte.Help URLs
DGBH_URL_INTRO=https://www.digibyte.help/diginode/        # Link to introduction what a DigiNode is. Shown in welcome box.
DGBH_URL_CUSTOM=https://www.digibyte.help/diginode/       # Information on customizing your install by editing diginode.settings
DGBH_URL_RPIOS64=https://www.digibyte.help/diginode/      # Advice on switching to Raspberry Pi OS 64-bit kernel
DGBH_URL_HARDWARE=https://www.digibyte.help/diginode/     # Advice on what hardware to get
DGBH_URL_USERCHANGE=https://www.digibyte.help/diginode/   # Advice on why you should change the username
DGBH_URL_HOSTCHANGE=https://www.digibyte.help/diginode/   # Advice on why you should change the hostname
DGBH_URL_STATICIP=https://www.digibyte.help/diginode/     # Advice on how to set a static IP
DGBH_URL_PORTFWD=https://www.digibyte.help/diginode/      # Advice on how to forward ports with your router
DGBH_URL_TWEET=https://www.digibyte.help/diginode/        # URL included in sample tweet.

# If update variable isn't specified, set to false
if [ -z "$NewInstall" ]; then
  NewInstall=true
fi

# whiptail dialog dimensions: 20 rows and 70 chars width assures to fit on small screens and is known to hold all content.
r=24
c=70

######## Undocumented Flags. Shhh ########
# These are undocumented flags; some of which we can use when repairing an installation
# The UNATTENDED_MODE flag is one example of this
RESET_MODE=false
UNATTENDED_MODE=false
DGNT_BRANCH="release"
UNINSTALL=false
DIGINODE_SKIP_OS_CHECK=false
DGA_DEV_MODE=false
STATUS_MONITOR=false
# Check arguments for the undocumented flags
# --dgndev (-d) will use and install the develop branch of DigiNode Tools (used during development)
for var in "$@"; do
    case "$var" in
        "--reset" ) RESET_MODE=true;;
        "--unattended" ) UNATTENDED_MODE=true;;
        "--dgnt-dev" ) DGNT_BRANCH="develop";; 
        "--dgnt-main" ) DGNT_BRANCH="main";; 
        "--dga-dev" ) DGA_DEV_MODE=true;; 
        "--uninstall" ) UNINSTALL=true;;
        "--skiposcheck" ) DGNT_SKIP_OS_CHECK=true;;
        "--verboseon" ) VERBOSE_MODE=true;;
        "--verboseoff" ) VERBOSE_MODE=false;;
        "--statusmonitor" ) STATUS_MONITOR=true;;
    esac
done


# Set these values so the installer can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_LIGHT_RED='\e[1;31m'
COL_LIGHT_BLUE='\e[0;94m'
COL_LIGHT_CYAN='\e[1;96m'
COL_BOLD_WHITE='\e[1;37m'
TICK="  [${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="  [${COL_LIGHT_RED}✗${COL_NC}]"
WARN="  [${COL_LIGHT_RED}!${COL_NC}]"
INFO="  [${COL_BOLD_WHITE}i${COL_NC}]"
INDENT="     "
# shellcheck disable=SC2034
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="  \\r\\033[K"

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



#####################################################################################################
### FUNCTIONS
#####################################################################################################

# Inform user if Verbose Mode is enabled
is_verbose_mode() {
    if [ $VERBOSE_MODE = true ]; then
        printf "%b Verbose Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
    fi
}

# Inform user if Verbose Mode is enabled
is_unattended_mode() {
    if [ "$UNATTENDED_MODE" = true ]; then
        printf "%b Unattended Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        if test -f "$DGNT_SETTINGS_FILE"; then
            printf "%b   No menus will be displayed - diginode.settings values will be used\\n" "${INDENT}"
        else
            printf "%b   diginode.settings file not found - it will be created\\n" "${INDENT}"
        fi
        printf "\\n"
    fi
}

# Inform user if DigiAsset Dev Mode is enable
is_dgadev_mode() {
    if [ "$DGA_DEV_MODE" = true ]; then
        printf "%b DigiAsset Node Developer Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b   The developer version of DigiAsset Node will be installed.\\n" "${INDENT}"
        printf "\\n"
        DGA_GITHUB_REPO=$DGA_GITHUB_REPO_DEV
    else
        DGA_GITHUB_REPO=$DGA_GITHUB_REPO_MAIN
    fi
}

# Inform user if Reset Mode is enabled
is_reset_mode() {
    # Exit if the user tries to run Reset Mode with Unattended mode at the same time - this is not supported.
    if [ "$UNATTENDED_MODE" = true ] && [ "$RESET_MODE" = true ]; then
        printf "%b %bERROR: Unattended Mode & Reset Mode cannot be used together.\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Reset Mode can only be used interactively. Please run again\\n" "${INDENT}"
        printf "%b without the --unattended flag.\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # Inform user if Reset Mode is enabled
    if [ "$RESET_MODE" = true ]; then
        printf "%b Reset Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Your DigiNode will be reset. All settings and configuration files\\n" "${INDENT}"
        printf "%b will be deleted and recreated. DigiByte and DigiAssets\\n" "${INDENT}"
        printf "%b software will be reinstalled. Any DigiByte blockchain data or\\n" "${INDENT}"
        printf "%b DigiAsset metadata will also be optionally deleted.\\n" "${INDENT}"
        printf "\\n"
    fi
}

# Load variables from diginode.settings file. Create the file first if it does not exit.
diginode_tools_create_settings() {

local str

# If we are in reset mode, delete the diginode.settings file, if it already exists
  if [ "$RESET_MODE" = true ] && [ -f "$DGNT_SETTINGS_FILE" ]; then
    printf "%b Reset Mode is Enabled. Deleting existing diginode.settings file.\\n" "${INFO}"
    rm -f $DGNT_SETTINGS_FILE
  fi

# If the diginode.settings file does not already exist, then create it
if [ ! -f "$DGNT_SETTINGS_FILE" ]; then

  # create .diginode settings folder if it does not exist
  if [ ! -d "$DGNT_SETTINGS_LOCATION" ]; then
    str="Creating ~/.diginode folder..."
    printf "\\n%b %s" "${INFO}" "${str}"
    if [ $VERBOSE_MODE = true ]; then
        printf "\\n"
        printf "%b   Folder location: $DGNT_SETTINGS_LOCATION\\n" "${INDENT}"
        sudo -u $USER_ACCOUNT mkdir $DGNT_SETTINGS_LOCATION
    else
        sudo -u $USER_ACCOUNT mkdir $DGNT_SETTINGS_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
  fi

  # Make sure the user owns this folder
  # chown $USER_ACCOUNT $DGNT_SETTINGS_LOCATION

  # create diginode.settings file
  str="Creating ~/.diginode/diginode.settings file..."
  printf "%b %s" "${INFO}" "${str}"
  sudo -u $USER_ACCOUNT touch $DGNT_SETTINGS_FILE
  cat <<EOF > $DGNT_SETTINGS_FILE
#!/bin/bash
# This settings file is used to store variables for the DigiNode Installer and DigiNode Status Monitor


############################################
####### FOLDER AND FILE LOCATIONS ##########
############################################

# DEFAULT FOLDER AND FILE LOCATIONS
# If you want to change the default location of folders you can edit them here
# Important: Use the USER_HOME variable to identify your home folder location.

# DGNT_SETTINGS_LOCATION=   [This value is set in the header of the installer script. Do not set it here.]
# DGNT_SETTINGS_FILE=       [This value is set in the header of the installer script. Do not set it here.]

# DIGIBYTE CORE BLOCKCHAIN DATA LOCATION:
# You can change this to optionally store the DigiByte blockchain data in a diferent location
# The value set below will be used by the normal install and the unattended install
# Note - changing this after the DigiByte Node has already been running will cause
# the blockchain to be be re-downloaded in the new location. The old data will need to be deleted manually
# or moved to the new location first. Follow these recommended steps to change the location:
# 1) Stop the digibyted service
# 2) Manually move the blockchain data from the old to the new location
# 3) Update this file with the new location below
# 4) Re-run the DigiNode Installer to automatically update your service file and digibyte.conf file with the new location
# 5) Restart the digibyted service 
DGB_DATA_LOCATION=$USER_HOME/.digibyte/


#####################################
####### OTHER SETTINGS ##############
#####################################

# THis will set the max connections in the digibyte.conf file on the first install
# This value set here is also used when performing an unattended install
# (Note: If a digibyte.conf file already exists that sets the maxconnections already, the value here will be ignored)
DGB_MAX_CONNECTIONS=300

# Stop the DigiNode Status Monitor automatically if it is left running
# Set to 0 to run indefinitely, or enter the number of seconds before it stops automatically.
# e.g. To stop after 12 hours enter: 43200
SM_AUTO_QUIT=43200

# Install the develop branch of DigiNode Tools (Specify either YES or NO)
# If NO, it will install the latest release version
DGNT_DEV_BRANCH=YES

# This let's you choose whther system upgrades are installed alongside upgrades for the DigiNode software
INSTALL_SYS_UPGRADES=NO


#####################################
####### UNATTENDED INSTALLER ########
#####################################

# INSTRUCTIONS: 
# These variables are used during an unattended install to automatically configure your DigiNode.
# Set these variables and then run the installer with the --unattended flag set.

# Decide whether to have the script enforce using user: digibyte (Set to YES/NO)
# If set to YES the Installer will only proceed if the the user is: digibyte
# If set to NO the Installer will install as the current user
UI_ENFORCE_DIGIBYTE_USER=YES

# Choose whether to change the system hostname to: diginode (Set to YES/NO)
# If you are running a dedicated device (e.g. Raspberry Pi) as your DigiNode then you probably want to do this.
# If it is running on a Linux box with a load of other stuff, then probably not.
UI_HOSTNAME_SET=YES

# Choose whether to setup the local ufw firewall (Set to YES/NO) [NOT WORKING YET]
UI_FIREWALL_SETUP=YES

# Choose whether to create or change the swap file size
# The optimal swap size will be calculated to ensure there is 8Gb total memory.
# e.g. If the system has 2Gb RAM, it will create a 6Gb swap file. Total: 8Gb.
# If there is more than 8Gb RAM available, no swap will be created.
# You can override this by manually entering the desired size in UI_SWAP_SIZE_MB below.
UI_SWAP_SETUP=YES

# You can optionally manually enter a desired swap file size here in MB.
# The UI_SWAP_SETUP variable above must be set to YES for this to be used.
# If you leave this value empty, the optimal swap file size will calculated by the installer.
# Enter the amount in MB only, without the units. (e.g. 4Gb = 4000 )
UI_SWAP_SIZE_MB=

# This is where the swap file will be located. You can change this to store it on an external drive
# if desired.
UI_SWAP_FILE=/swapfile

# Will install regardless of available disk space on the data drive. Use with caution.
UI_DISKSPACE_OVERRIDE=NO

# Choose whether to setup Tor [NOT WORKING YET]
UI_TOR_SETUP=YES

# Choose YES to do a Full DigiNode with both DigiByte and DigiAsset Nodes
# Choose NO to install DigiByte Core only
UI_DO_FULL_INSTALL=YES


#############################################
####### SYSTEM VARIABLES ####################
#############################################

# IMPORTANT: DO NOT CHANGE ANY OF THESE VALUES. THEY ARE CREATED AND SET AUTOMATICALLY BY THE INSTALLER AND STATUS MONITOR.

# DIGIBYTE NODE LOCATION:
# This references a symbolic link that points at the actual install folder. Please do not change this.
# If you must change the install location, do not edit it here - it may break things. Instead, create a symbolic link 
# called 'digibyte' in your home folder that points to the location of your DigiByte Core install folder.
# Be aware that DigiNode Installer upgrades will likely not work if you do this.
DGB_INSTALL_LOCATION=$USER_HOME/digibyte

# Do not change this. You can change the location of the blockchain data with the DGB_DATA_LOCATION variable above.
DGB_SETTINGS_LOCATION=$USER_HOME/.digibyte

# DIGIBYTE NODE FILES:
DGB_CONF_FILE=\$DGB_SETTINGS_LOCATION/digibyte.conf
DGB_CLI=\$DGB_INSTALL_LOCATION/bin/digibyte-cli
DGB_DAEMON=\$DGB_INSTALL_LOCATION/bin/digibyted

# IPFS NODE LOCATION
IPFS_SETTINGS_LOCATION=$USER_HOME/.ipfs

# DIGIASSET NODE LOCATION:
DGA_INSTALL_LOCATION=$USER_HOME/digiasset_node
DGA_SETTINGS_LOCATION=\$DGB_SETTINGS_LOCATION/assetnode_config
DGA_SETTINGS_FILE=\$DGA_SETTINGS_LOCATION/main.json

# DIGIASSET NODE FILES
DGA_CONFIG_FILE=\$DGA_INSTALL_LOCATION/_config/main.json

# SYSTEM SERVICE FILES:
DGB_SYSTEMD_SERVICE_FILE=/etc/systemd/system/digibyted.service
DGB_UPSTART_SERVICE_FILE=/etc/init/digibyted.conf
IPFS_SYSTEMD_SERVICE_FILE=$USER_HOME/.config/systemd/user/ipfs.service
IPFS_UPSTART_SERVICE_FILE=/etc/init/ipfs.conf
PM2_SYSTEMD_SERVICE_FILE=/etc/systemd/system/pm2-root.service
PM2_UPSTART_SERVICE_FILE=/etc/init/pm2-root.service

# Store DigiByte Core Installation details:
DGB_INSTALL_DATE=
DGB_UPGRADE_DATE=
DGB_VER_RELEASE=
DGB_VER_LOCAL=
DGB_VER_LOCAL_CHECK_FREQ=daily

# DIGINODE TOOLS LOCATION:
# This is the default location where the scripts get installed to. There should be no need to change this.
DGNT_LOCATION=$USER_HOME/diginode-tools

# DIGINODE TOOLS FILES:
DGNT_INSTALLER_SCRIPT=\$DGNT_LOCATION/diginode-installer.sh
DGNT_INSTALLER_LOG=\$DGNT_LOCATION/diginode.log
DGNT_MONITOR_SCRIPT=\$DGNT_LOCATION/diginode.sh

# DIGINODE TOOLS INSTALLATION DETAILS:
# Release/Github versions are queried once a day and stored here. Local version number are queried every minute.
DGNT_INSTALL_DATE=
DGNT_UPGRADE_DATE=
DGNT_MONITOR_FIRST_RUN=
DGNT_MONITOR_LAST_RUN=
DGNT_VER_LOCAL=
DGNT_VER_RELEASE=
DGNT_LOCAL_BRANCH=
DGNT_LOCAL_RELEASE=

# THese are updated automatically every time DigiNode Tools is installed/upgraded. 
# Stores the DigiNode Tools github branch that is currently installed (e.g. develop/main/release)
DGNT_LOCAL_BRANCH=
# Stores the version number of the release branch (if currently installed)
DGNT_LOCAL_RELEASE_VER=

# Store DigiAsset Node installation details:
DGA_INSTALL_DATE=
DGA_UPGRADE_DATE=
DGA_FIRST_RUN=
DGA_VER_MJR_LOCAL=
DGA_VER_MNR_LOCAL=
DGA_VER_LOCAL=
DGA_VER_MJR_RELEASE=
DGA_VER_RELEASE=


# Store IPFS Updater installation details:
IPFSU_VER_LOCAL=
IPFSU_VER_RELEASE=
IPFSU_INSTALL_DATE=
IPFSU_UPGRADE_DATE=

# Store GoIPFS installation details:
IPFS_VER_LOCAL=
IPFS_VER_RELEASE=
IPFS_INSTALL_DATE=
IPFS_UPGRADE_DATE=

# Store NodeJS installation details:
NODEJS_VER_LOCAL=
NODEJS_VER_RELEASE=
NODEJS_INSTALL_DATE=
NODEJS_UPGRADE_DATE=
NODEJS_PPA_ADDED=

# Timer variables (these control the timers in the Status Monitor loop)
SAVED_TIME_15SEC=
SAVED_TIME_1MIN=
SAVED_TIME_15MIN=
SAVED_TIME_1DAY=
SAVED_TIME_1WEEK=

# Disk usage variables (updated every 15 seconds)
BOOT_DISKFREE_HR=
BOOT_DISKFREE_MB=
BOOT_DISKUSED_HR=
BOOT_DISKUSED_MB=
BOOT_DISKUSED_PERC=
DGB_DATA_DISKFREE_HR=
DGB_DATA_DISKFREE_MB=
DGB_DATA_DISKUSED_HR=
DGB_DATA_DISKUSED_MB=
DGB_DATA_DISKUSED_PERC=

# IP addresses (only rechecked once every 15 minutes)
IP4_INTERNAL=$IP4_INTERNAL
IP4_EXTERNAL=

# This records when the wallet was last backed up
WALLET_BACKUP_DATE=
WALLET_BACKUP_ID=

# Store number of available system updates so the script only checks this occasionally
SYSTEM_REGULAR_UPDATES=
SYSTEM_SECURITY_UPDATES=

# Store when an open port test last ran successfully
# Note: If you want to run a port test again, remove the status and date from here
# If you wish to re-run the port test, you can delete the word 'passed' from IPFS_PORT_TEST_STATUS below.
IPFS_PORT_TEST_STATUS=
IPFS_PORT_TEST_DATE_date=

# Don't display donation plea more than once every 15 mins (value should be 'yes' or 'wait15')
DONATION_PLEA=yes

# Store DigiByte blockchain sync progress
BLOCKSYNC_VALUE=

EOF

    if [ $VERBOSE_MODE = true ]; then
        printf "\\n"
        printf "%b   File location: $DGNT_SETTINGS_FILE\\n" "${INDENT}"
    else
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If we are running unattended, then exit now so the user can customize diginode.settings, since it just been created
    if [ "$UNATTENDED_MODE" = true ]; then
        printf "\\n"
        printf "%b %bIMPORTANT: Customize your Unattended Install before running this again!!%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Since this is the first time running the DigiNode Installer, a settings file used for\\n" "${INDENT}"
        printf "%b customizing an Unattended Install has just been created at: $DGNT_SETTINGS_FILE\\n" "${INDENT}"
        printf "\\n"
        printf "%b If you want to customize your Unattended Install of DigiNode, you need to edit\\n" "${INDENT}"
        printf "%b this file before running the Installer again with the --unattended flag.\\n" "${INDENT}"
        printf "\\n"
        if [ "$TEXTEDITOR" != "" ]; then
            printf "%b You can edit it by entering:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   $TEXTEDITOR $DGNT_SETTINGS_FILE\\n" "${INDENT}"
            printf "\\n"
        fi
        exit
    fi

    # The settings file exists, so source it
    str="Importing diginode.settings file..."
    printf "%b %s" "${INFO}" "${str}"
    source $DGNT_SETTINGS_FILE

    if [ $VERBOSE_MODE = true ]; then
        printf "\\n"
        printf "%b   File location: $DGNT_SETTINGS_FILE\\n" "${INDENT}"
        printf "\\n"
    else
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"
    fi

    # Sets a variable to know that the diginode.settings file has been created for the first time
    IS_DGNT_SETTINGS_FILE_NEW="YES"

fi

}

# Import the diginode.settings file it it exists
# check if diginode.settings file exists
diginode_tools_import_settings() {

if [ -f "$DGNT_SETTINGS_FILE" ]; then

    # The settings file exists, so source it
    str="Importing diginode.settings file..."
    printf "%b %s" "${INFO}" "${str}"

    source $DGNT_SETTINGS_FILE
    
    if [ $VERBOSE_MODE = true ]; then
        printf "\\n"
        printf "%b   File location: $DGNT_SETTINGS_FILE\\n" "${INDENT}"
        printf "\\n"
    else
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"
    fi

else
    if [ $VERBOSE_MODE = true ]; then
        printf "%b diginode.settings file not found\\n" "${INDENT}"
        printf "\\n"
    fi
fi

}

# Function to set the DigiNode Tools Dev branch to use
set_dgnt_branch() {

    # Set relevant Github branch for DigiNode Tools
    if [ "$DGNT_BRANCH" = "develop" ]; then
        if [[ "${EUID}" -eq 0 ]]; then
            printf "%b DigiNode Tools Developer Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b   The develop branch will be used.\\n" "${INDENT}"
            printf "\\n"
        fi
        DGNT_INSTALLER_URL=$DGNT_INSTALLER_GITHUB_DEVELOP_URL
    elif [ "$DGNT_BRANCH" = "main" ]; then
        if [[ "${EUID}" -eq 0 ]]; then
            printf "%b DigiNode Tools Main Branch Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b   The main branch will be used. Used for testing before pushing a final release.\\n" "${INDENT}"
            printf "\\n"
        fi
        DGNT_INSTALLER_URL=$DGNT_INSTALLER_GITHUB_MAIN_URL
    else
        # If latest release branch does not exist, use main branch
            if [ "$DGNT_INSTALLER_GITHUB_LATEST_RELEASE_URL" = "" ]; then
                if [[ "${EUID}" -eq 0 ]] && [ $VERBOSE_MODE = true ]; then
                    printf "%b %bDigiNode Tools release branch is unavailable - main branch will be used.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                    printf "\\n"
                fi
                DGNT_INSTALLER_URL=$DGNT_INSTALLER_GITHUB_MAIN_URL
            else
                if [[ "${EUID}" -eq 0 ]] && [ $VERBOSE_MODE = true ]; then
                    printf "%b %bDigiNode Tools latest release branch will be used.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                    printf "\\n"
                fi
                DGNT_INSTALLER_URL=$DGNT_INSTALLER_OFFICIAL_URL
            fi
    fi
}

# These are only set after the intitial OS check since they cause an error on MacOS
set_sys_variables() {

    local str

    if [ $VERBOSE_MODE = true ]; then
        printf "%b Looking up system variables...\\n" "${INFO}"
    else
        str="Looking up system variables..."
        printf "%b %s" "${INFO}" "${str}"
    fi

    # check the 'cat' command is available
    if ! is_command cat ; then
        if [ $VERBOSE_MODE = false ]; then
            printf "\\n"
        fi
        printf "%b %bERROR: Unable to look up system variables - 'cat' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        exit 1
    fi

    # check the 'free' command is available
    if ! is_command free ; then
        if [ $VERBOSE_MODE = false ]; then
            printf "\\n"
        fi
        printf "%b %bERROR: Unable to look up system variables - 'free' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        exit 1
    fi

    # check the 'df' command is available
    if ! is_command df ; then
        if [ $VERBOSE_MODE = false ]; then
            printf "\\n"
        fi
        printf "%b %bERROR: Unable to look up system variables - 'df' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        exit 1
    fi

    # Store total system RAM as variables
    RAMTOTAL_KB=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
    RAMTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)

    # Store current total swap file size as variables
    SWAPTOTAL_KB=$(cat /proc/meminfo | grep SwapTotal: | tr -s ' ' | cut -d' ' -f2)
    SWAPTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f2)

    if [ $VERBOSE_MODE = true ]; then
        printf "%b   Total RAM: ${RAMTOTAL_HR}b ( KB: ${RAMTOTAL_KB} )\\n" "${INDENT}"
        if [ $SWAPTOTAL_HR = "0B" ]; then
            printf "%b   Total SWAP: none\\n" "${INDENT}"
        else
            printf "%b   Total SWAP: ${SWAPTOTAL_HR}b ( KB: ${SWAPTOTAL_KB} )\\n" "${INDENT}"
        fi
    fi

    BOOT_DISKTOTAL_HR=$(df . -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKTOTAL_KB=$(df . --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    DGB_DATA_DISKTOTAL_HR=$(df $DGB_DATA_LOCATION -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    DGB_DATA_DISKTOTAL_KB=$(df $DGB_DATA_LOCATION --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')

    if [ $VERBOSE_MODE = true ]; then
        printf "%b   Total Disk Space: ${BOOT_DISKTOTAL_HR}b ( KB: ${BOOT_DISKTOTAL_KB} )\\n" "${INDENT}"
    fi

 #   # No need to update the disk usage variables if running the status monitor, as it does it itself
 #   if [[ "$RUN_INSTALLER" != "NO" ]] ; then

        # Get internal IP address
        IP4_INTERNAL=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
        if [ -f "$DGNT_SETTINGS_FILE" ]; then
            sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=$IP4_INTERNAL|" $DGNT_SETTINGS_FILE
        fi

        # Lookup disk usage, and update diginode.settings if present
        update_disk_usage

        if [[ $VERBOSE_MODE = true ]]; then
            printf "%b   Used Boot Disk Space: ${BOOT_DISKUSED_HR}b ( ${BOOT_DISKUSED_PERC}% )\\n" "${INDENT}"
            printf "%b   Free Boot Disk Space: ${BOOT_DISKFREE_HR}b ( KB: ${BOOT_DISKFREE_KB} )\\n" "${INDENT}"
            printf "%b   Used Data Disk Space: ${DGB_DATA_DISKUSED_HR}b ( ${DGB_DATA_DISKUSED_PERC}% )\\n" "${INDENT}"
            printf "%b   Free Data Disk Space: ${DGB_DATA_DISKFREE_HR}b ( KB: ${DGB_DATA_DISKFREE_KB} )\\n" "${INDENT}"
        else
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

 #   fi
    printf "\\n"

}

# Lookup disk usage, and store in diginode.settins if present
update_disk_usage() {

        # Update current disk usage variables
        BOOT_DISKUSED_HR=$(df . -h --output=used | tail -n +2)
        BOOT_DISKUSED_KB=$(df . --output=used | tail -n +2)
        BOOT_DISKUSED_PERC=$(df . --output=pcent | tail -n +2)
        BOOT_DISKFREE_HR=$(df . -h --si --output=avail | tail -n +2)
        BOOT_DISKFREE_KB=$(df . --output=avail | tail -n +2)

        # Update current data disk usage variables
        DGB_DATA_DISKUSED_HR=$(df $DGB_DATA_LOCATION -h --output=used | tail -n +2)
        DGB_DATA_DISKUSED_KB=$(df $DGB_DATA_LOCATION --output=used | tail -n +2)
        DGB_DATA_DISKUSED_PERC=$(df $DGB_DATA_LOCATION --output=pcent | tail -n +2)
        DGB_DATA_DISKFREE_HR=$(df $DGB_DATA_LOCATION -h --si --output=avail | tail -n +2)
        DGB_DATA_DISKFREE_KB=$(df $DGB_DATA_LOCATION --output=avail | tail -n +2)

        # Trim white space from disk variables
        BOOT_DISKUSED_HR=$(echo -e " \t $BOOT_DISKUSED_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        BOOT_DISKUSED_KB=$(echo -e " \t $BOOT_DISKUSED_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        BOOT_DISKUSED_PERC=$(echo -e " \t $BOOT_DISKUSED_PERC \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        BOOT_DISKFREE_HR=$(echo -e " \t $BOOT_DISKFREE_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        BOOT_DISKFREE_KB=$(echo -e " \t $BOOT_DISKFREE_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        DGB_DATA_DISKUSED_HR=$(echo -e " \t $DGB_DATA_DISKUSED_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        DGB_DATA_DISKUSED_KB=$(echo -e " \t $DGB_DATA_DISKUSED_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        DGB_DATA_DISKUSED_PERC=$(echo -e " \t $DGB_DATA_DISKUSED_PERC \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        DGB_DATA_DISKFREE_HR=$(echo -e " \t $DGB_DATA_DISKFREE_HR \t " | sed 's/^[ \t]*//;s/[ \t]*$//')
        DGB_DATA_DISKFREE_KB=$(echo -e " \t $DGB_DATA_DISKFREE_KB \t " | sed 's/^[ \t]*//;s/[ \t]*$//')

        # Update diginode.settings file it it exists
        if [ -f "$DGNT_SETTINGS_FILE" ]; then
            sed -i -e "/^BOOT_DISKUSED_HR=/s|.*|BOOT_DISKUSED_HR=$BOOT_DISKUSED_HR|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKUSED_KB=/s|.*|BOOT_DISKUSED_KB=$BOOT_DISKUSED_KB|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKUSED_PERC=/s|.*|BOOT_DISKUSED_PERC=$BOOT_DISKUSED_PERC|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKFREE_HR=/s|.*|BOOT_DISKFREE_HR=$BOOT_DISKFREE_HR|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKFREE_KB=/s|.*|BOOT_DISKFREE_KB=$BOOT_DISKFREE_KB|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_HR=/s|.*|DGB_DATA_DISKUSED_HR=$DGB_DATA_DISKUSED_HR|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_KB=/s|.*|DGB_DATA_DISKUSED_KB=$DGB_DATA_DISKUSED_KB|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_PERC=/s|.*|DGB_DATA_DISKUSED_PERC=$DGB_DATA_DISKUSED_PERC|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKFREE_HR=/s|.*|DGB_DATA_DISKFREE_HR=$DGB_DATA_DISKFREE_HR|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKFREE_KB=/s|.*|DGB_DATA_DISKFREE_KB=$DGB_DATA_DISKFREE_KB|" $DGNT_SETTINGS_FILE
        fi

}

# Create digibyte.config file if it does not already exist
digibyte_create_conf() {

    local str
    local reset_digibyte_conf


    # If we are in reset mode, ask the user if they want to reinstall DigiByte Core
    if [ "$RESET_MODE" = true ] && [ -f "$DGB_CONF_FILE" ]; then

        if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-create your digibyte.conf file?\\n\\nNote: This will delete your current DigiByte Core configuration file and re-create with default settings. Any customisations will be lost. Your DigiByte wallet will not be affected." "${r}" "${c}"; then
            reset_digibyte_conf=true
        else
            reset_digibyte_conf=false
        fi
    fi

    #Display section header
    if [ -f "$DGB_CONF_FILE" ] && [ "$RESET_MODE" = true ] && [ "$reset_digibyte_conf" = true ]; then
        printf " =============== Resetting: digibyte.conf ==============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-configure the digibyte.conf file.\\n" "${INFO}"
        str="Deleting existing digibyte.conf file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $DGB_CONF_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    elif [ -f "$DGB_CONF_FILE" ] && [ "$RESET_MODE" = true ] && [ "$reset_digibyte_conf" = false ]; then
        printf " =============== Checking: digibyte.conf ===============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose NOT to re-configure the digibyte.conf file.\\n" "${INFO}"
    elif [ -f "$DGB_CONF_FILE" ] && [ "$RESET_MODE" = false ]; then
        printf " =============== Checking: digibyte.conf ===============================\\n\\n"
        # ==============================================================================
    else
        printf " =============== Creating: digibyte.conf ===============================\\n\\n"
        # ==============================================================================
    fi

    # Do some intial setup before creating the digibyte.conf file for the first time
    if [ ! -f "$DGB_CONF_FILE" ]; then

        # Max connections are set from the diginode.settings file
        set_maxconnections=$DGB_MAX_CONNECTIONS

        # Increase dbcache size if there is more than ~7Gb of RAM (Default: 450)
        # Initial sync times are significantly faster with a larger dbcache.
        local set_dbcache
        if [ $RAMTOTAL_KB -ge "7340032" ]; then
            str="System RAM exceeds 7GB. Setting dbcache to 2Gb..."
            printf "%b %s" "${INFO}" "${str}"
            set_dbcache=2048
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            set_dbcache=450
        fi

        # generate a random rpc password, if the digibyte.conf file does not exist
 
        local set_rpcpassword
        str="Generating random RPC password..."
        printf "%b %s" "${INFO}" "${str}"
        set_rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # create .digibyte settings folder if it does not already exist
    if [ ! -d $DGB_SETTINGS_LOCATION ]; then
        str="Creating ~/.digibyte folder..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mkdir $DGB_SETTINGS_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If digibyte.conf file already exists, append any missing values. Otherwise create it.
    if test -f "$DGB_CONF_FILE"; then

        # Import variables from digibyte.conf settings file
        str="Located digibyte.conf file. Importing..."
        printf "%b %s" "${INFO}" "${str}"
        source $DGB_CONF_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        printf "%b Checking digibyte.conf settings...\\n" "${INFO}"
        
        #Update daemon variable in settings if it exists and is blank, otherwise append it
        if grep -q "daemon=" $DGB_CONF_FILE; then
            if [ "$daemon" = "" ] || [ "$daemon" = "0" ]; then
                echo "$INDENT   Updating digibyte.conf: daemon=1"
                sed -i -e "/^daemon=/s|.*|daemon=1|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: daemon=1"
            echo "daemon=1" >> $DGB_CONF_FILE
        fi

        #Update dbcache variable in settings file, otherwise append it
        if grep -q "dbcache=" $DGB_CONF_FILE; then
            if [ "$dbcache" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: dbcache=$set_dbcache"
                sed -i -e "/^dbcache=/s|.*|dbcache=$set_dbcache|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: dbcache=$set_dbcache"
            echo "dbcache=$set_dbcache" >> $DGB_CONF_FILE
        fi

        #Update maxconnections variable in settings file, otherwise append it
        if grep -q "maxconnections=" $DGB_CONF_FILE; then
            if [ "$maxconnections" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: maxconnections=$set_maxconnections"
                sed -i -e "/^maxconnections=/s|.*|maxconnections=$set_maxconnections|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: maxconnections=$set_maxconnections"
            echo "maxconnections=$set_maxconnections" >> $DGB_CONF_FILE
        fi

        #Update listen variable in settings if it exists and is blank, otherwise append it
        if grep -q "listen=" $DGB_CONF_FILE; then
            if [ "$listen" = "" ] || [ "$listen" = "0" ]; then
                echo "$INDENT   Updating digibyte.conf: listen=1"
                sed -i -e "/^listen=/s|.*|listen=1|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: listen=1"
            echo "listen=1" >> $DGB_CONF_FILE
        fi

        #Update rpcuser variable in settings if it exists and is blank, otherwise append it
        if grep -q "rpcuser=" $DGB_CONF_FILE; then
            if [ "$rpcuser" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: rpcuser=digibyte"
                sed -i -e "/^rpcuser=/s|.*|rpcuser=digibyte|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: rpcuser=digibyte"
            echo "rpcuser=digibyte" >> $DGB_CONF_FILE
        fi

        #Update rpcpassword variable in settings if variable exists but is blank, otherwise append it
        if grep -q "rpcpassword=" $DGB_CONF_FILE; then
            if [ "$rpcpassword" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: rpcpassword=$set_rpcpassword"
                sed -i -e "/^rpcpassword=/s|.*|rpcpassword=$set_rpcpassword|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: rpcpassword=$set_rpcpassword"
            echo "rpcpassword=$set_rpcpassword" >> $DGB_CONF_FILE
        fi

        #Update server variable in settings if it exists and is blank, otherwise append it
        if grep -q "server=" $DGB_CONF_FILE; then
            if [ "$server" = "" ] || [ "$server" = "0" ]; then
                echo "$INDENT   Updating digibyte.conf: server=1"
                sed -i -e "/^server=/s|.*|server=1|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: server=1"
            echo "server=1" >> $DGB_CONF_FILE
        fi

        #Update rpcport variable in settings if it exists and is blank, otherwise append it
        if grep -q "rpcport=" $DGB_CONF_FILE; then
            if [ "$rpcport" = "" ] || [ "$rpcport" != "14022" ]; then
                echo "$INDENT   Updating digibyte.conf: rpcport=14022"
                sed -i -e "/^rpcport=/s|.*|rpcport=14022|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: rpcport=14022"
            echo "rpcport=14022" >> $DGB_CONF_FILE
        fi

        #Update rpcbind variable in settings if it exists and is blank, otherwise append it
        if grep -q "rpcbind=" $DGB_CONF_FILE; then
            if [ "$rpcbind" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: rpcbind=127.0.0.1"
                sed -i -e "/^rpcbind=/s|.*|rpcbind=127.0.0.1|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: rpcbind=127.0.0.1"
            echo "rpcbind=127.0.0.1" >> $DGB_CONF_FILE
        fi

        #Update rpcallowip variable in settings if it exists and is blank, otherwise append it
        if grep -q "rpcallowip=" $DGB_CONF_FILE; then
            if [ "$rpcallowip" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: rpcallowip=127.0.0.1"
                sed -i -e "/^rpcallowip=/s|.*|rpcallowip=127.0.0.1|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: rpcallowip=127.0.0.1"
            echo "rpcallowip=127.0.0.1" >> $DGB_CONF_FILE
        fi
        printf "%b Completed digibyte.conf checks.\\n" "${TICK}"

    else
        # Create a new digibyte.conf file
        str="Creating ~/.diginode/digibyte.conf file..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_CONF_FILE
        cat <<EOF > $DGB_CONF_FILE
# This config should be placed in the following path:
# ~/.digibyte/digibyte.conf


# [core]
# Run in the background as a daemon and accept commands.
daemon=1

# Set database cache size in megabytes; machines sync faster with a larger cache.
# Recommend setting as high as possible based upon machine's available RAM. (default: 450)
dbcache=$set_dbcache

# Reduce storage requirements by only storing most recent N MiB of block. This mode is 
# incompatible with -txindex and -coinstatsindex. WARNING: Reverting this setting requires
# re-downloading the entire blockchain. (default: 0 = disable pruning blocks, 1 = allow manual
# pruning via RPC, greater than 550 = automatically prune blocks to stay under target size in MiB).
prune=0

# Keep at most <n> unconnectable transactions in memory. (default: 100)
maxorphantx=100

# Keep the transaction memory pool below <n> megabytes. (default: 300)
maxmempool=300

# Specify a non-default location to store blockchain and other data.
datadir=$DGB_DATA_LOCATION


# [network]
# Maintain at most N connections to peers. (default: 125)
maxconnections=$set_maxconnections

# Tries to keep outbound traffic under the given target (in MiB per 24h), 0 = no limit (default: 0)   
maxuploadtarget=0

# Whitelist peers connecting from the given IP address (e.g. 1.2.3.4) or CIDR notated network
# (e.g. 1.2.3.0/24). Use [permissions]address for permissions. Uses same permissions as
# Whitelist Bound IP Address. Can be specified multiple times. Whitelisted peers cannot be
# DoS banned and their transactions are always relayed, even if they are already in the mempool.
# Useful for a gateway node.
whitelist=127.0.0.1

# Accept incoming connections from peers.
listen=1


# [rpc]
# RPC user
rpcuser=digibyte

# RPC password
rpcpassword=$set_rpcpassword

# Accept command line and JSON-RPC commands.
server=1

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
rpcbind=127.0.0.1

# Listen for JSON-RPC connections on this port
rpcport=14022

# Allow JSON-RPC connections from specified source. Valid for <ip> are a single IP (e.g. 1.2.3.4),
# a network/netmask (e.g. 1.2.3.4/255.255.255.0) or a network/CIDR (e.g. 1.2.3.4/24). This option
# can be specified multiple times.
rpcallowip=127.0.0.1


# [wallet]
# Do not load the wallet and disable wallet RPC calls. (Default: 0 = wallet is enabled)
disablewallet=0
EOF
printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    printf "\\n"
}


# A simple function that just the installer title in a box
installer_title_box() {
     clear -x
     echo " ╔════════════════════════════════════════════════════════╗"
     echo " ║                                                        ║"
     echo " ║         ${txtbld}D I G I N O D E   I N S T A L L E R${txtrst}            ║ "
     echo " ║                                                        ║"
     echo " ║  Install and configure your DigiByte & DigiAsset Node  ║"
     echo " ║                                                        ║"
     echo " ╚════════════════════════════════════════════════════════╝" 
     echo ""
}

diginode_logo() {
echo ""
echo -e "${txtblu}
                       ƊƊƊƊƊƊƊ                       
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ              
            ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ          
         ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       
       ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   ƊƊ    ƊƊƊƊƊƊƊƊƊƊƊ     
     ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ    Ɗ    ƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   
    ƊƊƊƊƊƊƊƊƊ                           ƊƊƊƊƊƊƊƊƊ  
   ƊƊƊƊƊƊƊƊ                               ƊƊƊƊƊƊƊƊ 
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ        ƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       ƊƊƊƊƊƊƊƊƊ        ƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       ƊƊƊƊƊƊƊƊƊ        ƊƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       ƊƊƊƊƊƊƊƊƊ        ƊƊƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊ       ƊƊƊƊƊƊƊƊ        ƊƊƊƊƊƊƊƊƊƊƊƊƊ
   ƊƊƊƊƊƊƊƊƊƊ#       ƊƊƊƊ          ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ 
    ƊƊƊƊƊƊƊƊ.                   ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ  
     ƊƊƊƊƊƊ              ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   
       ƊƊƊƊƊƊƊ    ƊƊ   ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ     
         ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       
            ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ          
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   ${txtrst}${txtbld}"
echo -e "       ____   _         _   _   __            __     "             
echo -e "      / __ \ (_)____ _ (_) / | / /____   ____/ /___  "
echo -e "     / / / // // __ '// / /  |/ // __ \ / __  // _ \ "
echo -e "    / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/ "
echo -e "   /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/  "
echo -e "              /____/                                 ${txtrst}"
echo    ""
}

diginode_logo_v2() {
echo ""
echo -e "${txtblu}
                       ƊƊƊƊƊƊƊ
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ
            ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ
         ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       
       ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}####${txtblu}Ɗ${txtrst}####${txtblu}ƊƊƊƊƊƊƊƊƊƊƊ     
     ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}####${txtblu}Ɗ${txtrst}####${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   
    ƊƊƊƊƊƊƊƊƊ${txtrst}###########################${txtblu}ƊƊƊƊƊƊƊƊƊ  
   ƊƊƊƊƊƊƊƊ${txtrst}###############################${txtblu}ƊƊƊƊƊƊƊƊ 
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}########${txtblu}ƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}#######${txtblu}ƊƊƊƊƊƊƊƊƊ${txtrst}########${txtblu}ƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}#######${txtblu}ƊƊƊƊƊƊƊƊƊ${txtrst}########${txtblu}ƊƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}#######${txtblu}ƊƊƊƊƊƊƊƊƊ${txtrst}########${txtblu}ƊƊƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}#######${txtblu}ƊƊƊƊƊƊƊƊ${txtrst}########${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊ
   ƊƊƊƊƊƊƊƊƊƊƊ${txtrst}#######${txtblu}ƊƊƊƊ${txtrst}##########${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ 
    ƊƊƊƊƊƊƊƊ${txtrst}#####################${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ  
     ƊƊƊƊƊƊ${txtrst}##############${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   
       ƊƊƊƊƊƊƊ${txtrst}####${txtblu}ƊƊ${txtrst}###${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ     
         ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       
            ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ          
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   ${txtrst}${txtbld}"
echo -e "       ____   _         _   _   __            __     "             
echo -e "      / __ \ (_)____ _ (_) / | / /____   ____/ /___  "
echo -e "     / / / // // __ '// / /  |/ // __ \ / __  // _ \ "
echo -e "    / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/ "
echo -e "   /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/  "
echo -e "              /____/                                 ${txtrst}"
echo    ""
}

diginode_logo_v3() {
echo ""
echo -e "${txtblu}
                       ƊƊƊƊƊƊƊ
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ
            ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ
         ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       
       ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊ${txtblu}Ɗ${txtrst}ƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊ     
     ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊ${txtblu}Ɗ${txtrst}ƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   
    ƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊ  
   ƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊ 
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊ
  ƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊ
   ƊƊƊƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ 
    ƊƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ  
     ƊƊƊƊƊƊ${txtrst}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   
       ƊƊƊƊƊƊƊ${txtrst}ƊƊƊƊ${txtblu}ƊƊ${txtrst}ƊƊƊ${txtblu}ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ     
         ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       
            ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ          
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   ${txtrst}${txtbld}"
echo -e "       ____   _         _   _   __            __     "             
echo -e "      / __ \ (_)____ _ (_) / | / /____   ____/ /___  "
echo -e "     / / / // // __ '// / /  |/ // __ \ / __  // _ \ "
echo -e "    / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/ "
echo -e "   /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/  "
echo -e "              /____/                                 ${txtrst}"
echo    ""
}

make_temporary_log() {
    # Create a random temporary file for the log
    TEMPLOG=$(mktemp /tmp/diginode_temp.XXXXXX)
    # Open handle 3 for templog
    # https://stackoverflow.com/questions/18460186/writing-outputs-to-log-file-and-console
    exec 3>"$TEMPLOG"
    # Delete templog, but allow for addressing via file handle
    # This lets us write to the log without having a temporary file on the drive, which
    # is meant to be a security measure so there is not a lingering file on the drive during the install process
    rm "$TEMPLOG"
}

is_command() {
    # Checks to see if the given command (passed as a string argument) exists on the system.
    # The function returns 0 (success) if the command exists, and 1 if it doesn't.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}

# Function to establish OS type and system architecture
# These checks are a work in progress since we need more hardware/OS combinations to test against
# Currently BSD is not being supported. I am unclear if we can run DigiNode on it.

sys_check() {
    # Lookup OS type, and only continue if the user is running linux
    local is_linux
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux detected
        printf "%b OS Type: %bLinux GNU%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        is_linux="yes"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        printf "%b OS Type: %bMacOS%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
    elif [[ "$OSTYPE" == "cygwin" ]]; then
        # POSIX compatibility layer and Linux environment emulation for Windows
        printf "%b OS Type: %bWindows (Cygwin)%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
    elif [[ "$OSTYPE" == "msys" ]]; then
        printf "%b OS Type: %bWindows (msys)%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
        # bsd detected
    elif [[ "$OSTYPE" == "bsd" ]]; then
        printf "  %b OS Type: %bBSD%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
        # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
    elif [[ "$OSTYPE" == "win32" ]]; then
        # I'm not sure this can happen.
        printf "%b OS Type: %bWindows%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
    elif [[ "$OSTYPE" == "freebsd"* ]]; then
        printf "%b OS Type: %bFreeBSD%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
        # solaris detected
    elif [[ "$OSTYPE" == "solaris" ]]; then
        printf "%b OS Type: %bSolaris%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
    else
        # Unknown.
        printf "%b OS Type: %bUnknown - $OSTYPE%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        is_linux="no"
    fi

    if [ "$is_linux" = "no" ]; then 
        printf "\\n"
        printf "%b %bERROR: OS is unsupported%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b DigiNode Installer requires a Linux OS with a a 64-bit kernel (aarch64 or X86_64)\\n" "${INDENT}"
        printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
        printf "%b should be supported please contact @digibytehelp on Twitter including\\n" "${INDENT}"
        printf "%b the OS type: $OSTYPE\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # Try to establish system architecture, and only continue if it is 64 bit

    # only run this check if the 'arch' command is present on the system
    if is_command arch ; then
        local sysarch
        local is_64bit
        sysarch=$(arch)

        # Try and identify 64bit OS's
        if [[ "$sysarch" == "aarch64" ]]; then
            printf "%b Architecture: %b$sysarch%b" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            ARCH="aarch64"
            is_64bit="yes"
        elif [[ "$sysarch" == "arm"* ]]; then
            printf "%b Architecture: %b$sysarch%b" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            is_64bit="no32"
        elif [ "$sysarch" = "x86_64" ]; then
            printf "%b Architecture: %b$sysarch%b" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            ARCH="x86_64"
            is_64bit="yes"
        elif [ "$sysarch" = "x86_32" ]; then
            printf "%b Architecture: %b$sysarch%b" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            is_64bit="no32"
        else
            printf "%b Architecture: %b$sysarch%b" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            is_64bit="no"
        fi

        if [ "$is_64bit" = "yes" ]; then
            printf "    %b %b64-bit OS%b\n" "${TICK}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
        else
            printf "    %b 64-bit OS\n" "${CROSS}"
            printf "\n" 
        fi


        if [[ "$is_64bit" == "no32" ]]; then
            printf "%b %bERROR: 32-bit OS detected - 64-bit required%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b DigiNode Installer requires a 64-bit Linux OS (aarch64 or X86_64)\\n" "${INDENT}"
            printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
            printf "%b should be supported please contact @digibytehelp on Twitter letting me\\n" "${INDENT}"
            printf "%b know the reported system architecture above.\\n" "${INDENT}"
            printf "\\n"
            # If it's linux running on ARM and...
            if [[ "$sysarch" == "arm"* ]] && [[ "$OSTYPE" == "linux-gnu"* ]]; then
                # ...if it's Raspbian buster, show the instructions to upgrade the kernel to 64-bit.
                if [[ $(lsb_release -is) = "Raspbian" ]] && [[ $(lsb_release -cs) = "buster" ]]; then
                    printf "%b Since you are running Raspberry Pi OS, you can install the 64-bit kernel\\n" "${INFO}"
                    printf "%b by copying the command below and pasting into the terminal.\\n" "${INDENT}"
                    printf "%b Your Pi will restart with the 64-bit kernel. Then run the installer again.\\n" "${INDENT}"
                    printf "%b For more information, visit: $DGBH_URL_RPIOS64\\n" "${INDENT}"
                    printf "\\n"
                    printf "%b sudo apt update && sudo apt upgrade && echo \"arm_64bit=1\" | sudo tee -a /boot/config.txt && sudo systemctl reboot\\n" "${INDENT}"
                    printf "\n"

                fi
            fi
            exit 1
        elif [[ "$is_64bit" == "no" ]]; then
            printf "%b %bERROR: Unrecognised system architecture%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b DigiNode Installer requires a 64-bit OS (aarch64 or X86_64)\\n" "${INDENT}"
            printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
            printf "%b should be supported please contact @digibytehelp on Twitter letting me\\n" "${INDENT}"
            printf "%b know the reported system architecture above.\\n" "${INDENT}"
            printf "\\n"
            exit 1
        fi
    else
        printf "%b %b$ERROR: Unable to perform check for 64-bit OS - arch command is not present%b" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    fi
}


# Function to check for compatible Raspberry Pi hardware
rpi_check() {

sysarch=$(arch)

if [[ "$sysarch" == "aarch"* ]] || [[ "$sysarch" == "arm"* ]]; then

    # check the 'tr' command is available
    if ! is_command tr ; then
        printf "%b %bERROR: Unable to check for Raspberry Pi hardware - 'tr' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    fi

    # check the 'tr' command is available
    if ! is_command grep ; then
        printf "%b %bERROR: Unable to check for Raspberry Pi hardware - 'grep' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    fi

    # Store device model in variable
    MODEL=$(tr -d '\0' < /proc/device-tree/model)

    # Store device revision in local variable (used to work out which Pi model it is)
    local revision
    revision=$(cat /proc/cpuinfo | grep Revision | cut -d' ' -f2)

    # Store total system RAM in whole Gb. Append 'b' to it so it says Gb. (Used for future Pi models we don't know about yet)
    MODELMEM="${RAMTOTAL_HR}b"

    ######### RPI MODEL DETECTION ###################################

    # Create local variables to store the pitype and pigen
    local pitype
    local pigen

    # Look for any mention of 'Raspberry Pi' so we at least know it is a Pi 
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi" || echo "")
    if [[ $pigen == "Raspberry Pi" ]]; then
        pitype="pi"
    fi
    
    # Look for any mention of 'Raspberry Pi 5' so we can narrow it to Pi 5
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 5" || echo "")
    if [[ $pigen == "Raspberry Pi 5" ]]; then
        pitype="pi5"
    fi

    # Look for any mention of 'Raspberry Pi 4' so we can narrow it to a Pi 4 
    # even if it is a model we have not seen before
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 4" || echo "")
    if [[ $pigen = "Raspberry Pi 4" ]]; then
        pitype="pi4"
    fi

    # Assuming it is likely a Pi, lookup the known models of Rasberry Pi hardware 
    if [ "$pitype" != "" ]; then
        if [ $revision = 'd03114' ]; then #Pi 4 8Gb
            pitype="pi4"
            MODELMEM="8Gb"
        elif [ $revision = 'c03130' ]; then #Pi 400 4Gb
            pitype="pi4"
            MODELMEM="4Gb"
        elif [ $revision = 'c03112' ]; then #Pi 4 4Gb
            pitype="pi4"
            MODELMEM="4Gb"
        elif [ $revision = 'c03111' ]; then #Pi 4 4Gb
            pitype="pi4"
            MODELMEM="4Gb"
        elif [ $revision = 'b03112' ]; then #Pi 4 2Gb
            pitype="pi4_lowmem"
            MODELMEM="2Gb"
        elif [ $revision = 'b03111' ]; then #Pi 4 2Gb
            pitype="pi4_lowmem"
            MODELMEM="2Gb"
        elif [ $revision = 'a03111' ]; then #Pi 4 1Gb
            pitype="pi4_lowmem"
            MODELMEM="1Gb"
        elif [ $revision = 'a020d3' ]; then #Pi 3 Model B+ 1Gb
            pitype="pi3"
            MODELMEM="1Gb"
        elif [ $revision = 'a22082' ]; then #Pi 3 Model B 1Gb
            pitype="pi3"
            MODELMEM="1Gb"
        elif [ $revision = 'a02082' ]; then #Pi 3 Model B 1Gb
            pitype="pi3"
            MODELMEM="1Gb"
        elif [ $revision = '9000C1' ]; then #Pi Zero W 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '900093' ]; then #Pi Zero v1.3 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '900092' ]; then #Pi Zero v1.2 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = 'a22042' ]; then #Pi 2 Model B v1.2 1Gb
            pitype="piold"
            MODELMEM="1Gb"
        elif [ $revision = 'a21041' ]; then #Pi 2 Model B v1.1 1Gb
            pitype="piold"
            MODELMEM="1Gb"
        elif [ $revision = 'a01041' ]; then #Pi 2 Model B v1.1 1Gb
            pitype="piold"
            MODELMEM="1Gb"
        elif [ $revision = '0015' ]; then #Pi Model A+ 512Mb / 256Mb
            pitype="piold"
            # the same revision number was used for both the 512Mb and 256Mb models so lets check which is which
            local pi0015ram
            pi0015ram=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
            if [ "$pi0015ram" -gt "300000" ]; then
                MODELMEM="512Mb"
            else
                MODELMEM="256Mb"
            fi
            MODELMEM="512Mb / 256Mb"
        elif [ $revision = '0012' ]; then #Pi Model A+ 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0014' ]; then #Pi Computer Module 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '0011' ]; then #Pi Compute Module 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '900032' ]; then #Pi Module B+ 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '0013' ]; then #Pi Module B+ 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '0010' ]; then #Pi Module B+ 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '000d' ]; then #Pi Module B Rev 2 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '000e' ]; then #Pi Module B Rev 2 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '000f' ]; then #Pi Module B Rev 2 512Mb
            pitype="piold"
            MODELMEM="512Mb"
        elif [ $revision = '0007' ]; then #Pi Module A 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0008' ]; then #Pi Module A 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0009' ]; then #Pi Module A 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0004' ]; then #Pi Module B Rev 2 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0005' ]; then #Pi Module B Rev 2 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0006' ]; then #Pi Module B Rev 2 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0003' ]; then #Pi Module B Rev 1 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        elif [ $revision = '0002' ]; then #Pi Module B Rev 1 256Mb
            pitype="piold"
            MODELMEM="256Mb"
        fi
    fi

    # Generate Pi hardware read out
    if [ "$pitype" = "pi5" ]; then
        printf "%b Raspberry Pi 5 Detected\\n" "${TICK}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        if [[ "$RUN_INSTALLER" != "NO" ]] ; then
            printf "\\n"
            rpi_microsd_check
        fi
        printf "\\n"
    elif [ "$pitype" = "pi4" ]; then
        printf "%b Raspberry Pi 4 Detected\\n" "${TICK}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        if [[ "$RUN_INSTALLER" != "NO" ]] ; then
            printf "\\n"
            rpi_microsd_check
        fi
        printf "\\n"
    elif [ "$pitype" = "pi4_lowmem" ]; then
        printf "%b Raspberry Pi 4 Detected   [ %bLOW MEMORY DEVICE!!%b ]\\n" "${TICK}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        # hide this part if running digimon
        if [[ "$RUN_INSTALLER" != "NO" ]] ; then
            printf "\\n"
            printf "%b %bWARNING: Low Memory Device%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b You should be able to run a DigiNode on this Pi but performance may suffer\\n" "${INDENT}"   
            printf "%b due to this model only having $MODELMEM RAM. You will need a swap file.\\n" "${INDENT}"
            printf "%b A Raspberry Pi 4 with at least 4Gb is recommended. 8Gb or more is preferred.\\n" "${INDENT}"
            printf "\\n"
            rpi_microsd_check
        fi
        printf "\\n"
    elif [ "$pitype" = "pi3" ]; then
        printf "%b Raspberry Pi 3 Detected   [ %bLOW MEMORY DEVICE!!%b ]\\n" "${TICK}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        # hide this part if running digimon
        IS_RPI="YES"
        if [[ "$RUN_INSTALLER" != "NO" ]] ; then
            printf "\\n"
            printf "%b %bWARNING: Low Memory Device%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b You may be able to run a DigiNode on this Pi but performance may suffer\\n" "${INDENT}"   
            printf "%b due to this model only having $MODELMEM RAM. You will need a swap file.\\n" "${INDENT}"
            printf "%b A Raspberry Pi 4 with at least 4Gb is recommended. 8Gb or more is preferred.\\n" "${INDENT}"
            printf "\\n"
            rpi_microsd_check     
        fi
        printf "\\n"
    elif [ "$pitype" = "piold" ]; then
        printf "%b %bERROR: Raspberry Pi 2 (or older) Detected%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bThis Raspberry Pi is too old to run a DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b A Raspberry Pi 4 with at least 4Gb is recommended. 8Gb or more is preferred.\\n" "${INDENT}"
        printf "\\n"
        exit 1
    elif [ "$pitype" = "pi" ]; then
        printf "\\n"
        printf "%b %bERROR: Unknown Raspberry Pi Detected%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b This script is currently unable to recognise your Raspberry Pi.\\n" "${INDENT}"
        printf "%b Presumably this is because it is a new model that it has not seen before.\\n" "${INDENT}"
        printf "\\n"
        printf "%b Please contact @digibytehelp on Twitter including the following information\\n" "${INDENT}"
        printf "%b so that support for it can be added:\\n" "${INDENT}"
        printf "\\n"
        printf "%b Model: %b$MODEL%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Memory: %b$MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Revision: %b$revision%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        exit 1
    fi
else
    if [ $VERBOSE_MODE = true ]; then
        printf "%b Raspberry Pi NOT Detected - no ARM processor found\\n" "${INFO}"
        printf "\\n"
    fi
fi

}

# This will check if the Raspbery Pi is booting from a microSD card, rather than an external drive connected via USB
rpi_microsd_check() {
    # Only display this message if running this install script directly (not when running diginode.sh)
    if [[ "$RUN_INSTALLER" != "NO" ]] ; then

        local usb_drive=$(df | grep boot | grep -oa sda)
        local microsd_drive=$(df | grep boot | grep -oa mmcblk0)

        str="Boot Check: "
        printf "%b %s" "${INFO}" "${str}"

        # Check for hdd/ssd boot drive
        if [[ "$usb_drive" == "sda" ]]; then
            printf "%b%b %s %bPASSED%b   Raspberry Pi is booting from an external USB Drive\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b   Note: While booting from an HDD will work, an SSD is stongly recommended.\\n" "${INDENT}"
            printf "\\n"
            IS_MICROSD="NO"
        fi
        # Check for micro sd boot drive
        if [[ "$microsd_drive" == "mmcblk0" ]]; then
            if [[ "$MODELMEM" = "1Gb" ]] || [[ "$MODELMEM" = "2Gb" ]] || [[ "$MODELMEM" = "4Gb" ]]; then
                printf "%b%b %s %bFAILED%b   Raspberry Pi is booting from a microSD card\\n" "${OVER}" "${CROSS}" "${str}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bERROR: Running a DigiNode from a microSD card is not supported%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b Since your Raspberry Pi has $MODELMEM you need to be booting from an SSD drive.\\n" "${INFO}" "${COL_NC}"
                printf "%b It requires at least 6Gb RAM in order to run a DigiNode, and the microSD card\\n" "${INDENT}"
                printf "%b is too slow to run both the DigiNode and the swap file together.\\n" "${INDENT}"
                printf "%b Please use an external SSD drive connected via USB. For help on what\\n" "${INDENT}"
                printf "%b hardware you need, visit:\\n" "${INDENT}"
                printf "%b   $DGBH_URL_HARDWARE\\n" "${INDENT}"
                printf "\\n"
                exit 1
            else
                printf "%b%b %s %bFAILED%b   Raspberry Pi is booting from a microSD card\\n" "${OVER}" "${CROSS}" "${str}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bWARNING: Running a DigiNode from a microSD card is not recommended%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b It is strongly recommended to use an external SSD drive connected via USB\\n" "${INDENT}"
                printf "%b to run a DigiNode on a Raspberry Pi - using a microSD card is inadvisable.\\n" "${INDENT}"
                printf "%b MicroSD cards are prone to corruption and perform significantly slower.\\n" "${INDENT}"
                printf "%b For help on what hardware you need, visit:\\n" "${INDENT}"
                printf "%b   $DGBH_URL_HARDWARE\\n" "${INDENT}"
                printf "\\n"
                IS_MICROSD="YES"
                STARTPAUSE="YES"
            fi
        fi
    fi
}

# If the user is using a Raspberry Pi, show some microSD warnings
rpi_microsd_ask() {

# If this is a Raspberry Pi, booting from a microSD, advise that it is better to use an SSD.
if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]] ; then

    if whiptail --backtitle "" --title "Raspberry Pi is booting from microSD" --yesno "WARNING: You are currently booting your Raspberry Pi from a microSD card.\\n\\nIt is strongly recommended to use a Solid State Drive (SSD) connected via USB for your DigiNode. A conventional Hard Disk Drive (HDD) will also work, but an SSD is preferred, being faster and more robust.\\n\\nMicroSD cards are prone to corruption and perform significantly slower than an SSD or HDD.\\n\\nFor advice on what hardware to get for your DigiNode, visit:\\n$DGBH_URL_HARDWARE\\n\\n\\n\\nChoose Yes to indicate that you have understood this message, and wish to continue installing on the microSD card." --defaultno "${r}" "${c}"; then
    #Nothing to do, continue
      echo
    else
      printf "%b Installer exited at microSD warning message.\\n" "${INFO}"
      printf "\\n"
      exit
    fi
fi

# If they are booting their Pi from SSD, warn to unplug the microSD card, if present (just to double check!)
if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "NO" ]] ; then
        
        whiptail --msgbox --backtitle "" --title "Remove the microSD card from the Raspberry Pi." "If there is a microSD card in the slot on the Raspberry Pi, please remove it now. It will not be required." 9 "${c}"
fi

}

# Compatibility
package_manager_detect() {

# Does avahi daemon need to be installed? (this only gets installed if the hostname is set to 'diginode')
if [[ "$INSTALL_AVAHI" = "YES" ]]; then
    avahi_package="avahi-daemon"
else
    avahi_package=""
fi

# If apt-get is installed, then we know it's part of the Debian family
if is_command apt-get ; then
    # Set some global variables here
    # We don't set them earlier since the family might be Red Hat, so these values would be different
    PKG_MANAGER="apt-get"
    # A variable to store the command used to update the package cache
    UPDATE_PKG_CACHE="${PKG_MANAGER} update"
    # The command we will use to actually install packages
    PKG_INSTALL=("${PKG_MANAGER}" -qq --no-install-recommends install)
    # grep -c will return 1 if there are no matches. This is an acceptable condition, so we OR TRUE to prevent set -e exiting the script.
    PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"
    # Update package cache. This is required already here to assure apt-cache calls have package lists available.
    update_package_cache || exit 1
    # Debian 7 doesn't have iproute2 so check if it's available first
    if apt-cache show iproute2 > /dev/null 2>&1; then
        iproute_pkg="iproute2"
    # Otherwise, check if iproute is available
    elif apt-cache show iproute > /dev/null 2>&1; then
        iproute_pkg="iproute"
    # Else print error and exit
    else
        printf "%b Aborting installation: iproute2 and iproute packages were not found in APT repository.\\n" "${CROSS}"
        exit 1
    fi
 
    # Packages required to perfom the system check (stored as an array)
    SYS_CHECK_DEPS=(grep dnsutils)
    # Packages required to run this install script (stored as an array)
    INSTALLER_DEPS=(git "${iproute_pkg}" jq whiptail)
    # Packages required to run DigiNode (stored as an array)
    DIGINODE_DEPS=(cron curl iputils-ping lsof netcat psmisc sudo unzip idn2 sqlite3 libcap2-bin dns-root-data libcap2 "$avahi_package" )

    # This function waits for dpkg to unlock, which signals that the previous apt-get command has finished.
    test_dpkg_lock() {
        i=0
        # fuser is a program to show which processes use the named files, sockets, or filesystems
        # So while the lock is held,
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1
        do
            # we wait half a second,
            sleep 0.5
            # increase the iterator,
            ((i=i+1))
        done
        # and then report success once dpkg is unlocked.
        return 0
    }

# If apt-get is not found, check for rpm to see if it's a Red Hat family OS
elif is_command rpm ; then
    # Then check if dnf or yum is the package manager
    if is_command dnf ; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi

    # These variable names match the ones in the Debian family. See above for an explanation of what they are for.
    PKG_INSTALL=("${PKG_MANAGER}" install -y)
    PKG_COUNT="${PKG_MANAGER} check-update | egrep '(.i686|.x86|.noarch|.arm|.src)' | wc -l"
    SYS_CHECK_DEPS=(grep bind-utils)
    INSTALLER_DEPS=(git iproute newt procps-ng which chkconfig ca-certificates jq)
    DIGINODE_DEPS=(cronie curl findutils nmap-ncat sudo unzip libidn2 psmisc sqlite libcap lsof "$avahi_package" )

# If neither apt-get or yum/dnf package managers were found
else
    # it's not an OS we can support,
    printf "%b OS distribution not supported\\n" "${CROSS}"
    # so exit the installer
    exit
fi
}

# Let user know if they have outdated packages on their system and
# advise them to run a package update at soonest possible.
notify_package_updates_available() {
    # Local, named variables
    local str="Checking ${PKG_MANAGER} for upgraded packages"
    printf "\\n%b %s..." "${INFO}" "${str}"
    # Store the list of packages in a variable
    updatesToInstall=$(eval "${PKG_COUNT}")

    if [[ -d "/lib/modules/$(uname -r)" ]]; then
        if [[ "${updatesToInstall}" -eq 0 ]]; then
            printf "%b%b %s... up to date!\\n\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b%b %s... %s updates available\\n" "${OVER}" "${TICK}" "${str}" "${updatesToInstall}"
            echo ""
            printf "%b %bIt is recommended to update your OS after installing DigiNode.%b\\n\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        fi
    else
        printf "%b %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        printf "    Kernel update detected. If the install fails, please reboot and try again\\n"
    fi
}

update_package_cache() {
    # Running apt-get update/upgrade with minimal output can cause some issues with
    # requiring user input (e.g password for phpmyadmin see #218)

    # Update package cache on apt based OSes. Do this every time since
    # it's quick and packages can be updated at any time.

    # Local, named variables
    local str="Update local cache of available packages"
    printf "%b %s..." "${INFO}" "${str}"
    # Create a command from the package cache variable
    if eval "${UPDATE_PKG_CACHE}" &> /dev/null; then
        printf "%b%b %s" "${OVER}" "${TICK}" "${str}"
    else
        # Otherwise, show an error and exit
        printf "%b%b %s\\n" "${OVER}" "${CROSS}" "${str}"
        printf "  %bError: Unable to update package cache. Please try \"%s\"%b" "${COL_LIGHT_RED}" "sudo ${UPDATE_PKG_CACHE}" "${COL_NC}"
        return 1
    fi
}

install_dependent_packages() {

    # Install packages passed in via argument array
    # No spinner - conflicts with set -e
    declare -a installArray

    # Debian based package install - debconf will download the entire package list
    # so we just create an array of packages not currently installed to cut down on the
    # amount of download traffic.
    # NOTE: We may be able to use this installArray in the future to create a list of package that were
    # installed by us, and remove only the installed packages, and not the entire list.
    if is_command apt-get ; then
        # For each package, check if it's already installed (and if so, don't add it to the installArray)
        for i in "$@"; do
            printf "%b Checking for %s..." "${INFO}" "${i}"
            if dpkg-query -W -f='${Status}' "${i}" 2>/dev/null | grep "ok installed" &> /dev/null; then
                printf "%b  %b Checking for %s\\n" "${OVER}" "${TICK}" "${i}"
            else
                printf "%b  %b Checking for %s (will be installed)\\n" "${OVER}" "${INFO}" "${i}"
                installArray+=("${i}")
            fi
        done
        # If there's anything to install, install everything in the list.
        if [[ "${#installArray[@]}" -gt 0 ]]; then
            test_dpkg_lock
            printf "%b Processing %s install(s) for: %s, please wait...\\n" "${INFO}" "${PKG_MANAGER}" "${installArray[*]}"
            printf '%*s\n' "$columns" '' | tr " " -;
            "${PKG_INSTALL[@]}" "${installArray[@]}"
            printf '%*s\n' "$columns" '' | tr " " -;
            return
        fi
        printf "\\n"
        return 0
    fi

    # Install Fedora/CentOS packages
    for i in "$@"; do
    # For each package, check if it's already installed (and if so, don't add it to the installArray)
        printf "  %b Checking for %s..." "${INFO}" "${i}"
        if "${PKG_MANAGER}" -q list installed "${i}" &> /dev/null; then
            printf "%b  %b Checking for %s\\n" "${OVER}" "${TICK}" "${i}"
        else
            printf "%b  %b Checking for %s (will be installed)\\n" "${OVER}" "${INFO}" "${i}"
            installArray+=("${i}")
        fi
    done
    # If there's anything to install, install everything in the list.
    if [[ "${#installArray[@]}" -gt 0 ]]; then
        printf "%b Processing %s install(s) for: %s, please wait...\\n" "${INFO}" "${PKG_MANAGER}" "${installArray[*]}"
        printf '%*s\n' "$columns" '' | tr " " -;
        "${PKG_INSTALL[@]}" "${installArray[@]}"
        printf '%*s\n' "$columns" '' | tr " " -;
        return
    fi
    printf "\\n"
    return 0
}

# Check that this OS is supported
os_check() {
    if [ "$DIGINODE_SKIP_OS_CHECK" != true ]; then
        # This function gets a list of supported OS versions from a TXT record at diginode-versions.digibyte.help
        # and determines whether or not the script is running on one of those systems
        local remote_os_domain valid_os valid_version valid_response detected_os detected_version display_warning cmdResult digReturnCode response
        remote_os_domain=${OS_CHECK_DOMAIN_NAME:-"$DGNT_VERSIONS_URL"}

        detected_os=$(grep "\bID\b" /etc/os-release | cut -d '=' -f2 | tr -d '"')
        detected_version=$(grep VERSION_ID /etc/os-release | cut -d '=' -f2 | tr -d '"')

        cmdResult="$(dig +short -t txt "${remote_os_domain}" @8.8.8.8 2>&1; echo $?)"
        # Gets the return code of the previous command (last line)
        digReturnCode="${cmdResult##*$'\n'}"

        if [ ! "${digReturnCode}" == "0" ]; then
            valid_response=false
        else
            # Dig returned 0 (success), so get the actual response, and loop through it to determine if the detected variables above are valid
            response="${cmdResult%%$'\n'*}"
            # If the value of ${response} is a single 0, then this is the return code, not an actual response.
            if [ "${response}" == 0 ]; then
                valid_response=false
            fi

            IFS=" " read -r -a supportedOS < <(echo "${response}" | tr -d '"')
            for distro_and_versions in "${supportedOS[@]}"
            do
                distro_part="${distro_and_versions%%=*}"
                versions_part="${distro_and_versions##*=}"

                # If the distro part is a (case-insensistive) substring of the computer OS
                if [[ "${detected_os^^}" =~ ${distro_part^^} ]]; then
                    valid_os=true
                    IFS="," read -r -a supportedVer <<<"${versions_part}"
                    for version in "${supportedVer[@]}"
                    do
                        if [[ "${detected_version}" =~ $version ]]; then
                            valid_version=true
                            break
                        fi
                    done
                    break
                fi
            done
        fi

        if [ "$valid_os" = true ] && [ "$valid_version" = true ] && [ ! "$valid_response" = false ]; then
            display_warning=false
        fi

        if [ "$display_warning" != false ]; then
            if [ "$valid_response" = false ]; then

                if [ "${digReturnCode}" -eq 0 ]; then
                    errStr="dig succeeded, but response was blank. Please contact support"
                else
                    errStr="dig failed with return code ${digReturnCode}"
                fi
                printf "%b %bRetrieval of supported OS list failed. %s. %b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${errStr}" "${COL_NC}"
                printf "%b %bUnable to determine if the detected OS (%s %s) is supported%b\\n"  "${INDENT}" "${COL_LIGHT_RED}" "${detected_os^}" "${detected_version}" "${COL_NC}"
                printf "%b Possible causes for this include:\\n" "${INDENT}" 
                printf "%b  - Firewall blocking certain DNS lookups from DigiNode device\\n" "${INDENT}" 
                printf "%b  - Google DNS (8.8.8.8) being blocked (required to obtain TXT record from ${DGNT_VERSIONS_URL} containing supported OS)\\n" "${INDENT}" 
                printf "%b  - Other internet connectivity issues\\n" "${INDENT}"
            else
                printf "%b %bUnsupported OS detected: %s %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${detected_os^}" "${detected_version}" "${COL_NC}"
                printf "%b If you are seeing this message and you believe your OS should be supported, please contact @digibytehelp on Twitter.\\n" "${INDENT}" 
            fi
            printf "\\n"
            printf "%b %bhttps://digibyte.help/diginode%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b If you wish to attempt to continue anyway, you can try one of the following commands to skip this check:\\n" "${INDENT}" 
            printf "\\n"
            printf "%b e.g: If you are seeing this message on a fresh install, you can run:\\n" "${INDENT}" 
            printf "%b   %bcurl -sSL $DGNT_INSTALLER_URL | DIGINODE_SKIP_OS_CHECK=true sudo -E bash%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b It is possible that the installation will still fail at this stage due to an unsupported configuration.\\n" "${INDENT}" 
            printf "%b %bIf that is the case, feel free to ask @digibytehelp on Twitter.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            exit 1

        else
            printf "%b %bSupported OS detected%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            echo ""
        fi
    else
        printf "%b %bDIGINODE_SKIP_OS_CHECK env variable set to true - installer will continue%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    fi
}

# SELinux
checkSelinux() {
    local DEFAULT_SELINUX
    local CURRENT_SELINUX
    local SELINUX_ENFORCING=0
    # Check for SELinux configuration file and getenforce command
    if [[ -f /etc/selinux/config ]] && command -v getenforce &> /dev/null; then
        # Check the default SELinux mode
        DEFAULT_SELINUX=$(awk -F= '/^SELINUX=/ {print $2}' /etc/selinux/config)
        case "${DEFAULT_SELINUX,,}" in
            enforcing)
                printf "%b %bDefault SELinux: %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${DEFAULT_SELINUX}" "${COL_NC}"
                SELINUX_ENFORCING=1
                ;;
            *)  # 'permissive' and 'disabled'
                printf "%b %bDefault SELinux: %s%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${DEFAULT_SELINUX}" "${COL_NC}"
                ;;
        esac
        # Check the current state of SELinux
        CURRENT_SELINUX=$(getenforce)
        case "${CURRENT_SELINUX,,}" in
            enforcing)
                printf "%b %bCurrent SELinux: %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${CURRENT_SELINUX}" "${COL_NC}"
                SELINUX_ENFORCING=1
                ;;
            *)  # 'permissive' and 'disabled'
                printf "%b %bCurrent SELinux: %s%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${CURRENT_SELINUX}" "${COL_NC}"
                ;;
        esac
    else
        echo -e "${INFO} ${COL_GREEN}SELinux not detected${COL_NC}\\n";
    fi
    # Exit the installer if any SELinux checks toggled the flag
    if [[ "${SELINUX_ENFORCING}" -eq 1 ]] && [[ -z "${DIGINODE_SELINUX}" ]]; then
        printf "%b DigiNode does not provide an SELinux policy as the required changes modify the security of your system.\\n" "${INDENT}" 
        printf "%b Please refer to https://wiki.centos.org/HowTos/SELinux if SELinux is required for your deployment.\\n" "${INDENT}" 
        printf "%b  This check can be skipped by setting the environment variable %bDIGINODE_SELINUX%b to %btrue%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b  e.g: export DIGINODE_SELINUX=true\\n" "${INDENT}" 
        printf "%b  By setting this variable to true you acknowledge there may be issues with DigiNode during or after the install\\n" "${INDENT}" 
        printf "\\n%b  %bSELinux Enforcing detected, exiting installer%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}";
        printf "\\n"
        exit 1;
    elif [[ "${SELINUX_ENFORCING}" -eq 1 ]] && [[ -n "${DIGINODE_SELINUX}" ]]; then
        printf "%b %bSELinux Enforcing detected%b. DIGINODE_SELINUX env variable set - installer will continue\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
    fi
}

# Function to check if the hostname of the machine is set to 'diginode'
hostname_check() {

if [[ "$HOSTNAME" == "diginode" ]]; then
    printf "%b Hostname Check: %bPASSED%b   Hostname is set to 'diginode'\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    INSTALL_AVAHI="YES"
elif [[ "$HOSTNAME" == "" ]]; then
    printf "%b Hostname Check: %bERROR%b   Unable to check hostname\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b This installer currently assumes it will always be able to discover the\\n" "${INDENT}"
    printf "%b current hostname. It is therefore assumed that noone will ever see this error message!\\n" "${INDENT}"
    printf "%b If you have, please contact @digibytehelp on Twitter and let me know so I can work on\\n" "${INDENT}"
    printf "%b a workaround for your linux system.\\n" "${INDENT}"
    printf "\\n"
    exit 1
else
    printf "%b Hostname Check: %bFAILED%b   Hostname is not set to 'diginode'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b Your hostname is currently '$HOSTNAME'. It is advisable to change this to 'diginode'.\\n"  "${INDENT}"
    printf "%b This is optional but recommended, since it will make the DigiAssets website available at\\n"  "${INDENT}"
    printf "%b https://diginode.local which is obviously easier than remembering an IP address.\\n"  "${INDENT}"
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "%b Interactive Install: Do you want to change the hostname to 'digibyte'?\\n" "${INFO}"
    printf "\\n"
fi

}

# Display a request to change the hostname, if needed
hostname_ask_change() {

if [ ! "$UNATTENDED_MODE" == true ]; then

    if [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]]; then

        if whiptail  --backtitle "" --title "Changing your hostname to 'diginode' is recommended." --yesno "\\n\\nIt is recommended that you change your hostname to: 'diginode'.

    This is optional but recommended, since it will make the DigiAssets website available at https://diginode.local which is obviously easier than remembering an IP address.

    Would you like to change your hostname to 'diginode'?"  --yes-button "Yes (Recommended)" "${r}" "${c}"; then

          HOSTNAME_DO_CHANGE="YES"
          INSTALL_AVAHI="YES"

          printf "%b Interactive Install: Yes - Hostname will be changed.\\n" "${INFO}"
          printf "\\n"
        else
          printf "%b Interactive Install: No - Hostname will not be changed.\\n" "${INFO}"
          printf "\\n"
        fi
    fi
fi

}

# Function to change the hostname of the machine to 'diginode'
hostname_do_change() {

# If running unattended, and the flag to change the hostname in diginode.settings is set to yes, then go ahead with the change.
if [[ "$NewInstall" = "yes" ]] && [[ "$UNATTENDED_MODE" == true ]] && [[ "$UI_HOSTNAME_SET" = "YES" ]]; then
    HOSTNAME_DO_CHANGE="YES"
fi

# Only change the hostname if the user has agreed to do so (either via prompt or via UI setting)
if [[ "$HOSTNAME_DO_CHANGE" = "YES" ]]; then

    # if the current hostname if not 'diginode' then go ahead and change it
    if [[ ! "$HOSTNAME" == "diginode" ]]; then

        # Save current and new hostnames to a variable
        CUR_HOSTNAME=$HOSTNAME
        NEW_HOSTNAME="diginode"

        str="Changing Hostname from '$CUR_HOSTNAME' to '$NEW_HOSTNAME'..."
        printf "\\n%b %s" "${INFO}" "${str}"

        # Change hostname in /etc/hosts file
        sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts

        # Change hostname using hostnamectl
        if is_command hostnamectl ; then
            sudo hostnamectl set-hostname diginode 2>/dev/null
            printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "\\n%b %bUnable to change hostname using hostnamectl (command not present). Trying manual method...%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            hostname $NEW_HOSTNAME 2>/dev/null
            sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hostname 2>/dev/null
        fi


        if [[ "$UNATTENDED_MODE" == true ]]; then
            printf "%b Unattended Mode: Your system will reboot automatically in 5 seconds...\\n" "${INFO}"
            printf "%b You system will now reboot for the hostname change to take effect.\\n" "${INDENT}"
            sleep 5
            sudo reboot
        else
            printf "\\n%b %bPlease restart your machine now!%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b You need to reboot for the changes to the hostname to take effect.\\n" "${INDENT}"
            printf "%b You can do that now by entering:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   sudo reboot\\n" "${INDENT}"
            printf "\\n"
            exit
        fi

        exit

    fi
fi
}

# Function to check if the user account 'digibyte' is currently in use, and if it is not, check if it already exists
user_check() {

    # Only do this check if DigiByte Core is not currently installed
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

        if [[ "$USER_ACCOUNT" == "digibyte" ]]; then
            printf "%b User Account Check: %bPASSED%b   Current user is 'digibyte'\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
        else
            # If we doing an unattended install, and the setting filee forces using user 'digibyte', then
            if id "digibyte" &>/dev/null; then
                printf "%b User Account Check: %bFAILED%b   Current user is NOT 'digibyte'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bWARNING: You are NOT currently logged in as user 'digibyte'%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b A 'digibyte' user account already exists, but you are currently logged in as '$USER_ACCOUNT'.\\n"  "${INDENT}"
                printf "%b It is advisable to use the 'digibyte' account for your DigiNode. This is optional but recommended, since it\\n"  "${INDENT}"
                printf "%b will isolate your DigiByte wallet in its own user account.  For more information visit:\\n"  "${INDENT}"
                printf "%b  $DGBH_URL_USERCHANGE\\n"  "${INDENT}"
                printf "\\n"
                if [[ "$UNATTENDED_MODE" == true ]] && [ $UI_ENFORCE_DIGIBYTE_USER = "YES" ]; then
                    USER_DO_SWITCH="YES"
                    printf "%b %bUnattended Mode: Unable to continue - user is not 'digibyte' and requirement is enforced in diginode.settings%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                    printf "\\n"
                    exit 1
                elif [[ "$UNATTENDED_MODE" == true ]] && [ $UI_ENFORCE_DIGIBYTE_USER = "NO" ]; then
                    USER_DO_SWITCH="NO"
                    printf "%b Unattended Install: Skipping using 'digibyte' user - user '$USER_ACCOUNT' will be used\\n" "${INFO}"
                    printf "\\n"
                else
                    USER_ASK_SWITCH="YES"
                fi
            else
                printf "%b User Account Check: %bFAILED%b   User is NOT 'digibyte'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bWARNING: You are NOT currently logged in as user 'digibyte'.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b It is advisable to create a new 'digibyte' user account for your DigiNode.\\n"  "${INDENT}"
                printf "%b This is optional but recommended, since it will isolate your DigiByte wallet\\n"  "${INDENT}"
                printf "%b its own user account. For more information visit:\\n"  "${INDENT}"
                printf "%b  $DGBH_URL_USERCHANGE\\n"  "${INDENT}"
                printf "\\n"
                 if [[ "$UNATTENDED_MODE" == true ]] && [ $UI_ENFORCE_DIGIBYTE_USER = "YES" ]; then
                    printf "%b %bUnattended Mode: Unable to continue - user is not 'digibyte' and requirement is enforced in diginode.settings%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                    printf "\\n"
                    exit 1
                elif [[ "$UNATTENDED_MODE" == true ]] && [ $UI_ENFORCE_DIGIBYTE_USER = "NO" ]; then
                    USER_DO_CREATE="NO"
                    printf "\\n"
                    printf "%b Unattended Install: Skipping creating 'digibyte' user - using user '$USER_ACCOUNT'\\n" "${INFO}"
                else
                    USER_ASK_CREATE="YES"
                fi
            fi
        fi

    fi


}

# As we are not in the 'digibyte' user account, let's ask if we can switch to it, or create it if it does not exist
user_ask_change() {

# Display a request to change the user, if needed
if [[ "$USER_ASK_SWITCH" = "YES" ]]; then

    # Only ask to change the user if DigiByte Core is not yet installed
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

      if whiptail  --backtitle "" --title "Installing as user 'digibyte' is recommended." --yesno "It is recommended that you login as 'digibyte' before installing your DigiNode.\\n\\nThis is optional but encouraged, since it will isolate your DigiByte wallet its own user account.\\n\\nFor more information visit:\\n  $DGBH_URL_USERCHANGE\\n\\n\\nThere is already a 'digibyte' user account on this machine, but you are not currently using it - you are signed in as '$USER_ACCOUNT'. Would you like to switch users now?\\n\\nChoose NO to continue installation as '$USER_ACCOUNT'.\\n\\nChoose YES to exit and login as 'digibyte' from where you can run this installer again."  --yes-button "Yes (Recommended)" --no-button "No" "${r}" "${c}"; then

        USER_DO_SWITCH="YES"
        printf "%b User Account: You chose to install as user: 'digibyte' (This account already exists.).\\n" "${INFO}"
        printf "\\n"
      else
        printf "%b User Account: You chose to install as user: '$USER_ACCOUNT'. (The existing 'digibyte' user will not be used).\\n" "${INFO}"
        printf "\\n"
      fi
  fi
fi

# Display a request to create the 'digibyte' user, if needed
if [[ "$USER_ASK_CREATE" = "YES" ]]; then

    # Only ask to create the user if DigiByte Core is not yet installed
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

      if whiptail  --backtitle "" --title "Creating a new 'digibyte' user is recommended." --yesno "It is recommended that you create a new 'digibyte' user for your DigiNode.\\n\\nThis is optional but encouraged, since it will isolate your DigiByte wallet in its own user account.\\n\\nFor more information visit:\\n$DGBH_URL_USERCHANGE\\n\\n\\nYou are currently signed in as user '$USER_ACCOUNT'. Would you like to create a new 'digibyte' user now?\\n\\nChoose YES to create and sign in to the new user account, from where you can run this installer again.\\n\\nChoose NO to continue installation as '$USER_ACCOUNT'."  --yes-button "Yes (Recommended)" --no-button "No" "${r}" "${c}"; then

        USER_DO_CREATE="YES"
        printf "%b User Account: You chose to install as user: 'digibyte'. (This account will be created.)\\n" "${INFO}"
        printf "\\n"
      else
        printf "%b User Account: You chose to install as user: '$USER_ACCOUNT'.\\n" "${INFO}"
        printf "\\n"
      fi
  fi
fi

}

# If the user is currently not 'digibyte' we need to create the account, or sign in as it
user_do_change() {

if [ "$USER_DO_SWITCH" = "YES" ]; then
    printf "%b User Account: Switching to user account: 'digibyte'... \\n" "${INFO}"
    print "\\n"
    printf "%b You will now be asked to sign is as the user 'digibyte'. You will be asked for your password.\\n" "${INFO}"
    printf "%b Once you have signed in successfully to the 'digibyte' account, the installer will restart.\\n" "${INDENT}"
    print "\\n"
    su digibyte
    printf "\\n"
    if [ "$(id -u -n)" = "digibyte" ]; then
        printf "%b Re-running installer as user: digbyte ... \\n" "${INFO}"
        sleep 3
        exec curl -sSL $DGNT_INSTALLER_URL | sudo bash -s $add_args "$@"
    else
        printf "%b %bERROR: Unable to switch to user: digibyte%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b Please sign as user 'digibyte' and run this installer again: \\n" "${INFO}"
        prinff "\\n"
        printf "%b   su digibyte\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi
fi

if [ "$USER_DO_CREATE" = "YES" ]; then

    printf "%b User Account: Creating user account: 'digibyte'... \\n" "${INFO}"
    
    DGB_USER_PASS=$(whiptail --passwordbox "Please choose a password for the new 'digibyte' user.\\n\\nDon't forget this - you will need it to access your DigiNode!" 8 78 --title "Choose a password for new user: digibyte" 3>&1 1>&2 2>&3)
                                                                        # A trick to swap stdout and stderr.
    # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
    exitstatus=$?
    if [ $exitstatus == 0 ]; then

        # Encrypt CLEARTEXT password
        local str="Encrypting CLEARTEXT password ... "
        printf "%b %s..." "${INFO}" "${str}"
        DGB_USER_PASS_ENCR=$(perl -e 'print crypt($ARGV[0], "password")' $DGB_USER_PASS)
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        
        # Create digibyte user
        local str="Creating user 'digibyte' ... "
        printf "%b %s..." "${INFO}" "${str}"
        useradd -m -p "$DGB_USER_PASS_ENCR" digibyte
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Check if the digibyte group exists
        local str="Checking for group 'digibyte' ... "
        printf "%b %s..." "${INFO}" "${str}"
        if getent group digibyte > /dev/null 2>&1; then
            # succeed
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b %s..." "${INFO}" "${str}"
            local str="Creating group 'digibyte ... '"
            # if group can be created
            if groupadd digibyte; then
                printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
                local str="Adding user 'digibyte' to group 'digibyte' ... "
                printf "%b %s..." "${INFO}" "${str}"
                # if digibyte user can be added to group digibyte
                if usermod -aG digibyte digibyte; then
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                else
                    printf "%b%b %s\\n" "${OVER}" "${CROSS}" "${str}"
                fi
            else
                printf "%b%b %s\\n" "${OVER}" "${CROSS}" "${str}"
            fi
        fi

        # Add digibyte user to sudo group
        str="Add digibyte user to sudo group..."
        printf "%b %s..." "${INFO}" "${str}"
        sudo usermod -aG sudo digibyte
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"

        printf "%b You will now be asked to sign is as the user 'digibyte'. You will be asked for your password.\\n" "${INFO}"
        printf "%b Once you have signed in successfully to the 'digibyte' account, the installer will restart.\\n" "${INDENT}"
        printf "\\n"
        su digibyte
        printf "\\n"

        if [ "$(id -u -n)" = "digibyte" ]; then
            printf "%b Re-running installer as user: digbyte ... \\n" "${INFO}"
            sleep 3
            exec curl -sSL $DGNT_INSTALLER_URL | sudo bash -s $add_args "$@"
        else
            printf "%b %bERROR: Unable to switch to user: digibyte%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b Please sign as user 'digibyte' and run this installer again: \\n" "${INFO}"
            printf "\\n"
            printf "%b   su digibyte\\n" "${INDENT}"
            printf "\\n"
            exit 1
        fi

    else
        printf "%b %bYou cancelled creating a password.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bIf you prefer, you can manually create a 'digibyte' user account:\\n" "${INFO}"
        printf "\\n"
        printf "%b   sudo adduser digibyte\\n" "${INDENT}"
        printf "%b   sudo passwd digibyte\\n" "${INDENT}"
        printf "%b   sudo usermod -aG sudo digibyte\\n" "${INDENT}"
        printf "\\n"
        printf "%b Then login as the new user:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   su digibyte\\n" "${INDENT}"
        printf "\\n"
        printf "%b Once you are logged in as digibyte, run this installer again.\\n" "${INDENT}"
        printf "\\n"
        exit
    fi

fi

}

# Check if the 'digibyte' user exists and create if it does not
user_create_digibyte() {

    local str="Checking for user 'digibyte'"
    printf "%b %s..." "${INFO}" "${str}"
    # If the digibyte user exists,
    if id -u digibyte &> /dev/null; then
        # and if the digibyte group exists,
        if getent group digibyte > /dev/null 2>&1; then
            # succeed
            printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
        else
            local str="Checking for group 'digibyte'"
            printf "  %b %s..." "${INFO}" "${str}"
            local str="Creating group 'digibyte'"
            # if group can be created
            if groupadd digibyte; then
                printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
                local str="Adding user 'digibyte' to group 'digibyte'"
                printf "  %b %s..." "${INFO}" "${str}"
                # if digibyte user can be added to group digibyte
                if usermod -g digibyte digibyte; then
                    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
                else
                    printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
                fi
            else
                printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            fi
        fi
    else
        # If the digibyte user doesn't exist,
        printf "%b  %b %s" "${OVER}" "${CROSS}" "${str}"
        local str="Creating user 'digibyte'"
        printf "%b %b %s..." "${OVER}" "${INFO}" "${str}"
        # create her with the useradd command,
        if getent group digibyte > /dev/null 2>&1; then
            # then add her to the digibyte group (as it already exists)
            if useradd -r --no-user-group -g digibyte -s /usr/sbin/nologin digibyte; then
                printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            fi
        else
            # add user digibyte with default group settings
            if useradd -r -s /usr/sbin/nologin digibyte; then
                printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
            fi
        fi
    fi
}


# This function looks up which init system this Linux distro uses
# Reference: https://unix.stackexchange.com/questions/18209/detect-init-system-using-the-shell 

get_system_init() {

# Which init system are we using?
if [[ `/sbin/init --version 2>/dev/null` =~ upstart ]]; then
    INIT_SYSTEM="upstart"
    if [ $VERBOSE_MODE = true ]; then
        printf "%b Init System: upstart\\n" "${INFO}"
    fi
elif [[ `systemctl` =~ -\.mount ]]; then
    INIT_SYSTEM="systemd"
    if [ $VERBOSE_MODE = true ]; then
        printf "%b Init System: systemd\\n" "${INFO}"
    fi
elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
    INIT_SYSTEM="sysv-init"
    if [ $VERBOSE_MODE = true ]; then
        printf "%b Init System: sysv-init\\n" "${INFO}"
    fi
else
    INIT_SYSTEM="unknown"
    if [ $VERBOSE_MODE = true ]; then
        printf "%b Init System: Unknown\\n" "${INFO}"
    fi
fi

}


# This will check if a swap file is needed to run a DigiNode on this device, and suggest a recommend what size is needed
swap_check() {

    local swap_current_size

    if [ "$SWAPTOTAL_HR" = "0B" ]; then
      swap_current_size="${COL_LIGHT_RED}none${COL_NC}"
    else
      swap_current_size="${COL_LIGHT_GREEN}${SWAPTOTAL_HR}b${COL_NC}"
    fi
    printf "%b System Memory Check:     System RAM: %b${RAMTOTAL_HR}b%b     SWAP size: $swap_current_size\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    # insert a single line gap if this is the installer
    if [[ "$RUN_INSTALLER" != "NO" ]] ; then
        printf "\\n"
    fi

    # Check the existing swap file is large enough based on how much RAM the device has
    #
    # Note: these checks on the current swap size use the lower Kibibyte value
    # so that if the recomended swap size is 4Gb, and they enter 4 Gigabytes or 4 Gibibytes
    # the size check will come out the same for either
    if [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "6835938" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="7Gb"
        SWAP_REC_SIZE_MB=7000
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "5859375" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="6Gb"
        SWAP_REC_SIZE_MB=6000
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "4882813" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="5Gb"
        SWAP_REC_SIZE_MB=5000
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "3906250" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="4Gb"
        SWAP_REC_SIZE_MB=4000
    elif [ "$RAMTOTAL_KB" -le "5000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "2929688" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="3Gb"
        SWAP_REC_SIZE_MB=3000
    elif [ "$RAMTOTAL_KB" -le "6000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "1953125" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="3Gb"
        SWAP_REC_SIZE_MB=2000
    elif [ "$RAMTOTAL_KB" -le "7000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "976562" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="1Gb"
        SWAP_REC_SIZE_MB=1000

    # If there is no swap file present, calculate recomended swap file size
    elif [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="7Gb"
        SWAP_REC_SIZE_MB=7000
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="6Gb"
        SWAP_REC_SIZE_MB=6000
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="5Gb"
        SWAP_REC_SIZE_MB=5000
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="4Gb"
        SWAP_REC_SIZE_MB=4000
    elif [ "$RAMTOTAL_KB" -le "5000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="3Gb"
        SWAP_REC_SIZE_MB=3000
    elif [ "$RAMTOTAL_KB" -le "6000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="2Gb"
        SWAP_REC_SIZE_MB=2000
    elif [ "$RAMTOTAL_KB" -le "7000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="1Gb"
        SWAP_REC_SIZE_MB=1000
    fi

    if [ "$SWAP_NEEDED" = "YES" ]; then
        printf "%b Swap Check: %bFAILED%b   Not enough total memory for DigiNode.\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bWARNING: You need to create a swap file.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Running a DigiNode requires approximately 5Gb RAM. Since your device only\\n" "${INFO}"
        printf "%b has ${RAMTOTAL_HR}b RAM, it is recommended to create a swap file of at least $SWAP_REC_SIZE_HR or more.\\n" "${INDENT}"
        printf "%b This will give your system at least 8Gb of total memory to work with.\\n" "${INDENT}"
        # Only display this line when using digimon.sh
        if [[ "$RUN_INSTALLER" = "NO" ]] ; then
            printf "%b The official DigiNode installer can setup the swap file for you.\\n" "${INDENT}"
        fi
    fi

    if [ "$SWAP_TOO_SMALL" = "YES" ]; then
        printf "%b Swap Check: %bFAILED%b   Not enough total memory for DigiNode.\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bWARNING: Your swap file is too small%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Running a DigiNode requires approximately 5Gb RAM. Since your device only\\n" "${INDENT}"
        printf "%b has ${RAMTOTAL_HR}b RAM, it is recommended to increase your swap size to at least $SWAP_REC_SIZE_HR or more.\\n" "${INDENT}"
        printf "%b This will give your system at least 8Gb of total memory to work with.\\n" "${INDENT}"
        # Only display this line when using digimon.sh
        if [[ "$RUN_INSTALLER" = "NO" ]] ; then
            printf "%b The official DigiNode installer can setup the swap file for you.\\n" "${INDENT}"
        fi
    fi

    # Calculate total memory available
    TOTALMEM_KB=$(( $RAMTOTAL_KB + $SWAPTOTAL_KB ))

    if [ $RAMTOTAL_KB -gt 7800000 ] && [ "$SWAPTOTAL_KB" = 0 ]; then
        printf "%b Swap Check: %bPASSED%b   Your system has more than 7Gb RAM so no swap file is required.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    elif [ $TOTALMEM_KB -gt 7800000 ]; then
        printf "%b Swap Check: %bPASSED%b   Your system RAM and SWAP combined exceed 7Gb.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    fi
    printf "\\n"
}

# If a swap file is needed, this will ask the user to confirm that they want to create one or increase the size of an existing one
swap_ask_change() {
# Display a request to change the hostname, if needed
if [[ "$SWAP_ASK_CHANGE" = "YES" ]]; then

    local str_swap_needed

    if [ "$SWAP_NEEDED" = "YES" ]; then
        str_swap_needed="WARNING: You need to create a swap file.\\n\\nRunning a DigiNode requires approximately 5Gb RAM. Since your system only has ${RAMTOTAL_HR}b RAM, it is recommended to create a swap file of at least $swap_rec_size or more. This will give your system at least 8Gb of total memory to work with.\\n\\n"

        SWAP_TARG_SIZE_MB=$(whiptail  --inputbox "$str" "${r}" "${c}" $SWAP_REC_SIZE_MB --title "No swap file detected!" 3>&1 1>&2 2>&3) 

        local str_swap_too_low
        str_swap_too_low="The entered value is smaller than the reccomended swap size. Please enter the recommended size or larger."
        if [ "$SWAP_TARG_SIZE_MB" -lt "$SWAP_REC_SIZE_MB" ]; then
            whiptail --msgbox --title "Swap file size is too small!" "$str_swap_too_low" "${r}" "${c}"
            swap_ask_change
        fi

        SWAP_FILE_LOCATION=/swapfile

    fi

    if [ "$SWAP_TOO_SMALL" = "YES" ]; then
        str="WARNING: You need a larger swap file.\\n\\nRunning a DigiNode requires approximately 5Gb RAM. Since your device only has ${RAMTOTAL_HR}b RAM, it is recommended to increase your swap size to at least $SWAP_REC_SIZE_HR or more. This will give your system at least 8Gb of total memory to work with.\\n\\n"

        SWAP_TARG_SIZE_MB=$(whiptail  --inputbox "$str" "${r}" "${c}" $SWAP_REC_SIZE_MB --title "Swap file size is too small!" 3>&1 1>&2 2>&3) 

        local str_swap_too_low
        str_swap_too_low="The entered value is smaller than the reccomended swap size. Please enter the recommended size or larger."
        if [ "$SWAP_TARG_SIZE_MB" -lt "$SWAP_REC_SIZE_MB" ]; then
            whiptail --msgbox --title "Swap file size is too small!" "$str_swap_too_low" "${r}" "${c}"
            swap_ask_change
        fi

        SWAP_FILE_LOCATION=/swapfile

    fi

fi

}

# If a swap file is needed, this function will create one or change the size of an existing one
swap_do_change() {

    # If in Unattended mode, and a swap file is needed, then proceed
    if [[ $NewInstall = "yes" ]] && [[ "$UNATTENDED_MODE" = "true" ]] && [ "$SWAP_NEEDED" = "YES" ]; then
        SWAP_DO_CHANGE="YES"
    fi

    # If in Unattended mode, and the existing swap file is to small, then proceed
    if [[ $NewInstall = "yes" ]] && [[ "$UNATTENDED_MODE" = "true" ]] && [ "$SWAP_TOO_SMALL" = "YES" ]; then
        SWAP_DO_CHANGE="YES"
    fi

    # Go ahead and create/change the swap if requested
    if [[ $SWAP_DO_CHANGE = "YES" ]]; then

        #create local variable
        local str

        # Display section break
        if [ "$SWAP_NEEDED" = "YES" ]; then
            printf " =============== Creating: SWAP file ===================================\\n\\n"
            # ==============================================================================
        elif [ "$SWAP_TOO_SMALL" = "YES" ]; then
            printf " =============== Modifying: SWAP file ==================================\\n\\n"
            # ==============================================================================
        fi

        # Display message if we are doing a unattended install using a manual swap size
        if [[ "$UNATTENDED_MODE" = "true" ]] && [[ "$UI_SWAP_SIZE_MB" != "" ]]; then
            SWAP_TARG_SIZE_MB=$UI_SWAP_SIZE_MB
            printf "%b Unattended Install: Using manual swap file size from diginode.settings\\n" "${INFO}"
        fi

         # Display message if we are doing a unattended install using a reccomended swap size
        if [[ "$UNATTENDED_MODE" = "true" ]] && [[ "$UI_SWAP_SIZE_MB" = "" ]]; then
            SWAP_TARG_SIZE_MB=$SWAP_REC_SIZE_MB
            printf "%b Unattended Install: Using recommended swap size of $SWAP_REC_SIZE_HR\\n" "${INFO}" 
        fi

        # If unattended install, and no swap file location is specified, use the dafault
        if [[ "$UNATTENDED_MODE" = "true" ]] && [[ "$UI_SWAP_FILE" = "" ]]; then
            SWAP_FILE=/swapfile
            printf "%b Unattended Install: Using default SWAP file location: /swapfile\\n" "${INFO}"
        fi

        # Display message if we are doing a unattended install using a manual swap size
        if [[ "$UNATTENDED_MODE" = "true" ]] && [[ "$UI_SWAP_FILE" != "" ]]; then
            SWAP_FILE=$UI_SWAP_FILE
            printf "%b %bUnattended Install: Using manual swap file size from diginode.settings: $UI_SWAP_FILE%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        fi

        # Append M units to target swap file size
        SWAP_TARG_SIZE_MB="${SWAP_TARG_SIZE_MB}M"

        # If the swap file already exists, but is too small
        if [ "$SWAP_TOO_SMALL" = "YES" ]; then

            # Disable existing swap file
            str="Disable existing swap file..."
            printf "\\n%b %s..." "${INFO}" "${str}"
            swapoff -a
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Remove swap file entry from fstab file
            str="Deleting swap entry from fstab file..."
            printf "\\n%b %s..." "${INFO}" "${str}"
            sudo sed -i.bak '/swap/d' /etc/fstab
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        fi

       # Allocate space for new swap file
        str="Allocate $SWAP_TARG_SIZE_MB MB for new swap file..."
        printf "\\n%b %s..." "${INFO}" "${str}"
        fallocate -l "$SWAP_TARG_SIZE_MB" "$SWAP_FILE"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Mark new file as swap
        printf "%b Mark as new swap file...\\n" "${INFO}"
        mkswap "$SWAP_FILE"       
        
        # Secure swap file
        str="Secure swap file..."
        printf "\\n%b %s..." "${INFO}" "${str}"
        chown root:root $SWAP_FILE
        chmod 0600 $SWAP_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Activate new swap file
        str="Activate new swap file..."
        printf "\\n%b %s..." "${INFO}" "${str}"
        swapon "$SWAP_FILE"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}" 

        # Make new swap file available at boot
        str="Make new swap file available at boot..."
        printf "\\n%b %s..." "${INFO}" "${str}"
        echo "$SWAP_FILE none swap defaults 0 0" >> /etc/fstab
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}" 

    fi

}

#check there is sufficient space on the chosen drive to download the blockchain
disk_check() {
    # Only run the check if DigiByte Core is not yet installed
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

        if [[ "$DGB_DATA_DISKFREE_KB" -lt "$DGB_DATA_REQUIRED_KB" ]]; then
            printf "%b Disk Space Check: %bFAILED%b   Not enough space available\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b %bWARNING: DigiByte blockchain data will not fit on this drive%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b The fully downloaded blockchain currently requires approximately $DGB_DATA_REQUIRED_HR\\n" "${INDENT}"
            printf "%b The current location only has ${DGB_DATA_DISKFREE_HR}b free. You can change the location of where the\\n" "${INDENT}"
            printf "%b DigiByte blockchain data is stored by editing the diginode.settings file.\\n" "${INDENT}"
            printf "%b Alternatively, you can edit you digibyte.conf file to prune the blockchain data\\n" "${INDENT}"
            printf "%b automatically when it gets too large.\\n" "${INDENT}"
            printf "\\n"
            # Only display this line when using digimon.sh
            if [[ "$UI_DISKSPACE_OVERRIDE" = "YES" && "$UNATTENDED_MODE" = true ]]; then
                printf "%b Unattended Install: Disk Space Check Override ENABLED. Continuing...\\n" "${INFO}"
                printf "\\n"
            elif [[ "$UNATTENDED_MODE" = true ]]; then
                if [[ "$UI_DISKSPACE_OVERRIDE" = "NO" ]] || [[ "$UI_DISKSPACE_OVERRIDE" = "" ]]; then
                  printf "%b Unattended Install: Disk Space Check Override DISABLED. Exiting Installer...\\n" "${INFO}"
                  printf "\\n"
                  exit 1
                fi
            else
                QUERY_LOWDISK_SPACE="YES"
            fi      
        else
            printf "%b Disk Space Check: %bPASSED%b   There is sufficient space to download the DigiByte blockchain.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b    Space Required: ${DGB_DATA_REQUIRED_HR}  Space Available: ${DGB_DATA_DISKFREE_HR}b\\n" "${INDENT}"
            printf "\\n"
        fi
    else
        printf "%b Disk Space Check: SKIPPED   DigiByte Core is already installed.\\n" "${INFO}"
        printf "\\n"
    fi
}

# If this is the first time installing DigiByte Core, warn if the data drive does not have enough space
disk_ask_lowspace() {

if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

    # If low disk space is detected on in the default install location, ask the user if they want to continue
    if [[ "$QUERY_LOWDISK_SPACE" = "YES" ]]; then
        if whiptail  --backtitle "" --title "Not enough free space to download the blockchain." --yesno "WARNING: There is not enough free space on this drive to download a full copy of the DigiByte blockchain.\\n\\nIf you continue, you will need to enable pruning the blockchain to prevent it from filling up the drive. You can do this by editing the digibyte.conf settings file.\\n\\nDo you wish to continue with the install now?\\n\\nChoose YES to indicate that you have understood this message, and wish to continue." --defaultno "${r}" "${c}"; then

            printf "%b %bIMPORTANT: You need to have DigiByte Core prune your blockchain or it will fill up your data drive%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"

        else
          printf "%b %bIMPORTANT: You need to have DigiByte Core prune your blockchain or it will fill up your data drive%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          
          if [ "$TEXTEDITOR" != "" ]; then
                printf "%b You can do this by editing the digibyte.conf file:\\n" "${INDENT}"
                printf "\\n"
                printf "%b   $TEXTEDITOR $DGB_CONF_FILE\\n" "${INDENT}"
                printf "\\n"
                printf "%b Once you have made your changes, re-run the installer.\\n" "${INDENT}"
                printf "\\n"
          fi
        fi
    fi

fi

}

# The menu displayed on first install - asks to install DigiByte Core alone, or also the DigiAsset Node
menu_first_install() {

    printf " =============== INSTALL MENU ==========================================\\n\\n"
    # ==============================================================================

    opt1a="Full DigiNode "
    opt1b=" Install DigiByte Core & DigiAsset Node (Recommended)"
    
    opt2a="DigiByte Core ONLY "
    opt2b=" DigiAsset Node will NOT be installed."


    # Display the information to the user
    UpdateCmd=$(whiptail --title "DigiNode Install Menu" --menu "\\n\\nPlease choose whether you would like to perform a full DigiNode install, or to install DigiByte Core only. A full install is recommended.\\n\\nRunning a DigiAsset Node supports the network by helping to decentralize DigiAsset metadata. It also gives you the ability to create your own DigiAssets, and earn DigiByte for hosting other people's metadata.\\n\\nPlease choose an option:\\n\\n" "${r}" 80 3 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
    { printf "  %bCancel was selected, exiting installer%b\\n\\n" "${COL_LIGHT_RED}" "${COL_NC}"; exit 1; }

    # Set the variable based on if the user chooses
    case ${UpdateCmd} in
        # Install Full DigiNode
        ${opt1a})
            DO_FULL_INSTALL=YES
            printf "%b %soption selected\\n" "${INFO}" "${opt1a}"
            ;;
        # Install DigiByte Core ONLY
        ${opt2a})
            DO_FULL_INSTALL=NO
            printf "%b %soption selected\\n" "${INFO}" "${opt2a}"
            ;;
    esac
    printf "\\n"
}

# Function to display the upgrade menu when a previous install has been detected
menu_existing_install() {

    printf " =============== UPGRADE MENU ==========================================\\n\\n"
    # ==============================================================================

    opt1a="Upgrade"
    opt1b="Upgrade DigiNode software to the latest versions."
    
    opt2a="Reset"
    opt2b="Reset all settings and reinstall DigiNode software."

    opt3a="Uninstall"
    opt3b="Remove DigiNode from your systems."


    # Display the information to the user
    UpdateCmd=$(whiptail --title "Existing DigiNode Detected!" --menu "\\n\\nWe have detected an existing DigiNode on this system.\\n\\nPlease choose one of the options below. \\n\\n(Note: In all cases, your DigiByte wallet will not be harmed. That said, a backup is highly recommended.)\\n\\n" "${r}" "${c}" 3 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" \
    "${opt3a}"  "${opt3b}" 4>&3 3>&2 2>&1 1>&3) || \
    { printf "%b %bCancel was selected, exiting installer%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; exit; }

    # Set the variable based on if the user chooses
    case ${UpdateCmd} in
        # Update, or
        ${opt1a})
            printf "%b You selected the UPGRADE option.\\n" "${INFO}"
            printf "\\n"

            ;;
        # Reset,
        ${opt2a})
            printf "%b You selected the RESET option.\\n" "${INFO}"
            printf "\\n"
            RESET_MODE=true
            ;;
        # Uninstall,
        ${opt3a})
            printf "%b You selected the UNINSTALL option.\\n" "${INFO}"
            printf "\\n"
            uninstall_do_now
            ;;
    esac
}


# A function for displaying the dialogs the user sees when first running the installer
welcomeDialogs() {
    # Display the welcome dialog using an appropriately sized window via the calculation conducted earlier in the script
    whiptail --msgbox --backtitle "" --title "Welcome to DigiNode Installer" "DigiNode Installer will install and configure DigiByte Core and DigiAsset Node on this device.\\n\\nRunning DigiByte Core means you have a full copy of the DigiByte blockchain on your machine and are helping contribute to the decentralization and security of the network.\\n\\nWith a DigiAsset Node you are helping to decentralize and redistribute DigiAsset metadata. It also gives you the ability to earn DGB for hosting others data, as well as being able to create your own DigiAssets on your own node.\\n\\nTo learn more, visit: $DGBH_URL_INTRO" "${r}" "${c}"

# Request that users donate if they find DigiNode Installer useful
whiptail --msgbox --backtitle "" --title "DigiNode Installer is FREE and OPEN SOURCE" "If you find it useful, donations in DGB are much appreciated:
                  ▄▄▄▄▄▄▄  ▄    ▄ ▄▄▄▄▄ ▄▄▄▄▄▄▄  
                  █ ▄▄▄ █ ▀█▄█▀▀██  █▄█ █ ▄▄▄ █  
                  █ ███ █ ▀▀▄▀▄▀▄ █▀▀▄█ █ ███ █  
                  █▄▄▄▄▄█ █ █ ▄ ▄▀▄▀▄ █ █▄▄▄▄▄█  
                  ▄▄▄▄▄ ▄▄▄▄▄ █▄▄▀▄▄▄ ▄▄ ▄ ▄ ▄   
                  █ ▄▀ ▄▄▄▀█ ▄▄ ▄▄▀  ▀█▄▀██▄ ▄▀  
                   ▀▀ ▄▀▄  █▀█ ▄ ▀ ▄  █  ▀▀█▄█▀  
                   █ █▀▄▄▀█ █ ▀▄▀▄██▄▀▄██▀▀▄ ▀▀  
                  ▄█▀ █▀▄▄    █▄█▀▄▄▀▀▄ ▀  █▄ ▀  
                  █ ▄██ ▄▀▀█ ▄▄█ ▄█▀▄▀▄█▀▀█▀▄▀▀  
                  █ ██▄ ▄▄ ▄▀█ ▄███▄▄▀▄▄▄▄▄▄▄▀   
                  ▄▄▄▄▄▄▄ █▀▄ ▀ █▄▄▄ ██ ▄ █ ▀▀▀  
                  █ ▄▄▄ █ ▄█▀ █▄█▀▄▄▀▀█▄▄▄██▄▄█  
                  █ ███ █ █ ▀▄▄ ▀▄ ███  ▄█▄  █▀  
                  █▄▄▄▄▄█ █  █▄  █▄▄ ▀▀  ▀▄█▄▀   

           dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup" "${r}" "${c}"

# If this is the first time running the installer, and the diginode.settings file has just been created,
# ask the user if they want to EXIT to customize their install settings.

if [ "$IS_DGNT_SETTINGS_FILE_NEW" = "YES" ]; then

    if whiptail --backtitle "" --title "Do you want to customize your DigiNode installation?" --yesno "Before proceeding, you may wish to edit the diginode.settings file that has just been created in the ~/.digibyte folder.\\n\\nThis is for advanced users who want to customize their install, such as to change the location of where the DigiByte blockchain data is stored.\\n\\nIn most cases, there should be no need to do this, and you can safely continue with the defaults.\\n\\nFor more information on customizing your installation, visit: $DGBH_URL_CUSTOM\\n\\n\\nTo proceed with the defaults, choose Continue (Recommended)\\n\\nTo exit and customize your installation, choose Exit" --no-button "Exit" --yes-button "Continue" "${r}" "${c}"; then
    #Nothing to do, continue
      printf "%b You chose to proceed without customizing your install.\\n" "${INFO}"
    else
        printf "%b You exited the installler at the customization message.\\n" "${INFO}"
        printf "\\n"
        printf "%b %bTo customize your DigiNode install, please edit the diginode.settings file.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        if [ "$TEXTEDITOR" != "" ]; then
            printf "%b Do this by entering:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   $TEXTEDITOR $DGNT_SETTINGS_FILE\\n" "${INDENT}"
            printf "\\n"
            printf "%b Once you have made your changes, re-run the installer.\\n" "${INDENT}"
        fi
        printf "%b For more help go to: $DGBH_URL_CUSTOM\\n"  "${INDENT}"
        printf "\\n"
        exit
    fi

fi

# Explain the need for a static address
if whiptail --defaultno --backtitle "" --title "Your DigiNode needs a Static IP address." --yesno "IMPORTANT: Your DigiNode is a SERVER so it needs a STATIC IP ADDRESS to function properly.\\n\\nIf you have not already done so, you must ensure that this device has a static IP address. This can be done through DHCP reservation, or by manually assigning one. Depending on your operating system, there are many ways to achieve this.\\n\\nThis devices current IP address is: $IP4_INTERNAL\\n\\nFor more help, please visit: $DGBH_URL_STATICIP\\n\\nChoose Continue to indicate that you have understood this message." --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then
#Nothing to do, continue
  printf "%b You acknowledged that your system requires a Static IP Address.\\n" "${INFO}"
  printf "\\n"
else
  printf "%b Installer exited at static IP message.\\n" "${INFO}"
  printf "\\n"
  exit
fi

}


# Create service so that DigiByte daemon will run at boot
digibyte_create_service() {

# If you want to make changes to how DigiByte daemon services are created/managed for diferent systems, refer to this website:
#

# If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
if [ "$RESET_MODE" = true ]; then

    # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
    if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB_UPSTART_SERVICE_FILE" ]; then

        if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-create your digibyted.service file?\\n\\nNote: This will delete your current systemd service file and re-create with default settings. Any customisations will be lost.\\n\\nNote: The service file ensures that the DigiByte daemon starts automatically after a reboot or if it crashes." "${r}" "${c}"; then
            DGB_SERVICE_CREATE=YES
            DGB_SERVICE_INSTALL_TYPE="reset"
        else
            printf " =============== Resetting: DigiByte daemon service ====================\\n\\n"
            # ==============================================================================
            printf "%b Reset Mode: You skipped re-configuring the DigiByte daemon service.\\n" "${INFO}"
            printf "\\n"
            DGB_SERVICE_CREATE=NO
            DGB_SERVICE_INSTALL_TYPE="none"
            return
        fi
    fi
fi

# If the SYSTEMD service files do not yet exist, then assume this is a new install
if [ ! -f "$DGB_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
            DGB_SERVICE_CREATE="YES"
            DGB_SERVICE_INSTALL_TYPE="new"
fi

# If the UPSTART service files do not yet exist, then assume this is a new install
if [ ! -f "$DGB_DAEMON_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
            DGB_SERVICE_CREATE="YES"
            DGB_SERVICE_INSTALL_TYPE="new"
fi


if [ "$DGB_SERVICE_CREATE" = "YES" ]; then

    # Display section break
    if [ "$DGB_SERVICE_INSTALL_TYPE" = "new" ]; then
        printf " =============== Installing: DigiByte daemon service ===================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_SERVICE_INSTALL_TYPE" = "update" ]; then
        printf " =============== Updating: DigiByte daemon service =====================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_SERVICE_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Resetting: DigiByte daemon service ====================\\n\\n"
        # ==============================================================================
    fi

    # If DigiByte daemon systemd service file already exists, and we are in Reset Mode, stop it and delete it, since we will replace it
    if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ] && [ "$DGB_SERVICE_INSTALL_TYPE" = "reset" ]; then

        printf "%b Reset Mode: You chose to re-create the digibyted systemd service file.\\n" "${INFO}"

        printf "%b Reset Mode: Stopping DigiByte daemon systemd service...\\n" "${INFO}"

        # Stop the service now
        systemctl stop digibyted

        printf "%b Reset Mode: Disabling DigiByte daemon systemd service...\\n" "${INFO}"

        # Disable the service now
        systemctl disable digibyted

        str="Reset Mode: Deleting DigiByte daemon systemd service file: $DGB_SYSTEMD_SERVICE_FILE ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $DGB_SYSTEMD_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If DigiByte daemon upstart service file already exists, and we are in Reset Mode, stop it and delete it, since we will replace it
    if [ -f "$DGB_UPSTART_SERVICE_FILE" ] && [ "$DGB_SERVICE_INSTALL_TYPE" = "reset" ]; then

        printf "%b Reset Mode: You chose to re-create the digibyted upstart service file.\\n" "${INFO}"

        printf "%b Reset Mode: Stopping DigiByte daemon upstart service...\\n" "${INFO}"

        # Stop the service now
        service digibyted stop

        printf "%b Reset Mode: Disabling DigiByte daemon upstart service...\\n" "${INFO}"

        # Disable the service now
        service digibyted disable

        str="Deleting DigiByte daemon upstart service file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $DGB_UPSTART_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If using systemd and the DigiByte daemon service file does not exist yet, let's create it
    if [ ! -f "$DGB_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then

        # Create a new DigiByte daemon service file

        str="Creating DigiByte daemon systemd service file: $DGB_SYSTEMD_SERVICE_FILE ... "
        printf "%b %s" "${INFO}" "${str}"
        touch $DGB_SYSTEMD_SERVICE_FILE
        cat <<EOF > $DGB_SYSTEMD_SERVICE_FILE
[Unit]
Description=DigiByte's distributed currency daemon
After=network.target

[Service]
User=$USER_ACCOUNT
Group=$USER_ACCOUNT

Type=forking
PIDFile=${DGB_SETTINGS_LOCATION}/digibyted.pid
ExecStart=${DGB_DAEMON} -daemon -pid=${DGB_SETTINGS_LOCATION}/digibyted.pid \\
-conf=${DGB_CONF_FILE} -datadir=${DGB_DATA_LOCATION}

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Enable the service to run at boot
        printf "%b Enabling DigiByte daemon systemd service...\\n" "${INFO}"
        systemctl enable digibyted

        # Start the service now
        printf "%b Starting DigiByte daemon systemd service...\\n" "${INFO}"
        systemctl start digibyted

    fi


    # If using upstart and the DigiByte daemon service file does not exist yet, let's create it
    if [ ! -f "$DGB_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then

        # Create a new DigiByte daemon upstart service file

        str="Creating DigiByte daemon upstart service file: $DGB_UPSTART_SERVICE_FILE ... "
        printf "%b %s" "${INFO}" "${str}"
        touch $DGB_UPSTART_SERVICE_FILE
        cat <<EOF > $DGB_UPSTART_SERVICE_FILE
description "DigiByte Core Daemon"

start on runlevel [2345]
stop on starting rc RUNLEVEL=[016]

env DIGBYTED_BIN="$DGB_DAEMON"
env DIGIBYTED_USER="$USER_ACCOUNT"
env DIGIBYTED_GROUP="$USER_ACCOUNT"
env DIGIBYTED_PIDFILE="$DGB_SETTINGS_LOCATION/digibyted.pid"
env DIGIBYTED_CONFIGFILE="$DGB_CONF_FILE"
env DIGIBYTED_DATADIR="$DGB_DATA_LOCATION"

expect fork

respawn
respawn limit 5 120
kill timeout 600

exec start-stop-daemon \
    --start \
    --pidfile "\$DIGIBYTED_PIDFILE" \
    --chuid \$DIGIBYTED_USER:\$DIGIBYTED_GROUP \
    --exec "\$DIGIBYTED_BIN" \
    -- \
    -pid="\$DIGIBYTED_PIDFILE" \
    -conf="\$DIGIBYTED_CONFIGFILE" \
    -datadir="\$DIGIBYTED_DATADIR"
EOF
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"


        # Start the service now
        printf "%b Starting DigiByte daemon upstart service...\\n" "${INFO}"
        service digibyted start

    fi

    # If using sysv-init or another unknown system, we don't yet support creating the DigiByte daemon service
    if [ "$INIT_SYSTEM" = "sysv-init" ] || [ "$INIT_SYSTEM" = "unknown" ]; then

        printf "%b Unable to create a DigiByte daemon service for your system - systemd/upstart not found.\\n" "${CROSS}"
        printf "%b Please contact @digibytehelp on Twitter for help.\\n" "${CROSS}"
        exit 1

    fi

printf "\\n"

fi

}

request_social_media () {  

    if [ $NewInstall = true ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf " =======================================================================\\n"
        printf " ======== ${txtgrn}Congratulations - Your DigiNode has been installed!${txtrst} ==========\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo "Thanks for supporting DigiByte!"
        echo ""
        echo " Please let everyone know what you are helping support the DigiByte network"
        echo " by sharing on social media using the hashtag #DigiNode."
        echo ""
        echo " Here's a sample Tweet you can use:"
        echo "\"I just set up a #DigiNode to help support the decentralization of #DigiByte network!"
        echo "If you want to help, you can learn more at $DGBH_URL_TWEET \""
        echo ""
    elif [ $NewInstall = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf " =======================================================================\\n"
        printf " ======== ${txtgrn}DigiByte Core has been installed!${txtrst} ============================\\n"
        printf " =======================================================================\\n\\n"
        # ================================================================================================
        echo " Thanks for supporting DigiByte by running a DigiByte full node!"
        echo ""
        echo " If you want to help even more, please consider also running a DigiAsset Node"
        echo " as well. You can run this installer again at any time to upgrade to a full"
        echo " DigiNode."
        echo ""
    elif [ "$RESET_MODE" = true ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf " =======================================================================\\n"
        printf " ================== ${txtgrn}Your DigiNode has been Reset!${txtrst} ======================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo ""
    elif [ "$RESET_MODE" = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf " =======================================================================\\n"
        printf " ================== ${txtgrn}DigiByte Core has been Reset!${txtrst} ======================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo ""
    elif [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf " =======================================================================\\n"
        printf " ================== ${txtgrn}Your DigiNode has been Upgraded!${txtrst} ===================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
    elif [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf " =======================================================================\\n"
        printf " ================== ${txtgrn}DigiByte Core has been Upgraded!${txtrst} ===================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
    fi
}


donation_qrcode() {  

    printf " ============== Please Donate to support DigiNode Tools ================\\n\\n"
    # ==============================================================================

    echo " If you find DigiNode Tools useful, and want to support future development,"
    echo "donations in DGB are much appreciated. Thanks for your support. - Olly @saltedlolly"             
    echo "                      ▄▄▄▄▄▄▄  ▄    ▄ ▄▄▄▄▄ ▄▄▄▄▄▄▄"  
    echo "                      █ ▄▄▄ █ ▀█▄█▀▀██  █▄█ █ ▄▄▄ █"  
    echo "                      █ ███ █ ▀▀▄▀▄▀▄ █▀▀▄█ █ ███ █"  
    echo "                      █▄▄▄▄▄█ █ █ ▄ ▄▀▄▀▄ █ █▄▄▄▄▄█"  
    echo "                      ▄▄▄▄▄ ▄▄▄▄▄ █▄▄▀▄▄▄ ▄▄ ▄ ▄ ▄ "  
    echo "                      █ ▄▀ ▄▄▄▀█ ▄▄ ▄▄▀  ▀█▄▀██▄ ▄▀"  
    echo "                       ▀▀ ▄▀▄  █▀█ ▄ ▀ ▄  █  ▀▀█▄█▀"  
    echo "                       █ █▀▄▄▀█ █ ▀▄▀▄██▄▀▄██▀▀▄ ▀▀"  
    echo "                      ▄█▀ █▀▄▄    █▄█▀▄▄▀▀▄ ▀  █▄ ▀"  
    echo "                      █ ▄██ ▄▀▀█ ▄▄█ ▄█▀▄▀▄█▀▀█▀▄▀▀"  
    echo "                      █ ██▄ ▄▄ ▄▀█ ▄███▄▄▀▄▄▄▄▄▄▄▀ "  
    echo "                      ▄▄▄▄▄▄▄ █▀▄ ▀ █▄▄▄ ██ ▄ █ ▀▀▀"  
    echo "                      █ ▄▄▄ █ ▄█▀ █▄█▀▄▄▀▀█▄▄▄██▄▄█"  
    echo "                      █ ███ █ █ ▀▄▄ ▀▄ ███  ▄█▄  █▀"  
    echo "                      █▄▄▄▄▄█ █  █▄  █▄▄ ▀▀  ▀▄█▄▀ "
    echo ""  
    echo "               dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup"
    echo ""
}

request_reboot () {  

    if [ $NewInstall = true ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf "%b %bTo complete your install you need to reboot your system.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: sudo reboot\\n" "${INDENT}"
        printf "\\n"
        printf "%b %b'DigiNode Status Monitor' can be used to monitor your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To run it enter: diginode\\n" "${INDENT}"
        printf "\\n"
    elif [ $NewInstall = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf "%b %b'DigiNode Status Monitor' can be used to monitor your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To run it enter: diginode\\n" "${INDENT}"
        printf "\\n"
    elif [ "$RESET_MODE" = true ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf "%b %bAfter performing a reset, it is advisable to reboot your system.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: sudo reboot\\n" "${INDENT}"
        printf "\\n"
        printf "%b %b'DigiNode Status Monitor' can be used to monitor your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To run it enter: diginode\\n" "${INDENT}"
        printf "\\n"
    elif [ "$RESET_MODE" = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf "%b %b'DigiNode Status Monitor' can be used to monitor your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To run it enter: diginode\\n" "${INDENT}"
        printf "\\n"
    elif [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf "%b %bAfter performing an upgrade, it is advisable to reboot your system.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: sudo reboot\\n" "${INDENT}"
        printf "\\n"
        printf "%b %b'DigiNode Status Monitor' can be used to monitor your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To run it enter: diginode\\n" "${INDENT}"
        printf "\\n"
    elif [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf "%b %b'DigiNode Status Monitor' can be used to monitor your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To run it enter: diginode\\n" "${INDENT}"
        printf "\\n"
    fi
}

stop_service() {
    # Stop service passed in as argument.
    # Can softfail, as process may not be installed when this is called
    local str="Stopping ${1} service"
    printf "%b %s..." "${INFO}" "${str}"
    if is_command systemctl ; then
        systemctl stop "${1}" &> /dev/null || true
    else
        service "${1}" stop &> /dev/null || true
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Start/Restart service passed in as argument
restart_service() {
    # Local, named variables
    local str="Restarting ${1} service"
    printf "%b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to restart the service
        systemctl restart "${1}" &> /dev/null
    else
        # Otherwise, fall back to the service command
        service "${1}" restart &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Enable service so that it will start with next reboot
enable_service() {
    # Local, named variables
    local str="Enabling ${1} service to start on reboot"
    printf "%b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to enable the service
        systemctl enable "${1}" &> /dev/null
    else
        #  Otherwise, use update-rc.d to accomplish this
        update-rc.d "${1}" defaults &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Disable service so that it will not with next reboot
disable_service() {
    # Local, named variables
    local str="Disabling ${1} service"
    printf "%b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to disable the service
        systemctl disable "${1}" &> /dev/null
    else
        # Otherwise, use update-rc.d to accomplish this
        update-rc.d "${1}" disable &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

check_service_active() {
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to check the status of the service
        systemctl is-active "${1}" &> /dev/null
    else
        # Otherwise, fall back to service command
        service "${1}" status &> /dev/null
    fi
}

# Function to compare two version numbers
function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }



# This function will check if DigiByte Core is installed, and if it is, check if there is an update available

digibyte_check() {

    printf " =============== Checking: DigiByte Core ===============================\\n\\n"
    # ==============================================================================

    # Let's check if DigiByte Core is already installed
    str="Is DigiByte Core already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then
        DGB_STATUS="installed"
        printf "%b%b %s YES! [ DigiNode Install Detected. ] \\n" "${OVER}" "${TICK}" "${str}"
    else
        DGB_STATUS="not_detected"
    fi

    # Just to be sure, let's try another way to check if DigiByte Core installed by looking for the digibyte-cli binary
    if [ "$DGB_STATUS" = "not_detected" ]; then
        if [ -f $DGB_CLI ]; then
            DGB_STATUS="installed"
            printf "%b%b %s YES!  [ DigiByte CLI located. ] \\n" "${OVER}" "${TICK}" "${str}"
        else
            DGB_STATUS="not_detected"
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
            DGB_VER_LOCAL=""
            sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=|" $DGNT_SETTINGS_FILE
        fi
    fi

    # Next let's check if DigiByte daemon is running
    if [ "$DGB_STATUS" = "installed" ]; then
      str="Is DigiByte Core running?..."
      printf "%b %s" "${INFO}" "${str}"
      if check_service_active "digibyted"; then
          DGB_STATUS="running"
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
      else
          DGB_STATUS="notrunning"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
      fi
    fi

    # If it's running, is digibyted in the process of starting up, and not yet ready to respond to requests?
    if [ "$DGB_STATUS" = "running" ]; then
        str="Is DigiByte Core finished starting up?..."
        printf "%b %s" "${INFO}" "${str}"
        BLOCKCOUNT_LOCAL=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>/dev/null)

        # Check if the value returned is an integer (we we know digibyted is responding)
 #       if [ "$BLOCKCOUNT_LOCAL" -eq "$BLOCKCOUNT_LOCAL" ] 2>/dev/null; then
        if [ "$BLOCKCOUNT_LOCAL" = "" ]; then
          printf "%b%b %s NOT YET...\\n" "${OVER}" "${CROSS}" "${str}"
          DGB_STATUS="startingup"
        else
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # If DigiByte Core is currently in the process of starting up, we need to wait until it
    # can actually respond to requests so we can get the current version number from digibyte-cli
    if [ "$DGB_STATUS" = "startingup" ]; then
        every15secs=0
        progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
        str="DigiByte Core is in the process of starting up. This can take up to 10 minutes. Please wait..."
        printf "%b %s" "${INFO}" "${str}"
        tput civis
        while [ $DGB_STATUS = "startingup" ]; do

            # Show Spinner while waiting
            if [ "$progress" = "[${COL_BOLD_WHITE}◜ ${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE} ◝${COL_NC}]"
            elif [ "$progress" = "[${COL_BOLD_WHITE} ◝${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE} ◞${COL_NC}]"
            elif [ "$progress" = "[${COL_BOLD_WHITE} ◞${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE}◟ ${COL_NC}]"
            elif [ "$progress" = "[${COL_BOLD_WHITE}◟ ${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
            fi 

            if [ "$every15secs" -ge 30 ]; then
              BLOCKCOUNT_LOCAL=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>/dev/null)
              if [ "$BLOCKCOUNT_LOCAL" = "" ]; then
                printf "%b%b %s $progress Querying..." "${OVER}" "${INFO}" "${str}"
                every15secs=0
                sleep 0.5
              else
                DGB_STATUS="running"
                printf "%b%b %s Done!\\n" "${OVER}" "${INFO}" "${str}"
                tput cnorm
              fi
            else
                every15secs=$((every15secs + 1))
                printf "%b%b %s $progress" "${OVER}" "${INFO}" "${str}"
                sleep 0.5
            fi
        done

    fi

        # Get the version number of the current DigiByte Core and write it to to the settings file
    if [ "$DGB_STATUS" = "running" ]; then
        str="Current Version:"
        printf "%b %s" "${INFO}" "${str}"
        DGB_VER_LOCAL=$(sudo -u $USER_ACCOUNT $DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
        sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=$DGB_VER_LOCAL|" $DGNT_SETTINGS_FILE
        printf "%b%b %s DigiByte Core v${DGB_VER_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
    fi

      # If DigiByte Core is not running, we can't get the version number from there, so we will resort to what is in the diginode.settings file
    if [ "$DGB_STATUS" = "notrunning" ]; then
      # Double check by looking for the folder name in the home folder
      str="Looking for current version number in diginode.settings file..."
      printf "%b %s" "${INFO}" "${str}"

        # If the local version number is not stored
        if [ "$DGB_VER_LOCAL" = "" ]; then
            printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b Unable to find version number of current DigiByte Core install.\\n" "${CROSS}"
            printf "\\n"
            printf "%b DigiByte Core cannot be upgraded. Skipping...\\n" "${INFO}"
            printf "\\n"
            DGB_DO_INSTALL=NO
            DGB_INSTALL_TYPE="none"
            return     
        else
            printf "%b%b %s Found: v${DGB_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi


    # Check Github repo to find the version number of the latest DigiByte Core release
    str="Checking GitHub repository for the latest release..."
    printf "%b %s" "${INFO}" "${str}"
    DGB_VER_RELEASE=$(curl -sfL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//g')

    # If can't get Github version number
    if [ "$DGB_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of DigiByte Core. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b DigiByte Core cannot be upgraded. Skipping...\\n" "${INFO}"
        printf "\\n"
        DGB_DO_INSTALL=NO
        DGB_INSTALL_TYPE="none"
        DGB_UPDATE_AVAILABLE=NO
        return     
    else
        printf "%b%b %s Found: v${DGB_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^DGB_VER_RELEASE=/s|.*|DGB_VER_RELEASE=$DGB_VER_RELEASE|" $DGNT_SETTINGS_FILE
    fi


    # If a local version already exists.... (i.e. we have a local version number)
    if [ ! $DGB_VER_LOCAL = "" ]; then
      # ....then check if a DigiByte Core upgrade is required
      if [ $(version $DGB_VER_LOCAL) -ge $(version $DGB_VER_RELEASE) ]; then
          printf "%b DigiByte Core is already up to date.\\n" "${INFO}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to re-install DigiByte Core v${DGB_VER_RELEASE}.\\n" "${INFO}"
            DGB_INSTALL_TYPE="askreset"
          else
            printf "%b Upgrade not required.\\n" "${INFO}"
            DGB_DO_INSTALL=NO
            DGB_INSTALL_TYPE="none"
            DGB_UPDATE_AVAILABLE=NO
            printf "\\n"
            return
          fi
      else
          printf "%b %bDigiByte Core will be upgraded from v${DGB_VER_LOCAL} to v${DGB_VER_RELEASE}.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          DGB_INSTALL_TYPE="upgrade"
          DGB_ASK_UPGRADE=YES
      fi
    fi 

    # If no current version is installed, then do a clean install
    if [ $DGB_STATUS = "not_detected" ]; then
      printf "%b %bDigiByte Core v${DGB_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      DGB_INSTALL_TYPE="new"
      DGB_DO_INSTALL=YES
    fi

    printf "\\n"

}

# This function will install DigiByte Core if it not yet installed, and if it is, upgrade it to the latest release
# Note: It does not (re)start the digibyted.service automatically when done
digibyte_do_install() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$DGB_ASK_UPGRADE" = "YES" ]; then
    DGB_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall DigiByte Core
if [ "$DGB_INSTALL_TYPE" = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install DigiByte Core v${DGB_VER_RELEASE}?\\n\\nNote: This will delete your current DigiByte Core folder at $DGB_INSTALL_LOCATION and re-install it. Your DigiByte settings and wallet will not be affected." "${r}" "${c}"; then
        DGB_DO_INSTALL=YES
        DGB_INSTALL_TYPE="reset"
    else 
        DGB_DO_INSTALL=NO
        DGB_INSTALL_TYPE="skipreset"
        DGB_UPDATE_AVAILABLE=NO
    fi

fi

if [ "$DGB_INSTALL_TYPE" = "skipreset" ]; then
    printf " =============== Resetting: DigiByte Core =============================\\n\\n"
    # ==============================================================================
    printf "%b Reset Mode: You skipped re-installing DigiByte Core.\\n" "${INFO}"
    printf "\\n"
    return
fi

if [ "$DGB_DO_INSTALL" = "YES" ]; then

    # Display section break
    if [ "$DGB_INSTALL_TYPE" = "new" ]; then
        printf " =============== Installing: DigiByte Core =============================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf " =============== Upgrading: DigiByte Core ==============================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Resetting: DigiByte Core ==============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-install DigiByte Core.\\n" "${INFO}"
    fi


    # Stop DigiByte Core if it is running, as we need to upgrade or reset it
    if [ "$DGB_STATUS" = "running" ] && [ $DGB_INSTALL_TYPE = "upgrade" ]; then
       stop_service digibyted
       DGB_STATUS="stopped"
    elif [ "$DGB_STATUS" = "running" ] && [ $DGB_INSTALL_TYPE = "reset" ]; then
       stop_service digibyted
       DGB_STATUS="stopped"
    fi
    
   # Delete old DigiByte Core tar files, if present
    if compgen -G "$USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz" > /dev/null; then
        str="Deleting old DigiByte Core tar.gz files from home folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Dispaly the download URL
    if [ $VERBOSE_MODE = true ]; then
        printf "DigiByte binary URL: https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_RELEASE}/digibyte-${DGB_VER_RELEASE}-${ARCH}-linux-gnu.tar.gz" "${INFO}"
    fi

    # Downloading latest DigiByte Core binary from GitHub
    str="Downloading DigiByte Core v${DGB_VER_RELEASE} from Github repository..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT wget -q https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_RELEASE}/digibyte-${DGB_VER_RELEASE}-${ARCH}-linux-gnu.tar.gz -P $USER_HOME
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # If there is an old backup of DigiByte Core, delete it
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backuo" ]; then
        str="Deleting old backup of DigiByte Core v${DGB_VER_LOCAL}..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If an there is an existing version version, move it it to a backup version
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}" ]; then
        str="Backing up the existing version of DigiByte Core: $USER_HOME/digibyte-$DGB_VER_LOCAL ..."
        printf "%b %s" "${INFO}" "${str}"
        mv $USER_HOME/digibyte-${DGB_VER_LOCAL} $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Extracting DigiByte Core binary
    str="Extracting DigiByte Core v${DGB_VER_RELEASE} ..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT tar -xf $USER_HOME/digibyte-$DGB_VER_RELEASE-$ARCH-linux-gnu.tar.gz -C $USER_HOME
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Delete old ~/digibyte symbolic link
    if [ -h "$USER_HOME/digibyte" ]; then
        str="Deleting old 'digibyte' symbolic link from home folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/digibyte
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Create new symbolic link
    str="Creating new ~/digibyte symbolic link pointing at $USER_HOME/digibyte-$DGB_VER_RELEASE ..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT ln -s $USER_HOME/digibyte-$DGB_VER_RELEASE $USER_HOME/digibyte
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Delete the backup version, now the new version has been installed
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-OLD" ]; then
        str="Deleting previous version of DigiByte Core: $USER_HOME/digibyte-$DGB_VER_LOCAL-OLD ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -rf $USER_HOME/digibyte-${DGB_VER_LOCAL}-OLD
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    
    # Delete DigiByte Core tar.gz file
    str="Deleting DigiByte Core install file: digibyte-$DGB_VER_RELEASE-$ARCH-linux-gnu.tar.gz ..."
    printf "%b %s" "${INFO}" "${str}"
    rm -f $USER_HOME/digibyte-$DGB_VER_RELEASE-$ARCH-linux-gnu.tar.gz
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Update diginode.settings with new DigiByte Core local version number and the install/upgrade date
    DGB_VER_LOCAL=$DGB_VER_RELEASE
    sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=$DGB_VER_LOCAL|" $DGNT_SETTINGS_FILE
    if [ $DGB_INSTALL_TYPE = "install" ]; then
        sed -i -e "/^DGB_INSTALL_DATE=/s|.*|DGB_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ $DGB_INSTALL_TYPE = "upgrade" ]; then
        sed -i -e "/^DGB_UPGRADE_DATE=/s|.*|DGB_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Re-enable and re-start DigiByte daemon service after reset/upgrade
    if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf "%b Upgrade Completed: Renabling and restarting DigiByte daemon service ...\\n" "${INFO}"
        enable_service digibyted
        start_service digibyted
        DGB_STATUS="running"
    elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf "%b Reset Completed: Renabling and restarting DigiByte daemon service ...\\n" "${INFO}"
        enable_service digibyted
        start_service digibyted
        DGB_STATUS="running"
    fi

    # Reset DGB Install and Upgrade Variables
    DGB_INSTALL_TYPE=""
    DGB_UPDATE_AVAILABLE=NO
    DGB_POSTUPDATE_CLEANUP=YES

    # Create hidden file to denote this version was installed with the official installer
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then
        str="Labeling as official DigiNode install..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_INSTALL_LOCATION/.officialdiginode
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    printf "\\n"

fi

}


# This function will install or upgrade the local version of the 'DigiNode Tools' scripts.
# By default, it will always install the latest release version from GitHub. If the existing installed version
# is the develop version or an older release version, it will be upgraded to the latest release version.
# If the --dgnt_dev_branch flag is used at launch it will always replace the local version
# with the latest develop branch version from Github.

diginode_tools_check() {

printf " =============== Checking: DigiNode Tools ==============================\\n\\n"
# ==============================================================================

    local str

    #lookup latest release version on Github (need jq installed for this query)
    local dgnt_ver_release_query=$(curl -sL https://api.github.com/repos/saltedlolly/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')

    # If we get a response, update the stored release version
    if [ "$dgnt_ver_release_query" != "" ]; then
        DGNT_VER_RELEASE=$dgnt_ver_release_query
        sed -i -e "/^DGNT_VER_RELEASE=/s|.*|DGNT_VER_RELEASE=$DGNT_VER_RELEASE|" $DGNT_SETTINGS_FILE
    fi

    # Get the current local version and branch, if any
    if [[ -f "$DGNT_MONITOR_SCRIPT" ]]; then
        local dgnt_ver_local_query=$(cat $DGNT_MONITOR_SCRIPT | grep -m1 DGNT_VER_LOCAL  | cut -d'=' -f 2)

        DGNT_LOCAL_BRANCH=$(git -C $DGNT_LOCATION rev-parse --abbrev-ref HEAD 2>/dev/null)
    fi

    # If we get a valid version number, update the stored local version
    if [ "$dgnt_ver_local_query" != "" ]; then
        DGNT_VER_LOCAL=$dgnt_ver_local_query
        sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=$DGNT_VER_LOCAL|" $DGNT_SETTINGS_FILE
    fi

    # If we get a valid local branch, update the stored local branch
    if [ "$DGNT_LOCAL_BRANCH" != "" ]; then
        sed -i -e "/^DGNT_LOCAL_BRANCH=/s|.*|DGNT_LOCAL_BRANCH=$DGNT_LOCAL_BRANCH|" $DGNT_SETTINGS_FILE
    fi

    # Let's check if DigiNode Tools already installed
    str="Are DigiNode Tools already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ ! -f "$DGNT_MONITOR_SCRIPT" ]; then
        DGNT_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        DGNT_VER_LOCAL=""
        sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        DGNT_STATUS="installed"
        if [ "$DGNT_LOCAL_BRANCH" = "release" ]; then
            printf "%b%b %s YES!  DigiNode Tools v${DGNT_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGNT_LOCAL_BRANCH" = "develop" ]; then
            printf "%b%b %s YES!  DigiNode Tools develop branch\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGNT_LOCAL_BRANCH" = "main" ]; then
            printf "%b%b %s YES!  DigiNode Tools main branch\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # Requested branch
    if [ "$DGNT_BRANCH" = "develop" ]; then
        printf "%b DigiNode Tools develop branch requested.\\n" "${INFO}"
    elif [ "$DGNT_BRANCH" = "main" ]; then
        printf "%b DigiNode Tools main branch requested.\\n" "${INFO}"
    fi

    # If there is no release version (i.e. it returns 'null'), use the main version
    if [ "$DGNT_BRANCH" = "release" ] && [ "$DGNT_VER_RELEASE" = "null" ]; then
        printf "%b DigiNode Tools release branch requested.\\n" "${INFO}"
        printf "%b ERROR: Release branch is unavailable. main branch will be installed.\\n" "${CROSS}"
        DGNT_BRANCH="main"
    fi

   

    # Upgrade to release branch
    if [ "$DGNT_BRANCH" = "release" ]; then
        # If it's the release version lookup latest version (this is what is used normally, with no argument specified)

        if [ "$DGNT_LOCAL_BRANCH" = "release" ]; then

            if  [ $(version $DGNT_VER_LOCAL) -ge $(version $DGNT_VER_RELEASE) ]; then

                if [ "$RESET_MODE" = true ]; then
                    printf "%b Reset Mode is Enabled. You will be asked if you want to re-install DigiByte Core v${DGB_VER_RELEASE}.\\n" "${INFO}"
                    DGNT_INSTALL_TYPE="askreset"
                else
                    printf "%b DigiNode Tools are up to date.\\n" "${INFO}"
                    DGNT_INSTALL_TYPE="none"
                fi

            else        
                printf "%b %bDigiNode Tools can be upgraded from v{$DGNT_VER_LOCAL} to v${DGNT_VER_RELEASE}.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                DGNT_INSTALL_TYPE="upgrade"
                DGNT_ASK_UPGRADE=YES
            fi

        elif [ "$DGNT_LOCAL_BRANCH" = "main" ]; then
            printf "%b %bDigiNode Tools will be upgraded from the main branch to the v${DGNT_VER_RELEASE} release version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_LOCAL_BRANCH" = "develop" ]; then
            printf "%b %bDigiNode Tools will be upgraded from the develop branch to the v${DGNT_VER_RELEASE} release version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        else 
            printf "%b %bDigiNode Tools v${DGNT_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="new"
            DGNT_DO_INSTALL=YES
        fi

    # Upgrade to develop branch
    elif [ "$DGNT_BRANCH" = "develop" ]; then
        if [ "$DGNT_LOCAL_BRANCH" = "release" ]; then
            printf "%b %bDigiNode Tools v${DGNT_VER_LOCAL} will be replaced with the develop branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_LOCAL_BRANCH" = "main" ]; then
            printf "%b %bDigiNode Tools main branch will be replaced with the develop branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_LOCAL_BRANCH" = "develop" ]; then
            printf "%b %bDigiNode Tools develop version will be upgraded to the latest version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        else
            printf "%b %bDigiNode Tools develop branch will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="new"
            DGNT_DO_INSTALL=YES
        fi
    
    # Upgrade to main branch
    elif [ "$DGNT_BRANCH" = "main" ]; then
        if [ "$DGNT_LOCAL_BRANCH" = "release" ]; then
            printf "%b %bDigiNode Tools v${DGNT_VER_LOCAL} will replaced with the main branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_LOCAL_BRANCH" = "main" ]; then
            printf "%b %bDigiNode Tools main branch will be upgraded to the latest version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_LOCAL_BRANCH" = "develop" ]; then
            printf "%b %bDigiNode Tools develop branch will be replaced with the main branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        else
            printf "%b %bDigiNode Tools main branch will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="new"
            DGNT_DO_INSTALL=YES
        fi
    fi
    printf "\\n"

}



diginode_tools_do_install() {

# If we are in unattended mode and there is an upgrade to do, then go ahead and do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$DGNT_ASK_UPGRADE" = "YES" ]; then
    DGNT_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall DigiByte Core
if [ $DGNT_INSTALL_TYPE = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install DigiAsset Tools v${DGNT_VER_RELEASE}?\\n\\nNote: This will delete your current DigiNode Tools folder at $DGNT_LOCATION and re-install it." "${r}" "${c}"; then
        printf "%b Reset Mode: You chose to re-install DigiNode Tools\\n" "${INFO}"
        DGNT_DO_INSTALL=YES
        DGNT_INSTALL_TYPE="reset"
    else
        printf " =============== Resetting: DigNode Tools ==============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You skipped re-installing DigiNode Tools\\n" "${INFO}"
        printf "\\n"
        DGNT_DO_INSTALL=NO
        DGNT_INSTALL_TYPE="none"
        return
    fi

fi


    # If a new version needs to be installed, do it now
    if [ "$DGNT_DO_INSTALL" = "YES" ]; then

                # Display section break
        if [ "$DGNT_INSTALL_TYPE" = "new" ]; then
            printf " =============== Installing: DigNode Tools =============================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "upgrade" ]; then
            printf " =============== Upgrading: DigNode Tools ==============================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "reset" ]; then
            printf " =============== Resetting: DigNode Tools ==============================\\n\\n"
            # ==============================================================================
            printf "%b Reset Mode: You chose to re-install DigNode Tools.\\n" "${INFO}"
        fi

        # first delete the current installed version of DigiNode Tools (if it exists)
        if [[ -d $DGNT_LOCATION ]]; then
            str="Removing DigiNode Tools current version..."
            printf "%b %s" "${INFO}" "${str}"
            rm -rf $DGNT_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Next install the newest version
        cd $USER_HOME
        # Clone the develop version if develop flag is set
        if [ "$DGNT_BRANCH" = "develop" ]; then
            str="Installing DigiNode Tools develop branch..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch develop https://github.com/saltedlolly/diginode-tools/
            sed -i -e "/^DGNT_LOCAL_BRANCH=/s|.*|DGNT_LOCAL_BRANCH=develop|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        # Clone the develop version if develop flag is set
        elif [ "$DGNT_BRANCH" = "main" ]; then
            str="Installing DigiNode Tools main branch..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch main https://github.com/saltedlolly/diginode-tools/
            sed -i -e "/^DGNT_LOCAL_BRANCH=/s|.*|DGNT_LOCAL_BRANCH=main|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGNT_BRANCH" = "release" ]; then
            str="Installing DigiNode Tools v${DGNT_VER_RELEASE}..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet https://github.com/saltedlolly/diginode-tools/
            sed -i -e "/^DGNT_LOCAL_BRANCH=/s|.*|DGNT_LOCAL_BRANCH=release|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=$DGNT_VER_RELEASE|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Make downloads executable
        str="Making DigiNode scripts executable..."
        printf "%b %s" "${INFO}" "${str}"
        chmod +x $DGNT_INSTALLER_SCRIPT
        chmod +x $DGNT_MONITOR_SCRIPT
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Add alias so entering 'diginode' works from any folder
        if grep -q "alias diginode=" "$USER_HOME/.bashrc"; then
            str="Updating 'diginode' alias in .bashrc file..."
            printf "%b %s" "${INFO}" "${str}"
            # Update existing alias for 'diginode'
            sed -i -e "/^alias diginode=/s|.*|alias diginode='$DGNT_MONITOR_SCRIPT'|" $USER_HOME/.bashrc
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            str="Adding 'diginode' alias to .bashrc file..."
            printf "%b %s" "${INFO}" "${str}"
            # Append alias to .bashrc file
            echo "" >> $USER_HOME/.bashrc
            echo "# Alias for DigiNode tools so that entering 'diginode' will run this from any folder" >> $USER_HOME/.bashrc
            echo "alias diginode='$DGNT_MONITOR_SCRIPT'" >> $USER_HOME/.bashrc
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Add alias so entering 'diginode-installer' works from any folder
        if grep -q "alias diginode-installer=" "$USER_HOME/.bashrc"; then
            str="Updating 'diginode-installer' alias in .bashrc file..."
            printf "%b %s" "${INFO}" "${str}"
            # Update existing alias for 'diginode'
            sed -i -e "/^alias diginode-installer=/s|.*|alias diginode-installer='$DGNT_INSTALLER_SCRIPT'|" $USER_HOME/.bashrc
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            str="Adding 'diginode-installer' alias to .bashrc file..."
            printf "%b %s" "${INFO}" "${str}"
            # Append alias to .bashrc file
            echo "" >> $USER_HOME/.bashrc
            echo "# Alias for DigiNode tools so that entering 'diginode-installer' will run this from any folder" >> $USER_HOME/.bashrc
            echo "alias diginode-installer='$DGNT_INSTALLER_SCRIPT'" >> $USER_HOME/.bashrc
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
        printf "\\n"
    fi
}


# This function will check if IPFS is installed, and if it is, check if there is an update available

ipfs_check() {

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    printf " =============== Checking: IPFS daemon =================================\\n\\n"
    # ==============================================================================

    # Get the local version number of IPFS Updater (this will also tell us if it is installed)
    IPFSU_VER_LOCAL=$(ipfs-update --version 2>/dev/null | cut -d' ' -f3)

    # Let's check if IPFS Updater is already installed
    str="Is IPFS Updater already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$IPFSU_VER_LOCAL" = "" ]; then
        IPFSU_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        IPFSU_VER_LOCAL=""
        sed -i -e "/^IPFSU_VER_LOCAL=/s|.*|IPFSU_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFSU_STATUS="installed"
        sed -i -e "/^IPFSU_VER_LOCAL=/s|.*|IPFSU_VER_LOCAL=$IPFSU_VER_LOCAL|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: IPFS Updater v${IPFSU_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Check for latest IPFS Updater release online
    str="Checking IPFS website for the latest IPFS Updater release..."
    printf "%b %s" "${INFO}" "${str}"
    # Gets latest IPFS Updater version, disregarding releases candidates (they contain 'rc' in the name).
    IPFSU_VER_RELEASE=$(curl -sL https://dist.ipfs.io/ipfs-update/versions 2>/dev/null | tail -n 1 | sed 's/v//g')

    # If can't get Github version number
    if [ "$IPFSU_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of IPFS Updater. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b IPFS Updater cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"
        IPFSU_DO_INSTALL=NO
        IPFSU_INSTALL_TYPE="none"
        IPFSU_UPDATE_AVAILABLE=NO
        return     
    else
        printf "%b%b %s Found: v${IPFSU_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^IPFSU_VER_RELEASE=/s|.*|IPFSU_VER_RELEASE=$IPFSU_VER_RELEASE|" $DGNT_SETTINGS_FILE
    fi

    # If an IPFS Updater local version already exists.... (i.e. we have a local version number)
    if [ ! $IPFSU_VER_LOCAL = "" ]; then
      # ....then check if an upgrade is required
      if [ $(version $IPFSU_VER_LOCAL) -ge $(version $IPFSU_VER_RELEASE) ]; then
          printf "%b IPFS Updater is already up to date.\\n" "${TICK}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to reinstall IPFS Updater v${IPFSU_VER_RELEASE}.\\n" "${INFO}"
            IPFSU_INSTALL_TYPE="askreset"
            IPFSU_DO_INSTALL=YES
          else
            printf "%b Upgrade not required for IPFS Updater tool.\\n" "${INFO}"
            IPFSU_DO_INSTALL=NO
            IPFSU_INSTALL_TYPE="none"
            IPFSU_UPDATE_AVAILABLE=NO
          fi
      else
          printf "%b %bIPFS Updater will be upgraded from v${IPFSU_VER_LOCAL} to v${IPFSU_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          IPFSU_INSTALL_TYPE="upgrade"
          IPFSU_DO_UPGRADE=YES
      fi
    fi 

    # If no current version is installed, then do a clean install
    if [ $IPFSU_STATUS = "not_detected" ]; then
      printf "%b %bIPFS Updater v${IPFSU_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      IPFSU_INSTALL_TYPE="new"
      IPFSU_DO_INSTALL=YES
    fi

    # Check for latest Go-IPFS release online
    str="Checking IPFS website for the latest Go-IPFS release..."
    printf "%b %s" "${INFO}" "${str}"
    # Gets latest Go-IPFS version, disregarding releases candidates (they contain 'rc' in the name).
    IPFS_VER_RELEASE=$(curl -sL https://dist.ipfs.io/go-ipfs/versions 2>/dev/null | sed '/rc/d' | tail -n 1 | sed 's/v//g')

    # If can't get Github version number
    if [ "$IPFS_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of Go-IPFS. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b Go-IPFS cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"
        IPFS_DO_INSTALL=NO
        IPFS_INSTALL_TYPE="none"
        IPFS_UPDATE_AVAILABLE=NO
        return     
    else
        printf "%b%b %s Found: v${IPFS_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^IPFS_VER_RELEASE=/s|.*|IPFS_VER_RELEASE=$IPFS_VER_RELEASE|" $DGNT_SETTINGS_FILE
    fi

    # Get the local version number of Go-IPFS (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Let's check if Go-IPFS is already installed
    str="Is Go-IPFS already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=$IPFS_VER_LOCAL|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: Go-IPFS v${IPFS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Next let's check if IPFS daemon is running with upstart
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
      str="Is Go-IPFS daemon service running?..."
      printf "%b %s" "${INFO}" "${str}"
      if check_service_active "ipfs"; then # BANANA
          IPFS_STATUS="running"
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
      else
          IPFS_STATUS="stopped"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
      fi
    fi

    # Next let's check if IPFS daemon is running
    if [ systemctl is-active --quiet --user ipfs ]; then
      str="Is Go-IPFS daemon service running?..."
      printf "%b %s" "${INFO}" "${str}"
      if check_service_active "ipfs"; then # BANANA
          IPFS_STATUS="running"
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
      else
          IPFS_STATUS="stopped"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
      fi
    fi


    # If a Go-IPFS local version already exists.... (i.e. we have a local version number)
    if [ ! $IPFS_VER_LOCAL = "" ]; then
      # ....then check if an upgrade is required
      if [ $(version $IPFS_VER_LOCAL) -ge $(version $IPFS_VER_RELEASE) ]; then
          printf "%b Go-IPFS is already up to date.\\n" "${TICK}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to reinstall Go-IPFS v${IPFS_VER_RELEASE}.\\n" "${INFO}"
            IPFS_INSTALL_TYPE="askreset"
            IPFS_DO_INSTALL=YES
          else
            printf "%b Upgrade not required.\\n" "${INFO}"
            IPFS_DO_INSTALL=NO
            IPFS_INSTALL_TYPE="none"
            IPFS_UPDATE_AVAILABLE=NO
            printf "\\n"
            return
          fi
      else
          printf "%b Go-IPFS can be be upgraded from v${IPFS_VER_LOCAL} to v${IPFS_VER_RELEASE}\\n" "${INFO}"
          IPFS_INSTALL_TYPE="upgrade"
          IPFS_ASK_UPGRADE=YES
      fi
    fi 

    # If no current version is installed, then do a clean install
    if [ $IPFS_STATUS = "not_detected" ]; then
      printf "%b %bGo-IPFS v${IPFS_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      IPFS_INSTALL_TYPE="new"
      IPFS_DO_INSTALL="if_doing_full_install"
    fi

    printf "\\n"

fi

}

# This function will install Go-IPFS if it not yet installed, and if it is, upgrade it to the latest release
ipfs_do_install() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
    IPFS_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall DigiByte Core
if [ "$IPFS_INSTALL_TYPE" = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install Go-IPFS v${IPFS_VER_RELEASE}?\\n\\nThis will delete both Go-IPFS and the IPFS Updater utility and re-install them." "${r}" "${c}"; then
        IPFS_DO_INSTALL=YES
        IPFS_INSTALL_TYPE="reset"
        # Reset IPFS Updater as well, if needed
        if [ $IPFSU_INSTALL_TYPE = "askreset" ]; then
            IPFSU_DO_INSTALL=YES
            IPFSU_INSTALL_TYPE="reset"
        fi
    else        
        printf " =============== Resetting: IPFS =======================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You skipped re-installing Go-IPFS.\\n" "${INFO}"
        IPFS_DO_INSTALL=NO
        IPFS_INSTALL_TYPE="none"
        IPFS_UPDATE_AVAILABLE=NO
        # Don't reset IPFS Updater, if we are not resetting Go-IPFS (no point)
        if [ $IPFSU_INSTALL_TYPE = "askreset" ]; then
            IPFSU_DO_INSTALL=NO
            IPFSU_INSTALL_TYPE="none"
        fi
        return
    fi

fi

# If this is a new install of IPFS, and the user has opted to do a full DigiNode install, then proceed
if  [ "$IPFS_INSTALL_TYPE" = "new" ] && [ "$IPFS_DO_INSTALL" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    IPFS_DO_INSTALL=YES
fi


if [ "$IPFS_DO_INSTALL" = "YES" ]; then

    # Display section break
    if [ "$IPFS_INSTALL_TYPE" = "new" ]; then
        printf " =============== Installing: IPFS ======================================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
        printf " =============== Upgrading: IPFS =======================================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Resetting: IPFS =======================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-install Go-IPFS.\\n" "${INFO}"
    fi

    # Let's find the correct file type to download based on the current architecture
    if [ "$ARCH" = "aarch64" ]; then
        ipfsarch="arm64"
    elif [ "$ARCH" = "X86_64" ]; then
        ipfsarch="amd64"
    fi

    # First, Upgrade IPFS Updater if there is an update

    if [ "$IPFSU_DO_INSTALL" = "YES" ]; then

        # If we are re-installing the current version of IPFS Updater, delete the existing install folder
        if [ $IPFSU_INSTALL_TYPE = "reset" ]; then
            str="Reset Mode: Deleting IPFS Updater v${IPFSU_VER_LOCAL}..."
            printf "%b %s" "${INFO}" "${str}"
            rm -r /usr/local/bin/ipfs-update
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If we are updating the current version of IPFS Updater, delete the existing install folder
        if [ $IPFSU_INSTALL_TYPE = "upgrade" ]; then
            str="Preparing Upgrade: Deleting IPFS Updater v${IPFSU_VER_LOCAL}..."
            printf "%b %s" "${INFO}" "${str}"
            rm -r /usr/local/bin/ipfs-update
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi


        # Delete any old IPFS Updater tar files
        if compgen -G "$USER_HOME/ipfs-update*.tar.gz" > /dev/null; then
            str="Deleting any old IPFS Updater tar.gz files from home folder..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $USER_HOME/ipfs-update*.tar.gz
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Downloading latest IPFS Updater tar.gz from IPFS distributions website
        str="Downloading IPFS Updater v${IPFSU_VER_RELEASE} from IPFS distributions website..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT wget -q https://dist.ipfs.io/ipfs-update/v${IPFSU_VER_RELEASE}/ipfs-update_v${IPFSU_VER_RELEASE}_linux-${ipfsarch}.tar.gz -P $USER_HOME
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Delete old IPFS Updater backup, if it exists
        if [ -d "$USER_HOME/ipfs-update-oldversion" ]; then
            str="Deleting old backup of IPFS Updater..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $USER_HOME/ipfs-update-oldversion
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If an there is an existing IPFS Update version, move it it to a backup version
        if [ -d "$USER_HOME/ipfs-update" ]; then
            str="Backing up the existing version of IPFS Updater to $USER_HOME/ipfs-update-oldversion..."
            printf "%b %s" "${INFO}" "${str}"
            mv $USER_HOME/ipfs-update $USER_HOME/ipfs-update-oldversion
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Extracting IPFS Updator tar.gz
        str="Extracting IPFS Updator v${IPFSU_VER_RELEASE} ..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT tar -xf $USER_HOME/ipfs-update_v${IPFSU_VER_RELEASE}_linux-${ipfsarch}.tar.gz -C $USER_HOME
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Install IPFS Updater
        printf "%b Installing IPFS Updater v${IPFSU_VER_RELEASE} ...\\n" "${INFO}"
        cd $USER_HOME/ipfs-update/
        bash install.sh
        cd $USER_HOME

        # Delete the IPFS Updater backup version, now the new version has been installed
        if [ -d "$USER_HOME/ipfs-update-oldversion" ]; then
            str="Deleting previous version of IPFS Updater: $USER_HOME/ipfs-update-oldversion ..."
            printf "%b %s" "${INFO}" "${str}"
            rm -rf $USER_HOME/ipfs-update-oldversion
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Delete the IPFS Updater backup version, now the new version has been installed
        if [ -d "$USER_HOME/ipfs-update-oldversion" ]; then
            str="Deleting IPFS Updater install folder: $USER_HOME/ipfs-update-oldversion ..."
            printf "%b %s" "${INFO}" "${str}"
            rm -rf $USER_HOME/ipfs-update
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Delete IPFS Updater tar.gz installer file
        str="Deleting IPFS Updater install file: $USER_HOME/ipfs-update_v${IPFSU_VER_RELEASE}_linux-${ipfsarch}.tar.gz ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $USER_HOME/ipfs-update_v${IPFSU_VER_RELEASE}_linux-${ipfsarch}.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Get the new version number of the local IPFS Updater install
        IPFSU_VER_LOCAL=$(ipfs-update --version 2>/dev/null | cut -d' ' -f3)

        # Update diginode.settings with new IPFS Updater local version number and the install/upgrade date
        sed -i -e "/^IPFSU_VER_LOCAL=/s|.*|IPFSU_VER_LOCAL=$IPFSU_VER_LOCAL|" $DGNT_SETTINGS_FILE
        if [ $IPFSU_INSTALL_TYPE = "install" ]; then
            sed -i -e "/^IPFSU_INSTALL_DATE=/s|.*|IPFSU_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
        elif [ $IPFSU_INSTALL_TYPE = "upgrade" ]; then
            sed -i -e "/^IPFSU_UPGRADE_DATE=/s|.*|IPFSU_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
        fi

        # Reset IPFS Updater Install and Upgrade Variables
        IPFSU_INSTALL_TYPE=""
        IPFSU_UPDATE_AVAILABLE=NO
        IPFSU_POSTUPDATE_CLEANUP=YES

    fi


     # Stop IPFS service if it is running, as we need to upgrade or reset it
    if [ "$IPFS_STATUS" = "running" ]; then

        if [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Preparing Upgrade: Stopping IPFS service ...\\n" "${INFO}"
        elif [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
            printf "%b Preparing Reset: Stopping IPFS service ...\\n" "${INFO}"
        fi

        if [ "$INIT_SYSTEM" = "systemd" ]; then

            # Disable the service from running at boot
            printf "%b Disabling IPFS systemd service...\\n" "${INFO}"
            sudo -u $USER_ACCOUNT sudo -u $USER_ACCOUNT systemctl --user disable ipfs
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Stop the service now
            str="Stopping IPFS systemd service..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT systemctl --user stop ipfs
            IPFS_STATUS="stopped"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        fi

        if [ "$INIT_SYSTEM" = "upstart" ]; then

            # Enable the service to run at boot
            printf "%b Stopping IPFS upstart service...\\n" "${INFO}"
            service ipfs stop
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_STATUS="stopped"

        fi
    fi


    # If we are re-installing the current version of Go-IPFS, delete the existing binary
    if [ $IPFS_INSTALL_TYPE = "reset" ]; then
        str="Reset Mode: Deleting Go-IPFS v${IPFS_VER_LOCAL} ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f /usr/local/bin/ipfs
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"

        # Delete IPFS settings
        if [ -d "$USER_HOME/.ipfs" ]; then
            if whiptail --backtitle "" --title "RESET MODE" --yesno "Would you like to reset your IPFS settings folder?\\n\\nThis will delete the folder: ~/.ipfs" "${r}" "${c}"; then
                str="Reset Mode: Deleting ~/.ipfs settings folder..."
                printf "%b %s" "${INFO}" "${str}"
                rm -r $USER_HOME/.ipfs
                printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b Reset Mode: You chose not to reset the IPFS settings folder (~/.ipfs).\\n" "${INFO}"
            fi
        fi
    fi

    # Install latest version of GoIPFS
    printf "%b Installing Go-IPFS version v${IPFS_VER_RELEASE} ...\\n" "${INFO}"
    sudo ipfs-update install latest
    if [ "$IPFS_STATUS" = "not_detected" ];then
        IPFS_STATUS="installed"
    fi

    # Get the new version number of the local Go-IPFS install
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Update diginode.settings with new Go local version number and the install/upgrade date
    sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=$IPFS_VER_LOCAL|" $DGNT_SETTINGS_FILE
    if [ $IPFS_INSTALL_TYPE = "install" ]; then
        sed -i -e "/^IPFS_INSTALL_DATE=/s|.*|IPFS_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ $IPFS_INSTALL_TYPE = "upgrade" ]; then
        sed -i -e "/^IPFS_UPGRADE_DATE=/s|.*|IPFS_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Initialize IPFS, if it has not already been done so
    if [ ! -d "$USER_HOME/.ipfs" ]; then
        sudo -u $USER_ACCOUNT ipfs init
        sudo -u $USER_ACCOUNT ipfs cat /ipfs/QmQPeNsJPyVWPFDVHb77w8G42Fvo15z4bG2X8D2GhfbSXc/readme
    fi

    # Re-enable and re-start IPFS service after reset/upgrade
    if [ "$IPFS_STATUS" = "stopped" ]; then

        if [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Upgrade Completed: Renabling and restarting IPFS service ...\\n" "${INFO}"
        elif [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Completed: Renabling and restarting IPFS service ...\\n" "${INFO}"
        fi

        if [ "$INIT_SYSTEM" = "systemd" ]; then

            # Enable the service to run at boot
            printf "%b Enabling IPFS systemd service...\\n" "${INFO}"
            sudo -u $USER_ACCOUNT sudo -u $USER_ACCOUNT systemctl --user enable ipfs
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Start the service now
            str="Starting IPFS systemd service..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT sudo -u $USER_ACCOUNT systemctl --user start ipfs
            IPFS_STATUS="running"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [ "$INIT_SYSTEM" = "upstart" ]; then

            # Enable the service to run at boot
            printf "%b Starting IPFS upstart service...\\n" "${INFO}"
            service ipfs start
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_STATUS="running"

        fi

    fi

    # Reset GoIPFS Install and Upgrade Variables
    IPFS_INSTALL_TYPE=""
    IPFS_UPDATE_AVAILABLE=NO
    IPFS_POSTUPDATE_CLEANUP=YES

fi

printf "\\n"

}

# Create service so that IPFS will run at boot
ipfs_create_service() {

# If you want to make changes to how IPFS services are created/managed for diferent systems, refer to this website:
# https://github.com/ipfs/go-ipfs/tree/master/misc 


# If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
if [ "$RESET_MODE" = true ]; then

    # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
    if [ test -f "$IPFS_SYSTEMD_SERVICE_FILE" ] || [ test -f "$IPFS_UPSTART_SERVICE_FILE" ]; then

        if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-configure the IPFS service?\\n\\nThe IPFS service ensures that your IPFS daemon starts automatically at boot, and stays running 24/7. This will delete your existing IPFS service file and recreate it." "${r}" "${c}"; then
            IPFS_CREATE_SERVICE=YES
            IPFS_SERVICE_INSTALL_TYPE="reset"
        else
            printf " =============== Resetting: IPFS Daemon Service ========================\\n\\n"
            # ==============================================================================
            printf "%b Reset Mode: You skipped re-configuring the IPFS service.\\n" "${INFO}"
            IPFS_CREATE_SERVICE=NO
            IPFS_SERVICE_INSTALL_TYPE="none"
            return
        fi
    fi
fi

# If the SYSTEMD service files do not yet exist, then assume this is a new install
if [ ! -f "$IPFS_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
            IPFS_CREATE_SERVICE="if_doing_full_install"
            IPFS_SERVICE_INSTALL_TYPE="new"
fi

# If the UPSTART service files do not yet exist, then assume this is a new install
if [ ! -f "$IPFS_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
            IPFS_CREATE_SERVICE="if_doing_full_install"
            IPFS_SERVICE_INSTALL_TYPE="new"
fi

# If this is a new install of DigiAsset Node, and the user has opted to do a full DigiNode install, then proceed
if  [ "$IPFS_SERVICE_INSTALL_TYPE" = "new" ] && [ "$IPFS_CREATE_SERVICE" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    IPFS_CREATE_SERVICE=YES
fi


if [ "$IPFS_CREATE_SERVICE" = "YES" ]; then

    # Display section break
    if [ "$IPFS_SERVICE_INSTALL_TYPE" = "new" ]; then
        printf " =============== Installing: IPFS Daemon Service =======================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_SERVICE_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Resetting: IPFS Daemon Service ========================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-configure the IPFS service.\\n" "${INFO}"
    fi


    # If IPFS systemd service file already exists, and we are in Reset Mode, stop it and delete it, since we will replace it
    if [ -f "$IPFS_SYSTEMD_SERVICE_FILE" ] && [ "$IPFS_SERVICE_INSTALL_TYPE" = "reset" ]; then

        printf "%b Preparing Reset: Stopping and disabling IPFS service ...\\n" "${INFO}"

        # Stop the service now
        sudo -u $USER_ACCOUNT systemctl --user stop ipfs
        IPFS_STATUS="stopped"

        # Disable the service now
        sudo -u $USER_ACCOUNT systemctl --user disable ipfs

        # Disable linger
        loginctl disable-linger $USER_ACCOUNT

        str="Deleting IPFS systemd service file: $IPFS_SYSTEMD_SERVICE_FILE ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $IPFS_SYSTEMD_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If IPFS upstart service file already exists, and we are in Reset Mode, delete it, since we will update it
    if [ -f "$IPFS_UPSTART_SERVICE_FILE" ] && [ "$IPFS_SERVICE_INSTALL_TYPE" = "reset" ]; then

        printf "%b Preparing Reset: Stopping IPFS service ...\\n" "${INFO}"

        # Start the service now
        str="Stopping IPFS upstart service..."
        printf "%b %s" "${INFO}" "${str}"
        service ipfs stop
        IPFS_STATUS="stopped"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        str="Deleting IPFS upstart service file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $IPFS_UPSTART_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi


    # If using systemd and the IPFS service file does not exist yet, let's create it
    if [ ! -f "$IPFS_SYSTEMD_SERVICE_FILE" ] && [ $INIT_SYSTEM = "systemd" ]; then

        printf "\\n" 
        printf "%b IPFS systemd service will now be created.\\n" "${INFO}"

        # First create the folders it lives in if they don't already exist

        if [ ! -d $USER_HOME/.config ]; then
            str="Creating ~/.config folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $USER_HOME/.config
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
        if [ ! -d $USER_HOME/.config/systemd ]; then
            str="Creating ~/.config/systemd folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $USER_HOME/.config/systemd
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
        if [ ! -d $USER_HOME/.config/systemd/user ]; then
            str="Creating ~/.config/systemd/user folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $USER_HOME/.config/systemd/user
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
        
        # Create a new IPFS service file

        str="Creating IPFS systemd service file: $IPFS_SYSTEMD_SERVICE_FILE ... "
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $IPFS_SYSTEMD_SERVICE_FILE
        sudo -u $USER_ACCOUNT cat <<EOF > $IPFS_SYSTEMD_SERVICE_FILE
[Unit]
Description=IPFS daemon

[Service]
# Environment="IPFS_PATH=/data/ipfs"  # optional path to ipfs init directory if not default (\$HOME/.ipfs)
ExecStart=/usr/local/bin/ipfs daemon
Restart=on-failure

[Install]
WantedBy=default.target
EOF
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Enable linger so IPFS can run at boot
        str="Enable lingering for user $USER_ACCOUNT..."
        printf "%b %s" "${INFO}" "${str}"
        loginctl enable-linger $USER_ACCOUNT
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Enable the service to run at boot
        printf "%b Enabling IPFS systemd service...\\n" "${INFO}"
        sudo -u $USER_ACCOUNT systemctl --user enable ipfs
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Start the service now
        str="Starting IPFS systemd service..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT systemctl --user start ipfs
        IPFS_STATUS="running"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    fi

    # If using upstart and the IPFS service file does not exist yet, let's create it
    if [ -f "$IPFS_UPSTART_SERVICE_FILE" ] && [ $INIT_SYSTEM = "upstart" ]; then

        # Create a new IPFS upstart service file

        str="Creating IPFS upstart service file: $IPFS_UPSTART_SERVICE_FILE ... "
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $IPFS_UPSTART_SERVICE_FILE
        sudo -u $USER_ACCOUNT cat <<EOF > $IPFS_UPSTART_SERVICE_FILE
description "ipfs: interplanetary filesystem"

start on (local-filesystems and net-device-up IFACE!=lo)
stop on runlevel [!2345]

limit nofile 524288 1048576
limit nproc 524288 1048576
setuid $USER_ACCOUNT
chdir $USER_HOME
respawn
exec ipfs daemon
EOF
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"


        # Start the service now
        str="Starting IPFS upstart service..."
        printf "%b %s" "${INFO}" "${str}"
        service ipfs start
        IPFS_STATUS="running"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    fi

    # If the system is not using upstart or systemd then quit since others are not yet supported
    if [ $INIT_SYSTEM = "sysv-init" ] || [ $INIT_SYSTEM = "unknown" ]; then

        printf "%b Unable to create an IPFS service for your system - systemd/upstart not found.\\n" "${CROSS}"
        printf "%b Please contact @digibytehelp on Twitter for help.\\n" "${CROSS}"
        exit 1

    fi

fi

printf "\\n"

}

# This function will check if NodeJS is installed, and if it is, check if there is an update available
# LAtest distrbutions can be checked here: https://github.com/nodesource/distributions 

nodejs_check() {

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    printf " =============== Checking: NodeJS ======================================\\n\\n"
    # ==============================================================================

    # Get the local version number of NodeJS (this will also tell us if it is installed)
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')

    # Later versions use purely the 'node --version' command, (rather than nodejs)
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
    fi

    # Let's check if NodeJS is already installed
    str="Is NodeJS already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        NODEJS_STATUS="installed"
        sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=$NODEJS_VER_LOCAL|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: NodeJS v${NODEJS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If this is the first time running the NodeJS check, and we are doing a full install, let's add the official repositories to ensure we get the latest version
    if [ "$NODEJS_PPA_ADDED" = "" ] || [ "$NODEJS_PPA_ADDED" = "NO" ]; then

        # Is this Debian or Ubuntu?
        local is_debian=$(cat /etc/issue | grep -Eo "Debian" 2>/dev/null)
        local is_ubuntu=$(cat /etc/issue | grep -Eo "Ubuntu" 2>/dev/null)

        # Set correct PPA repository
        if [ "$is_debian" = "Debian" ]; then
            printf "%b Adding NodeSource PPA for NodeJS LTS version for Debian...\\n" "${INFO}"
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
        fi
        if [ "$is_ubuntu" = "Ubuntu" ]; then
            printf "%b Adding NodeSource PPA for NodeJS LTS version for Ubuntu...\\n" "${INFO}"
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        fi


        # Update variable in diginode.settings so this does not run again
        NODEJS_PPA_ADDED=YES
        sed -i -e "/^NODEJS_PPA_ADDED=/s|.*|NODEJS_PPA_ADDED=$NODEJS_PPA_ADDED|" $DGNT_SETTINGS_FILE
    else
        printf "%b NodeSource PPA repository has already been added. It should only need to be done once.\\n" "${TICK}"
        printf "%b If needed, you can have this script add it again, by editing the diginode.settings\\n" "${INDENT}"
        printf "%b file in the ~/.digibyte folder and changing the NODEJS_PPA_ADDED value to NO. \\n" "${INDENT}"
    fi

    # Look up the latest candidate release
    str="Checking for the latest NodeJS LTS release..."
    printf "%b %s" "${INFO}" "${str}"
    # Gets latest Go-IPFS version, disregarding releases candidates (they contain 'rc' in the name).
    NODEJS_VER_RELEASE=$(apt-cache policy nodejs | grep Candidate | cut -d' ' -f4 | cut -d'-' -f1)

    if [ "$NODEJS_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for release version of NodeJS.\\n" "${CROSS}"
        printf "\\n"
        printf "%b NodeJS cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"
        NODEJS_DO_INSTALL=NO
        NODEJS_INSTALL_TYPE="none"
        NODEJS_UPDATE_AVAILABLE=NO
        return
    else
        printf "%b%b %s Found: v${NODEJS_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^NODEJS_VER_RELEASE=/s|.*|NODEJS_VER_RELEASE=$NODEJS_VER_RELEASE|" $DGNT_SETTINGS_FILE
    fi

    # If a NodeJS local version already exists.... (i.e. we have a local version number)
    if [ "$NODEJS_VER_LOCAL" != "" ]; then
      # ....then check if an upgrade is required
      if [ $(version $NODEJS_VER_LOCAL) -ge $(version $NODEJS_VER_RELEASE) ]; then
          printf "%b NodeJS is already up to date.\\n" "${TICK}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to re-install NodeJS v${NODEJS_VER_RELEASE}.\\n" "${INFO}"
            NODEJS_INSTALL_TYPE="askreset"
            NODEJS_DO_INSTALL=YES
          else
            printf "%b Upgrade not required.\\n" "${INFO}"
            printf "\\n"
            NODEJS_DO_INSTALL=NO
            NODEJS_INSTALL_TYPE="none"
            NODEJS_UPDATE_AVAILABLE=NO
            return
          fi
      else
          printf "%b NodeJS can be upgraded from v${NODEJS_VER_LOCAL} to v${NODEJS_VER_RELEASE}\\n" "${INFO}"
          NODEJS_INSTALL_TYPE="upgrade"
          NODEJS_ASK_UPGRADE=YES
      fi
    fi

    # If a NodeJS needs to be upgraded...
    if [ "$NODEJS_INSTALL_TYPE" = "upgrade" ]; then
      # ....does it require a major upgrade? (e.g. from before v14)
      if [ $(version $NODEJS_VER_LOCAL) -lt $(version 14.0.0) ]; then
            NODEJS_INSTALL_TYPE="majorupgrade"
      fi
    fi 

    # If no current version is installed, then do a clean install
    if [ "$NODEJS_STATUS" = "not_detected" ]; then
      printf "%b NodeJS v${NODEJS_VER_RELEASE} will be installed.\\n" "${INFO}"
      NODEJS_INSTALL_TYPE="new"
      NODEJS_DO_INSTALL="if_doing_full_install"
    fi

    printf "\\n"

fi

}

# This function will install NodeJS if it not yet installed, and if it is, upgrade it to the latest release
nodejs_do_install() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$NODEJS_ASK_UPGRADE" = "YES" ]; then
    NODEJS_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to re-install NodeJS
if [ "$NODEJS_INSTALL_TYPE" = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install NodeJS v${NODEJS_VER_RELEASE}\\n\\nNote: This will delete NodeJS and re-install it." "${r}" "${c}"; then
        NODEJS_DO_INSTALL=YES
        NODEJS_INSTALL_TYPE="reset"
    else
        printf " =============== Resetting: NodeJS =====================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You skipped re-installing NodeJS.\\n" "${INFO}"
        printf "\\n"
        NODEJS_DO_INSTALL=NO
        NODEJS_INSTALL_TYPE="none"
        NODEJS_UPDATE_AVAILABLE=NO
        return
    fi

fi

# If this is a new install of NodeJS, and the user has opted to do a full DigiNode install, then proceed, If the user is doing a full install, and this is a new install, then proceed
if  [ "$NODEJS_INSTALL_TYPE" = "new" ] && [ "$NODEJS_DO_INSTALL" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    NODEJS_DO_INSTALL=YES
fi

if [ "$NODEJS_DO_INSTALL" = "YES" ]; then

    # Display section break
    printf "\\n"
    if [ $NODEJS_INSTALL_TYPE = "new" ]; then
        printf " =============== Installing: NodeJS ====================================\\n\\n"
        # ==============================================================================
    elif [ $NODEJS_INSTALL_TYPE = "majorupgrade" ] || [ $NODEJS_INSTALL_TYPE = "upgrade" ]; then
        printf " =============== Upgrading: NodeJS =====================================\\n\\n"
        # ==============================================================================
    elif [ $NODEJS_INSTALL_TYPE = "reset" ]; then
        printf " =============== Resetting: NodeJS =====================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose re-install NodeJS.\\n" "${INFO}"
    fi


    # Install NodeJS if it does not exist
    if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
        printf "%b Installing NodeJS v${NODEJS_VER_RELEASE} ...\\n" "${INFO}"
        sudo apt-get install nodejs -y -q
        printf "\\n"
    fi

    # If NodeJS 14 exists, upgrade it
    if [ "$NODEJS_INSTALL_TYPE" = "upgrade" ]; then
        printf "%b Updating to NodeJS v${NODEJS_VER_RELEASE} ...\\n" "${INFO}"
        sudo apt-get install nodejs -y -q
        printf "\\n"
    fi

    # If NodeJS exists, but needs a major upgrade, remove the old versions first as there can be conflicts
    if [ "$NODEJS_INSTALL_TYPE" = "majorupgrade" ]; then
        printf "%b Since this is a major upgrade, the old versions of NodeJS will be removed first, to ensure there are no conflicts.\\n" "${INFO}"
        printf "%b Purging old versions of NodeJS v${NODEJS_VER_LOCAL} ...\\n" "${INFO}"
        sudo apt-get purge nodejs-legacy nodejs -y -q
        sudo apt-get autoremove -y -q
        printf "\\n"
        printf "%b Installing NodeJS v${NODEJS_VER_RELEASE} ...\\n" "${INFO}"
        sudo apt-get install nodejs -y -q
        printf "\\n"
    fi

    # If we are in Reset Mode, remove and re-install
    if [ "$NODEJS_INSTALL_TYPE" = "reset" ]; then
        printf "%b Reset Mode is ENABLED. Removing NodeJS v${NODEJS_VER_RELEASE} ...\\n" "${INFO}"
        sudo apt-get purge nodejs-legacy nodejs -y -q
        sudo apt-get autoremove -y -q
        printf "\\n"
        printf "%b Re-installing NodeJS v${NODEJS_VER_RELEASE} ...\\n" "${INFO}"
        sudo apt-get install nodejs -y -q
        printf "\\n"
    fi

    # Get the new version number of the NodeJS install
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | cut -d' ' -f3)

    # Later versions use purely the 'node --version' command, (rather than nodejs)
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_VER_LOCAL=$(node --version 2>/dev/null | cut -d' ' -f3)
    fi

    # Update diginode.settings with new NodeJS local version number and the install/upgrade date
    sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=$NODEJS_VER_LOCAL|" $DGNT_SETTINGS_FILE
    if [ $NODEJS_INSTALL_TYPE = "install" ] || [ $NODEJS_INSTALL_TYPE = "reset" ]; then
        sed -i -e "/^NODEJS_INSTALL_DATE=/s|.*|NODEJS_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ $NODEJS_INSTALL_TYPE = "upgrade" || [ $NODEJS_INSTALL_TYPE = "majorupgrade" ]]; then
        sed -i -e "/^NODEJS_UPGRADE_DATE=/s|.*|NODEJS_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Reset NodeJS Install and Upgrade Variables
    NODEJS_INSTALL_TYPE=""
    NODEJS_UPDATE_AVAILABLE=NO
    NODEJS_POSTUPDATE_CLEANUP=YES

fi

printf "\\n"

}

# This function will check if DigiAsset Node is installed, and if it is, check if there is an update available

digiasset_node_check() {

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    printf " =============== Checking: DigiAsset Node ==============================\\n\\n"
    # ==============================================================================

    # Let's check if this is an Official DigiAsset Node is already installed. This file is created after a succesful previous installation with this installer.
    str="Is DigiAsset Node already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        DGA_STATUS="installed"
        printf "%b%b %s YES! [ DigiNode Install Detected. ] \\n" "${OVER}" "${TICK}" "${str}"
    else
        DGA_STATUS="not_detected"
    fi

    # Just to be sure, let's try another way to check if DigiAsset Node is installed by looking for the 'digiasset_node' api.js file
    if [ "$DGA_STATUS" = "not_detected" ]; then
        if [ -f "$DGA_INSTALL_LOCATION/lib/api.js" ]; then
            DGA_STATUS="installed"
            printf "%b%b %s YES! [ Located: ~/digiasset_node/lib/api.js ]\\n" "${OVER}" "${TICK}" "${str}"
        else
            DGA_STATUS="not_detected"
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi


    # If we know DigiAsset Node is installed, let's check if it is actually running
    # First we'll see if it is running using the command: node index.js
    if [ "$DGA_STATUS" = "installed" ]; then
        str="Is DigiAsset Node currently running?..."
        IS_DGANODE_RUNNING=$(sudo -u $USER_ACCOUNT pgrep -f "node index.js" 2>/dev/null)
        printf "%b %s" "${INFO}" "${str}"
        if [ "$IS_DGANODE_RUNNING" != "" ]; then
            DGA_STATUS="running"
            IS_DGANODE_RUNNING="YES"
            printf "%b%b %s YES! [ Using: node index.js ]\\n" "${OVER}" "${TICK}" "${str}"
        else
            # If that didn't work, check if it is running using PM2
            IS_PM2_RUNNING=$(pm2 pid index 2>/dev/null)
            if [ "$IS_PM2_RUNNING" = "" ]; then
                DGA_STATUS="stopped"
                IS_PM2_RUNNING="NO"
                printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
            elif [ "$IS_PM2_RUNNING" = "0" ]; then
                DGA_STATUS="stopped"
                IS_PM2_RUNNING="NO"
                printf "%b%b %s NO! [ PM2: index.js is stopped ]\\n" "${OVER}" "${CROSS}" "${str}"
            else
                DGA_STATUS="running"
                IS_PM2_RUNNING="YES"
                printf "%b%b %s YES! [ PM2: index.js is running ]\\n" "${OVER}" "${TICK}" "${str}"
            fi    
        fi
    fi


    # If an existing DigiAsset Node is installed, get the current major release number directly from the api.js file
    # The advantage of this method is that it will work even if DigiAsset Node is not running
    if test -f $DGA_INSTALL_LOCATION/lib/api.js; then
      DGA_VER_MJR_LOCAL_QUERY=$(cat $DGA_INSTALL_LOCATION/lib/api.js 2>/dev/null | grep "const apiVersion=" | cut -d'=' -f2 | cut -d';' -f1)

      # If we actually get a valid response, update DGA_VER_MJR_LOCAL variable with a new major version 
      if [ "$DGA_VER_MJR_LOCAL_QUERY" != "" ]; then
        DGA_VER_MJR_LOCAL=$DGA_VER_MJR_LOCAL_QUERY
        sed -i -e "/^DGA_VER_MJR_LOCAL=/s|.*|DGA_VER_MJR_LOCAL=$DGA_VER_MJR_LOCAL|" $DGNT_SETTINGS_FILE
      fi
    fi

    # Next let's try and get the minor version, which may or may not be available yet
    # If DigiAsset Node is running we can get it directly from the web server
    if [ "$DGA_STATUS" = "running" ]; then
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
    fi

    # IF it's not running, we can look in the main.json file. This may not be current but it's better than nothing.
    # We are only going to use this method though if DigiAsset Node is definitely installed.
    if [ "$DGA_STATUS" = "stopped" ]; then

        # Check main.json file, if it exists
        if test -f $DGA_SETTINGS_FILE; then
            DGA_VER_MNR_LOCAL_QUERY=$(cat $DGA_SETTINGS_FILE | jq .templateVersion | sed 's/"//g')
        fi

        # If the result is 'null', set it to actually null
        if [ "$DGA_VER_MNR_LOCAL_QUERY" = "null" ]; then
            DGA_VER_MNR_LOCAL_QUERY="NA"
        fi

        # This is a beta so the minor version doesn't exist
        if [ "$DGA_VER_MNR_LOCAL_QUERY" = "NA" ]; then
            DGA_VER_MNR_LOCAL="beta"
            str="Current Version:"
            printf "%b %s" "${INFO}" "${str}"
            sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=$DGA_VER_MNR_LOCAL|" $DGNT_SETTINGS_FILE
            printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL} beta\\n" "${OVER}" "${INFO}" "${str}"
        # If we actually get a version number then we can use it
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
    fi


    # Now we can update the main DGA_VER_LOCAL variable with the current version (major or minor depending on what was found)
    if [ "$DGA_VER_MNR_LOCAL" = "beta" ]; then
        DGA_VER_LOCAL="$DGA_VER_MAJ_LOCAL beta"  # e.g. DigiAsset Node v3 beta
    elif [ "$DGA_VER_MNR_LOCAL" = "" ]; then
        DGA_VER_LOCAL="$DGA_VER_MAJ_LOCAL"       # e.g. DigiAsset Node v3
    elif [ "$DGA_VER_MNR_LOCAL" != "" ]; then
        DGA_VER_LOCAL="$DGA_VER_MNR_LOCAL"       # e.g. DigiAsset Node v3.2
    fi
    sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=$DGA_VER_LOCAL|" $DGNT_SETTINGS_FILE


    # Next we need to check for the latest release at the DigiAssetX website
    str="Checking DigiAssetX website for the latest release..."
    printf "%b %s" "${INFO}" "${str}"
    DGA_VER_RELEASE_QUERY=$(curl -sfL https://versions.digiassetx.com/digiasset_node/versions.json 2>/dev/null | jq last | sed 's/"//g')

    # If we can't get Github version number
    if [ "$DGA_VER_RELEASE_QUERY" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of DigiAsset Node. Is the Internet down?\\n" "${CROSS}"
        printf "\\n"
        printf "%b DigiAsset Node cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"
        DGA_DO_INSTALL=NO
        DGA_INSTALL_TYPE="none"
        DGA_UPDATE_AVAILABLE=NO
        printf "\\n"
        return     
    else
        DGA_VER_RELEASE=$DGA_VER_RELEASE_QUERY
        printf "%b%b %s Found: DigiAsset Node v${DGA_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^DGA_VER_RELEASE=/s|.*|DGA_VER_RELEASE=$DGA_VER_RELEASE|" $DGNT_SETTINGS_FILE
        DGA_VER_MJR_RELEASE=$(echo $DGA_VER_RELEASE | cut -d'.' -f1)
        sed -i -e "/^DGA_VER_MJR_RELEASE=/s|.*|DGA_VER_MJR_RELEASE=$DGA_VER_MJR_RELEASE|" $DGNT_SETTINGS_FILE
    fi


    # If a local version already exists (i.e. we have a local version number) check if a DigiAsset Node upgrade is required
    # This will compare the major version numbers of the local with the remote
    if [ "$DGA_VER_MJR_LOCAL" != "" ]; then
      # ....then 
      if [ $(version $DGA_VER_MJR_LOCAL) -ge $(version $DGA_VER_MJR_RELEASE) ]; then
          printf "%b DigiAsset Node is already up to date.\\n" "${INFO}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to re-install DigiAsset Node v${DGA_VER_RELEASE}.\\n" "${INFO}"
            DGA_INSTALL_TYPE="askreset"
            DGA_DO_INSTALL=YES
          else
            printf "%b Upgrade not required.\\n" "${INFO}"
            DGA_DO_INSTALL=NO
            DGA_INSTALL_TYPE="none"
            DGA_UPDATE_AVAILABLE=NO
            printf "\\n"
            return
          fi
      else
          if [ $DGA_DEV_MODE = true ]; then 
            printf "%b %bDigiAsset Node can be upgraded from v${DGA_VER_LOCAL} to v${DGA_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        else
            printf "%b %bDigiAsset Node can be upgraded from v${DGA_VER_LOCAL} to the latest development version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        fi
          DGA_INSTALL_TYPE="upgrade"
          DGA_ASK_UPGRADE=YES
      fi
    fi 

    # If no current version is installed, then do a clean install
    if [ $DGA_STATUS = "not_detected" ]; then
        if [ $DGA_DEV_MODE = true ]; then 
            printf "%b %bDigiAsset Node develop branch will be installed.%b\\n" "${INFO}"
        else
            printf "%b %bDigiAsset Node v${DGA_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        fi
        DGA_INSTALL_TYPE="new"
        DGA_DO_INSTALL="if_doing_full_install"
    fi

    printf "\\n"

fi

}

# This function will install DigiAsset Node if it not yet installed, and if it is, upgrade it to the latest release
digiasset_node_do_install() {

# If we are in unattended mode and there is an upgrade to do, then go ahead and do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$DGA_ASK_UPGRADE" = "YES" ]; then
    DGA_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall DigiByte Core
if [ "$DGA_INSTALL_TYPE" = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install DigiAsset Node v${DGA_VER_RELEASE}?\\n\\nNote: This will delete your current DigiAsset Node folder at $DGA_INSTALL_LOCATION and re-install it. Your DigiAsset settings folder at ~/.digibyte/assetnode_settings will not be affected." "${r}" "${c}"; then
        DGA_DO_INSTALL=YES
        DGA_INSTALL_TYPE="reset"
    else
        printf " =============== Resetting: DigiAsset Node =============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You skipped re-installing DigiAsset Node.\\n" "${INFO}"
        printf "\\n"
        DGA_DO_INSTALL=NO
        DGA_INSTALL_TYPE="none"
        DGA_UPDATE_AVAILABLE=NO
        return
    fi

fi

# If this is a new install of DigiAsset Node, and the user has opted to do a full DigiNode install, then proceed
if  [ "$DGA_INSTALL_TYPE" = "new" ] && [ "$DGA_DO_INSTALL" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    DGA_DO_INSTALL=YES
fi


if [ "$DGA_DO_INSTALL" = "YES" ]; then

    # Display section break
    printf "\\n"
    if [ $DGA_INSTALL_TYPE = "new" ]; then
        printf " =============== Installing: DigiAsset Node ============================\\n\\n"
        # ==============================================================================
    elif [ $DGA_INSTALL_TYPE = "upgrade" ]; then
        printf " =============== Upgrading: DigiAsset Node =============================\\n\\n"
        # ==============================================================================
    elif [ $DGA_INSTALL_TYPE = "reset" ]; then
        printf " =============== Resetting: DigiAsset Node =============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-install DigiAsset Node.\\n" "${INFO}"
    fi

    # If we are in Reset Mode and PM2 is running let's stop it
    if [ "$DGA_STATUS" = "running" ] && [ "$IS_PM2_RUNNING" = "YES" ] && [ "$DGA_INSTALL_TYPE" = "reset" ]; then
       printf "%b Reset Mode: Stopping PM2 digiasset service...\\n" "${INFO}"
       pm2 stop index
       DGA_STATUS="stopped"
    fi

    if [ $DGA_INSTALL_TYPE = "reset" ]; then

        str="Reset Mode: Delete DigiAsset Node pm2 instance..."
        printf "%b %s" "${INFO}" "${str}"
        pm2 delete digiasset
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"


        # Delete existing 'digiasset_node' folder (if it exists)
        str="Reset Mode: Deleting current '~/digiasset_node' folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r -f $USER_HOME/digiasset_node
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Install the latest version of NPM
    printf "%b Install latest version of npm...\\n" "${INFO}"
    npm install --quiet npm@latest -g

    # Install the latest version of PM2
    printf "%b Install latest version of PM2...\\n" "${INFO}"
    npm install --quiet pm2@latest -g

    # Cloning DigiAsset Node from Github (will use dev branch set in header if the --dga-dav flaf was include)
    if [ $DGA_DEV_MODE = true ]; then 
        str="Cloning DigiAsset Node develop branch from Github repository..."
    else
        str="Cloning DigiAsset Node v${DGA_VER_RELEASE} from Github repository..."
    fi
    printf "%b %s" "${INFO}" "${str}"
    cd $USER_HOME
    sudo -u $USER_ACCOUNT git clone -q $DGA_GITHUB_REPO
    printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"


    # Start DigiAsset Node, and tell it to save the current setup. This will ensure it runs the digiasset node automatically when PM2 starts.
    cd $DGA_INSTALL_LOCATION
    sudo -u $USER_ACCOUNT pm2 start index.js --name digiasset -- --log
    sudo -u $USER_ACCOUNT pm2 save -force


    # Update diginode.settings with new DigiAsset Node version number and the install/upgrade date
    DGA_VER_LOCAL=$DGA_VER_RELEASE
    sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=$DGA_VER_LOCAL|" $DGNT_SETTINGS_FILE
    if [ $DGA_INSTALL_TYPE = "install" ] || [ $DGA_INSTALL_TYPE = "reset" ]; then
        sed -i -e "/^DGA_INSTALL_DATE=/s|.*|DGA_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ $DGA_INSTALL_TYPE = "upgrade" ]; then
        sed -i -e "/^DGA_UPGRADE_DATE=/s|.*|DGA_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Reset DGA Install and Upgrade Variables
    DGA_INSTALL_TYPE=""
    DGA_UPDATE_AVAILABLE=NO
    DGA_POSTUPDATE_CLEANUP=YES

    # Create DigiAsset Node PM2

    # Create hidden file in the 'digiasset_node' folder to denote this version was installed with the official installer
    if [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        sudo -u $USER_ACCOUNT touch $DGA_INSTALL_LOCATION/.officialdiginode
    fi

    printf "\\n"

fi

}


# Create pm2 service so that DigiAsset Node will run at boot
digiasset_node_pm2_create_service() {

# If you want to make changes to how PM2 services are created/managed, refer to this website:
# https://www.tecmint.com/enable-pm2-to-auto-start-node-js-app/

# If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
if [ "$RESET_MODE" = true ]; then

    # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
    if [ -f "$PM2_UPSTART_SERVICE_FILE" ] || [ -f "$PM2_SYSTEMD_SERVICE_FILE" ]; then

        if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-configure the DigiAsset Node PM2 service?\\n\\nThe PM2 service ensures that your DigiAsset Node starts automatically at boot, and stays running 24/7. This will delete your existing PM2 service file and recreate it." "${r}" "${c}"; then
            PM2_DO_INSTALL=YES
            PM2_INSTALL_TYPE="reset"
        else
            printf " =============== Resetting: NodeJS PM2 Service =========================\\n\\n"
            # ==============================================================================
            printf "%b Reset Mode: You skipped re-configuring the DigiAsset Node PM2 service.\\n" "${INFO}"
            PM2_DO_INSTALL=NO
            PM2_INSTALL_TYPE="none"
            return
        fi
    fi
fi

# If the SYSTEMD service files do not yet exist, then assume this is a new install
if [ ! -f "$PM2_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
            PM2_DO_INSTALL="if_doing_full_install"
            PM2_INSTALL_TYPE="new"
fi

# If the UPSTART service files do not yet exist, then assume this is a new install
if [ ! -f "$PM2_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
            PM2_DO_INSTALL="if_doing_full_install"
            PM2_INSTALL_TYPE="new"
fi

# If this is a new install of NodeJS PM2 service file, and the user has opted to do a full DigiNode install, then proceed
if  [ "$PM2_INSTALL_TYPE" = "new" ] && [ "$PM2_DO_INSTALL" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    PM2_DO_INSTALL=YES
fi


if [ "$PM2_DO_INSTALL" = "YES" ]; then

    # Display section break
    printf "\\n"
    if [ "$PM2_INSTALL_TYPE" = "new" ]; then
        printf " =============== Installing: NodeJS PM2 Service ========================\\n\\n"
        # ==============================================================================
    elif [ "$PM2_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Resetting: NodeJS PM2 Service =========================\\n\\n"
        printf "%b Reset Mode: You chose re-configure the DigiAsset Node PM2 service.\\n" "${INFO}"
        # ==============================================================================
    fi

    # If SYSTEMD service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
    if [ -f "$PM2_SYSTEMD_SERVICE_FILE" ] && [ "$PM2_INSTALL_TYPE" = "reset" ]; then

        # Stop the service now
        sudo systemctl stop pm2-root

        # Disable the service now
        sudo systemctl disable pm2-root

        str="Deleting PM2 systemd service file: $PM2_SYSTEMD_SERVICE_FILE ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $PM2_SYSTEMD_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If UPSTART service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
    if [ -f "$PM2_UPSTART_SERVICE_FILE" ] && [ "$PM2_INSTALL_TYPE" = "reset" ]; then

        # Stop the service now
        sudo service pm2-root stop

        # Disable the service now
        sudo service pm2-root disable

        str="Deleting PM2 upstart service file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $PM2_UPSTART_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If this system uses SYSTEMD and the service file does not yet exist, then set it it up
    if [ ! -f "$PM2_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then

        # Generate the PM2 service file
        pm2 startup

        # Restart the PM2 service
        restart_service pm2-root

    fi

    # If this system uses UPSTART and the service file does not yet exist, then set it it up
    if [ ! -f "$PM2_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then

        # Generate the PM2 service file
        pm2 startup

        # Restart the PM2 service
        restart_service pm2-root
    fi

    # If using sysv-init or another unknown system, we don't yet support creating a PM2 service file
    if [ "$INIT_SYSTEM" = "sysv-init" ] || [ "$INIT_SYSTEM" = "unknown" ]; then
        printf "%b Unable to create a PM2 service for your system - systemd/upstart not found.\\n" "${CROSS}"
        printf "%b Please contact @digibytehelp on Twitter for help.\\n" "${CROSS}"
        exit 1
    fi

fi



}


# This function will ask the user if they want to install the system upgrades that have been found
menu_ask_install_updates() {

# If there is an upgrade available for DigiByte Core, IPFS, NodeJS, DigiAsset Node or DigiNode Tools, ask the user if they wan to install them
if [[ "$DGB_ASK_UPGRADE" = "YES" ]] || [[ "$DGA_ASK_UPGRADE" = "YES" ]] || [[ "$IPFS_ASK_UPGRADE" = "YES" ]] || [[ "$NODEJS_ASK_UPGRADE" = "YES" ]] || [[ "$DGNT_ASK_UPGRADE" = "YES" ]]; then

    # Don't ask if we are running unattended
    if [ ! "$UNATTENDED_MODE" == true ]; then

        if [ "$DGB_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dgb="- DigiByte Core v$DGB_VER_RELEASE\\n"
        fi
        if [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_ipfs="- Go-IPFS v$IPFS_VER_RELEASE\\n"
        fi
        if [ "$NODEJS_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_nodejs="- NodeJS LTS v$NODEJS_VER_RELEASE\\n"
        fi
        if [ "$DGA_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dga="- DigiAsset Node v$DGA_VER_RELEASE\\n"
        fi
        if [ "$DGNT_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dgn="- DigiNode Tools v$DGNT_VER_RELEASE\\n"
        fi


        if whiptail --backtitle "" --title "DigiNode software updates are available" --yesno "There are updates available for your DigiNode:\\n $upgrade_msg_dgb $upgrade_msg_ipfs $upgrade_msg_nodejs $upgrade_msg_dga $upgrade_msg_dgn\\n\\nWould you like to install them now?" --yes-button "Yes (Recommended)" "${r}" "${c}"; then
            printf "%b You chose to install the available updates:\\n$upgrade_msg_dgb $upgrade_msg_ipfs $upgrade_msg_nodejs $upgrade_msg_dga $upgrade_msg_dgn\\n" "${INFO}"
            printf "\\n"
        #Nothing to do, continue
          echo
          if [ $DGB_ASK_UPGRADE = "YES" ]; then
            DGB_DO_INSTALL=YES
          fi
          if [ $IPFS_ASK_UPGRADE = "YES" ]; then
            IPFS_DO_INSTALL=YES
          fi
          if [ $NODEJS_ASK_UPGRADE = "YES" ]; then
            NODEJS_DO_INSTALL=YES
          fi
          if [ $DGA_ASK_UPGRADE = "YES" ]; then
            DGA_DO_INSTALL=YES
          fi
          if [ $DGNT_ASK_UPGRADE = "YES" ]; then
            DGNT_DO_INSTALL=YES
          fi
        else
          printf "%b You chose NOT to install the available updates:\\n$upgrade_msg_dgb $upgrade_msg_ipfs $upgrade_msg_nodejs $upgrade_msg_dga $upgrade_msg_dgn\\n" "${INFO}"
          printf "\\n"
          exit
        fi

    fi

fi

}

# This function will ask the user if they want to install DigiAssets Node
menu_ask_install_digiasset_node() {

# Provided we are not in unnatteneded mode, and it is not already installed, ask the user if they want to install a DigiAssets Node
if [ ! -f $DGA_INSTALL_LOCATION/.officialdiginode ] && [ "$UNATTENDED_MODE" == false ]; then

        if whiptail --backtitle "" --title "Install DigiAsset Node?" --yesno "You do not currently have the DigiAsset Node installed. Running the DigiAsset Node helps to support the network by decentralizing the DigiAsset metadata. It also gives you the ability to create your own DigiAssets and lets you earn DGB for hosting other people's metadata.\\n\\n\\nWould you like to install the DigiAsset Node now?" --yes-button "Yes (Recommended)" "${r}" "${c}"; then
        #Nothing to do, continue
          DO_FULL_INSTALL=YES
            printf "%b You choose to install the DigiAsset Node.\\n" "${INFO}"
            printf "\\n"
        else
          DO_FULL_INSTALL=NO
          printf "%b You choose NOT to install the DigiAsset Node.\\n" "${INFO}"
          printf "\\n"
        fi

fi

}

# Create DigiAssets main.json settings file (if it does not already exist), and if it does, updates it with the latest RPC credentials from digibyte.conf
digiasset_node_create_settings() {

    local str

    # If we are in reset mode, ask the user if they want to recreate the entire DigiAssets settings folder if it already exists
    if [ "$RESET_MODE" = true ] && [ -f "$DGA_SETTINGS_FILE" ]; then

        if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to reset your DigiAsset Node settings?\\n\\nThis will delete your current DigiAsset Node settings located in ~/.digibyte/assetnode_config/ and then recreate them with the default settings." "${r}" "${c}"; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="reset"
        else
            printf " =============== Resetting: DigiAsset Node settings ====================\\n\\n"
            # ==============================================================================
            printf "%b Reset Mode: You skipped re-configuring the DigiAsset Node settings folder.\\n" "${INFO}"
            DGA_SETTINGS_CREATE=NO
            DGA_SETTINGS_CREATE_TYPE="none"
            return
        fi
    fi

    # If DigiAsset Node settings do not yet exist, then assume this is a new install
    if [ ! -f "$DGA_SETTINGS_FILE" ]; then
                DGA_SETTINGS_CREATE="if_doing_full_install"
                DGA_SETTINGS_CREATE_TYPE="new"
    fi

    # If this is the first time creating the DigiAsset Node settings file, and the user has opted to do a full DigiNode install, then proceed
    if  [ "$DGA_SETTINGS_CREATE_TYPE" = "new" ] && [ "$DGA_SETTINGS_CREATE" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        DGA_SETTINGS_CREATE=YES
    fi

    # Let's get the latest RPC credentials from digibyte.conf if it exists
    if [ -f $DGB_CONF_FILE ]; then
        source $DGB_CONF_FILE
    fi


    # If main.json file already exists, and we are not doing a reset, let's check if the rpc user and password need updating
    if [ -f $DGA_SETTINGS_FILE ] && [ ! $DGA_SETTINGS_CREATE_TYPE = "reset" ]; then

        local rpcuser_json_cur
        local rpcpass_json_cur
        local rpcpass_json_cur

        # Let's get the current rpcuser and rpcpassword from the main.json file

        rpcuser_json_cur=$(cat $DGA_SETTINGS_FILE | jq '.wallet.user' | tr -d '"')
        rpcpass_json_cur=$(cat $DGA_SETTINGS_FILE | jq '.wallet.pass' | tr -d '"')
        rpcport_json_cur=$(cat $DGA_SETTINGS_FILE | jq '.wallet.port' | tr -d '"')

        # Compare them with the digibyte.conf values to see if they need updating

        if [ "$rpcuser" != "$rpcuser_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update"
        elif [ "$rpcpass" != "$rpcpass_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update"
        elif [ "$rpcport" != "$rpcport_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update"
        fi
    fi


    if [ "$DGA_SETTINGS_CREATE" = "YES" ]; then

         # Display section break
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "new" ]; then
            printf " =============== Creating: DigiAsset Node settings ===================\\n\\n"
            # ==============================================================================
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ]; then
            printf " =============== Updating: DigiAsset Node settings ====================\\n\\n"
            printf "%b RPC credentials in digibyte.conf have changed. The main.json file will be updated.\\n" "${INFO}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "reset" ]; then
            printf " =============== Resetting: DigiAsset Node settings ====================\\n\\n"
            printf "%b Reset Mode: You chose to re-configure your DigiAsset Node settings.\\n" "${INFO}"
            # ==============================================================================
        fi

        # If we are in reset mode, delete the entire DigiAssets settings folder if it already exists
        if [ $DGA_SETTINGS_CREATE_TYPE = "reset" ] && [ -d "$DGA_SETTINGS_LOCATION" ]; then
            str="Deleting existing DigiAssets settings..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f -r $DGA_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If main.json file already exists, update the rpc user and password if they have changed
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ]; then

            str="Updating RPC credentials in main.json..."
            printf "%b %s" "${INFO}" "${str}"

            tmpfile=($mktemp)

            cp $DGA_SETTINGS_FILE "$tmpfile" &&
            jq --arg user "$rpcuser" --arg pass "$rpcpass" --arg port "$rpcport" '.wallet.user |= $user | .wallet.pass |= $pass | .wallet.port |= $port'
              "$tmpfile" >$DGA_SETTINGS_FILE &&
            mv "$tmpfile" $DGA_SETTINGS_FILE &&
            rm -f "$tmpfile"

            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        fi

        # create .digibyte settings folder if it does not already exist
        if [ ! -d $DGB_SETTINGS_LOCATION ]; then
            str="Creating ~/.digibyte/ folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $DGB_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # create assetnode_config folder if it does not already exist
        if [ ! -d $DGA_SETTINGS_LOCATION ]; then
            str="Creating ~/.digibyte/assetnode_config/ folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $DGA_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [ ! -f $DGA_SETTINGS_FILE ]; then
            # Create a new main.json settings file
            str="Creating ~/.digibyte/assetnode_config/main.json settings file..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT touch $DGA_SETTINGS_FILE
            cat <<EOF > $DGA_SETTINGS_FILE
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
      "user":         "$rpcuser",
      "pass":         "$rpcpassword",
      "host":         "127.0.0.1",
      "port":         $rpcport
    }
}
EOF
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        printf "\\n"

    fi
}


# Perform uninstall if requested
uninstall_do_now() {

    printf " =============== UNINSTALLING DIGINODE =================================\\n\\n"
    # ==============================================================================

    printf "%b DigiNode will now be uninstalled from your system. Your DigiByte wallet file will not be harmed.\\n" "${INFO}"
    printf "\\n"


    ################## UNINSTALL DIGIASSET NODE ##########################################


    # Display the uninstall DigiNode title if it needs to be uninstalled
    if [ -f "$DGA_SETTINGS_FILE" ] || [ -d "$DGA_INSTALL_LOCATION" ]; then

        printf " =============== Uninstall: DigiAsset Node =============================\\n\\n"
        # ==============================================================================
        local uninstall_dga=yes
    fi

    # Ask to delete DigiAsset Node if it exists
    if [ -d "$DGA_INSTALL_LOCATION" ]; then

        # Do you want to uninstall your DigiAsset Node?
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to uninstall DigiAsset Node v${DGA_VER_LOCAL}?" "${r}" "${c}"; then

            # Delete existing 'digiasset_node' folder (if it exists)
            str="Uninstalling DigiAsset Node software..."
            printf "%b %s" "${INFO}" "${str}"
            pm2 delete digiasset
            rm -r -f $USER_HOME/digiasset_node
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b You chose not to uninstall DigiAsset Node v${DGA_VER_LOCAL}.\\n" "${INFO}"
        fi
    fi

    # Ask to delete DigiAsset Node settings (main.json) if it exists
    if [ -f "$DGA_SETTINGS_FILE" ]; then

        # Do you want to delete digibyte.conf?
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to delete your DigiAsset Node settings folder: ~/.digibyte/asset_settings ?" "${r}" "${c}"; then

            # Delete asset_settings folder
            str="Deleting DigiAssets settings folder: asset_settings.."
            printf "%b %s" "${INFO}" "${str}"
            rm -f -r $DGA_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b You chose not to delete your DigiAsset settings folder.\\n" "${INFO}"
        fi
    fi

    # Insert a line break if either of these were present
    if [ "$uninstall_dga" = "yes" ]; then
        printf "\\n"
    fi


    ################## UNINSTALL IPFS #################################################

    # Get the local version number of Go-IPFS (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=$IPFS_VER_LOCAL|" $DGNT_SETTINGS_FILE
    fi

    # Next let's check if IPFS daemon is running
    if [ "$IPFS_STATUS" = "installed" ]; then
      if check_service_active "ipfs"; then
          IPFS_STATUS="running"
      else
          IPFS_STATUS="stopped"
      fi
    fi

    # Ask to uninstall GoIPFS
    if [ -f /usr/local/bin/ipfs-update ] || [ -f /usr/local/bin/ipfs ]; then

    printf " =============== Uninstall: Go-IPFS ====================================\\n\\n"
    # ==============================================================================

        # Delete IPFS
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to uninstall GoIPFS v${IPFS_VER_LOCAL}?\\n\\nThis will uninstalled both the IPFS Updater utility and GoIPFS." "${r}" "${c}"; then

            printf "%b You chose to uninstall Go-IPFS v${IPFS_VER_LOCAL}.\\n" "${INFO}"

            # Stop IPFS service if it is running, as we need to upgrade or reset it
            if [ "$IPFS_STATUS" = "running" ]; then
               printf "%b Preparing Uninstall: Stopping IPFS service ...\\n" "${INFO}"
               stop_service digibyted
               IPFS_STATUS="stopped"
            fi

            # Delete the SYSTEMD service file if it exists
            if [ -f "$IPFS_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
                str="Deleting IPFS systemd service file..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $IPFS_SYSTEMD_SERVICE_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete the UPSTART service file if it exists
            if [ -f "$IPFS_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
                str="Deleting IPFS upstart service file..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $IPFS_UPSTART_SERVICE_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete IPFS Updater binary
            if [ -f /usr/local/bin/ipfs-update ]; then
                str="Deleting current IPFS Updater binary: /usr/local/bin/ipfs-update..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f /usr/local/bin/ipfs-update
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete IPFS Updater installer
            if [ -d $USER_HOME/ipfs-update ]; then
                str="Deleting current IPFS Updater installer: ~/ipfs-update..."
                printf "%b %s" "${INFO}" "${str}"
                rm -r $USER_HOME/ipfs-update
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Remove IPFS updater from PATH
            str="Deleting ipfs-update entry from PATH..."
            printf "%b %s..." "${INFO}" "${str}"
            sudo sed -i.bak '/swap/d' /etc/fstab
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Delete Go-IPFS binary
            if [ -f /usr/local/bin/ipfs ]; then
                str="Deleting current Go-IPFS binary..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f /usr/local/bin/ipfs
                IPFS_STATUS="not_detected"
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

        else
            printf "%b You chose not to uninstall IPFS.\\n" "${INFO}"
        fi

        # Delete IPFS settings
        if [ -d "$USER_HOME/.ipfs" ]; then
            if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to delete your IPFS settings folder?\\n\\nThis will delete the folder: ~/.ipfs" "${r}" "${c}"; then
                str="Deleting ~/.ipfs settings folder..."
                printf "%b %s" "${INFO}" "${str}"
                rm -r $USER_HOME/.ipfs
                printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b You chose not to delete the IPFS settings folder (~/.ipfs).\\n" "${INFO}"
            fi
        fi
        printf "\\n"
    fi

    ################## UNINSTALL DIGIBYTE CORE #################################################

    printf " =============== Uninstall: DigiByte Node ==============================\\n\\n"
    # ==============================================================================


    # Uninstall DigiByte Core
    if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to uninstall DigiByte Core v${DGB_VER_LOCAL}?\\n\\nYour wallet, settings and blockchain data will not be affected." "${r}" "${c}"; then

        printf "%b You chose to uninstall DigiByte Core.\\n" "${INFO}"

        printf "%b Stopping DigiByte Core daemon...\\n" "${INFO}"
        sudo service digibyted stop
        sudo service digibyted disable
        DGB_STATUS="stopped"

        # Delete systemd service file
        if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ]; then
            str="Deleting DigiByte daemon systemd service file: $DGB_SYSTEMD_SERVICE_FILE ..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $DGB_SYSTEMD_SERVICE_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Delte upstart service file
        if [ -f "$DGB_UPSTART_SERVICE_FILE" ]; then
            str="Deleting DigiByte daemon upstart service file..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $DGB_UPSTART_SERVICE_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

       # Delete old DigiByte Core tar files, if present
        if compgen -G "$USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz" > /dev/null; then
            str="Deleting old DigiByte Core tar.gz files from home folder..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Delete DigiByte Core folder
        if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}" ]; then
            str="Deleting DigiByte Core v${DGB_VER_LOCAL}"
            printf "%b %s" "${INFO}" "${str}"
            rm -rf $USER_HOME/digibyte-${DGB_VER_LOCAL}
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Delete ~/digibyte symbolic link
        if [ -h "$USER_HOME/digibyte" ]; then
            str="Deleting digibyte symbolic link in home folder..."
            printf "%b %s" "${INFO}" "${str}"
            rm $USER_HOME/digibyte
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

    else
        printf "%b You chose not to uninstall DigiByte Core.\\n" "${INFO}"
    fi


    # Ask to delete digibyte.conf if it exists
    if [ -f "$DGB_CONF_FILE" ]; then

        # Do you want to delete digibyte.conf?
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to delete your digibyte.conf settings file?\\n\\nThis will remove any customisations you made to your DigiByte install." "${r}" "${c}"; then

            # Delete digibyte.conf
            str="Deleting digibyte.conf file..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $DGB_CONF_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b You chose not to delete your digibyte.conf settings file.\\n" "${INFO}"
        fi
    fi

    # Delete DigiByte blockchain data
    if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to delete the DigiByte blockchain data?\\n\\nIf you re-install DigiByte Core, it will need to re-download the entire blockchain which can take several days.\\n\\nNote: Your wallet will be unaffected." "${r}" "${c}"; then

        # Delete systemd service file
        if [ -d "$DGB_DATA_LOCATION" ]; then
            str="Deleting DigiByte Core blockchain data..."
            printf "%b %s" "${INFO}" "${str}"
            rm -rf $DGB_DATA_LOCATION/indexes
            rm -rf $DGB_DATA_LOCATION/chainstate
            rm -rf $DGB_DATA_LOCATION/blocks
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
        printf "\\n"

    else
        printf "%b You chose not to delete the existing DigiByte blockchain data.\\n" "${INFO}"
        printf "\\n"
    fi

    ################## UNINSTALL DIGINODE TOOLS #################################################

    # Show DigiNode Tools uninstall title if it exists
    if [ -d "$DGNT_LOCATION" ] || [ -f "$DGNT_SETTINGS_FILE" ]; then

        printf " =============== Uninstall: DigiNode Tools =============================\\n\\n"
        # ==============================================================================

    fi

    # Ask to uninstall DigiNode Tools if the install folder exists
    if [ -d "$DGNT_LOCATION" ]; then

        # Delete DigiNode Tools
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to uninstall DigiNode Tools?\\n\\nThis will delete the 'DigiNode Status Monitor' and 'DigiNode Installer'." "${r}" "${c}"; then

            printf "%b You chose to uninstall DigiNode Tools.\\n" "${INFO}"

            # Delete ~/diginode folder and its contents
            if [ -d "$DGNT_LOCATION" ]; then
                str="Deleting DigiNode Tools..."
                printf "%b %s" "${INFO}" "${str}"
                rm -rf $DGNT_LOCATION
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete 'diginode-installer' alias
            if grep -q "alias diginode-installer=" "$USER_HOME/.bashrc"; then
                str="Deleting 'diginode-installer' alias in .bashrc file..."
                printf "%b %s" "${INFO}" "${str}"
                # Delete existing alias for 'diginode'
                sed -i "/# Alias for DigiNode tools so that entering 'diginode-installer' will run this from any folder/d" $USER_HOME/.bashrc
                sed -i '/alias diginode-installer=/d' $USER_HOME/.bashrc
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete 'diginode' alias
            if grep -q "alias diginode=" "$USER_HOME/.bashrc"; then
                str="Deleting 'diginode' alias in .bashrc file..."
                printf "%b %s" "${INFO}" "${str}"
                # Delete existing alias for 'diginode'
                sed -i "/# Alias for DigiNode tools so that entering 'diginode' will run this from any folder/d" $USER_HOME/.bashrc
                sed -i '/alias diginode=/d' $USER_HOME/.bashrc
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi
        else
            printf "%b You chose not to uninstall DigiNode Tools.\\n" "${INFO}"
        fi
    fi

    # Ask to delete diginode.settings if it exists
    if [ -f "$DGNT_SETTINGS_FILE" ]; then

        # Delete diginode.settings
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to delete your diginode.settings file?\\n\\nThis wil remove any customisations you have made to your DigiNode Install." "${r}" "${c}"; then

            printf "%b You chose to delete your diginode.settings file.\\n" "${INFO}"

            # Delete systemd service file
            if [ -f "$DGNT_SETTINGS_FILE" ]; then
                str="Deleting diginode.settings file..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $DGNT_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

        else
            printf "%b You chose not to delete your diginode.settings file.\\n" "${INFO}"
        fi
        printf "\\n"
    else
        # Insert a line break because this is the end of the Uninstall DigiNode Tools section    
        printf "\\n"
    fi

    printf "\\n"

    printf " =======================================================================\\n"
    printf " ================== ${txtgrn}DigiNode Uninstall Completed!${txtrst} ================\\n"
    printf " =======================================================================\\n\\n"
    # ==============================================================================

    printf "\\n"
    donation_qrcode
    printf "\\n"
    printf "%b %bIt is recommended that you restart your system having performed an uninstall.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b To restart now enter: sudo reboot\\n" "${INDENT}"
    printf "\\n"
    exit

}

# Simple function to find an installed text editor
set_text_editor() {

# Set default system text editor
if is_command nano ; then
    TEXTEDITOR=nano
elif is_command vim ; then
    TEXTEDITOR=vim
elif is_command vi ; then
    TEXTEDITOR=vi
fi

if [ $VERBOSE_MODE = true ]; then
    printf "%b Text Editor: $TEXTEDITOR\\n" "${INFO}"
fi

}

# This will launch the Status Monitor again after installing updates
launch_status_monitor() {

    if [ "$STATUS_MONITOR" = true ]; then
        printf "\\n"
        printf "%b DigiNode Status Monitor will launch in 10 seconds...\\n" "${INFO}"
        sleep 10
        exec diginode
    fi
}


#####################################################################################################
### FUNCTIONS - MAIN - THIS IS WHERE THE HEAVY LIFTING HAPPENS
#####################################################################################################


main() {

    ######## FIRST CHECK ########
    # Must be root to install
    local str="Root user check"
    printf "\\n"

    # If the user's id is zero,
    if [[ "${EUID}" -eq 0 ]]; then
        # they are root and all is good
        printf "%b %s\\n\\n" "${TICK}" "${str}"

        # set the DigiNode Tools branch to use for the installer
        set_dgnt_branch

        # Display a message if Verbose Mode is enabled
        is_verbose_mode

        # Display a message if Unattended Mode is enabled
        is_unattended_mode

        # Display a message if Reset Mode is enabled. Quit if Reset and Unattended Modes are enable together.
        is_reset_mode 

        # Display a message if DigiAsset Node developer mode is enabled
        is_dgadev_mode

        # Show the DigiNode logo
        diginode_logo_v3
        make_temporary_log

    else
        # show installer title box
        installer_title_box

        # set the DigiNode Tools branch to use for the installer
        set_dgnt_branch

        # Otherwise, they do not have enough privileges, so let the user know
        printf "%b %s\\n" "${INFO}" "${str}"
        printf "%b %bScript called with non-root privileges%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b DigiNode Installer requires elevated privileges to get started.\\n" "${INDENT}"
        printf "%b Please review the source code on GitHub for any concerns regarding this requirement\\n" "${INDENT}"
        printf "%b Make sure to download this script from a trusted source\\n\\n" "${INDENT}"
        printf "%b Sudo utility check" "${INFO}"

        # If the sudo command exists, try rerunning as admin
        if is_command sudo ; then
            printf "%b%b Sudo utility check\\n" "${OVER}" "${TICK}"

            # when run via curl piping
            if [[ "$0" == "bash" ]]; then
                # Only append this to the curl command this if there are arguments to include
                if [ ! $# -eq 0 ]; then
                    local add_args="-s --"
                fi

                printf "%b Re-running DigiNode Installer URL as root...\\n" "${INFO}"

                # Download the install script and run it with admin rights
                exec curl -sSL $DGNT_INSTALLER_URL | sudo bash -s $add_args "$@"
            else
                # when run via calling local bash script
                printf "%b Re-running DigiNode Installer as root...\\n" "${INFO}"
                exec sudo bash "$0" "$@"
            fi

            exit $?
        else
            # Otherwise, tell the user they need to run the script as root, and bail
            printf "%b  %b Sudo utility check\\n" "${OVER}" "${CROSS}"
            printf "%b Sudo is needed for the DigiNode installer to proceed.\\n\\n" "${INFO}"
            printf "%b %bPlease re-run as root.${COL_NC}\\n" "${INFO}" "${COL_LIGHT_RED}"
            exit 1
        fi
    fi

    # Perform basic system check and lookup hardware architecture
    sys_check

     # Check for supported package managers so that we may install dependencies
    package_manager_detect

    # Notify user of package availability
    notify_package_updates_available

    # Install packages necessary to perform os_check
    printf "%b Checking for / installing required dependencies for pre-install checks...\\n" "${INFO}"
    install_dependent_packages "${SYS_CHECK_DEPS[@]}"

    # Check that the installed OS is officially supported - display warning if not
    os_check

    # Check if SELinux is Enforcing
    checkSelinux

    # Set the system text editor
    set_text_editor

    # Get the init system used by this Linux distro
    get_system_init

    # Create the diginode.settings file if this is the first run
    diginode_tools_create_settings

    # import diginode settings
    diginode_tools_import_settings

    # Set the system variables once we know we are on linux
    set_sys_variables

    # Check for Raspberry Pi hardware
    rpi_check

    # Install packages used by this installation script
    printf "%b Checking for / installing required dependencies for installer...\\n" "${INFO}"
    install_dependent_packages "${INSTALLER_DEPS[@]}"

    # Check if there is an existing install of DigiByte Core, installed with this script
    if [[ -f "${DGB_INSTALL_LOCATION}/.officialdiginode" ]]; then
        NewInstall=false
        printf "%b Existing DigiNode detected...\\n" "${INFO}"

        # If uninstall is requested, then do it now
        if [[ "$UNINSTALL" == true ]]; then
            uninstall_do_now
        fi

        # if it's running unattended,
        if [[ "${UNATTENDED_MODE}" == true ]]; then
            printf "%b Unattended Upgrade: Performing automatic upgrade - no whiptail dialogs will be displayed\\n" "${INFO}"
            # Perform unattended upgrade
            UnattendedUpgrade=true
            # also disable debconf-apt-progress dialogs
            export DEBIAN_FRONTEND="noninteractive"
        else
            # If running attended, show the available options (upgrade/reset/uninstall)
            printf "%b Interactive Upgrade: Displaying options menu (update/reset/uninstall)\\n" "${INFO}"
            UnattendedUpgrade=false
        fi
        printf "\\n"
    else
        NewInstall=true
        if [[ "${UNATTENDED_MODE}" == true ]]; then
            printf "%b Unattended Install: Using diginode.settings file - no whiptail dialogs will be displayed\\n" "${INFO}"
            # Perform unattended upgrade
            UnattendedInstall=true
            # also disable debconf-apt-progress dialogs
            export DEBIAN_FRONTEND="noninteractive"
        else
            UnattendedInstall=false
            printf "%b Interactive Install: Displaying installation menu - Whiptail dialogs will be displayed\\n" "${INFO}"
        fi
        printf "\\n"
    fi



    # If there is an existing install of DigiByte Core, but it was not installed by this script, then exit
    if [ -f "$DGB_INSTALL_LOCATION/bin/digibyted" ] && [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then
        printf "%b %bUnable to upgrade this installation of DigiByte Core%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b An existing install of DigiByte Core was discovered, but it was not originally installed\\n" "${INDENT}"
        printf "%b using this Installer and so cannot be upgraded. Please start with with a clean Linux installation.\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # If this is a new interaactive Install, display the welcome dialogs
    if [[ "${NewInstall}" == true ]] && [[ "${UnattendedInstall}" == false ]]; then

        # pause for a moment beofe displaying menu
        sleep 2

        # Display welcome dialogs
        welcomeDialogs

        # Show microSD card warnings if this is a Raspberry Pi
        rpi_microsd_ask

    fi

    # Check if the current user is 'digibyte'
    user_check

    # Ask to change the user
    user_ask_change

    # Change the user
    user_do_change

    # Check if the hostname is set to 'diginode'
    hostname_check

    # Ask to change the hostname
    hostname_ask_change

    # Check if a swap file is needed
    swap_check

    # Ask to change the swap
    swap_ask_change

    # Do swap setup
    swap_do_change

    # Check data drive disk space to ensure there is enough space to download the entire blockchain
    disk_check

    # Check data drive disk space to ensure there is enough space to download the entire blockchain
    disk_ask_lowspace


    ### UNATTENDED INSTALL - SET FULL DIGINODE VS DGB ONLY  ###

    # If this is an unattended install, refer to the diginode.settings file to know if we are doing a full or partial install
    if [[ "${UnattendedInstall}" == true ]]; then
        DO_FULL_INSTALL=$UI_DO_FULL_INSTALL
    fi

    ### UNATTENDED UPGRADE - SET FULL DIGINODE VS DGB ONLY  ###

    # If we are doing an unattended upgrade, check whether DigiAsset Node exists to decide whther it needs to be upgraded
    if [[ "${UnattendedUpgrade}" == true ]]; then
        if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
            DO_FULL_INSTALL=YES
        else
            DO_FULL_INSTALL=NO
        fi
    fi

    ### FIRST INSTALL MENU ###

    # If this is a new interaactive Install, display the first install menu
    if [[ "${UnattendedInstall}" == false ]]; then

        # Ask whther to install only DigiByte Core, or DigiAssets Node as well
        menu_first_install

    fi

    ### UPGRADE MENU ###

    # If DigiByte Core is already install, display the update menu
    if [[ "${UnattendedUpgrade}" == false ]]; then

        # Display the existing install menu
        menu_existing_install

        # Ask to install DigiAssets Node, it is not already installed
        menu_ask_install_digiasset_node

    fi



    ### PREVIOUS INSTALL - CHECK FOR UPDATES ###

    # Check if DigiByte Core is installed, and if there is an upgrade available
    digibyte_check

    # Check if IPFS installed, and if there is an upgrade available
    ipfs_check

    # Check if NodeJS is installed
    nodejs_check

    # Check if DigiAssets Node is installed, and if there is an upgrade available
    digiasset_node_check

    # Check if DigiNode Tools are installed (i.e. these scripts), and if there is an upgrade available
    diginode_tools_check


    ### UPDATES MENU - ASK TO INSTALL ANY UPDATES ###

    # Ask to install any upgrades, if there are any
    menu_ask_install_updates


    # Install packages used by the actual software
    printf "%b Checking for / installing required dependencies for DigiNode software...\\n" "${INFO}"
    install_dependent_packages "${dep_install_list[@]}"
    unset dep_install_list


    ### INSTALL/UPGRADE DIGIBYTE CORE ###

    # Create DigiByte.conf file
    digibyte_create_conf

    # Install/upgrade DigiByte Core
    digibyte_do_install

    # Create digibyted.service
    digibyte_create_service


    ### INSTALL/UPGRADE DIGINODE TOOLS ###

    # Install DigiNode Tools
    diginode_tools_do_install


    ### INSTALL/UPGRADE DIGIASSETS NODE ###

    # Create assetnode_config script PLUS main.json file (if they don't yet exist)
    digiasset_node_create_settings

    # Install/upgrade IPFS
    ipfs_do_install

    # Create IPFS service
    ipfs_create_service

    # Install/upgrade NodeJS
    nodejs_do_install

    # Install DigiAssets along with IPFS
    digiasset_node_do_install

    # Setup PM2 init service
    digiasset_node_pm2_create_service



    ### CLEAN UP ###

    # Change the hostname
    hostname_do_change

    # Request social media post
    request_social_media

    # Display donation QR Code
    donation_qrcode

    # Display reboot message (and how to run Status Monitor)
    request_reboot

    # Launch Status Monitor if requested
    launch_status_monitor




    exit

    # This stuff requires a reboot after changing











    #####################################
    echo ""
    printf "%b Exiting script early during testing!!" "${INFO}"
    echo ""
    exit # EXIT HERE DURING TEST
    #####################################


    if [[ "${NewInstall}" == true ]]; then

        # pause for a moment beofe displaying menu
        sleep 3

        # Display welcome dialogs
        welcomeDialogs


        # Create directory for Pi-hole storage
        install -d -m 755 /etc/pihole/
        # Determine available interfaces
        get_available_interfaces
        # Find interfaces and let the user choose one
        chooseInterface
        # Decide what upstream DNS Servers to use
        setDNS
        # Give the user a choice of blocklists to include in their install. Or not.
        chooseBlocklists
        # Let the user decide if they want to block ads over IPv4 and/or IPv6
        use4andor6
        # Let the user decide if they want the web interface to be installed automatically
        setAdminFlag
        # Let the user decide if they want query logging enabled...
        setLogging
        # Let the user decide the FTL privacy level
        setPrivacyLevel
    else
        # Setup adlist file if not exists
        installDefaultBlocklists

        # Source ${setupVars} to use predefined user variables in the functions
        source "${setupVars}"

        # Get the privacy level if it exists (default is 0)
        if [[ -f "${PI_HOLE_CONFIG_DIR}/pihole-FTL.conf" ]]; then
            PRIVACY_LEVEL=$(sed -ne 's/PRIVACYLEVEL=\(.*\)/\1/p' "${PI_HOLE_CONFIG_DIR}/pihole-FTL.conf")

            # If no setting was found, default to 0
            PRIVACY_LEVEL="${PRIVACY_LEVEL:-0}"
        fi
    fi
    # Download or update the scripts by updating the appropriate git repos
    clone_or_update_repos

    # Install the Core dependencies
    local dep_install_list=("${PIHOLE_DEPS[@]}")
    if [[ "${INSTALL_WEB_SERVER}" == true ]]; then
        # And, if the setting says so, install the Web admin interface dependencies
        dep_install_list+=("${PIHOLE_WEB_DEPS[@]}")
    fi



    # On some systems, lighttpd is not enabled on first install. We need to enable it here if the user
    # has chosen to install the web interface, else the LIGHTTPD_ENABLED check will fail
    if [[ "${INSTALL_WEB_SERVER}" == true ]]; then
        enable_service lighttpd
    fi
    # Determine if lighttpd is correctly enabled
    if check_service_active "lighttpd"; then
        LIGHTTPD_ENABLED=true
    else
        LIGHTTPD_ENABLED=false
    fi
    # Create the digibyte user
    create_digibyte_user

    # Check if FTL is installed - do this early on as FTL is a hard dependency for Pi-hole
    local funcOutput
    funcOutput=$(get_binary_name) #Store output of get_binary_name here
    local binary
    binary="pihole-FTL${funcOutput##*pihole-FTL}" #binary name will be the last line of the output of get_binary_name (it always begins with pihole-FTL)
    local theRest
    theRest="${funcOutput%pihole-FTL*}" # Print the rest of get_binary_name's output to display (cut out from first instance of "pihole-FTL")
    if ! FTLdetect "${binary}" "${theRest}"; then
        printf "  %b FTL Engine not installed\\n" "${CROSS}"
        exit 1
    fi

    # Install and log everything to a file
    installPihole | tee -a /proc/$$/fd/3

    # Copy the temp log file into final log location for storage
    copy_to_install_log

    if [[ "${INSTALL_WEB_INTERFACE}" == true ]]; then
        # Add password to web UI if there is none
        pw=""
        # If no password is set,
        if [[ $(grep 'WEBPASSWORD' -c /etc/pihole/setupVars.conf) == 0 ]] ; then
            # generate a random password
            pw=$(tr -dc _A-Z-a-z-0-9 < /dev/urandom | head -c 8)
            # shellcheck disable=SC1091
            . /opt/pihole/webpage.sh
            echo "WEBPASSWORD=$(HashPassword "${pw}")" >> "${setupVars}"
        fi
    fi

    # Check for and disable systemd-resolved-DNSStubListener before reloading resolved
    # DNSStubListener needs to remain in place for installer to download needed files,
    # so this change needs to be made after installation is complete,
    # but before starting or resarting the dnsmasq or ftl services
    disable_resolved_stublistener

    # If the Web server was installed,
    if [[ "${INSTALL_WEB_SERVER}" == true ]]; then
        if [[ "${LIGHTTPD_ENABLED}" == true ]]; then
            restart_service lighttpd
            enable_service lighttpd
        else
            printf "  %b Lighttpd is disabled, skipping service restart\\n" "${INFO}"
        fi
    fi

    printf "  %b Restarting services...\\n" "${INFO}"
    # Start services

    # Enable FTL
    # Ensure the service is enabled before trying to start it
    # Fixes a problem reported on Ubuntu 18.04 where trying to start
    # the service before enabling causes installer to exit
    enable_service pihole-FTL
    restart_service pihole-FTL

    # Download and compile the aggregated block list
    runGravity

    # Force an update of the updatechecker
    /opt/pihole/updatecheck.sh
    /opt/pihole/updatecheck.sh x remote

    if [[ "${useUpdateVars}" == false ]]; then
        displayFinalMessage "${pw}"
    fi

    # If the Web interface was installed,
    if [[ "${INSTALL_WEB_INTERFACE}" == true ]]; then
        # If there is a password,
        if (( ${#pw} > 0 )) ; then
            # display the password
            printf "  %b Web Interface password: %b%s%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${pw}" "${COL_NC}"
            printf "  %b This can be changed using 'pihole -a -p'\\n\\n" "${INFO}"
        fi
    fi

    if [[ "${useUpdateVars}" == false ]]; then
        # If the Web interface was installed,
        if [[ "${INSTALL_WEB_INTERFACE}" == true ]]; then
            printf "  %b View the web interface at http://pi.hole/admin or http://%s/admin\\n\\n" "${INFO}" "${IPV4_ADDRESS%/*}"
        fi
        # Explain to the user how to use Pi-hole as their DNS server
        printf "  %b You may now configure your devices to use the Pi-hole as their DNS server\\n" "${INFO}"
        [[ -n "${IPV4_ADDRESS%/*}" ]] && printf "  %b Pi-hole DNS (IPv4): %s\\n" "${INFO}" "${IPV4_ADDRESS%/*}"
        [[ -n "${IPV6_ADDRESS}" ]] && printf "  %b Pi-hole DNS (IPv6): %s\\n" "${INFO}" "${IPV6_ADDRESS}"
        printf "  %b If you have not done so already, the above IP should be set to static.\\n" "${INFO}"
        INSTALL_TYPE="Installation"
    else
        INSTALL_TYPE="Update"
    fi

    # Display where the log file is
    printf "\\n  %b The install log is located at: %s\\n" "${INFO}" "${installLogLoc}"
    printf "%b%s Complete! %b\\n" "${COL_LIGHT_GREEN}" "${INSTALL_TYPE}" "${COL_NC}"

    if [[ "${INSTALL_TYPE}" == "Update" ]]; then
        printf "\\n"
        "${PI_HOLE_BIN_DIR}"/pihole version --current
    fi

    # Set this install as an official DigiNode install
    set_official
}

if [[ "$RUN_INSTALLER" != "NO" ]] ; then
    main "$@"
fi





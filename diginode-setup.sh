#!/bin/bash
#
#           Name:  DigiNode Setup v0.7.0
#
#        Purpose:  Install and manage a DigiByte Node and DigiAsset Node via the linux command line.
#          
#  Compatibility:  Supports x86_86 or arm64 hardware with Ubuntu or Debian 64-bit distros.
#                  Other distros may not work at present. Please help test so that support can be added.
#                  A Raspberry Pi 4 8Gb running Raspberry Pi OS Lite 64-bit is recommended.
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
#                  chmod +x ~/diginode-tools/diginode-setup.sh
#
#                  To run DigiNode Setup:
#
#                  ~/diginode-tools/diginode-setup.sh      
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
# (Note: The RUN_SETUP condition ensures that the VERBOSE_MODE setting only applies to DigiNode Setup
# and is ignored if running the Status Monitor script - that has its own VERBOSE_MODE setting.)
if [[ "$RUN_SETUP" != "NO" ]] ; then
    VERBOSE_MODE=false
fi

######### IMPORTANT NOTE ###########
# Both the DigiNode Setup and Status Monitor scripts make use of a setting file
# located at ~/.digibyte/diginode.settings
# If you want to change the default folder locations, you should change the settings in this file.
# (e.g. To store your DigiByte Core data file on an external drive.)
#
# NOTE: This variable sets the default location of the diginode.settings file. 
# There should be no reason to change this, and it is unadvisable to do.
DGNT_SETTINGS_LOCATION=$USER_HOME/.digibyte
DGNT_SETTINGS_FILE=$DGNT_SETTINGS_LOCATION/diginode.settings

# This variable stores the approximate amount of space required to download the entire DigiByte blockchain
# This value needs updating periodically as the size of the blockchain increases over time
# It is used during the disk space check to ensure there is enough space on the drive to download the DigiByte blockchain.
# Last Updated: 2022-12-12
DGB_DATA_REQUIRED_HR="45Gb"
DGB_DATA_REQUIRED_KB="45000000"

# This is the URLs where the install script is hosted. This is used primarily for testing.
DGNT_VERSIONS_URL=diginode-versions.digibyte.help    # Used to query TXT record containing compatible OS'es
DGNT_SETUP_OFFICIAL_URL=https://diginode-setup.digibyte.help
DGNT_SETUP_GITHUB_LATEST_RELEASE_URL=diginode-setup.digibyte.help
DGNT_SETUP_GITHUB_MAIN_URL=https://raw.githubusercontent.com/saltedlolly/diginode-tools/main/diginode-setup.sh
DGNT_SETUP_GITHUB_DEVELOP_URL=https://raw.githubusercontent.com/saltedlolly/diginode-tools/develop/diginode-setup.sh

# This is the Github repo for the DigiAsset Node (this only needs to be changed if you with to test a new version.)
# The main branch is used by default. The dev branch is installed if the --dgadev flag is used.
DGA_GITHUB_REPO_MAIN="--depth 1 https://github.com/digiassetX/digiasset_node.git"
DGA_GITHUB_REPO_DEV="--branch development https://github.com/digiassetX/digiasset_node.git"


# These are the commands that the user pastes into the terminal to run DigiNode Setup
DGNT_SETUP_OFFICIAL_CMD="curl $DGNT_SETUP_OFFICIAL_URL | bash"

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
DGNT_BRANCH_REMOTE="release"
UNINSTALL=false
SKIP_OS_CHECK=false
SKIP_PKG_UPDATE_CHECK=false
DGA_BRANCH="main"
STATUS_MONITOR=false
DGANODE_ONLY=
SKIP_CUSTOM_MSG=false
# Check arguments for the undocumented flags
# --dgndev (-d) will use and install the develop branch of DigiNode Tools (used during development)
for var in "$@"; do
    case "$var" in
        "--reset" ) RESET_MODE=true;;
        "--unattended" ) UNATTENDED_MODE=true;;
        "--dgntdev" ) DGNT_BRANCH_REMOTE="develop";; 
        "--dgntmain" ) DGNT_BRANCH_REMOTE="main";; 
        "--dgadev" ) DGA_BRANCH="development";; 
        "--uninstall" ) UNINSTALL=true;;
        "--skiposcheck" ) SKIP_OS_CHECK=true;;
        "--skipupdatepkgcache" ) SKIP_PKG_UPDATE_CHECK=true;;
        "--verboseon" ) VERBOSE_MODE=true;;
        "--verboseoff" ) VERBOSE_MODE=false;;
        "--statusmonitor" ) STATUS_MONITOR=true;;
        "--runlocal" ) DGNT_RUN_LOCATION="local";;
        "--runremote" ) DGNT_RUN_LOCATION="remote";;
        "--dganodeonly" ) DGANODE_ONLY=true;;
        "--fulldiginode" ) DGANODE_ONLY=false;;
        "--skipcustommsg" ) SKIP_CUSTOM_MSG=true;;
    esac
done


# Set these values so DigiNode Setup can still run in color
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
SKIP="  [${COL_BOLD_WHITE}-${COL_NC}]"
EMPTY="  [ ]"
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



#####################################################################################################
### FUNCTIONS
#####################################################################################################

# This will get the size of the current terminal window
get_term_size() {
    # Get terminal size ('stty' is POSIX and always available).
    # This can't be done reliably across all bash versions in pure bash.
    read -r LINES COLUMNS < <(stty size)
}

# Inform user if Verbose Mode is enabled
is_verbose_mode() {
    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b Verbose Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
    fi
}

# Tell the user where this script is running from
where_are_we() {
    if [ "$DGNT_RUN_LOCATION" = "local" ]; then
        printf "%b DigiNode Setup is running locally.\\n" "${INFO}"
        printf "\\n"
    fi
    if [ "$DGNT_RUN_LOCATION" = "remote" ]; then
        printf "%b DigiNode Setup is running remotely.\\n" "${INFO}"
        printf "\\n"
    fi
}

# Inform user if Verbose Mode is enabled
is_unattended_mode() {
    if [ "$UNATTENDED_MODE" = true ]; then
        printf "%b Unattended Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        if [ -f "$DGNT_SETTINGS_FILE" ]; then
            printf "%b   No menus will be displayed - diginode.settings values will be used\\n" "${INDENT}"
        elif [ "$SKIP_CUSTOM_MSG" = true ]; then
            printf "%b   diginode.settings file not found - it will be created and the default values used\\n" "${INDENT}"
        elif [ "$SKIP_CUSTOM_MSG" = false ]; then
            printf "%b   diginode.settings file not found - it will be created and setup will exit so you can customize your install\\n" "${INDENT}"
        fi
        printf "\\n"
    fi
}

# Inform user if DigiAsset Node ONLY is enable
is_dganode_only_mode() {
    if [ "$DGANODE_ONLY" = true ]; then
        printf "%b DigiAsset Node ONLY Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
    fi
    if [ "$DGANODE_ONLY" = false ]; then
        printf "%b FULL DigiNode Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
    fi
}

# Inform user if DigiAsset Dev Mode is enable
is_dgadev_mode() {
    if [ "$DGA_BRANCH" = "development" ]; then
        printf "%b DigiAsset Node Developer Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b   The development version of DigiAsset Node will be installed.\\n" "${INDENT}"
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
        purge_dgnt_settings
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

    # Update diginode.settings with the current version if it has just been created, is running locally, and is on the main branch
    if [ "$DGNT_RUN_LOCATION" = "remote" ]; then

        #lookup latest release version on Github (need jq installed for this query)
        local dgnt_ver_release_query=$(curl -sL https://api.github.com/repos/saltedlolly/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')

        # If we get a response, update the stored release version
        if [ "$dgnt_ver_release_query" != "" ]; then
            DGNT_VER_RELEASE=$dgnt_ver_release_query
            DGNT_SETTINGS_FILE_VER_NEW=$dgnt_ver_release_query
            printf "%b Setting diginode.settings version to $DGNT_SETTINGS_FILE_VER_NEW\\n" "${INFO}"
        fi

        # Set the current branch for diginpde.settings
        DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_BRANCH_REMOTE
        printf "%b Setting diginode.settings branch to $DGNT_SETTINGS_FILE_VER_BRANCH_NEW\\n" "${INFO}"

    fi

    # create .digibyte folder if it does not exist
    if [ ! -d "$DGNT_SETTINGS_LOCATION" ]; then
        str="Creating ~/.digibyte folder..."
        printf "\\n%b %s" "${INFO}" "${str}"
        if [ "$VERBOSE_MODE" = true ]; then
            printf "\\n"
            printf "%b   Folder location: $DGNT_SETTINGS_LOCATION\\n" "${INDENT}"
            sudo -u $USER_ACCOUNT mkdir $DGNT_SETTINGS_LOCATION
            IS_DIGIBYTE_SETTINGS_FOLDER_NEW="YES"
        else
            sudo -u $USER_ACCOUNT mkdir $DGNT_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IS_DIGIBYTE_SETTINGS_FOLDER_NEW="YES"
        fi
    fi

    # Make sure the user owns this folder
    # chown $USER_ACCOUNT $DGNT_SETTINGS_LOCATION

    ########################################
    # SET DIGINODE.SETTINGS DEFAULT VALUES #
    ########################################

    # The values are used when the diginode.settings file is first created

    # FILE AND FOLDER LOCATIONS
    DGB_DATA_LOCATION=$USER_HOME/.digibyte/

    # OTHER SETTINGS
    DGB_MAX_CONNECTIONS=300
    SM_AUTO_QUIT=20
    SM_DISPLAY_BALANCE=YES
    DGNT_DEV_BRANCH=YES
    INSTALL_SYS_UPGRADES=NO

    # UNATTENDED INSTALL
    UI_ENFORCE_DIGIBYTE_USER=YES
    UI_HOSTNAME_SET=YES
    UI_FIREWALL_SETUP=YES
    UI_SWAP_SETUP=YES
    UI_SWAP_SIZE_MB=
    UI_SWAP_FILE=/swapfile
    UI_DISKSPACE_OVERRIDE=NO
    UI_TOR_SETUP=YES
    UI_DO_FULL_INSTALL=YES
    UI_DGB_ENABLE_UPNP=NO
    UI_IPFS_ENABLE_UPNP=NO
    UI_IPFS_SERVER_PROFILE=NO
    UI_DGB_NETWORK=MAINNET

    # SYSTEM VARIABLES
    DGB_INSTALL_LOCATION=$USER_HOME/digibyte
    IPFS_KUBO_API_URL=http://127.0.0.1:5001/api/v0/
    DGB_PORT_TEST_ENABLED=YES
    IPFS_PORT_TEST_ENABLED=YES
    DONATION_PLEA=YES

    # create diginode.settings file
    diginode_settings_create_update

    if [ "$VERBOSE_MODE" = true ]; then
        printf "\\n"
        printf "%b   File location: $DGNT_SETTINGS_FILE\\n" "${INDENT}"
    else
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    IS_DIGINODE_SETTINGS_FILE_NEW="YES"

    # If we are running unattended, then exit now so the user can customize diginode.settings, since it just been created
    if [ "$UNATTENDED_MODE" = true ] && [ "$SKIP_CUSTOM_MSG" = false ]; then
        printf "\\n"
        printf "%b %bIMPORTANT: Customize your Unattended Install before running this again!!%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Since this is the first time running DigiNode Setup, a settings file used for\\n" "${INDENT}"
        printf "%b customizing an Unattended Install has just been created at: $DGNT_SETTINGS_FILE\\n" "${INDENT}"
        printf "\\n"
        printf "%b If you want to customize your Unattended Install of DigiNode, you need to edit\\n" "${INDENT}"
        printf "%b this file before running DigiNode Setup again with the --unattended flag.\\n" "${INDENT}"
        printf "\\n"
        if [ "$TEXTEDITOR" != "" ]; then
            printf "%b You can edit it by entering:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   $TEXTEDITOR $DGNT_SETTINGS_FILE\\n" "${INDENT}"
            printf "\\n"
        fi
        printf "%b Note: If you wish to skip displaying this message at first run in future, \\n" "${INDENT}"
        printf "%b       use the --skipcustommsg flag\\n" "${INDENT}"
        printf "\\n"
        exit
    fi

    # The settings file exists, so source it
    str="Importing diginode.settings file..."
    printf "%b %s" "${INFO}" "${str}"
    source $DGNT_SETTINGS_FILE

    if [ "$VERBOSE_MODE" = true ]; then
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


# This function actually creates or updates the diginode.settings file
diginode_settings_create_update() {

if [ -f "$DGNT_SETTINGS_FILE" ]; then
    str="Removing existing diginode.settings file..."
    printf "%b %s" "${INFO}" "${str}"
    rm -f DGNT_SETTINGS_FILE
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    recreate_diginode_settings="yes"
fi


# create diginode.settings file
if [ "$recreate_diginode_settings" = "yes" ]; then
    str="Recreating diginode.settings file..."
else
    str="Creating diginode.settings file..."
fi
printf "%b %s" "${INFO}" "${str}"
sudo -u $USER_ACCOUNT touch $DGNT_SETTINGS_FILE
cat <<EOF > $DGNT_SETTINGS_FILE
#!/bin/bash
# This settings file is used to store variables for DigiNode Setup and DigiNode Status Monitor

# DIGINODE.SETTINGS FILE VERSION
DGNT_SETTINGS_FILE_VER=$DGNT_SETTINGS_FILE_VER_NEW
DGNT_SETTINGS_FILE_VER_BRANCH=$DGNT_SETTINGS_FILE_VER_BRANCH_NEW

############################################
####### FOLDER AND FILE LOCATIONS ##########
##########################################

# DEFAULT FOLDER AND FILE LOCATIONS
# If you want to change the default location of folders you can edit them here
# Important: Use the USER_HOME variable to identify your home folder location.

# DGNT_SETTINGS_LOCATION=   [This value is set in the header of the setup script. Do not set it here.]
# DGNT_SETTINGS_FILE=       [This value is set in the header of the setup script. Do not set it here.]

# DIGIBYTE CORE BLOCKCHAIN DATA LOCATION:
# You can change this to optionally store the DigiByte blockchain data in a diferent location
# The value set below will be used by the normal install and the unattended install
# Note - changing this after the DigiByte Node has already been running will cause
# the blockchain to be be re-downloaded in the new location. The old data will need to be deleted manually
# or moved to the new location first. Follow these recommended steps to change the location:
# 1) Stop the digibyted service
# 2) Manually move the blockchain data from the old to the new location
# 3) Update this file with the new location below
# 4) Re-run DigiNode Setup to automatically update your service file and digibyte.conf file with the new location
# 5) Restart the digibyted service 
DGB_DATA_LOCATION=$DGB_DATA_LOCATION


#####################################
####### OTHER SETTINGS ##############
#####################################

# THis will set the max connections in the digibyte.conf file on the first install
# This value set here is also used when performing an unattended install
# (Note: If a digibyte.conf file already exists that sets the maxconnections already, the value here will be ignored)
DGB_MAX_CONNECTIONS=$DGB_MAX_CONNECTIONS

# Stop the DigiNode Status Monitor automatically if it is left running. The default is 20 minutes.
# To avoid putting unnecessary strain on your device, it is inadvisable to run the Status Monitor for
# long periods. Enter the number of minutes before it exits automatically, or set to 0 to run indefinitely.
# e.g. To stop after 1 hour enter: 60 
SM_AUTO_QUIT=$SM_AUTO_QUIT

# Choose whether to display the current wallet balance in the DigiNode Status Monitor. (Specify either YES or NO.)
# Note: The current wallet balance will only be displayed when (a) this variable is set to YES, and (b) the blockchain 
# has completed syncing, and (c) there are actually funds in the wallet (i.e. the balance is > 0).
SM_DISPLAY_BALANCE=$SM_DISPLAY_BALANCE

# Install the develop branch of DigiNode Tools (Specify either YES or NO)
# If NO, it will install the latest release version
DGNT_DEV_BRANCH=$DGNT_DEV_BRANCH

# This let's you choose whther system upgrades are installed alongside upgrades for the DigiNode software
INSTALL_SYS_UPGRADES=$INSTALL_SYS_UPGRADES


#####################################
####### UNATTENDED INSTALL ##########
#####################################

# INSTRUCTIONS: 
# These variables are used during an unattended install to automatically configure your DigiNode.
# Set these variables and then run DigiNode Setup with the --unattended flag set.

# Decide whether to have the script enforce using user: digibyte (Set to YES/NO)
# If set to YES DigiNode Setup will only proceed if the the user is: digibyte
# If set to NO DigiNode Setup will install as the current user
UI_ENFORCE_DIGIBYTE_USER=$UI_ENFORCE_DIGIBYTE_USER

# Choose whether to change the system hostname to: diginode (Set to YES/NO)
# If you are running a dedicated device (e.g. Raspberry Pi) as your DigiNode then you probably want to do this.
# If it is running on a Linux box with a load of other stuff, then maybe not.
# If you are running a DigiByte testnet, then the hostname will be set to diginode-testnet instead
UI_HOSTNAME_SET=$UI_HOSTNAME_SET

# Choose whether to setup the local ufw firewall (Set to YES/NO) [NOT WORKING YET]
UI_FIREWALL_SETUP=$UI_FIREWALL_SETUP

# Choose whether to create or change the swap file size
# The optimal swap size will be calculated to ensure there is 8Gb total memory.
# e.g. If the system has 2Gb RAM, it will create a 6Gb swap file. Total: 8Gb.
# If there is more than 8Gb RAM available, no swap will be created.
# You can override this by manually entering the desired size in UI_SWAP_SIZE_MB below.
UI_SWAP_SETUP=$UI_SWAP_SETUP

# You can optionally manually enter a desired swap file size here in MB.
# The UI_SWAP_SETUP variable above must be set to YES for this to be used.
# If you leave this value empty, the optimal swap file size will calculated by DigiNode Setup.
# Enter the amount in MB only, without the units. (e.g. 4Gb = 4000 )
UI_SWAP_SIZE_MB=$UI_SWAP_SIZE_MB

# This is where the swap file will be located. You can change this to store it on an external drive
# if desired.
UI_SWAP_FILE=$UI_SWAP_FILE

# Will install regardless of available disk space on the data drive. Use with caution.
UI_DISKSPACE_OVERRIDE=$UI_DISKSPACE_OVERRIDE

# Choose whether to setup Tor [NOT WORKING YET]
UI_TOR_SETUP=$UI_TOR_SETUP

# Choose YES to do a Full DigiNode with both DigiByte and DigiAsset Nodes
# Choose NO to install DigiByte Core only
UI_DO_FULL_INSTALL=$UI_DO_FULL_INSTALL

# Choose whther to have the script enable upnp. This can be set for DigiByte Core and for IPFS
# If set to NO, port forwarding will need to be setup manually. This is the recommended method.
# If set to YES, UPnP will be open the required ports automatically.
UI_DGB_ENABLE_UPNP=$UI_DGB_ENABLE_UPNP
UI_IPFS_ENABLE_UPNP=$UI_IPFS_ENABLE_UPNP

# Optionally use the Server Profile for IPFS. Set to YES or NO. Default is NO.
# The IPFS Server profile disables local host discovery, which is recommended when running a
# DigiAsset Node on a machine with a public IPv4 address, such as on a cloud VPS.
# Learn more: https://github.com/ipfs/kubo/blob/master/docs/config.md#profiles 
UI_IPFS_SERVER_PROFILE=$UI_IPFS_SERVER_PROFILE

# Choose which DigiByte Blockchain Network to use. (Set to MAINNET or TESTNET. Default is MAINNET)
UI_DGB_NETWORK=$UI_DGB_NETWORK


#############################################
####### SYSTEM VARIABLES ####################
#############################################

# IMPORTANT: DO NOT CHANGE ANY OF THESE VALUES. THEY ARE CREATED AND SET AUTOMATICALLY BY DigiNode Setup and the Status Monitor.
# Changing them will likely break your install, as the changes will be overwritten whenever a new version of DigiNode Tools is released.

# DIGIBYTE NODE LOCATION:
# This references a symbolic link that points at the actual install folder. Please do not change this.
# If you are using DigiNode Setup to manage your node there is no reason to change this.
# If you must change the install location, do not edit it here - it may break things. Instead, create a symbolic link 
# called 'digibyte' in your home folder that points to the location of your DigiByte Core install folder.
# Be aware that DigiNode Setup upgrades will likely not work if you do this. The Status Monitor script will help you create one.
#  
DGB_INSTALL_LOCATION=$DGB_INSTALL_LOCATION

# Do not change this.
# You can change the location of the blockchain data with the DGB_DATA_LOCATION variable above.
DGB_SETTINGS_LOCATION=\$USER_HOME/.digibyte

# DIGIBYTE NODE FILES: (do not change these)
DGB_CONF_FILE=\$DGB_SETTINGS_LOCATION/digibyte.conf 
DGB_CLI=\$DGB_INSTALL_LOCATION/bin/digibyte-cli
DGB_DAEMON=\$DGB_INSTALL_LOCATION/bin/digibyted

# IPFS NODE LOCATION (do not change this)
IPFS_SETTINGS_LOCATION=\$USER_HOME/.ipfs

# DIGIASSET NODE LOCATION: (do not change these)
# The backup location variable is a temporary folder that stores your _config folder backup during a reset or uninstall.
# When reinstalling, this folder is automatically restored to the correct location, typically ~/digiasset_node/_config
DGA_INSTALL_LOCATION=\$USER_HOME/digiasset_node
DGA_SETTINGS_LOCATION=\$DGA_INSTALL_LOCATION/_config
DGA_SETTINGS_BACKUP_LOCATION=\$USER_HOME/dga_config_backup

# DIGIASSET NODE FILES: (do not change these)
DGA_SETTINGS_FILE=\$DGA_SETTINGS_LOCATION/main.json
DGA_SETTINGS_BACKUP_FILE=\$DGA_SETTINGS_BACKUP_LOCATION/main.json

# SYSTEM SERVICE FILES: (do not change these)
DGB_SYSTEMD_SERVICE_FILE=/etc/systemd/system/digibyted.service
DGB_UPSTART_SERVICE_FILE=/etc/init/digibyted.conf
IPFS_SYSTEMD_SERVICE_FILE=/etc/systemd/system/ipfs.service
IPFS_UPSTART_SERVICE_FILE=/etc/init/ipfs.conf
PM2_SYSTEMD_SERVICE_FILE=/etc/systemd/system/pm2-$USER_ACCOUNT.service
PM2_UPSTART_SERVICE_FILE=/etc/init/pm2-$USER_ACCOUNT.service

# Store DigiByte Core Installation details:
DGB_INSTALL_DATE="$DGB_INSTALL_DATE"
DGB_UPGRADE_DATE="$DGB_UPGRADE_DATE"
DGB_VER_RELEASE="$DGB_VER_RELEASE"
DGB_VER_LOCAL="$DGB_VER_LOCAL"
DGB_VER_LOCAL_CHECK_FREQ="$DGB_VER_LOCAL_CHECK_FREQ"

# DIGINODE TOOLS LOCATION:
# This is the default location where the scripts get installed to. (Do not change this.)
DGNT_LOCATION=\$USER_HOME/diginode-tools

# DIGINODE TOOLS FILES: (do not change these)
DGNT_SETUP_SCRIPT=\$DGNT_LOCATION/diginode-setup.sh
DGNT_SETUP_LOG=\$DGNT_LOCATION/diginode.log
DGNT_MONITOR_SCRIPT=\$DGNT_LOCATION/diginode.sh

# DIGINODE TOOLS INSTALLATION DETAILS:
# Release/Github versions are queried once a day and stored here. Local version number are queried every minute.
DGNT_INSTALL_DATE="$DGNT_INSTALL_DATE"
DGNT_UPGRADE_DATE="$DGNT_UPGRADE_DATE"
DGNT_MONITOR_FIRST_RUN="$DGNT_MONITOR_FIRST_RUN"
DGNT_MONITOR_LAST_RUN="$DGNT_MONITOR_LAST_RUN"
DGNT_VER_LOCAL="$DGNT_VER_LOCAL"
DGNT_VER_LOCAL_DISPLAY="$DGNT_VER_LOCAL_DISPLAY"
DGNT_VER_RELEASE="$DGNT_VER_RELEASE"

# This is updated automatically every time DigiNode Tools is installed/upgraded. 
# It stores the DigiNode Tools github branch that is currently installed (e.g. develop/main/release)
DGNT_BRANCH_LOCAL="$DGNT_BRANCH_LOCAL"

# Store DigiAsset Node installation details:
DGA_INSTALL_DATE="$DGA_INSTALL_DATE"
DGA_UPGRADE_DATE="$DGA_UPGRADE_DATE"
DGA_FIRST_RUN="$DGA_FIRST_RUN"
DGA_VER_MJR_LOCAL="$DGA_VER_MJR_LOCAL"
DGA_VER_MNR_LOCAL="$DGA_VER_MNR_LOCAL"
DGA_VER_LOCAL="$DGA_VER_LOCAL"
DGA_VER_MJR_RELEASE="$DGA_VER_MJR_RELEASE"
DGA_VER_RELEASE="$DGA_VER_RELEASE"
DGA_LOCAL_BRANCH="$DGA_LOCAL_BRANCH"

# Store Kubo (Go-IPFS) installation details:
IPFS_VER_LOCAL="$IPFS_VER_LOCAL"
IPFS_VER_RELEASE="$IPFS_VER_RELEASE"
IPFS_INSTALL_DATE="$IPFS_INSTALL_DATE"
IPFS_UPGRADE_DATE="$IPFS_UPGRADE_DATE"
IPFS_KUBO_API_URL=$IPFS_KUBO_API_URL

# Store NodeJS installation details:
NODEJS_VER_LOCAL="$NODEJS_VER_LOCAL"
NODEJS_VER_RELEASE="$NODEJS_VER_RELEASE"
NODEJS_INSTALL_DATE="$NODEJS_INSTALL_DATE"
NODEJS_UPGRADE_DATE="$NODEJS_UPGRADE_DATE"
NODEJS_PPA_ADDED="$NODEJS_PPA_ADDED"

# Timer variables (these control the timers in the Status Monitor loop)
SAVED_TIME_15SEC="$SAVED_TIME_15SEC"
SAVED_TIME_1MIN="$SAVED_TIME_1MIN"
SAVED_TIME_15MIN="$SAVED_TIME_15MIN"
SAVED_TIME_1DAY="$SAVED_TIME_1DAY"
SAVED_TIME_1WEEK="$SAVED_TIME_1WEEK"

# Disk usage variables (updated every 15 seconds)
BOOT_DISKFREE_HR="$BOOT_DISKFREE_HR"
BOOT_DISKFREE_KB="$BOOT_DISKFREE_KB"
BOOT_DISKUSED_HR="$BOOT_DISKUSED_HR"
BOOT_DISKUSED_KB="$BOOT_DISKUSED_KB"
BOOT_DISKUSED_PERC="$BOOT_DISKUSED_PERC"
DGB_DATA_DISKFREE_HR="$DGB_DATA_DISKFREE_HR"
DGB_DATA_DISKFREE_KB="$DGB_DATA_DISKFREE_KB"
DGB_DATA_DISKUSED_HR="$DGB_DATA_DISKUSED_HR"
DGB_DATA_DISKUSED_KB="$DGB_DATA_DISKUSED_KB"
DGB_DATA_DISKUSED_PERC="$DGB_DATA_DISKUSED_PERC"

# IP addresses (only rechecked once every 15 minutes)
IP4_INTERNAL="$IP4_INTERNAL"
IP4_EXTERNAL="$IP4_EXTERNAL"

# This records when DigiNode was last backed up to a USB stick
DGB_WALLET_BACKUP_DATE_ON_DIGINODE="$DGB_WALLET_BACKUP_DATE_ON_DIGINODE"
DGA_CONFIG_BACKUP_DATE_ON_DIGINODE="$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE"

# Stores when an DigiByte Core port test last ran successfully.
# If you wish to re-enable the DigiByte Core port test, change the DGB_PORT_TEST_ENABLED variable to YES.
DGB_PORT_TEST_ENABLED="$DGB_PORT_TEST_ENABLED"
DGB_PORT_FWD_STATUS="$DGB_PORT_FWD_STATUS"
DGB_PORT_TEST_PASS_DATE="$DGB_PORT_TEST_PASS_DATE"
DGB_PORT_TEST_EXTERNAL_IP="$DGB_PORT_TEST_EXTERNAL_IP"
DGB_PORT_NUMBER_SAVED="$DGB_PORT_NUMBER_SAVED"

# Stores when an IPFS port test last ran successfully.
# If you wish to re-enable the IPFS port test, change the IPFS_PORT_TEST_ENABLED variable to YES.
IPFS_PORT_TEST_ENABLED="$IPFS_PORT_TEST_ENABLED"
IPFS_PORT_FWD_STATUS="$IPFS_PORT_FWD_STATUS"
IPFS_PORT_TEST_PASS_DATE="$IPFS_PORT_TEST_PASS_DATE"
IPFS_PORT_TEST_EXTERNAL_IP="$IPFS_PORT_TEST_EXTERNAL_IP"
IPFS_PORT_NUMBER_SAVED="$IPFS_PORT_NUMBER_SAVED"

# Do not display donation plea more than once every 15 mins (value should be YES or WAIT15)
DONATION_PLEA="$DONATION_PLEA"

# Store DigiByte blockchain sync progress
BLOCKSYNC_VALUE="$BLOCKSYNC_VALUE"

# Store number of available system updates so the script only checks this occasionally
SYSTEM_REGULAR_UPDATES="$SYSTEM_REGULAR_UPDATES"
SYSTEM_SECURITY_UPDATES="$SYSTEM_SECURITY_UPDATES"

EOF

}

# Import the diginode.settings file it it exists
# check if diginode.settings file exists
diginode_tools_import_settings() {

if [ -f "$DGNT_SETTINGS_FILE" ] && [ "$IS_DGNT_SETTINGS_FILE_NEW" != "YES" ]; then

    # The settings file exists, so source it
    str="Importing diginode.settings file..."
    printf "%b %s" "${INFO}" "${str}"

    source $DGNT_SETTINGS_FILE
    
    if [ "$VERBOSE_MODE" = true ]; then
        printf "\\n"
        printf "%b   File location: $DGNT_SETTINGS_FILE\\n" "${INDENT}"
        printf "\\n"
    else
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"
    fi

else
    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b diginode.settings file not found\\n" "${INDENT}"
        printf "\\n"
    fi
fi

}

# THis function will update the existing diginode.settings file with the new version, if there is one (this occurs whenever there is a new release of DigiNode Tools, or if the branch the user is running changes)
diginode_tools_update_settings() {

    if [ -f "$DGNT_SETTINGS_FILE" ] && [ "$IS_DGNT_SETTINGS_FILE_NEW" != "YES" ]; then

        # If this is running remotely, first check if the branch has been changed, then lookup the new release version, and then
        if [ "$DGNT_RUN_LOCATION" = "remote" ]; then

            # If the branch has changed we need to do a new update
            if [ "$DGNT_BRANCH_REMOTE" != "$DGNT_SETTINGS_FILE_VER_BRANCH" ]; then
                printf "%b diginode.settings branch has changed from \"$DGNT_SETTINGS_FILE_VER_BRANCH\" to \"$DGNT_BRANCH_REMOTE\".\\n" "${INFO}"
                DGNT_SETTINGS_DO_UPGRADE="YES"
                DGNT_SETTINGS_BRANCH_HAS_CHANGED="YES"
                DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_BRANCH_REMOTE
            fi

            # If we are running the develop or main branch do an update regardless
            if [ "$DGNT_SETTINGS_DO_UPGRADE" != "YES" ] && [ "$DGNT_BRANCH_REMOTE" = "main" ]; then
                printf "%b We are using the main branch - diginode.settings will be updated.\\n" "${INFO}"
                DGNT_SETTINGS_DO_UPGRADE="YES"
                DGNT_SETTINGS_BRANCH_HAS_CHANGED="YES"
                DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_BRANCH_REMOTE
            fi

            # If we are running the develop or main branch do an update regardless
            if [ "$DGNT_SETTINGS_DO_UPGRADE" != "YES" ] && [ "$DGNT_BRANCH_REMOTE" = "develop" ]; then
                printf "%b We are using the develop branch - diginode.settings will be updated.\\n" "${INFO}"
                DGNT_SETTINGS_DO_UPGRADE="YES"
                DGNT_SETTINGS_BRANCH_HAS_CHANGED="YES"
                DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_BRANCH_REMOTE
            fi

            # Let's get the current release version
            local dgnt_ver_release_query=$(curl -sL https://api.github.com/repos/saltedlolly/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')

             # If we get a response, update the stored release version
            if [ "$dgnt_ver_release_query" != "" ]; then
                DGNT_VER_RELEASE=$dgnt_ver_release_query
                DGNT_SETTINGS_FILE_VER_NEW=$dgnt_ver_release_query
            fi

        fi

        # If this is running locally, lookup the local version number to see if the settings file needs to be updated
        if [ "$DGNT_RUN_LOCATION" = "local" ]; then

            # Get the current local branch, if any
            if [[ -f "$DGNT_MONITOR_SCRIPT" ]]; then
                dgnt_branch_local_query=$(git -C $DGNT_LOCATION rev-parse --abbrev-ref HEAD 2>/dev/null)
            fi

            # If we get a valid local branch, update the stored local branch
            if [ "$dgnt_branch_local_query" != "" ]; then
                DGNT_BRANCH_LOCAL=$dgnt_branch_local_query
            fi

            # Set the local branch to "release" if it returns "HEAD"
            if [ "$DGNT_BRANCH_LOCAL" = "HEAD" ]; then
                DGNT_BRANCH_LOCAL="release"
            fi

            # If the files have been manually updated over SFTP (usually during development), the script may not have been able to detect the local branch
            # In this case, we'll update diginode.settings regardless since it may have been changed. (We just don't know so must assume it has.)
            if [ "$DGNT_BRANCH_LOCAL" = "" ]; then

                printf "%b WARNING: The current local branch of DigiNode Tools is unknown - diginode.settings will be updated to avoid problems.\\n" "${WARN}"
                DGNT_SETTINGS_DO_UPGRADE="YES"
                DGNT_SETTINGS_BRANCH_HAS_CHANGED="YES"  #At least we are assuming it has
                DGNT_SETTINGS_FILE_VER_BRANCH_NEW=""
            fi

            # If the branch has changed we need to do a new update to diginode.settings
            # (we only need to check this if it has not already been established that we need to do an update above)
            if [ "$DGNT_BRANCH_LOCAL" != "$DGNT_SETTINGS_FILE_VER_BRANCH" ] && [ "$DGNT_SETTINGS_DO_UPGRADE" != "YES" ]; then
                printf "%b diginode.settings branch has changed from \"$DGNT_SETTINGS_FILE_VER_BRANCH\" to \"$DGNT_BRANCH_LOCAL\".\\n" "${INFO}"
                DGNT_SETTINGS_DO_UPGRADE="YES"
                DGNT_SETTINGS_BRANCH_HAS_CHANGED="YES"
                DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_BRANCH_LOCAL
            fi

            # If we are running the develop or main branch do an update regardless
            if [ "$DGNT_SETTINGS_DO_UPGRADE" != "YES" ] && [ "$DGNT_BRANCH_LOCAL" = "main" ]; then
                printf "%b We are using the main branch - diginode.settings will be updated.\\n" "${INFO}"
                DGNT_SETTINGS_DO_UPGRADE="YES"
                DGNT_SETTINGS_BRANCH_HAS_CHANGED="YES"
                DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_BRANCH_REMOTE
            fi

            # If we are running the develop or main branch do an update regardless
            if [ "$DGNT_SETTINGS_DO_UPGRADE" != "YES" ] && [ "$DGNT_BRANCH_LOCAL" = "develop" ]; then
                printf "%b We are using the develop branch - diginode.settings will be updated.\\n" "${INFO}"
                DGNT_SETTINGS_DO_UPGRADE="YES"
                DGNT_SETTINGS_BRANCH_HAS_CHANGED="YES"
                DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_BRANCH_REMOTE
            fi

            # Get the current local version, if any
            if [[ -f "$DGNT_MONITOR_SCRIPT" ]]; then
                local dgnt_ver_local_query=$(cat $DGNT_MONITOR_SCRIPT | grep -m1 DGNT_VER_LOCAL  | cut -d'=' -f 2)
            fi

            # If we get a valid version number, update the stored local version
            if [ "$dgnt_ver_local_query" != "" ]; then
                DGNT_VER_LOCAL=$dgnt_ver_local_query
                DGNT_SETTINGS_FILE_VER_NEW=$dgnt_ver_local_query
            fi

        fi

        # If the diginode.settings file branch has not changed, check if the diginode.settings file version has changed
        if [ "$DGNT_SETTINGS_BRANCH_HAS_CHANGED" != "YES" ] && [ $(version $DGNT_SETTINGS_FILE_VER_NEW) -gt $(version $DGNT_SETTINGS_FILE_VER) ]; then
            printf "%b diginode.settings needs upgrading from v$DGNT_SETTINGS_FILE_VER to v$DGNT_SETTINGS_FILE_VER_NEW.\\n" "${INFO}"
            # create a new diginode.settinngs file
            DGNT_SETTINGS_DO_UPGRADE="YES"
            DGNT_SETTINGS_FILE_VER_BRANCH_NEW=$DGNT_SETTINGS_FILE_VER_BRANCH
        fi

        # 
        if [ "$DGNT_SETTINGS_DO_UPGRADE" = "YES" ]; then
            printf "%b Starting diginode.settings upgrade...\\n" "${INFO}"

            # Update diginode.settings
            diginode_settings_create_update

            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Import the new diginode.settings file
            str="Importing new diginode.settings file..."
            printf "%b %s" "${INFO}" "${str}"
            source $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    
        fi

        # Only insert a line break if we did updated diginode.settings
        if [ "$DGNT_SETTINGS_DO_UPGRADE" = "YES" ]; then
            printf "\\n"
        fi

        DGNT_SETTINGS_DO_UPGRADE="NO"

    fi

}

# Function to set the DigiNode Tools Dev branch to use
set_dgnt_branch() {

    # Set relevant Github branch for DigiNode Tools
    if [ "$DGNT_BRANCH_REMOTE" = "develop" ]; then
        if [[ "${EUID}" -eq 0 ]]; then
            printf "%b DigiNode Tools Developer Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b   The develop branch will be used.\\n" "${INDENT}"
            printf "\\n"
        fi
        DGNT_SETUP_URL=$DGNT_SETUP_GITHUB_DEVELOP_URL
    elif [ "$DGNT_BRANCH_REMOTE" = "main" ]; then
        if [[ "${EUID}" -eq 0 ]]; then
            printf "%b DigiNode Tools Main Branch Mode: %bEnabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b   The main branch will be used. Used for testing before pushing a final release.\\n" "${INDENT}"
            printf "\\n"
        fi
        DGNT_SETUP_URL=$DGNT_SETUP_GITHUB_MAIN_URL
    else
        # If latest release branch does not exist, use main branch
            if [ "$DGNT_SETUP_GITHUB_LATEST_RELEASE_URL" = "" ]; then
                if [[ "${EUID}" -eq 0 ]] && [ $VERBOSE_MODE = true ]; then
                    printf "%b %bDigiNode Tools release branch is unavailable - main branch will be used.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                    printf "\\n"
                fi
                DGNT_SETUP_URL=$DGNT_SETUP_GITHUB_MAIN_URL
            else
                if [[ "${EUID}" -eq 0 ]] && [ $VERBOSE_MODE = true ]; then
                    printf "%b %bDigiNode Tools latest release branch will be used.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                    printf "\\n"
                fi
                DGNT_SETUP_URL=$DGNT_SETUP_GITHUB_LATEST_RELEASE_URL
            fi
    fi
}


# These are only set after the intitial OS check since they cause an error on MacOS
set_sys_variables() {

    local str

    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b Looking up system variables...\\n" "${INFO}"
    else
        str="Looking up system variables..."
        printf "%b %s" "${INFO}" "${str}"
    fi

    # check the 'cat' command is available
    if ! is_command cat ; then
        if [ "$VERBOSE_MODE" = false ]; then
            printf "\\n"
        fi
        printf "%b %bERROR: Unable to look up system variables - 'cat' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        purge_dgnt_settings
        exit 1
    fi

    # check the 'free' command is available
    if ! is_command free ; then
        if [ "$VERBOSE_MODE" = false ]; then
            printf "\\n"
        fi
        printf "%b %bERROR: Unable to look up system variables - 'free' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        purge_dgnt_settings
        exit 1
    fi

    # check the 'df' command is available
    if ! is_command df ; then
        if [ "$VERBOSE_MODE" = false ]; then
            printf "\\n"
        fi
        printf "%b %bERROR: Unable to look up system variables - 'df' command not found%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        purge_dgnt_settings
        exit 1
    fi

    # Store total system RAM as variables
    RAMTOTAL_KB=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
    RAMTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)

    # Store current total swap file size as variables
    SWAPTOTAL_KB=$(cat /proc/meminfo | grep SwapTotal: | tr -s ' ' | cut -d' ' -f2)
    SWAPTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f2)

    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b   Total RAM: ${RAMTOTAL_HR}b ( KB: ${RAMTOTAL_KB} )\\n" "${INDENT}"
        if [ "$SWAPTOTAL_HR" = "0B" ]; then
            printf "%b   Total SWAP: none\\n" "${INDENT}"
        else
            printf "%b   Total SWAP: ${SWAPTOTAL_HR}b ( KB: ${SWAPTOTAL_KB} )\\n" "${INDENT}"
        fi
    fi

    BOOT_DISKTOTAL_HR=$(df . -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKTOTAL_KB=$(df . --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    DGB_DATA_DISKTOTAL_HR=$(df $DGB_DATA_LOCATION -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    DGB_DATA_DISKTOTAL_KB=$(df $DGB_DATA_LOCATION --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')

    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b   Total Disk Space: ${BOOT_DISKTOTAL_HR}b ( KB: ${BOOT_DISKTOTAL_KB} )\\n" "${INDENT}"
    fi

 #   # No need to update the disk usage variables if running the status monitor, as it does it itself
 #   if [[ "$RUN_SETUP" != "NO" ]] ; then

        # Get internal IP address
        IP4_INTERNAL=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
        if [ -f "$DGNT_SETTINGS_FILE" ]; then
            sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"$IP4_INTERNAL\"|" $DGNT_SETTINGS_FILE
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

# If the .digibyte folder and diginode.settings file have just been created, and we exit with an error at startup, delete them
purge_dgnt_settings() {

if [ "$IS_DGNT_SETTINGS_FILE_NEW" = "YES" ]; then

    # Delete diginode.settings file
    printf "%b %bPurging installation file...%b\\n" "${INFO}"
    if [ -f "$DGNT_SETTINGS_FILE" ]; then
        str="Deleting diginode.settings file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
fi

if [ "$IS_DIGIBYTE_SETTINGS_FOLDER_NEW" = "YES" ]; then

    # Delete ~/.digibyte folder
    if [ -d "$DGNT_SETTINGS_LOCATION" ]; then
        str="Deleting ~/digibyte folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r $DGNT_SETTINGS_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
fi

if [ "$IS_DGNT_SETTINGS_FILE_NEW" = "YES" ] || [ "$IS_DIGIBYTE_SETTINGS_FOLDER_NEW" = "YES" ]; then
    printf "\\n"
fi

}

# Lookup disk usage, and store in diginode.settings if present
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

        # Get clean percentage (no percentage symbol)
        DGB_DATA_DISKUSED_PERC_CLEAN=$(echo -e " \t $DGB_DATA_DISKUSED_PERC \t " | cut -d'%' -f1)

        # Update diginode.settings file it it exists
        if [ -f "$DGNT_SETTINGS_FILE" ]; then
            sed -i -e "/^BOOT_DISKUSED_HR=/s|.*|BOOT_DISKUSED_HR=\"$BOOT_DISKUSED_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKUSED_KB=/s|.*|BOOT_DISKUSED_KB=\"$BOOT_DISKUSED_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKUSED_PERC=/s|.*|BOOT_DISKUSED_PERC=\"$BOOT_DISKUSED_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKFREE_HR=/s|.*|BOOT_DISKFREE_HR=\"$BOOT_DISKFREE_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKFREE_KB=/s|.*|BOOT_DISKFREE_KB=\"$BOOT_DISKFREE_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_HR=/s|.*|DGB_DATA_DISKUSED_HR=\"$DGB_DATA_DISKUSED_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_KB=/s|.*|DGB_DATA_DISKUSED_KB=\"$DGB_DATA_DISKUSED_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_PERC=/s|.*|DGB_DATA_DISKUSED_PERC=\"$DGB_DATA_DISKUSED_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKFREE_HR=/s|.*|DGB_DATA_DISKFREE_HR=\"$DGB_DATA_DISKFREE_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKFREE_KB=/s|.*|DGB_DATA_DISKFREE_KB=\"$DGB_DATA_DISKFREE_KB\"|" $DGNT_SETTINGS_FILE
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
        printf "%b DigiByte daemon will be stopped.\\n" "${INFO}"
        stop_service digibyted
        DGB_STATUS="stopped"
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
        if [ "$RAMTOTAL_KB" -ge "7340032" ]; then
            str="System RAM exceeds 7GB. Setting dbcache to 1Gb..."
            printf "%b %s" "${INFO}" "${str}"
            set_dbcache=1024
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

        # Set the default rpcport
        local set_rpcport
        if [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then
            set_rpcport=14023
        elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then
            set_rpcport=14022
        fi

    # If the digibyte.conf file already exists
    elif [ -f "$DGB_CONF_FILE" ]; then

        # Import variables from digibyte.conf settings file
        str="Located digibyte.conf file. Importing..."
        printf "%b %s" "${INFO}" "${str}"
        source $DGB_CONF_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    fi

    # Set the upnp values, if we are enabling/disabling the UPnP status
    if [ "$DGB_ENABLE_UPNP" = "YES" ]; then
        upnp=1
    elif [ "$DGB_ENABLE_UPNP" = "NO" ]; then
        upnp=0
    fi

    # Set the dgb network values, if we are changing between testnet and mainnet
    if [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then
        testnet=1
    elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then
        testnet=0
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

        #Update rpcport variable in settings if it exists and is blank, otherwise append it. 
        #The default rpcport varies depending on if we are running mainnet or testnet.
        if grep -q "rpcport=" $DGB_CONF_FILE; then
            if grep -q "testnet=1" $DGB_CONF_FILE; then
                if [ "$rpcport" = "" ]; then
                    echo "$INDENT   Updating digibyte.conf: rpcport=14023"
                    sed -i -e "/^rpcport=/s|.*|rpcport=14023|" $DGB_CONF_FILE
                fi
            else
                if [ "$rpcport" = "" ]; then
                    echo "$INDENT   Updating digibyte.conf: rpcport=14022"
                    sed -i -e "/^rpcport=/s|.*|rpcport=14022|" $DGB_CONF_FILE
                fi
            fi
        else
            if grep -q "testnet=1" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: rpcport=14023"
                echo "rpcport=14023" >> $DGB_CONF_FILE
            else
                echo "$INDENT   Updating digibyte.conf: rpcport=14022"
                echo "rpcport=14022" >> $DGB_CONF_FILE
            fi
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

        # Change upnp status from enabled to disabled
        if grep -q "upnp=1" $DGB_CONF_FILE; then
            if [ "$upnp" = "0" ]; then
                echo "$INDENT   UPnP will be disabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        fi

        # Change upnp status from disabled to enabled
        if grep -q "upnp=0" $DGB_CONF_FILE; then
            if [ "$upnp" = "1" ]; then
                echo "$INDENT   UPnP will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        fi

        # Update upnp status in settings if it exists and is blank, otherwise append it
        if grep -q "upnp=" $DGB_CONF_FILE; then
            if [ "$upnp" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
            echo "upnp=$upnp" >> $DGB_CONF_FILE
        fi

        # Change dgb network from TESTNET to MAINNET
        if grep -q "testnet=1" $DGB_CONF_FILE; then
            if [ "$testnet" = "0" ]; then
                echo "$INDENT   Changing DigiByte Core network from TESTNET to MAINNET"
                echo "$INDENT   Updating digibyte.conf: testnet=$testnet"
                sed -i -e "/^testnet=/s|.*|testnet=$testnet|" $DGB_CONF_FILE
                DGB_NETWORK_IS_CHANGED="YES"
                # Change rpcport to mainnet default, if it is using testnet default
                if grep -q "rpcport=14023" $DGB_CONF_FILE; then
                    echo "$INDENT   Updating digibyte.conf: rpcport=14022"
                    sed -i -e "/^rpcport=/s|.*|rpcport=14022|" $DGB_CONF_FILE
                fi
                # Change listening port to mainnet default, if it is using testnet default
                if grep -q "port=12026" $DGB_CONF_FILE; then
                    echo "$INDENT   Updating digibyte.conf: port=12024"
                    sed -i -e "/^port=/s|.*|port=12024|" $DGB_CONF_FILE
                fi
            fi
        fi

        # Change dgb network from MAINNET to TESTNET
        if grep -q "testnet=0" $DGB_CONF_FILE; then
            if [ "$testnet" = "1" ]; then
                echo "$INDENT   Changing DigiByte Core network from MAINNET to TESTNET"
                echo "$INDENT   Updating digibyte.conf: testnet=$testnet"
                sed -i -e "/^testnet=/s|.*|testnet=$testnet|" $DGB_CONF_FILE
                DGB_NETWORK_IS_CHANGED="YES"
                # Change rpcport to testnet default, if it is using mainnet default
                if grep -q "rpcport=14022" $DGB_CONF_FILE; then
                    echo "$INDENT   Updating digibyte.conf: rpcport=14023"
                    sed -i -e "/^rpcport=/s|.*|rpcport=14023|" $DGB_CONF_FILE
                fi
                # Change listening port to testnet default, if it is using mainnet default
                if grep -q "port=12024" $DGB_CONF_FILE; then
                    echo "$INDENT   Updating digibyte.conf: port=12026"
                    sed -i -e "/^port=/s|.*|port=12026|" $DGB_CONF_FILE
                fi
            fi
        fi

        # Update dgb network in settings if it exists and is blank, otherwise append it
        if grep -q "testnet=" $DGB_CONF_FILE; then
            if [ "$testnet" = "" ]; then
                echo "$INDENT   Updating digibyte.conf: testnet=$testnet"
                sed -i -e "/^testnet=/s|.*|testnet=$testnet|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Updating digibyte.conf: testnet=$testnet"
            echo "testnet=$testnet" >> $DGB_CONF_FILE
        fi

        # Re-import variables from digibyte.conf in case they have changed
        str="Reimporting digibyte.conf values, as they may have changed..."
        printf "%b %s" "${INFO}" "${str}"
        source $DGB_CONF_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        printf "%b Completed digibyte.conf checks.\\n" "${TICK}"


    else

        # Create a new digibyte.conf file
        str="Creating ~/.diginode/digibyte.conf file..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_CONF_FILE
        cat <<EOF > $DGB_CONF_FILE
# This config should be placed in the following path:
# ~/.digibyte/digibyte.conf

# This template is based on the Bitcoin Core Config Generator by Jameson Lopp
# https://jlopp.github.io/bitcoin-core-config-generator/

# [chain]
# Run this node on the DigiByte Test Network. Equivalent to -chain=test. (Default: 0 = DigiByte testnet is disabled and mainnet is used)
testnet=$testnet

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

# Use UPnP to map the listening port.
upnp=$upnp

# Listen for incoming connections on non-default port. Mainnet default is 12024. Testnet default is 12026.
# Setting the port number here will override the default mainnet or testnet port numbers.
# port=12024


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

# Listen for JSON-RPC connections on this port. Mainnet default is 14022. Testnet default is 14023.
rpcport=$set_rpcport

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


# A simple function that just displays the title in a box
setup_title_box() {
     clear -x
     echo " ╔═════════════════════════════════════════════════════════╗"
     echo " ║                                                         ║"
     echo " ║             ${txtbld}D I G I N O D E   S E T U P${txtrst}                 ║"
     echo " ║                                                         ║"
     echo " ║     Setup and manage your DigiByte & DigiAsset Node     ║"
     echo " ║                                                         ║"
     echo " ╚═════════════════════════════════════════════════════════╝" 
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
        printf "%b DigiNode Setup requires a Linux OS with a a 64-bit kernel (aarch64 or X86_64)\\n" "${INDENT}"
        printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
        printf "%b should be supported please contact @digibytehelp on Twitter including\\n" "${INDENT}"
        printf "%b the OS type: $OSTYPE\\n" "${INDENT}"
        printf "\\n"
        purge_dgnt_settings
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
            printf "\\n" 
        fi


        if [[ "$is_64bit" == "no32" ]]; then
            printf "%b %bERROR: 32-bit OS detected - 64-bit required%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b DigiNode Setup requires a 64-bit Linux OS (aarch64 or X86_64)\\n" "${INDENT}"
            printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
            printf "%b should be supported please contact @digibytehelp on Twitter letting me\\n" "${INDENT}"
            printf "%b know the reported system architecture above.\\n" "${INDENT}"
            printf "\\n"
            purge_dgnt_settings
            exit 1
        elif [[ "$is_64bit" == "no" ]]; then
            printf "%b %bERROR: Unrecognised system architecture%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b DigiNode Setup requires a 64-bit OS (aarch64 or X86_64)\\n" "${INDENT}"
            printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
            printf "%b should be supported please contact @digibytehelp on Twitter letting me\\n" "${INDENT}"
            printf "%b know the reported system architecture above.\\n" "${INDENT}"
            printf "\\n"
            purge_dgnt_settings
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
        elif [ $revision = '902120' ]; then #Pi Zero 2 W
            pitype="piold"
            MODELMEM="1Gb"
        elif [ $revision = 'c03130' ]; then #Pi 400 4Gb
            pitype="pi4"
            MODELMEM="4Gb"
        elif [ $revision = 'c03114' ]; then #Pi 4 4Gb
            pitype="pi4"
            MODELMEM="4Gb"
        elif [ $revision = 'c03112' ]; then #Pi 4 4Gb
            pitype="pi4"
            MODELMEM="4Gb"
        elif [ $revision = 'c03111' ]; then #Pi 4 4Gb
            pitype="pi4"
            MODELMEM="4Gb"
        elif [ $revision = 'b03114' ]; then #Pi 4 2Gb
            pitype="pi4_lowmem"
            MODELMEM="2Gb"
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
        if [[ "$RUN_SETUP" != "NO" ]] ; then
            printf "\\n"
            rpi_microsd_check
        fi
        printf "\\n"
    elif [ "$pitype" = "pi4" ]; then
        printf "%b Raspberry Pi 4 Detected\\n" "${TICK}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        if [[ "$RUN_SETUP" != "NO" ]] ; then
            printf "\\n"
            rpi_microsd_check
        fi
        printf "\\n"
    elif [ "$pitype" = "pi4_lowmem" ]; then
        printf "%b Raspberry Pi 4 Detected   [ %bLOW MEMORY DEVICE!!%b ]\\n" "${TICK}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        # hide this part if running digimon
        if [[ "$RUN_SETUP" != "NO" ]] ; then
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
        if [[ "$RUN_SETUP" != "NO" ]] ; then
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
        purge_dgnt_settings
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
        purge_dgnt_settings
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
    if [[ "$RUN_SETUP" != "NO" ]] ; then

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
            if [[ "$MODELMEM" = "1Gb" ]] || [[ "$MODELMEM" = "2Gb" ]]; then
                printf "%b%b %s %bFAILED%b   Raspberry Pi is booting from a microSD card\\n" "${OVER}" "${CROSS}" "${str}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bERROR: Booting from microSD with less than 4Gb of RAM is not supported.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b Since your Raspberry Pi only has $MODELMEM of RAM, you need to be booting\\n" "${INDENT}"
                printf "%b from an SSD drive. Running a DigiNode requires at least 6Gb RAM, and a microSD\\n" "${INDENT}"
                printf "%b card is too slow to run both the DigiNode software and swap file together.\\n" "${INDENT}"
                printf "%b Please use an external SSD drive connected via USB. For advice on the\\n" "${INDENT}"
                printf "%b recommended DigiNode hardware, visit:\\n" "${INDENT}"
                printf "%b   $DGBH_URL_HARDWARE\\n" "${INDENT}"
                printf "\\n"
                purge_dgnt_settings
                exit 1

            elif [[ "$MODELMEM" = "4Gb" ]]; then
                printf "%b%b %s %bFAILED%b   Raspberry Pi is booting from a microSD card\\n" "${OVER}" "${CROSS}" "${str}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bWARNING: Running a DigiNode from a microSD card is not recommended.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b Running a DigiNode requires at least 6Gb RAM, and a microSD is typically too\\n" "${INDENT}"
                printf "%b slow to run both the DigiNode software and swap file. Since your Raspberry Pi\\n" "${INDENT}"
                printf "%b only has $MODELMEM RAM, if you want want to proceed you will need a USB stick\\n" "${INDENT}"
                printf "%b to store the swap file. 8Gb or 16Gb is sufficient and it should support USB 3.0\\n" "${INDENT}"
                printf "%b or better. An SSD is still recomended, so proceed at you own risk.\\n" "${INDENT}"
                printf "\\n"
                IS_MICROSD="YES"
                REQUIRE_USB_STICK_FOR_SWAP="YES"
            else
                printf "%b%b %s %bFAILED%b   Raspberry Pi is booting from a microSD card\\n" "${OVER}" "${CROSS}" "${str}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bWARNING: Running a DigiNode from a microSD card is not recommended%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
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
if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]] && [[ "$REQUIRE_USB_STICK_FOR_SWAP" = "YES" ]]; then

    if whiptail --backtitle "" --title "Raspberry Pi is booting from microSD" --yesno "WARNING: You are currently booting your Raspberry Pi from a microSD card.\\n\\nIt is strongly recommended to use a Solid State Drive (SSD) connected via USB for your DigiNode. MicroSD cards are prone to corruption and perform significantly slower than an SSD or HDD. For advice on reccomended DigiNode hardware, visit:\\n$DGBH_URL_HARDWARE\\n\\nSince your Raspberry Pi only has $MODELMEM RAM, if you want to proceed, you will need an empty USB stick to store the swap file. An 8Gb stick is sufficient, but 16Gb or larger is better. An SSD is still recommended, so proceed at you own risk.\n\\n\\nChoose Yes to indicate that you have understood this message, and wish to continue." --defaultno "${r}" "${c}"; then

    #Nothing to do, continue
      printf "%b Raspberry Pi Warning: You accepted the risks of running a DigiNode from a microSD.\\n" "${INFO}"
      printf "%b You agreed to use a USB stick for your swap file, despite the risks.\\n" "${INFO}"
    else
      printf "%b DigiNode Setup exited at microSD warning message.\\n" "${INFO}"
      printf "\\n"
      exit
    fi

elif [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]]; then

    if whiptail --backtitle "" --title "Raspberry Pi is booting from microSD" --yesno "WARNING: You are currently booting your Raspberry Pi from a microSD card.\\n\\nIt is strongly recommended to use a Solid State Drive (SSD) connected via USB for your DigiNode. A conventional Hard Disk Drive (HDD) will also work, but an SSD is preferred, being faster and more robust.\\n\\nMicroSD cards are prone to corruption and perform significantly slower than an SSD or HDD.\\n\\nFor advice on what hardware to get for your DigiNode, visit:\\n$DGBH_URL_HARDWARE\\n\\n\\n\\nChoose Yes to indicate that you have understood this message, and wish to continue installing on the microSD card." --defaultno "${r}" "${c}"; then
    #Nothing to do, continue
      printf "%b Raspberry Pi Warning: You accepted the risks of running a DigiNode from a microSD.\\n" "${INFO}"
    else
      printf "%b DigiNode Setup exited at microSD warning message.\\n" "${INFO}"
      printf "\\n"
      exit
    fi
fi

}

# If the user is using a Raspberry Pi, but not booting from microSD, then tell the user they can remove it
rpi_microsd_remove() {

# If they are booting their Pi from SSD, warn to unplug the microSD card, if present (just to double check!)
if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "NO" ]] ; then
        
        whiptail --msgbox --backtitle "" --title "Remove microSD card from the Raspberry Pi." "If there is a microSD card in the slot on the Raspberry Pi, you can remove it. It will not be required." 9 "${c}"
fi

}

# Compatibility
package_manager_detect() {

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
    SYS_CHECK_DEPS=(grep dnsutils jq)
    # Packages required to run this setup script (stored as an array)
    SETUP_DEPS=(git "${iproute_pkg}" whiptail bc)
    # Packages required to run DigiNode (stored as an array)
    DIGINODE_DEPS=(cron curl iputils-ping psmisc sudo tmux)

 # bak - DIGINODE_DEPS=(cron curl iputils-ping lsof netcat psmisc sudo unzip idn2 sqlite3 libcap2-bin dns-root-data libcap2 "${avahi_package}")

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
    SETUP_DEPS=(git iproute procps-ng which chkconfig jq)
    DIGINODE_DEPS=(cronie curl findutils sudo psmisc tmux)

# If neither apt-get or yum/dnf package managers were found
else
    # it's not an OS we can support,
    printf "%b OS distribution not supported\\n" "${CROSS}"
    # so exit DigiNode Setup
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
            system_updates_available="yes"
        fi
    else
        printf "%b %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        printf "    Kernel update detected. If the install fails, please reboot and try again\\n"
    fi
}

update_package_cache() {

    # Skip this if the --skipupdatepkgcache flag is used
    if [ "$SKIP_PKG_UPDATE_CHECK" != true ]; then

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
            printf "\\n"
            printf "%b You can skip the package update check using the --skipupdatepkgcache flag.\\n" "${INDENT}"
            printf "\\n"
            return 1
        fi

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
    if [ "$SKIP_OS_CHECK" != true ]; then
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
                printf "%b  - Google DNS (8.8.8.8) being blocked\\n" "${INDENT}" 
                printf "%b    (Required to obtain TXT record from ${DGNT_VERSIONS_URL} containing supported OS)\\n" "${INDENT}" 
                printf "%b  - Other internet connectivity issues\\n" "${INDENT}"
            else
                printf "%b %bUnsupported OS detected: %s %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${detected_os^}" "${detected_version}" "${COL_NC}"
                printf "%b If you are seeing this message and you believe your OS should be supported\\n" "${INDENT}" 
                printf "%b please contact @digibytehelp on Twitter or ask in the DigiNode Tools Telegram group.\\n" "${INDENT}" 
            fi
            printf "\\n"
            printf "%b %bhttps://digibyte.help/diginode%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b If you wish to attempt to continue anyway, you can try one of the\\n" "${INDENT}" 
            printf "%b following commands to skip this check:\\n" "${INDENT}" 
            printf "\\n"
            printf "%b e.g: If you are seeing this message on a fresh install, you can run:\\n" "${INDENT}" 
            printf "%b   %bcurl -sSL $DGNT_SETUP_OFFICIAL_URL | bash -s -- --skiposcheck%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b It is possible that the installation will still fail at this stage\\n" "${INDENT}" 
            printf "%b due to an unsupported configuration.\\n" "${INDENT}" 
            printf "%b %bIf that is the case, feel free to ask @digibytehelp on Twitter.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            exit 1

        else
            printf "%b %bSupported OS detected: %s %s%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${detected_os^}" "${detected_version}" "${COL_NC}"
            echo ""
        fi
    else
        printf "%b %b--skiposcheck flag detected - OS Check was skipped.%b\\n\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    fi
}

# SELinuxswap
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
    # Exit DigiNode Setup if any SELinux checks toggled the flag
    if [[ "${SELINUX_ENFORCING}" -eq 1 ]] && [[ -z "${DIGINODE_SELINUX}" ]]; then
        printf "%b DigiNode does not provide an SELinux policy as the required changes modify the security of your system.\\n" "${INDENT}" 
        printf "%b Please refer to https://wiki.centos.org/HowTos/SELinux if SELinux is required for your deployment.\\n" "${INDENT}" 
        printf "%b  This check can be skipped by setting the environment variable %bDIGINODE_SELINUX%b to %btrue%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b  e.g: export DIGINODE_SELINUX=true\\n" "${INDENT}" 
        printf "%b  By setting this variable to true you acknowledge there may be issues with DigiNode during or after the install\\n" "${INDENT}" 
        printf "\\n%b  %bSELinux Enforcing detected, exiting DigiNode Setup%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}";
        printf "\\n"
        purge_dgnt_settings
        exit 1;
    elif [[ "${SELINUX_ENFORCING}" -eq 1 ]] && [[ -n "${DIGINODE_SELINUX}" ]]; then
        printf "%b %bSELinux Enforcing detected%b. DIGINODE_SELINUX env variable set - DigiNode Setup will continue\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
    fi
}

# Function to check if the hostname of the machine is set to 'diginode'
hostname_check() {

    printf " =============== Checking: Hostname ====================================\\n\\n"
    # ==============================================================================


if [[ "$HOSTNAME" == "diginode" ]] && [[ "$DGB_NETWORK_IS_CHANGED" != "YES" ]] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then

    printf "%b Hostname Check: %bPASSED%b   Hostname is set to: $HOSTNAME\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    INSTALL_AVAHI="YES"
    HOSTNAME_DO_CHANGE="NO"

elif [[ "$HOSTNAME" == "diginode-testnet" ]] && [[ "$DGB_NETWORK_IS_CHANGED" != "YES" ]] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then

    printf "%b Hostname Check: %bPASSED%b   Hostname is set to: $HOSTNAME\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    INSTALL_AVAHI="YES"
    HOSTNAME_DO_CHANGE="NO"

elif [[ "$HOSTNAME" == "diginode" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then
 
    printf "%b %bYou DigiByte Node has successfully been changed from MAINNET to TESTNET%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b Important: It is recommend that you change your hostname to 'diginode-testnet'\\n"  "${INFO}"
    printf "%b Your hostname is currently '$HOSTNAME'. Since you have just switched to\\n"  "${INDENT}"
    printf "%b to running a DigiByte testnet node it is advisable to change the hostname\\n"  "${INDENT}"
    printf "%b to 'diginode-testnet'. This is optional but recommended, since it will ensure\\n"  "${INDENT}"
    printf "%b the current hostname does not conflict with another DigiByte mainnet node on\\n"  "${INDENT}"
    printf "%b your network. If you are planning to run two DigiNodes on your network,\\n"  "${INDENT}"
    printf "%b one on DigiByte MAINNET and the other on TESTNET, it is advisable to give\\n"  "${INDENT}"
    printf "%b them diferent hostnames on your network so they are easier to identify.\\n"  "${INDENT}"
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

elif [[ "$HOSTNAME" == "diginode-testnet" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then
 
    printf "%b %bYou DigiByte Node has successfully been changed from TESTNET to MAINNET%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b Important: It is recommend that you change your hostname to 'diginode-testnet'\\n"  "${INFO}"
    printf "%b Your hostname is currently '$HOSTNAME'. Since you have just switched to\\n"  "${INDENT}"
    printf "%b running a DigiByte mainnet node, it is advisable to change the hostname\\n"  "${INDENT}"
    printf "%b to 'diginode' . This is optional but recommended, since it will ensure\\n"  "${INDENT}"
    printf "%b the current hostname does not conflict with another DigiByte testnet node on\\n"  "${INDENT}"
    printf "%b your network. If you are planning to run two DigiNodes on your network, one on\\n"  "${INDENT}"
    printf "%b DigiByte MAINNET and the other on TESTNET, it is advisable to give them diferent\\n"  "${INDENT}"
    printf "%b hostnames on your network so they are easier to identify.\\n"  "${INDENT}"
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

elif [[ "$HOSTNAME" == "" ]]; then
    printf "%b Hostname Check: %bERROR%b   Unable to check hostname\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b DigiNode Setup currently assumes it will always be able to discover the\\n" "${INDENT}"
    printf "%b current hostname. It is therefore assumed that noone will ever see this error message!\\n" "${INDENT}"
    printf "%b If you have, please contact @digibytehelp on Twitter and let me know so I can work on\\n" "${INDENT}"
    printf "%b a workaround for your linux system.\\n" "${INDENT}"
    printf "\\n"
    exit 1

elif [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then
    printf "%b Hostname Check: %bFAILED%b   Recommend changing Hostname to 'diginode-testnet'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b Your hostname is currently '$HOSTNAME'. It is advisable to change this to 'diginode-testnet'.\\n"  "${INDENT}"
    printf "%b This is optional but recommended, since it will make the DigiAssets website available at\\n"  "${INDENT}"
    printf "%b https://diginode-testnet.local which is obviously easier than remembering an IP address.\\n"  "${INDENT}"
    printf "%b If you are planning to run two DigiNodes on your network, one on the DigiByte MAINNET\\n"  "${INDENT}"
    printf "%b and the other on TESTNET, it is advisable to give them different hostnames on your\\n"  "${INDENT}"
    printf "%b network so they are easier to identify and do not conflict with one another.\\n"  "${INDENT}"
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

elif [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then
    printf "%b Hostname Check: %bFAILED%b   Hostname is not set to 'diginode'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b Your hostname is currently '$HOSTNAME'. It is advisable to change this to 'diginode'.\\n"  "${INDENT}"
    printf "%b This is optional but recommended, since it will make the DigiAssets website available at\\n"  "${INDENT}"
    printf "%b https://diginode.local which is obviously easier than remembering an IP address.\\n"  "${INDENT}"
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"
fi

}

# Display a request to change the hostname, if needed
hostname_ask_change() {

if [ ! "$UNATTENDED_MODE" == true ]; then

    if [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" == "diginode" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then

        if whiptail  --backtitle "" --title "Changing your hostname to 'diginode-testnet' is recommended." --yesno "\\nYour hostname is currently '$HOSTNAME'.\\n\\nWould you like to change your hostname to 'diginode-testnet'?\\n\\n If you are running your DigiNode on a dedicated computer on your local network, then this change is recommended. It will ensure that the hostname reflects that device is running a DigiByte testnet node. It will also make it easier to identify, should you setup another DigiNode on your network.\\n\\nIf you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you likely do not want to do this."  --yes-button "Yes" "${r}" "${c}"; then

            HOSTNAME_DO_CHANGE="YES"
            HOSTNAME_CHANGE_TO="diginode-testnet"
            INSTALL_AVAHI="YES"

            printf "%b You chose to change your hostname to: diginode-testnet\\n" "${INFO}"
            printf "\\n"
        else
            printf "%b You chose not to change your hostname to: diginode-testnet (it will remain as diginode).\\n" "${INFO}"
            printf "\\n"
        fi

    elif [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" == "diginode-testnet" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then

        if whiptail  --backtitle "" --title "Changing your hostname to 'diginode' is recommended." --yesno "\\nYour hostname is currently '$HOSTNAME'.\\n\\nWould you like to change your hostname to 'diginode'?\\n\\nIf you are running your DigiNode on a dedicated computer on your local network, then this change is recommended. It will ensure that the hostname reflects that the device is no longer running a DigiByte testnet node. It will also make it easier to identify, should you setup another DigiNode on your network.\\n\\nIf you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you likely do not want to do this."  --yes-button "Yes" "${r}" "${c}"; then

            HOSTNAME_DO_CHANGE="YES"
            HOSTNAME_CHANGE_TO="diginode"
            INSTALL_AVAHI="YES"

            printf "%b You chose to change your hostname to: diginode\\n" "${INFO}"
            printf "\\n"
        else
            printf "%b You chose not to change your hostname to: diginode (it will remain as diginode-testnet).\\n" "${INFO}"
            printf "\\n"
        fi


    elif [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then

        if whiptail  --backtitle "" --title "Changing your hostname to 'diginode-test' is recommended." --yesno "\\nYour hostname is currently '$HOSTNAME'.\\n\\nWould you like to change your hostname to 'diginode-testnet'?\\n\\nIf you running your DigiNode on a dedicated device on your local network, then this is recommended, since it will make the DigiAssets website available at http://diginode-testnet.local:8090 which is obviously easier than remembering an IP address.\\n\\nIf you are planning to run two DigiNodes on your network, one on the DigiByte MAINNET, and the other on TESTNET, it is advisable to give them different hostnames on your network so they are easier to identify and do not conflict with one another.\\n\\nIf you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you likely do not want to change its hostname."  --yes-button "Yes" "${r}" "${c}"; then

            HOSTNAME_DO_CHANGE="YES"
            HOSTNAME_CHANGE_TO="diginode-testnet"
            INSTALL_AVAHI="YES"

            printf "%b You chose to change your hostname to: diginode-testnet\\n" "${INFO}"
            printf "\\n"
        else
            printf "%b You chose not to change your hostname to: diginode-testnet.\\n" "${INFO}"
            printf "\\n"
        fi

    elif [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then

        if whiptail  --backtitle "" --title "Changing your hostname to 'diginode' is recommended." --yesno "\\nYour hostname is currently '$HOSTNAME'.\\n\\nWould you like to change your hostname to 'diginode'?\\n\\nIf you running your DigiNode on a dedicated device on your local network, then this is recommended, since it will make the DigiAssets website available at http://diginode.local:8090 which is obviously easier than remembering an IP address.\\n\\nIf you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you likely do not want to change its hostname."  --yes-button "Yes" "${r}" "${c}"; then

          HOSTNAME_DO_CHANGE="YES"
          HOSTNAME_CHANGE_TO="diginode"
          INSTALL_AVAHI="YES"

          printf "%b You chose to change your hostname to: digibyte.\\n" "${INFO}"
          printf "\\n"
        else
          printf "%b You chose not to change your hostname to: digibyte.\\n" "${INFO}"
          printf "\\n"
        fi

    fi
fi

}

# Function to change the hostname of the machine to 'diginode'
hostname_do_change() {

# Does avahi daemon need to be installed? (this only gets installed if the hostname is set to 'diginode')
if [ "$INSTALL_AVAHI" = "YES" ]; then
    install_dependent_packages avahi-daemon
fi

# If running unattended, and the flag to change the hostname in diginode.settings is set to yes, then go ahead with the change.

if [[ "$NewInstall" = true ]] && [[ "$UNATTENDED_MODE" == true ]] && [[ "$UI_HOSTNAME_SET" = "YES" ]] && [ "$UI_DGB_NETWORK" = "MAINNET" ] && [[ "$HOSTNAME" != "digibyte" ]]; then

        HOSTNAME_DO_CHANGE="YES"

elif [[ "$NewInstall" = true ]] && [[ "$UNATTENDED_MODE" == true ]] && [[ "$UI_HOSTNAME_SET" = "YES" ]] && [ "$UI_DGB_NETWORK" = "TESTNET" ] && [[ "$HOSTNAME" != "digibyte-testnet" ]]; then

        HOSTNAME_DO_CHANGE="YES"

fi


# Only change the hostname if the user has agreed to do so (either via prompt or via UI setting)
if [[ "$HOSTNAME_DO_CHANGE" = "YES" ]]; then

    # if the current hostname if not the hostname we want to change to then go ahead and change it
    if [[ ! "$HOSTNAME" == "$HOSTNAME_CHANGE_TO" ]]; then

        # Save current and new hostnames to a variable
        CUR_HOSTNAME=$HOSTNAME
        NEW_HOSTNAME=$HOSTNAME_CHANGE_TO
        str="Changing Hostname from '$CUR_HOSTNAME' to '$NEW_HOSTNAME'..."
        printf "%b %s" "${INFO}" "${str}"

        # Change hostname in /etc/hosts file
        sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts

        # Change hostname using hostnamectl
        if is_command hostnamectl ; then
            sudo hostnamectl set-hostname $NEW_HOSTNAME 2>/dev/null
            printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "\\n%b %bUnable to change hostname using hostnamectl (command not present). Trying manual method...%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            hostname $NEW_HOSTNAME 2>/dev/null
            sudo sed -i "s/$CUR_HOSTNAME/$NEW_HOSTNAME/g" /etc/hostname 2>/dev/null
        fi

    fi
fi

}

# Function to check if the user account 'digibyte' is currently in use, and if it is not, check if it already exists
user_check() {

    # Only do this check if DigiByte Core is not currently installed
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

        printf " =============== Checking: User Account ================================\\n\\n"
        # ==============================================================================

        if [[ "$USER_ACCOUNT" == "digibyte" ]]; then
            printf "%b User Account Check: %bPASSED%b   Current user is 'digibyte'\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
        else
            # If we doing an unattended install, and the setting filee forces using user 'digibyte', then
            if id "digibyte" &>/dev/null; then
                printf "%b User Account Check: %bFAILED%b   Current user is NOT 'digibyte'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b %bWARNING: You are NOT currently logged in as user 'digibyte'%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b A 'digibyte' user account already exists, but you are currently logged in as '$USER_ACCOUNT'.\\n"  "${INDENT}"
                printf "%b It is advisable to use the 'digibyte' account for your DigiNode. This is optional but recommended, since it\\n"  "${INDENT}"
                printf "%b will isolate your DigiByte wallet in its own user account.  For more information visit:\\n"  "${INDENT}"
                printf "%b  $DGBH_URL_USERCHANGE\\n"  "${INDENT}"
                printf "\\n"
                if [[ "$UNATTENDED_MODE" == true ]] && [ $UI_ENFORCE_DIGIBYTE_USER = "YES" ]; then
                    USER_DO_SWITCH="YES"
                    printf "%b %bUnattended Mode: Unable to continue - user is not 'digibyte' and requirement is enforced in diginode.settings%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                    printf "\\n"
                    purge_dgnt_settings
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
                printf "%b %bWARNING: You are NOT currently logged in as user 'digibyte'.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "%b It is advisable to create a new 'digibyte' user account for your DigiNode.\\n"  "${INDENT}"
                printf "%b This is optional but recommended, since it will isolate your DigiByte wallet\\n"  "${INDENT}"
                printf "%b its own user account. For more information visit:\\n"  "${INDENT}"
                printf "%b  $DGBH_URL_USERCHANGE\\n"  "${INDENT}"
                printf "\\n"
                 if [[ "$UNATTENDED_MODE" == true ]] && [ $UI_ENFORCE_DIGIBYTE_USER = "YES" ]; then
                    printf "%b %bUnattended Mode: Unable to continue - user is not 'digibyte' and requirement is enforced in diginode.settings%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
                    printf "\\n"
                    purge_dgnt_settings
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

      if whiptail  --backtitle "" --title "Installing as user 'digibyte' is recommended." --yesno "It is recommended that you login as 'digibyte' before installing your DigiNode.\\n\\nThis is optional but encouraged, since it will isolate your DigiByte wallet its own user account.\\n\\nFor more information visit:\\n  $DGBH_URL_USERCHANGE\\n\\n\\nThere is already a 'digibyte' user account on this machine, but you are not currently using it - you are signed in as '$USER_ACCOUNT'. Would you like to switch users now?\\n\\nChoose YES to exit and login as 'digibyte' from where you can run DigiNode Setup again.\\n\\nChoose NO to continue installation as '$USER_ACCOUNT'."  --yes-button "Yes (Recommended)" --no-button "No" "${r}" "${c}"; then

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

      if whiptail  --backtitle "" --title "Creating a new 'digibyte' user is recommended." --yesno "It is recommended that you create a new 'digibyte' user for your DigiNode.\\n\\nThis is optional but encouraged, since it will isolate your DigiByte wallet in its own user account.\\n\\nFor more information visit:\\n$DGBH_URL_USERCHANGE\\n\\n\\nYou are currently signed in as user '$USER_ACCOUNT'. Would you like to create a new 'digibyte' user now?\\n\\nChoose YES to create and sign in to the new user account, from where you can run DigiNode Setup again.\\n\\nChoose NO to continue installation as '$USER_ACCOUNT'."  --yes-button "Yes (Recommended)" --no-button "No" "${r}" "${c}"; then

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

    # Delete the settings file that was just created
    purge_dgnt_settings

    printf "%b Please sign as user 'digibyte' by entering:\\n" "${INFO}"
    printf "\\n"
    printf "%b   ${txtbld}su - digibyte${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b Then switch to your the home directory:\\n" "${INDENT}"
    printf "\\n"
    printf "%b   ${txtbld}cd${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b And then run DigiNode Setup again.\\n" "${INDENT}"
    printf "\\n"
    exit
fi


if [ "$USER_DO_CREATE" = "YES" ]; then

    # Don't do this again if we need to re-enter the password
    if [ "$skip_if_reentering_password" != "yes" ]; then

        # Delete the settings file that was just created
        purge_dgnt_settings

        printf "%b User Account: Creating user account: 'digibyte'... \\n" "${INFO}"

    fi

    DGB_USER_PASS1=$(whiptail --passwordbox "Please choose a password for the new 'digibyte' user.\\n\\nIMPORTANT: Don't forget this - you will need it to access your DigiNode!" 8 78 --title "Choose a password for new user: digibyte" 3>&1 1>&2 2>&3)
                                                                        # A trick to swap stdout and stderr.
    # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
    exitstatus=$?
    if [ $exitstatus == 0 ]; then
        printf "%b Password entered for new 'digibyte' user.\\n" "${INFO}"
    else
        printf "%b %bYou cancelled creating a password.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bIf you prefer, you can manually create a 'digibyte' user account:\\n" "${INFO}"
        printf "\\n"
        printf "%b   ${txtbld}sudo adduser digibyte${txtrst}\\n" "${INDENT}"
        printf "%b   ${txtbld}sudo passwd digibyte${txtrst}\\n" "${INDENT}"
        printf "%b   ${txtbld}sudo usermod -aG sudo digibyte${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b Login as the new user:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ${txtbld}su - digibyte${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b Switch to your new home directory:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ${txtbld}cd${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b And then run DigiNode Setup again.\\n" "${INDENT}"
        printf "\\n"
        exit
    fi

    DGB_USER_PASS2=$(whiptail --passwordbox "Please re-enter the password to confirm." 8 78 --title "Re-enter password for new user: digibyte" 3>&1 1>&2 2>&3)
                                                                        # A trick to swap stdout and stderr.
    # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
    exitstatus=$?
    if [ $exitstatus == 0 ]; then
        printf "%b Password re-entered for new 'digibyte' user.\\n" "${INFO}"
        # Compare both passwords to check they match
        if [ "$DGB_USER_PASS1" = "$DGB_USER_PASS2" ]; then
            printf "%b Passwords match.\\n" "${TICK}"
            DGB_USER_PASS=$DGB_USER_PASS1
            digibyte_user_passwords_match="yes"
            printf "\\n"
        else
            whiptail --msgbox --title "Passwords do not match!" "The passwords do not match. Please try again." 10 "${c}"
            printf "%b Passwords do not match. Please try again.\\n" "${CROSS}"
            skip_if_reentering_password="yes"

            # re do prompt for password
            user_do_change
        fi
    else
        printf "%b %bYou cancelled creating a password.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bIf you prefer, you can manually create a 'digibyte' user account:\\n" "${INFO}"
        printf "\\n"
        printf "%b   ${txtbld}sudo adduser digibyte${txtrst}\\n" "${INDENT}"
        printf "%b   ${txtbld}sudo passwd digibyte${txtrst}\\n" "${INDENT}"
        printf "%b   ${txtbld}sudo usermod -aG sudo digibyte${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b Login as the new user:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ${txtbld}su - digibyte${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b Switch to your new home directory:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ${txtbld}cd${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b And then run DigiNode Setup again.\\n" "${INDENT}"
        printf "\\n"
        exit
    fi


    # If the passwords have been entered okay proceed cretaing the new account (unless it has already been done)
    if [ "$digibyte_user_passwords_match" = "yes" ]; then

        # Encrypt CLEARTEXT password
        local str="Encrypting CLEARTEXT password ... "
        printf "%b %s..." "${INFO}" "${str}"
        DGB_USER_PASS_ENCR=$(perl -e 'print crypt($ARGV[0], "password")' $DGB_USER_PASS)
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        
        # Create digibyte user
        local str="Creating user 'digibyte'. This can sometimes take a moment. Please wait... "
        printf "%b %s..." "${INFO}" "${str}"

        # For Ubuntu:
        useradd digibyte -p $DGB_USER_PASS_ENCR -U -G sudo -m --shell /bin/bash 

   #     useradd -G wheel digibyte -m -s /bin/bash #CentOS

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

        printf "%b The new user 'digibyte' has been created.\\n" "${INDENT}"
        printf "\\n"
        printf "%b Please sign as user 'digibyte' by entering:\\n" "${INFO}"
        printf "\\n"
        printf "%b   ${txtbld}su - digibyte${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b Then switch to your new home directory:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ${txtbld}cd${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b And then run DigiNode Setup again.\\n" "${INDENT}"
        printf "\\n"

        #clear password variables
        DGB_USER_PASS1=null
        DGB_USER_PASS2=null
        DGB_USER_PASS=null
        DGB_USER_PASS_ENCR=null

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

    printf " =============== Checking: RAM and SWAP file ===========================\\n\\n"
    # ==============================================================================

    local swap_current_size

    if [ "$SWAPTOTAL_HR" = "0B" ]; then
      swap_current_size="${COL_LIGHT_RED}none${COL_NC}"
    else
      swap_current_size="${COL_LIGHT_GREEN}${SWAPTOTAL_HR}b${COL_NC}"
    fi
    printf "%b System Memory Check:     System RAM: %b${RAMTOTAL_HR}b%b     SWAP size: $swap_current_size\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    # insert a single line gap if this is DigiNode Setup
    if [[ "$RUN_SETUP" != "NO" ]] ; then
        printf "\\n"
    fi

    # Check the existing swap file is large enough based on how much RAM the device has
    #
    # Note: these checks on the current swap size use the lower Kibibyte value
    # so that if the recomended swap size is 4Gb, and they enter 4 Gigabytes or 4 Gibibytes
    # the size check will come out the same for either
    #
    # These check for a minimum total of 12Gb, but recommend a total of 16Gb. THe user can then choose how big they want.
    #

    if [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "10742187" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="15Gb"
        SWAP_REC_SIZE_MB=15000
        SWAP_MIN_SIZE_HR="11Gb"
        SWAP_MIN_SIZE_MB=11000
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "9765625" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="14Gb"
        SWAP_REC_SIZE_MB=14000
        SWAP_MIN_SIZE_HR="10Gb"
        SWAP_MIN_SIZE_MB=10000
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "8789062" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="13Gb"
        SWAP_REC_SIZE_MB=13000
        SWAP_MIN_SIZE_HR="9Gb"
        SWAP_MIN_SIZE_MB=9000
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "7812500" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="12Gb"
        SWAP_REC_SIZE_MB=12000
        SWAP_MIN_SIZE_HR="8Gb"
        SWAP_MIN_SIZE_MB=8000
    elif [ "$RAMTOTAL_KB" -le "5000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "6835938" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="11Gb"
        SWAP_REC_SIZE_MB=11000
        SWAP_MIN_SIZE_HR="7Gb"
        SWAP_MIN_SIZE_MB=7000
    elif [ "$RAMTOTAL_KB" -le "6000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "5859375" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="10Gb"
        SWAP_REC_SIZE_MB=10000
        SWAP_MIN_SIZE_HR="6Gb"
        SWAP_MIN_SIZE_MB=6000
    elif [ "$RAMTOTAL_KB" -le "7000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "4882813" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="9Gb"
        SWAP_REC_SIZE_MB=9000
        SWAP_MIN_SIZE_HR="5Gb"
        SWAP_MIN_SIZE_MB=5000
    elif [ "$RAMTOTAL_KB" -le "8000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "3906250" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="8Gb"
        SWAP_REC_SIZE_MB=8000
        SWAP_MIN_SIZE_HR="4Gb"
        SWAP_MIN_SIZE_MB=4000
    elif [ "$RAMTOTAL_KB" -le "9000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "2929688" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="7Gb"
        SWAP_REC_SIZE_MB=7000
        SWAP_MIN_SIZE_HR="3Gb"
        SWAP_MIN_SIZE_MB=3000
    elif [ "$RAMTOTAL_KB" -le "10000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "1953125" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="6Gb"
        SWAP_REC_SIZE_MB=6000
        SWAP_MIN_SIZE_HR="2Gb"
        SWAP_MIN_SIZE_MB=2000
    elif [ "$RAMTOTAL_KB" -le "11000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "976562" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE_HR="5Gb"
        SWAP_REC_SIZE_MB=5000
        SWAP_MIN_SIZE_HR="1Gb"
        SWAP_MIN_SIZE_MB=1000

    # If there is no swap file present, calculate recomended swap file size

    # OLD

    elif [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="15Gb"
        SWAP_REC_SIZE_MB=15000
        SWAP_MIN_SIZE_HR="11Gb"
        SWAP_MIN_SIZE_MB=11000
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="14Gb"
        SWAP_REC_SIZE_MB=14000
        SWAP_MIN_SIZE_HR="10Gb"
        SWAP_MIN_SIZE_MB=10000
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="13Gb"
        SWAP_REC_SIZE_MB=13000
        SWAP_MIN_SIZE_HR="9Gb"
        SWAP_MIN_SIZE_MB=9000
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="12Gb"
        SWAP_REC_SIZE_MB=12000
        SWAP_MIN_SIZE_HR="8Gb"
        SWAP_MIN_SIZE_MB=8000
    elif [ "$RAMTOTAL_KB" -le "5000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="11Gb"
        SWAP_REC_SIZE_MB=11000
        SWAP_MIN_SIZE_HR="7Gb"
        SWAP_MIN_SIZE_MB=7000
    elif [ "$RAMTOTAL_KB" -le "6000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="10Gb"
        SWAP_REC_SIZE_MB=10000
        SWAP_MIN_SIZE_HR="6Gb"
        SWAP_MIN_SIZE_MB=6000
    elif [ "$RAMTOTAL_KB" -le "7000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="9Gb"
        SWAP_REC_SIZE_MB=9000
        SWAP_MIN_SIZE_HR="5Gb"
        SWAP_MIN_SIZE_MB=5000
    elif [ "$RAMTOTAL_KB" -le "8000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="8Gb"
        SWAP_REC_SIZE_MB=8000
        SWAP_MIN_SIZE_HR="4Gb"
        SWAP_MIN_SIZE_MB=4000
    elif [ "$RAMTOTAL_KB" -le "9000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="7Gb"
        SWAP_REC_SIZE_MB=7000
        SWAP_MIN_SIZE_HR="3Gb"
        SWAP_MIN_SIZE_MB=3000
    elif [ "$RAMTOTAL_KB" -le "10000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="6Gb"
        SWAP_REC_SIZE_MB=6000
        SWAP_MIN_SIZE_HR="2Gb"
        SWAP_MIN_SIZE_MB=2000
    elif [ "$RAMTOTAL_KB" -le "11000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="5Gb"
        SWAP_REC_SIZE_MB=5000
        SWAP_MIN_SIZE_HR="1Gb"
        SWAP_MIN_SIZE_MB=1000
    elif [ "$RAMTOTAL_KB" -le "12000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE_HR="4Gb"
        SWAP_REC_SIZE_MB=4000
        SWAP_MIN_SIZE_HR="0Gb"
        SWAP_MIN_SIZE_MB=0
    fi


    if [ "$SWAP_NEEDED" = "YES" ]; then
        printf "%b Swap Check: %bFAILED%b   Not enough total memory for DigiNode.\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bWARNING: You need to create a swap file.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b A DigiByte Node typically requires around 6Gb RAM but this can be higher during the\\n" "${INDENT}"
        printf "%b intial sync when it may use 8Gb or more. A DigiAsset Node requires around 3Gb RAM.\\n" "${INDENT}"
        printf "%b It is always advisable to have a swap file even if your system has enough RAM.\\n" "${INDENT}"
        printf "%b Since a full DigiNode can require up to 10Gb RAM, as a bare minimum you should\\n" "${INDENT}"
        printf "%b ensure that your RAM and SWAP file combined is not less than 12Gb.\\n" "${INDENT}"          
        printf "%b Since your device only has ${RAMTOTAL_HR}b RAM, it is recommended to create\\n" "${INDENT}"
        printf "%b a swap file of at least $SWAP_REC_SIZE_HR. This will give your system at least\\n" "${INDENT}"
        printf "%b 16Gb of total memory to work with.\\n" "${INDENT}"
        # Only display this line when using digimon.sh
        if [[ "$RUN_SETUP" = "NO" ]] ; then
            printf "%b The official DigiNode Setup can setup the swap file for you.\\n" "${INDENT}"
        fi
        SWAP_ASK_CHANGE="YES"
    fi

    if [ "$SWAP_TOO_SMALL" = "YES" ]; then
        printf "%b Swap Check: %bFAILED%b   Not enough total memory for DigiNode.\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bWARNING: Your swap file is too small%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b A DigiByte Node typically requires around 6Gb RAM but this can be higher during the\\n" "${INDENT}"
        printf "%b intial sync when it may use 8Gb or more. A DigiAsset Node requires around 3Gb RAM.\\n" "${INDENT}"
        printf "%b It is always advisable to have a swap file even if your system has enough RAM.\\n" "${INDENT}"
        printf "%b Since your device only has ${RAMTOTAL_HR}b RAM, it is recommended to increase the\\n" "${INDENT}"
        printf "%b size of your swap file to at least $SWAP_REC_SIZE_HR. This will give your system at\\n" "${INDENT}"
        printf "%b least 16Gb of total memory to work with.\\n" "${INDENT}"
        # Only display this line when using digimon.sh
        if [[ "$RUN_SETUP" = "NO" ]] ; then
            printf "%b The official DigiNode Setup can setup the swap file for you.\\n" "${INDENT}"
        fi
        SWAP_ASK_CHANGE="YES"
    fi

    # Calculate total memory available
    TOTALMEM_KB=$(( $RAMTOTAL_KB + $SWAPTOTAL_KB ))

    if [ $RAMTOTAL_KB -gt 15800000 ] && [ "$SWAPTOTAL_KB" = 0 ]; then
        printf "%b Swap Check: %bPASSED%b   Your system has at least 16Gb RAM so a swap file is not required.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    elif [ $TOTALMEM_KB -gt 15800000 ]; then
        printf "%b Swap Check: %bPASSED%b   Your system RAM and SWAP combined is at least 16Gb.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    elif [ $RAMTOTAL_KB -gt 11800000 ] && [ "$SWAPTOTAL_KB" = 0 ]; then
        printf "%b Swap Check: %bPASSED%b   Your system has at least 12Gb RAM so a swap file is not required.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b A DigiByte Node typically requires ~6Gb RAM but this can be higher during the\\n" "${INDENT}"
        printf "%b intial sync when it may use 8Gb or more. A DigiAsset Node requires ~3Gb RAM.\\n" "${INDENT}"
        printf "%b It is always advisable to have a swap file even if your system has enough RAM.\\n" "${INDENT}"
        printf "%b Since your device only has ${RAMTOTAL_HR}b RAM, it is recommended to create\\n" "${INDENT}"
        printf "%b a swap file of at least $SWAP_REC_SIZE_HR. This will give your system at\\n" "${INDENT}"
        printf "%b least 16Gb of total memory to work with.\\n" "${INDENT}"
    elif [ $TOTALMEM_KB -gt 11800000 ]; then
         printf "%b Swap Check: %bPASSED%b   Your system RAM and SWAP combined is at least 12Gb.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"  
        printf "%b A DigiByte Node typically requires ~6Gb RAM but this can be higher during the\\n" "${INDENT}"
        printf "%b intial sync when it may use 8Gb or more. A DigiAsset Node requires ~3Gb RAM.\\n" "${INDENT}"
        printf "%b It is always advisable to have a swap file even if your system has enough RAM.\\n" "${INDENT}"
        printf "%b Since your device only has ${RAMTOTAL_HR}b RAM, it is recommended to increase\\n" "${INDENT}"
        printf "%b the size of your swap file to at least $SWAP_REC_SIZE_HR. This will give your\\n" "${INDENT}"
        printf "%b system at least 16Gb of total memory to work with.\\n" "${INDENT}"     
    fi
    printf "\\n"
}




# If a swap file is needed, this will ask the user to confirm that they want to create one or increase the size of an existing one
swap_ask_change() {

# Display a request to change the hostname, if needed
if [ "$SWAP_ASK_CHANGE" = "YES" ] && [ "$UNATTENDED_MODE" == false ]; then

        # Do this if the current swap file is too small
    if [ "$SWAP_TOO_SMALL" = "YES" ]; then

        if [ "$skip_if_reentering_swap_size" != "yes" ]; then

            # Ask the user if they want to create a swap file now, or exit
            if whiptail --title "Swap file detected." --yesno "WARNING: Your current swap file is too small.\\n\\nA DigiByte Node typically requires around 6Gb RAM but this can reach 8Gb or more during the intial sync. A DigiAsset Node requires around 3Gb RAM. In total, a full DigiNode running both can require up to 12Gb RAM.\\n\\nIt is always advisable to have a swap file even if your system has enough RAM. As a bare minimum you should ensure that your total memory (system RAM and swap file combined) is not less than 12Gb. 16Gb is recommended. \\n\\nWould you like to create a new swap file now?\\n\\n\\nChoose CONTINUE To have DigiNode Setup assist you in creating a new swap file.\\n\\nChoose EXIT to quit DigiNode Setup and create a new swap file manually." --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then

                #Nothing to do, continue
                printf "%b You chose to exit to create a new swap file.\\n" "${INFO}"
            else
              printf "%b You chose to exit to create a swap file manually.\\n" "${INFO}"
              printf "\\n"
              exit
            fi

        fi

    fi

    # Do this if there is no swap file
    if [ "$SWAP_NEEDED" = "YES" ]; then

        if [ "$skip_if_reentering_swap_size" != "yes" ]; then

            if whiptail --title "Swap file not detected." --yesno "WARNING: You need to create a swap file.\\n\\nA DigiByte Node typically requires around 6Gb RAM but this can reach 8Gb or more during the intial sync. A DigiAsset Node requires around 3Gb RAM. In total, a full DigiNode running both can require up to 12Gb RAM.\\n\\nIt is always advisable to have a swap file even if your system has enough RAM. As a bare minimum you should ensure that your total memory (system RAM and swap file combined) is not less than 12Gb. 16Gb is recommended.\\n\\nChoose CONTINUE To have DigiNode Setup assist you in creating a new swap file.\\n\\nChoose EXIT to quit DigiNode Setup and create a new swap file manually." --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then

                #Nothing to do, continue
                printf "%b You chose to create a new swap file.\\n" "${INFO}"
            else
              printf "%b You chose to exit to create a swap file manually.\\n" "${INFO}"
              printf "\\n"
              exit
            fi

        fi

    fi


    # Do this if there is no swap file OR the current swap file is too small
    if [ "$SWAP_NEEDED" = "YES" ] || [ "$SWAP_TOO_SMALL" = "YES" ]; then

        if [ "$skip_if_reentering_swap_size" != "yes" ]; then

            #If we are using a Pi, booting from microSD, and we need a USB stick for the swap, tell the user to prepare one
            if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]] && [[ "$REQUIRE_USB_STICK_FOR_SWAP" = "YES" ]]; then

                # Ask the user if they want to create a swap file now, or exit
                if whiptail --title "USB stick required." --yesno "You need a USB stick to store your swap file.\\n\\nSince you are running your system off a microSD card, and this Pi only has $MODELMEM RAM, you need to use a USB stick to store your swap file:\\n\\n - Minimum capacity is 16Gb.\\n - For best performance it should support USB 3.0 or greater.\\n - WARNING: The existing contents will be erased.\\n\\nDo not insert the USB stick into the Pi yet. If it is already plugged in, please UNPLUG it before continuing.\\n\\nChoose CONTINUE once you are ready, with the USB stick unplugged.\\n\\nChoose EXIT to quit DigiNode Setup and create a swap file manually." --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then

                    #Nothing to do, continue
                    printf "%b You chose to continue and begin preparing the swap file on a USB stick.\\n" "${INFO}"
                else
                  printf "%b You chose to exit to create a swap file manually.\\n" "${INFO}"
                  printf "\\n"
                  exit
                fi

                # Get the user to insert the USB stick to use as a swap drive and detect it
                USB_SWAP_STICK_INSERTED="NO"
                cancel_insert_usb=""
                LSBLK_BEFORE_USB_INSERTED=$(lsblk)
                progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
                printf "%b Please insert the USB stick you wish to use for your swap drive now. (WARNING: The contents will be erased.)\\n" "${INFO}"
                printf "\\n"
                printf "%b Press any key to cancel.\\n" "${INFO}"
                printf "\\n"
                str="Waiting for USB stick... "
                printf "%b %s" "${INDENT}" "${str}"
                tput civis
                while [ "$USB_SWAP_STICK_INSERTED" = "NO" ]; do

                    # Show Spinner while waiting for SWAP drive
                    if [ "$progress" = "[${COL_BOLD_WHITE}◜ ${COL_NC}]" ]; then
                      progress="[${COL_BOLD_WHITE} ◝${COL_NC}]"
                    elif [ "$progress" = "[${COL_BOLD_WHITE} ◝${COL_NC}]" ]; then
                      progress="[${COL_BOLD_WHITE} ◞${COL_NC}]"
                    elif [ "$progress" = "[${COL_BOLD_WHITE} ◞${COL_NC}]" ]; then
                      progress="[${COL_BOLD_WHITE}◟ ${COL_NC}]"
                    elif [ "$progress" = "[${COL_BOLD_WHITE}◟ ${COL_NC}]" ]; then
                      progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
                    fi

                    LSBLK_AFTER_USB_INSERTED=$(lsblk)

                    USB_SWAP_DRIVE=$(diff  <(echo "$LSBLK_BEFORE_USB_INSERTED" ) <(echo "$LSBLK_AFTER_USB_INSERTED") | grep '>' | grep -m1 sd | cut -d' ' -f2)

                    if [ "$USB_SWAP_DRIVE" != "" ]; then
                        USB_SWAP_STICK_INSERTED="YES"
                        if [ "$USB_SWAP_DRIVE" = "├─sdb1" ]; then
                            USB_SWAP_DRIVE="sdb"
                        fi

                        # Check if USB_SWAP_DRIVE string starts with └─ or ├─ (this can happen if the user booted the machine with the backup USB stick already inserted)
                        # This snippet will clean up the USB_BACKUP_DRIVE variable on that rare occurrence
                        #
                        # if the string starts with └─, remove it
                        if [[ $USB_SWAP_DRIVE = └─* ]]; then
                            cleanup_swap_name=true
                            USB_SWAP_DRIVE=$(echo $USB_SWAP_DRIVE | sed 's/└─//')
                        fi
                        # if the string starts with ├─, remove it
                        if [[ $USB_SWAP_DRIVE = ├─* ]]; then
                            cleanup_swap_name=true
                            USB_SWAP_DRIVE=$(echo $USB_SWAP_DRIVE | sed 's/├─//')
                        fi
                        # if the string ends in a number, remove it
                        if [[ $USB_SWAP_DRIVE = *[0-9] ]]; then
                            cleanup_swap_name=true
                            USB_SWAP_DRIVE=$(echo $USB_SWAP_DRIVE | sed 's/.$//')
                        fi 

                        printf "%b%b %s USB Stick Inserted: $USB_SWAP_DRIVE\\n" "${OVER}" "${TICK}" "${str}"
                        tput cnorm

                        # Display partition name cleanup messages
                        if [[ $cleanup_swap_name = true ]]; then
                            printf "%b (Note: Swap stick was already inserted at boot. In future, do not plug it in until requested or you may encounter errors.)\\n" "${INFO}"
                            cleanup_swap_name=false
                        fi
                    else
                        printf "%b%b %s $progress" "${OVER}" "${INDENT}" "${str}"
                        LSBLK_BEFORE_USB_INSERTED=$(lsblk)
                        read -t 0.5 -n 1 keypress && cancel_insert_usb="yes" && break
                    fi
                done

                # Return to menu if a keypress was detected to cancel inserting a USB
                if [ "$cancel_insert_usb" = "yes" ]; then
                    whiptail --msgbox --backtitle "" --title "USB Swap Setup Cancelled." "USB Swap Setup Cancelled." "${r}" "${c}" 
                    printf "%b You cancelled the USB backup.\\n" "${INFO}"
                    printf "\\n"
                    cancel_insert_usb=""
                    exit
                fi

                # Wipe the current partition on the drive
                str="Wiping exisiting partition(s) on USB stick..."
                printf "%b %s" "${INFO}" "${str}"
                sfdisk --quiet --delete /dev/$USB_SWAP_DRIVE
                # dd if=/dev/zero of=/dev/$USB_SWAP_DRIVE bs=512 count=1 seek=0
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                # Wipe the current partition on the drive
                str="Create new primary gpt partition on USB stick..."
                printf "%b %s" "${INFO}" "${str}"
                parted --script --align=opt /dev/${USB_SWAP_DRIVE} mklabel gpt mkpart primary 0% 100%
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                # Set up file system on USB stick
                printf "Setting up EXT4 file system on USB stick. Please wait..." "${INFO}"
                printf "(Note: This may take some time. Do not unplug the USB stick.)" "${INDENT}"
                mkfs.ext4 -f /dev/${USB_SWAP_DRIVE}1

                # Create mount point for USB drive, if needed
                if [ ! -d /media/usbswap ]; then
                    str="Create mount point for USB drive..."
                    printf "%b %s" "${INFO}" "${str}"
                    mkdir /media/usbswap
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                # Create mount point for USB drive, if needed
                str="Mount new USB swap partition..."
                printf "%b %s" "${INFO}" "${str}"
                mount /dev/${USB_SWAP_DRIVE}1 /media/usbswap
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                # Set swap file location
                SWAP_FILE="/media/usbswap/swapfile"

            else
                # Use default swap location, if we are not using an external USB
                SWAP_FILE="/swapfile"
            fi

        fi


        # Ask the user what size of swap file they want
        SWAP_TARG_SIZE_MB=$(whiptail  --inputbox "\\nPlease enter the desired swap file size in MB.\\n\\nNote: As a bare minimum, you should ensure that your total memory (system RAM + swap file) is at least 12GB, but 16GB is recommended to avoid any issues. Since your system has ${RAMTOTAL_HR}b RAM, it is recommended to create a swap file of at least $SWAP_REC_SIZE_HR.\\n\\nThe recommended size has been entered for you. If you are unsure, use this." "${r}" "${c}" $SWAP_REC_SIZE_MB --title "Enter swap file size" 3>&1 1>&2 2>&3) 

        # The `3>&1 1>&2 2>&3` is a small trick to swap the stderr with stdout
        # Meaning instead of return the error code, it returns the value entered

        # Now to check if the user pressed OK or Cancel
        exitstatus=$?
        if [ $exitstatus = 0 ]; then
            printf "%b You chose to create a swap file: $SWAP_TARG_SIZE_MB Mb\\n" "${INFO}"
        else
            printf "%b You exited when choosing a swap file size.\\n" "${INFO}"
            printf "\\n"
            exit
        fi

        # Check the entered value is big enough
        if [ "$SWAP_TARG_SIZE_MB" -lt "$SWAP_MIN_SIZE_MB" ]; then
            whiptail --msgbox --title "Alert: Swap file size is too small!" "The swap file size you entered is not big enough." 10 "${c}"
            printf "%b The swap file size you entered was too small.\\n" "${INFO}"
            skip_if_reentering_swap_size="yes"
            swap_ask_change
        fi

        SWAP_DO_CHANGE="YES"
        printf "\\n"

    fi

fi

}

# If a swap file is needed, this function will create one or change the size of an existing one
swap_do_change() {

    # If in Unattended mode, and a swap file is needed, then proceed
    if [[ $NewInstall = true ]] && [[ "$UNATTENDED_MODE" = "true" ]] && [ "$SWAP_NEEDED" = "YES" ]; then
        SWAP_DO_CHANGE="YES"
    fi

    # If in Unattended mode, and the existing swap file is to small, then proceed
    if [[ $NewInstall = true ]] && [[ "$UNATTENDED_MODE" = "true" ]] && [ "$SWAP_TOO_SMALL" = "YES" ]; then
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

        #Which distro are we using?
        local detected_os=$(grep "\bID\b" /etc/os-release | cut -d '=' -f2 | tr -d '"')


        ######################################
        ### SETUP SWAP FILE ON DEBIAN
        ######################################

        # If this is DEBIAN and it uses dphys-swapfile...
        if [ "$detected_os" = "debian" ] && [ -f /etc/dphys-swapfile ]; then

            # If the swap file already exists, but is too small
            if [ "$SWAP_TOO_SMALL" = "YES" ]; then

                # Disable existing swap file
                str="Disable existing swap file..."
                printf "%b %s..." "${INFO}" "${str}"
                dphys-swapfile swapoff
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            fi

            # Find CONF_SWAPSIZE value and update it
            str="Updating CONF_SWAPSIZE value..."
            printf "%b %s..." "${INFO}" "${str}"

            # Look for a line that starts with CONF_SWAPSWIZE
            if [ "$(cat /etc/dphys-swapfile | grep -Eo ^CONF_SWAPSIZE=)" = "CONF_SWAPSIZE=" ]; then
    
                sed -i -e "/^CONF_SWAPSIZE=/s|.*|CONF_SWAPSIZE=$SWAP_TARG_SIZE_MB|" /etc/dphys-swapfile
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Look for a line that starts with #CONF_SWAPSWIZE
            elif [ "$(cat /etc/dphys-swapfile | grep -Eo ^#CONF_SWAPSIZE=)" = "#CONF_SWAPSIZE=" ]; then

                sed -i -e "/^#CONF_SWAPSIZE=/s|.*|CONF_SWAPSIZE=$SWAP_TARG_SIZE_MB|" /etc/dphys-swapfile
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Look for a line that starts with # CONF_SWAPSWIZE
            elif [ "$(cat /etc/dphys-swapfile | grep -Eo ^# CONF_SWAPSIZE=)" = "# CONF_SWAPSIZE=" ]; then

                sed -i -e "/^# CONF_SWAPSIZE=/s|.*|CONF_SWAPSIZE=$SWAP_TARG_SIZE_MB|" /etc/dphys-swapfile
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            else

                printf "%b%b %s Fail!\\n" "${OVER}" "${CROSS}" "${str}"
                printf "\\n"
                printf "%b ERROR: Unable to update CONF_SWAPSIZE variable in /etc/dphys-swapfile\\n" "${INFO}"
                printf "\\n"
                exit 1

            fi

            # Find CONF_MAXSWAP value and update it
            str="Updating CONF_MAXSWAP value..."
            printf "%b %s..." "${INFO}" "${str}"

            # Look for a line that starts with CONF_MAXSWAP
            if [ "$(cat /etc/dphys-swapfile | grep -Eo ^CONF_MAXSWAP=)" = "CONF_MAXSWAP=" ]; then
    
                sed -i -e "/^CONF_MAXSWAP=/s|.*|CONF_MAXSWAP=$SWAP_TARG_SIZE_MB|" /etc/dphys-swapfile
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Look for a line that starts with #CONF_MAXSWAP
            elif [ "$(cat /etc/dphys-swapfile | grep -Eo ^#CONF_MAXSWAP=)" = "#CONF_MAXSWAP=" ]; then

                sed -i -e "/^#CONF_MAXSWAP=/s|.*|CONF_MAXSWAP=$SWAP_TARG_SIZE_MB|" /etc/dphys-swapfile
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Look for a line that starts with # CONF_MAXSWAP
            elif [ "$(cat /etc/dphys-swapfile | grep -Eo ^# CONF_MAXSWAP=)" = "# CONF_MAXSWAP=" ]; then

                sed -i -e "/^# CONF_MAXSWAP=/s|.*|CONF_MAXSWAP=$SWAP_TARG_SIZE_MB|" /etc/dphys-swapfile
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            else

                printf "%b%b %s Fail!\\n" "${OVER}" "${CROSS}" "${str}"
                printf "\\n"
                printf "%b ERROR: Unable to update CONF_MAXSWAP variable in /etc/dphys-swapfile\\n" "${INFO}"
                printf "\\n"
                exit 1

            fi


            #If we are using a Pi, booting from microSD, and are using a USB stick for the swap, tell the system to use it
            if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]] && [[ "$REQUIRE_USB_STICK_FOR_SWAP" = "YES" ]]; then

                # Find CONF_SWAPFILE value and update it
                str="Using USB Stick for Swap. Updating CONF_SWAPFILE location to $SWAP_FILE ..."
                printf "%b %s..." "${INFO}" "${str}"

                # Look for a line that starts with CONF_MAXSWAP
                if [ "$(cat /etc/dphys-swapfile | grep -Eo ^CONF_SWAPFILE=)" = "CONF_SWAPFILE=" ]; then
        
                    sed -i -e "/^CONF_SWAPFILE=/s|.*|CONF_SWAPFILE=$SWAP_FILE|" /etc/dphys-swapfile
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                # Look for a line that starts with #CONF_MAXSWAP
                elif [ "$(cat /etc/dphys-swapfile | grep -Eo ^#CONF_SWAPFILE=)" = "#CONF_SWAPFILE=" ]; then

                    sed -i -e "/^#CONF_SWAPFILE=/s|.*|CONF_SWAPFILE=$SWAP_FILE|" /etc/dphys-swapfile
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                # Look for a line that starts with # CONF_MAXSWAP
                elif [ "$(cat /etc/dphys-swapfile | grep -Eo ^# CONF_SWAPFILE=)" = "# CONF_SWAPFILE=" ]; then

                    sed -i -e "/^# CONF_SWAPFILE=/s|.*|CONF_SWAPFILE=$SWAP_FILE|" /etc/dphys-swapfile
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                else

                    printf "%b%b %s Fail!\\n" "${OVER}" "${CROSS}" "${str}"
                    printf "\\n"
                    printf "%b ERROR: Unable to update CONF_SWAPFILE location in /etc/dphys-swapfile\\n" "${INFO}"
                    printf "\\n"
                    exit 1

                fi

            fi

            # Setup the swap file on the USB stick
            printf "%b Initializing swap file...\\n" "${INFO}"
            dphys-swapfile setup

            # Get the UUID of the USB stick with the swap file
            str="Turning on the swap file..."
            printf "\\n%b %s..." "${INFO}" "${str}"
            dphys-swapfile swapon
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Tell user the swap file has been created
            if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]] && [[ "$REQUIRE_USB_STICK_FOR_SWAP" = "YES" ]]; then
                whiptail --msgbox --title "Swap file created on USB stick." "The swap file has been setup on the USB stick. Do not unplug it or the DigiNode will not work." 10 "${c}"
            fi

            REBOOT_NEEDED="YES"



        ###################################################################
        ### SETUP SWAP FILE ON UBUNTU (OR DEBIAN WITH NO DPHYS-SWAPFILE) ##
        ###################################################################

        elif [ "$detected_os" = "ubuntu" ] || [ "$detected_os" = "debian" ]; then

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
            str="Allocate ${SWAP_TARG_SIZE_MB}B for new swap file..."
            printf "%b %s..." "${INFO}" "${str}"
            fallocate -l "$SWAP_TARG_SIZE_MB" "$SWAP_FILE"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Mark new file as swap
            printf "%b Set up new swap file...\\n" "${INFO}"
            mkswap "$SWAP_FILE"       
            
            # Secure swap file
            str="Assign root as swap file owner..."
            printf "%b %s..." "${INFO}" "${str}"
            chown root:root $SWAP_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Secure swap file
            str="Give root read/write permissions for swap file..."
            printf "%b %s..." "${INFO}" "${str}"
            chmod 0600 $SWAP_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Activate new swap file
            str="Activate new swap file..."
            printf "%b %s..." "${INFO}" "${str}"
            swapon "$SWAP_FILE"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}" 

            #If we are using a Pi, booting from microSD, and we need a USB stick for the swap, tell the user to prepare one
            if [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]] && [[ "$REQUIRE_USB_STICK_FOR_SWAP" = "YES" ]]; then

                # Get the UUID of the USB stick with the swap file
                str="Lookup UUID of USB stick..."
                printf "%b %s..." "${INFO}" "${str}"
                SWAP_USB_UUID=$(blkid | grep sda1 | cut -d' ' -f2 | cut -d'=' -f2 | sed 's/"//g')
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}" 

                # Make new swap drive and file available at boot
                str="Make USB drive and swap file available at next boot..."
                printf "%b %s..." "${INFO}" "${str}"
                sudo sed -i.bak '/usbswap/d' /etc/fstab
                sudo sed -i.bak '/swapfile/d' /etc/fstab
                echo "UUID=$SWAP_USB_UUID /media/usbswap auto nosuid,nodev,nofail 0 0" >> /etc/fstab
                echo "$SWAP_FILE swap swap defaults 0 0" >> /etc/fstab
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}" 

                # Tell user the swap file has been created
                whiptail --msgbox --title "Swap file created on USB stick." "The swap file has been setup on the USB stick. Do not unplug it or the DigiNode will not work." 10 "${c}"

            else

                # Make new swap file available at boot
                str="Make swap file available at next boot..."
                printf "%b %s..." "${INFO}" "${str}"
                sudo sed -i.bak '/swap/d' /etc/fstab
                echo "$SWAP_FILE none swap defaults 0 0" >> /etc/fstab
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}" 

            fi

            REBOOT_NEEDED="YES"

        else

            printf "\\n"
            printf "%b ERROR: Unable to recognise this Linux distro to setup swap file.\\n" "${INFO}"
            printf "\\n"
            printf "%b Swap setup for your Linux distro is not currently supported.\\n" "${INFO}"
            printf "%b Please post a message in the 'DigiNode Tools' Telegram group including\\n" "${INDENT}"
            printf "%b the distro you are running ($detected_os).\\n" "${INDENT}"
            printf "\\n"
            printf "%b Go here: https://t.me/+ked2VGZsLPAyN2Jk\\n" "${INFO}"
            printf "\\n"
            exit 1

        fi

        printf "\\n"

    fi

}

# This function will help the user backup their DigiByte wallet to an external USB drive. It will also optionally backup the DigiAsset Node _config folder.
usb_backup() {

    # Skip this part if we need to re-enter the encryption password
    if [ "$skip_if_reentering_encryption_passphrases" != "yes" ]; then

        printf " =============== DigiNode Backup =======================================\\n\\n"
        # ==============================================================================

        # Reset selection variables in case this is not the first time running though the options
        run_wallet_backup=false
        run_dgaconfig_backup=false
        cancel_insert_usb=""


        # Introduction to backup.
        if whiptail --backtitle "" --title "DigiNode Backup" "This tool helps you backup your DigiByte wallet and/or DigiAsset Node settings to a USB stick.\\n\\nIt is recommended that you use a USB stick that is not used for anything else, and that you store it somewhere safe and secure.\\n\\nYou do not require a lot of space for the backup - any small USB stick is fine. For best results, make sure it is formatted with exFAT.\\n\\nIMPORTANT: To perform a backup, you need access to a free USB slot on your DigiNode. If your DigiNode is running in the cloud, you will likely not be able to use this tool." --yesno --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then
            printf "%b You chose to begin the backup process.\\n" "${INFO}"
        else
            printf "%b You chose not to begin the backup process. Returning to menu...\\n" "${INFO}"
            printf "\\n"
            menu_existing_install 
        fi

        # Ask to backup DigiByte Core Wallet, if it exists
        if [ -f "$DGB_SETTINGS_LOCATION/wallet.dat" ]; then


            # Ask if the user wants to backup their DigiBytewallet
            if whiptail --backtitle "" --title "DIGIBYTE CORE WALLET BACKUP" --yesno "Would you like to backup your DigiByte wallet?\\n\\nThis is highly recomended, if you have not already done so, as it will safeguard the contents of your DigiByte wallet, and make it easy to restore your DigiNode in the event of hardware failure." --yes-button "Yes (Recommended)" "${r}" "${c}"; then

                run_wallet_backup=true
            else
                run_wallet_backup=false
            fi
        else
            printf "%b No DigiByte Core wallet file currently exists. Returning to menu...\\n" "${INFO}"
            run_wallet_backup=false
            # Display a message saying that the wallet.dat file does not exist
            whiptail --msgbox --backtitle "" --title "ERROR: wallet.dat not found" "No DigiByte Core wallet.dat file currently exists to backup. The script will exit." "${r}" "${c}"
            printf "\\n"
            menu_existing_install   
            printf "\\n"
        fi

        # Ask to backup the DigiAsset Node _config folder, if it exists
        if [ -d "$DGA_SETTINGS_LOCATION" ]; then

            # Ask the user if they want to backup their DigiAsset Node settings
            if whiptail --backtitle "" --title "DIGIASSET NODE BACKUP" --yesno "Would you like to also backup your DigiAsset Node settings?\\n\\nThis will backup your DigiAsset Node _config folder which stores your Amazon web services credentials, RPC password etc. It means you can quickly restore your DigiNode in the event of a hardware failure, or if you wish to move your DigiNode to a different device.\\n\\nNote: Before creating a backup, it is advisable to have first completed setting up your DigiAsset Node via the web UI."  --yes-button "Yes (Recommended)" "${r}" "${c}"; then

                run_dgaconfig_backup=true
            else
                run_dgaconfig_backup=false
            fi
        fi

        # Return to main menu if the user has selected to backup neither the wallet nor the DigiAsset config
        if [[ "$run_wallet_backup" == false ]] && [[ "$run_dgaconfig_backup" == false ]]; then
                printf "%b Backup cancelled. Returning to menu...\\n" "${INFO}"
                printf "\\n"
                menu_existing_install
        fi

        # Display start backup messages
        if [[ "$run_wallet_backup" == true ]] && [[ "$run_dgaconfig_backup" == true ]]; then
            printf "%b You chose to backup both your DigiByte wallet and DigiAsset Node settings.\\n" "${INFO}"
        elif [[ "$run_wallet_backup" == true ]] && [[ "$run_dgaconfig_backup" == false ]]; then
            printf "%b You chose to backup only your DigiByte Core wallet.\\n" "${INFO}"
        elif [[ "$run_dgaconfig_backup" == false ]] && [[ "$run_dgaconfig_backup" == true ]]; then
            printf "%b You chose to backup only your DigiAsset Node settings.\\n" "${INFO}"
        fi

        # If we are backing up the wallet, we first check that it is encrypted (DigiByte daemon needs to be running to do this)
        if [[ "$run_wallet_backup" == true ]]; then

            # Start the DigiByte service now, in case it is not already running
            printf "%b DigiByte daemon must be running to check your wallet before backup.\\n" "${INFO}"

            # Next let's check if DigiByte daemon is running, and start it if it is not
            if check_service_active "digibyted"; then
                DGB_STATUS="running"
            else
                DGB_STATUS="notrunning"
                restart_service digibyted
                DGB_STATUS="running"
            fi
            printf "\\n"
        

            # Run the digibyte_check function, because we need to be sure that DigiByte Core is not only running, 
            # but has also completely finished starting up, and this function will wait until it has finished starting up before continuing.
            digibyte_check

            printf " =============== Checking: DigiByte Wallet =============================\\n\\n"
            # ==============================================================================

            # Check if the wallet is currently unencrypted
            IS_WALLET_ENCRYPTED=$(sudo -u $USER_ACCOUNT $DGB_CLI walletlock 2>&1 | grep -Eo "running with an unencrypted wallet")
            if [ "$IS_WALLET_ENCRYPTED" = "running with an unencrypted wallet" ]; then

                printf "%b DigiByte Wallet is NOT currently encrypted.\\n" "${CROSS}"

                # Ask the user if they want to encrypt with a password?
                if whiptail --backtitle "" --title "ENCRYPT WALLET" --yesno "Would you like to encrypt your DigiByte wallet with a passphrase?\\n\\nThis is highly recommended. It offers an additional level of security, since if someone finds the USB stick, they will not be able to access the wallet.dat file without the passphrase."  --yes-button "Yes (Recommended)" "${r}" "${c}"; then

                    printf "%b You chose to encrypt your wallet with a passphrase.\\n" "${INFO}"
                    encrypt_wallet_now=true
                else
                    printf "%b You chose NOT to encrypt your wallet with a passphrase.\\n" "${INFO}"
                    encrypt_wallet_now=false
                    printf "\\n"
                fi
            else
                printf "%b DigiByte Wallet is already encrypted.\\n" "${TICK}"
                printf "\\n"
            fi


        fi

    fi    

    # START PASSPHRASE ENCRYPTION OF DIGIBYTE WALLET

    if [[ "$encrypt_wallet_now" == true ]]; then

        WALLET_ENCRYT_PASS1=$(whiptail --passwordbox "Please enter a passphrase to encrypt your DigiByte Core wallet. It can be as long as you like and may include spaces.\\n\\nIMPORTANT: DO NOT FORGET THIS PASSPHRASE - you will need it every time you want to access your wallet. Should you forget it, there is no way to regain access to your wallet. You have been warned!!" 8 78 --title "Enter a passphrase to encrypt your DigiByte wallet" 3>&1 1>&2 2>&3)
            # A trick to swap stdout and stderr.
            # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
        exitstatus=$?
        if [ $exitstatus == 0 ]; then
            printf "%b Passphrase entered for encrypted wallet.\\n" "${INFO}"
        else
            printf "%b %bYou cancelled choosing a wallet encryption passphrase.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            # Display a message saying that the wallet.dat file does not exist
            whiptail --msgbox --backtitle "" --title "Backup cancelled." "You cancelled entering an encryption passphrase. The script will exit." "${r}" "${c}" 
            printf "\\n"
            menu_existing_install  
        fi

        WALLET_ENCRYT_PASS2=$(whiptail --passwordbox "Please re-enter the passphrase to confirm." 8 78 --title "Re-enter passphrase for wallet encryption" 3>&1 1>&2 2>&3)
            # A trick to swap stdout and stderr.
            # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
        exitstatus=$?
        if [ $exitstatus == 0 ]; then
            printf "%b Passphrase re-entered for wallet encryption.\\n" "${INFO}"
            # Compare both passphrases to check they match
            if [ "$WALLET_ENCRYT_PASS1" = "$WALLET_ENCRYT_PASS2" ]; then
                printf "%b Passphrases match.\\n" "${TICK}"
                WALLET_ENCRYT_PASS=$WALLET_ENCRYT_PASS1
                wallet_encryption_passphrases_match="yes"
            else
                whiptail --msgbox --title "Passwords do not match!" "The passwords do not match. Please try again." 10 "${c}"
                printf "%b Passwords do not match. Please try again.\\n" "${CROSS}"
                skip_if_reentering_encryption_passphrases="yes"

                # re-do prompt for password
                usb_backup
            fi
        else
            printf "%b %bYou cancelled choosing an encryption password.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            # Display a message saying that the wall.dat file does not exist
            whiptail --msgbox --backtitle "" --title "Backup cancelled." "You cancelled entering a backup password. The script will exit." "${r}" "${c}" 
            printf "\\n"
            menu_existing_install  
        fi


        # If the passphrases have been entered correctly, proceed encrypting the wallet.dat file
        if [ "$wallet_encryption_passphrases_match" = "yes" ]; then

            # Encrypting wallet.dat file
            local str="Encrypting Digibyte wallet"
            printf "%b %s..." "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT $DGB_CLI encryptwallet "$WALLET_ENCRYT_PASS" 1>/dev/null

            # If the command completed without error, then assume the wallet is encrypted
            if [ $? -eq 0 ]; then
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                whiptail --msgbox --backtitle "" --title "DigiByte Wallet is now encrypted." "Your DigiByte wallet is now encrypted. Do not forget the passphrase!!" "${r}" "${c}" 
                
                # Restart the DigiByte service
                printf "%b Restarting DigiByte daemon systemd service...\\n\\n" "${INFO}"
                restart_service digibyted
            else
                whiptail --msgbox --backtitle "" --title "DigiByte Wallet encryption failed." "ERROR: Your DigiByte wallet was not successfully encrypted. The script will exit." "${r}" "${c}" 
                printf "\\n"
                exit 1
            fi

        fi

        #clear wallet encryption variables
        encrypt_wallet_now=null
        skip_if_reentering_encryption_passphrases="no"
        WALLET_ENCRYT_PASS1=null
        WALLET_ENCRYT_PASS2=null
        WALLET_ENCRYT_PASS=null

    fi

    # END PASSWORD ENCRYPTION OF DIGIBYTE WALLET

    if [[ "$run_wallet_backup" == true ]] || [[ "$run_dgaconfig_backup" == true ]]; then

        printf " =============== DigiNode Backup =======================================\\n\\n"
        # ==============================================================================

        # Ask the user to prepare their backup USB stick
        if whiptail --backtitle "" --title "PREPARE BACKUP USB STICK" --yesno "Are you ready to proceed with DigiNode backup?\\n\\nPlease have your backup USB stick ready - for best results make sure it is formatted in either exFAT or FAT32. NTFS may not work!\\n\\nIMPORTANT: Do not insert the USB stick into the DigiNode yet. If it is already plugged in, please UNPLUG it before continuing."  --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then

            printf "%b You confirmed your backup USB stick is ready.\\n" "${INFO}"
        else
            printf "%b You chose not to proceed with the backup. Returning to menu...\\n" "${INFO}"
            run_wallet_backup=false
            printf "\\n"
            menu_existing_install
        fi
        printf "\\n"

        # Ask the user to insert the USB stick to use as a backup drive and detect it
        USB_BACKUP_STICK_INSERTED="NO"
        LSBLK_BEFORE_USB_INSERTED=$(lsblk)
        progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
        printf "%b %bPlease insert the USB stick you wish to use for your backup now.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b (If it is already plugged in, unplug it, wait a moment, and then\\n" "${INDENT}"
        printf "%b plug it back in so the script can detect it.)\\n" "${INDENT}"
        printf "\\n"
        printf "%b Press any key to cancel.\\n" "${INFO}"
        printf "\\n"
        str="Waiting for USB stick... "
        printf "%b %s" "${INDENT}" "${str}"
        tput civis
        while [ "$USB_BACKUP_STICK_INSERTED" = "NO" ]; do

            # Show Spinner while waiting for USB backup stick
            if [ "$progress" = "[${COL_BOLD_WHITE}◜ ${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE} ◝${COL_NC}]"
            elif [ "$progress" = "[${COL_BOLD_WHITE} ◝${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE} ◞${COL_NC}]"
            elif [ "$progress" = "[${COL_BOLD_WHITE} ◞${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE}◟ ${COL_NC}]"
            elif [ "$progress" = "[${COL_BOLD_WHITE}◟ ${COL_NC}]" ]; then
              progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
            fi

            LSBLK_AFTER_USB_INSERTED=$(lsblk)

            USB_BACKUP_DRIVE=$(diff  <(echo "$LSBLK_BEFORE_USB_INSERTED" ) <(echo "$LSBLK_AFTER_USB_INSERTED") | grep '>' | grep -m1 sd | cut -d' ' -f2)

            if [ "$USB_BACKUP_DRIVE" != "" ]; then

                # Check if USB_BACKUP_DRIVE string starts with └─ or ├─ (this can happen if the user booted the machine with the backup USB stick already inserted)
                # This snippet will clean up the USB_BACKUP_DRIVE variable on that rare occurrence
                #
                # if the string starts with └─, remove it
                if [[ $USB_BACKUP_DRIVE = └─* ]]; then
                    cleanup_partion_name=true
                    USB_BACKUP_DRIVE=$(echo $USB_BACKUP_DRIVE | sed 's/└─//')
                fi
                # if the string starts with ├─, remove it
                if [[ $USB_BACKUP_DRIVE = ├─* ]]; then
                    cleanup_partion_name=true
                    USB_BACKUP_DRIVE=$(echo $USB_BACKUP_DRIVE | sed 's/├─//')
                fi
                # if the string ends in a number, remove it
                if [[ $USB_BACKUP_DRIVE = *[0-9] ]]; then
                    cleanup_partion_name=true
                    USB_BACKUP_DRIVE=$(echo $USB_BACKUP_DRIVE | sed 's/.$//')
                fi 

                printf "%b%b %s USB Stick Inserted: $USB_BACKUP_DRIVE\\n" "${OVER}" "${TICK}" "${str}"
                USB_BACKUP_STICK_INSERTED="YES"
                cancel_insert_usb="no"
                tput cnorm

                # Display partition name cleanup messages
                if [[ $cleanup_partion_name = true ]]; then
                    printf "%b (Note: Backup stick was already inserted at boot. If future, do not plug it in until requested or you may encounter errors.)\\n" "${INFO}"
                    cleanup_partion_name=false
                fi

            else
                printf "%b%b %s $progress" "${OVER}" "${INDENT}" "${str}"
                LSBLK_BEFORE_USB_INSERTED=$(lsblk)
 #               sleep 0.5
                read -t 0.5 -n 1 keypress && cancel_insert_usb="yes" && break
            fi
        done

        # Return to menu if a keypress was detected to cancel inserting a USB
        if [ "$cancel_insert_usb" = "yes" ]; then
            whiptail --msgbox --backtitle "" --title "USB Backup Cancelled." "USB Backup Cancelled." "${r}" "${c}" 
            printf "%b You cancelled the USB backup.\\n" "${INFO}"
            printf "\\n"
            cancel_insert_usb=""
            menu_existing_install
        fi

        # Create mount point for USB stick, if needed
        if [ ! -d /media/usbbackup ]; then
            str="Creating mount point for inserted USB stick..."
            printf "%b %s" "${INFO}" "${str}"
            mkdir /media/usbbackup
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Mount USB stick
        local format_usb_stick_now=false
        local mount_partition=""
        printf "%b Checking USB for suitable partitions...\\n" "${INFO}"
        # Query partprobe to find valid partition
        if [ "$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}2 2>/dev/null)" != "" ]; then
            partition_type=$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}2 2>&1)
            if [ "$(echo $partition_type | grep -Eo "msdos")" = "msdos" ] || [ "$(echo $partition_type | grep -Eo "loop")" = "loop" ]; then
                printf "%b Trying to mount partition ${USB_BACKUP_DRIVE}2...\\n" "${INFO}"
                mount /dev/${USB_BACKUP_DRIVE}2 /media/usbbackup 1>/dev/null
                mount_partition="${USB_BACKUP_DRIVE}2"
            fi
        elif [ "$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}1 2>/dev/null)" != "" ]; then
            partition_type=$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}1 2>&1)
            if [ "$(echo $partition_type | grep -Eo "msdos")" = "msdos" ] || [ "$(echo $partition_type | grep -Eo "loop")" = "loop" ]; then
                printf "%b Trying to mount partition ${USB_BACKUP_DRIVE}1...\\n" "${INFO}"
                mount /dev/${USB_BACKUP_DRIVE}1 /media/usbbackup 1>/dev/null
                mount_partition="${USB_BACKUP_DRIVE}1"
            fi
        else
            printf "%b No suitable partition found. Removing mount point.\\n" "${INFO}"
            rmdir /media/usbbackup
            mount_partition=""
        fi

        # Did the USB stick get mounted successfully?
        str="Did USB stick mount successfully?..."
        printf "%b %s" "${INFO}" "${str}"
        if [ "$(lsblk | grep -Eo /media/usbbackup)" = "/media/usbbackup" ]; then
            printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"

            # TEST WRITE TO USB USING TOUCH testfile.txt
            printf "%b Checking the inserted USB stick is writeable...\\n" "${INFO}"
            touch /media/usbbackup/testfile.txt 2>/dev/null
            if [ -f /media/usbbackup/testfile.txt ]; then
                printf "%b%b %s Yes! [ Write test completed successfully ]\\n" "${OVER}" "${TICK}" "${str}" 
                rm /media/usbbackup/testfile.txt
                format_usb_stick_now=false
            else
                printf "%b%b %s No! [ Write test FAILED ]\\n" "${OVER}" "${CROSS}" "${str}" 
                format_usb_stick_now=true 
            fi

            # Does USB stick contain an existing backup?
            if [ -f /media/usbbackup/diginode_backup/diginode_backup.info ]; then
                printf "%b Existed DigiNode backup detected on USB stick:\\n" "${INFO}"
                source /media/usbbackup/diginode_backup/diginode_backup.info
                printf "%b DigiByte Wallet backup date: $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\\n" "${INDENT}"
                printf "%b DigiAsset Node backup date: $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\\n" "${INDENT}"
            fi

        else
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
            format_usb_stick_now=true
        fi


        # Offer to format the stick if needed
        if [ "$format_usb_stick_now" = true ]; then
            printf "%b Asking to format USB stick...\\n" "${INFO}"

            # Ask the user if they want to format the USB stick
            if whiptail --title "Inserted USB Stick is not writeable." --yesno "Would you like to format the USBs stick?\\n\\nThe stick you inserted does not appear to be writeable, and needs to be formatted before it can be used for the backup.\\n\\nWARNING: If you continue, any existing data on the USB stick will be erased. If you prefer to try a different USB stick, please choose Exit, and run this again from the main menu." --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then

                printf "%b You confirmed you want to format the USB stick.\\n" "${INFO}"
                printf "\\n"

                # FORMAT USB STICK HERE 

                printf " =============== Format USB Stick ======================================\\n\\n"
                # ==============================================================================

                opt1a="exFAT"
                opt1b="Format the USB stick as exFAT."
                
                opt2a="FAT32"
                opt2b="Format the USB stick as FAT32."


                # Display the information to the user
                UpdateCmd=$(whiptail --title "Format USB Stick" --menu "\\n\\nPlease choose what file system you would like to format your USB stick. \\n\\nIMPORTANT: If you continue, any data currently on the stick will be erased.\\n\\n" "${r}" "${c}" 3 \
                "${opt1a}"  "${opt1b}" \
                "${opt2a}"  "${opt2b}" 4>&3 3>&2 2>&1 1>&3) || \
                { printf "%b %bCancel was selected. Returning to main menu.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; whiptail --msgbox --backtitle "" --title "Remove the USB stick" "Please unplug the USB stick now." "${r}" "${c}"; format_usb_stick_now=false; printf "\\n"; menu_existing_install; }

                # Set the variable based on if the user chooses
                case ${UpdateCmd} in
                    # Update, or
                    ${opt1a})
                        printf "%b You selected to format the USB stick as exFAT.\\n" "${INFO}"
                        USB_BACKUP_STICK_FORMAT="exfat"

                        ;;
                    # Reset,
                    ${opt2a})
                        printf "%b You selected to format the USB stick as FAT32.\\n" "${INFO}"                   
                        USB_BACKUP_STICK_FORMAT="fat32"
                        ;;
                esac

                # Unmount USB stick
                str="Unmount the USB stick at /dev/${USB_BACKUP_DRIVE}..."
                printf "%b %s" "${INFO}" "${str}"
                umount /dev/${USB_BACKUP_DRIVE} 2>/dev/null 1>/dev/null
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                # Wipe the current partition on the drive
#                str="Wiping exisiting partition(s) on the USB stick..."
#                printf "%b %s" "${INFO}" "${str}"
#                sfdisk --quiet --delete /dev/$USB_BACKUP_DRIVE

                # If the command completed without error, then assume the wallet was formatted
#                if [ $? -eq 0 ]; then
#                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
#                else
#                    printf "%b%b %s Failed!\\n" "${OVER}" "${CROSS}" "${str}"
#                    whiptail --msgbox --backtitle "" --title "Deleting USB Partitons Failed." "ERROR: Your USB stick could not be wiped. Try formatting it on another computer - exFAT or FAT32 are recommended.\\n\\nPlease unplug the USB stick now before continuing." "${r}" "${c}" 
#                    printf "\\n"
#                    format_usb_stick_now=false
#                    menu_existing_install
#                fi

                # Create new partition on the USB stick
                if [ "$USB_BACKUP_STICK_FORMAT" = "exfat" ]; then
                    str="Creating GPT partition for exFAT file system on the USB stick..."
                    printf "%b %s" "${INFO}" "${str}"
                    parted --script --align=opt /dev/${USB_BACKUP_DRIVE} mklabel gpt mkpart primary ntfs 0% 100%
                    partprobe
                    sleep 5
                elif [ "$USB_BACKUP_STICK_FORMAT" = "fat32" ]; then
                    str="Creating GPT partition for FAT32 file system on the USB stick..."
                    printf "%b %s" "${INFO}" "${str}"
                    parted --script --align=opt /dev/${USB_BACKUP_DRIVE} mklabel gpt mkpart primary fat32 0% 100%
                    partprobe
                    sleep 5
                fi

                # If the command completed without an error, then assume the partition was created successfully
                if [ $? -eq 0 ]; then
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                else
                    printf "%b%b %s Failed!\\n" "${OVER}" "${CROSS}" "${str}"
                    whiptail --msgbox --backtitle "" --title "Creating GPT Partition Failed." "ERROR: Your USB stick could not be partitioned. Try partioning it on another computer - exFAT or FAT32 are recommended.\\n\\nPlease unplug the USB stick now before continuing." "${r}" "${c}" 
                    printf "\\n"
                    format_usb_stick_now=false
                    menu_existing_install
                fi

                # Set up file system on USB stick (exfat or fat32)
                if [ "$USB_BACKUP_STICK_FORMAT" = "exfat" ]; then
                    printf "Creating exFAT file system. Please wait...\\n" "${INFO}"
                    mkfs.exfat /dev/${USB_BACKUP_DRIVE}1  -L DigiNodeBAK
                elif [ "$USB_BACKUP_STICK_FORMAT" = "fat32" ]; then
                    printf "Creating FAT32 file system. Please wait...\\n" "${INFO}"
                    mkfs.vfat /dev/${USB_BACKUP_DRIVE}1 -n DIGINODEBAK -v
                fi

                # If the command completed without an error, then assume the partition was successfully formatted
                if [ $? -eq 0 ]; then
                    printf "File system created successfully." "${TICK}"
                else
                    printf "ERROR: Creating file system failed." "${CROSS}"

                    whiptail --msgbox --backtitle "" --title "Creating File System Failed." "ERROR: The $USB_BACKUP_STICK_FORMAT file system could not be created. Try formatting it on another computer - exFAT or FAT32 are recommended.\\n\\nPlease unplug the USB stick now before continuing." "${r}" "${c}" 
                    printf "\\n"
                    format_usb_stick_now=false
                    menu_existing_install
                fi

                # Create mount point for USB backup drive, if needed
                if [ ! -d /media/usbbackup ]; then
                    str="Create mount point for USB backup drive..."
                    printf "%b %s" "${INFO}" "${str}"
                    mkdir /media/usbbackup
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                # Create mount point for USB backup drive, if needed
                str="Mount new USB backup partition..."
                printf "%b %s" "${INFO}" "${str}"
                mount /dev/${USB_BACKUP_DRIVE}1 /media/usbbackup
                mount_partition="${USB_BACKUP_DRIVE}1"
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            else
                printf "%b You chose not to proceed with formatting the USB stick. Returning to menu...\\n" "${INFO}"
                whiptail --msgbox --backtitle "" --title "Remove the USB stick" "Please unplug the USB stick now." "${r}" "${c}"
                run_wallet_backup=false
                run_dgaconfig_backup=false
                format_usb_stick_now=false
                printf "\\n"  
                menu_existing_install
            fi
            printf "\\n"
            format_usb_stick_now=false

        fi

        # Create backup folder on USB stick, if it does not already exist
        if [ ! -d /media/usbbackup/diginode_backup ]; then
            str="Create \"diginode_backup\" folder on USB drive..."
            printf "%b %s" "${INFO}" "${str}"
            mkdir /media/usbbackup/diginode_backup
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Create a backup status file on the USB stick, if it does not already exist
        if [ ! -f /media/usbbackup/diginode_backup/diginode_backup.info ]; then

            str="Creating DigiNode Backup status file on USB stick: diginode_backup.info ... "
            printf "%b %s" "${INFO}" "${str}"
            touch /media/usbbackup/diginode_backup/diginode_backup.info
            cat <<EOF > /media/usbbackup/diginode_backup/diginode_backup.info
# Latest DigiNode Backup
DGB_WALLET_BACKUP_DATE_ON_USB_STICK=""
DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=""

# Old DigiNode Backup (Created if you overwrite an existing backup)
DGB_WALLET_OLD_BACKUP_DATE_ON_USB_STICK=""
DGA_CONFIG_OLD_BACKUP_DATE_ON_USB_STICK=""
EOF
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Create a backup log file on the USB stick, if it does not already exist
        if [ ! -f /media/usbbackup/diginode_backup/diginode_backup.log ]; then

            str="Creating DigiNode Backup log file on USB stick: diginode_backup.log ... "
            printf "%b %s" "${INFO}" "${str}"
            touch /media/usbbackup/diginode_backup/diginode_backup.log
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Source the diginode_backup.info file to find out when last backups were carried out
        source /media/usbbackup/diginode_backup/diginode_backup.info

        # Create a variable containing the time and date right now for logging changes
        NEW_BACKUP_DATE=$(date)

        # If the wallet.dat file does not exist on the USB stick, delete the corresponding backup date in the status file (perhaps a previous backup has been manually deleted)
        if [ ! -f /media/usbbackup/diginode_backup/wallet.dat ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" != "" ]; then
            str="wallet.dat has been deleted since last backup. Removing backup date from diginode_backup.info ... "
            printf "%b %s" "${INFO}" "${str}"
            DGB_WALLET_BACKUP_DATE_ON_USB_STICK=""            
            sed -i -e "/^DGB_WALLET_BACKUP_DATE_ON_USB_STICK=/s|.*|DGB_WALLET_BACKUP_DATE_ON_USB_STICK=|" /media/usbbackup/diginode_backup/diginode_backup.info
            echo "$NEW_BACKUP_DATE DigiByte Wallet: wallet.dat has been manually deleted from USB stick- removing previous backup date from diginode_backup.info." >> /media/usbbackup/diginode_backup/diginode_backup.log
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If the dga_config_backup folder does not exist on the USB stick, delete the corresponding backup date in the status file (perhap a previous backup has been manually deleted)
        if [ ! -d /media/usbbackup/diginode_backup/dga_config_backup ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" != "" ]; then
            str="DigiAssets dga_config_backup folder has been deleted from the USB stick since last backup. Removing backup date from diginode_backup.info ... "
            printf "%b %s" "${INFO}" "${str}"  
            DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=""          
            sed -i -e "/^DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=/s|.*|DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=|" /media/usbbackup/diginode_backup/diginode_backup.info
            echo "$NEW_BACKUP_DATE DigiAsset Node Settings: _config folder has been manually deleted from USB stick- removing previous backup date from diginode_backup.info." >> /media/usbbackup/diginode_backup/diginode_backup.log
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # START DIGIBYTE WALLET BACKUP

        if [ "$run_wallet_backup" = true ]; then

            # If a wallet.dat backup exists on the stick already
            if [ -f /media/usbbackup/diginode_backup/wallet.dat ]; then

                #If the stick already contains a wallet.dat backup, but there is no date logged anywhere of when a previous backup was conducted, ask the user if they want to continue
                if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" = "" ]; then
                    # Ask the user to prepare their backup USB stick
                    if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of another DigiByte wallet. Do you want to overwrite it?\\n\\nIt is unknown when this backup was created, and it appears that it was not created from this DigiNode. \\n\\nIf you continue the existing backup will be overwritten." "${r}" "${c}"; then

                        do_wallet_backup_now=true
                        printf "%b DigiByte Wallet: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                        echo "$NEW_BACKUP_DATE DigiByte Wallet: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    else
                        printf "%b DigiByte Wallet: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                        do_wallet_backup_now=false
                    fi
                fi

                #If the stick already contains a wallet.dat backup, but it was not created by this DigiNode, ask the user if they want to continue
                if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" != "" ]; then
                    # Ask the user to prepare their backup USB stick
                    if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of a DigiByte wallet. Do you want to overwrite it?\\n\\nThe existing wallet backup was created:\\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK \\n\\nIt is not known whether the backup was made from this DigiNode. If you continue the existing backup will be overwritten." "${r}" "${c}"; then

                        do_wallet_backup_now=true
                        printf "%b DigiByte Wallet: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                        echo "$NEW_BACKUP_DATE DigiByte Wallet: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    else
                        printf "%b DigiByte Wallet: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                        do_wallet_backup_now=false
                    fi
                fi

                #If the stick already contains a wallet.dat backup, but it was not created by this DigiNode, ask the user if they want to continue
                if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" != "" ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" = "" ]; then
                    # Ask the user to prepare their backup USB stick
                    if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of a DigiByte wallet. Do you want to overwrite it?\\n\\nIt is unknown when this backup was created, or whether it was created from this DigiNode. This DigiNode was previously backed up to another stick on:\\n  $DGB_WALLET_BACKUP_DATE_ON_DIGINODE\\n\\nIf you continue the existing wallet backup will be overwritten." "${r}" "${c}"; then

                        do_wallet_backup_now=true
                        printf "%b DigiByte Wallet: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                        echo "$NEW_BACKUP_DATE DigiByte Wallet: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    else
                        printf "%b DigiByte Wallet: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                        do_wallet_backup_now=false
                    fi
                fi

                #If the stick already contains a wallet.dat backup, and there has been a previous backup logged on both the stick and the DigiNode, check if they are the same or not
                if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" != "" ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" != "" ]; then

                    # If this is the same backup stick as was used last time, then ask the user if they want to overwrite it
                    if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" ]; then

                        # Ask the user to prepare their backup USB stick
                        if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of this DigiByte wallet. Do you want to overwrite it?\\n\\nThis backup was previously created on:\\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK.\\n\\nYou should not need to create a new backup unless you have recently encrypted the wallet. If you continue your existing wallet backup will be overwritten." "${r}" "${c}"; then

                            do_wallet_backup_now=true
                            printf "%b DigiByte Wallet: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                            echo "$NEW_BACKUP_DATE DigiByte Wallet: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        else
                            printf "%b DigiByte Wallet: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                            do_wallet_backup_now=false
                        fi

                    else

                        # Ask the user to prepare their backup USB stick
                        if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a DigiByte wallet backup. Do you want to overwrite it?\\n\\nThis DigiByte wallet backup was made on:\\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK.\\n\\nA previous backup was made to a different USB stick on:\\n  $DGB_WALLET_BACKUP_DATE_ON_DIGINODE\\n\\nIf you continue the existing backup will be overwritten." "${r}" "${c}"; then

                            do_wallet_backup_now=true
                            printf "%b DigiByte Wallet: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                            echo "$NEW_BACKUP_DATE DigiByte Wallet: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        else
                            printf "%b DigiByte Wallet: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                            do_wallet_backup_now=false
                        fi

                    fi

                fi

            else
                # If NO wallet.dat file exists on the stick already

                #If the wallet.dat file has seemingly never been backed up anywhere else
                if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ]; then
                    do_wallet_backup_now=true
                    printf "%b DigiByte Wallet: No previous wallet.dat backup has been detected. Backup will proceed...\\n" "${INFO}"
                    echo "$NEW_BACKUP_DATE DigiByte Wallet: No previous wallet.dat backup has been detected. Backup will proceed..." >> /media/usbbackup/diginode_backup/diginode_backup.log
                fi

                #If the wallet.dat file has previously been backed up somewhere else, but not to this stick, ask the user if they want to continue
                if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" != "" ]; then
                    # Ask the user to prepare their backup USB stick
                    do_wallet_backup_now=true
                    printf "%b DigiByte Wallet: This backup will replace the one created on: $DGB_WALLET_BACKUP_DATE_ON_DIGINODE\\n" "${INFO}"
                    echo "$NEW_BACKUP_DATE DigiByte Wallet: This backup will replace the one created on: $DGB_WALLET_BACKUP_DATE_ON_DIGINODE" >> /media/usbbackup/diginode_backup/diginode_backup.log
                fi
                
            fi

            # Perform DigiByte wallet backup
            if [ "$do_wallet_backup_now" = true ]; then

                # Backup the existing wallet backup, if it exists
                if [ -f /media/usbbackup/diginode_backup/wallet.dat ]; then

                    # Delete previous secondary backup of existing wallet, if it exists
                    if [ -f /media/usbbackup/diginode_backup/wallet.dat.old ]; then
                        str="Deleting existing old backup: wallet.dat.old ... "
                        printf "%b %s" "${INFO}" "${str}" 
                        rm /media/usbbackup/diginode_backup/wallet.dat.old
                        echo "$NEW_BACKUP_DATE DigiByte Wallet: Deleted existing old backup: wallet.dat.old" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi

                    # Rename existing wallet backup to .old
                    str="Renaming existing wallet.dat backup to wallet.dat.old ... "
                    printf "%b %s" "${INFO}" "${str}" 
                    mv /media/usbbackup/diginode_backup/wallet.dat /media/usbbackup/diginode_backup/wallet.dat.old
                    echo "$NEW_BACKUP_DATE DigiByte Wallet: Renaming existing wallet.dat backup to wallet.dat.old." >> /media/usbbackup/diginode_backup/diginode_backup.log
                    sed -i -e "/^DGB_WALLET_OLD_BACKUP_DATE_ON_USB_STICK=/s|.*|DGB_WALLET_OLD_BACKUP_DATE_ON_USB_STICK=\"$DGB_WALLET_BACKUP_DATE_ON_USB_STICK\"|" $DGNT_SETTINGS_FILE
                    sed -i -e "/^DGB_WALLET_BACKUP_DATE_ON_USB_STICK=/s|.*|DGB_WALLET_BACKUP_DATE_ON_USB_STICK=\"\"|" $DGNT_SETTINGS_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                fi

                # Copy "live" wallet to backup stick
                str="Backing up DigiByte wallet to USB stick ... "
                printf "%b %s" "${INFO}" "${str}" 
                cp $DGB_SETTINGS_LOCATION/wallet.dat /media/usbbackup/diginode_backup/
                if [ $? -eq 0 ]; then
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"           
                    echo "$NEW_BACKUP_DATE DigiByte Wallet: Backup completed successfully." >> /media/usbbackup/diginode_backup/diginode_backup.log
                    local dgb_backup_result="ok"

                    DGB_WALLET_BACKUP_DATE_ON_USB_STICK="$NEW_BACKUP_DATE"
                    str="Log DigiByte wallet backup date on the USB stick... "
                    printf "%b %s" "${INFO}" "${str}"          
                    sed -i -e "/^DGB_WALLET_BACKUP_DATE_ON_USB_STICK=/s|.*|DGB_WALLET_BACKUP_DATE_ON_USB_STICK=\"$NEW_BACKUP_DATE\"|" /media/usbbackup/diginode_backup/diginode_backup.info
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                    DGB_WALLET_BACKUP_DATE_ON_DIGINODE="$NEW_BACKUP_DATE" 
                    str="Log DigiByte wallet backup date in the DigiNode settings... "
                    printf "%b %s" "${INFO}" "${str}"          
                    sed -i -e "/^DGB_WALLET_BACKUP_DATE_ON_DIGINODE=/s|.*|DGB_WALLET_BACKUP_DATE_ON_DIGINODE=\"$NEW_BACKUP_DATE\"|" $DGNT_SETTINGS_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                else
                    printf "%b%b %s FAIL!\\n" "${OVER}" "${CROSS}" "${str}"
                    echo "$NEW_BACKUP_DATE DigiByte Wallet: Backup failed due to an error." >> /media/usbbackup/diginode_backup/diginode_backup.log
                    local dgb_backup_result="failed"
                fi

            fi

        fi

        #################################
        # START DIGIASSET CONFIG BACKUP TO USB STICK
        #################################


        if [ "$run_dgaconfig_backup" = true ]; then

            # If a 'dga_config_backup' folder exists on the stick already
            if [ -d /media/usbbackup/diginode_backup/dga_config_backup ]; then

                #If the stick already contains a 'dga_config_backup' folder, but there is no date logged anywhere of when a previous backup was conducted, ask the user if they want to continue
                if [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" = "" ] && [ "$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK" = "" ]; then
                    if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of another DigiAsset Node. Do you want to overwrite it?\\n\\nIt is unknown when this backup was created, and it appears that it was not created from this DigiNode. \\n\\nIf you continue the existing backup will be overwritten." "${r}" "${c}"; then

                        do_dgaconfig_backup_now=true
                        printf "%b DigiAsset Settings: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                        echo "$NEW_BACKUP_DATE DigiAsset Settings: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    else
                        printf "%b DigiAsset Settings: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                        do_dgaconfig_backup_now=false
                    fi
                fi

                #If the stick already contains a 'dga_config_backup' folder, but it was not created by this DigiNode, ask the user if they want to continue
                if [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" = "" ] && [ "$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK" != "" ]; then
                    # Ask the user to prepare their backup USB stick
                    if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of another DigiAsset Node. Do you want to overwrite it?\\n\\nThe existing backup was created:\\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK \\n\\nIt is not known whether the backup was made from this DigiNode. If you continue the existing backup will be overwritten." "${r}" "${c}"; then

                        do_dgaconfig_backup_now=true
                        printf "%b DigiAsset Settings: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                        echo "$NEW_BACKUP_DATE DigiAsset Settings: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    else
                        printf "%b DigiAsset Settings: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                        do_dgaconfig_backup_now=false
                    fi
                fi

                #If the stick already contains a DigiAsset Settings folder, but it was not created by this DigiNode, ask the user if they want to continue
                if [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" != "" ] && [ "$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK" = "" ]; then
                    # Ask the user to prepare their backup USB stick
                    if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of another DigiAsset Node. Do you want to overwrite it?\\n\\nIt is unknown when this backup was created, or whether it was created from this DigiNode. This DigiNode was preciously backed up to another stick on:\\n  $DGA_CONFIG_BACKUP_DATE_ON_DIGINODE\\n\\nIf you continue the existing DigiAsset settings backup will be overwritten." "${r}" "${c}"; then

                        do_dgaconfig_backup_now=true
                        printf "%b DigiAsset Settings: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                        echo "$NEW_BACKUP_DATE DigiAsset Settings: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    else
                        printf "%b DigiAsset Settings: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                        do_dgaconfig_backup_now=false
                    fi
                fi

                #If the stick already contains a DigiAsset Settings folder, and there has been a previous backup logged on both the stick and the DigiNode, check if they are the same or not
                if [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" != "" ] && [ "$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK" != "" ]; then

                    # If this is the same backup stick as was used last time, then ask the user if they want to overwrite it
                    if [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" = "$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK" ]; then

                        if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a backup of this DigiAsset Node. Do you want to overwrite it?\\n\\nThis backup was previously created on:\\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK.\\n\\nYou should not need to create a new DigiAsset Settings backup unless you have recently changed your configuration. If you continue your existing DigiAsset Settings backup will be overwritten." "${r}" "${c}"; then

                            do_dgaconfig_backup_now=true
                            printf "%b DigiAsset Settings: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                            echo "$NEW_BACKUP_DATE DigiAsset Settings: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        else
                            printf "%b DigiAsset Settings: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                            do_dgaconfig_backup_now=false
                        fi

                    else

                        # Ask the user to prepare their backup USB stick
                        if whiptail --backtitle "" --title "Existing backup found on stick" --yesno "WARNING: This USB stick already contains a DigiAsset Node backup. Do you want to overwrite it?\\n\\nThis DigiAsset Node backup was made on:\\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK.\\n\\nA previous backup was made to a different USB stick on:\\n  $DGA_CONFIG_BACKUP_DATE_ON_DIGINODE\\n\\nIf you continue the current backup will be overwritten." "${r}" "${c}"; then

                            do_dgaconfig_backup_now=true
                            printf "%b DigiAsset Settings: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                            echo "$NEW_BACKUP_DATE DigiAsset Settings: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        else
                            printf "%b DigiAsset Settings: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                            do_dgaconfig_backup_now=false
                        fi

                    fi

                fi

            else
                # If no DigiAsset settings folder exists on the stick already

                #If the DigiAsset settings folder seemingly never been backed up anywhere else
                if [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" = "" ]; then
                    do_dgaconfig_backup_now=true
                    printf "%b DigiAsset Settings: No previous backup has been detected. Backup will proceed...\\n" "${INFO}"
                    echo "$NEW_BACKUP_DATE DigiAsset Settings: No previous backup has been detected. Backup will proceed..." >> /media/usbbackup/diginode_backup/diginode_backup.log
                fi

                #If the DigiAsset settings folder has previously been backed up somewhere else, but not to this stick, note that it is replacing the old backup
                if [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" != "" ]; then
                    do_dgaconfig_backup_now=true
                    printf "%b DigiAsset Settings: This backup will replace the one created on: $DGA_CONFIG_BACKUP_DATE_ON_DIGINODE\\n" "${INFO}"
                    echo "$NEW_BACKUP_DATE DigiAsset Settings: This backup will replace the one created on: $DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" >> /media/usbbackup/diginode_backup/diginode_backup.log
                fi
                
            fi

            # Perform DigiAsset settings backup
            if [ "$do_dgaconfig_backup_now" = true ]; then

                # Backup the existing wallet backup, if it exists
                if [ -d /media/usbbackup/diginode_backup/dga_config_backup ]; then

                    # Delete previous secondary backup folder of DigiAsset, if it exists
                    if [ -d /media/usbbackup/diginode_backup/dga_config_backup_old ]; then
                        str="Deleting existing old backup: dga_config_backup_old ... "
                        printf "%b %s" "${INFO}" "${str}" 
                        rm -rf /media/usbbackup/diginode_backup/dga_config_backup_old
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                        echo "$NEW_BACKUP_DATE DigiAsset Settings: Deleting existing old backup: dga_config_backup_old" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    fi

                    # Rename existing wallet backup folder to old
                    str="Renaming existing dga_config_backup folder to dga_config_backup_old ... "
                    printf "%b %s" "${INFO}" "${str}" 
                    mv /media/usbbackup/diginode_backup/dga_config_backup /media/usbbackup/diginode_backup/dga_config_backup_old
                    echo "$NEW_BACKUP_DATE DigiAsset Settings: Renaming existing dga_config_backup folder to dga_config_backup_old" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    sed -i -e "/^DGA_CONFIG_OLD_BACKUP_DATE_ON_USB_STICK=/s|.*|DGA_CONFIG_OLD_BACKUP_DATE_ON_USB_STICK=\"$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\"|" $DGNT_SETTINGS_FILE
                    sed -i -e "/^DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=/s|.*|DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=\"\"|" $DGNT_SETTINGS_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                fi

                 # Create DigiAsset Settings backup folder
                    if [ ! -d /media/usbbackup/diginode_backup/dga_config_backup ]; then
                        str="Create DigiAsset settings backup folder on USB stick: dga_config_backup ... "
                        printf "%b %s" "${INFO}" "${str}" 
                        mkdir /media/usbbackup/diginode_backup/dga_config_backup
                        echo "$NEW_BACKUP_DATE DigiAsset Settings: Create backup folder on USB stick: dga_config_backup" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi

                # TO DO.......... >>>>>>    

                # Copy DigiAsset Settings to backup stick
                str="Backing up DigiAsset Settings to USB stick ... "
                printf "%b %s" "${INFO}" "${str}" 
                cp $DGA_SETTINGS_LOCATION/*.json /media/usbbackup/diginode_backup/dga_config_backup/
                if [ $? -eq 0 ]; then
                    echo "$NEW_BACKUP_DATE DigiAsset Settings: Backup completed successfully." >> /media/usbbackup/diginode_backup/diginode_backup.log
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    local dga_backup_result="ok"

                    DGA_CONFIG_BACKUP_DATE_ON_USB_STICK="$NEW_BACKUP_DATE"
                    str="Log DigiAsset settings backup date on the USB stick... "
                    printf "%b %s" "${INFO}" "${str}"          
                    sed -i -e "/^DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=/s|.*|DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=\"$NEW_BACKUP_DATE\"|" /media/usbbackup/diginode_backup/diginode_backup.info
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"   

                    DGA_CONFIG_BACKUP_DATE_ON_DIGINODE="$NEW_BACKUP_DATE" 
                    str="Log DigiAsset settings backup date in the DigiNode settings... "
                    printf "%b %s" "${INFO}" "${str}"          
                    sed -i -e "/^DGA_CONFIG_BACKUP_DATE_ON_DIGINODE=/s|.*|DGA_CONFIG_BACKUP_DATE_ON_DIGINODE=\"$NEW_BACKUP_DATE\"|" $DGNT_SETTINGS_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"   
                    
                else
                    echo "$NEW_BACKUP_DATE DigiAsset Settings: Backup failed due to an error." >> /media/usbbackup/diginode_backup/diginode_backup.log
                    printf "%b%b %s FAIL!\\n" "${OVER}" "${CROSS}" "${str}"
                    local dga_backup_result="failed"
                fi

            fi

        fi

        # Display new backup details, if a backup occurred
        if [ "$dgb_backup_result" = "ok" ] || [ "$dga_backup_result" = "ok" ]; then
            if [ -f /media/usbbackup/diginode_backup/diginode_backup.info ]; then
                printf "%b New DigiNode backup on USB stick:\\n" "${INFO}"
                source /media/usbbackup/diginode_backup/diginode_backup.info
                printf "%b DigiByte Wallet backup date: $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\\n" "${INDENT}"
                printf "%b DigiAsset Node backup date: $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\\n" "${INDENT}"
            fi  
        fi

        # Unmount USB stick
        str="Unmount the USB backup stick..."
        printf "%b %s" "${INFO}" "${str}"
        umount /dev/$mount_partition
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Display backup completed messages

        if [ "$dgb_backup_result" = "ok" ] && [ "$dga_backup_result" = "ok" ]; then
            whiptail --msgbox --backtitle "" --title "DigiNode Backup Completed Successfully" "Your DigiByte wallet and DigiAsset settings have been successfully backed up to the USB stick.\\n\\nPlease unplug the backup USB stick now. When you are done press OK." "${r}" "${c}"
        elif [ "$dgb_backup_result" = "ok" ]; then
            whiptail --msgbox --backtitle "" --title "DigiByte Wallet Backup Completed Successfully" "Your DigiByte wallet has been successfully backed up to the USB stick.\\n\\nPlease unplug the backup USB stick now. When you are done press OK." "${r}" "${c}"
        elif [ "$dga_backup_result" = "ok" ]; then
            whiptail --msgbox --backtitle "" --title "DigiAsset Settings Backup Succeeded" "Your DigiAsset Settings have been successfully backed up to the USB stick.\\n\\nPlease unplug the backup USB stick now. When you are done press OK." "${r}" "${c}"
        fi

        # Display backup failed messages

        if [ "$dgb_backup_result" = "failed" ] && [ "$dga_backup_result" = "failed" ]; then
            whiptail --msgbox --backtitle "" --title "DigiNode Backup Failed" "ERROR: Your DigiByte wallet and DigiAsset settings backup failed. Please check the USB stick.\\n\\nPlease unplug the USB stick. When you have done so, press OK." "${r}" "${c}"
        elif [ "$dgb_backup_result" = "failed" ]; then
            whiptail --msgbox --backtitle "" --title "DigiByte Wallet Backup Failed" "ERROR: Your DigiByte wallet backup failed due to an error. Please check the USB stick.\\n\\nPlease unplug the USB stick now. When you have done so, press OK." "${r}" "${c}"
        elif [ "$dga_backup_result" = "failed" ]; then
            whiptail --msgbox --backtitle "" --title "DigiAsset Settings Backup Failed" "ERROR: Your DigiAsset Settings backup failed. Please check the USB stick.\\n\\nPlease unplug the backup USB now. When you have done so, press OK." "${r}" "${c}"
        fi

        # BACKUP FINISHED

        # Tell user to eject backup USB stick, reset variables, and return to the main menu
        printf "%b Backup complete. Returning to menu...\\n" "${INFO}"
        run_wallet_backup=false
        run_dgaconfig_backup=false
        do_wallet_backup_now=false
        do_dgaconfig_backup_now=false
        printf "\\n"
        menu_existing_install

    fi

}

# This function will help the user restore their DigiByte wallet backup and DigiAsset settings from an external USB drive
usb_restore() {

    printf " =============== DigiNode Restore =======================================\\n\\n"
    # ==============================================================================

    # Reset selection variables in case this is not the first time running though the options
    run_wallet_restore=false
    run_dgaconfig_restore=false


    # Introduction to restore.
    if whiptail --backtitle "" --title "DigiNode Restore" "This tool will help you to restore your DigiByte Core wallet and/or DigiAsset Node settings from your USB backup stick.\\n\\nThe USB backup must previously have been made from the DigNode Tools backup menu. Please have your DigiNode USB backup stick ready before continuing. \\n\\nWARNING: If you continue, your current existing wallet and settings will be replaced with the ones on the USB backup. Any funds in the current wallet will be lost!!" --yesno --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then
        printf "%b You chose to begin the restore process.\\n" "${INFO}"
    else
        printf "%b You chose not to begin the restore process. Returning to menu...\\n" "${INFO}"
        printf "\\n"
        menu_existing_install 
    fi

    # Ask the user to insert the USB backup stick and detect it
    cancel_insert_usb=""
    USB_BACKUP_STICK_INSERTED="NO"
    LSBLK_BEFORE_USB_INSERTED=$(lsblk)
    progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
    printf "%b %bPlease insert the USB stick containing your DigiNode backup.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "%b (If it is already plugged in, unplug it, wait a moment, and then\\n" "${INDENT}"
    printf "%b plug it back in so the script can detect it.)\\n" "${INDENT}"
    printf "\\n"
    printf "%b To cancel, press any key.\\n" "${INFO}"
    printf "\\n"
    str="Waiting for USB stick... "
    printf "%b %s" "${INDENT}" "${str}"
    tput civis
    while [ "$USB_BACKUP_STICK_INSERTED" = "NO" ]; do

        # Show Spinner while waiting for USB backup stick
        if [ "$progress" = "[${COL_BOLD_WHITE}◜ ${COL_NC}]" ]; then
          progress="[${COL_BOLD_WHITE} ◝${COL_NC}]"
        elif [ "$progress" = "[${COL_BOLD_WHITE} ◝${COL_NC}]" ]; then
          progress="[${COL_BOLD_WHITE} ◞${COL_NC}]"
        elif [ "$progress" = "[${COL_BOLD_WHITE} ◞${COL_NC}]" ]; then
          progress="[${COL_BOLD_WHITE}◟ ${COL_NC}]"
        elif [ "$progress" = "[${COL_BOLD_WHITE}◟ ${COL_NC}]" ]; then
          progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
        fi

        LSBLK_AFTER_USB_INSERTED=$(lsblk)

        USB_BACKUP_DRIVE=$(diff  <(echo "$LSBLK_BEFORE_USB_INSERTED" ) <(echo "$LSBLK_AFTER_USB_INSERTED") | grep '>' | grep -m1 sd | cut -d' ' -f2)

        if [ "$USB_BACKUP_DRIVE" != "" ]; then

            # Check if USB_BACKUP_DRIVE string starts with └─ or ├─ (this can happen if the user booted the machine with the backup USB stick already inserted)
            # This snippet will clean up the USB_BACKUP_DRIVE variable on that rare occurrence
            #
            # if the string starts with └─, remove it
            if [[ $USB_BACKUP_DRIVE = └─* ]]; then
                cleanup_partion_name=true
                USB_BACKUP_DRIVE=$(echo $USB_BACKUP_DRIVE | sed 's/└─//')
            fi
            # if the string starts with ├─, remove it
            if [[ $USB_BACKUP_DRIVE = ├─* ]]; then
                cleanup_partion_name=true
                USB_BACKUP_DRIVE=$(echo $USB_BACKUP_DRIVE | sed 's/├─//')
            fi
            # if the string ends in a number, remove it
            if [[ $USB_BACKUP_DRIVE = *[0-9] ]]; then
                cleanup_partion_name=true
                USB_BACKUP_DRIVE=$(echo $USB_BACKUP_DRIVE | sed 's/.$//')
            fi 

            printf "%b%b %s USB Stick Inserted: $USB_BACKUP_DRIVE\\n" "${OVER}" "${TICK}" "${str}"
            USB_BACKUP_STICK_INSERTED="YES"
            cancel_insert_usb="no"
            tput cnorm

            # Display partition name cleanup messages
            if [[ $cleanup_partion_name = true ]]; then
                printf "%b (Note: Backup stick was already inserted at boot. If future, do not plug it in until requested or you may encounter errors.)\\n" "${INFO}"
                cleanup_partion_name=false
            fi

        else
            printf "%b%b %s $progress" "${OVER}" "${INDENT}" "${str}"
            LSBLK_BEFORE_USB_INSERTED=$(lsblk)
#               sleep 0.5
            read -t 0.5 -n 1 keypress && cancel_insert_usb="yes" && break
        fi
    done

    # Return to menu if a keypress was detected to cancel inserting a USB
    if [ "$cancel_insert_usb" = "yes" ]; then
        whiptail --msgbox --backtitle "" --title "USB Restore Cancelled." "USB Restore Cancelled." "${r}" "${c}" 
        printf "\\n"
        printf "%b You cancelled the USB backup.\\n" "${INFO}"
        printf "\\n"
        cancel_insert_usb=""
        menu_existing_install
    fi

    # Create mount point for USB stick, if needed
    if [ ! -d /media/usbbackup ]; then
        str="Creating mount point for inserted USB stick..."
        printf "%b %s" "${INFO}" "${str}"
        mkdir /media/usbbackup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Mount USB stick
    local mount_partition=""
    printf "%b Checking USB for suitable partitions...\\n" "${INFO}"
    # Query partprobe to find valid partition
    if [ "$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}2 2>/dev/null)" != "" ]; then
        partition_type=$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}2 2>&1)
        if [ "$(echo $partition_type | grep -Eo "msdos")" = "msdos" ] || [ "$(echo $partition_type | grep -Eo "loop")" = "loop" ]; then
            printf "%b Trying to mount partition ${USB_BACKUP_DRIVE}2...\\n" "${INFO}"
            mount /dev/${USB_BACKUP_DRIVE}2 /media/usbbackup 1>/dev/null
            mount_partition="${USB_BACKUP_DRIVE}2"
        fi
    elif [ "$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}1 2>/dev/null)" != "" ]; then
        partition_type=$(partprobe -d -s /dev/${USB_BACKUP_DRIVE}1 2>&1)
        if [ "$(echo $partition_type | grep -Eo "msdos")" = "msdos" ] || [ "$(echo $partition_type | grep -Eo "loop")" = "loop" ]; then
            printf "%b Trying to mount partition ${USB_BACKUP_DRIVE}1...\\n" "${INFO}"
            mount /dev/${USB_BACKUP_DRIVE}1 /media/usbbackup 1>/dev/null
            mount_partition="${USB_BACKUP_DRIVE}1"
        fi
    else
        printf "%b No suitable partition found. Removing mount point.\\n" "${INFO}"
        rmdir /media/usbbackup
        mount_partition=""
    fi

    # Did the USB stick get mounted successfully?
    str="Did USB stick mount successfully?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$(lsblk | grep -Eo /media/usbbackup)" = "/media/usbbackup" ]; then
        printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"

        # Does USB stick contain an existing backup?
        if [ -f /media/usbbackup/diginode_backup/diginode_backup.info ]; then
            printf "%b Existed DigiNode backup detected on USB stick:\\n" "${INFO}"
            source /media/usbbackup/diginode_backup/diginode_backup.info
            printf "%b DigiByte Wallet backup date: $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\\n" "${INDENT}"
            printf "%b DigiAsset Node backup date: $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\\n" "${INDENT}"
        else
            whiptail --msgbox --backtitle "" --title "DigiNode Backup not found." "The USB stick does not appear to contain a DigiNode backup.\\n\\nPlease unplug the stick and choose OK to return to the main menu.\\n" "${r}" "${c}" 
            printf "\\n"
            printf "%b %bERROR: No DigiNode backup found on stick.%b Returning to menu.\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            cancel_insert_usb=""
            menu_existing_install
        fi

    else
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        whiptail --msgbox --backtitle "" --title "Could not mount USB Stick." "The USB stick could not be mounted. Is this the correct DigiNode backup stick?\\n\\nPlease unplug the stick and choose OK to return to the main menu.\\n" "${r}" "${c}" 
        printf "\\n"
        printf "%b %bERROR: USB stick could not be mounted.%b Returning to menu.\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        cancel_insert_usb=""
        menu_existing_install
    fi

    # Create a variable containing the time and date right now for logging changes
    NOW_DATE=$(date)

    # If the wallet.dat file does not exist on the USB stick, delete the corresponding backup date in the status file (perhaps a previous backup has been manually deleted)
    if [ ! -f /media/usbbackup/diginode_backup/wallet.dat ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" != "" ]; then
        str="wallet.dat has been deleted since last backup. Removing backup date from diginode_backup.info ... "
        printf "%b %s" "${INFO}" "${str}"
        DGB_WALLET_BACKUP_DATE_ON_USB_STICK=""            
        sed -i -e "/^DGB_WALLET_BACKUP_DATE_ON_USB_STICK=/s|.*|DGB_WALLET_BACKUP_DATE_ON_USB_STICK=|" /media/usbbackup/diginode_backup/diginode_backup.info
        echo "$NOW_DATE DigiByte Wallet: wallet.dat has been manually deleted from USB stick- removing previous backup date from diginode_backup.info." >> /media/usbbackup/diginode_backup/diginode_backup.log
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If the dga_config_backup folder does not exist on the USB stick, delete the corresponding backup date in the status file (perhap a previous backup has been manually deleted)
    if [ ! -d /media/usbbackup/diginode_backup/dga_config_backup ] && [ "$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" != "" ]; then
        str="DigiAssets dga_config_backup folder has been deleted from the USB stick since last backup. Removing backup date from diginode_backup.info ... "
        printf "%b %s" "${INFO}" "${str}"  
        DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=""          
        sed -i -e "/^DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=/s|.*|DGA_CONFIG_BACKUP_DATE_ON_USB_STICK=|" /media/usbbackup/diginode_backup/diginode_backup.info
        echo "$NOW_DATE DigiAsset Node Settings: _config folder has been manually deleted from USB stick- removing previous backup date from diginode_backup.info." >> /media/usbbackup/diginode_backup/diginode_backup.log
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # ASK WHAT TO RESTORE

    # Does a local wallet.dat file already exit?
    if [ -f $DGB_SETTINGS_LOCATION/wallet.dat ]; then
        IS_LOCAL_WALLET="YES"
    else
        IS_LOCAL_WALLET="NO"
    fi

    # Setup restore menu text for DigiByte Wallet
    if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ] && [ "$IS_LOCAL_WALLET" = "YES" ]; then
        restore_str="Would you like to restore your DigiByte wallet from the USB backup?\\n\\nThis DigiByte wallet backup was made on:\\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\\n\\nThe current wallet was likely created:\\n  $DGB_INSTALL_DATE\\n\\nWARNING: If you continue your current wallet will be replaced with the one from the USB backup stick and any funds will be lost."
    elif [ "$IS_LOCAL_WALLET" = "NO" ]; then
        restore_str="Would you like to restore your DigiByte wallet from the USB backup?\\n\\nThis DigiByte wallet backup was made on:\\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\\n\\nNote: There is currently no existing wallet on this DigiNode."
    else
        restore_str="Would you like to restore your DigiByte wallet from the USB backup?\\n\\nThis DigiByte wallet backup was made on:\\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\\n\\nThe current wallet was previously backed up on:\\n  $DGB_WALLET_BACKUP_DATE_ON_DIGINODE\\n\\nWARNING: If you continue your current wallet will be replaced with the one on the USB backup stick and any funds will be lost."
    fi

    # Ask to restore the DigiByte Core Wallet backup, if it exists
    if [ -f /media/usbbackup/diginode_backup/wallet.dat ]; then

        # Ask if the user wants to restore their DigiByte wallet
        if whiptail --backtitle "" --title "RESTORE DIGIBYTE CORE WALLET" --yesno "$restore_str" --yes-button "Yes" "${r}" "${c}"; then

            run_wallet_restore=true
        else
            run_wallet_restore=false
        fi
    else
        printf "%b No DigiByte Core wallet backup was found on the USB stick.\\n" "${INFO}"
        run_wallet_restore=false
        # Display a message saying that the wallet.dat file does not exist
        whiptail --msgbox --backtitle "" --title "ERROR: DigiByte wallet backup not found" "No DigiByte Core wallet.dat was found on the USB backup stick so there is nothing to restore." "${r}" "${c}" 
    fi

    # Ask to restore the DigiAsset Node _config folder, if it exists
    if [ -d /media/usbbackup/diginode_backup/dga_config_backup ]; then

        # Ask the user if they want to restore their DigiAsset Node settings
        if whiptail --backtitle "" --title "RESTORE DIGIASSET NODE SETTINGS" --yesno "Would you like to also restore your DigiAsset Node settings?\\n\\nThis will replace your DigiAsset Node _config folder which stores your Amazon web services credentials, RPC password etc.\\n\\nThis DigiAsset settings backup was created:\\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\\n\\nWARNING: If you continue your current existing DigiAsset Node settings will be replaced with the backup."  --yes-button "Yes" "${r}" "${c}"; then

            run_dgaconfig_restore=true
        else
            run_dgaconfig_restore=false
        fi
    else
        printf "%b No DigiAsset Node settings backup was found on the USB stick.\\n" "${INFO}"
        run_dgaconfig_restore=false
        # Display a message saying that the wallet.dat file does not exist
        whiptail --msgbox --backtitle "" --title "ERROR: DigiAsset Node settings backup not found" "No DigiAsset Node settings backup was found on the USB backup stick so there is nothing to restore." "${r}" "${c}" 
    fi

    # Return to main menu if the user has selected to restore neither the wallet nor the DigiAsset config
    if [[ "$run_wallet_restore" == false ]] && [[ "$run_dgaconfig_restore" == false ]]; then
            printf "%b Restore cancelled. Returning to menu...\\n" "${INFO}"
            printf "\\n"
            menu_existing_install
    fi

    # Display start restore messages
    if [[ "$run_wallet_restore" == true ]] && [[ "$run_dgaconfig_restore" == true ]]; then
        printf "%b You chose to restore both your DigiByte wallet and DigiAsset Node settings.\\n" "${INFO}"
    elif [[ "$run_wallet_restore" == true ]] && [[ "$run_dgaconfig_restore" == false ]]; then
        printf "%b You chose to restore only your DigiByte Core wallet.\\n" "${INFO}"
    elif [[ "$run_dgaconfig_restore" == false ]] && [[ "$run_dgaconfig_restore" == true ]]; then
        printf "%b You chose to restore only your DigiAsset Node settings.\\n" "${INFO}"
    fi

        ################################################
        # START DIGIBYTE WALLET RESTORE FROM USB STICK #
        ################################################

    if [ "$run_wallet_restore" = true ]; then

        # Stop the DigiByte service now
        stop_service digibyted


        # Backup the existing "live" wallet, if it exists
        if [ -f "$DGB_SETTINGS_LOCATION/wallet.dat" ]; then

            # Delete previous secondary backup of existing wallet, if it exists
            if [ -f "$DGB_SETTINGS_LOCATION/wallet.dat.old" ]; then
                str="Deleting old local backup: wallet.dat.old ... "
                printf "%b %s" "${INFO}" "${str}" 
                rm $DGB_SETTINGS_LOCATION/wallet.dat.old
                echo "$NOW_DATE DigiByte Wallet: Deleted existing old local backup: wallet.dat.old" >> /media/usbbackup/diginode_backup/diginode_backup.log
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Rename existing wallet backup to .old
            str="Renaming existing local wallet.dat to wallet.dat.old ... "
            printf "%b %s" "${INFO}" "${str}" 
            mv $DGB_SETTINGS_LOCATION/wallet.dat $DGB_SETTINGS_LOCATION/wallet.dat.old
            echo "$NOW_DATE DigiByte Wallet: Renaming local wallet.dat to wallet.dat.old." >> /media/usbbackup/diginode_backup/diginode_backup.log
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        fi

        # Copy backup wallet on USB stick to "live" wallet on DigiNode
        str="Restoring backup DigiByte wallet on USB stick to DigiNode ... "
        printf "%b %s" "${INFO}" "${str}" 
        cp /media/usbbackup/diginode_backup/wallet.dat $DGB_SETTINGS_LOCATION
        if [ $? -eq 0 ]; then
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"           
            echo "$NOW_DATE DigiByte Wallet: Restore completed successfully." >> /media/usbbackup/diginode_backup/diginode_backup.log
            local dgb_restore_result="ok"

            DGB_WALLET_BACKUP_DATE_ON_DIGINODE="$DGB_WALLET_BACKUP_DATE_ON_USB_STICK" 
            str="Logging the originating DigiByte wallet backup date in DigiNode settings... "
            printf "%b %s" "${INFO}" "${str}"          
            sed -i -e "/^DGB_WALLET_BACKUP_DATE_ON_DIGINODE=/s|.*|DGB_WALLET_BACKUP_DATE_ON_DIGINODE=\"$DGB_WALLET_BACKUP_DATE_ON_DIGINODE\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Change file owner to user account
            str="Changing owner of wallet.dat to $USER_ACCOUNT ... "
            printf "%b %s" "${INFO}" "${str}" 
            chown $USER_ACCOUNT:$USER_ACCOUNT $DGB_SETTINGS_LOCATION/wallet.dat
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Change file permissions to user read/write 600
            str="Changing permissions of wallet.dat ... "
            printf "%b %s" "${INFO}" "${str}" 
            chmod 600 $DGB_SETTINGS_LOCATION/wallet.dat
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        else
            printf "%b%b %s FAIL!\\n" "${OVER}" "${CROSS}" "${str}"
            echo "$NOW_DATE DigiByte Wallet: Restore failed due to an error." >> /media/usbbackup/diginode_backup/diginode_backup.log
            local dgb_restore_result="failed"
        fi

        # Stop the DigiByte service now
        restart_service digibyted

    fi

        #################################################
        # START DIGIASSET CONFIG RESTORE FROM USB STICK #
        #################################################

    if [ "$run_dgaconfig_restore" = true ]; then

        printf "%b Stopping DigiAsset Node...\\n" "${INFO}"

        # Stop the DigiAsset Node now
        sudo -u $USER_ACCOUNT pm2 stop digiasset

       # Restore DigiAsset settings to the live location
        if [ -d "$DGA_SETTINGS_LOCATION" ]; then

            # Delete the existing DigiAsset live settings, if they exists
            str="Deleting current DigiAsset Node json configuration files ... "
            printf "%b %s" "${INFO}" "${str}" 
            rm $DGA_SETTINGS_LOCATION/*.json
            echo "$NOW_DATE DigiAsset Settings: Deleting current DigiAsset Node json configuration files" >> /media/usbbackup/diginode_backup/diginode_backup.log
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Restore DigiAsset Settings from backup stick
            str="Restoring DigiAsset Settings from USB stick ... "
            printf "%b %s" "${INFO}" "${str}" 
            cp /media/usbbackup/diginode_backup/dga_config_backup/*.json $DGA_SETTINGS_LOCATION/
            if [ $? -eq 0 ]; then
                echo "$NOW_DATE DigiAsset Settings: Restore completed successfully." >> /media/usbbackup/diginode_backup/diginode_backup.log
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                local dga_restore_result="ok"

                DGA_CONFIG_BACKUP_DATE_ON_DIGINODE="$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK" 
                str="Logging the originating DigiNode settings backup date in DigiNode settings... "
                printf "%b %s" "${INFO}" "${str}"          
                sed -i -e "/^DGA_CONFIG_BACKUP_DATE_ON_DIGINODE=/s|.*|DGA_CONFIG_BACKUP_DATE_ON_DIGINODE=\"$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE\"|" $DGNT_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"   

                # Change _config folder owner to the current user account
                str="Changing owner of _config folder to $USER_ACCOUNT ... "
                printf "%b %s" "${INFO}" "${str}" 
                chown -R $USER_ACCOUNT:$USER_ACCOUNT $DGA_SETTINGS_LOCATION
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                
            else
                echo "$NOW_DATE DigiAsset Settings: Restore failed due to an error." >> /media/usbbackup/diginode_backup/diginode_backup.log
                printf "%b%b %s FAIL!\\n" "${OVER}" "${CROSS}" "${str}"
                local dga_restore_result="failed"
            fi
            printf "\\n"
        else

            # create ~/dga_config_backup/ folder if it does not already exist
            if [ ! -d $DGA_SETTINGS_BACKUP_LOCATION ]; then #
                str="Creating ~/dga_config_backup/ settings folder..."
                printf "%b %s" "${INFO}" "${str}"
                sudo -u $USER_ACCOUNT mkdir $DGA_SETTINGS_BACKUP_LOCATION
                echo "$NOW_DATE DigiAsset Settings: Creating ~/dga_config_backup/ settings folder" >> /media/usbbackup/diginode_backup/diginode_backup.log
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete the existing DigiAsset backup settings, if they exists
            str="Deleting current DigiAsset Node json backup configuration files ... "
            printf "%b %s" "${INFO}" "${str}" 
            rm $DGA_SETTINGS_BACKUP_LOCATION/*.json
            echo "$NOW_DATE DigiAsset Settings: Deleting current DigiAsset Node backup json configuration files" >> /media/usbbackup/diginode_backup/diginode_backup.log
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Restore DigiAsset Settings from backup stick to local backup location
            str="Restoring DigiAsset Settings from USB stick to local backup location ... "
            printf "%b %s" "${INFO}" "${str}" 
            cp /media/usbbackup/diginode_backup/dga_config_backup/*.json $DGA_SETTINGS_BACKUP_LOCATION/
            if [ $? -eq 0 ]; then
                echo "$NOW_DATE DigiAsset Settings: Restore completed successfully." >> /media/usbbackup/diginode_backup/diginode_backup.log
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                local dga_restore_result="ok"

                DGA_CONFIG_BACKUP_DATE_ON_DIGINODE="$DGA_CONFIG_BACKUP_DATE_ON_USB_STICK" 
                str="Logging the originating DigiNode settings backup date in DigiNode settings... "
                printf "%b %s" "${INFO}" "${str}"          
                sed -i -e "/^DGA_CONFIG_BACKUP_DATE_ON_DIGINODE=/s|.*|DGA_CONFIG_BACKUP_DATE_ON_DIGINODE=\"$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE\"|" $DGNT_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"   

                # Change ~/dga_config_backup/ folder owner to the current user account
                str="Changing owner of ~/dga_config_backup/ folder to $USER_ACCOUNT ... "
                printf "%b %s" "${INFO}" "${str}" 
                chown -R $USER_ACCOUNT:$USER_ACCOUNT $DGA_SETTINGS_BACKUP_LOCATION
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                
            else
                echo "$NOW_DATE DigiAsset Settings: Restore failed due to an error." >> /media/usbbackup/diginode_backup/diginode_backup.log
                printf "%b%b %s FAIL!\\n" "${OVER}" "${CROSS}" "${str}"
                local dga_restore_result="failed"
            fi
            printf "\\n"

        fi


        # Now run the digiasset function, to update the RPC credentials in main.json if they are different to what is in digibyte.conf
        digiasset_node_create_settings

    fi

    # Unmount USB stick
    str="Unmount the USB backup stick..."
    printf "%b %s" "${INFO}" "${str}"
    umount /dev/$mount_partition
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Display restore completed messages

    if [ "$dgb_restore_result" = "ok" ] && [ "$dga_restore_result" = "ok" ]; then
        whiptail --msgbox --backtitle "" --title "DigiNode Restore Completed Successfully" "Your DigiByte wallet and DigiAsset settings have been successfully restored from the USB stick.\\n\\nPlease unplug the USB stick now. When you are done press OK." "${r}" "${c}"
    elif [ "$dgb_restore_result" = "ok" ]; then
        whiptail --msgbox --backtitle "" --title "DigiByte Wallet Restore Completed Successfully" "Your DigiByte wallet has been successfully restored from the USB stick.\\n\\nPlease unplug the USB stick now. When you are done press OK." "${r}" "${c}"
    elif [ "$dga_restore_result" = "ok" ]; then
        whiptail --msgbox --backtitle "" --title "DigiAsset Settings Successfully Restored" "Your DigiAsset Settings have been successfully restored from the USB stick.\\n\\nPlease unplug the USB stick now. When you are done press OK." "${r}" "${c}"
    fi

    # Display backup failed messages

    if [ "$dgb_restore_result" = "failed" ] && [ "$dga_restore_result" = "failed" ]; then
        whiptail --msgbox --backtitle "" --title "DigiNode Restore Failed" "ERROR: Your DigiByte wallet and DigiAsset settings restore failed. Please check the USB stick.\\n\\nPlease unplug the USB stick. When you have done so, press OK." "${r}" "${c}"
    elif [ "$dgb_restore_result" = "failed" ]; then
        whiptail --msgbox --backtitle "" --title "DigiByte Wallet Restore Failed" "ERROR: Your DigiByte wallet restore failed due to an error. Please check the USB stick.\\n\\nPlease unplug the USB stick now. When you have done so, press OK." "${r}" "${c}"
    elif [ "$dga_restore_result" = "failed" ]; then
        whiptail --msgbox --backtitle "" --title "DigiAsset Settings Restore Failed" "ERROR: Your DigiAsset Settings restore failed due to an error. Please check the USB stick.\\n\\nPlease unplug the USB stick now. When you have done so, press OK." "${r}" "${c}"
    fi

    # BACKUP FINISHED

    # Tell user to eject backup USB stick, reset variables, and return to the main menu
    printf "%b Restore complete. Returning to menu...\\n" "${INFO}"
    run_wallet_restore=false
    run_dgaconfig_restore=false
    printf "\\n"
    menu_existing_install

}

#check there is sufficient space on the chosen drive to download the blockchain
disk_check() {

    printf " =============== Checking: Disk Space ==================================\\n\\n"
    # ==============================================================================

    # Only run the check if DigiByte Core is not yet installed
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

        if [[ "$DGB_DATA_DISKFREE_KB" -lt "$DGB_DATA_REQUIRED_KB" ]]; then
            printf "%b Disk Space Check: %bFAILED%b   Not enough space available\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b %bWARNING: DigiByte blockchain data will not fit on this drive%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
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
                  printf "%b Unattended Install: Disk Space Check Override DISABLED. Exiting DigiNode Setup...\\n" "${INFO}"
                  printf "\\n"
                  purge_dgnt_settings
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
            PRUNE_BLOCKCHAIN="YES"
        else
          printf "%b %bIMPORTANT: You need to have DigiByte Core prune your blockchain or it will fill up your data drive%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          
          if [ "$TEXTEDITOR" != "" ]; then
                printf "%b You can do this by editing the digibyte.conf file:\\n" "${INDENT}"
                printf "\\n"
                printf "%b   $TEXTEDITOR $DGB_CONF_FILE\\n" "${INDENT}"
                printf "\\n"
                printf "%b Once you have made your changes, re-run DigiNode Setup.\\n" "${INDENT}"
                printf "\\n"
          fi
          exit
        fi
    fi

fi

}

# The menu displayed on first install - asks to install DigiByte Core alone, or also the DigiAsset Node
menu_first_install() {

    printf " =============== INSTALL MENU ==========================================\\n\\n"
    # ==============================================================================

    opt1a="Full DigiNode "
    opt1b=" Install DigiByte & DigiAsset Node (Recommended)"
    
    opt2a="DigiByte Node"
    opt2b=" Install a DigiByte Node ONLY."

    opt3a="DigiAsset Node"
    opt3b=" Install a DigiAsset Node ONLY."

    opt4a="DigiNode Tools"
    opt4b=" Use Status Monitor with an existing DigiByte Node."


    # Display the information to the user
    UpdateCmd=$(whiptail --title "DigiNode Setup - Main Menu" --menu "\\nPlease choose what to install. A FULL DigiNode is recommended.\\n\\nIf you already have a DigiByte Node on this machine, you can install DigiNode Tools ONLY to use the Status Monitor with it.\\n\\nRunning a DigiAsset Node supports the DigiByte network by helping to decentralize DigiAsset metadata. You can also use it to mint your own DigiAssets and earn \$DGB for hosting the community metadata.\\n\\n\\n\\nPlease choose an option:\\n\\n" --cancel-button "Exit" "${r}" 80 4 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" \
    "${opt3a}"  "${opt3b}" \
    "${opt4a}"  "${opt4b}" 3>&2 2>&1 1>&3) || \
    { printf "%b %bExit was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; printf "\\n"; digifact_randomize; digifact_display; printf "\\n"; exit; }

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
        # Install DigiByte Core ONLY
        ${opt3a})
            printf "%b %soption selected\\n" "${INFO}" "${opt2a}"
            printf "\\n"
            install_digiasset_node_only
            ;;
        # Install DigiNode ONLY
        ${opt4a})
            printf "%b %soption selected\\n" "${INFO}" "${opt3a}"
            printf "\\n"
            install_diginode_tools_only
            ;;
    esac
    printf "\\n"
}

# This function will install or upgrade the DigiNode Tools script on this machine
install_diginode_tools_only() {

    # Check and install/upgrade DigiNode Tools
    diginode_tools_check
    diginode_tools_do_install

    # Display closing message
    closing_banner_message

    # Choose a random DigiFact
    digifact_randomize

    # Display a random DigiFact
    digifact_display

    # Display donation QR Code
    donation_qrcode

    printf "%b %b'DigiNode Status Monitor' can be used to monitor your existing DigiByte Node if you have one.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b To run it enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b %b'DigiNode Setup' can now be run locally to upgrade DigiNode Tools or setup your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b To run it enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b Note: If this is your first time installing DigiNode Tools, these aliases will not work yet.\\n" "${INDENT}"
    printf "%b If you are connected over SSH you will need to exit and re-connect before you can use them.\\n" "${INDENT}"
    printf "\\n"

    exit
}

install_digiasset_node_only() {

    # Install packages used by the actual software
    printf " =============== Checking: DigiNode dependencies =======================\\n\\n"
    # ==============================================================================
    
    printf "%b Checking for / installing required dependencies for DigiNode software...\\n" "${INFO}"
    # Check again for supported package managers so that we may install dependencies
    package_manager_detect
    local dep_install_list=("${DIGINODE_DEPS[@]}")
    install_dependent_packages "${dep_install_list[@]}"
    unset dep_install_list

    # Set variable to install DigiAsset Node stuff
    DO_FULL_INSTALL="YES"

    # Prompt for upnp
    menu_ask_upnp

    # Check if IPFS installed, and if there is an upgrade available
    ipfs_check

    # Check if NodeJS installed, and if there is an upgrade available
    nodejs_check

    # Check if DigiAssets Node is installed, and if there is an upgrade available
    digiasset_node_check

    # Check if DigiNode Tools are installed (i.e. these scripts), and if there is an upgrade available
    diginode_tools_check

    ### UPDATES MENU - ASK TO INSTALL ANY UPDATES ###

    # Ask to install any upgrades, if there are any
    menu_ask_install_updates

    ### INSTALL/UPGRADE DIGINODE TOOLS ###

    # Install DigiNode Tools
    diginode_tools_do_install

    ### INSTALL/UPGRADE DIGIASSETS NODE ###

    # Install/upgrade IPFS
    ipfs_do_install

    # Create IPFS service
    ipfs_create_service

    # Install/upgrade NodeJS
    nodejs_do_install

    # Create or update main.json file with RPC credentials
    digiasset_node_create_settings

    # Install DigiAssets along with IPFS
    digiasset_node_do_install

    # Setup PM2 init service
    digiasset_node_create_pm2_service

    ### CHANGE THE HOSTNAME TO DIGINODE ###

    # Check if the hostname is set to 'diginode'
    hostname_check

    # Ask to change the hostname
    hostname_ask_change


    ### CHANGE HOSTNAME LAST BECAUSE MACHINE IMMEDIATELY NEEDS TO BE REBOOTED ###

    # Change the hostname
    hostname_do_change

    # Choose a random DigiFact
    digifact_randomize

    # Display a random DigiFact
    digifact_display

    # Display donation QR Code
    donation_qrcode

    printf "\\n"
    printf "%b %bYour DigiAsset Node should now be accessible via the web UI.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    if [ "$HOSTNAME" = "diginode" ]; then
        printf "%b You can access it at: ${txtbld}http://diginode.local:8090${txtrst}\\n" "${INDENT}"
    else
        printf "%b You can access it at: ${txtbld}http://${IP4_INTERNAL}:8090${txtrst}\\n" "${INDENT}"       
    fi
    printf "\\n"
    if [ "$HOSTNAME" != "diginode" ] && [ "$IP4_EXTERNAL" != "$IP4_INTERNAL" ]; then
        printf "%b If it is running in the cloud, you can try the external IP: ${txtbld}http://${IP4_EXTERNAL}:8090${txtrst}\\n" "${INDENT}"
        printf "\\n"
    fi
    printf "%b %b'DigiNode Tools' can be run locally from the command line.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b To launch 'DigiNode Status Monitor' enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b To launch 'DigiNode Setup' enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b Please note:\\n" "${INFO}"
    printf "\\n"
    printf "%b - If this is your first time installing DigiNode Tools, the above aliases will not work yet.\\n" "${INDENT}"
    printf "%b   If you are connected over SSH you will need to exit and re-connect before you can use it.\\n" "${INDENT}"
    printf "\\n"

    exit

}

lookup_external_ip() {

    # update external IP address and save to settings file
    str="Looking up external IP address..."
    printf "  %b %s" "${INFO}" "${str}"
    IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short)
    if [ $IP4_EXTERNAL_QUERY != "" ]; then
        IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
        sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $DGNT_SETTINGS_FILE
    fi
    printf "  %b%b %s Done!\\n" "  ${OVER}" "${TICK}" "${str}"
    printf "\\n"

}

# Function to display the upgrade menu when a previous install has been detected
menu_existing_install() {

    printf " =============== MAIN MENU =============================================\\n\\n"
    # ==============================================================================

    opt1a="Update"
    opt1b="Check for updates to your DigiNode software."

    opt2a="Backup"
    opt2b="Backup your wallet & settings to a USB stick."

    opt3a="Restore"
    opt3b="Restore your wallet & settings from a USB stick."

    opt4a="Ports"
    opt4b="Enable or disable UPnP to automatically forward ports."

    opt5a="Network"
    opt5b="Change DigiByte network - mainnet or testnet."

    opt6a="Extras"
    opt6b="Install optional extras for your DigiNode."
    
    opt7a="Reset"
    opt7b="Reset all settings and reinstall DigiNode software."

    opt8a="Uninstall"
    opt8b="Remove DigiNode from your system."


    # Display the information to the user
    UpdateCmd=$(whiptail --title "Existing DigiNode Detected!" --menu "\\n\\nAn existing DigiNode has been detected on this system.\\n\\nPlease choose from the following options:\\n\\n" --cancel-button "Exit" "${r}" "${c}" 8 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" \
    "${opt3a}"  "${opt3b}" \
    "${opt4a}"  "${opt4b}" \
    "${opt5a}"  "${opt5b}" \
    "${opt6a}"  "${opt6b}" \
    "${opt7a}"  "${opt7b}" \
    "${opt8a}"  "${opt8b}" 3>&2 2>&1 1>&3 ) || \
    { printf "%b Exit was selected, exiting DigiNode Setup\\n" "${INDENT}"; echo ""; closing_banner_message; digifact_randomize; digifact_display; donation_qrcode; display_system_updates_reminder; backup_reminder; exit; }


    # Set the variable based on if the user chooses
    case ${UpdateCmd} in
        # Update, or
        ${opt1a})
            printf "%b You selected the UPDATE option.\\n" "${INFO}"
            printf "\\n"

            # If DigiAssets Node is installed, we already know this is a full install
            if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
                DO_FULL_INSTALL=YES
            fi
            install_or_upgrade
            ;;
        # USB Stick Backup
        ${opt2a})
            printf "%b You selected the BACKUP option.\\n" "${INFO}"
            printf "\\n"
            usb_backup
            ;;
        # USB Stick Restore
        ${opt3a})
            printf "%b You selected the RESTORE option.\\n" "${INFO}"
            printf "\\n"
            usb_restore
            ;;
        # Change Port forwarding
        ${opt4a})
            printf "%b You selected the PORT FORWARDING option.\\n" "${INFO}"
            printf "\\n"
            change_upnp_status
            ;;
        # Change DigiByte Network - mainet or testnet
        ${opt5a})
            printf "%b You selected the DIGIBYTE NETWORK option.\\n" "${INFO}"
            printf "\\n"
            change_dgb_network
            ;;
        # Extras
        ${opt6a})
            printf "%b You selected the EXTRAS option.\\n" "${INFO}"
            printf "\\n"
            menu_extras
            ;;
        # Reset,
        ${opt7a})
            printf "%b You selected the RESET option.\\n" "${INFO}"
            printf "\\n"
            RESET_MODE=true
            install_or_upgrade
            ;;
        # Uninstall,
        ${opt8a})
            printf "%b You selected the UNINSTALL option.\\n" "${INFO}"
            printf "\\n"
            uninstall_do_now
            ;;
    esac
}

# Function to display the extras menu, which is used to install optional software for the DigiNode
menu_extras() {

    printf " =============== EXTRAS MENU ===========================================\\n\\n"
    # ==============================================================================

    opt1a="Argon One Daemon"
    opt1b="Install fan software for Argon ONE RPi4 case."

    opt2a="Main Menu"
    opt2b="Return to the main menu."


    # Display the information to the user
    UpdateCmd=$(whiptail --title "EXTRAS MENU" --menu "\\n\\nPlease choose from the following options:\\n\\n" --cancel-button "Exit" "${r}" "${c}" 5 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
    { printf "%b Exit was selected, exiting DigiNode Setup\\n" "${INDENT}"; echo ""; closing_banner_message; digifact_randomize; digifact_display; donation_qrcode; backup_reminder; display_system_updates_reminder; exit; }


    # Set the variable based on if the user chooses
    case ${UpdateCmd} in
        # Update, or
        ${opt1a})
            printf "%b You selected the ARGONE ONE DAEMON option.\\n" "${INFO}"
            printf "\\n"
            install_argon_one_fan_software
            ;;
        # USB Stick Backup
        ${opt2a})
            printf "%b You selected the MAIN MENU option.\\n" "${INFO}"
            printf "\\n"
            menu_existing_install
            ;;
    esac
}

# Function to change the current upnp forwarding
change_upnp_status() {

    FORCE_DISPLAY_UPNP_MENU=true

    # If DigiAssets Node is installed, we already know this is a full install
    if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        DO_FULL_INSTALL=YES
    fi

    printf " =============== Checking: DigiByte Node ===============================\\n\\n"
    # ==============================================================================

    # Let's check if DigiByte Node is already installed
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
          DGB_STATUS="stopped"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
      fi
    fi

    printf "\\n"

    printf " =============== Checking: IPFS Node ===================================\\n\\n"
    # ==============================================================================

    # Get the local version number of Kubo (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Let's check if Kubo is already installed
    str="Is Kubo already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: Kubo v${IPFS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Next let's check if IPFS daemon is running with upstart
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
      str="Is Kubo daemon upstart service running?..."
      printf "%b %s" "${INFO}" "${str}"
      if check_service_active "ipfs"; then
          IPFS_STATUS="running"
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
      else
          IPFS_STATUS="stopped"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
      fi
    fi

    # Next let's check if IPFS daemon is running with systemd
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
        str="Is Kubo daemon systemd service running?..."
        printf "%b %s" "${INFO}" "${str}"

        # Check if it is running or not #CHECKLATER
        systemctl is-active --quiet ipfs && IPFS_STATUS="running" || IPFS_STATUS="stopped"

        if [ "$IPFS_STATUS" = "running" ]; then
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$IPFS_STATUS" = "stopped" ]; then
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi

    printf "\\n"

    # Prompt to change upnp status
    menu_ask_upnp

    # Update digibyte.conf
    digibyte_create_conf

    # Restart DigiByte daemon if upnp status has changed
    if [ "$DGB_UPNP_STATUS_UPDATED" = "YES" ]; then

        # Restart Digibyted if the upnp status has just been changed
        if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ] || [ "$DGB_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core UPnP status has been changed. DigiByte daemon will be restarted...\\n" "${INFO}"
            restart_service digibyted
        fi

    fi

    # Set the IPFS upnp values, if we are enabling/disabling the UPnP status
    if [ "$IPFS_ENABLE_UPNP" = "YES" ]; then
        if [ "$UPNP_IPFS_CURRENT" != "false" ]; then
            str="Enabling UPnP port forwarding for Kubo IPFS..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT ipfs config --bool Swarm.DisableNatPortMap "false"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            if [ -f "$USER_HOME/.jsips/config" ]; then
                str="Enabling UPnP port forwarding for JS-IPFS..."
                printf "%b %s" "${INFO}" "${str}"
                update_upnp_now="$(jq ".Swarm.DisableNatPortMap = \"false\"" $DGA_SETTINGS_FILE)" && \
                echo -E "${update_upnp_now}" > $DGA_SETTINGS_FILE
                local jsipfs_upnp_updated="yes"
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi
            IPFS_UPNP_STATUS_UPDATED="YES"
        fi
    elif [ "$IPFS_ENABLE_UPNP" = "NO" ]; then
        if [ "$UPNP_IPFS_CURRENT" != "true" ]; then
            str="Disabling UPnP port forwarding for Kubo IPFS..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT ipfs config --bool Swarm.DisableNatPortMap "true"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            if [ -f "$USER_HOME/.jsips/config" ]; then
                str="Disabling UPnP port forwarding for JS-IPFS..."
                printf "%b %s" "${INFO}" "${str}"
                update_upnp_now="$(jq ".Swarm.DisableNatPortMap = \"true\"" $DGA_SETTINGS_FILE)" && \
                echo -E "${update_upnp_now}" > $DGA_SETTINGS_FILE
                local jsipfs_upnp_updated="yes"
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi
            IPFS_UPNP_STATUS_UPDATED="YES"
        fi
    fi 

    if [ "$IPFS_UPNP_STATUS_UPDATED" = "YES" ]; then

        # Restart Kubo IPFS if the upnp status has just been changed
        if [ "$IPFS_STATUS" = "running" ] || [ "$IPFS_STATUS" = "stopped" ]; then

            # Restart IPFS if the upnp status has just been changed
            printf "%b Kubo IPFS UPnP status has been changed. IPFS daemon will be restarted...\\n" "${INFO}"
            restart_service ipfs
        fi

        # Restart DigiAsset Node if the JS-IPFS upnp status has just been changed
        if [ "$jsipfs_upnp_updated" = "yes" ]; then

            # Restart IPFS if the upnp status has just been changed
            printf "%b JS-IPFS UPnP status has been changed. DigiAsset Node will be restarted...\\n" "${INFO}"
            pm2 restart digiasset
        fi

    fi

    printf "\\n"


    FORCE_DISPLAY_UPNP_MENU=false
    DGB_UPNP_STATUS_UPDATED=""
    IPFS_UPNP_STATUS_UPDATED=""
    jsipfs_upnp_updated=""

    menu_existing_install

}

# Function to change the current DigiByte Network between MAINNET and TESTNET
change_dgb_network() {

    FORCE_DISPLAY_DGB_NETWORK_MENU=true

    # If DigiAssets Node is installed, we already know this is a full install
    if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        DO_FULL_INSTALL=YES
    fi

    # Check to see if DigiByte Core is running or not, and find out which network (mainnet/testnet) it is currently using
    digibyte_check

    # Prompt to change dgb network
    menu_ask_dgb_network

    # Update digibyte.conf
    digibyte_create_conf

    # Restart DigiByte daemon if dgb network has changed
    if [ "$DGB_NETWORK_IS_CHANGED" = "YES" ]; then

        # Restart Digibyted if the upnp status has just been changed
        if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ] || [ "$DGB_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core network has been changed. DigiByte daemon will be restarted...\\n" "${INFO}"
            restart_service digibyted
        fi

    fi

    # Run IPFS cehck to discover the current ports that are being used
    ipfs_check

    # update IPFS ports
    ipfs_update_port


    if [ "$kuboipfs_port_has_changed" = "yes" ]; then

        # Restart Kubo IPFS if the IPFS port has just been changed
        if [ "$IPFS_STATUS" = "running" ] || [ "$IPFS_STATUS" = "stopped" ]; then

            # Restart IPFS if the Kubo IPFS has just been changed
            printf "%b Kubo IPFS port has been changed. IPFS daemon will be restarted...\\n" "${INFO}"
            restart_service ipfs
        fi

    fi

    if [ "$jsipfs_port_has_changed" = "yes" ]; then

        # Restart IPFS if the upnp status has just been changed
        printf "%b JS-IPFS port has been changed. DigiAsset Node will be restarted...\\n" "${INFO}"
        pm2 restart digiasset

    fi

    printf "\\n"

    # Get the default listening port number, if it is not manually set in digibyte.conf
    if [ "$port" = "" ]; then
        if [ "$testnet" = "1" ]; then
            port="12026"
        else
            port="12024"
        fi
    fi 

    # Display alert box informing the user that listening port and rpcport have changed.
    if [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$testnet" = "1" ]; then
        whiptail --msgbox --title "You are now running on the DigiByte testnet!" "Your DigiByte Node has been changed to run on TESTNET.\\n\\nYour listening port is now $port. If you have not already done so, please open this port on your router.\\n\\nYour RPC port is now $rpcport. This will have been changed if you were previously using the default port 14022 on mainnet." 20 "${c}"

            # Prompt to delete the mainnet blockchain data if it already exists
            if [ -d "$DGB_DATA_LOCATION/indexes" ] || [ -d "$DGB_DATA_LOCATION/chainstate" ] || [ -d "$DGB_DATA_LOCATION/blocks" ]; then

                # Delete DigiByte blockchain data
                if whiptail --backtitle "" --title "Delete mainnet blockchain data?" --yesno "Would you like to delete the DigiByte mainnet blockchain data, since you are now running on testnet?\\n\\nDeleting it will free up disk space on your device, but if you later decide to switch back to running on mainnet, you will need to re-sync the entire mainnet blockchain which can take several days.\\n\\nNote: Your mainnet wallet will be kept." 15 "${c}"; then

                    if [ -d "$DGB_DATA_LOCATION" ]; then
                        str="Deleting DigiByte Core MAINNET blockchain data..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf $DGB_DATA_LOCATION/indexes
                        rm -rf $DGB_DATA_LOCATION/chainstate
                        rm -rf $DGB_DATA_LOCATION/blocks
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi
                    printf "\\n"

                else
                    printf "%b You chose to keep the existing DigiByte mainnet blockchain data.\\n" "${INFO}"
                    printf "\\n"
                fi
            fi

    elif [ "$DGB_NETWORK_IS_CHANGED" = "YES" ]; then
        if [ "$testnet" = "0" ] || [ "$testnet" = "" ]; then
            whiptail --msgbox --title "You are now running on the DigiByte mainnet!" "Your DigiByte Node has been changed to run on MAINNET.\\n\\nYour listening port is now $port. If you have not already done so, please open this port on your router.\\n\\nYour RPC port is now $rpcport. This will have been changed if you were previously using the default port 14023 on testnet." 20 "${c}"

            # Prompt to delete the testnet blockchain data if it already exists
            if [ -d "$DGB_DATA_LOCATION/testnet4/indexes" ] || [ -d "$DGB_DATA_LOCATION/testnet4/chainstate" ] || [ -d "$DGB_DATA_LOCATION/testnet4/blocks" ]; then

                # Delete DigiByte blockchain data
                if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to delete the DigiByte testnet blockchain data, since you are now running on mainnet?\\n\\nDeleting it will free up disk space on your device, but if you later decide to switch back to running on testnet, you will need to re-sync the entire testnet blockchain which can take several hours.\\n\\nNote: Your testnet wallet will be kept." 15 "${c}"; then

                    if [ -d "$DGB_DATA_LOCATION/testnet4" ]; then
                        str="Deleting DigiByte Core TESTNET blockchain data..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf $DGB_DATA_LOCATION/testnet4/indexes
                        rm -rf $DGB_DATA_LOCATION/testnet4/chainstate
                        rm -rf $DGB_DATA_LOCATION/testnet4/blocks
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi
                    printf "\\n"

                else
                    printf "%b You chose to keep the existing DigiByte mainnet blockchain data.\\n" "${INFO}"
                    printf "\\n"
                fi
            fi
        fi    
    fi

    # Check hostname
    hostname_check

    hostname_ask_change

    hostname_do_change

    ### WRAP UP ###

    # Display closing message
    closing_banner_message

    if [[ "${NewInstall}" == false ]]; then

        # Choose a random DigiFact
        digifact_randomize

        # Display a random DigiFact
        digifact_display

    fi

    # Display donation QR Code
    donation_qrcode

    # Show final messages - Display reboot message (and how to run Status Monitor)
    final_messages

    # Share backup reminder
    backup_reminder

    exit

}


# A function for displaying the dialogs the user sees when first running DigiNode Setup
welcomeDialogs() {
    # Display the welcome dialog using an appropriately sized window via the calculation conducted earlier in the script
    whiptail --msgbox --backtitle "" --title "Welcome to DigiNode Setup" "DigiNode Setup will help you to setup and manage a DigiByte Node and a DigiAsset Node on this device.\\n\\nRunning a DigiByte Full Node means you have a complete copy of the DigiByte blockchain on your device and are helping contribute to the decentralization and security of the blockchain network.\\n\\nWith a DigiAsset Node you are helping to decentralize and redistribute DigiAsset metadata. It also gives you the ability to create your own DigiAssets via the built-in web UI, and additionally lets you earn DGB in exchange for hosting the DigiAsset metadata of others. \\n\\nTo learn more, visit: $DGBH_URL_INTRO" "${r}" "${c}"

# Request that users donate if they find DigiNode Setup useful
donationDialog

# Explain the need for a static address
if whiptail --defaultno --backtitle "" --title "Your DigiNode needs a Static IP address." --yesno "IMPORTANT: Your DigiNode is a SERVER so it needs a STATIC IP ADDRESS to function properly.\\n\\nIf you have not already done so, you must ensure that this device has a static IP address on the network. This can be done through DHCP reservation, or by manually assigning one. Depending on your operating system, there are many ways to achieve this.\\n\\nThe current IP address is: $IP4_INTERNAL\\n\\nFor more help, please visit: $DGBH_URL_STATICIP\\n\\nChoose Continue to indicate that you have understood this message." --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then
#Nothing to do, continue
  printf "%b You acknowledged that your system requires a Static IP Address.\\n" "${INFO}"
  printf "\\n"
else
  printf "%b DigiNode Setup exited at static IP message.\\n" "${INFO}"
  printf "\\n"
  exit
fi

}

# Request that users donate if they find DigiNode Setup useful
donationDialog() {

whiptail --msgbox --backtitle "" --title "DigiNode Tools is FREE and OPEN SOURCE" "Please donate to support future development:
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
}


# If this is the first time running DigiNode Setup, and the diginode.settings file has just been created,
# ask the user if they want to EXIT to customize their install settings.

ask_customize() {

if [ "$IS_DGNT_SETTINGS_FILE_NEW" = "YES" ]; then

    if whiptail --backtitle "" --title "Do you want to customize your DigiNode installation?" --yesno "Before proceeding, you may wish to edit the diginode.settings file that has just been created in the ~/.digibyte folder.\\n\\nThis is for advanced users who want to customize their install, such as to change the location of where the DigiByte blockchain data is stored.\\n\\nIn most cases, there should be no need to do this, and you can safely continue with the defaults.\\n\\nFor more information on customizing your installation, visit: $DGBH_URL_CUSTOM\\n\\n\\nTo proceed with the defaults, choose Continue (Recommended)\\n\\nTo exit and customize your installation, choose Exit" --no-button "Exit" --yes-button "Continue" "${r}" "${c}"; then
    #Nothing to do, continue
      printf ""
    else
        printf "%b You exited the installler at the customization message.\\n" "${INFO}"
        printf "\\n"
        printf "%b %bTo customize your DigiNode install, please edit the diginode.settings file.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        if [ "$TEXTEDITOR" != "" ]; then
            printf "%b Do this by entering:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   $TEXTEDITOR $DGNT_SETTINGS_FILE\\n" "${INDENT}"
            printf "\\n"
            printf "%b Once you have made your changes, re-run DigiNode Setup.\\n" "${INDENT}"
        fi
        printf "%b For more help go to: $DGBH_URL_CUSTOM\\n"  "${INDENT}"
        printf "\\n"
        exit
    fi

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
        printf " =============== Install: DigiByte daemon service ======================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_SERVICE_INSTALL_TYPE" = "update" ]; then
        printf " =============== Update: DigiByte daemon service =======================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_SERVICE_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: DigiByte daemon service ========================\\n\\n"
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
description "DigiByte Daemon"

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

closing_banner_message() {  

    if [ "$NewInstall" = true ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf " =======================================================================\\n"
        printf " ======== ${txtgrn}Congratulations - Your DigiNode has been installed!${txtrst} ==========\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo "                    Thanks for supporting DigiByte!"
        echo ""
        echo "   Please let everyone know what you are helping support the DigiByte network"
        echo "   by sharing on social media using the hashtag #DigiNode"
        echo ""
    elif [ "$NewInstall" = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf " =======================================================================\\n"
        printf " ======== ${txtgrn}DigiByte Node has been installed!${txtrst} ============================\\n"
        printf " =======================================================================\\n\\n"
        # ================================================================================================
        echo "      Thanks for supporting DigiByte by running a DigiByte full node!"
        echo ""
        echo "  If you want to help even more, please consider also running a DigiAsset Node"
        echo "  as well. You can run DigiNode Setup again at any time to upgrade to a full"
        echo "  DigiNode."
        echo ""
    elif [ "$RESET_MODE" = true ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf " =======================================================================\\n"
        printf " ================== ${txtgrn}DigiNode has been Reset!${txtrst} ===========================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo ""
    elif [ "$RESET_MODE" = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf " =======================================================================\\n"
        printf " ================== ${txtgrn}DigiByte Node has been Reset!${txtrst} ======================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo ""
    elif [ "$DO_FULL_INSTALL" = "YES" ]; then
        if [ "$DIGINODE_UPGRADED" = "YES" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiNode has been Upgraded!${txtrst} ========================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        else
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiNode is up to date!${txtrst} ============================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        fi
    elif [ "$DO_FULL_INSTALL" = "NO" ]; then
        if [ "$DIGINODE_UPGRADED" = "YES" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiByte Node has been Upgraded!${txtrst} ===================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        else
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiByte Node is up to date!${txtrst} =======================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        fi
    else
        if [ "$DGNT_INSTALL_TYPE" = "new" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiNode Tools have been installed!${txtrst} ================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "upgrade" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiNode Tools have been upgraded!${txtrst} =================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "none" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiNode Tools are up to date!${txtrst} =====================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "reset" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtgrn}DigiNode Tools have been reset!${txtrst} ====================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        fi
    fi
}


donation_qrcode() {  

    printf " ============== ${txtgrn}Please DONATE to support DigiNode Tools${txtrst} ================\\n\\n"
    # ==============================================================================

    echo "    I have built DigiNode Tools with the objective of making it easy for everyone"
    echo "    in the DigiByte community to run their own full node. Thousands of"
    echo "    unpaid hours have already gone into its development. If you find DigiNode"
    echo "    Tools useful, please make a donation to support future development."
    echo "    Thank you for your support, Olly.  >> Find me on Twitter @saltedlolly <<"
    echo ""
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

# Backup reminder
backup_reminder() { 

    # Only display this once DigiNode is already installed
    if [ "$NewInstall" != true ]; then

        # Lookup current wallet balance
        WALLET_BALANCE=$(digibyte-cli getbalance 2>/dev/null)
        # If the wallet balance is 0, then set the value to "" so it is hidden
        if [ "$WALLET_BALANCE" = "0.00000000" ]; then
            WALLET_BALANCE=""
        fi

        # If this is a full install, and no backup exists
        if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ] && [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" = "" ] && [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ] && [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ] && [ "$WALLET_BALANCE" != "" ]; then

            printf "%b %bReminder: Don't forget to backup your DigiNode%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b You can use 'DigiNode Setup' to backup your DigiByte wallet & DigiAsset Node settings\\n" "${INDENT}"
            printf "%b to a USB stick.\\n" "${INDENT}"
            printf "\\n"
        fi

        # If this is a full install, and the DigiByte wallet has been backed up but not DigiAsset settings
        if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" != "" ] && [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" = "" ] && [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then

            printf "%b %bReminder: Don't forget to backup your DigiAsset Node settings%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b You currently only have a USB backup of your DigiByte wallet. It is reccomended to also=\\n" "${INDENT}"
            printf "%b backup your DigiAsset Node settings. You can do this using 'DigiNode Setup'.\\n" "${INDENT}"
            printf "\\n"
        fi

        # If only DigiByte core is installed, but not DigiAsset Node, and no wallet backup had been done
        if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ] && [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ] && [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ] && [ "$WALLET_BALANCE" != "" ]; then

            printf "%b %bReminder: Don't forget to backup your DigiByte wallet%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b You can use 'DigiNode Setup' to backup your DigiByte wallet to a USB stick.\\n" "${INDENT}"
            printf "\\n"
        fi

    fi

}

final_messages() {  

    # Deduce what they new hostname will be after reboot
    if [ "$NEW_HOSTNAME" = "diginode" ]; then
        HOSTNAME_AFTER_REBOOT="diginode"
    elif [ "$NEW_HOSTNAME" = "diginode-testnet" ]; then
        HOSTNAME_AFTER_REBOOT="diginode-testnet"
    elif [ "$HOSTNAME" = "diginode" ]; then
        HOSTNAME_AFTER_REBOOT="diginode"
    elif [ "$HOSTNAME" = "diginode-testnet" ]; then
        HOSTNAME_AFTER_REBOOT="diginode-testnet"
    fi


    if [ "$DO_FULL_INSTALL" = "YES" ]; then 
        printf "\\n"
        printf "%b %bYour DigiAsset Node should now be accessible via the web UI.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"

        if [ "$HOSTNAME_AFTER_REBOOT" = "diginode" ] || [ "$HOSTNAME_AFTER_REBOOT" = "diginode-testnet" ]; then
            printf "%b You can access it at: ${txtbld}http://${HOSTNAME_AFTER_REBOOT}.local:8090${txtrst}\\n" "${INDENT}"
        else
            printf "%b You can access it at: ${txtbld}http://${IP4_INTERNAL}:8090${txtrst}\\n" "${INDENT}"       
        fi
        printf "\\n"
        if [ "$HOSTNAME_AFTER_REBOOT" != "diginode" ] || [ "$HOSTNAME_AFTER_REBOOT" != "diginode-testnet" ]; then
            if [ "$IP4_EXTERNAL" != "$IP4_INTERNAL" ]; then
                printf "%b If it is running in the cloud, you can try the external IP: ${txtbld}https://${IP4_EXTERNAL}:8090${txtrst}\\n" "${INDENT}"
                printf "\\n" 
            fi
        fi   
    fi

    if [ "$PRUNE_BLOCKCHAIN" = "YES" ]; then
          printf "%b %bIMPORTANT: Remember to have DigiByte Core prune your blockchain or it will fill up your data drive%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        if [ "$TEXTEDITOR" != "" ]; then
            printf "%b You can do this by editing the digibyte.conf file:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   $TEXTEDITOR $DGB_CONF_FILE\\n" "${INDENT}"
            printf "\\n"
        fi
    fi

    if [ $NewInstall = true ]; then
        printf "%b %b'DigiNode Tools' can be run locally from the command line.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To launch 'DigiNode Status Monitor' enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b To launch 'DigiNode Setup' enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b Note: If this is your first time installing DigiNode Tools, these aliases will not work until you reboot.\\n" "${INDENT}"
        printf "\\n"
    elif [ "$RESET_MODE" = true ]; then
        printf "%b %bAfter performing a reset, it is advisable to reboot your system.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: ${txtbld}sudo reboot${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b %b'DigiNode Tools' can be run locally from the command line.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To launch 'DigiNode Status Monitor' enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b To launch 'DigiNode Setup' enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
        printf "\\n"
    else
        if [ "$STATUS_MONITOR" = "false" ] && [ "$DGNT_RUN_LOCATION" = "remote" ]; then
            printf "%b %b'DigiNode Tools' can be run locally from the command line.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b To launch 'DigiNode Status Monitor' enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
            printf "\\n"
            printf "%b To launch 'DigiNode Setup' enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
            printf "\\n"
        fi

        display_system_updates_reminder

    fi

    # Display restart messages, if needed
    if [ "$HOSTNAME_DO_CHANGE" = "YES" ]; then
        printf "%b %bYour hostname has been changed. You need to reboot now for the change to take effect.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: ${txtbld}sudo reboot${txtrst}\\n" "${INDENT}"
        printf "\\n"
        if [ "$HOSTNAME_AFTER_REBOOT" = "diginode" ] || [ "$HOSTNAME_AFTER_REBOOT" = "diginode-testnet" ]; then
            printf "%b Once rebooted, reconnect over SSH with: ${txtbld}ssh ${USER_ACCOUNT}@${HOSTNAME_AFTER_REBOOT}.local${txtrst}\\n" "${INDENT}"
        else
            printf "%b Once rebooted, reconnect over SSH with: ${txtbld}ssh ${USER_ACCOUNT}@${IP4_INTERNAL}${txtrst}\\n" "${INDENT}"       
        fi
        printf "\\n"
    elif [ "$REBOOT_NEEDED" = "YES" ]; then
        printf "%b %bYou need to reboot now for your swap file change to take effect.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: ${txtbld}sudo reboot${txtrst}\\n" "${INDENT}"
        printf "\\n"
        if [ "$HOSTNAME_AFTER_REBOOT" = "diginode" ] || [ "$HOSTNAME_AFTER_REBOOT" = "diginode-testnet" ]; then
            printf "%b Once rebooted, reconnect over SSH with: ${txtbld}ssh ${USER_ACCOUNT}@${HOSTNAME_AFTER_REBOOT}.local${txtrst}\\n" "${INDENT}"
        else
            printf "%b Once rebooted, reconnect over SSH with: ${txtbld}ssh ${USER_ACCOUNT}@${IP4_INTERNAL}${txtrst}\\n" "${INDENT}"       
        fi
        printf "\\n"       
    elif [ $NewInstall = true ]; then
        printf "%b %bYou need to reboot your system so that the above aliases will work.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: ${txtbld}sudo reboot${txtrst}\\n" "${INDENT}"
        printf "\\n"
        if [ "$HOSTNAME_AFTER_REBOOT" = "diginode" ] || [ "$HOSTNAME_AFTER_REBOOT" = "diginode-testnet" ]; then
            printf "%b Once rebooted, reconnect over SSH with: ${txtbld}ssh ${USER_ACCOUNT}@${HOSTNAME_AFTER_REBOOT}.local${txtrst}\\n" "${INDENT}"
        else
            printf "%b Once rebooted, reconnect over SSH with: ${txtbld}ssh ${USER_ACCOUNT}@${IP4_INTERNAL}${txtrst}\\n" "${INDENT}"       
        fi
        printf "\\n"       
    fi

    if [ "$INSTALL_ERROR" = "YES" ] && [ $NewInstall = true ]; then
        printf "%b %bWARNING: One or more software downloads had errors!%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b Your DigiNode may not be fully functional. Try running DigiNode Setup again.\\n" "${INDENT}"
        printf "%b If the problem persists, please reach out to @digibytehelp on Twitter.\\n" "${INDENT}"
        printf "\\n"
    fi

    if [ "$INSTALL_ERROR" = "YES" ] && [ $NewInstall = false ]; then
        printf "%b %bWARNING: One or more DigiNode updates could not be downloaded.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b There were errors when downloading updates. Try running DigiNode Setup again.\\n" "${INDENT}"
        printf "%b If the problem persists, please reach out to @digibytehelp on Twitter.\\n" "${INDENT}"
        printf "\\n"
    fi

}

display_system_updates_reminder() {

    if [ "$system_updates_available" = "yes" ]; then
        printf "%b %bThere are system updates available for your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To install them now enter: ${txtbld}sudo apt-get upgrade${txtrst}\\n" "${INDENT}"
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
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
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
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
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
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
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
    printf "%b%b %s...\\n" "${OVER}" "${TICK}" "${str}"
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



# This function will ask the user if they want to install a DigiByte testnode node or just a mainnet node
menu_ask_dgb_network() {

local show_dgb_network_menu="no"

# FIRST DECIDE WHTHER TO SHOW THE DGB NETWORK MENU

# If digibyte.conf file does not exist yet, show the dgb network menu
if [ ! -f "$DGB_CONF_FILE" ]; then
    show_dgb_network_menu="yes"
fi

# If digibyte.conf file already exists, show the dgb network menu if it does not contain the testnet variable
if [ -f "$DGB_CONF_FILE" ]; then

        # Update testnet status in settings if it exists and is blank, otherwise append it
        if grep -q "testnet=1" $DGB_CONF_FILE; then
            show_dgb_network_menu="maybe"
        elif grep -q "testnet=0" $DGB_CONF_FILE; then
            show_dgb_network_menu="maybe"
        elif grep -q "testnet=" $DGB_CONF_FILE; then
            show_dgb_network_menu="yes"
        else
            show_dgb_network_menu="yes"
        fi
fi

# If this is a new install and the testnet values already exist
if [ "$show_dgb_network_menu" = "maybe" ] && [ "$NewInstall" = true ]; then
    show_dgb_network_menu="yes"
fi

# If we are running this from the main menu, always show the menu prompts
if [ "$show_dgb_network_menu" = "maybe" ] && [ "$FORCE_DISPLAY_DGB_NETWORK_MENU" = true ]; then
    show_dgb_network_menu="yes"
fi



# SHOW DGB NETWORK MENU

# Don't ask if we are running unattended
if [ ! "$UNATTENDED_MODE" == true ]; then

    # Display dgb network section break
    if [ "$show_dgb_network_menu" = "yes" ]; then

            printf " =============== DIGIBYTE NETWORK SELECTION ============================\\n\\n"
            # ==============================================================================

    fi


    # SHOW THE DGB NETWORK MENU FOR ANEW INSTALL
    if [ "$show_dgb_network_menu" = "yes" ] && [ "$NewInstall" = true ]; then

        if whiptail --backtitle "" --title "DIGIBYTE NETWORK SELECTION" --yesno "Would you like to run this DigiByte full node on mainnet or testnet?\\n\\nThe testnet network is used by developers for testing. It is functionally identical to the mainnet network, except the DigiByte on it are worthless.\\n\\nUnless you are a developer, your first priority should always be to run a mainnet node. However, to support the DigiByte network even further, you can also run a testnet node. By doing so, you are helping developers building on the DigiByte blockchain, and is another great way to support the network." --yes-button "Mainnet (Recommended)" --no-button "Testnet" "${r}" "${c}"; then
            printf "%b You chose to setup DigiByte Core on MAINNET.\\n" "${INFO}"
            DGB_NETWORK_FINAL="MAINNET"
        #Nothing to do, continue
        else
            printf "%b You chose to setup DigiByte Core on TESTNET.\\n" "${INFO}"
            DGB_NETWORK_FINAL="TESTNET"
        fi
        printf "\\n"

    # SHOW THE DGB NETWORK MENU FOR AN EXISTING TESTNET INSTALL
    elif [ "$show_dgb_network_menu" = "yes" ] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then

        if whiptail --backtitle "" --title "DIGIBYTE NETWORK SELECTION" --yesno "DigiByte Core is currently set to run on the TESTNET network.\\n\\nWould you like to switch it to use the MAINNET network?\\n\\nThe testnet network is used by developers for testing. It is functionally identical to the mainnet network, except the DigiByte on it are worthless.\\n\\nUnless you are a developer, your first priority should always be to run a mainnet node. However, to support the DigiByte network even further, you can also run a testnet node. By doing so, you are helping developers building on the DigiByte blockchain, and is another great way to support the network." --yes-button "Switch to MAINNET" --no-button "Cancel" "${r}" "${c}"; then
            printf "%b You chose to switch DigiByte Core to run MAINNET.\\n" "${INFO}"
            DGB_NETWORK_FINAL="MAINNET"
        #Nothing to do, continue
        else
            printf "%b You chose to leave DigiByte Core on TESTNET. Returning to menu...\\n" "${INFO}"
            DGB_NETWORK_FINAL="TESTNET"
            menu_existing_install 
        fi
        printf "\\n"

    # SHOW THE DGB NETWORK MENU FOR AN EXISTING MAINNET INSTALL
    elif [ "$show_dgb_network_menu" = "yes" ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then

        if whiptail --backtitle "" --title "DIGIBYTE NETWORK SELECTION" --yesno "DigiByte Core is currently set to run on the MAINNET network.\\n\\nWould you like to switch it to use the TESTNET network?\\n\\nThe testnet network is used by developers for testing. It is functionally identical to the mainnet network, except the DigiByte on it are worthless.\\n\\nUnless you are a developer, your first priority should always be to run a mainnet node. However, to support the DigiByte network even further, you can also run a testnet node. By doing so, you are helping developers building on the DigiByte blockchain, and is another great way to support the network." --yes-button "Switch to TESTNET" --no-button "Cancel" "${r}" "${c}"; then
            printf "%b You chose to switch DigiByte Core to run TESTNET.\\n" "${INFO}"
            DGB_NETWORK_FINAL="TESTNET"
        #Nothing to do, continue
        else
            printf "%b You chose to leave DigiByte Core on MAINNET. Returning to menu...\\n" "${INFO}"
            DGB_NETWORK_FINAL="MAINNET"
            menu_existing_install 
        fi
        printf "\\n"

    elif [ "$show_dgb_network_menu" = "no" ]; then

        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
            DGB_NETWORK_FINAL="MAINNET"
        elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
            DGB_NETWORK_FINAL="TESTNET"
        fi

    fi

else


    # If we are running unattended, and the script wants to prompt the user with the dgb network menu, then get the values from diginode.settings

    # Display digibyte network section break
    if [ "$show_dgb_network_menu" = "yes" ]; then

        printf " =============== Unattended Mode: Set DigiByte Core Network ============\\n\\n"
        # ==============================================================================


        if [ "$UI_DGB_NETWORK" = "MAINNET" ]; then

            printf "%b Unattended Mode: DigiByte Core will run MAINNET\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_NETWORK value in diginode.settings)\\n" "${INDENT}"
            DGB_NETWORK_FINAL="MAINNET"

        elif [ "$UI_DGB_NETWORK" = "TESTNET" ]; then

            printf "%b Unattended Mode: DigiByte Core will run TESTNET" "${INFO}"
            printf "%b                  (Set from UI_DGB_NETWORK value in diginode.settings)\\n" "${INDENT}"
            DGB_NETWORK_FINAL="TESTNET"

        else

            printf "%b Unattended Mode: Skipping changing the DigiByte Core network. It will remain on $DGB_NETWORK_CURRENT.\\n" "${INFO}"

            if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
                DGB_NETWORK_FINAL="MAINNET"
            elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
                DGB_NETWORK_FINAL="TESTNET"
            fi

        fi

        printf "\\n"

    else

        printf " =============== Unattended Mode: Set DigiByte Core Network ============\\n\\n"
        # ==============================================================================        

        # If we are not changing the DigiByte network, then set the final as current

        printf "%b Unattended Mode: Skipping changing the DigiByte Core network. It will remain on $DGB_NETWORK_CURRENT.\\n" "${INFO}"

        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
            DGB_NETWORK_FINAL="MAINNET"
        elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
            DGB_NETWORK_FINAL="TESTNET"
        fi
  
        printf "\\n"

    fi

fi

}



# This function will ask the user if they want to enable or disbale upnp for digibyte core and/or ipfs
menu_ask_upnp() {

local show_dgb_upnp_menu="no"
local show_ipfs_upnp_menu="no"

# FIRST DECIDE WHTHER TO SHOW THE UPNP MENU

# If digibyte.conf file does not exist yet, show the upnp menu
if [ ! -f "$DGB_CONF_FILE" ]; then
    show_dgb_upnp_menu="yes"
fi

# If digibyte.conf file already exists, show the upnp menu if it does not contain upnp variables
if [ -f "$DGB_CONF_FILE" ]; then

        # Update upnp status in settings if it exists and is blank, otherwise append it
        if grep -q "upnp=1" $DGB_CONF_FILE; then
            show_dgb_upnp_menu="maybe"
            UPNP_DGB_CURRENT=1
        elif grep -q "upnp=0" $DGB_CONF_FILE; then
            show_dgb_upnp_menu="maybe"
            UPNP_DGB_CURRENT=0
        elif grep -q "upnp=" $DGB_CONF_FILE; then
            show_dgb_upnp_menu="yes"
        else
            show_dgb_upnp_menu="yes"
        fi
fi

# If this is a new install and the upnp values already exist
if [ "$show_dgb_upnp_menu" = "maybe" ] && [ "$NewInstall" = true ]; then
    show_dgb_upnp_menu="yes"
fi

# If we are running this from the main menu, always show the menu prompts
if [ "$show_dgb_upnp_menu" = "maybe" ] && [ "$FORCE_DISPLAY_UPNP_MENU" = true ]; then
    show_dgb_upnp_menu="yes"
fi




# IF THIS IS A FULL INSTALL CHECK FOR KUBO IPFS

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    local try_for_jsipfs="no"

    # If there are not any IPFS config files, show the menu
    if [ ! -f "$USER_HOME/.ipfs/config" ] && [ ! -f "$USER_HOME/.jsipfs/config" ]; then
        show_ipfs_upnp_menu="yes"
    fi

    # Is there a working version of Kubo available?
    if [ -f "$USER_HOME/.ipfs/config" ]; then

        local test_kubo_query

        test_kubo_query=$(curl -X POST http://127.0.0.1:5001/api/v0/id 2>/dev/null)
        test_kubo_query=$(echo $test_kubo_query | jq .AgentVersion | grep -Eo kubo)

        # If this is Kubo, check the current UPNP status, otherwise test for JS-IPFS
        if [ "$test_kubo_query" = "kubo" ]; then

            # Is Kubo installed and running, and what is the upnp status?
            query_ipfs_upnp_status=$(sudo -u $USER_ACCOUNT ipfs config show 2>/dev/null | jq .Swarm.DisableNatPortMap)

            if [ "$query_ipfs_upnp_status" != "" ]; then
                UPNP_IPFS_CURRENT=$query_ipfs_upnp_status
            else
                try_for_jsipfs="yes"
            fi

        fi

    fi

    # Ok, there is no Kubo. Is there a JS-IPFS config file available?
    if [ -f "$USER_HOME/.jsipfs/config" ] && [ "$try_for_jsipfs" = "yes" ]; then

        # Test if JS-IPFS is in use
        is_jsipfs_in_use=$(cat $DGA_SETTINGS_FILE | jq .ipfs | sed 's/"//g')

        # If yes, then get the current JS-IPFS upnp status
        if [ "$is_jsipfs_in_use" = "true" ]; then

            # Get JS-IPFS upnp status
            query_jsipfs_upnp_status=$(cat ~/.jsipfs/config | jq .Swarm.DisableNatPortMap)

            if [ "$query_ipfs_upnp_status" != "" ]; then
                UPNP_IPFS_CURRENT=$query_ipfs_upnp_status
            fi
 
        else

            show_ipfs_upnp_menu="yes"

        fi

    fi

    # If this is a new install, show the upnp prompt menu regardless
    if [ "$DGANODE_ONLY" = true ] && [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        show_ipfs_upnp_menu="yes"
    fi

    # If we are running this from the main menu, always show the menu prompts
    if [ "$FORCE_DISPLAY_UPNP_MENU" = true ]; then
        show_ipfs_upnp_menu="yes"
    fi

fi



# SHOW UPNP MENU

# Don't ask if we are running unattended
if [ ! "$UNATTENDED_MODE" == true ]; then

    # Display upnp section break
    if [ "$show_dgb_upnp_menu" = "yes" ] || [ "$show_ipfs_upnp_menu" = "yes" ]; then

            printf " =============== UPnP MENU =============================================\\n\\n"
            # ==============================================================================

    fi

    # Set up a string to display the current UPnP status
    local upnp_current_status_1
    local upnp_current_status_2
    local upnp_current_status_3
    local upnp_current_status

    if [ "$UPNP_DGB_CURRENT" != "" ] || [ "$UPNP_IPFS_CURRENT" != "" ]; then
        upnp_current_status_1="Note:\\n"
    fi

    if [ "$UPNP_DGB_CURRENT" = "1" ]; then
        upnp_current_status_2=" - UPnP is currently ENABLED for DigiByte Core\\n"
    elif [ "$UPNP_DGB_CURRENT" = "0" ]; then
        upnp_current_status_2=" - UPnP is currently DISABLED for DigiByte Core\\n"
    fi

    if [ "$UPNP_IPFS_CURRENT" = "false" ]; then
        upnp_current_status_3=" - UPnP is currently ENABLED for IPFS\\n"
    elif [ "$UPNP_IPFS_CURRENT" = "true" ]; then
        upnp_current_status_3=" - UPnP is currently DISABLED for IPFS\\n"
    fi

    if [ "$upnp_current_status_2" != "" ] || [ "$upnp_current_status_3" != "" ]; then
        upnp_current_status="$upnp_current_status_1$upnp_current_status_2$upnp_current_status_3\\n"
    fi


    # SHOW THE DGB + IPFS UPnP MENU
    if [ "$show_dgb_upnp_menu" = "yes" ] && [ "$show_ipfs_upnp_menu" = "yes" ]; then
        
        if whiptail --backtitle "" --title "PORT FORWARDING" --yesno "How would you like to setup port forwarding?\\n\\nTo make your device discoverable by other nodes on the Internet, you need to forward the following ports on your router:\\n\\n  DigiByte Node:    12024 TCP (or 12026 for a testnet node)\\n  DigiAsset Node:   4001 TCP\\n\\nIf you are comfortable configuring your router, it is recommended to do this manually. The alternative is to enable UPnP to automatically open the ports for you, though this can sometimes not work properly, depending on your router.\\n\\n${upnp_current_status}For help with port forwarding:\\n$DGBH_URL_PORTFWD" --yes-button "Setup Manually" --no-button "Use UPnP" "${r}" "${c}"; then
            printf "%b You chose to DISABLE UPnP for DigiByte Core and IPFS\\n" "${INFO}"
            DGB_ENABLE_UPNP="NO"
            IPFS_ENABLE_UPNP="NO"
        #Nothing to do, continue
        else
            printf "%b You chose to ENABLE UPnP for DigiByte Core and IPFS\\n" "${INFO}"
            DGB_ENABLE_UPNP="YES"
            IPFS_ENABLE_UPNP="YES"
        fi
        printf "\\n"

    # SHOW THE DGB ONLY UPnP MENU
    elif [ "$show_dgb_upnp_menu" = "yes" ] && [ "$show_ipfs_upnp_menu" = "no" ]; then

        if whiptail --backtitle "" --title "PORT FORWARDING" --yesno "How would you like to setup port forwarding?\\n\\nTo make your device discoverable by other nodes on the Internet, you need to forward the following port on your router:\\n\\n  DigiByte Node:    12024 TCP (or 12026 for a testnet node)\\n\\nIf you are comfortable configuring your router, it is recommended to do this manually. The alternative is to enable UPnP to automatically open the port for you, though this can sometimes not work properly, depending on your router.\\n\\n${upnp_current_status}For help with port forwarding:\\n$DGBH_URL_PORTFWD" --yes-button "Setup Manually" --no-button "Use UPnP" "${r}" "${c}"; then
            printf "%b You chose to DISABLE UPnP for DigiByte Core\\n" "${INFO}"
            DGB_ENABLE_UPNP="NO"
            IPFS_ENABLE_UPNP="SKIP"
        #Nothing to do, continue
        else
            printf "%b You chose to ENABLE UPnP for DigiByte Core\\n" "${INFO}"
            DGB_ENABLE_UPNP="YES"
            IPFS_ENABLE_UPNP="SKIP"
        fi
        printf "\\n"


    # SHOW THE IPFS ONLY UPnP MENU
    elif [ "$show_dgb_upnp_menu" = "no" ] && [ "$show_ipfs_upnp_menu" = "yes" ]; then


        if whiptail --backtitle "" --title "PORT FORWARDING" --yesno "How would you like to setup port forwarding?\\n\\nTo make your device discoverable by other nodes on the internet, you need to forward the following port on your router:\\n\\n  DigiAsset Node:   4001 TCP\\n\\nIf you are comfortable configuring your router, it is recommended to do this manually. The alternative is to enable UPnP to automatically open the port for you, though this can sometimes be temperamental.\\n\\n${upnp_current_status}For help with port forwarding:\\n$DGBH_URL_PORTFWD" --yes-button "Setup Manually" --no-button "Use UPnP" "${r}" "${c}"; then
            printf "%b You chose to DISABLE UPnP for IPFS" "${INFO}"
            DGB_ENABLE_UPNP="SKIP"
            IPFS_ENABLE_UPNP="NO"
        #Nothing to do, continue
        else
            printf "%b You chose to ENABLE UPnP for IPFS\\n" "${INFO}"
            DGB_ENABLE_UPNP="SKIP"
            IPFS_ENABLE_UPNP="YES"
        fi
        printf "\\n"

    elif [ "$show_dgb_upnp_menu" = "no" ] && [ "$show_ipfs_upnp_menu" = "no" ]; then

        DGB_ENABLE_UPNP="SKIP"
        IPFS_ENABLE_UPNP="SKIP"

    fi

else

    # If we are running unattended, and the script wants to prompt the user with the upnp menu, then get the values from diginode.settings

    # Display upnp section break
    if [ "$show_dgb_upnp_menu" = "yes" ] || [ "$show_ipfs_upnp_menu" = "yes" ]; then

            printf " =============== Unattended Mode: Configuring UPnP =====================\\n\\n"
            # ==============================================================================

    fi

    if [ "$show_dgb_upnp_menu" = "yes" ]; then

        if [ "$UI_DGB_ENABLE_UPNP" = "YES" ]; then

            printf "%b Unattended Mode: UPnP will be ENABLED for DigiByte Core\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_ENABLE_UPNP value in diginode.settings)\\n" "${INDENT}"
            DGB_ENABLE_UPNP="YES"

        elif [ "$UI_DGB_ENABLE_UPNP" = "NO" ]; then

            printf "%b Unattended Mode: UPnP will be DISABLED for DigiByte Core" "${INFO}"
            printf "%b                  (Set from UI_DGB_ENABLE_UPNP value in diginode.settings)\\n" "${INDENT}"
            DGB_ENABLE_UPNP="NO"

        else

            printf "%b Unattended Mode: Skipping setting up UPnP for DigiByte Core. It is already configured.\\n" "${INFO}"
            DGB_ENABLE_UPNP="SKIP"

        fi
    fi

    if [ "$show_ipfs_upnp_menu" = "yes" ]; then

        if [ "$UI_IPFS_ENABLE_UPNP" = "YES" ]; then

            printf "%b Unattended Mode: UPnP will be ENABLED for IPFS" "${INFO}"
            printf "%b                  (Set from UI_IPFS_ENABLE_UPNP value in diginode.settings)\\n" "${INDENT}"
            IPFS_ENABLE_UPNP="YES"

        elif [ "$UI_IPFS_ENABLE_UPNP" = "NO" ]; then

            printf "%b Unattended Mode: UPnP will be DISABLED for IPFS" "${INFO}"
            printf "%b                  (Set from UI_IPFS_ENABLE_UPNP value in diginode.settings)\\n" "${INDENT}"

            IPFS_ENABLE_UPNP="NO"

        else

            printf "%b Unattended Mode: Skipping setting up UPnP for IPFS. It is already configured.\\n" "${INFO}"
            DGB_ENABLE_UPNP="SKIP"

        fi
    fi

    # Insert blank row if anything was displayed above
    if [ "$show_dgb_upnp_menu" = "yes" ] || [ "$show_ipfs_upnp_menu" = "yes" ]; then  
        printf "\\n"
    fi


fi

}





# This function will check if DigiByte Node is installed, and if it is, check if there is an update available

digibyte_check() {

    printf " =============== Checking: DigiByte Node ===============================\\n\\n"
    # ==============================================================================

    # Let's check if DigiByte Node is already installed
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

    # Restart if the RPC port has changed and it can't connect
    if [ "$DGB_STATUS" = "running" ]; then
        IS_RPC_PORT_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Could not connect to the server")
        if [ "$IS_RPC_PORT_CHANGED" = "Could not connect to the server" ]; then
            printf "%b RPC port has been changed. DigiByte daemon will be restarted.\\n" "${INFO}"
            restart_service digibyted
        fi
    fi

    # Restart Digibyted if the RPC username or password in digibyte.conf have recently been changed
    if [ "$DGB_STATUS" = "running" ]; then
        IS_RPC_CREDENTIALS_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Incorrect rpcuser or rpcpassword")
        if [ "$IS_RPC_CREDENTIALS_CHANGED" = "Incorrect rpcuser or rpcpassword" ]; then
            printf "%b RPC credentials have been changed. DigiByte daemon will be restarted.\\n" "${INFO}"
            restart_service digibyted
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
        printf "%b %bDigiByte Core is in the process of starting up. This can take 10 mins or more.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        str="Please wait..."
        printf "%b %s" "${INDENT}" "${str}"
        tput civis
        # Query if digibyte has finished starting up. Display error. Send success to null.
        is_dgb_live_query=$(sudo -u $USER_ACCOUNT $DGB_CLI uptime 2>&1 1>/dev/null)
        if [ "$is_dgb_live_query" != "" ]; then
            dgb_error_msg=$(echo $is_dgb_live_query | cut -d ':' -f3)
        fi
        while [ $DGB_STATUS = "startingup" ]; do

            # Show Spinner while waiting for DigiByte Core to finishing starting up
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
                # Query if digibyte has finished starting up. Display error. Send success to null.
                is_dgb_live_query=$(sudo -u $USER_ACCOUNT $DGB_CLI uptime 2>&1 1>/dev/null)
                if [ "$is_dgb_live_query" != "" ]; then
                    dgb_error_msg=$(echo $is_dgb_live_query | cut -d ':' -f3)
                    printf "%b%b %s $dgb_error_msg $progress Querying..." "${OVER}" "${INDENT}" "${str}"
                    every15secs=0
                    sleep 0.5
                else
                    DGB_STATUS="running"
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    tput cnorm
                fi
            else
                every15secs=$((every15secs + 1))
                printf "%b%b %s $dgb_error_msg $progress" "${OVER}" "${INDENT}" "${str}"
                sleep 0.5
            fi
        done

    fi




        # Get the version number of the current DigiByte Node and write it to to the settings file
    if [ "$DGB_STATUS" = "running" ]; then
        str="Current Version:"
        printf "%b %s" "${INFO}" "${str}"
        DGB_VER_LOCAL=$(sudo -u $USER_ACCOUNT $DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
        sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s DigiByte Core v${DGB_VER_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"

        # Find out which DGB network is running - mainnet or testnet
        str="Checking which DigiByte chain is running (mainnet or testnet?)..."
        printf "%b %s" "${INFO}" "${str}"

        # Query if DigiByte Core is running the testnet or mainnet chain
        DGB_NETWORK_CHAIN_QUERY=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockchaininfo 2>/dev/null | grep -m1 chain | cut -d '"' -f4)
        if [ "$DGB_NETWORK_CHAIN_QUERY" != "" ]; then
            DGB_NETWORK_CHAIN=$DGB_NETWORK_CHAIN_QUERY
        fi

        if [ "$DGB_NETWORK_CHAIN" = "test" ]; then 
            DGB_NETWORK_CURRENT="TESTNET"
            printf "%b%b %s TESTNET\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CHAIN" = "main" ]; then 
            DGB_NETWORK_CURRENT="MAINNET"
            printf "%b%b %s MAINNET\\n" "${OVER}" "${TICK}" "${str}"
        else
            # Just in case there is no response from digibyte-cli, check digibyte.conf in an emergency
            if [ -f "$DGB_CONF_FILE" ]; then

                    # Get testnet status from digibyte.conf
                    if grep -q "testnet=1" $DGB_CONF_FILE; then
                        DGB_NETWORK_CURRENT="TESTNET"
                        printf "%b%b %s TESTNET (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
                    else
                        DGB_NETWORK_CURRENT="MAINNET"
                        printf "%b%b %s MAINNET (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
                    fi
            fi
        fi
    fi

      # If DigiByte Core is not running, we can't get the version number from there, so we will resort to what is in the diginode.settings file
    if [ "$DGB_STATUS" = "notrunning" ]; then

        printf "%b DigiByte Core is installed, but not currently running (digibyte-cli is not responding).\\n" "${INFO}"

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

        # If digibyte.conf file already exists, find out whther this installed version is using testnet or not
        if [ -f "$DGB_CONF_FILE" ]; then

                str="Checking digibyte.conf for which network DigiByte Core is running (mainnet or testnet)?..."
                printf "%b %s" "${INFO}" "${str}"

                # Get testnet status from digibyte.conf
                if grep -q "testnet=1" $DGB_CONF_FILE; then
                    DGB_NETWORK_CURRENT="TESTNET"
                    printf "%b%b %s TESTNET\\n" "${OVER}" "${TICK}" "${str}"
                else
                    DGB_NETWORK_CURRENT="MAINNET"
                    printf "%b%b %s MAINNET\\n" "${OVER}" "${TICK}" "${str}"
                fi
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
        sed -i -e "/^DGB_VER_RELEASE=/s|.*|DGB_VER_RELEASE=\"$DGB_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
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
    printf " =============== Reset: DigiByte Node ==================================\\n\\n"
    # ==============================================================================
    printf "%b Reset Mode: You skipped re-installing DigiByte Core.\\n" "${INFO}"
    printf "\\n"
    return
fi

if [ "$DGB_DO_INSTALL" = "YES" ]; then

    # Display section break
    if [ "$DGB_INSTALL_TYPE" = "new" ]; then
        printf " =============== Install: DigiByte Node ================================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf " =============== Upgrade: DigiByte Node ================================\\n\\n"
        # ==============================================================================
    elif [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: DigiByte Node ==================================\\n\\n"
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

    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: DigiByte Core Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b The new version of DigiByte Core could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
        printf "%b Please contact @digibytehelp so a fix can be issued. For now the existing version will be restarted.\\n" "${INDENT}"

        # Re-enable and re-start DigiByte daemon service as the download failed
        if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Upgrade Failed: Re-enabling and re-starting DigiByte daemon service ...\\n" "${INFO}"
            enable_service digibyted
            restart_service digibyted
            DGB_STATUS="running"
            DIGINODE_UPGRADED="YES"
        elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Failed: Renabling and restarting DigiByte daemon service ...\\n" "${INFO}"
            enable_service digibyted
            restart_service digibyted
            DGB_STATUS="running"
        fi

        printf "\\n"
        INSTALL_ERROR="YES"
        return 1
    fi

    # If there is an old backup of DigiByte Core, delete it
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backup" ]; then
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
    sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    if [ "$DGB_INSTALL_TYPE" = "new" ]; then
        sed -i -e "/^DGB_INSTALL_DATE=/s|.*|DGB_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        sed -i -e "/^DGB_UPGRADE_DATE=/s|.*|DGB_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Re-enable and re-start DigiByte daemon service after reset/upgrade
    if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf "%b Upgrade Completed: Re-enabling and re-starting DigiByte daemon service ...\\n" "${INFO}"
        enable_service digibyted
        restart_service digibyted
        DGB_STATUS="running"
        DIGINODE_UPGRADED="YES"
    elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf "%b Reset Completed: Renabling and restarting DigiByte daemon service ...\\n" "${INFO}"
        enable_service digibyted
        restart_service digibyted
        DGB_STATUS="running"
    fi

    # Reset DGB Install and Upgrade Variables
    DGB_INSTALL_TYPE=""
    DGB_UPDATE_AVAILABLE=NO
    DGB_POSTUPDATE_CLEANUP=YES

    # Create hidden file to denote this version was installed with the official DigiNode Setup
    if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then
        str="Labeling as official DigiNode install..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_INSTALL_LOCATION/.officialdiginode
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Add DigiByte binary folder to the path for now
    if [ -f "$DGB_CLI" ]; then
        str="Adding $DGB_CLI folder to path..."
        printf "%b %s" "${INFO}" "${str}"
        export PATH+=":$DGB_INSTALL_LOCATION/bin"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Add DigiByte binary folder to the path permanently (so it works after reboot)
    str="Is DigiByte binary folder path already in .bashrc?..."
    printf "%b %s" "${INFO}" "${str}"
    if grep -q "export PATH+=:$DGB_INSTALL_LOCATION/bin" "$USER_HOME/.bashrc"; then
        printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"
    else
        # Append export path to .bashrc file
        echo "" >> $USER_HOME/.bashrc
        echo "# Add DigiByte binary folder to path" >> $USER_HOME/.bashrc
        echo "export PATH+=:$DGB_INSTALL_LOCATION/bin" >> $USER_HOME/.bashrc
        printf "%b%b %s No - Added!\\n" "${OVER}" "${TICK}" "${str}"
    fi


    printf "\\n"

fi

}


# This function will install or upgrade the local version of the 'DigiNode Tools' scripts.
# By default, it will always install the latest release version from GitHub. If the existing installed version
# is the develop version or an older release version, it will be upgraded to the latest release version.
# If the --dgntdev flag is used at launch it will always replace the local version
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
        sed -i -e "/^DGNT_VER_RELEASE=/s|.*|DGNT_VER_RELEASE=\"$DGNT_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # Get the current local version and branch, if any
    if [[ -f "$DGNT_MONITOR_SCRIPT" ]]; then
        local dgnt_ver_local_query=$(cat $DGNT_MONITOR_SCRIPT | grep -m1 DGNT_VER_LOCAL  | cut -d'=' -f 2)
        local dgnt_branch_local_query=$(git -C $DGNT_LOCATION rev-parse --abbrev-ref HEAD 2>/dev/null)
    else
        DGNT_BRANCH_LOCAL=""
        sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=|" $DGNT_SETTINGS_FILE  
    fi

    # If we get a valid version number, update the stored local version
    if [ "$dgnt_ver_local_query" != "" ]; then
        DGNT_VER_LOCAL=$dgnt_ver_local_query
        sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=\"$DGNT_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    fi

    # If we get a valid local branch, update the stored local branch
    if [ "$dgnt_branch_local_query" != "" ]; then
        DGNT_BRANCH_LOCAL=$dgnt_branch_local_query

        # If the local branch has returned as "HEAD", then set it to "release"
        if [ "$DGNT_BRANCH_LOCAL" = "HEAD" ]; then
            DGNT_BRANCH_LOCAL="release"
        fi
        sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"$DGNT_BRANCH_LOCAL\"|" $DGNT_SETTINGS_FILE
    fi

    # Update diginode.settings with the current version if it has just been created, is running locally, and is on the main branch
    if [ "$IS_DGNT_SETTINGS_FILE_NEW" = "YES" ] && [ "$DGNT_RUN_LOCATION" = "local" ] && [ "$DGNT_BRANCH_LOCAL" = "release" ]; then
        printf "%b Setting file version of diginode.settings to $DGNT_VER_LOCAL\\n" "${INFO}"
        sed -i -e "/^DGNT_SETTINGS_FILE_VER=/s|.*|DGNT_SETTINGS_FILE_VER=\"$DGNT_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    fi

    # Let's check if DigiNode Tools already installed
    str="Are DigiNode Tools already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ ! -f "$DGNT_MONITOR_SCRIPT" ]; then
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        DGNT_VER_LOCAL=""
        DGNT_BRANCH_LOCAL=""
        sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
        sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        if [ "$DGNT_BRANCH_LOCAL" = "release" ]; then
            printf "%b%b %s YES!  DigiNode Tools v${DGNT_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGNT_BRANCH_LOCAL" = "develop" ]; then
            printf "%b%b %s YES!  DigiNode Tools develop branch\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGNT_BRANCH_LOCAL" = "main" ]; then
            printf "%b%b %s YES!  DigiNode Tools main branch\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"

            # If there is a local version number, but no local branch, set the branch to HEAD
            if [ "$DGNT_VER_LOCAL" != "" ]; then
                DGNT_BRANCH_LOCAL="release"
                sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"release\"|" $DGNT_SETTINGS_FILE
                printf "%b WARNING: Local version is v${DGNT_VER_LOCAL} but the local branch was not detected - it has been set to: release\\n" "${WARN}"
            fi
        fi
    fi

    # Requested branch
    if [ "$DGNT_BRANCH_REMOTE" = "develop" ]; then
        printf "%b DigiNode Tools develop branch requested.\\n" "${INFO}"
    elif [ "$DGNT_BRANCH_REMOTE" = "main" ]; then
        printf "%b DigiNode Tools main branch requested.\\n" "${INFO}"
    fi

    # If there is no release version (i.e. it returns 'null'), use the main version
    if [ "$DGNT_BRANCH_REMOTE" = "release" ] && [ "$DGNT_VER_RELEASE" = "null" ]; then
        printf "%b DigiNode Tools release branch requested.\\n" "${INFO}"
        printf "%b ERROR: Release branch is unavailable. main branch will be installed.\\n" "${CROSS}"
        DGNT_BRANCH_REMOTE="main"
    fi

   

    # Upgrade to release branch
    if [ "$DGNT_BRANCH_REMOTE" = "release" ]; then
        # If it's the release version lookup latest version (this is what is used normally, with no argument specified)

        if [ "$DGNT_BRANCH_LOCAL" = "release" ]; then

            if  [ $(version $DGNT_VER_LOCAL) -ge $(version $DGNT_VER_RELEASE) ]; then

                if [ "$RESET_MODE" = true ]; then
                    printf "%b Reset Mode is Enabled. You will be asked if you want to re-install DigiByte Core v${DGB_VER_RELEASE}.\\n" "${INFO}"
                    DGNT_INSTALL_TYPE="askreset"
                else
                    printf "%b Upgrade not required.\\n" "${INFO}"
                    DGNT_INSTALL_TYPE="none"
                fi

            else        
                printf "%b %bDigiNode Tools can be upgraded from v${DGNT_VER_LOCAL} to v${DGNT_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                DGNT_INSTALL_TYPE="upgrade"
                DGNT_ASK_UPGRADE=YES
            fi

        elif [ "$DGNT_BRANCH_LOCAL" = "main" ]; then
            printf "%b %bDigiNode Tools will be upgraded from the main branch to the v${DGNT_VER_RELEASE} release version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_BRANCH_LOCAL" = "develop" ]; then
            printf "%b %bDigiNode Tools will be upgraded from the develop branch to the v${DGNT_VER_RELEASE} release version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        else 
            printf "%b %bDigiNode Tools v${DGNT_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="new"
            DGNT_DO_INSTALL=YES
        fi

    # Upgrade to develop branch
    elif [ "$DGNT_BRANCH_REMOTE" = "develop" ]; then
        if [ "$DGNT_BRANCH_LOCAL" = "release" ]; then
            printf "%b %bDigiNode Tools v${DGNT_VER_LOCAL} will be replaced with the develop branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_BRANCH_LOCAL" = "main" ]; then
            printf "%b %bDigiNode Tools main branch will be replaced with the develop branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_BRANCH_LOCAL" = "develop" ]; then
            printf "%b %bDigiNode Tools develop version will be upgraded to the latest version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        else
            printf "%b %bDigiNode Tools develop branch will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="new"
            DGNT_DO_INSTALL=YES
        fi
    
    # Upgrade to main branch
    elif [ "$DGNT_BRANCH_REMOTE" = "main" ]; then
        if [ "$DGNT_BRANCH_LOCAL" = "release" ]; then
            printf "%b %bDigiNode Tools v${DGNT_VER_LOCAL} will replaced with the main branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_BRANCH_LOCAL" = "main" ]; then
            printf "%b %bDigiNode Tools main branch will be upgraded to the latest version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGNT_INSTALL_TYPE="upgrade"
            DGNT_DO_INSTALL=YES
        elif [ "$DGNT_BRANCH_LOCAL" = "develop" ]; then
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

# If we are in reset mode, ask the user if they want to reinstall DigiNode Tools
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
            printf " =============== Install: DigNode Tools ================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "upgrade" ]; then
            printf " =============== Upgrade: DigNode Tools ================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "reset" ]; then
            printf " =============== Reset: DigNode Tools ==================================\\n\\n"
            # ==============================================================================
            printf "%b Reset Mode: You chose to re-install DigNode Tools.\\n" "${INFO}"
        fi

        # first delete the current installed version of DigiNode Tools (if it exists)
        if [[ -d $DGNT_LOCATION ]]; then
            str="Removing DigiNode Tools current version..."
            printf "%b %s" "${INFO}" "${str}"
            rm -rf $DGNT_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            DGNT_VER_LOCAL_DISPLAY=""
            sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=|" $DGNT_SETTINGS_FILE
        fi

        # Next install the newest version
        cd $USER_HOME
        # Clone the develop version if develop flag is set
        if [ "$DGNT_BRANCH_REMOTE" = "develop" ]; then
            str="Installing DigiNode Tools develop branch..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch develop https://github.com/saltedlolly/diginode-tools/
            DGNT_BRANCH_LOCAL="develop"
            sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"develop\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        # Clone the develop version if develop flag is set
        elif [ "$DGNT_BRANCH_REMOTE" = "main" ]; then
            str="Installing DigiNode Tools main branch..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch main https://github.com/saltedlolly/diginode-tools/
            DGNT_BRANCH_LOCAL="main"
            sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"main\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGNT_BRANCH_REMOTE" = "release" ]; then
            str="Installing DigiNode Tools v${DGNT_VER_RELEASE}..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch v${DGNT_VER_RELEASE} https://github.com/saltedlolly/diginode-tools/ 2>/dev/null
            DGNT_BRANCH_LOCAL="release"
            sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"release\"|" $DGNT_SETTINGS_FILE
            DGNT_VER_LOCAL=$DGNT_VER_RELEASE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=\"$DGNT_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Update diginode.settings with the install/upgrade date
        if [ "$DGNT_INSTALL_TYPE" = "new" ]; then
            sed -i -e "/^DGNT_INSTALL_DATE=/s|.*|DGNT_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
        elif [ "$DGNT_INSTALL_TYPE" = "upgrade" ]; then
            sed -i -e "/^DGNT_UPGRADE_DATE=/s|.*|DGNT_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
        fi

        # Get the current local version and branch, if any
        if [[ -f "$DGNT_MONITOR_SCRIPT" ]]; then
            local dgnt_ver_local_query=$(cat $DGNT_MONITOR_SCRIPT | grep -m1 DGNT_VER_LOCAL  | cut -d'=' -f 2)
            local dgnt_branch_local_query=$(git -C $DGNT_LOCATION rev-parse --abbrev-ref HEAD 2>/dev/null)
        fi

        # If we get a valid version number, update the stored local version
        if [ "$dgnt_ver_local_query" != "" ]; then
            DGNT_VER_LOCAL=$dgnt_ver_local_query
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=\"$DGNT_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        fi

        # If we get a valid local branch, update the stored local branch
        if [ "$dgnt_branch_local_query" != "" ]; then
            if [ "$dgnt_branch_local_query" = "HEAD" ]; then
                dgnt_branch_local_query="release"
            fi
            DGNT_BRANCH_LOCAL=$dgnt_branch_local_query
            sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"$DGNT_BRANCH_LOCAL\"|" $DGNT_SETTINGS_FILE
        fi

        # Update DigiNode Tools display verion
        if [ "$DGNT_BRANCH_LOCAL" = "release" ]; then
            DGNT_VER_LOCAL_DISPLAY="v${DGNT_VER_LOCAL}"
            sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=\"$DGNT_VER_LOCAL_DISPLAY\"|" $DGNT_SETTINGS_FILE
            printf "%b New local version: $DGNT_VER_LOCAL_DISPLAY\\n" "${INFO}"
            DIGINODE_UPGRADED="YES"
        elif [ "$DGNT_BRANCH_LOCAL" = "develop" ]; then
            DGNT_VER_LOCAL_DISPLAY="dev-branch"
            sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=\"$DGNT_VER_LOCAL_DISPLAY\"|" $DGNT_SETTINGS_FILE
            printf "%b New local version: $DGNT_VER_LOCAL_DISPLAY\\n" "${INFO}"
            DIGINODE_UPGRADED="YES"
        elif [ "$DGNT_BRANCH_LOCAL" = "main" ]; then
            DGNT_VER_LOCAL_DISPLAY="main-branch"
            sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=\"$DGNT_VER_LOCAL_DISPLAY\"|" $DGNT_SETTINGS_FILE
            printf "%b New local version: $DGNT_VER_LOCAL_DISPLAY\\n" "${INFO}"
            DIGINODE_UPGRADED="YES"
        fi

        # Make downloads executable
        str="Making DigiNode scripts executable..."
        printf "%b %s" "${INFO}" "${str}"
        chmod +x $DGNT_SETUP_SCRIPT
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

        # Add alias so entering 'diginode-setup' works from any folder
        if grep -q "alias diginode-setup=" "$USER_HOME/.bashrc"; then
            str="Updating 'diginode-setup' alias in .bashrc file..."
            printf "%b %s" "${INFO}" "${str}"
            # Update existing alias for 'diginode'
            sed -i -e "/^alias diginode-setup=/s|.*|alias diginode-setup='$DGNT_SETUP_SCRIPT'|" $USER_HOME/.bashrc
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            str="Adding 'diginode-setup' alias to .bashrc file..."
            printf "%b %s" "${INFO}" "${str}"
            # Append alias to .bashrc file
            echo "" >> $USER_HOME/.bashrc
            echo "# Alias for DigiNode tools so that entering 'diginode-setup' will run this from any folder" >> $USER_HOME/.bashrc
            echo "alias diginode-setup='$DGNT_SETUP_SCRIPT'" >> $USER_HOME/.bashrc
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Load new aliases
        if [ "$NewInstall" = true ]; then
            str="Loading new aliases now..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT source $USER_HOME/.bashrc
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Reset DGNT Install and Upgrade Variables
        DGNT_UPDATE_AVAILABLE=NO
        DGNT_POSTUPDATE_CLEANUP=YES

        printf "\\n"
    fi
}


# This function will check if IPFS is installed, and if it is, check if there is an update available

ipfs_check() {

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    printf " =============== Checking: Kubo (Go-IPFS) ==============================\\n\\n"
    # ==============================================================================

    # Check for latest Go-IPFS release online
    str="Checking Github for the latest Kubo release..."
    printf "%b %s" "${INFO}" "${str}"
    # Gets latest Kubo version, disregarding releases candidates (they contain 'rc' in the name).
    IPFS_VER_RELEASE=$(curl -sfL https://api.github.com/repos/ipfs/kubo/releases/latest | jq -r ".tag_name" | sed 's/v//g')

    # If can't get Github version number
    if [ "$IPFS_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of Kubo. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b Kubo cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"
        IPFS_DO_INSTALL=NO
        IPFS_INSTALL_TYPE="none"
        IPFS_UPDATE_AVAILABLE=NO
        return     
    else
        printf "%b%b %s Found: Kubo v${IPFS_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^IPFS_VER_RELEASE=/s|.*|IPFS_VER_RELEASE=\"$IPFS_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # Get the local version number of Kubo (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Let's check if Kubo is already installed
    str="Is Kubo already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: Kubo v${IPFS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Next let's check if IPFS daemon is running with upstart
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
      str="Is Kubo daemon upstart service running?..."
      printf "%b %s" "${INFO}" "${str}"
      if check_service_active "ipfs"; then
          IPFS_STATUS="running"
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
      else
          IPFS_STATUS="stopped"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
      fi
    fi

    # Next let's check if IPFS daemon is running with systemd
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
        str="Is Kubo daemon systemd service running?..."
        printf "%b %s" "${INFO}" "${str}"

        # Check if it is running or not #CHECKLATER
        systemctl is-active --quiet ipfs && IPFS_STATUS="running" || IPFS_STATUS="stopped"

        if [ "$IPFS_STATUS" = "running" ]; then
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$IPFS_STATUS" = "stopped" ]; then
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi


    # If a Kubo local version already exists.... (i.e. we have a local version number)
    if [ ! $IPFS_VER_LOCAL = "" ]; then
      # ....then check if an upgrade is required
      if [ $(version $IPFS_VER_LOCAL) -ge $(version $IPFS_VER_RELEASE) ]; then
          printf "%b Kubo is already up to date.\\n" "${TICK}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to reinstall Kubo v${IPFS_VER_RELEASE}.\\n" "${INFO}"
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
          printf "%b %bKubo can be upgraded from v${IPFS_VER_LOCAL} to v${IPFS_VER_RELEASE}.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          IPFS_INSTALL_TYPE="upgrade"
          IPFS_ASK_UPGRADE=YES
      fi
    fi 

    # Lookup the current Kubo IPFS ports
    if [ -f "$USER_HOME/.ipfs/config" ]; then
        printf "%b Retrieving current port numbers for Kubo IPFS...\\n" "${INFO}"

        str="Kubo IPFS IP4 Port:"
        printf "%b %s" "${INFO}" "${str}"
        IPFS_PORT_IP4=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[0] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $IPFS_PORT_IP4\\n" "${OVER}" "${TICK}" "${str}"
        
        str="Kubo IPFS IP6 Port:"
        printf "%b %s" "${INFO}" "${str}"
        IPFS_PORT_IP6=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[1] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $IPFS_PORT_IP6\\n" "${OVER}" "${TICK}" "${str}"

        str="Kubo IPFS IP4 Quic Port:"
        printf "%b %s" "${INFO}" "${str}"
        IPFS_PORT_IP4_QUIC=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[2] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $IPFS_PORT_IP4_QUIC\\n" "${OVER}" "${TICK}" "${str}"
        
        str="Kubo IPFS IP6 Quic Port:"
        printf "%b %s" "${INFO}" "${str}"
        IPFS_PORT_IP6_QUIC=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[3] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $IPFS_PORT_IP6_QUIC\\n" "${OVER}" "${TICK}" "${str}"

    fi

    # Lookup the current JS-IPFS ports
    if [ -f "$USER_HOME/.jsipfs/config" ]; then
        printf "%b Retrieving current port numbers for JS-IPFS...\\n" "${INFO}"

        str="JS-IPFS IP4 Port:"
        printf "%b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP4=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[0] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $JSIPFS_PORT_IP4\\n" "${OVER}" "${TICK}" "${str}"
        
        str="JS-IPFS IP6 Port:"
        printf "%b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP6=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[1] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $JSIPFS_PORT_IP6\\n" "${OVER}" "${TICK}" "${str}"

        str="JS-IPFS IP4 Quic Port:"
        printf "%b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP4_QUIC=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[2] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $JSIPFS_PORT_IP4_QUIC\\n" "${OVER}" "${TICK}" "${str}"
        
        str="JS-IPFS IP6 Quic Port:"
        printf "%b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP6_QUIC=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[3] | sed 's/"//g' | cut -d'/' -f5)
        printf "%b%b %s $JSIPFS_PORT_IP6_QUIC\\n" "${OVER}" "${TICK}" "${str}"

    fi


    # If no current version is installed, then do a clean install
    if [ "$IPFS_STATUS" = "not_detected" ]; then
      printf "%b %bKubo v${IPFS_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      IPFS_INSTALL_TYPE="new"
      IPFS_DO_INSTALL="if_doing_full_install"
    fi

    printf "\\n"

fi

}

# This function will install Kubo if it not yet installed, and if it is, upgrade it to the latest release
ipfs_do_install() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
    IPFS_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall IPFS
if [ "$IPFS_INSTALL_TYPE" = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install Kubo v${IPFS_VER_RELEASE}?" "${r}" "${c}"; then
        IPFS_DO_INSTALL=YES
        IPFS_INSTALL_TYPE="reset"
    else        
        printf " =============== Resetting: Kubo (Go-IPFS) =============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You skipped re-installing Kubo.\\n" "${INFO}"
        IPFS_DO_INSTALL=NO
        IPFS_INSTALL_TYPE="none"
        IPFS_UPDATE_AVAILABLE=NO
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
        printf " =============== Install: Kubo (Go-IPFS) ===============================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
        printf " =============== Upgrade: Kubo (Go-IPFS) ===============================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: Kubo (Go-IPFS) =================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-install Kubo.\\n" "${INFO}"
    fi

    # Let's find the correct file type to download based on the current architecture
    if [ "$ARCH" = "aarch64" ]; then
        ipfsarch="arm64"
    elif [ "$ARCH" = "X86_64" ]; then
        ipfsarch="amd64"
    elif [ "$ARCH" = "x86_64" ]; then
        ipfsarch="amd64"
    fi

    # First, Clean up any old IPFS Updater files (IPFS Updater is no longer used at all so we get rid of all trace of it)

    # If we are updating the current version of IPFS Updater, delete the existing install folder
    if [ "$IPFSU_INSTALL_TYPE" = "upgrade" ]; then
        str="Old Version Cleanup: Deleting IPFS Updater v${IPFSU_VER_LOCAL}..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r /usr/local/bin/ipfs-update
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete any old IPFS Updater tar files
    if compgen -G "$USER_HOME/ipfs-update*.tar.gz" > /dev/null; then
        str="Old Version Cleanup: Deleting any old IPFS Updater tar.gz files from home folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $USER_HOME/ipfs-update*.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete old IPFS Updater backup, if it exists
    if [ -d "$USER_HOME/ipfs-update-oldversion" ]; then
        str="Old Version Cleanup: Deleting old backup of IPFS Updater..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $USER_HOME/ipfs-update-oldversion
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete the IPFS Updater backup version, now the new version has been installed
    if [ -d "$USER_HOME/ipfs-update-oldversion" ]; then
        str="Old Version Cleanup: Deleting IPFS Updater install folder: $USER_HOME/ipfs-update-oldversion ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -rf $USER_HOME/ipfs-update
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi


     # Stop IPFS service if it is running, as we need to upgrade or reset it
    if [ "$IPFS_STATUS" = "running" ]; then

        if [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Preparing Upgrade: Stopping IPFS service ...\\n" "${INFO}"
        elif [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
            printf "%b Preparing Reset: Stopping IPFS service ...\\n" "${INFO}"
        fi

        if [ "$INIT_SYSTEM" = "systemd" ]; then

            # Stop the service now
            str="Stopping IPFS systemd service..."
            printf "%b %s" "${INFO}" "${str}"
            systemctl stop ipfs
            IPFS_STATUS="stopped"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Disable the service from running at boot
            printf "%b Disabling IPFS systemd service...\\n" "${INFO}"
            systemctl disable ipfs

        fi

        if [ "$INIT_SYSTEM" = "upstart" ]; then

            # Enable the service to run at boot
            printf "%b Stopping IPFS upstart service...\\n" "${INFO}"
            service ipfs stop
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_STATUS="stopped"

        fi
    fi


    # If we are re-installing the current version of Kubo, delete the existing binary
    if [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
        str="Reset Mode: Deleting Kubo v${IPFS_VER_LOCAL} ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f /usr/local/bin/ipfs
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"

        # Delete IPFS settings
        if [ -d "$USER_HOME/.ipfs" ]; then
            if whiptail --backtitle "" --title "RESET MODE" --yesno "Would you like to reset your IPFS settings folder?\\n\\nThis will delete the folder: ~/.ipfs" "${r}" "${c}"; then
                str="Reset Mode: Deleting ~/.ipfs settings folder..."
                printf "%b %s" "${INFO}" "${str}"
                rm -rf $USER_HOME/.ipfs
                printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b Reset Mode: You chose not to reset the IPFS settings folder (~/.ipfs).\\n" "${INFO}"
            fi
        fi
    fi

    # If there is an existing Go-IPFS install tar file, delete it
    if [ -f "$USER_HOME/go-ipfs_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz" ]; then
        str="Deleting existing Go-IPFS install file: go-ipfs_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/go-ipfs_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If there is an existing Kubo install tar file, delete it
    if [ -f "$USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz" ]; then
        str="Deleting existing Kubo install file: kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Downloading latest Kubo install file from GitHub
    str="Downloading Kubo v${IPFS_VER_RELEASE} from Github repository..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT wget -q https://github.com/ipfs/kubo/releases/download/v${IPFS_VER_RELEASE}/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz -P $USER_HOME


    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "%b%b %s Failed!\\n" "${OVER}" "${CROSS}" "${str}"
        printf "\\n"
        printf "%b%b ${txtred}ERROR: Kubo Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b The new version of Kubo could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
        printf "%b Please contact @digibytehelp so a fix can be issued. For now the existing version will be restarted.\\n" "${INDENT}"

        if [ "$INIT_SYSTEM" = "systemd" ]; then

            # Enable the service to run at boot
            str="Re-enabling IPFS systemd service..."
            printf "%b %s" "${INFO}" "${str}"
            systemctl enable ipfs
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Start the service now
            str="Re-starting IPFS systemd service..."
            printf "%b %s" "${INFO}" "${str}"
            systemctl start ipfs
            IPFS_STATUS="running"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [ "$INIT_SYSTEM" = "upstart" ]; then

            # Enable the service to run at boot
            str="Re-starting IPFS upstart service..."
            printf "%b %s" "${INFO}" "${str}"
            service ipfs start
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_STATUS="running"

        fi

        printf "\\n"
        INSTALL_ERROR="YES"
        return 1
    fi

    # If there is an existing Go-IPFS install folder, delete it
    if [ -d "$USER_HOME/go-ipfs" ]; then
        str="Deleting existing ~/go-ipfs folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r $USER_HOME/go-ipfs
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If there is an existing Kubo install folder, delete it
    if [ -d "$USER_HOME/kubo" ]; then
        str="Deleting existing ~/kubo folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r $USER_HOME/kubo
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Extracting Kubo install files
    str="Extracting Kubo v${IPFS_VER_RELEASE} ..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT tar -xf $USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz -C $USER_HOME
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Delete Kubo install tar file, delete it
    if [ -f "$USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz" ]; then
        str="Deleting Kubo install file: kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Install Kubo to bin folder
    printf "%b Installing Kubo v${IPFS_VER_RELEASE} ...\\n" "${INFO}"
    (cd $USER_HOME/kubo; ./install.sh)

    # If the command completed without error, then assume IPFS installed correctly
    if [ $? -eq 0 ]; then
        printf "%b Kubo appears to have been installed correctly.\\n" "${INFO}"
        
        if [ "$IPFS_STATUS" = "not_detected" ];then
            IPFS_STATUS="installed"
        fi
        DIGINODE_UPGRADED="YES"
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: Kubo Installation Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b This can sometimes occur because of a connection problem - it seems to be caused by a problem connecting with their servers.\\n" "${INFO}"
        printf "%b It is advisable to wait a moment and then try again. The issue will typically resolve itself if you keep retrying.\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # Delete ~/kubo install folder
    if [ -d "$USER_HOME/kubo" ]; then
        str="Deleting ~/kubo install folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r $USER_HOME/kubo
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Get the new version number of the local Kubo install
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Update diginode.settings with new Kubo local version number and the install/upgrade date
    sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    if [ "$IPFS_INSTALL_TYPE" = "new" ]; then
        sed -i -e "/^IPFS_INSTALL_DATE=/s|.*|IPFS_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
        sed -i -e "/^IPFS_UPGRADE_DATE=/s|.*|IPFS_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Initialize IPFS, if it has not already been done so
    if [ ! -d "$USER_HOME/.ipfs" ]; then
        export IPFS_PATH=$USER_ACCOUNT/.ipfs

        local use_ipfs_server_profile

        # If we are in unattended mode setup whether we are using the server profile
        if [ "$UNATTENDED_MODE" == true ]; then
            if [ "$UI_IPFS_SERVER_PROFILE" = "YES" ]; then
                printf "%b Unattended Mode: The IPFS Server profile will be used.\\n" "${INFO}"
                use_ipfs_server_profile="yes"
            elif [ "$UI_IPFS_SERVER_PROFILE" = "NO" ]; then
                printf "%b Unattended Mode: The IPFS Server profile will NOT be used.\\n" "${INFO}"
                use_ipfs_server_profile="no"
            else
                printf "%b Unattended Mode: The IPFS Server profile will NO be used.\\n" "${INFO}"
                use_ipfs_server_profile="no"
            fi
        else
            # Ask the user if they want to use the server profile
            if whiptail --backtitle "" --title "Use IPFS Server Profile?" --yesno --defaultno "Do you want to use the IPFS server profile?\\n\\nThe server profile disables local host discovery, and is recommended when running IPFS on machines with a public IPv4 address, such as on a cloud VPS.\\n\\nIf you are setting up your DigiAsset Node on a device on your local network, then you likely do not need to do this." "${r}" "${c}"; then
                printf "%b You chose to enable the IPFS Server profile.\\n" "${INFO}"
                use_ipfs_server_profile="yes"
            else
                printf "%b You chose NOT to enable the IPFS Server profile.\\n" "${INFO}"
                use_ipfs_server_profile="no"
            fi

        fi

        if [ "$use_ipfs_server_profile" = "yes" ]; then
            sudo -u $USER_ACCOUNT ipfs init -p server
        elif [ "$use_ipfs_server_profile" = "no" ]; then
            sudo -u $USER_ACCOUNT ipfs init
        fi

        sudo -u $USER_ACCOUNT ipfs cat /ipfs/QmQPeNsJPyVWPFDVHb77w8G42Fvo15z4bG2X8D2GhfbSXc/readme
        printf "\\n"
    fi

    # Set the upnp values, if we are enabling/disabling the UPnP status
    if [ "$IPFS_ENABLE_UPNP" = "YES" ]; then
        str="Enabling UPnP port forwarding for Kubo IPFS..."
        printf "%b %s" "${INFO}" "${str}"
        
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        if [ -f "$USER_HOME/.jsips/config" ]; then
            str="Enabling UPnP port forwarding for JS-IPFS..."
            printf "%b %s" "${INFO}" "${str}"
            update_upnp_now="$(jq ".Swarm.DisableNatPortMap = \"false\"" $DGA_SETTINGS_FILE)" && \
            echo -E "${update_upnp_now}" > $DGA_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    elif [ "$IPFS_ENABLE_UPNP" = "NO" ]; then
        str="Disabling UPnP port forwarding for Kubo IPFS..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT ipfs config --bool Swarm.DisableNatPortMap "true"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        if [ -f "$USER_HOME/.jsips/config" ]; then
            str="Disabling UPnP port forwarding for JS-IPFS..."
            printf "%b %s" "${INFO}" "${str}"
            update_upnp_now="$(jq ".Swarm.DisableNatPortMap = \"true\"" $DGA_SETTINGS_FILE)" && \
            echo -E "${update_upnp_now}" > $DGA_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi


    # Set the IPFS port based on whether we are using DigiByte mainnet or testnet. 
    # This is to ensure that if you run a testnet node and a mainnet node on the same network they do not both use the same IPFS port and conflict with each other. Default IPFS port with mainnet is 4001. Default IPFS port with testnet is 4004. If another port number has been used they will be left as they are.
    ipfs_update_port


    # Re-enable and re-start IPFS service after reset/upgrade
    if [ "$IPFS_STATUS" = "stopped" ]; then

        if [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Upgrade Completed: Re-enabling and re-starting IPFS service ...\\n" "${INFO}"
        elif [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Completed: Renabling and restarting IPFS service ...\\n" "${INFO}"
        fi

        if [ "$INIT_SYSTEM" = "systemd" ]; then

            # Enable the service to run at boot
            str="Enabling IPFS systemd service..."
            printf "%b %s" "${INFO}" "${str}"
            systemctl enable ipfs
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Start the service now
            str="Starting IPFS systemd service..."
            printf "%b %s" "${INFO}" "${str}"
            systemctl start ipfs
            IPFS_STATUS="running"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [ "$INIT_SYSTEM" = "upstart" ]; then

            # Enable the service to run at boot
            str="Starting IPFS upstart service..."
            printf "%b %s" "${INFO}" "${str}"
            service ipfs start
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_STATUS="running"

        fi

    fi

    # Reset GoIPFS Install and Upgrade Variables
    IPFS_INSTALL_TYPE=""
    IPFS_UPDATE_AVAILABLE=NO
    IPFS_POSTUPDATE_CLEANUP=YES

    printf "\\n"

fi

# Enable and start IPFS service if it is installed but not running for some reason (perhaps due to a failed previous install)
if [ "$IPFS_STATUS" = "stopped" ]; then

    printf " =============== Starting: IPFS ========================================\\n\\n"
    # ==============================================================================

    printf "%b IPFS is installed but not currently running.\\n" "${INFO}"

    if [ "$INIT_SYSTEM" = "systemd" ]; then

        # Enable the service to run at boot
        str="Enabling IPFS systemd service..."
        printf "%b %s" "${INFO}" "${str}"
        systemctl enable ipfs
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Start the service now
        str="Starting IPFS systemd service..."
        printf "%b %s" "${INFO}" "${str}"
        systemctl start ipfs
        IPFS_STATUS="running"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    if [ "$INIT_SYSTEM" = "upstart" ]; then

        # Enable the service to run at boot
        str="Starting IPFS upstart service..."
        printf "%b %s" "${INFO}" "${str}"
        service ipfs start
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        IPFS_STATUS="running"

    fi

    printf "\\n"

fi

}


# Set the IPFS port based on whether we are using DigiByte mainnet or testnet. 
# This is to ensure that if you run a testnet node and a mainnet node on the same network they do not both use the same IPFS port and conflict with each other. Default IPFS port with mainnet is 4001. Default IPFS port with testnet is 4004. If another port number has been used they will be left as they are.

ipfs_update_port() {

    # If we are using Kubo IPFS

    if [ -f "$USER_HOME/.ipfs/config" ]; then

        # If using DigiByte testnet, change default Kubo IPFS port to 4004

        local update_ipfsport_now

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP4" = "4001" ]]; then
            str="Using DigiByte testnet. Changing Kubo IPFS IP4 port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4004\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP6" = "4001" ]]; then
            str="Using DigiByte testnet. Changing Kubo IPFS IP6 port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4004\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP4_QUIC" = "4001" ]]; then
            str="Using DigiByte testnet. Changing Kubo IPFS IP4 quic port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4004/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP6_QUIC" = "4001" ]]; then
            str="Using DigiByte testnet. Changing Kubo IPFS IP6 quic port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4004/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If using DigiByte mainnet, change default Kubo IPFS port to 4001

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP4" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing Kubo IPFS IP4 port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4001\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP6" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing Kubo IPFS IP6 port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4001\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP4_QUIC" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing Kubo IPFS IP4 quic port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4001/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP6_QUIC" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing Kubo IPFS IP6 quic port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4001/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi

    # If we are using JS-IPFS

    if [ -f "$USER_HOME/.jsipfs/config" ]; then

        # If using DigiByte testnet, change default JS-IPFS port to 4004

        local update_ipfsport_now

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP4" = "4001" ]]; then
            str="Using DigiByte testnet. Changing JS-IPFS IP4 port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4004\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP6" = "4001" ]]; then
            str="Using DigiByte testnet. Changing JS-IPFS IP6 port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4004\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP4_QUIC" = "4001" ]]; then
            str="Using DigiByte testnet. Changing JS-IPFS IP4 quic port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4004/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP6_QUIC" = "4001" ]]; then
            str="Using DigiByte testnet. Changing JS-IPFS IP6 quic port from 4001 to 4004..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4004/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If using DigiByte mainnet, change default JS-IPFS port to 4001

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP4" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing JS-IPFS IP4 port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4001\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP6" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing JS-IPFS IP6 port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4001\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP4_QUIC" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing JS-IPFS IP4 quic port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4001/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP6_QUIC" = "4004" ]]; then
            str="Using DigiByte mainnet. Changing JS-IPFS IP6 quic port from 4004 to 4001..."
            printf "%b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4001/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi

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
        printf " =============== Install: IPFS Daemon Service ==========================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_SERVICE_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: IPFS Daemon Service ============================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-configure the IPFS service.\\n" "${INFO}"
    fi


    # If IPFS systemd service file already exists, and we are in Reset Mode, stop it and delete it, since we will replace it
    if [ -f "$IPFS_SYSTEMD_SERVICE_FILE" ] && [ "$IPFS_SERVICE_INSTALL_TYPE" = "reset" ]; then

        printf "%b Preparing Reset: Stopping and disabling IPFS service ...\\n" "${INFO}"

        # Stop the service now
        systemctl stop ipfs
        IPFS_STATUS="stopped"

        # Disable the service now
        systemctl disable ipfs

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

        printf "%b IPFS systemd service will now be created.\\n" "${INFO}"

        # First create the folders it lives in if they don't already exist

 #       if [ ! -d $USER_HOME/.config ]; then
 #           str="Creating ~/.config folder..."
 #           printf "%b %s" "${INFO}" "${str}"
 #           sudo -u $USER_ACCOUNT mkdir $USER_HOME/.config
 #           printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
 #       fi
 #       if [ ! -d $USER_HOME/.config/systemd ]; then
 #           str="Creating ~/.config/systemd folder..."
 #           printf "%b %s" "${INFO}" "${str}"
 #           sudo -u $USER_ACCOUNT mkdir $USER_HOME/.config/systemd
 #           printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
 #       fi
 #       if [ ! -d $USER_HOME/.config/systemd/user ]; then
 #           str="Creating ~/.config/systemd/user folder..."
 #           printf "%b %s" "${INFO}" "${str}"
 #           sudo -u $USER_ACCOUNT mkdir $USER_HOME/.config/systemd/user
 #           printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
 #       fi
        
        # Create a new IPFS service file

        str="Creating IPFS systemd service file: $IPFS_SYSTEMD_SERVICE_FILE ... "
        printf "%b %s" "${INFO}" "${str}"
        touch $IPFS_SYSTEMD_SERVICE_FILE
        cat <<EOF > $IPFS_SYSTEMD_SERVICE_FILE
# This file will be overwritten on package upgrades, avoid customizations here.
#
# To make persistant changes, create file in 
# "/etc/systemd/system/ipfs.service.d/overwrite.conf" with 
# \`systemctl edit ipfs.service\`. This file will be parsed after this 
# file has been parsed.
#
# To overwrite a variable, like ExecStart you have to specify it once
# blank and a second time with a new value, like:
# ExecStart=
# ExecStart=/usr/bin/ipfs daemon --flag1 --flag2
#
# For more info about custom unit files see systemd.unit(5).

[Unit]
Description=InterPlanetary File System (IPFS) daemon
Documentation=https://docs.ipfs.io/
After=network.target

[Service]

# enable for 1-1024 port listening
#AmbientCapabilities=CAP_NET_BIND_SERVICE 
# enable to specify a custom path see docs/environment-variables.md for further documentations
#Environment=IPFS_PATH=/custom/ipfs/path
# enable to specify a higher limit for open files/connections
#LimitNOFILE=1000000

#don't use swap
MemorySwapMax=0

# Don't timeout on startup. Opening the IPFS repo can take a long time in some cases (e.g., when
# badger is recovering) and migrations can delay startup.
#
# Ideally, we'd be a bit smarter about this but there's no good way to do that without hooking
# systemd dependencies deeper into Kubo.
TimeoutStartSec=infinity

Type=notify
User=$USER_ACCOUNT
Group=$USER_ACCOUNT
StateDirectory=ipfs
Environment=IPFS_PATH=$USER_HOME/.ipfs
ExecStart=
ExecStart=/usr/local/bin/ipfs daemon --init --migrate
Restart=on-failure
KillSignal=SIGINT

[Install]
WantedBy=default.target


EOF
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

#        # Enable linger so IPFS can run at boot
#        str="Enable lingering for user $USER_ACCOUNT..."
#        printf "%b %s" "${INFO}" "${str}"
#        loginctl enable-linger $USER_ACCOUNT
#        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
#        str=""

        # Enable the service to run at boot
        printf "%b Enabling IPFS systemd service...\\n" "${INFO}"
        systemctl enable ipfs
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Start the service now
        str="Starting IPFS systemd service..."
        printf "%b %s" "${INFO}" "${str}"
        systemctl start ipfs
        IPFS_STATUS="running"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        str=""

    fi

    # If using upstart and the IPFS service file does not exist yet, let's create it
    if [ -f "$IPFS_UPSTART_SERVICE_FILE" ] && [ $INIT_SYSTEM = "upstart" ]; then

        printf "%b IPFS upstart service will now be created.\\n" "${INFO}"

        # Create a new IPFS upstart service file

        str="Creating IPFS upstart service file: $IPFS_UPSTART_SERVICE_FILE ... "
        printf "%b %s" "${INFO}" "${str}"
        touch $IPFS_UPSTART_SERVICE_FILE
        cat <<EOF > $IPFS_UPSTART_SERVICE_FILE
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
    if [ "$INIT_SYSTEM" = "sysv-init" ] || [ "$INIT_SYSTEM" = "unknown" ]; then

        printf "%b Unable to create an IPFS service for your system - systemd/upstart not found.\\n" "${CROSS}"
        printf "%b Please contact @digibytehelp on Twitter for help.\\n" "${CROSS}"
        exit 1

    fi

    printf "\\n"

fi

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
        sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: NodeJS v${NODEJS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Get current NodeJS major version
    str="Is NodeJS at least version 16?..."
    NODEJS_VER_LOCAL_MAJOR=$(echo $NODEJS_VER_LOCAL | cut -d'.' -f 1)
    if [ "$NODEJS_VER_LOCAL_MAJOR" != "" ]; then
        printf "%b %s" "${INFO}" "${str}"
        if [ "$NODEJS_VER_LOCAL_MAJOR" -lt "16" ]; then
            NODEJS_PPA_ADDED="NO"
            printf "%b%b %s NO! NodeSource PPA will be re-added.\\n" "${OVER}" "${CROSS}" "${str}"
        else
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi


    # If this is the first time running the NodeJS check, and we are doing a full install, let's add the official repositories to ensure we get the latest version
    if [ "$NODEJS_PPA_ADDED" = "" ] || [ "$NODEJS_PPA_ADDED" = "NO" ]; then

        # Is this Debian or Ubuntu?
        local is_debian=$(cat /etc/os-release | grep ID | grep debian -Eo)
        local is_ubuntu=$(cat /etc/os-release | grep ID | grep ubuntu -Eo)
        local is_fedora=$(cat /etc/os-release | grep ID | grep fedora -Eo)
        local is_centos=$(cat /etc/os-release | grep ID | grep centos -Eo)

        # Set correct PPA repository
        if [ "$is_ubuntu" = "ubuntu" ]; then
            printf "%b Adding NodeSource PPA for NodeJS LTS version for Ubuntu...\\n" "${INFO}"
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            NODEJS_PPA_ADDED=YES
        elif [ "$is_debian" = "debian" ]; then
            printf "%b Adding NodeSource PPA for NodeJS LTS version for Debian...\\n" "${INFO}"
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            NODEJS_PPA_ADDED=YES
        elif [ "$is_fedora" = "fedora" ]; then
            printf "%b Adding NodeSource PPA for NodeJS LTS version for Fedora...\\n" "${INFO}"
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            NODEJS_PPA_ADDED=YES
        elif [ "$is_centos" = "centos" ]; then
            printf "%b Adding NodeSource PPA for NodeJS LTS version for CentOS...\\n" "${INFO}"
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            NODEJS_PPA_ADDED=YES
        else
            printf "%b Adding NodeSource PPA for NodeJS LTS version for unknown distro...\\n" "${INFO}"
            curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
            NODEJS_PPA_ADDED=YES
        fi


        # Update variable in diginode.settings so this does not run again
        sed -i -e "/^NODEJS_PPA_ADDED=/s|.*|NODEJS_PPA_ADDED=\"$NODEJS_PPA_ADDED\"|" $DGNT_SETTINGS_FILE
    else
        printf "%b NodeSource PPA repository has already been added or is not required.\\n" "${TICK}"
        printf "%b If needed, you can have this script attempt to add it, by editing the diginode.settings\\n" "${INDENT}"
        printf "%b file in the ~/.digibyte folder and changing the NODEJS_PPA_ADDED value to NO. \\n" "${INDENT}"
    fi

    # Look up the latest candidate release
    str="Checking for the latest NodeJS release..."
    printf "%b %s" "${INFO}" "${str}"

    if [ "$PKG_MANAGER" = "apt-get" ]; then
        # Gets latest NodeJS release version, disregarding releases candidates (they contain 'rc' in the name).
        NODEJS_VER_RELEASE=$(apt-cache policy nodejs | grep Candidate | cut -d' ' -f4 | cut -d'-' -f1 | cut -d'~' -f1)
    fi

    if [ "$PKG_MANAGER" = "dnf" ]; then
        # Gets latest NodeJS release version, disregarding releases candidates (they contain 'rc' in the name).
        printf "%b ERROR: DigiNode Setup is not yet able to check for NodeJS releases with dnf.\\n" "${CROSS}"
        exit 1
    fi

    if [ "$PKG_MANAGER" = "yum" ]; then
        # Gets latest NodeJS release version, disregarding releases candidates (they contain 'rc' in the name).
        printf "%b ERROR: DigiNode Setup is not yet able to check for NodeJS releases with yum.\\n" "${CROSS}"
        exit 1
    fi

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
        sed -i -e "/^NODEJS_VER_RELEASE=/s|.*|NODEJS_VER_RELEASE=\"$NODEJS_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
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
          printf "%b %bNodeJS can be upgraded from v${NODEJS_VER_LOCAL} to v${NODEJS_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
      printf "%b %bNodeJS v${NODEJS_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
    if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
        printf " =============== Install: NodeJS =======================================\\n\\n"
        # ==============================================================================
    elif [ "$NODEJS_INSTALL_TYPE" = "majorupgrade" ] || [ $NODEJS_INSTALL_TYPE = "upgrade" ]; then
        printf " =============== Upgrade: NodeJS =======================================\\n\\n"
        # ==============================================================================
    elif [ "$NODEJS_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: NodeJS =========================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose re-install NodeJS.\\n" "${INFO}"
    fi


    # Do apt-get installation of NodeJS
    if [ "$PKG_MANAGER" = "apt-get" ]; then

        # Install NodeJS if it does not exist
        if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
            printf "%b Installing NodeJS v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            printf "\\n"
        fi

        # If NodeJS 14 exists, upgrade it
        if [ "$NODEJS_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Updating to NodeJS v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

        # If NodeJS exists, but needs a major upgrade, remove the old versions first as there can be conflicts
        if [ "$NODEJS_INSTALL_TYPE" = "majorupgrade" ]; then
            printf "%b Since this is a major upgrade, the old versions of NodeJS will be removed first, to ensure there are no conflicts.\\n" "${INFO}"
            printf "%b Purging old versions of NodeJS v${NODEJS_VER_LOCAL} ...\\n" "${INFO}"
            sudo apt-get purge nodejs-legacy nodejs -y -q
            sudo apt-get autoremove -y -q
            printf "\\n"
            printf "%b Installing NodeJS v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

        # If we are in Reset Mode, remove and re-install
        if [ "$NODEJS_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Mode is ENABLED. Removing NodeJS v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get purge nodejs-legacy nodejs -y -q
            sudo apt-get autoremove -y -q
            printf "\\n"
            printf "%b Re-installing NodeJS v${NODEJS_VER_RELEASE} ...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

    fi

    # Do yum installation of NodeJS
    if [ "$PKG_MANAGER" = "yum" ]; then
            # Install NodeJS if it does not exist
        if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
            printf "%b Installing NodeJS v${NODEJS_VER_RELEASE} with yum..\\n" "${INFO}"
            yum install nodejs14
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

    fi

    # Do dnf installation of NodeJS
    if [ "$PKG_MANAGER" = "dnf" ]; then
        # Install NodeJS if it does not exist
        if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
            printf "%b Installing NodeJS v${NODEJS_VER_RELEASE} with dnf..\\n" "${INFO}"
            dnf module install nodejs:12
            printf "\\n"
            DIGINODE_UPGRADED="YES"
        fi

    fi


    # Get the new version number of the NodeJS install
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | cut -d' ' -f3)

    # Later versions use purely the 'node --version' command, (rather than nodejs)
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_VER_LOCAL=$(node --version 2>/dev/null | cut -d' ' -f3)
    fi

    # Update diginode.settings with new NodeJS local version number and the install/upgrade date
    sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    if [ "$NODEJS_INSTALL_TYPE" = "new" ] || [ "$NODEJS_INSTALL_TYPE" = "reset" ]; then
        NODEJS_INSTALL_DATE="$(date)"
        sed -i -e "/^NODEJS_INSTALL_DATE=/s|.*|NODEJS_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ "$NODEJS_INSTALL_TYPE" = "upgrade" ] || [ "$NODEJS_INSTALL_TYPE" = "majorupgrade" ]; then
        NODEJS_UPGRADE_DATE="$(date)"
        sed -i -e "/^NODEJS_UPGRADE_DATE=/s|.*|NODEJS_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Reset NodeJS Install and Upgrade Variables
    NODEJS_INSTALL_TYPE=""
    NODEJS_UPDATE_AVAILABLE=NO
    NODEJS_POSTUPDATE_CLEANUP=YES

    printf "\\n"

fi

# If there is no install date (i.e. NodeJS was already installed when this script was first run) add it now, since it was up-to-date at this time
if [ "$NODEJS_INSTALL_DATE" = "" ]; then
    NODEJS_INSTALL_DATE="$(date)"
    sed -i -e "/^NODEJS_INSTALL_DATE=/s|.*|NODEJS_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
fi


}

# This function will check if DigiAsset Node is installed, and if it is, check if there is an update available

digiasset_node_check() {

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    printf " =============== Checking: DigiAsset Node ==============================\\n\\n"
    # ==============================================================================

    # Let's check if this is an Official DigiAsset Node is already installed. This file is created after a succesful previous installation with DigiNode Setup.
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
        IS_DGANODE_RUNNING=$(ps aux | sed '/grep/d' | grep "node index.js" -Eo)
        printf "%b %s" "${INFO}" "${str}"
        if [ "$IS_DGANODE_RUNNING" = "node index.js" ]; then
            DGA_STATUS="running"
            IS_DGANODE_RUNNING="YES"
            printf "%b%b %s YES! [ Using: node index.js ]\\n" "${OVER}" "${TICK}" "${str}"
        else
            # If that didn't work, check if it is running using PM2
            IS_DGANODE_RUNNING=$(ps aux | sed '/grep/d' | grep digiasset_node/index.js -Eo)
            if [ "$IS_DGANODE_RUNNING" = "digiasset_node/index.js" ]; then
                DGA_STATUS="running"
                IS_PM2_RUNNING="YES"
                printf "%b%b %s YES! [ PM2 digiasset process is running ]\\n" "${OVER}" "${TICK}" "${str}"
            else
                IS_PM2_RUNNING=$(sudo -u $USER_ACCOUNT pm2 pid digiasset 2>/dev/null)
                if [ "$IS_PM2_RUNNING" = "0" ]; then
                    DGA_STATUS="stopped"
                    IS_PM2_RUNNING="NO"
                    printf "%b%b %s NO! [ PM2 digiasset process is stopped ]\\n" "${OVER}" "${CROSS}" "${str}"
                elif [ "$IS_PM2_RUNNING" = "" ]; then
                    DGA_STATUS="stopped"
                    IS_PM2_RUNNING="NO" 
                    printf "%b%b %s NO!  [ PM2 digiasset process does not exist ]\\n" "${OVER}" "${CROSS}" "${str}"
                else
                    DGA_STATUS="running"
                    IS_PM2_RUNNING="YES"
                    printf "%b%b %s YES! [ PM2 digiasset process is probably running ]\\n" "${OVER}" "${TICK}" "${str}"
                fi
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
        sed -i -e "/^DGA_VER_MJR_LOCAL=/s|.*|DGA_VER_MJR_LOCAL=\"$DGA_VER_MJR_LOCAL\"|" $DGNT_SETTINGS_FILE
      fi
    fi

     # Get the current local branch, if it exists
     if [ -f "$DGA_INSTALL_LOCATION" ]; then
        DGA_LOCAL_BRANCH=$(git -C $DGA_INSTALL_LOCATION rev-parse --abbrev-ref HEAD 2>/dev/null)
    fi

    # If we get a valid local branch, update the stored local branch
    if [ "$DGA_LOCAL_BRANCH" != "" ]; then
        sed -i -e "/^DGA_LOCAL_BRANCH=/s|.*|DGA_LOCAL_BRANCH=\"$DGA_LOCAL_BRANCH\"|" $DGNT_SETTINGS_FILE
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
            if [ "$DGA_LOCAL_BRANCH" = "main" ]; then
                DGA_VER_MNR_LOCAL=""
                str="Current Version:"
                printf "%b %s" "${INFO}" "${str}"
                sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=\"$DGA_VER_MNR_LOCAL\"|" $DGNT_SETTINGS_FILE
                printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL}.x\\n" "${OVER}" "${INFO}" "${str}"
            fi
            if [ "$DGA_LOCAL_BRANCH" = "development" ]; then
                DGA_VER_MNR_LOCAL="beta"
                str="Current Version:"
                printf "%b %s" "${INFO}" "${str}"
                sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=\"$DGA_VER_MNR_LOCAL\"|" $DGNT_SETTINGS_FILE
                printf "%b%b %s DigiAsset Node v${DGA_VER_MJR_LOCAL} beta\\n" "${OVER}" "${INFO}" "${str}"
            fi

        # If we actually get a version number then we can use it
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
    fi


    # Now we can update the main DGA_VER_LOCAL variable with the current version (major or minor depending on what was found)
    if [ "$DGA_VER_MNR_LOCAL" = "beta" ]; then
        DGA_VER_LOCAL="$DGA_VER_MJR_LOCAL beta"  # e.g. DigiAsset Node v3 beta
    elif [ "$DGA_VER_MNR_LOCAL" = "" ]; then
        DGA_VER_LOCAL="$DGA_VER_MJR_LOCAL"       # e.g. DigiAsset Node v3
    elif [ "$DGA_VER_MNR_LOCAL" != "" ]; then
        DGA_VER_LOCAL="$DGA_VER_MNR_LOCAL"       # e.g. DigiAsset Node v3.2
    fi
    sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=\"$DGA_VER_LOCAL\"|" $DGNT_SETTINGS_FILE


    # Next we need to check for the latest release at the DigiAssetX website
    str="Querying DigiAssetX website for the latest release..."
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
        sed -i -e "/^DGA_VER_RELEASE=/s|.*|DGA_VER_RELEASE=\"$DGA_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
        DGA_VER_MJR_RELEASE=$(echo $DGA_VER_RELEASE | cut -d'.' -f1)
        sed -i -e "/^DGA_VER_MJR_RELEASE=/s|.*|DGA_VER_MJR_RELEASE=\"$DGA_VER_MJR_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi


    ###############################################################################
    # TEMPORARY FIX TO UPGRADE v3 RELEASE TO USE DEV VERSION UNTIL v4 IS RELEASED #
    ###############################################################################

    if [ "$DGA_VER_MJR_RELEASE" = "3" ]; then
        printf "%b ${txtbylw}DigiAsset Node v3.x release version found. Requesting development version instead...${txtrst}\\n" "${INFO}"
        printf "%b (DigiNode Tools now requires at least DigiAsset Node v4 so the development version\\n" "${INDENT}"
        printf "%b  will automatically be installed until v4 is officially released.)\\n" "${INDENT}"
        DGA_BRANCH="development"
    fi

    ###############################################################################
    # END TEMPORARY FIX
    ###############################################################################

    # Requested branch
    if [ "$DGA_BRANCH" = "development" ]; then
        printf "%b DigiAsset Node development version requested.\\n" "${INFO}"
    elif [ "$DGA_BRANCH" = "main" ]; then
        printf "%b DigiAsset Node release version requested.\\n" "${INFO}"
    fi


    # Upgrade to release branch
    if [ "$DGA_BRANCH" = "main" ]; then
        # If it's the release version lookup latest version (this is what is used normally, with no argument specified)

        if [ "$DGA_LOCAL_BRANCH" = "main" ]; then

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

                    # Restart PM2 Service if it is not running and no upgrade is required
                    if [ "$DGA_DO_INSTALL" = "NO" ] && [ "$DGA_INSTALL_TYPE" = "none" ] && [ "$DGA_UPDATE_AVAILABLE" = "NO" ] && [ "$DGA_STATUS" = "stopped" ]; then

                        # Start DigiAsset Node, and tell it to save the current setup. This will ensure it runs the digiasset node automatically when PM2 starts.
                        printf "%b DigiAsset Node PM2 Service is not currently running. Starting Service...\\n" "${INFO}"
                        cd $DGA_INSTALL_LOCATION
                        is_pm2_digiasset_running=$(pm2 status digiasset | grep -Eo -m 1 digiasset)
                        if [ "$is_pm2_digiasset_running" != "digiasset" ]; then
                            sudo -u $USER_ACCOUNT PM2_HOME=$USER_HOME/.pm2 pm2 start index.js -f --name digiasset -- --log
                            printf "%b Saving PM2 process state..\\n" "${INFO}"
                            sudo -u $USER_ACCOUNT pm2 save -force
                        fi

                    fi
                    printf "\\n"

                    return
                  fi
            else        
                printf "%b %bDigiAsset Node can be upgraded from v{$DGA_VER_LOCAL} to v${DGA_VER_RELEASE}.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                DGA_INSTALL_TYPE="upgrade"
                DGA_ASK_UPGRADE=YES
            fi


        elif [ "$DGA_LOCAL_BRANCH" = "development" ]; then
            printf "%b %bDigiAsset Node will be upgraded from the development branch to the v${DGA_VER_RELEASE} release version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGA_INSTALL_TYPE="upgrade"
            DGA_DO_INSTALL=YES
        else 
            printf "%b %bDigiAsset Node v${DGA_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGA_INSTALL_TYPE="new"
            DGA_DO_INSTALL="if_doing_full_install"
        fi

    # Upgrade to development branch
    elif [ "$DGA_BRANCH" = "development" ]; then
        if [ "$DGA_LOCAL_BRANCH" = "main" ]; then
            printf "%b %bDigiAsset Node v${DGA_VER_LOCAL} will be replaced with the development branch.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGA_INSTALL_TYPE="upgrade"
            DGA_DO_INSTALL=YES
        elif [ "$DGA_LOCAL_BRANCH" = "development" ]; then
            printf "%b %bDigiAsset Node development branch will be upgraded to the latest version.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGA_INSTALL_TYPE="upgrade"
            DGA_DO_INSTALL=YES
        else
            printf "%b %bDigiAsset Node development branch will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGA_INSTALL_TYPE="new"
            DGA_DO_INSTALL="if_doing_full_install"
        fi
    
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

# If we are in reset mode, ask the user if they want to reinstall DigiAsset Node
if [ "$DGA_INSTALL_TYPE" = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install DigiAsset Node v${DGA_VER_RELEASE}?\\n\\nNote: This will delete your current DigiAsset Node folder at $DGA_INSTALL_LOCATION and re-install it. Your DigiAsset settings folder at ~/digiasset_node/_config will be kept." "${r}" "${c}"; then
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
    if [ "$DGA_INSTALL_TYPE" = "new" ]; then
        printf " =============== Install: DigiAsset Node ===============================\\n\\n"
        # ==============================================================================
    elif [ "$DGA_INSTALL_TYPE" = "upgrade" ]; then
        printf " =============== Upgrade: DigiAsset Node ===============================\\n\\n"
        # ==============================================================================
    elif [ "$DGA_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: DigiAsset Node =================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-install DigiAsset Node.\\n" "${INFO}"
    fi

    # Get the local version number of NodeJS (this will also tell us if it is installed)
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')

    # Later versions use purely the 'node --version' command, (rather than nodejs)
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
    fi

    # Get current NodeJS major version
    str="Is NodeJS installed and at least version 16?..."
    NODEJS_VER_LOCAL_MAJOR=$(echo $NODEJS_VER_LOCAL | cut -d'.' -f 1)
    if [ "$NODEJS_VER_LOCAL_MAJOR" != "" ]; then
        printf "%b %s" "${INFO}" "${str}"
        if [ "$NODEJS_VER_LOCAL_MAJOR" -lt "16" ]; then
            printf "\\n"
            printf "%b%b ${txtred}ERROR: NodeJS 16.x or greater is required to run a DigiAsset Node!${txtrst}\\n" "${OVER}" "${CROSS}"
            printf "\\n"
            printf "%b You need to install the correct Nodesource PPA for your distro.\\n" "${INFO}"
            printf "%b Please get in touch via the DigiNode Tools Telegram group so a fix can be made for your distro.\\n" "${INDENT}"
            printf "\\n"
            exit 1
        else
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: NodeJS is not installed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b You need to install NodeJS. It should have been installed before this, but there was likely an error.\\n" "${INFO}"
        printf "%b Please get in touch via the DigiNode Tools Telegram group so a fix can be made for your distro.\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # If we are in Reset Mode and PM2 is running let's stop it
    if [ "$DGA_STATUS" = "running" ] && [ "$IS_PM2_RUNNING" = "YES" ] && [ "$DGA_INSTALL_TYPE" = "reset" ]; then
       printf "%b Reset Mode: Stopping PM2 digiasset service...\\n" "${INFO}"
       sudo -u $USER_ACCOUNT pm2 stop digiasset
       DGA_STATUS="stopped"
    fi

    if [ "$DGA_INSTALL_TYPE" = "reset" ]; then

        str="Reset Mode: Delete DigiAsset Node pm2 instance..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT pm2 delete digiasset
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"

        # Delete existing 'digiasset_node' files (if they exists)
        if [[ -d $DGA_INSTALL_LOCATION/lib ]]; then
            str="Removing existing DigiAsset Node files..."
            printf "%b %s" "${INFO}" "${str}"
            rm -rf $DGA_INSTALL_LOCATION/lib
            rm -rf $DGA_INSTALL_LOCATION/node_modules
            rm -rf $DGA_INSTALL_LOCATION/template
            rm $DGA_INSTALL_LOCATION/index.js
            rm $DGA_INSTALL_LOCATION/LICENCE
            rm $DGA_INSTALL_LOCATION/*.log
            rm $DGA_INSTALL_LOCATION/*.json
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi


    # Prepare UPGRADE - delete PM2 service, backup DigiAsset Node Settings, dete DigiAsset Node folder

    if [ "$DGA_INSTALL_TYPE" = "upgrade" ]; then

        # Start DigiAsset Node, and tell it to save the current setup. This will ensure it runs the digiasset node automatically when PM2 starts.
        is_pm2_digiasset_running=$(sudo -u $USER_ACCOUNT pm2 status digiasset | grep -Eo -m 1 digiasset)
        if [ "$is_pm2_digiasset_running" = "digiasset" ]; then
            printf "%b Preparing Upgrade: Stopping DigiAsset Node PM2 process...\\n" "${INFO}"
            sudo -u $USER_ACCOUNT pm2 stop digiasset
            printf "%b Preparing Upgrade: Deleting DigiAsset Node PM2 process...\\n" "${INFO}"
            sudo -u $USER_ACCOUNT pm2 delete digiasset
            DGA_STATUS="stopped"
        fi

        # create ~/dga_config_backup/ folder if it does not already exist
        if [ ! -d $DGA_SETTINGS_BACKUP_LOCATION ]; then #
            str="Preparing Upgrade: Creating ~/dga_config_backup/ backup folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $DGA_SETTINGS_BACKUP_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    
        # Delete asset_settings folder
        str="Preparing Upgrade: Backing up DigiAsset settings to ~/dga_config_backup"
        printf "%b %s" "${INFO}" "${str}" 
        mv $DGA_SETTINGS_LOCATION/*.json $DGA_SETTINGS_BACKUP_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Delete existing 'digiasset_node' folder (if it exists)
        str="Preparing Upgrade: Deleting ~/digiasset_node folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r -f $USER_HOME/digiasset_node
        DGA_LOCAL_BRANCH=""
        sed -i -e "/^DGA_LOCAL_BRANCH=/s|.*|DGA_LOCAL_BRANCH=|" $DGNT_SETTINGS_FILE
        DGA_VER_LOCAL=""
        sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=|" $DGNT_SETTINGS_FILE
        DGA_VER_MJR_LOCAL=""
        sed -i -e "/^DGA_VER_MJR_LOCAL=/s|.*|DGA_VER_MJR_LOCAL=|" $DGNT_SETTINGS_FILE
        DGA_VER_MNR_LOCAL=""
        sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    fi


    # Let's check if npm is already installed
    str="Is npm already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    NPM_VER_LOCAL=$(npm -v 2>/dev/null)
    if [ "$NPM_VER_LOCAL" = "" ]; then
        NPM_DO_INSTALL="YES"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        # If no local version can be detected, let's immediately install npm
    else
        printf "%b%b %s YES!   Found: npm v${NPM_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
        CHECK_FOR_NPM_UPDATE="YES"
    fi

    # Install npm now if it is not installed
    if [ "$NPM_DO_INSTALL" = "YES" ]; then
        install_dependent_packages npm
    fi


    # If npm is installed, check for npm update
    if [ "$CHECK_FOR_NPM_UPDATE" = "YES" ]; then

        # Check for latest npm release online
        str="Checking the latest npm release..."
        printf "%b %s" "${INFO}" "${str}"
        # Gets latest npm version
        NPM_VER_RELEASE=$(npm show npm version 2>/dev/null)

        # If can't get npm release version number
        if [ "$NPM_VER_RELEASE" = "" ]; then
            printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b Unable to check for new version of npm. Is the Internet down?.\\n" "${CROSS}"
            printf "\\n"
            printf "%b npm cannot be upgraded at this time. Skipping...\\n" "${INFO}"
            printf "\\n"   
        else
            printf "%b%b %s Found: npm v${NPM_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If an npm local version already exists.... (i.e. we have a local version number)
        if [ ! $NPM_VER_LOCAL = "" ] && [ ! $NPM_VER_RELEASE = "" ]; then
          # ....then check if an upgrade is required
          if [ $(version $NPM_VER_LOCAL) -ge $(version $NPM_VER_RELEASE) ]; then
              printf "%b npm is already up to date.\\n" "${TICK}"
              if [ "$RESET_MODE" = true ]; then
                printf "%b Reset Mode is Enabled. npm v${NPM_VER_RELEASE} will be re-installed.\\n" "${INFO}"
                NPM_DO_INSTALL=YES
              else
                printf "%b Upgrade not required for npm.\\n" "${INFO}"
              fi
          else
              printf "%b %bnpm will be upgraded from v${NPM_VER_LOCAL} to v${NPM_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
              NPM_DO_INSTALL="YES"
          fi
        fi 

        # Install the latest version of npm, if needed
        if [ "$NPM_DO_INSTALL" = "YES" ]; then
            printf "%b Install latest version of npm...\\n" "${INFO}"
            npm install --quiet npm@latest -g
        fi

    fi


    # Let's check if pm2 is already installed
    str="Is pm2 already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    PM2_VER_LOCAL=$(npm list -g --depth=0 pm2 2>/dev/null | grep pm2 | cut -d'@' -f2)
    if [ "$PM2_VER_LOCAL" = "" ]; then
        PM2_DO_INSTALL="YES"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
    else
        printf "%b%b %s YES!   Found: pm2 v${PM2_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Check for latest pm2 release online
    str="Checking the latest pm2 release..."
    printf "%b %s" "${INFO}" "${str}"
    # Gets latest PM2 version, disregarding releases candidates (they contain 'rc' in the name).
    PM2_VER_RELEASE=$(npm show pm2 version 2>/dev/null)

    # If can't get pm2 release version number
    if [ "$PM2_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of pm2. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b pm2 cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"   
    else
        printf "%b%b %s Found: pm2 v${PM2_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If an pm2 local version already exists.... (i.e. we have a local version number)
    if [ ! $PM2_VER_LOCAL = "" ] && [ ! $PM2_VER_RELEASE = "" ]; then
      # ....then check if an upgrade is required
      if [ $(version $PM2_VER_LOCAL) -ge $(version $PM2_VER_RELEASE) ]; then
          printf "%b pm2 is already up to date.\\n" "${TICK}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. pm2 v${PM2_VER_RELEASE} will be re-installed.\\n" "${INFO}"
            PM2_DO_INSTALL=YES
          else
            printf "%b Upgrade not required for pm2.\\n" "${INFO}"
          fi
      else
          printf "%b %bpm2 will be upgraded from v${PM2_VER_LOCAL} to v${PM2_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          PM2_DO_INSTALL="YES"
      fi
    fi 

    # Install the latest version of PM2, if needed
    if [ "$PM2_DO_INSTALL" = "YES" ]; then
        printf "%b Install latest version of pm2...\\n" "${INFO}"
        npm install --quiet pm2@latest -g
    fi

    # Next install the newest version
    cd $USER_HOME

    # Clone the development version if develop flag is set, and this is a new install
    if [ "$DGA_BRANCH" = "development" ] && [ "$DGA_INSTALL_TYPE" = "new" ]; then
        str="Cloning DigiAsset Node development branch from Github repository..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch development https://github.com/digiassetX/digiasset_node.git
        sed -i -e "/^DGA_LOCAL_BRANCH=/s|.*|DGA_LOCAL_BRANCH=\"development\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Fetch the development version if develop flag is set, and this is an update
    elif [ "$DGA_BRANCH" = "development" ] && [ "$DGA_INSTALL_TYPE" = "upgrade" ]; then
        str="Cloning DigiAsset Node development branch from Github repository..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch development https://github.com/digiassetX/digiasset_node.git
        sed -i -e "/^DGA_LOCAL_BRANCH=/s|.*|DGA_LOCAL_BRANCH=\"development\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Clone the release version if main flag is set, and this is a new install
    elif [ "$DGA_BRANCH" = "main" ] && [ "$DGA_INSTALL_TYPE" = "new" ]; then
        str="Cloning DigiAsset Node v${DGA_VER_RELEASE} from Github repository..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT git clone --depth 1 --quiet https://github.com/digiassetX/digiasset_node.git
       sed -i -e "/^DGA_LOCAL_BRANCH=/s|.*|DGA_LOCAL_BRANCH=\"main\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Fetch the release version if main flag is set, and this is an update
    elif [ "$DGA_BRANCH" = "main" ] && [ "$DGA_INSTALL_TYPE" = "upgrade" ]; then
        str="Cloning DigiAsset Node v${DGA_VER_RELEASE} from Github repository..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT git clone --depth 1 --quiet https://github.com/digiassetX/digiasset_node.git
        sed -i -e "/^DGA_LOCAL_BRANCH=/s|.*|DGA_LOCAL_BRANCH=\"main\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Restore DigiAsset Node settings from local backup, if it exists, and then delete the backup folder
    if [ -f $DGA_SETTINGS_BACKUP_FILE ] && [ ! -f $DGA_SETTINGS_FILE ]; then

        # create ~/digiasset_node/_config folder, it does not already exist
        if [ ! -d $DGA_SETTINGS_LOCATION ]; then #
            str="Creating ~/digiasset_node/_config settings folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $DGA_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        str="Restoring DigiAsset configuration files from local backup..."
        printf "%b %s" "${INFO}" "${str}"
        mv $DGA_SETTINGS_BACKUP_LOCATION/*.json $DGA_SETTINGS_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        str="Removing DigiAsset configuration local backup folder: ~/dga_config_backup ..."
        printf "%b %s" "${INFO}" "${str}"
        rmdir $DGA_SETTINGS_BACKUP_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Install latest dependencies
    printf "%b Install latest DigiAsset Node dependencies...\\n" "${INFO}"
    cd $DGA_INSTALL_LOCATION
    sudo -u $USER_ACCOUNT npm install
    cd $USER_HOME

    # Start DigiAsset Node, and tell it to save the current setup. This will ensure it runs the digiasset node automatically when PM2 starts.
    printf "%b Starting DigiAsset Node with PM2...\\n" "${INFO}"
    cd $DGA_INSTALL_LOCATION
    sudo -u $USER_ACCOUNT PM2_HOME=$USER_HOME/.pm2 pm2 start index.js -f --name digiasset -- --log
    printf "%b Saving PM2 process state..\\n" "${INFO}"
    sudo -u $USER_ACCOUNT pm2 save -force



    # Update diginode.settings with new DigiAsset Node version number and the install/upgrade date
    DGA_VER_LOCAL=$DGA_VER_RELEASE
    sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=\"$DGA_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    if [ "$DGA_INSTALL_TYPE" = "new" ] || [ "$DGA_INSTALL_TYPE" = "reset" ]; then
        sed -i -e "/^DGA_INSTALL_DATE=/s|.*|DGA_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ "$DGA_INSTALL_TYPE" = "upgrade" ]; then
        sed -i -e "/^DGA_UPGRADE_DATE=/s|.*|DGA_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
        DIGINODE_UPGRADED="YES"
    fi

    # Reset DGA Install and Upgrade Variables
    DGA_INSTALL_TYPE=""
    DGA_UPDATE_AVAILABLE=NO
    DGA_POSTUPDATE_CLEANUP=YES

    # Create DigiAsset Node PM2

    # Create hidden file in the 'digiasset_node' folder to denote this version was installed with the official DigiNode Setup script
    if [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        sudo -u $USER_ACCOUNT touch $DGA_INSTALL_LOCATION/.officialdiginode
    fi

    printf "\\n"

fi

}

# Create DigiAssets main.json settings file (if it does not already exist), and if it does, updates it with the latest RPC credentials from digibyte.conf
digiasset_node_create_settings() {

    local str

    # If we are in reset mode, ask the user if they want to recreate the entire DigiAssets settings folder if it already exists
    if [ "$RESET_MODE" = true ] && [ -f "$DGA_SETTINGS_FILE" ]; then

        if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to reset your DigiAsset Node settings?\\n\\nThis will delete your current DigiAsset Node settings located in ~/digiasset_node/_config and then recreate them with the default settings." "${r}" "${c}"; then
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

    # If DigiAsset Node live & backup settings do not yet exist, then assume this is a new install
    if [ ! -f "$DGA_SETTINGS_FILE" ] && [ ! -f "$DGA_SETTINGS_BACKUP_FILE" ]; then
                DGA_SETTINGS_CREATE="if_doing_full_install"
                DGA_SETTINGS_CREATE_TYPE="new"
    fi

    # If DigiAsset Node live settings do not exist, but backup settings do, then assume this is a restore install
    if [ ! -f "$DGA_SETTINGS_FILE" ] && [ -f "$DGA_SETTINGS_BACKUP_FILE" ]; then
                DGA_SETTINGS_CREATE="if_doing_full_install"
                DGA_SETTINGS_CREATE_TYPE="restore"
    fi

    # If this is the first time creating the DigiAsset Node settings file, and the user has opted to do a full DigiNode install, then proceed
    if  [ "$DGA_SETTINGS_CREATE_TYPE" = "new" ] && [ "$DGA_SETTINGS_CREATE" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        DGA_SETTINGS_CREATE=YES
    fi

    # If we are restoring the DigiAsset Node backup settings file, and the user has opted to do a full DigiNode install, then proceed
    if  [ "$DGA_SETTINGS_CREATE_TYPE" = "restore" ] && [ "$DGA_SETTINGS_CREATE" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        DGA_SETTINGS_CREATE=YES
    fi

    # Display title if the settings file already exist
    if [ -f $DGA_SETTINGS_FILE ] || [ -f $DGA_SETTINGS_BACKUP_FILE ]; then
            printf " =============== Checking: DigiAsset Node settings =====================\\n\\n"
            # ==============================================================================
    fi

    # Let's get the latest RPC credentials from digibyte.conf if it exists
    if [ -f $DGB_CONF_FILE ]; then
        source $DGB_CONF_FILE
        if [ -f $DGA_SETTINGS_FILE ] || [ -f $DGA_SETTINGS_BACKUP_FILE ]; then
            printf "%b Getting latest RPC credentials from digibyte.conf\\n" "${INFO}"
        fi
    else
        local create_dummy_rpc_credentials="yes"
        rpcuser=no_digibyte_config_file_found
        rpcpassword=no_digibyte_config_file_found
        rpcport=14022
        if [ -f $DGA_SETTINGS_FILE ] || [ -f $DGA_SETTINGS_BACKUP_FILE ]; then
            printf "%b digibyte.conf does not exist. Placeholder RPC credentials generated.\\n" "${INFO}"
            create_dummy_rpc_credentials="done"
        fi
    fi

    # Check if DigiAsset settings file exists
    if [ -f $DGA_SETTINGS_FILE ]; then
        printf "%b Existing DigiAsset settings found.\\n" "${INFO}"
    fi

    # Check if DigiAsset settings backup file exists
    if [ -f $DGA_SETTINGS_BACKUP_FILE ]; then
        printf "%b Existing DigiAsset backup settings found.\\n" "${INFO}"
    fi

    # If live main.json file already exists, and we are not doing a reset, let's check if the rpc user and password need updating
    if [ -f $DGA_SETTINGS_FILE ] && [ "$DGA_SETTINGS_CREATE_TYPE" != "reset" ]; then

        str="Checking if RPC credentials have changed..."
        printf "%b %s" "${INFO}" "${str}"

        local rpcuser_json_cur
        local rpcpassword_json_cur
        local rpcport_json_cur

        # Let's get the current rpcuser and rpcpassword from the main.json file

        rpcuser_json_cur=$(cat $DGA_SETTINGS_FILE | jq '.wallet.user' | tr -d '"')
        rpcpassword_json_cur=$(cat $DGA_SETTINGS_FILE | jq '.wallet.pass' | tr -d '"')
        rpcport_json_cur=$(cat $DGA_SETTINGS_FILE | jq '.wallet.port' | tr -d '"')

        # Compare them with the digibyte.conf values to see if they need updating

        if [ "$rpcuser" != "$rpcuser_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update"
            rpc_change_user=true
        fi
        if [ "$rpcpassword" != "$rpcpassword_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update"
            rpc_change_password=true
        fi
        if [ "$rpcport" != "$rpcport_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update"
            rpc_change_port=true
        fi
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ]; then
            printf "%b%b %s Yes! DigiAsset settings need updating.\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" != "update" ]; then
            printf "%b%b %s No!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # If backup main.json file already exists, and we are not doing a reset, let's check if the rpc user and password need updating
    if [ -f $DGA_SETTINGS_BACKUP_FILE ] && [ "$DGA_SETTINGS_CREATE_TYPE" != "reset" ]; then

        str="Checking if RPC credentials have changed..."
        printf "%b %s" "${INFO}" "${str}"

        local rpcuser_json_cur
        local rpcpassword_json_cur
        local rpcport_json_cur

        # Let's get the current rpcuser and rpcpassword from the main.json file

        rpcuser_json_cur=$(cat $DGA_SETTINGS_BACKUP_FILE | jq '.wallet.user' | tr -d '"')
        rpcpassword_json_cur=$(cat $DGA_SETTINGS_BACKUP_FILE | jq '.wallet.pass' | tr -d '"')
        rpcport_json_cur=$(cat $DGA_SETTINGS_BACKUP_FILE | jq '.wallet.port' | tr -d '"')

        # Compare them with the digibyte.conf values to see if they need updating

        if [ "$rpcuser" != "$rpcuser_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update_restore"
            rpc_change_user=true
        fi
        if [ "$rpcpassword" != "$rpcpassword_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update_restore"
            rpc_change_password=true
        fi
        if [ "$rpcport" != "$rpcport_json_cur" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update_restore"
            rpc_change_port=true
        fi
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update_restore" ]; then
            printf "%b%b %s Yes! DigiAsset backup settings need updating.\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" != "update_restore" ]; then
            printf "%b%b %s No!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # If live main.json file already exists, and we are not doing a reset, let's check if the Kubo IPFS URL needs adding
    if [ -f $DGA_SETTINGS_FILE ] && [ "$DGA_SETTINGS_CREATE_TYPE" != "reset" ]; then

        str="Checking if Kubo IPFS API URL needs updating..."
        printf "%b %s" "${INFO}" "${str}"

        local ipfsurl_json_cur

        # Let's get the current IPFS URL from the main.json file

        ipfsurl_json_cur=$(cat $DGA_SETTINGS_FILE | jq '.ipfs' | tr -d '"')

        # Compare them with the digibyte.conf values to see if they need updating

        if [ "$ipfsurl_json_cur" != "$IPFS_KUBO_API_URL" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update"
            ipfs_api_url_change=true
        fi
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ]; then
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" != "update" ]; then
            printf "%b%b %s No!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # If backup main.json file already exists, and we are not doing a reset, let's check if the Kubo IPFS URL needs adding
    if [ -f $DGA_SETTINGS_BACKUP_FILE ] && [ "$DGA_SETTINGS_CREATE_TYPE" != "reset" ]; then

        str="Checking if Kubo IPFS API URL needs updating..."
        printf "%b %s" "${INFO}" "${str}"

        local ipfsurl_json_cur

        # Let's get the current IPFS URL from the main.json file

        ipfsurl_json_cur=$(cat $DGA_SETTINGS_BACKUP_FILE | jq '.ipfs' | tr -d '"')

        # Compare them with the digibyte.conf values to see if they need updating

        if [ "$ipfsurl_json_cur" != "$IPFS_KUBO_API_URL" ]; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="update_restore"
            ipfs_api_url_change=true
        fi
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update_restore" ]; then
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" != "update_restore" ]; then
            printf "%b%b %s No!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi


    if [ "$DGA_SETTINGS_CREATE" = "YES" ]; then

        printf "\\n"

         # Display section break
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "new" ]; then
            # ==============================================================================
            printf " =============== Creating: DigiAsset Node settings =====================\\n\\n"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ]; then
            # ==============================================================================
            printf " =============== Updating: DigiAsset Node settings =====================\\n\\n"
            printf "%b RPC credentials in digibyte.conf have changed. The main.json file will be updated.\\n" "${INFO}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "restore" ]; then
            # ==============================================================================
            printf " =============== Restoring: DigiAsset Node settings ====================\\n\\n"
            printf "%b Your DigiAsset Node backup settings will be restored.\\n" "${INFO}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "update_restore" ]; then
            # ==============================================================================
            printf " =============== Updating & Restoring: DigiAsset Node settings =========\\n\\n"
            printf "%b RPC credentials in digibyte.conf have changed. DigiAsset backup settings will be updated and restored.\\n" "${INFO}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "reset" ]; then
            # ==============================================================================
            printf " =============== Resetting: DigiAsset Node settings ====================\\n\\n"
            printf "%b Reset Mode: You chose to re-configure your DigiAsset Node settings.\\n" "${INFO}"
        fi

        if [ "$create_dummy_rpc_credentials" = "yes" ]; then  
            printf "%b digibyte.conf does not exist. Placeholder RPC credentials generated.\\n" "${INFO}"
        fi


        # If we are in reset mode, delete the entire DigiAssets settings folder if it already exists
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "reset" ] && [ -d "$DGA_SETTINGS_LOCATION" ]; then
            str="Deleting existing DigiAssets settings..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f -r $DGA_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If the live main.json file already exists, update the rpc user and password if they have changed
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ] && [ -f "$DGA_SETTINGS_FILE" ]; then

            if [ "$rpc_change_user" = true ]; then
                str="Updating RPC user in main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_rpcuser="$(jq ".wallet.user = \"$rpcuser\"" $DGA_SETTINGS_FILE)" && \
                echo -E "${update_rpcuser}" > $DGA_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            if [ "$rpc_change_password" = true ]; then
                str="Updating RPC password in main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_rpcpassword="$(jq ".wallet.pass = \"$rpcpassword\"" $DGA_SETTINGS_FILE)" && \
                echo -E "${update_rpcpassword}" > $DGA_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            if [ "$rpc_change_port" = true ]; then
                str="Updating RPC port in main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_rpcport="$(jq ".wallet.port = $rpcport" $DGA_SETTINGS_FILE)" && \
                echo -E "${update_rpcport}" > $DGA_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            if [ "$ipfs_api_url_change" = true ]; then
                str="Updating IPFS URL in main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_ipfsurl="$(jq ".ipfs = \"$IPFS_KUBO_API_URL\"" $DGA_SETTINGS_FILE)" && \
                echo -E "${update_ipfsurl}" > $DGA_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

        fi

        # If the backup main.json file already exists, update the rpc user and password if they have changed
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update_restore" ] && [ -f "$DGA_SETTINGS_BACKUP_FILE" ]; then

            if [ "$rpc_change_user" = true ]; then
                str="Updating RPC user in backup main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_rpcuser="$(jq ".wallet.user = \"$rpcuser\"" $DGA_SETTINGS_BACKUP_FILE)" && \
                echo -E "${update_rpcuser}" > $DGA_SETTINGS_BACKUP_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            if [ "$rpc_change_password" = true ]; then
                str="Updating RPC password in backup main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_rpcpassword="$(jq ".wallet.pass = \"$rpcpassword\"" $DGA_SETTINGS_BACKUP_FILE)" && \
                echo -E "${update_rpcpassword}" > $DGA_SETTINGS_BACKUP_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            if [ "$rpc_change_port" = true ]; then
                str="Updating RPC port in backup main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_rpcport="$(jq ".wallet.port = $rpcport" $DGA_SETTINGS_BACKUP_FILE)" && \
                echo -E "${update_rpcport}" > $DGA_SETTINGS_BACKUP_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            if [ "$ipfs_api_url_change" = true ]; then
                str="Updating IPFS URL in backup main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_ipfsurl="$(jq ".ipfs = \"$IPFS_KUBO_API_URL\"" $DGA_SETTINGS_BACKUP_FILE)" && \
                echo -E "${update_ipfsurl}" > $DGA_SETTINGS_BACKUP_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

        fi

        # Restart PM2 if the live main.json credentials have been updated
        if [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ]; then
            printf "%b Restarting PM2 digiasset service, as the credentials have been updated...\\n" "${INFO}"
            sudo -u $USER_ACCOUNT pm2 restart digiasset
        fi

        # If the main.json settings file does not exist anywhere, create the backup settings folder
        if [ ! -f "$DGA_SETTINGS_BACKUP_FILE" ] && [ ! -f "$DGA_SETTINGS_FILE" ]; then

            # create ~/dga_config_backup/ folder if it does not already exist
            if [ ! -d $DGA_SETTINGS_BACKUP_LOCATION ]; then #
                str="Creating ~/dga_config_backup/ settings folder..."
                printf "%b %s" "${INFO}" "${str}"
                sudo -u $USER_ACCOUNT mkdir $DGA_SETTINGS_BACKUP_LOCATION
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Create a new main.json settings backup file
            if [ ! -f $DGA_SETTINGS_BACKUP_FILE ]; then
                str="Creating ~/dga_config_backup/main.json settings file..."
                printf "%b %s" "${INFO}" "${str}"
                sudo -u $USER_ACCOUNT touch $DGA_SETTINGS_BACKUP_FILE
                cat <<EOF > $DGA_SETTINGS_BACKUP_FILE
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
    },
    "ipfs":           "http://127.0.0.1:5001/api/v0/"
}
EOF
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

        fi

    fi

    printf "\\n"
}


# Create pm2 service so that DigiAsset Node will run at boot
digiasset_node_create_pm2_service() {

# If you want to make changes to how PM2 services are created/managed, refer to this website:
# https://www.tecmint.com/enable-pm2-to-auto-start-node-js-app/

# If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
if [ "$RESET_MODE" = true ]; then

    # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
    if [ -f "$PM2_UPSTART_SERVICE_FILE" ] || [ -f "$PM2_SYSTEMD_SERVICE_FILE" ]; then

        if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-configure the DigiAsset Node PM2 service?\\n\\nThe PM2 service ensures that your DigiAsset Node starts automatically at boot, and stays running 24/7. This will delete your existing PM2 service file and recreate it." "${r}" "${c}"; then
            PM2_SERVICE_DO_INSTALL=YES
            PM2_SERVICE_INSTALL_TYPE="reset"
        else
            printf " =============== Resetting: NodeJS PM2 Service =========================\\n\\n"
            # ==============================================================================
            printf "%b Reset Mode: You skipped re-configuring the DigiAsset Node PM2 service.\\n" "${INFO}"
            PM2_SERVICE_DO_INSTALL=NO
            PM2_SERVICE_INSTALL_TYPE="none"
            return
        fi
    fi
fi

# If the SYSTEMD service files do not yet exist, then assume this is a new install
if [ ! -f "$PM2_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
            PM2_SERVICE_DO_INSTALL="if_doing_full_install"
            PM2_SERVICE_INSTALL_TYPE="new"
fi

# If the UPSTART service files do not yet exist, then assume this is a new install
if [ ! -f "$PM2_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
            PM2_SERVICE_DO_INSTALL="if_doing_full_install"
            PM2_SERVICE_INSTALL_TYPE="new"
fi

# If this is a new install of NodeJS PM2 service file, and the user has opted to do a full DigiNode install, then proceed
if  [ "$PM2_SERVICE_INSTALL_TYPE" = "new" ] && [ "$PM2_SERVICE_DO_INSTALL" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    PM2_SERVICE_DO_INSTALL=YES
fi


if [ "$PM2_SERVICE_DO_INSTALL" = "YES" ]; then

    # Display section break
    printf "\\n"
    if [ "$PM2_SERVICE_INSTALL_TYPE" = "new" ]; then
        printf " =============== Install: NodeJS PM2 Service ===========================\\n\\n"
        # ==============================================================================
    elif [ "$PM2_SERVICE_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: NodeJS PM2 Service =============================\\n\\n"
        printf "%b Reset Mode: You chose re-configure the DigiAsset Node PM2 service.\\n" "${INFO}"
        # ==============================================================================
    fi

    # If SYSTEMD service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
    if [ -f "$PM2_SYSTEMD_SERVICE_FILE" ] && [ "$PM2_SERVICE_INSTALL_TYPE" = "reset" ]; then

        # Stop the service now
        systemctl stop "pm2-$USER_ACCOUNT"

        # Disable the service now
        systemctl disable "pm2-$USER_ACCOUNT"

        str="Deleting PM2 systemd service file: $PM2_SYSTEMD_SERVICE_FILE ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $PM2_SYSTEMD_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If UPSTART service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
    if [ -f "$PM2_UPSTART_SERVICE_FILE" ] && [ "$PM2_SERVICE_INSTALL_TYPE" = "reset" ]; then

        # Stop the service now
        service "pm2-$USER_ACCOUNT" stop

        # Disable the service now
        service "pm2-$USER_ACCOUNT" disable

        str="Deleting PM2 upstart service file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $PM2_UPSTART_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If this system uses SYSTEMD and the service file does not yet exist, then set it it up
    if [ ! -f "$PM2_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then

        # Generate the PM2 service file
        env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER_ACCOUNT --hp $USER_HOME

        systemctl enable "pm2-$USER_ACCOUNT"

        # Restart the PM2 service
        # restart_service "pm2-$USER_ACCOUNT"

    fi

    # If this system uses UPSTART and the service file does not yet exist, then set it it up
    if [ ! -f "$PM2_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then

        # Generate the PM2 service file
        pm2 startup

        pm2 startup | grep sudo

        # Restart the PM2 service
        restart_service "pm2-$USER_ACCOUNT"
    fi

    # If using sysv-init or another unknown system, we don't yet support creating a PM2 service file
    if [ "$INIT_SYSTEM" = "sysv-init" ] || [ "$INIT_SYSTEM" = "unknown" ]; then
        printf "%b Unable to create a PM2 service for your system - systemd/upstart not found.\\n" "${CROSS}"
        printf "%b Please contact @digibytehelp on Twitter for help.\\n" "${CROSS}"
        exit 1
    fi

    printf "\\n"

fi



}


# This function will ask the user if they want to install the system upgrades that have been found
menu_ask_install_updates() {

# If there is an upgrade available for DigiByte Core, IPFS, NodeJS, DigiAsset Node or DigiNode Tools, ask the user if they wan to install them
if [[ "$DGB_ASK_UPGRADE" = "YES" ]] || [[ "$DGA_ASK_UPGRADE" = "YES" ]] || [[ "$IPFS_ASK_UPGRADE" = "YES" ]] || [[ "$NODEJS_ASK_UPGRADE" = "YES" ]] || [[ "$DGNT_ASK_UPGRADE" = "YES" ]]; then

    # Don't ask if we are running unattended
    if [ ! "$UNATTENDED_MODE" == true ]; then

        printf " =============== UPDATE MENU ===========================================\\n\\n"
        # ==============================================================================

        if [ "$DGB_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dgb=" >> DigiByte Core v$DGB_VER_RELEASE\\n"
        fi
        if [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_ipfs=" >> Kubo v$IPFS_VER_RELEASE\\n"
        fi
        if [ "$NODEJS_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_nodejs=" >> NodeJS v$NODEJS_VER_RELEASE\\n"
        fi
        if [ "$DGA_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dga=" >> DigiAsset Node v$DGA_VER_RELEASE\\n"
        fi
        if [ "$DGNT_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dgnt=" >> DigiNode Tools v$DGNT_VER_RELEASE\\n"
        fi


        if whiptail --backtitle "" --title "DigiNode software updates are available" --yesno "The following updates are available for your DigiNode:\\n\\n$upgrade_msg_dgb$upgrade_msg_ipfs$upgrade_msg_nodejs$upgrade_msg_dga$upgrade_msg_dgnt\\nWould you like to install them now?" --yes-button "Yes (Recommended)" "${r}" "${c}"; then
            printf "%b You chose to install the available updates:\\n$upgrade_msg_dgb$upgrade_msg_ipfs$upgrade_msg_nodejs$upgrade_msg_dga$upgrade_msg_dgnt" "${INFO}"
        #Nothing to do, continue
          if [ "$DGB_ASK_UPGRADE" = "YES" ]; then
            DGB_DO_INSTALL=YES
          fi
          if [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
            IPFS_DO_INSTALL=YES
          fi
          if [ "$NODEJS_ASK_UPGRADE" = "YES" ]; then
            NODEJS_DO_INSTALL=YES
          fi
          if [ "$DGA_ASK_UPGRADE" = "YES" ]; then
            DGA_DO_INSTALL=YES
          fi
          if [ "$DGNT_ASK_UPGRADE" = "YES" ]; then
            DGNT_DO_INSTALL=YES
          fi
        else
          printf "%b You chose NOT to install the available updates:\\n$upgrade_msg_dgb$upgrade_msg_ipfs$upgrade_msg_nodejs$upgrade_msg_dga$upgrade_msg_dgnt" "${INFO}"
          printf "\\n"
          display_system_updates_reminder
          exit
        fi

    printf "\\n"

    fi

fi

}

# This function will ask the user if they want to install DigiAssets Node
menu_ask_install_digiasset_node() {

# Provided we are not in unnatteneded mode, and it is not already installed, ask the user if they want to install a DigiAssets Node
if [ ! -f $DGA_INSTALL_LOCATION/.officialdiginode ] && [ "$UNATTENDED_MODE" == false ]; then

        if whiptail --backtitle "" --title "Install DigiAsset Node?" --yesno "Would you like to install a DigiAsset Node?\\n\\nYou do not currently have a DigiAsset Node installed. Running a DigiAsset Node along side your DigiByte Full Node helps to support the network by decentralizing DigiAsset metadata.\\n\\nYou can earn \$DGB for hosting other people's metadata, and it also gives you the ability to create your own DigiAssets from the web interface." --yes-button "Yes (Recommended)" "${r}" "${c}"; then
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


# Perform uninstall if requested
uninstall_do_now() {

    printf " =============== Uninstall DigiNode ====================================\\n\\n"
    # ==============================================================================

    printf "%b DigiNode will now be uninstalled from your system.\\n" "${INFO}"
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

            local delete_dga=yes

        else
            local delete_dga=no
            printf "%b You chose not to uninstall DigiAsset Node v${DGA_VER_LOCAL}.\\n" "${INFO}"
        fi
    fi

    # Ask to delete DigiAsset Node config folder if it exists
    if [ -d "$DGA_SETTINGS_LOCATION" ] && [ "$delete_dga" = "yes" ]; then

        # Do you want to delete digibyte.conf?
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete your DigiAsset Node settings folder: ~/digiasset_node/_config ?\\n\\n(If you choose No, the _config folder will backed up to your home folder, and automatically restored to its original location, when you reinstall the DigiAsset Node software.)" "${r}" "${c}"; then
            local delete_dga_config=yes
        else
            local delete_dga_config=no
            printf "%b You chose not to delete your DigiAsset settings folder.\\n" "${INFO}"
        fi
    fi

    # Stop PM2 service, if we are deleting DigiAsset Node
    if [ "$delete_dga" = "yes" ]; then

        # Stop digiasset PM2 service
        printf "Deleting DigiAsset Node PM2 service...\\n"
        sudo -u $USER_ACCOUNT pm2 delete digiasset
        printf "\\n"

    fi

    # Backup DigiAsset _config folder to the home folder, if we are uninstalling DigiAssets Node, but keeping the configuration
    if [ "$delete_dga_config" = "no" ] && [ "$delete_dga" = "yes" ]; then

        # create ~/dga_config_backup/ folder if it does not already exist
        if [ ! -d $DGA_SETTINGS_BACKUP_LOCATION ]; then #
            str="Creating ~/dga_config_backup/ backup folder..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT mkdir $DGA_SETTINGS_BACKUP_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    
        # Delete asset_settings folder
        str="Backing up the DigiAssets settings from ~/digiasset_node/_config to ~/dga_config_backup"
        printf "%b %s" "${INFO}" "${str}"
        mv $DGA_SETTINGS_LOCATION/*.json $DGA_SETTINGS_BACKUP_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete DigiAsset _config folder, if we are keeping the DigiAssets Node, but deleting the configuration
    if [ "$delete_dga_config" = "yes" ] && [ "$delete_dga" = "yes" ]; then

            # Delete asset_settings folder
            str="Deleting DigiAssets settings folder: ~/digiasset_node/_config.."
            printf "%b %s" "${INFO}" "${str}"
            rm -f -r $DGA_SETTINGS_LOCATION
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete DigiAsset Node
    if [ "$delete_dga" = "yes" ]; then

        # Delete existing 'digiasset_node' folder (if it exists)
        str="Deleting ~/digiasset_node folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r -f $USER_HOME/digiasset_node
        DGA_LOCAL_BRANCH=""
        sed -i -e "/^DGA_LOCAL_BRANCH=/s|.*|DGA_LOCAL_BRANCH=|" $DGNT_SETTINGS_FILE
        DGA_VER_LOCAL=""
        sed -i -e "/^DGA_VER_LOCAL=/s|.*|DGA_VER_LOCAL=|" $DGNT_SETTINGS_FILE
        DGA_VER_MJR_LOCAL=""
        sed -i -e "/^DGA_VER_MJR_LOCAL=/s|.*|DGA_VER_MJR_LOCAL=|" $DGNT_SETTINGS_FILE
        DGA_VER_MNR_LOCAL=""
        sed -i -e "/^DGA_VER_MNR_LOCAL=/s|.*|DGA_VER_MNR_LOCAL=|" $DGNT_SETTINGS_FILE
        DGA_INSTALL_DATE=""
        sed -i -e "/^DGA_INSTALL_DATE=/s|.*|DGA_INSTALL_DATE=|" $DGNT_SETTINGS_FILE
        DGA_UPGRADE_DATE=""
        sed -i -e "/^DGA_UPGRADE_DATE=/s|.*|DGA_UPGRADE_DATE=|" $DGNT_SETTINGS_FILE
        DGA_FIRST_RUN=""
        sed -i -e "/^DGA_FIRST_RUN=/s|.*|DGA_FIRST_RUN=|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete JS-IPFS settings
    if [ -d "$USER_HOME/.jsipfs" ]; then
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete your JS-IPFS settings folder?\\n\\nThis will delete the folder: ~/.jsipfs\\n\\nThis folder contains all the settings and metadata related to the IPFS implementation built into the DigiAsset Node software." "${r}" "${c}"; then
            str="Deleting ~/.jsipfs settings folder..."
            printf "%b %s" "${INFO}" "${str}"
            rm -r $USER_HOME/.jsipfs
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b You chose not to delete the JS-IPFS settings folder (~/.jsipfs).\\n" "${INFO}"
        fi
    fi

    # Ask to delete PM2 service, if it exists
    if [ -f "$PM2_UPSTART_SERVICE_FILE" ] || [ -f "$PM2_SYSTEMD_SERVICE_FILE" ]; then

        # Do you want to delete pm2 service?
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to delete your PM2 service file?\\n\\nNote: This ensures that the DigiAsset Node starts at launch, and relaunches if it crashes for some reason. You can safely delete this if you do not use PM2 for anything else." "${r}" "${c}"; then

                # If SYSTEMD service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
            if [ -f "$PM2_SYSTEMD_SERVICE_FILE" ]; then

                # Stop the service now
                systemctl stop "pm2-$USER_ACCOUNT"

                # Disable the service now
                systemctl disable "pm2-$USER_ACCOUNT"

                str="Deleting PM2 systemd service file: $PM2_SYSTEMD_SERVICE_FILE ..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $PM2_SYSTEMD_SERVICE_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # If UPSTART service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
            if [ -f "$PM2_UPSTART_SERVICE_FILE" ]; then

                # Stop the service now
                service "pm2-$USER_ACCOUNT" stop

                # Disable the service now
                service "pm2-$USER_ACCOUNT" disable

                str="Deleting PM2 upstart service file: $PM2_UPSTART_SERVICE_FILE ..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $PM2_UPSTART_SERVICE_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

        else
            printf "%b You chose not to delete your PM2 service file.\\n" "${INFO}"
        fi
    fi


    # Insert a line break if either of these were present
    if [ "$uninstall_dga" = "yes" ]; then
        printf "\\n"
    fi


    ################## UNINSTALL IPFS #################################################

    # Get the local version number of Kubo (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
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

    printf " =============== Uninstall: Kubo (Go-IPFS) =============================\\n\\n"
    # ==============================================================================

        # Delete IPFS
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to uninstall Kubo v${IPFS_VER_LOCAL}?\\n\\nThis will uninstall the IPFS software." "${r}" "${c}"; then

            printf "%b You chose to uninstall Kubo v${IPFS_VER_LOCAL}.\\n" "${INFO}"


            # Stop IPFS service if it is running, as we need to upgrade or reset it
            if [ "$IPFS_STATUS" = "running" ]; then
               printf "%b Preparing Uninstall: Stopping and disabling IPFS service ...\\n" "${INFO}"
               stop_service ipfs
               disable_service ipfs
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
                IPFSU_VER_LOCAL=""
                sed -i -e "/^IPFSU_VER_LOCAL=/s|.*|IPFSU_VER_LOCAL=|" $DGNT_SETTINGS_FILE
                IPFSU_INSTALL_DATE=""
                sed -i -e "/^IPFSU_INSTALL_DATE=/s|.*|IPFSU_INSTALL_DATE=|" $DGNT_SETTINGS_FILE
                IPFSU_UPGRADE_DATE=""
                sed -i -e "/^IPFSU_UPGRADE_DATE=/s|.*|IPFSU_UPGRADE_DATE=|" $DGNT_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete Kubo binary
            if [ -f /usr/local/bin/ipfs ]; then
                str="Deleting current Kubo binary: /usr/local/bin/ipfs..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f /usr/local/bin/ipfs
                IPFS_STATUS="not_detected"
                IPFS_VER_LOCAL=""
                delete_kubo="yes"
                sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
                IPFS_INSTALL_DATE=""
                sed -i -e "/^IPFS_INSTALL_DATE=/s|.*|IPFS_INSTALL_DATE=|" $DGNT_SETTINGS_FILE
                IPFS_UPGRADE_DATE=""
                sed -i -e "/^IPFS_UPGRADE_DATE=/s|.*|IPFS_UPGRADE_DATE=|" $DGNT_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Set IPFS URL in main.json to true (this will ensure that it uses js-IPFS is used now that Kubo is uninstalled)
            if [ -f $DGA_SETTINGS_FILE ]; then
                str="Setting IPFS to 'true' in main.json..."
                printf "%b %s" "${INFO}" "${str}"
                update_ipfsurl="$(jq ".ipfs = true" $DGA_SETTINGS_FILE)" && \
                echo -E "${update_ipfsurl}" > $DGA_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete IPFS settings
            if [ -d "$USER_HOME/.ipfs" ]; then
                if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete your Kubo IPFS settings folder?\\n\\nThis will delete the folder: ~/.ipfs\\n\\nThis folder contains all the settings and metadata related to your Kubo IPFS node." "${r}" "${c}"; then
                    str="Deleting ~/.ipfs settings folder..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -r $USER_HOME/.ipfs
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                else
                    printf "%b You chose not to delete the Kubo IPFS settings folder (~/.ipfs).\\n" "${INFO}"
                fi
            fi

            # Restart the DigiAsset Node, if we uninstalled Kobu. This is to force it to switch over to using JS-IPFS
            if [ "$delete_kubo" = "yes" ] && [ "$delete_dga" = "no" ]; then
                str="Restarting DigiAsset Node so it switches from using Kubo to JS-IPFS..."
                printf "%b %s" "${INFO}" "${str}"
                sudo -u $USER_ACCOUNT pm2 restart digiasset
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi


        else
            printf "%b You chose not to uninstall IPFS.\\n" "${INFO}"
            delete_kubo="no"
        fi

        printf "\\n"
    fi

    ################## UNINSTALL DIGIBYTE NODE #################################################

    # Only prompt to unistall DigiByte Node if it is an official install
    if [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then

        printf " =============== Uninstall: DigiByte Node ==============================\\n\\n"
        # ==============================================================================


        # Uninstall DigiByte Core
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to uninstall DigiByte Core v${DGB_VER_LOCAL}?\\n\\nThis step uninstalls the DigiByte Core software only - your wallet, settings and blockchain data will not be affected." "${r}" "${c}"; then

            printf "%b You chose to uninstall DigiByte Core.\\n" "${INFO}"

            printf "%b Stopping DigiByte Core daemon...\\n" "${INFO}"
            stop_service digibyted
            disable_service digibyted
            DGB_STATUS="stopped"

            # Delete systemd service file
            if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ]; then
                str="Deleting DigiByte daemon systemd service file: $DGB_SYSTEMD_SERVICE_FILE ..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $DGB_SYSTEMD_SERVICE_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete upstart service file
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
                DGB_VER_LOCAL=""
                sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=|" $DGNT_SETTINGS_FILE
                DGB_INSTALL_DATE=""
                sed -i -e "/^DGB_INSTALL_DATE=/s|.*|DGB_INSTALL_DATE=|" $DGNT_SETTINGS_FILE
                DGB_UPGRADE_DATE=""
                sed -i -e "/^DGB_UPGRADE_DATE=/s|.*|DGB_UPGRADE_DATE=|" $DGNT_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete ~/digibyte symbolic link
            if [ -h "$USER_HOME/digibyte" ]; then
                str="Deleting digibyte symbolic link in home folder..."
                printf "%b %s" "${INFO}" "${str}"
                rm $USER_HOME/digibyte
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete .bashrc path to DigiByte binary folder
            if grep -q "$USER_HOME/digibyte/bin" "$USER_HOME/.bashrc"; then
                str="Deleting path to DigiByte binary folder in .bashrc file..."
                printf "%b %s" "${INFO}" "${str}"
                # Delete existing path for DigiByte binaries
                sed -i "/# Add DigiByte binary folder to path/d" $USER_HOME/.bashrc
                sed -i "/export PATH+=:\/home\/$USER_ACCOUNT\/digibyte\/bin/d" $USER_HOME/.bashrc
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Ask to delete digibyte.conf if it exists
            if [ -f "$DGB_CONF_FILE" ]; then

                # Do you want to delete digibyte.conf?
                if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete your digibyte.conf settings file?\\n\\nThis will remove any customisations you made to your DigiByte install." "${r}" "${c}"; then

                    # Delete digibyte.conf
                    str="Deleting digibyte.conf file..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -f $DGB_CONF_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                else
                    printf "%b You chose not to delete your digibyte.conf settings file.\\n" "${INFO}"
                fi
            fi

            # Only prompt to delete the blockchain data if it already exists
            if [ -d "$DGB_DATA_LOCATION/indexes" ] || [ -d "$DGB_DATA_LOCATION/chainstate" ] || [ -d "$DGB_DATA_LOCATION/blocks" ]; then

                # Delete DigiByte blockchain data
                if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete the DigiByte MAINNET blockchain data?\\n\\nIf you delete it, and later re-install DigiByte Core, it will need to re-download the entire blockchain which can take several days.\\n\\nNote: Your mainnet wallet will be kept." "${r}" "${c}"; then

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
                    printf "%b You chose not to keep the existing DigiByte MAINNET blockchain data.\\n" "${INFO}"
                    printf "\\n"
                fi

            fi

            # Only prompt to delete the testnet blockchain data if it already exists
            if [ -d "$DGB_DATA_LOCATION/testnet4/indexes" ] || [ -d "$DGB_DATA_LOCATION/testnet4/chainstate" ] || [ -d "$DGB_DATA_LOCATION/testnet4/blocks" ]; then

                # Delete DigiByte blockchain data
                if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete the DigiByte TESTNET blockchain data?\\n\\nIf you delete it, and later re-install DigiByte Core, it will need to re-download the entire blockchain which can take several days.\\n\\nNote: Your testnet wallet will be kept." "${r}" "${c}"; then

                    # Delete systemd service file
                    if [ -d "$DGB_DATA_LOCATION/testnet4" ]; then
                        str="Deleting DigiByte Core TESTNET blockchain data..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf $DGB_DATA_LOCATION/testnet4/indexes
                        rm -rf $DGB_DATA_LOCATION/testnet4/chainstate
                        rm -rf $DGB_DATA_LOCATION/testnet4/blocks
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi
                    printf "\\n"

                else
                    printf "%b You chose to keep the existing DigiByte TESTNET blockchain data.\\n" "${INFO}"
                    printf "\\n"
                fi

            fi

        else
            printf "%b You chose not to uninstall DigiByte Core.\\n" "${INFO}"
            printf "\\n"
        fi

    fi




    ################## UNINSTALL DIGINODE TOOLS #################################################

    uninstall_diginode_tools_now

    printf " =======================================================================\\n"
    printf " ================== ${txtgrn}DigiNode Uninstall Completed!${txtrst} ======================\\n"
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


# Uninstall DigiNode Tools Only
uninstall_diginode_tools_now() {

    # Show DigiNode Tools uninstall title if it exists
    if [ -d "$DGNT_LOCATION" ] || [ -f "$DGNT_SETTINGS_FILE" ]; then

        printf " =============== Uninstall: DigiNode Tools =============================\\n\\n"
        # ==============================================================================

    fi

    # Ask to uninstall DigiNode Tools if the install folder exists
    if [ -d "$DGNT_LOCATION" ]; then

        # Delete DigiNode Tools
        if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to uninstall DigiNode Tools?\\n\\nThis will delete the 'DigiNode Status Monitor' and 'DigiNode Setup' scripts." "${r}" "${c}"; then

            printf "%b You chose to uninstall DigiNode Tools.\\n" "${INFO}"

            # Delete ~/diginode folder and its contents
            if [ -d "$DGNT_LOCATION" ]; then
                str="Deleting DigiNode Tools..."
                printf "%b %s" "${INFO}" "${str}"
                rm -rf $DGNT_LOCATION
                DGNT_BRANCH_LOCAL=""
                sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=|" $DGNT_SETTINGS_FILE
                DGNT_VER_LOCAL_=""
                sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
                DGNT_VER_LOCAL_DISPLAY=""
                sed -i -e "/^DGNT_VER_LOCAL_DISPLAY=/s|.*|DGNT_VER_LOCAL_DISPLAY=|" $DGNT_SETTINGS_FILE
                DGNT_INSTALL_DATE=""
                sed -i -e "/^DGNT_INSTALL_DATE=/s|.*|DGNT_INSTALL_DATE=|" $DGNT_SETTINGS_FILE
                DGNT_UPGRADE_DATE=""
                sed -i -e "/^DGNT_UPGRADE_DATE=/s|.*|DGNT_UPGRADE_DATE=|" $DGNT_SETTINGS_FILE
                DGNT_MONITOR_FIRST_RUN=""
                sed -i -e "/^DGNT_MONITOR_FIRST_RUN=/s|.*|DGNT_MONITOR_FIRST_RUN=|" $DGNT_SETTINGS_FILE
                DGNT_MONITOR_LAST_RUN=""
                sed -i -e "/^DGNT_MONITOR_LAST_RUN=/s|.*|DGNT_MONITOR_LAST_RUN=|" $DGNT_SETTINGS_FILE
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete 'diginode-setup' alias
            if grep -q "alias diginode-setup=" "$USER_HOME/.bashrc"; then
                str="Deleting 'diginode-setup' alias in .bashrc file..."
                printf "%b %s" "${INFO}" "${str}"
                # Delete existing alias for 'diginode'
                sed -i "/# Alias for DigiNode tools so that entering 'diginode-setup' will run this from any folder/d" $USER_HOME/.bashrc
                sed -i '/alias diginode-setup=/d' $USER_HOME/.bashrc
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


            # Ask to delete diginode.settings if it exists
            if [ -f "$DGNT_SETTINGS_FILE" ]; then

                # Delete diginode.settings
                if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete your diginode.settings file?\\n\\nThis wil remove any customisations you have made to your DigiNode Install." "${r}" "${c}"; then

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

        else
            printf "%b You chose not to uninstall DigiNode Tools.\\n" "${INFO}"
        fi
    fi

    printf "\\n"

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

if [ "$VERBOSE_MODE" = true ]; then
    printf "%b Text Editor: $TEXTEDITOR\\n" "${INFO}"
fi

}

# Select a random DigiFact to display
digifact_randomize() {

array[0]="digifact1"
array[1]="digifact2"
array[2]="digifact3"
array[3]="digifact4"
array[4]="digifact5"
array[5]="digifact6"
array[6]="digifact7"
array[7]="digifact8"
array[8]="digifact9"
array[9]="digifact10"
array[10]="digifact11"
array[11]="digifact12"
array[12]="digifact13"
array[13]="digifact14"
array[14]="digifact15"
array[15]="digifact16"
array[16]="digifact17"
array[17]="digifact18"
array[18]="digifact19"
array[19]="digifact20"
array[20]="digifact21"
array[21]="digifact22"
array[22]="digifact23"
array[23]="digifact24"
array[24]="digifact25"
array[25]="digifact26"
array[26]="digifact27"
array[27]="digifact28"
array[28]="digifact29"
array[29]="digifact30"
array[30]="digifact31"  
array[31]="digifact32"
array[32]="digifact33"
array[33]="digifact34"
array[34]="digifact35"
array[35]="digifact36"
array[36]="digifact37"
array[37]="digifact38"
array[38]="digifact39"
array[39]="digifact40"
array[40]="digifact41"
array[41]="digifact42"
array[42]="digifact43"
array[43]="digifact44"
array[44]="digifact45"
array[45]="digifact46"
array[46]="digifact47"
array[47]="digifact48"
array[48]="digifact49"
array[49]="digifact50"
array[50]="digifact51"
array[51]="digifact52"
array[52]="digifact53"
array[53]="digifact54"   
array[54]="digifact55"
array[55]="digifact56"
array[56]="digifact57"
array[57]="digifact58"
array[58]="digifact59"
array[59]="digifact60"
array[60]="digifact61"
array[61]="digifact62"
array[62]="digifact63"
array[63]="digifact64"
array[64]="digifact65"
array[65]="digifact66"
array[66]="digifact67"
array[67]="digifact68"
array[68]="digifact69"
array[69]="digifact70"
array[70]="digifact71"
array[71]="digifact72"
array[72]="digifact73"
array[73]="digifact74"
array[74]="digifact75"
array[75]="digifact76"
array[76]="digifact77"
array[77]="social1"
array[78]="social2"
array[79]="help1"
array[80]="help2"
array[81]="help3"
array[82]="help4"
array[83]="help5"
array[84]="help6"

size=${#array[@]}
index=$(($RANDOM % $size))

# Store previous one, so we can make sure we don't display the same one twice in a row
DIGIFACT_PREVIOUS=$DIGIFACT

# Get new random DigiFact
DIGIFACT="${array[$index]}"

# If the new DigiFact is the same as the previous one, try again until we get a diferent one
if [ "$DIGIFACT" = "$DIGIFACT_PREVIOUS" ]; then
    DIGIFACT="${array[$index]}"
fi
if [ "$DIGIFACT" = "$DIGIFACT_PREVIOUS" ]; then
    DIGIFACT="${array[$index]}"
fi
if [ "$DIGIFACT" = "$DIGIFACT_PREVIOUS" ]; then
    DIGIFACT="${array[$index]}"
fi

}

# Display the DigiFact
digifact_display() {

#             ╔════════════════════════════════════════════════════════════════════╗

if [ "$DIGIFACT" = "digifact1" ]; then
    DIGIFACT_TITLE="DigiFact # 1 - Did you know..."
    DIGIFACT_L1="DigiByte is the longest UTXO blockchain in existence with over"
    DIGIFACT_L2="15 million blocks. Bitcoin will take until the next century to"
    DIGIFACT_L3="reach that many blocks."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact2" ]; then
    DIGIFACT_TITLE="DigiFact # 2 - Did you know..."
    DIGIFACT_L1="DigiByte has upgraded the network a number of times to include"
    DIGIFACT_L2="\"Improvement milestones\". These forks were not splits that"
    DIGIFACT_L3="generated additional coins, but rather a \"reorientation of the"
    DIGIFACT_L4="ship\" that everyone was onboard with."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact3" ]; then
    DIGIFACT_TITLE="DigiFact # 3 - Did you know..."
    DIGIFACT_L1="DigiByte was fairly launched in 2014, long before the 2017"
    DIGIFACT_L2="Initial Coin Offering (ICO) craze of whitepaper projects."
    DIGIFACT_L3="DigiByte launched with a fully working blockchain that has been"
    DIGIFACT_L4="improved upon consistently ever since."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact4" ]; then
    DIGIFACT_TITLE="DigiFact # 4 - Did you know..."
    DIGIFACT_L1="When DigiByte launched in 2014, a tiny DigiByte pre-mine (0.5%)"
    DIGIFACT_L2="was given away to community members within the first 30 days,"
    DIGIFACT_L3="and the details can be seen on BitcoinTalk. This was to done"
    DIGIFACT_L4="to incentivize people to download and run a full node helping to"
    DIGIFACT_L5="distribute the blockchain. None of the pre-mine was retained"
    DIGIFACT_L6="by the founder or developers."
fi

if [ "$DIGIFACT" = "digifact5" ]; then
    DIGIFACT_TITLE="DigiFact # 5 - Did you know..."
    DIGIFACT_L1="There is no founders reward in DigiByte. Nobody gets part of"
    DIGIFACT_L2="each blocks reward except whoever mined it."
    DIGIFACT_L3=""
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact6" ]; then
    DIGIFACT_TITLE="DigiFact # 6 - Did you know..."
    DIGIFACT_L1="The DigiByte founder and developers all purchased their DigiByte"
    DIGIFACT_L2="on an exchange at market rates, or mined their own DGB, just"
    DIGIFACT_L3="like you do."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact7" ]; then
    DIGIFACT_TITLE="DigiFact # 7 - Did you know..."
    DIGIFACT_L1="Fees for DigiByte are incredibly low. In Block 7658349, a user "
    DIGIFACT_L2="sent 342,000,000 DGB (worth \$6 million USD at the time) from the "
    DIGIFACT_L3="inputs of over 200 different addresses. It cost 1/10th of a "
    DIGIFACT_L4="cent (USD) in fees and took only a few seconds to confirm."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact8" ]; then
    DIGIFACT_TITLE="DigiFact # 8 - Did you know..."
    DIGIFACT_L1="DigiByte pioneered the DigiShield difficulty adjustment. It's"
    DIGIFACT_L2="used in Dogecoin, Ubiq, ZCash, Monacoin and parts of the code"
    DIGIFACT_L3="are even used in Ethereum."
    DIGIFACT_L4=" "
    DIGIFACT_L5="What is DigiShield (a.k.a MultiShield)? Learn more here:"
    DIGIFACT_L6="https://j.mp/3oivy5u"
fi

if [ "$DIGIFACT" = "digifact9" ]; then
    DIGIFACT_TITLE="DigiFact # 9 - Did you know..."
    DIGIFACT_L1="DigiByte was the first non-Bitcoin blockchain to fix the major"
    DIGIFACT_L2="inflation bug in 2018. Rapid response from our rock-star"
    DIGIFACT_L3="developers!"
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact10" ]; then
    DIGIFACT_TITLE="DigiFact # 10 - Did you know..."
    DIGIFACT_L1="The DigiByte \"Genesis Block\" contained the following headline:"
    DIGIFACT_L2="\"USA Today: 10/Jan/2014, Target: Data stolen from up to"
    DIGIFACT_L3="110M customers.\" This forever cemented DigiByte's focus on"
    DIGIFACT_L4="cybersecurity."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact11" ]; then
    DIGIFACT_TITLE="DigiFact # 11 - Did you know..."
    DIGIFACT_L1="DigiByte was the first coin to upgrade from a single mining "
    DIGIFACT_L2="algorithm to MultiAlgo, for the additional security provided by"
    DIGIFACT_L3="having 5x algorithms. This upgrade occurred in late 2014 as"
    DIGIFACT_L4="the \"MultiAlgo\" network upgrade."
    DIGIFACT_L5=" "
    DIGIFACT_L6="What's MultiAlgo? Learn more here: https://j.mp/3oivy5u"
fi

if [ "$DIGIFACT" = "digifact12" ]; then
    DIGIFACT_TITLE="DigiFact # 12 - Did you know..."
    DIGIFACT_L1="Initially DigiByte only used the Scrypt algorithm for mining."
    DIGIFACT_L2="In September 2014, the network upgraded to MultiAlgo,"
    DIGIFACT_L3="utilizing Scrypt, SHA256, Skein, Qubit & Myriad-Groestl."
    DIGIFACT_L4="This massively improved decentralization by enabling a broader"
    DIGIFACT_L5="variety of mining hardware to be used."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact13" ]; then
    DIGIFACT_TITLE="DigiFact # 13 - Did you know..."
    DIGIFACT_L1="In 2019, DigiByte upgraded the network, replacing the"
    DIGIFACT_L2="Myriad-Groestl algorithm for Odocrypt, to specifically target"
    DIGIFACT_L3="FPGA mining making that algorithm ASIC-resistant."
    DIGIFACT_L4=" "
    DIGIFACT_L5="Learn more about Odocrypt here: https://j.mp/3kpZKKB"
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact14" ]; then
    DIGIFACT_TITLE="DigiFact # 14 - Did you know..."
    DIGIFACT_L1="In 2018, the DigiByte community raised enough funds to supply"
    DIGIFACT_L2="Venezuelan refugees crossing the border with over a thousand"
    DIGIFACT_L3="bottles of water, feed 160 orphaned children for a month, provide"
    DIGIFACT_L4="essential maintenance for a hospital, refurbish an Adicora "
    DIGIFACT_L5="school kitchen, and hosting several free community lunches for"
    DIGIFACT_L6="hundreds of people."
fi

if [ "$DIGIFACT" = "digifact15" ]; then
    DIGIFACT_TITLE="DigiFact # 15 - Did you know..."
    DIGIFACT_L1="DigiByte is not an ICO or a token launched on another network,"
    DIGIFACT_L2="but rather a pure blockchain project with it's own consensus"
    DIGIFACT_L3="rules such as Bitcoin or Vertcoin."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact16" ]; then
    DIGIFACT_TITLE="DigiFact # 16 - Did you know..."
    DIGIFACT_L1="DigiByte was the first mobile wallet with a major focus on "
    DIGIFACT_L2="translations for worldwide accessibility, being available"
    DIGIFACT_L3="in 50+ languages on both Android & iOS."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact17" ]; then
    DIGIFACT_TITLE="DigiFact # 17 - Did you know..."
    DIGIFACT_L1="DigiByte can be used to store tiny amounts (80-bytes) of data"
    DIGIFACT_L2="along with a transaction known as OP_RETURN. This is useful for "
    DIGIFACT_L3="document hashes for notarization / validation, dApps, scripting"
    DIGIFACT_L4="and more."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact18" ]; then
    DIGIFACT_TITLE="DigiFact # 18 - Did you know..."
    DIGIFACT_L1="You can look up any transaction on the DigiByte Blockchain by"
    DIGIFACT_L2="inputting a transaction ID, DigiByte address, or block number"
    DIGIFACT_L3="into a \"Blockchain Explorer\". The community maintains one such"
    DIGIFACT_L4="explorer you can use at: https://digiexplorer.info."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact19" ]; then
    DIGIFACT_TITLE="DigiFact # 19 - Did you know..."
    DIGIFACT_L1="Have you wanted to run your own DigiExplorer? Or get other data"
    DIGIFACT_L2="out of the blockchain so you can integrate it with your business? "
    DIGIFACT_L3="There are handy guides at dgbwiki.com that will help you."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact20" ]; then
    DIGIFACT_TITLE="DigiFact # 20 - Did you know..."
    DIGIFACT_L1="In 2019, DigiByte implemented the unique algorithm Odocrypt,"
    DIGIFACT_L2="replacing the older Myriad-Groestl. This Odocrypt hashing"
    DIGIFACT_L3="algorithm is not used in any other project and was made"
    DIGIFACT_L4="specifically by DigiByte developers for DigiByte FPGA mining."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact21" ]; then
    DIGIFACT_TITLE="DigiFact # 21 - Did you know..."
    DIGIFACT_L1="Odocrypt was developed for DigiByte as a polymorphic algorithm"
    DIGIFACT_L2="that resists ASICs, due to Odocrypt reprogramming itself every"
    DIGIFACT_L3="10 days. It is only viable for FPGA mining, not ASICs."
    DIGIFACT_L4=" "
    DIGIFACT_L5="Learn more about Odocrypt here: https://j.mp/3kpZKKB"
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact22" ]; then
    DIGIFACT_TITLE="DigiFact # 22 - Did you know..."
    DIGIFACT_L1="DigiByte is available on 100+ exchanges, including many"
    DIGIFACT_L2="different fiat pairings with local currencies, making it easier"
    DIGIFACT_L3="than ever to buy DigiByte."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact23" ]; then
    DIGIFACT_TITLE="DigiFact # 23 - Did you know..."
    DIGIFACT_L1="DigiByte has a known founder, Jared Tate. Jared is still"
    DIGIFACT_L2="active in the community and contributes code to the DigiByte code-base."
    DIGIFACT_L3=""
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact24" ]; then
    DIGIFACT_TITLE="DigiFact # 24 - Did you know..."
    DIGIFACT_L1="DigiByte can do smart-contracts thanks to its \"script\" language"
    DIGIFACT_L2="You can run a whole lot of powerful tools on top of DigiByte to"
    DIGIFACT_L3="power a dApp."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact25" ]; then
    DIGIFACT_TITLE="DigiFact # 25 - Did you know..."
    DIGIFACT_L1="DigiByte has wallets for Windows, MacOS, Linux, Raspberry Pi,"
    DIGIFACT_L2="Android, iOS and even Chrome OS. We are also supported on several"
    DIGIFACT_L3="dozen other 3rd party & hardware wallets, each unique from the"
    DIGIFACT_L4="others."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact26" ]; then
    DIGIFACT_TITLE="DigiFact # 26 - Did you know..."
    DIGIFACT_L1="Digi-ID by DigiByte is one of the simplest yet most secure"
    DIGIFACT_L2="authentication methods in the world. Even Google warns against"
    DIGIFACT_L3="using their own time-based 2FA codes or SMS-2FA, but Digi-ID"
    DIGIFACT_L4="overcomes all the shortcomings. Digi-ID is open source, free,"
    DIGIFACT_L5="ad-free (forever), private & secure."
    DIGIFACT_L6="To learn more visit: https://www.digi-id.io/"
fi

if [ "$DIGIFACT" = "digifact27" ]; then
    DIGIFACT_TITLE="DigiFact # 27 - Did you know..."
    DIGIFACT_L1="The development of DigiByte is done by a worldwide team of"
    DIGIFACT_L2="volunteers, who all donate their time out of a passion for the"
    DIGIFACT_L3="project. There is no central company employing and paying"
    DIGIFACT_L4="people, it's all given freely by our incredible developers"
    DIGIFACT_L5="and supporting community."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact28" ]; then
    DIGIFACT_TITLE="DigiFact # 28 - Did you know..."
    DIGIFACT_L1="The last DigiByte will be mined by the year 2035. There is less"
    DIGIFACT_L2="than half of all remaining \$DGB waiting to be mined by anybody"
    DIGIFACT_L3="in the world. These are not \"owned\" by anybody, unlike an, "
    DIGIFACT_L4="ICO and will be newly \"minted\"."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact29" ]; then
    DIGIFACT_TITLE="DigiFact # 29 - Did you know..."
    DIGIFACT_L1="DigiByte can be used for Atomic Swaps with other blockchains"
    DIGIFACT_L2="safely and securely since the implementation of SegWit in "
    DIGIFACT_L3="early 2017. There is no need for a second layer network to"
    DIGIFACT_L4="perform this and it can instead be done directly."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact30" ]; then
    DIGIFACT_TITLE="DigiFact # 30 - Did you know..."
    DIGIFACT_L1="When all DigiByte have been mined, the network will continue to"
    DIGIFACT_L2="function with the miners mining / securing the network as they"
    DIGIFACT_L3="do at present. They will only get the transaction fees from"
    DIGIFACT_L4="sending \$DGB."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact31" ]; then
    DIGIFACT_TITLE="DigiFact # 31 - Did you know..."
    DIGIFACT_L1="If you ever have issues with getting your DigiByte out of a"
    DIGIFACT_L2="wallet, you can sweep the funds to a new wallet using the"
    DIGIFACT_L3="DigiSweep tool created by Matthew Cornelisse of DigiAssetX."
    DIGIFACT_L4="It's easy to use & open-source. Go here if you ever need it:"
    DIGIFACT_L5=""
    DIGIFACT_L6="https://digisweep.digiassetx.com/"
fi

if [ "$DIGIFACT" = "digifact32" ]; then
    DIGIFACT_TITLE="DigiFact # 32 - Did you know..."
    DIGIFACT_L1="When DigiByte launched, there was a count-down to the release"
    DIGIFACT_L2="of the code, and to the first block being mined. This was one"
    DIGIFACT_L3="of the things done to encourage a \"fair\" distribution, right"
    DIGIFACT_L4="from the very beginning in 2014."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact33" ]; then
    DIGIFACT_TITLE="DigiFact # 33 - Did you know..."
    DIGIFACT_L1="DigiByte was originally based on a fork of the Litecoin code-base"
    DIGIFACT_L2="(Though, a 100% independent blockchain with unique Genesis"
    DIGIFACT_L3="Block). DigiByte has since maintained closer features with"
    DIGIFACT_L4="Bitcoin, while also significantly innovating and surpassing it!"
    DIGIFACT_L5=" "
    DIGIFACT_L6="View the code at: https://github.com/digibyte-core/digibyte/"
fi

if [ "$DIGIFACT" = "digifact34" ]; then
    DIGIFACT_TITLE="DigiFact # 34 - Did you know..."
    DIGIFACT_L1="You can build second-layer networks on top of DigiByte such as"
    DIGIFACT_L2="DigiAssets, Lightning Networks, ICOs, Tokens, assets and more."
    DIGIFACT_L3=""
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact35" ]; then
    DIGIFACT_TITLE="DigiFact # 35 - Did you know..."
    DIGIFACT_L1="Theres a mind boggling number of possible DigiByte addresses."
    DIGIFACT_L2="1,461,501,637,330,902,918,203,684,832,716,283,019,655,932,542,976"
    DIGIFACT_L3="(2¹⁶⁰). This is a quindecillion. It's so big you could randomly   "
    DIGIFACT_L4="generate trillions a second & never generate the same as"
    DIGIFACT_L5="somebody else."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact36" ]; then
    DIGIFACT_TITLE="DigiFact # 36 - Did you know..."
    DIGIFACT_L1="You can accept DigiByte in retail scenarios just by entering"
    DIGIFACT_L2="the desired amount in to your wallet. The QR code will"
    DIGIFACT_L3="automatically include your address and amount when the"
    DIGIFACT_L4=" sender scans it. Super simple, straight from your wallet."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact37" ]; then
    DIGIFACT_TITLE="DigiFact # 37 - Did you know..."
    DIGIFACT_L1="The Core DigiByte wallet connects to a variety of peers, not"
    DIGIFACT_L2="just the 'closest' or 'fastest'. It finds connections from"
    DIGIFACT_L3="all over the world, to ensure you get a broad consensus"
    DIGIFACT_L4="on the DigiByte blockchain and protects you against sybil"
    DIGIFACT_L5="attacks."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact38" ]; then
    DIGIFACT_TITLE="DigiFact # 38 - Did you know..."
    DIGIFACT_L1="DigiByte implemented the DigiSpeed protocol in 2015. This allowed"
    DIGIFACT_L2="allowed DigiByte to decrease from 30 second to 15 second block"
    DIGIFACT_L3="timings. Lightning fast!"
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact39" ]; then
    DIGIFACT_TITLE="DigiFact # 39 - Did you know..."
    DIGIFACT_L1="Have you ever wanted to try another wallet? Are you after some"
    DIGIFACT_L2="fancy features? Or perhaps you just want simplicity?"
    DIGIFACT_L3="To discover the best wallet for you, visit:"
    DIGIFACT_L4=" "
    DIGIFACT_L5="https://digibytewallets.com/"
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact40" ]; then
    DIGIFACT_TITLE="DigiFact # 40 - Did you know..."
    DIGIFACT_L1="Did you know that DigiByte is permissionless? This means there"
    DIGIFACT_L2="is no individual or company to ask if you can build a dApp"
    DIGIFACT_L3="on top of it, use it, send it, receive it, accept it for your"
    DIGIFACT_L4="business, advertise it, promote it. You simply \"can\"!"
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact41" ]; then
    DIGIFACT_TITLE="DigiFact # 41 - Did you know..."
    DIGIFACT_L1="DigiByte is now working on its 8th \"protocol\" version in 6 years"
    DIGIFACT_L2="since creation. This is what the first number in the DigiByte"
    DIGIFACT_L3="Core Wallet version means, the protocol version. DigiByte"
    DIGIFACT_L4="has consistently grown and improved throughout its history,"
    DIGIFACT_L5="and continues to do-so."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact42" ]; then
    DIGIFACT_TITLE="DigiFact # 42 - Did you know..."
    DIGIFACT_L1="DigiBytes MultiAlgo means 5x algorithms all continuously compete"
    DIGIFACT_L2="for every single block. Others such as X16R are very different,"
    DIGIFACT_L3="instead rotating through each sub-algorithm with all miners"
    DIGIFACT_L4="swapping and using that same. As such, X16R is still a \"single"
    DIGIFACT_L5="algorithm\" compared with DigiBytes 5x MultiAlgo implementation."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact43" ]; then
    DIGIFACT_TITLE="DigiFact # 43 - Did you know..."
    DIGIFACT_L1="The Dandelion privacy protocol has been implemented in to"
    DIGIFACT_L2="DigiByte Core, as well as the DigiByte Android & iOS apps."
    DIGIFACT_L3="It helps protect your privacy, by masking the originating IP"
    DIGIFACT_L4="address."
    DIGIFACT_L5=" "
    DIGIFACT_L6="To learn more about Dandelion, visit: https://j.mp/3Hag6AX"
fi

if [ "$DIGIFACT" = "digifact44" ]; then
    DIGIFACT_TITLE="DigiFact # 44 - Did you know..."
    DIGIFACT_L1="MultiShield is a powerful difficulty adjustment algorithm. It"
    DIGIFACT_L2="ensures each of DigiBytes 5X algorithms all mine roughly an equal"
    DIGIFACT_L3="amount of blocks, while maintaining a steady 15 second timing."
    DIGIFACT_L4=" "
    DIGIFACT_L5="What is MultiShield? Learn more here:"
    DIGIFACT_L6="https://j.mp/3oivy5u"
fi

if [ "$DIGIFACT" = "digifact45" ]; then
    DIGIFACT_TITLE="DigiFact # 45 - Did you know..."
    DIGIFACT_L1="Because of MultiShield, DigiByte has some of the most accurate"
    DIGIFACT_L2="and stable block-timings. Where other projects usually wait"
    DIGIFACT_L3="for 3-4 days to adjust, MultiShield tweaks. adjusts & refines"
    DIGIFACT_L4="every single block."
    DIGIFACT_L5=" "
    DIGIFACT_L6="Learn more here: https://j.mp/3oivy5u"
fi

if [ "$DIGIFACT" = "digifact46" ]; then
    DIGIFACT_TITLE="DigiFact # 46 - Did you know..."
    DIGIFACT_L1="DigiByte was the first major blockchain project to enable the"
    DIGIFACT_L2="Dandelion privacy protocol, to protect your IP address. You can"
    DIGIFACT_L3="opt out of the privacy-protection it offers if you want even"
    DIGIFACT_L4="faster transactions."
    DIGIFACT_L5=" "
    DIGIFACT_L6="To learn more about Dandelion, visit: https://j.mp/3Hag6AX"
fi

if [ "$DIGIFACT" = "digifact47" ]; then
    DIGIFACT_TITLE="DigiFact # 47 - Did you know..."
    DIGIFACT_L1="DigiByte is all about choice, and what works for you personally."
    DIGIFACT_L2="DigiByte is available on over two dozen wallets, so there's"
    DIGIFACT_L3="something that will fit everyone's requirements."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact48" ]; then
    DIGIFACT_TITLE="DigiFact # 48 - Did you know..."
    DIGIFACT_L1="DigiByte originally had 60 second block timings, however through"
    DIGIFACT_L2="multiple network upgrades that were improved upon, first to 30,"
    DIGIFACT_L3="and now to the 15 seconds it is today."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact49" ]; then
    DIGIFACT_TITLE="DigiFact # 49 - Did you know..."
    DIGIFACT_L1="DigiByte has had 100% uptime since its launch. While some people"
    DIGIFACT_L2="restart their computers from time to time, hundreds of others"
    DIGIFACT_L3="remain online all the time so that even in event of a major"
    DIGIFACT_L4="nationwide internet outage, DigiByte would still continue to"
    DIGIFACT_L5="function."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact50" ]; then
    DIGIFACT_TITLE="DigiFact # 50 - Did you know..."
    DIGIFACT_L1="DigiByte Faucet is a useful website where anyone can get some"
    DIGIFACT_L2="free DGB and experience this amazing technology first hand."
    DIGIFACT_L3="For developers, they also provide a testnet faucet."
    DIGIFACT_L4="Tell your friends."
    DIGIFACT_L5=""
    DIGIFACT_L6="https://www.digifaucet.org/"
fi

if [ "$DIGIFACT" = "digifact51" ]; then
    DIGIFACT_TITLE="DigiFact # 51 - Did you know..."
    DIGIFACT_L1="Anybody is able to contribute to the DigiByte code and make"
    DIGIFACT_L2="improvements. All submissions get reviewed by other developers"
    DIGIFACT_L3="to ensure no malicious code is accidentally accepted."
    DIGIFACT_L4=" "
    DIGIFACT_L5="Join the Gitter dev chat here:"
    DIGIFACT_L6="https://gitter.im/DigiByte-Core/protocol"
fi

if [ "$DIGIFACT" = "digifact52" ]; then
    DIGIFACT_TITLE="DigiFact # 52 - Did you know..."
    DIGIFACT_L1="Have you ever wanted to see some statistics about the DigiByte"
    DIGIFACT_L2="network? For an overview of the of the DigiByte network, visit:"
    DIGIFACT_L3=" "
    DIGIFACT_L4="https://digistats.digibyteservers.io"
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact53" ]; then
    DIGIFACT_TITLE="DigiFact # 53 - Did you know..."
    DIGIFACT_L1="Nobody knows exactly how many \"nodes\" there are on the DigiByte"
    DIGIFACT_L2="network, because there is no central point that all computers"
    DIGIFACT_L3="check in with. This ensures your privacy when you download"
    DIGIFACT_L4="the wallet software."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact54" ]; then
    DIGIFACT_TITLE="DigiFact # 54 - Did you know..."
    DIGIFACT_L1="DigiByte has never hand a contentious hard fork despite ongoing"
    DIGIFACT_L2="major code changes. Mining is so decentralized that when the"
    DIGIFACT_L3="myriad-groestl algorithm was replaced with odocrypt, MG mining"
    DIGIFACT_L4="pools installed the upgrade even when it meant they would no"
    DIGIFACT_L5="longer be able to mine."
    DIGIFACT_L6=""
fi

 if [ "$DIGIFACT" = "digifact55" ]; then
    DIGIFACT_TITLE="DigiFact # 55 - Did you know..."
    DIGIFACT_L1="DigiByte mining is some of the most distributed in the industry."
    DIGIFACT_L2="When a 7-day period in September 2019 was compared against"
    DIGIFACT_L3="Bitcoin and Litecoin, DigiByte had over 10X the number of unique"
    DIGIFACT_L4="miners. This grew to over 20X the unique miners when looking at"
    DIGIFACT_L5="a 3-month period. View more stats here: https://j.mp/3ojzV08"
    DIGIFACT_L6=""
 fi

if [ "$DIGIFACT" = "digifact56" ]; then
    DIGIFACT_TITLE="DigiFact # 56 - Did you know..."
    DIGIFACT_L1="If the biggest 5x pools from Bitcoin were to collude, they could"
    DIGIFACT_L2="control the Bitcoin, Bitcoin Cash, and Bitcoin SV networks"
    DIGIFACT_L3="permanently until others grew to have more hash-power than them."
    DIGIFACT_L4="Those same pools would not be a threat to DigiByte thanks to"
    DIGIFACT_L5="DigiBytes MultiAlgo and MultiShield aspects."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact57" ]; then
    DIGIFACT_TITLE="DigiFact # 57 - Did you know..."
    DIGIFACT_L1="Every month, the DigiByte that miners get as a block-reward is"
    DIGIFACT_L2="decreased by 1%. This gives DigiByte a very smooth supply-curve"
    DIGIFACT_L3="for new DigiByte, rather than a \"halving\" event every few years."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact58" ]; then
    DIGIFACT_TITLE="DigiFact # 58 - Did you know..."
    DIGIFACT_L1="Transactions on the DigiByte network are public, but"
    DIGIFACT_L2="pseudo-anonymous. You can see them on a Blockchain explorer,"
    DIGIFACT_L3="however there is nothing inherently that can link a new"
    DIGIFACT_L4="transaction / address to an end-user. There are no usernames,"
    DIGIFACT_L5="email addresses etc required to use the DigiByte network."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact59" ]; then
    DIGIFACT_TITLE="DigiFact # 59 - Did you know..."
    DIGIFACT_L1="DigiByte addresses can be re-used, but it's completely optional."
    DIGIFACT_L2="The best practice is for a wallet to give you a new address"
    DIGIFACT_L3="each time after your previous address has received a"
    DIGIFACT_L4="transaction. This is why you get a newly generated address each"
    DIGIFACT_L5="time in the DigiByte Android & iOS apps."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact60" ]; then
    DIGIFACT_TITLE="DigiFact # 60 - Did you know..."
    DIGIFACT_L1="The source code for the DigiByte blockchain is completely"
    DIGIFACT_L2="open-source, anybody can see it, inspect it, and review it."
    DIGIFACT_L3="The Core Wallet is available at: "
    DIGIFACT_L4=" "
    DIGIFACT_L5="https://github.com/DigiByte-Core/DigiByte"
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact61" ]; then
    DIGIFACT_TITLE="DigiFact # 61 - Did you know..."
    DIGIFACT_L1="DigiByte blocks have an expected 15 second time, which means "
    DIGIFACT_L2="every single day there are 5,760 new blocks added to the"
    DIGIFACT_L3="DigiByte blockchain."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact62" ]; then
    DIGIFACT_TITLE="DigiFact # 62 - Did you know..."
    DIGIFACT_L1="A single DigiByte can be divided up to 8 decimal places. That's"
    DIGIFACT_L2="1/100,000,000 of a DigiByte. This is known as a Digit or DIT"
    DIGIFACT_L3="for short. (e.g. 1000 DITS)"
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact63" ]; then
    DIGIFACT_TITLE="DigiFact # 63 - Did you know..."
    DIGIFACT_L1="Each of the 5x algorithms that DigiByte uses to secure the"
    DIGIFACT_L2="network and mine new blocks has an equal 20% chance to find every"
    DIGIFACT_L3="single block. There is no priority given to one or another."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact64" ]; then
    DIGIFACT_TITLE="DigiFact # 64 - Did you know..."
    DIGIFACT_L1="DigiByte has 3x address types, each starting with a different"
    DIGIFACT_L2="prefix. Modern addresses start with the letters \"dgb1\""
    DIGIFACT_L3="for Bech32 formatted addresses or the letter \"S\" for"
    DIGIFACT_L4="SegWit (Segregated Witness). Legacy addresses start with the"
    DIGIFACT_L5="letter \"D\". While support for these will remain, they are"
    DIGIFACT_L6="gradually being phased out in favor of of Bech32 addresses."
fi

if [ "$DIGIFACT" = "digifact65" ]; then
    DIGIFACT_TITLE="DigiFact # 65 - Did you know..."
    DIGIFACT_L1="DigiByte addresses starting with \"dgb1\" (known as Bech32 format)"
    DIGIFACT_L2="have multiple advantages, such as error correction in the event"
    DIGIFACT_L3="they were incorrectly written-down, as well as being much easier"
    DIGIFACT_L4="for both humans and computers to recognise that they are"
    DIGIFACT_L5="DigiByte-specific addresses."
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact66" ]; then
    DIGIFACT_TITLE="DigiFact # 66 - Did you know..."
    DIGIFACT_L1="For a protocol upgrade to take place, over 70% of the network"
    DIGIFACT_L2="must agree and be in consensus that the upgrade will take place."
    DIGIFACT_L3="This occurs by \"signalling\" support for it when blocks are"
    DIGIFACT_L4="mined, over the course of a 1-week period."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact67" ]; then
    DIGIFACT_TITLE="DigiFact # 67 - Did you know..."
    DIGIFACT_L1="There is a maximum of 21 billion DigiByte that will ever exist."
    DIGIFACT_L2="This was intentionally chosen as a 1000:1 ratio compared to"
    DIGIFACT_L3="Bitcoins 21 million. No more can ever be created."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact68" ]; then
    DIGIFACT_TITLE="DigiFact # 68 - Did you know..."
    DIGIFACT_L1="DigiByte is available on thousands of Crypto ATMs around the"
    DIGIFACT_L2="world! This is a great way for people new to cryptocurrency"
    DIGIFACT_L3="to get involved through a more \"traditional\" method of currency"
    DIGIFACT_L4="exchange."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact69" ]; then
    DIGIFACT_TITLE="DigiFact # 69 - Did you know..."
    DIGIFACT_L1="DigiByte can be used to verify and validate documents, music,"
    DIGIFACT_L2="media, identity and more! Although DigiByte excels as a means of"
    DIGIFACT_L3="exchanging value, it is not limited to just being a currency."
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact70" ]; then
    DIGIFACT_TITLE="DigiFact # 70 - Did you know..."
    DIGIFACT_L1="You can use multiple wallets! DigiByte is not just limited to a"
    DIGIFACT_L2="single piece of software, and the community is encouraged to find"
    DIGIFACT_L3="an app that works best for them, so try one, try a few, and keep"
    DIGIFACT_L4="using the ones you like the most."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact71" ]; then
    DIGIFACT_TITLE="DigiFact # 71 - Did you know..."
    DIGIFACT_L1="DigiByte cannot ever have a centralized \"burning\" of the maximum"
    DIGIFACT_L2="supply as other ICO's or centrally controlled tokens can. Because"
    DIGIFACT_L3="DigiByte is a fully decentralized proejct, it's impossible to"
    DIGIFACT_L4="issue a large scale \"burning\" of unused DigiByte. At most, you"
    DIGIFACT_L5="could only ever destroy your own if you willingly transferred"
    DIGIFACT_L6="them in to the void."
fi

if [ "$DIGIFACT" = "digifact72" ]; then
    DIGIFACT_TITLE="DigiFact # 72 - Did you know..."
    DIGIFACT_L1="Transactions on the DigiByte blockchain cannot be undone, by"
    DIGIFACT_L2="anybody. Once a transaction has been made, it is permanent. Did"
    DIGIFACT_L3="you accidentally send 50 DigiByte instead of 5 DigiByte? You'll"
    DIGIFACT_L4="need to ask the recipient to return the surplus, as there is no"
    DIGIFACT_L5="\"Undo\" function, and no central banking authority who can"
    DIGIFACT_L6="roll back transactions."
fi

if [ "$DIGIFACT" = "digifact73" ]; then
    DIGIFACT_TITLE="DigiFact # 73 - Did you know..."
    DIGIFACT_L1="Do you want to start a DigiByte podcast, or meet-up? Go for it!"
    DIGIFACT_L2="There is nobody to ask for permission, part of DigiByte being a"
    DIGIFACT_L3="\"permissionless\" project. It is implied that you can, so go"
    DIGIFACT_L4="right ahead and do it."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact74" ]; then
    DIGIFACT_TITLE="DigiFact # 74 - Did you know..."
    DIGIFACT_L1="The name \"DigiByte\" was originally chosen as it signifies a"
    DIGIFACT_L2="\"Digital Byte\" of data. This is because blockchain technology"
    DIGIFACT_L3="such as DigiByte can be used for so much more than as a \"coin\""
    DIGIFACT_L4="such as silver or gold. DigiByte is incredibly multi-purpose."
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact75" ]; then
    DIGIFACT_TITLE="DigiFact # 75 - Did you know..."
    DIGIFACT_L1="A copy of the DigiByte blockchain open source code v7.17.2 is"
    DIGIFACT_L2="laying in cold storage 250 meters deep in the permafrost of an"
    DIGIFACT_L3="Arctic mountain! Thanks to the GitHub Arctic Code Vault program!"
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "digifact76" ]; then
    DIGIFACT_TITLE="DigiFact # 76 - Did you know..."
    DIGIFACT_L1="If you have ever had the misfortune to accidentally send your"
    DIGIFACT_L2="DigiByte to a Dogecoin address, your coins may not be lost."
    DIGIFACT_L3="DigiSweep by @mctrivia may be able to help you recover them."
    DIGIFACT_L4="Go here:"
    DIGIFACT_L5=""
    DIGIFACT_L6="https://digisweep.digiassetx.com/"
fi

if [ "$DIGIFACT" = "digifact77" ]; then
    DIGIFACT_TITLE="DigiFact # 76 - Did you know..."
    DIGIFACT_L1="The DigiByte Alliance is a public non-profit foundation founded"
    DIGIFACT_L2="in Wyoming in March 2021. Its mission is to to accelerate the"
    DIGIFACT_L3="growth and adoption of DigiByte."
    DIGIFACT_L4=""
    DIGIFACT_L5="Learn more: https://www.dgballiance.org/"
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "social1" ]; then
    DIGIFACT_TITLE="Join the DigiByte Community on Reddit!"
    DIGIFACT_L1="Have you joined the DigiByte subreddit yet?"
    DIGIFACT_L2="We have a growing community of over 45,000 members."
    DIGIFACT_L3=" "
    DIGIFACT_L4="Join here: https://reddit.com/r/Digibyte"
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "social2" ]; then
    DIGIFACT_TITLE="Join the DigiByte Community on Discord!"
    DIGIFACT_L1="Have you joined the DigiByte Community on Discord yet?"
    DIGIFACT_L2=" "
    DIGIFACT_L3="Join here: https://dsc.gg/digibytediscord"
    DIGIFACT_L4=""
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "help1" ]; then
    DIGIFACT_TITLE="      DigiFact Tip!"
    DIGIFACT_L1="Some of these DigiFacts include a website URL which can be"
    DIGIFACT_L2="dificult to open from the terminal. To open a link,"
    DIGIFACT_L3="try holding the \"Cmd\" key on Mac or the \"Ctrl\" key"
    DIGIFACT_L4="on Windows as you click on it."
    DIGIFACT_L5=" "
    DIGIFACT_L6="Try it now: https://diginode.digibyte.help"
fi

if [ "$DIGIFACT" = "help2" ]; then
    DIGIFACT_TITLE="Need Help with DigiNode Tools?"
    DIGIFACT_L1="You can reach out to @digibytehelp on Twitter."
    DIGIFACT_L2=" "
    DIGIFACT_L3="You can also join the DigiNode Tools telegram group here: "
    DIGIFACT_L4=" "
    DIGIFACT_L5="https://t.me/joinchat/ked2VGZsLPAyN2Jk"
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "help3" ]; then
    DIGIFACT_TITLE="    Need DigiByte Support?"
    DIGIFACT_L1="For general DigiByte support, the best place to start is with"
    DIGIFACT_L2="the community support tool available here:"
    DIGIFACT_L3=" "
    DIGIFACT_L4="https://dgbsupport.digiassetx.com/"
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "help4" ]; then
    DIGIFACT_TITLE="      DigiNode Tip!"
    DIGIFACT_L1="Did you know that you can view your DigiNode on a map?"
    DIGIFACT_L2=" "
    DIGIFACT_L3=" DigiByte Node: https://nodes.digibyte.host/"
    DIGIFACT_L4="DigiAsset Node: https://ipfs.digiassetx.com/"
    DIGIFACT_L5=" "
    DIGIFACT_L6="This is a good way to check your DigiNode is setup correctly!"
fi

if [ "$DIGIFACT" = "help5" ]; then
    DIGIFACT_TITLE="    Need DigiAsset Support?"
    DIGIFACT_L1="For help with creating DigiAssets, a good place to start is"
    DIGIFACT_L2="the DigiAssetX Telegram group here:"
    DIGIFACT_L3=" "
    DIGIFACT_L4="https://t.me/digiassetX"
    DIGIFACT_L5=""
    DIGIFACT_L6=""
fi

if [ "$DIGIFACT" = "help6" ]; then
    DIGIFACT_TITLE="    Want to learn more about DigiByte?"
    DIGIFACT_L1="The DGB Wiki is a fanatastic resource of information on all"
    DIGIFACT_L2="things DigiByte, written and maintained by members of the"
    DIGIFACT_L3="DigiByte community:"
    DIGIFACT_L4=" "
    DIGIFACT_L5="https://dgbwiki.com/"
    DIGIFACT_L6=""
fi




printf "  ╔═════════════════════════════════════════════════════════════════════╗\\n"
printf "  ║ " && printf "%-66s %-4s\n" "              $DIGIFACT_TITLE" " ║"
printf "  ╠═════════════════════════════════════════════════════════════════════╣\\n"

if [ "$DIGIFACT_L1" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L1" " ║"
fi

if [ "$DIGIFACT_L2" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L2" " ║"
fi

if [ "$DIGIFACT_L3" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L3" " ║"
fi

if [ "$DIGIFACT_L4" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L4" " ║"
fi

if [ "$DIGIFACT_L5" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L5" " ║"
fi

if [ "$DIGIFACT_L6" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L6" " ║"
fi

if [ "$DIGIFACT_L7" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L7" " ║"
fi

if [ "$DIGIFACT_L8" != "" ]; then
printf "  ║ " && printf "%-66s %-4s\n" "$DIGIFACT_L8" " ║"
fi

printf "  ╚═════════════════════════════════════════════════════════════════════╝\\n"
printf "\\n"

}



####################################
######## EXTRAS ####################
####################################

# This function will install or upgrade the fan Argon One Daemon, a replacement daemon
# for controlling the fan in the Argon One cases for the Raspberry Pi 4.
#
# More info here: https://github.com/iandark/argon-one-daemon

install_argon_one_fan_software() {

# Is this an upgrade or an install?
if [ -d "$USER_HOME/argon-one-daemon" ]; then
    ARGONFAN_INSTALL_TYPE="upgrade"
else
    ARGONFAN_INSTALL_TYPE="new"
fi

# Display section break
if [ "$ARGONFAN_INSTALL_TYPE" = "new" ]; then
    printf " =============== Install: Argon One Daemon =============================\\n\\n"
    # ==============================================================================
elif [ "$ARGONFAN_INSTALL_TYPE" = "upgrade" ]; then
    printf " =============== Upgrade: Argon One Daemon =============================\\n\\n"
    # ==============================================================================
fi


# Display INSTALL dialog

if [ "$ARGONFAN_INSTALL_TYPE" = "new" ]; then

    # Explain the need for a static address
    if whiptail --defaultno --backtitle "" --title "Install Argon One Daemon" --yesno "Would you like to install the Argon One Daemon?\\n\\nThis software is used to manage the fan on the Argon ONE M.2 Case for the Raspberry Pi 4. It will also work with the Argon Artik Fan Hat. If are not using these devices, do not install the software.\\n\\nMore info: https://github.com/iandark/argon-one-daemon\\n\\n" --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then
    #Nothing to do, continue
      printf "%b You choose to INSTALL the Argon One Daemon.\\n" "${INFO}"
      printf "\\n"
    else
      printf "%b You choose not to INSTALL the Argon One Daemon.\\n" "${INFO}"
      printf "\\n"
      menu_existing_install
    fi

elif [ "$ARGONFAN_INSTALL_TYPE" = "upgrade" ]; then

    # Explain the need for a static address
    if whiptail --defaultno --backtitle "" --title "Upgrade Argon One Daemon" --yesno "Would you like to upgrade the Argon One Daemon?\\n\\nThis software is used to manage the fan on the Argon ONE M.2 Case for the Raspberry Pi 4.\\n\\n" --yes-button "Continue" --no-button "Exit" "${r}" "${c}"; then
    #Nothing to do, continue
      printf "%b You choose to UPGRADE the Argon One Daemon.\\n" "${INFO}"
      printf "\\n"
    else
      printf "%b You choose not to UPGRADE the Argon One Daemon.\\n" "${INFO}"
      printf "\\n"
      menu_existing_install
    fi

fi




if [ "$ARGONFAN_INSTALL_TYPE" = "new" ]; then

    # Cloning from GitHub
    str="Cloning Argon One Daemon from Github repository..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT git clone --depth 1 --quiet https://github.com/iandark/argon-one-daemon $USER_HOME/argon-one-daemon 2>/dev/null

    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: Argone One Daemon Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b Argon One Daemon could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
        printf "%b Please contact @digibytehelp so a fix can be issued.\\n" "${INDENT}"
        printf "\\n"

        exit
    fi

fi

if [ "$ARGONFAN_INSTALL_TYPE" = "upgrade" ]; then

    # Cloning from GitHub
    str="Pulling latest Argon One Daemon from Github repository..."
    printf "%b %s" "${INFO}" "${str}"
    cd $USER_HOME/argon-one-daemon
    sudo -u $USER_ACCOUNT git pull -q

    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: Argon One Daemon Upgrade Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b Argon One Daemon could not be upgraded. Perhaps the download URL has changed?\\n" "${INFO}"
        printf "%b Please contact @digibytehelp so a fix can be issued.\\n" "${INDENT}"
        printf "\\n"

        exit
    fi

fi

# Make install script executable
# str="Making Argone One Daemon install script executable..."
# printf "%b %s" "${INFO}" "${str}"
# chmod +x $USER_HOME/argon-one-daemon/install
# printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

# Install/upgrade daemon
printf "%b Installing/upgrading Argone One Daemon...\\n" "${INFO}"
cd $USER_HOME/argon-one-daemon
sudo -u $USER_ACCOUNT $USER_HOME/argon-one-daemon/install

# If there was an error
if [ $? -ne 0 ]; then
    printf "\\n"
    printf "%b Installing Argon One Daemon failed. Please install any missing dependencies and run this again.\\n" "${INFO}"
    printf "\\n"
    exit 1
fi

sleep 5

# Set fan to auto
printf "\\n"
str="Setting Fan to Auto Mode..."
printf "%b %s" "${INFO}" "${str}"
argonone-cli --auto
printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

printf "\\n"

if [ "$ARGONFAN_INSTALL_TYPE" = "new" ]; then
    printf "%b %bArgon One Daemon has been installed and set to automatic mode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b The automatic mode values are:\\n" "${INDENT}"
    echo "      - Above 55℃ the fan runs at 10%."
    echo "      - Above 60℃ the speed increases to 55%."
    echo "      - Above 65℃ the fan will spin at 100%."
    echo "      - The default hysteresis is 3℃."
    printf "\\n"
    printf "%b These can be changed using the CLI tool: ${txtbld}argonone-cli --help${txtrst}\\n" "${INDENT}"
    printf "\\n"
    exit
fi

if [ "$ARGONFAN_INSTALL_TYPE" = "upgrade" ]; then
    printf "%b %bArgon One Daemon has been upgraded and set to automatic mode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b The automatic mode values are:\\n" "${INDENT}"
    echo "      - Above 55℃ the fan runs at 10%."
    echo "      - Above 60℃ the speed increases to 55%."
    echo "      - Above 65℃ the fan will spin at 100%."
    echo "      - The default hysteresis is 3℃."
    printf "\\n"
    printf "%b These can be changed using the CLI tool: ${txtbld}argonone-cli --help${txtrst}\\n" "${INDENT}"
    printf "\\n"
    exit
fi

printf "\\n"

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

        # set the DigiNode Tools branch to use for DigiNode Setup
        set_dgnt_branch

        # Display a message if Unattended Mode is enabled
        is_unattended_mode

        # Display if DigiAsset Node only mode is manually enabled or disable via the launch flag
        is_dganode_only_mode

        # Display a message if Verbose Mode is enabled
        is_verbose_mode

        # Display a message if Reset Mode is enabled. Quit if Reset and Unattended Modes are enable together.
        is_reset_mode 

        # Display a message if DigiAsset Node developer mode is enabled
        is_dgadev_mode

        # Is this script running remotely or locally?
        where_are_we

        # Show the DigiNode logo
        diginode_logo_v3
        make_temporary_log

    else
        # show DigiNode Setup title box
        setup_title_box

        # set the DigiNode Tools branch to use for DigiNode Setup
        set_dgnt_branch

        # Otherwise, they do not have enough privileges, so let the user know
        printf "%b %s\\n" "${INFO}" "${str}"
        printf "%b %bScript called with non-root privileges%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b DigiNode Setup requires elevated privileges to get started.\\n" "${INDENT}"
        printf "%b Please review the source code on GitHub for any concerns regarding this\\n" "${INDENT}"
        printf "%b requirement. Make sure to download this script from a trusted source.\\n\\n" "${INDENT}"
        printf "%b Sudo utility check" "${INFO}"

        # If the sudo command exists, try rerunning as admin
        if is_command sudo ; then
            printf "%b%b Sudo utility check\\n" "${OVER}" "${TICK}"

            # when run via curl piping
            if [[ "$0" == "bash" ]]; then

                printf "%b Re-running DigiNode Setup URL as root...\\n" "${INFO}"

                # Download the install script and run it with admin rights
                exec curl -sSL $DGNT_SETUP_URL | sudo bash -s -- --runremote "$@" 
            else
                # when run via calling local bash script
                printf "%b Re-running DigiNode Setup as root...\\n" "${INFO}"
                exec sudo bash "$0" --runlocal "$@"
            fi

            exit $?
        else
            # Otherwise, tell the user they need to run the script as root, and bail
            printf "%b  %b Sudo utility check\\n" "${OVER}" "${CROSS}"
            printf "%b Sudo is needed for DigiNode Setup to proceed.\\n\\n" "${INFO}"
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

    # update diginode settings if there is a new version
    diginode_tools_update_settings

    # Set the system variables once we know we are on linux
    set_sys_variables

    # Lookup the external IP
    lookup_external_ip

    # If there is an existing install of a DigiAsset Node, but no DigiByte Node then let's assume this is a DigiAsset Only setup
    if [ ! -f "$DGB_INSTALL_LOCATION/bin/digibyted" ] && [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ] && [ "$UNOFFICIAL_DIGIBYTE_NODE" != "YES" ] && [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ] && [ -z "$DGANODE_ONLY" ]; then
        printf "%b DigiAsset Asset Node ONLY Detected. Hardware checks will be skipped.\\n" "${INFO}"
        DGANODE_ONLY=true
    fi

    if [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ] && [ "$DGANODE_ONLY" = true ]; then
        printf "%b %bWARNING: DigiByte Node Detected. DigiAsset Node ONLY Mode has been disabled.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        DGANODE_ONLY=false
    fi

    # Check for Raspberry Pi hardware
    if [[ "$DGANODE_ONLY" == false ]]; then
        rpi_check
    else
        printf "%b Skipping Raspberry Pi hardware checks...\\n" "${INFO}"
        printf "\\n"
    fi

    # Install packages used by this installation script
    printf "%b Checking for / installing required dependencies for DigiNode Setup...\\n" "${INFO}"
    install_dependent_packages "${SETUP_DEPS[@]}"

    # Check if there is an existing install of DigiByte Core, installed with this script
    if [[ -f "${DGB_INSTALL_LOCATION}/.officialdiginode" ]]; then
        NewInstall=false
        printf "%b Existing DigiNode detected...\\n\\n" "${INFO}"

        # If uninstall is requested, then do it now
        if [[ "$UNINSTALL" == true ]]; then
            uninstall_do_now
        fi

        # if it's running unattended,
        if [[ "${UNATTENDED_MODE}" == true ]]; then

            printf "%b %bUnattended Upgrade: Performing automatic upgrade%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b ${txtbld}No menus will be displayed${txtrst}\\n" "${INDENT}"
            printf "\\n"

            # Perform unattended upgrade
            UnattendedUpgrade=true
            # also disable debconf-apt-progress dialogs
            export DEBIAN_FRONTEND="noninteractive"
        else
            # If running attended, show the main menu
            UnattendedUpgrade=false
        fi
    else
        NewInstall=true
        if [[ "${UNATTENDED_MODE}" == true ]]; then

            printf "%b %bUnattended Install: Using options from diginode.settings%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "%b ${txtbld}No menus will be displayed${txtrst}\\n" "${INDENT}"
            printf "\\n"

            # Perform unattended upgrade
            UnattendedInstall=true
            # also disable debconf-apt-progress dialogs
            export DEBIAN_FRONTEND="noninteractive"
        else
            UnattendedInstall=false
        fi
    fi



    # If there is an existing install of DigiByte Core, but it was not installed by this script, mark this node as "unofficial"
    if [ -f "$DGB_INSTALL_LOCATION/bin/digibyted" ] && [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ]; then
        UNOFFICIAL_DIGIBYTE_NODE="YES"
        UNOFFICIAL_DIGIBYTE_NODE_LOCATION="$DGB_INSTALL_LOCATION"
    elif [ -f "/usr/bin/digibyted/bin/digibyted" ]; then
        UNOFFICIAL_DIGIBYTE_NODE="YES"
        UNOFFICIAL_DIGIBYTE_NODE_LOCATION="/usr/bin/digibyted"
    elif [ -f "/usr/bin/digibyte/bin/digibyted" ]; then
        UNOFFICIAL_DIGIBYTE_NODE="YES"
        UNOFFICIAL_DIGIBYTE_NODE_LOCATION="/usr/bin/digibyte"
    fi



    # If this is an "unofficial" DigiByte Node
    if [ "$UNOFFICIAL_DIGIBYTE_NODE" = "YES" ]; then

        # Display donation dialog
        donationDialog

        printf "%b %bUnable to upgrade this installation of DigiByte Core%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b An existing install of DigiByte Core was discovered, but it was not originally installed\\n" "${INDENT}"
        printf "%b using DigiNode Setup and so cannot be upgraded. Please start with with a clean Linux installation.\\n" "${INDENT}"
        printf "\\n"
        printf "%b DigiByte Node Location: $UNOFFICIAL_DIGIBYTE_NODE_LOCATION\\n" "${INFO}"
        printf "\\n"

        # If DigiNode Tools is installed, offer to check for an update
        if [ -f "$DGNT_MONITOR_SCRIPT" ]; then
            
            printf " =============== DIGINODE SETUP - MAIN MENU ============================\\n\\n"
            # ==============================================================================

            opt1a="Update"
            opt1b="Check for updates to DigiNode Tools"
            
            opt2a="Uninstall"
            opt2b="Remove DigiNode Tools from your system"


            # Display the information to the user
            UpdateCmd=$(whiptail --title "DigiNode Setup - Main Menu" --menu "\\nAn existing DigiByte Node was discovered on this system, but since DigiNode Setup was not used to set it up originally, it cannot be used to manage it.\\n\\nDigiByte Node Location: $UNOFFICIAL_DIGIBYTE_NODE_LOCATION\\n\\nYou can check for updates to DigiNode Tools itself to upgrade the Status Monitor. You can also choose to Uninstall DigiNode Tools.\\n\\nPlease choose an option:\\n\\n" --cancel-button "Exit" "${r}" 80 3 \
            "${opt1a}"  "${opt1b}" \
            "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
            { printf "%b %bExit was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; printf "\\n"; digifact_randomize; digifact_display; printf "\\n"; exit; }

            # Set the variable based on if the user chooses
            case ${UpdateCmd} in
                # Install DigiNode Tools
                ${opt1a})
                    printf "%b %soption selected\\n" "${INFO}" "${opt1a}"
                    printf "\\n"
                                
                    ;;
                # Uninstall,
                ${opt2a})
                    printf "%b You selected the UNINSTALL option.\\n" "${INFO}"
                    printf "\\n"
                    uninstall_diginode_tools_now
                    digifact_randomize
                    digifact_display
                    donation_qrcode
                    printf "\\n"
                    exit
                    ;;
            esac
            printf "\\n"

        # If DigiNode Tools is not installed), offer to install them
        else
            if whiptail --backtitle "" --title "DigiNode Setup - Main Menu" --yesno "Would you like to install DigiNode Tools?\\n\\nAn existing DigiByte Node was discovered on this system, but since DigiNode Setup was not used to set it up originally, it cannot be used to manage it.\\n\\nDigiByte Node Location: $UNOFFICIAL_DIGIBYTE_NODE_LOCATION\\n\\nYou can install DigiNode Tools, so you can use the Status Monitor with your existing DigiByte Node. Would you like to do that now?" "${r}" "${c}"; then

                install_diginode_tools_only

            else
                printf "%b Exiting: You chose not to install DigiNode Tools.\\n" "${INFO}"
                printf "\\n"
                digifact_randomize
                digifact_display
                printf "\\n"
                exit
            fi
        fi

    fi


    # If the is a DigiAsset Node ONLY (No DigiByte Node)
    if [[ "$DGANODE_ONLY" == true ]]; then
 
        # Display donation dialog
        donationDialog

        # If DigiNode Tools is installed, offer to check for an update
        if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
            
            printf " =============== DIGIASSET NODE ONLY - MAIN MENU =======================\\n\\n"
            # ==============================================================================

            opt1a="Update"
            opt1b=" Check for updates to your DigiAsset Node"

            opt2a="Setup DigiByte Node"
            opt2b=" Upgrade to a full DigiNode"
            
            opt3a="Uninstall"
            opt3b=" Remove DigiAsset Node from your system"




            # Display the information to the user
            UpdateCmd=$(whiptail --title "DigiNode Setup - Main Menu" --menu "\\nAn existing DigiAsset Node was discovered.\\n\\nYou can check for updates to your DigiAsset Node or uninstall it.\\nYou can also upgrade to a full DigiNode.\\n\\nPlease choose an option:\\n\\n" --cancel-button "Exit" "${r}" 80 3 \
            "${opt1a}"  "${opt1b}" \
            "${opt2a}"  "${opt2b}" \
            "${opt3a}"  "${opt3b}" 3>&2 2>&1 1>&3) || \
            { printf "%b %bExit was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; printf "\\n"; digifact_randomize; digifact_display; printf "\\n"; exit; }

            # Set the variable based on if the user chooses
            case ${UpdateCmd} in
                # Install DigiNode Tools
                ${opt1a})
                    printf "%b You selected to UPDATE your DigiAsset Node.\\n" "${INFO}"
                    printf "\\n" 
                    install_digiasset_node_only          
                    ;;
                # Add DigiByte Node,
                ${opt2a})
                    printf "%b You selected to UPGRADE your DigiAsset Node and install a DigiByte Node.\\n" "${INFO}"
                    printf "\\n"
                    if [ "$DGNT_RUN_LOCATION" = "remote" ]; then
                        exec curl -sSL diginode-setup.digibyte.help | bash -s -- --dganodeonly --unattended
                    elif [ "$DGNT_RUN_LOCATION" = "local" ]; then
                        sudo -u $USER_ACCOUNT $DGNT_SETUP_SCRIPT --fulldiginode --unattended
                    fi    
                    printf "\\n"
                    exit
                    ;;
                # Uninstall,
                ${opt3a})
                    printf "%b You selected to UNINSTALL your DigiAsset Node.\\n" "${INFO}"
                    printf "\\n"
                    uninstall_do_now
                    printf "\\n"
                    exit
                    ;;
            esac
            printf "\\n"

        # If DigiNode Tools is not installed), offer to install them
        else
            if whiptail --backtitle "" --title "DigiNode Setup - Main Menu" --yesno "Would you like to setup a DigiAsset Node?\\n\\nYou ran DigiNode Setup with the --dganodeonly flag set. This allows you to setup a DigiAsset Node ONLY without a DigiByte Node.\\n\\nWith a DigiAsset Node you are helping to decentralize and redistribute DigiAsset metadata. By running your own DigiAsset Node, you can get paid in DGB for hosting the DigiAsset metadata of others." "${r}" "${c}"; then

                install_digiasset_node_only

            else
                printf "%b Exiting: You chose not to install a DigiAsset Node.\\n" "${INFO}"
                printf "\\n"
                digifact_randomize
                digifact_display
                printf "\\n"
                exit
            fi
        fi

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

    # Check data drive disk space to ensure there is enough space to download the entire blockchain
    disk_check

    # Check data drive disk space to ensure there is enough space to download the entire blockchain
    disk_ask_lowspace

    # Check if a swap file is needed
    swap_check

    # Ask to change the swap
    swap_ask_change

    # Do swap setup
    swap_do_change


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

        # Ask the user if they want to customize their install
        ask_customize

        # Ask whther to install only DigiByte Core, or DigiAssets Node as well
        menu_first_install

        # Tell the user to remove the microSD card from the Pi if not being used
        rpi_microsd_remove

        # Continue with install upgrade
        install_or_upgrade

    fi

    ### UPGRADE MENU ###

    # If DigiByte Core is already install, display the update menu
    if [[ "${UnattendedUpgrade}" == false ]]; then

        # Display the existing install menu
        menu_existing_install

    fi

    ### UPGRADE MENU ###

    # If DigiByte Core is already install, display the update menu
    if [[ "${UnattendedUpgrade}" == true ]] || [[ "${UnattendedInstall}" == true ]]; then

        # Continue with install upgrade
        install_or_upgrade

    fi

}

install_or_upgrade() {

    # If DigiByte Core is already install, display the update menu
    if [[ "${UnattendedUpgrade}" == false ]]; then

        # Ask to install DigiAssets Node, it is not already installed
        menu_ask_install_digiasset_node

    fi

    ### INSTALL DIGINODE DEPENDENCIES ###

    # Install packages used by the actual software
    printf " =============== Checking: DigiNode dependencies =======================\\n\\n"
    # ==============================================================================
    
    printf "%b Checking for / installing required dependencies for DigiNode software...\\n" "${INFO}"
    # Check again for supported package managers so that we may install dependencies
    package_manager_detect
    local dep_install_list=("${DIGINODE_DEPS[@]}")
    install_dependent_packages "${dep_install_list[@]}"
    unset dep_install_list

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


    ### INSTALL/UPGRADE DIGIBYTE CORE ###

    # If this is a new install, ask if you user wants to setup a testnet or mainnet DigiByte Node
    menu_ask_dgb_network

    # If this is a new install, ask the user if they want to enable or disable UPnP for port forwarding
    menu_ask_upnp

    # Create/update digibyte.conf file
    digibyte_create_conf

    # Install/upgrade DigiByte Core
    digibyte_do_install

    # Create digibyted.service
    digibyte_create_service


    ### INSTALL/UPGRADE DIGINODE TOOLS ###

    # Install DigiNode Tools
    diginode_tools_do_install


    ### INSTALL/UPGRADE DIGIASSETS NODE ###

    # Install/upgrade IPFS
    ipfs_do_install

    # Create IPFS service
    ipfs_create_service

    # Install/upgrade NodeJS
    nodejs_do_install

    # Create or update main.json file with RPC credentials
    digiasset_node_create_settings

    # Install DigiAssets along with IPFS
    digiasset_node_do_install

    # Setup PM2 init service
    digiasset_node_create_pm2_service


    ### CHANGE THE HOSTNAME TO DIGINODE ###

    # Check if the hostname is set to 'diginode'
    hostname_check

    # Ask to change the hostname
    hostname_ask_change


    ### CHANGE HOSTNAME LAST BECAUSE MACHINE IMMEDIATELY NEEDS TO BE REBOOTED ###

    # Change the hostname
    hostname_do_change

    
    ### WRAP UP ###

    # Display closing message
    closing_banner_message

    if [[ "${NewInstall}" == false ]]; then

        # Choose a random DigiFact
        digifact_randomize

        # Display a random DigiFact
        digifact_display

    fi

    # Display donation QR Code
    donation_qrcode

    # Show final messages - Display reboot message (and how to run Status Monitor)
    final_messages

    # Share backup reminder
    backup_reminder

    exit

}

if [[ "$RUN_SETUP" != "NO" ]] ; then
    main "$@"
fi





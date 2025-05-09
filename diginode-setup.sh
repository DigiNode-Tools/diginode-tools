#!/bin/bash
#
#           Name:  DigiNode Setup v0.11.3
#
#        Purpose:  Install and manage a DigiByte Node and DigiAsset Node via the linux command line.
#          
#  Compatibility:  Supports x86_86 or arm64 hardware with Raspberry Pi OS, Ubuntu or Debian 64-bit distros.
#                  A Raspberry Pi with at least 8Gb RAM running Raspberry Pi OS Lite 64-bit is recommended.
#
#         Author:  Olly Stedall [ Bluesky: @olly.st ]
#
#        Website:  https://diginode.tools
#
#        Support:  Telegram - https://t.me/DigiNodeTools
#                  Bluesky  - https://bsky.app/profile/diginode.tools   
#
# -----------------------------------------------------------------------------------------------------

DGNT_VER_LIVE=0.11.3
# Last Updated: 2025-04-22

# Convert to a fixed width string of 9 characters to display in the script
DGNT_VER_LIVE_FW=$(printf "%-9s" "v$DGNT_VER_LIVE")

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# We do not want users to end up with a pagrtially working install, so we exit the script
# instead of continuing the installation with something broken
# set -e

# Play an error beep if it exits with an error, but not if this is sourced from the DigiNode Dashboard script
if [[ "$RUN_SETUP" != "NO" ]] ; then
    trap error_beep exit 1
fi

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

# Dialog result codes
# dialog code values can be set by environment variables, we only override if
# the env var is not set or empty.
: "${DIALOG_OK:=0}"
: "${DIALOG_CANCEL:=1}"
: "${DIALOG_ESC:=255}"

# Set VERBOSE_MODE to YES to get more verbose feedback. Very useful for troubleshooting.
# This can be overridden when needed by the --verbose or --verboseoff flags.
# (Note: The RUN_SETUP condition ensures that the VERBOSE_MODE setting only applies to DigiNode Setup
# and is ignored if running the DigiNode Dashboard script - that has its own VERBOSE_MODE setting.)
if [[ "$RUN_SETUP" != "NO" ]] ; then
    VERBOSE_MODE=false
fi


######## NEW GENERIC BLOCKCHAIN IDENTIFIER VARIABLES #########

# DIGIBYTE VARIABLES

CRYPTO_NAME="DigiByte"
CRYPTO_SYMBOL="DGB"
SETTINGS_LOCATION=$USER_HOME/.digibyte
SETTINGS_FILE=$SETTINGS_LOCATION/diginode.settings
HOSTNAME_MAINNET="diginode"
HOSTNAME_TESTNET="diginode-testnet"


######### IMPORTANT NOTE ###########
# Both the DigiNode Setup and DigiNode Dashboard scripts make use of a setting file
# located at ~/.digibyte/diginode.settings
# If you want to change the default folder locations, you should change the settings in this file.
# (e.g. To store your DigiByte Core data file on an external drive.)
#
# NOTE: This variable sets the default location of the diginode.settings file. 
# There should be no reason to change this, and it is unadvisable to do.
DGNT_SETTINGS_LOCATION=$USER_HOME/.digibyte
DGNT_SETTINGS_FILE=$DGNT_SETTINGS_LOCATION/diginode.settings

# This is the URLs where the install script is hosted. This is used primarily for testing.
DGNT_VERSIONS_URL=versions.diginode.tools    # Used to query TXT record containing compatible OS'es
DGNT_SETUP_OFFICIAL_URL=setup.diginode.tools
DGNT_SETUP_GITHUB_MAIN_URL=https://raw.githubusercontent.com/DigiNode-Tools/diginode-tools/main/diginode-setup.sh
DGNT_SETUP_GITHUB_DEVELOP_URL=https://raw.githubusercontent.com/DigiNode-Tools/diginode-tools/develop/diginode-setup.sh

# This is the Github repo for the DigiAsset Node (this only needs to be changed if you wish to test a new version.)
# The main branch is used by default. The dev branch is installed if the --dgadev flag is used.
DGA_GITHUB_REPO_MAIN="--depth 1 https://github.com/digiassetX/digiasset_node.git"
DGA_GITHUB_REPO_DEV="--branch development https://github.com/digiassetX/digiasset_node.git"

# These are the commands that the user pastes into the terminal to run DigiNode Setup
DGNT_SETUP_OFFICIAL_CMD="curl $DGNT_SETUP_OFFICIAL_URL | bash"

# We clone (or update) the DigiNode git repository during the install. This helps to make sure that we always have the latest version of the relevant files.
DGNT_RELEASE_URL="https://github.com/DigiNode-Tools/diginode-tools.git"

# DigiNode Tools Website URL
DGNT_WEBSITE_URL=https://diginode.tools

# DigiNode.Tools Help URLs
DGBH_URL_INTRO=https://diginode.tools                                           # Link to introduction what a DigiNode is. Shown in welcome box.
DGBH_URL_CUSTOM=https://diginode.tools/faq                                      # Information on customizing your install by editing diginode.settings
DGBH_URL_HARDWARE=https://diginode.tools/build-your-own-raspberry-pi-diginode/  # Advice on what hardware to get
DGBH_URL_USERCHANGE=https://diginode.tools/faq                                  # Advice on why you should change the username
DGBH_URL_HOSTCHANGE=https://diginode.tools/faq                                  # Advice on why you should change the hostname
DGBH_URL_STATICIP=https://diginode.tools/raspberry-pi-setup-guide-step-7/       # Advice on how to set a static IP
DGBH_URL_PORTFWD=https://diginode.tools/raspberry-pi-setup-guide-step-7/        # Advice on how to forward ports with your router
DGBH_URL_ADVANCED=https://diginode.tools/advanced-features/                     # Advanced features


# DigiNode Tools Social Accounts
SOCIAL_BLUESKY_URL="https://bsky.app/profile/diginode.tools"
SOCIAL_BLUESKY_HANDLE="@diginode.tools"
SOCIAL_NOSTR_NPUB=""
SOCIAL_TELEGRAM_URL="https://t.me/DigiNodeTools"

# If update variable isn't specified, set to false
if [ -z "$NewInstall" ]; then
  NewInstall=true
fi

# dialog dimensions: 24 rows and 70 chars width assures to fit on small screens and is known to hold all content.
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
SKIP_CUSTOM_MSG=false
DISPLAY_HELP=false
INSTALL_DGB_RELEASE_TYPE=""
DGNS_UNKNOWN_FLAG=false
UPDATE_TEST=false
SKIP_HASH=false
# Check arguments for the undocumented flags
# --dgndev (-d) will use and install the develop branch of DigiNode Tools (used during development)
for var in "$@"; do
    case "$var" in
        "--reset" ) RESET_MODE=true;;
        "--unattended" ) UNATTENDED_MODE=true;;
        "--dgntdev" ) DGNT_BRANCH_REMOTE="develop";; 
        "--dgntmain" ) DGNT_BRANCH_REMOTE="main";; 
#!!        "--dgadev" ) DGA_BRANCH="development";; 
        "--uninstall" ) UNINSTALL=true;;
        "--skiposcheck" ) SKIP_OS_CHECK=true;;
        "--skippkgupdate" ) SKIP_PKG_UPDATE_CHECK=true;;
        "--verbose" ) VERBOSE_MODE=true;;
        "--verboseoff" ) VERBOSE_MODE=false;;
        "--statusmonitor" ) STATUS_MONITOR=true;;
        "--runlocal" ) DGNT_RUN_LOCATION="local";;
        "--runremote" ) DGNT_RUN_LOCATION="remote";;
        "--skipcustommsg" ) SKIP_CUSTOM_MSG=true;;
        "--dgbpre" ) REQUEST_DGB_RELEASE_TYPE="prerelease";;
        "--dgbnopre" ) REQUEST_DGB_RELEASE_TYPE="release";;
        "--updatetest" ) UPDATE_TEST=true;;
        "--skiphash" ) SKIP_HASH=true;;
        "--help" ) DISPLAY_HELP=true;;
        "-h" ) DISPLAY_HELP=true;;
        # If an unknown flag is used...
        * ) DGNS_UNKNOWN_FLAG=true;;
    esac
done


# Set these values so DigiNode Setup can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_LIGHT_RED='\e[1;31m'
COL_LIGHT_BLUE='\e[0;94m'
COL_LIGHT_CYAN='\e[1;96m'
COL_BOLD_WHITE='\e[1;37m'
COL_LIGHT_YEL='\e[1;33m'
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
txtbwht="$(tput setaf 15)" # Bright White

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

# If this is an unknown flag, warn and quit
if [ $DGNS_UNKNOWN_FLAG = true ]; then # 

    # are we running remotely or locally?
    if [[ "$0" == "bash" ]]; then
        DGNT_RUN_LOCATION="remote"
    else
        DGNT_RUN_LOCATION="local"
    fi

    printf "\\n"
    printf "%b ERROR: Unrecognised flag used: $var\\n" "${WARN}"
    printf "\\n"
    printf "%b For help, enter:\\n" "${INDENT}"
    printf "\\n"
    
    if [ "$DGNT_RUN_LOCATION" = "local" ]; then
        printf "%b$ %bdiginode-setup --help%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
    fi
    if [ "$DGNT_RUN_LOCATION" = "remote" ]; then
        printf "%b $ %bcurl -sSL setup.diginode.tools | bash -s -- --help%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
    fi
    printf "\\n"
    exit
fi

#####################################################################################################
### FUNCTIONS
#####################################################################################################

# Display DigiNode Setup help screen if the --help or -h flags was used
display_help() {
    if [ "$DISPLAY_HELP" = true ]; then
        echo ""
        echo "  ╔═════════════════════════════════════════════════════════╗"
        echo "  ║                                                         ║"
        echo "  ║             ${txtbld}D I G I N O D E   S E T U P${txtrst}   $DGNT_VER_LIVE_FW     ║"
        echo "  ║                                                         ║"
        echo "  ║     Setup and manage your DigiByte & DigiAsset Node     ║"
        echo "  ║                                                         ║"
        echo "  ╚═════════════════════════════════════════════════════════╝" 
        echo ""

        # are we running remotely or locally?
        if [[ "$0" == "bash" ]]; then
            DGNT_RUN_LOCATION="remote"
        else
            DGNT_RUN_LOCATION="local"
        fi

        printf "%b You can use the following flags when running DigiNode Setup:\\n" "${INDENT}"
        printf "\\n"
        printf "%b %b--help%b or %b-h%b    - Display this help screen.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--verbose%b       - Enable verbose mode.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--unattended%b    - Run in unattended mode. No menus or prompts will be displayed.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b                   Include --skipcustommsg to also skip the customization message displayed on first run.\\n" "${INDENT}"
        printf "%b %b--skiposcheck%b   - Skip startup OS check in case of problems with your system. Proceed with caution.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--skippkgupdate%b - Skip package cache update. (Some VPS won't let you update.)\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--skiphash%b      - Skip SHA256 hash verification of install binaries. (Not recommended. Emergency use only.)\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--dgbpre%b        - Install the pre-release version of DigiByte Core, if available.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--dgbnopre%b      - Downgrade from pre-release version of DigiByte Core to latest release.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--dgntdev%b       - Developer Mode: Install the dev branch of DigiNode Tools.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
 #!!       printf "%b %b--dgadev%b        - Developer Mode: Install the dev branch of DigiAsset Node.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b                   WARNING: Developer Mode should only be used for testing and may break your existing setup.\\n" "${INDENT}"
        printf "%b %b--uninstall%b     - Uninstall DigiNode software from your system. DigiByte wallet will not be harmed.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b %b--reset%b         - Reset your DigiNode settings and reinstall your DigiNode software.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
        if [ "$DGNT_RUN_LOCATION" = "local" ]; then
            printf "   Usage: %bdiginode-setup --flag%b   (Replace --flag with the desired flags.)\\n" "${COL_BOLD_WHITE}" "${COL_NC}"
        fi
        if [ "$DGNT_RUN_LOCATION" = "remote" ]; then
            printf "   Usage: %bcurl -sSL setup.diginode.tools | bash -s -- --flag%b   (Replace --flag with the desired flags.)\\n" "${COL_BOLD_WHITE}" "${COL_NC}"
        fi
        printf "\\n"
        printf "%b For more help, visit: $DGBH_URL_ADVANCED\\n" "${INDENT}"
        printf "\\n"
        exit
    fi
}

# This will get the size of the current terminal window
get_term_size() {
    # Get terminal size ('stty' is POSIX and always available).
    # This can't be done reliably across all bash versions in pure bash.
    read -r LINES COLUMNS < <(stty size)
}

# Inform user if Verbose Mode is enabled
is_verbose_mode() {
    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b %bVerbose Mode: Enabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
        printf "%b %bUnattended Mode: Enabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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

# Inform user if DigiByte Core Prerelease version is being requested, or not
is_dgb_prerelease_mode() {
    if [ "$REQUEST_DGB_RELEASE_TYPE" = "prerelease" ]; then
        printf "%b %bDigiByte Core PRE-RELEASE Version Requested%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b   If available, the pre-release version of DigiByte Core will be used.\\n" "${INDENT}"
        printf "\\n"
    fi
    if [ "$REQUEST_DGB_RELEASE_TYPE" = "release" ]; then
        printf "%b %bDigiByte Core DOWNGRADE Requested%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b   If DigiByte Core is currently running a pre-release version,\\n" "${INDENT}"
        printf "%b   it will be downgraded the latest release version.\\n" "${INDENT}"
        printf "\\n"
    fi
}

# Inform user if the --skiphash flasg was used
is_skip_hash() {
    if [ "$SKIP_HASH" = true ]; then
        printf "%b %bSkip SHA256 Hash Requested%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b   Downloaded binaries will not be verified via the SHA256 hash.\\n" "${INDENT}"
        printf "\\n"
    fi
}

# Inform user if the --skiphash flasg was used
is_update_test() {
    if [ "$UPDATE_TEST" = true ]; then
        printf "%b %bDeveloper Mode: Update Test Requested%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b   This mode is strictly for DigiNode development. Please no not use this.\\n" "${INDENT}"
        printf "\\n"
    fi
}

# Inform user if DigiAsset Dev Mode is enable
is_dgadev_mode() {
    if [ "$DGA_BRANCH" = "development" ]; then
        printf "%b %bDigiAsset Node Developer Mode: Enabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
        printf "%b %bReset Mode: Enabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Your DigiNode will be reset. All settings and configuration files\\n" "${INDENT}"
        printf "%b will be deleted and recreated. DigiByte and DigiAssets\\n" "${INDENT}"
        printf "%b software will be reinstalled. Any DigiByte blockchain data or\\n" "${INDENT}"
        printf "%b DigiAsset metadata will also be optionally deleted.\\n" "${INDENT}"
        printf "\\n"
    fi

    # Inform user if Uninstall Mode is enabled
    if [ "$UNINSTALL" = true ]; then
        printf "%b %bUninstall Mode: Enabled%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Your DigiNode will be uninstalled. You will be prompted\\n" "${INDENT}"
        printf "%b which components you wish to remove or keep. Your DigiByte wallet\\n" "${INDENT}"
        printf "%b will not be harmed.\\n" "${INDENT}"
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
        local dgnt_ver_release_query=$(curl -sL https://api.github.com/repos/DigiNode-Tools/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')

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

    # create ~/.digibyte folder if it does not exist
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
    DGB_MAX_CONNECTIONS=150
    SM_AUTO_QUIT=1440
    SM_DISPLAY_BALANCE=YES
    SM_DISPLAY_MAINNET_MEMPOOL=YES
    SM_DISPLAY_TESTNET_MEMPOOL=YES
    SM_MEMPOOL_DISPLAY_TIMEOUT=30
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
    UI_DGB_MAINNET_ENABLE_TOR=YES
    UI_DGB_TESTNET_ENABLE_TOR=YES
    UI_IPFS_ENABLE_TOR=YES
    UI_DO_FULL_INSTALL=YES
    UI_DGB_ENABLE_UPNP=NO
    UI_IPFS_ENABLE_UPNP=NO
    UI_IPFS_SERVER_PROFILE=NO
    UI_DGB_CHAIN=MAINNET
    UI_SETUP_DIGINODE_MOTD=YES

    # SYSTEM VARIABLES
    DGB_INSTALL_LOCATION=$USER_HOME/digibyte
    DNSU_INSTALL_LOCATION=$USER_HOME/dnsu
    IPFS_KUBO_API_URL=http://127.0.0.1:5001/api/v0/
    DGB_PORT_TEST_ENABLED=YES
    IPFS_PORT_TEST_ENABLED=YES
    DONATION_PLEA=YES
    MOTD_STATUS=ASK
    DGB_PRERELEASE=

    # SET UPDATE GROUP - RANDOM NUMBER BETWEEN 1 and 4
    UPDATE_GROUP=$(( 1 + $RANDOM % 4 ))

    # generate unique system ID
    generate_node_uid

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

# If the value of UPDATE_GROUP is not currently a random number between 1 and 4, then set it
if [[ ! "$UPDATE_GROUP" =~ [1234] ]]; then
    str="Assigning random upgrade group..."
    printf "%b %s" "${INFO}" "${str}"
    UPDATE_GROUP=$(( 1 + $RANDOM % 4 ))
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
fi

# If display mempool values are not assigned, assign them to YES
if [ "$SM_DISPLAY_MAINNET_MEMPOOL" != "YES" ] || [ "$SM_DISPLAY_MAINNET_MEMPOOL" != "NO" ]; then
    SM_DISPLAY_MAINNET_MEMPOOL=YES
fi
if [ "$SM_DISPLAY_TESTNET_MEMPOOL" != "YES" ] || [ "$SM_DISPLAY_TESTNET_MEMPOOL" != "NO" ]; then
    SM_DISPLAY_TESTNET_MEMPOOL=YES
fi
if [ "$SM_MEMPOOL_DISPLAY_TIMEOUT" = "" ]; then
    SM_MEMPOOL_DISPLAY_TIMEOUT=30
fi
if [ "$NODE_UID" = "" ]; then
    generate_node_uid
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
# This settings file is used to store variables for DigiNode Setup and DigiNode Dashboard

# DIGINODE.SETTINGS FILE VERSION
DGNT_SETTINGS_FILE_VER=$DGNT_SETTINGS_FILE_VER_NEW
DGNT_SETTINGS_FILE_VER_BRANCH=$DGNT_SETTINGS_FILE_VER_BRANCH_NEW

############################################
####### FOLDER AND FILE LOCATIONS ##########
############################################

# DEFAULT FOLDER AND FILE LOCATIONS
# If you want to change the default location of folders you can edit them here
# Important: Use the USER_HOME variable to identify your home folder location.

# DGNT_SETTINGS_LOCATION=   [This value is set in the header of the setup script. Do not set it here.]
# DGNT_SETTINGS_FILE=       [This value is set in the header of the setup script. Do not set it here.]

# DIGIBYTE CORE BLOCKCHAIN DATA LOCATION:
# You can change this to optionally store the DigiByte blockchain data in a different location
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

# Stop the DigiNode Dashboard automatically if it is left running. The default is 1440 minutes.
# To avoid putting unnecessary strain on your device, it is inadvisable to run DigiNode Dashboard for
# long periods. Enter the number of minutes before it exits automatically, or set to 0 to run indefinitely.
# Note: Running indefinitely is nor reccomended if you frequently lose connection to your node since the
# old dashboards will be left running in the background. It is always reccomnded to set a fixed limit.
# e.g. To stop after 24 hours enter: 1440 
SM_AUTO_QUIT=$SM_AUTO_QUIT

# Choose whether to display the current wallet balance in the DigiNode Dashboard. (Specify either YES or NO.)
# Note: The current wallet balance will only be displayed when (a) this variable is set to YES, and (b) the blockchain 
# has completed syncing, and (c) there are actually funds in the wallet (i.e. the balance is > 0).
SM_DISPLAY_BALANCE=$SM_DISPLAY_BALANCE

# Choose whether to display DigiByte mempool data in the DigiNode Dashboard. (Specify either YES or NO.)
# SM_MEMPOOL_DISPLAY_TIMOUT specifies the number of seconds of there being zero transactions before the
# mempool data is hidden. This ensures that mempool data is only displayed when there is data to be displayed.
# Default value is SM_MEMPOOL_DISPLAY_TIMOUT=30
SM_DISPLAY_MAINNET_MEMPOOL=$SM_DISPLAY_MAINNET_MEMPOOL
SM_DISPLAY_TESTNET_MEMPOOL=$SM_DISPLAY_TESTNET_MEMPOOL
SM_MEMPOOL_DISPLAY_TIMEOUT=$SM_MEMPOOL_DISPLAY_TIMEOUT


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
# The optimal swap size will be calculated to ensure there is ~16Gb total memory (i.e. System RAM + SWAP = ~16Gb).
# e.g. If the system has 8Gb RAM, it will create a 8Gb swap file. Total: 16Gb.
# If there is more than 12Gb RAM available, no swap will be created.
# You can override this by manually entering the desired size in UI_SWAP_SIZE_MB below.
UI_SWAP_SETUP=$UI_SWAP_SETUP

# You can optionally manually enter a desired swap file size here in MB.
# The UI_SWAP_SETUP variable above must be set to YES for this to be used.
# If you leave this value empty, the optimal swap file size will calculated by DigiNode Setup.
# Enter the amount in MB only, without the units. (e.g. 8Gb = 8000 )
UI_SWAP_SIZE_MB=$UI_SWAP_SIZE_MB

# This is where the swap file will be located. You can change this to store it on an external drive
# if desired.
UI_SWAP_FILE=$UI_SWAP_FILE

# Will install regardless of available disk space on the data drive. Use with caution.
UI_DISKSPACE_OVERRIDE=$UI_DISKSPACE_OVERRIDE

# Choose whether to setup Tor
UI_DGB_MAINNET_ENABLE_TOR=$UI_DGB_MAINNET_ENABLE_TOR
UI_DGB_TESTNET_ENABLE_TOR=$UI_DGB_TESTNET_ENABLE_TOR
UI_IPFS_ENABLE_TOR=$UI_IPFS_ENABLE_TOR

# Choose YES to do a FULL DigiNode with both DigiByte and DigiAsset Nodes
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

# Choose which DigiByte Core chain to use. (Set to MAINNET or TESTNET. Default is MAINNET.)
# Alternatively, set to DUALNODE to setup DigiByte Core to run on both mainnet and testnet.
UI_DGB_CHAIN=$UI_DGB_CHAIN

# Choose whther to setup the Custom DigiNode MOTD. The will display the DigiNode logo and instructions each time you login to your DigiNode over SSH.
# If your DigiNode is not running on a dedicated device, you may want to disable this. Enter YES or NO.
UI_SETUP_DIGINODE_MOTD=$UI_SETUP_DIGINODE_MOTD


#############################################
####### SYSTEM VARIABLES ####################
#############################################

# IMPORTANT: DO NOT CHANGE ANY OF THESE VALUES !!!!
#
# THEY ARE CREATED AND SET AUTOMATICALLY BY DigiNode Setup and DigiNode Dashboard.
# Changing them yourself may break your DigiNode.

# This is a unique identifier generated at first install to anonymously identify each DigiNode.
# Do not edit this value or your node may break
NODE_UID=$NODE_UID

# DIGIBYTE NODE LOCATION: (Do not change this value)
# This references a symbolic link that points at the actual install folder. 
# If you are using DigiNode Setup to manage your node there is no reason to change this.
# If you must change the install location, do not edit it here - it may break things. Instead, create a symbolic link 
# called 'digibyte' in your home folder that points to the location of your DigiByte Core install folder.
# Be aware that DigiNode Setup upgrades will likely not work if you do this. The DigiNode Dashboard script will help you create one.
DGB_INSTALL_LOCATION=$DGB_INSTALL_LOCATION

# Do not change this value. If you wish to change the location where the
# blockchain data is stored, use the DGB_DATA_LOCATION variable above.
DGB_SETTINGS_LOCATION=\$USER_HOME/.digibyte

# DIGIBYTE NODE FILES: (Do not change these values)
DGB_CONF_FILE=\$DGB_SETTINGS_LOCATION/digibyte.conf 
DGB_CLI=\$DGB_INSTALL_LOCATION/bin/digibyte-cli
DGB_DAEMON=\$DGB_INSTALL_LOCATION/bin/digibyted

# IPFS NODE LOCATION: (Do not change this value)
IPFS_SETTINGS_LOCATION=\$USER_HOME/.ipfs

# DIGIASSET NODE LOCATION: (Do not change these values)
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
DGB2_SYSTEMD_SERVICE_FILE=/etc/systemd/system/digibyted-testnet.service
DGB2_UPSTART_SERVICE_FILE=/etc/init/digibyted-testnet.conf
IPFS_SYSTEMD_SERVICE_FILE=/etc/systemd/system/ipfs.service
IPFS_UPSTART_SERVICE_FILE=/etc/init/ipfs.conf
PM2_SYSTEMD_SERVICE_FILE=/etc/systemd/system/pm2-$USER_ACCOUNT.service
PM2_UPSTART_SERVICE_FILE=/etc/init/pm2-$USER_ACCOUNT.service

# Store DigiByte Core Installation details:
DGB_INSTALL_DATE="$DGB_INSTALL_DATE"
DGB_UPGRADE_DATE="$DGB_UPGRADE_DATE"
DGB_VER_RELEASE="$DGB_VER_RELEASE"
DGB_VER_PRERELEASE="$DGB_VER_PRERELEASE"
DGB_VER_LOCAL="$DGB_VER_LOCAL"
DGB_VER_LOCAL_CHECK_FREQ="$DGB_VER_LOCAL_CHECK_FREQ"
DGB_PRERELEASE="$DGB_PRERELEASE"
DGB_DUAL_NODE="$DGB_DUAL_NODE"

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

# DIGIBYTE NODE STATUS UPDATER:
DNSU_INSTALL_LOCATION=$DNSU_INSTALL_LOCATION
DNSU_INSTALL_DATE="$DNSU_INSTALL_DATE"
DNSU_UPGRADE_DATE="$DNSU_UPGRADE_DATE"
DNSU_VER_LOCAL="$DNSU_VER_LOCAL"
DNSU_VER_RELEASE="$DNSU_VER_RELEASE"

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

# Store IPFS Kubo installation details:
IPFS_VER_LOCAL="$IPFS_VER_LOCAL"
IPFS_VER_RELEASE="$IPFS_VER_RELEASE"
IPFS_INSTALL_DATE="$IPFS_INSTALL_DATE"
IPFS_UPGRADE_DATE="$IPFS_UPGRADE_DATE"
IPFS_KUBO_API_URL=$IPFS_KUBO_API_URL

# Store Node.js installation details:
NODEJS_VER_LOCAL="$NODEJS_VER_LOCAL"
NODEJS_VER_RELEASE="$NODEJS_VER_RELEASE"
NODEJS_INSTALL_DATE="$NODEJS_INSTALL_DATE"
NODEJS_UPGRADE_DATE="$NODEJS_UPGRADE_DATE"
NODEJS_REPO_ADDED="$NODEJS_REPO_ADDED"

# Timer variables (these control the timers in the DigiNode Dashboard loop)
SAVED_TIME_10SEC="$SAVED_TIME_10SEC"
SAVED_TIME_1MIN="$SAVED_TIME_1MIN"
SAVED_TIME_15MIN="$SAVED_TIME_15MIN"
SAVED_TIME_1DAY="$SAVED_TIME_1DAY"
SAVED_TIME_1WEEK="$SAVED_TIME_1WEEK"
SAVED_TIME_DIGIFACTS="$SAVED_TIME_DIGIFACTS"

# Disk usage variables (updated every 10 seconds)
BOOT_DISKFREE_HR="$BOOT_DISKFREE_HR"
BOOT_DISKFREE_KB="$BOOT_DISKFREE_KB"
BOOT_DISKUSED_HR="$BOOT_DISKUSED_HR"
BOOT_DISKUSED_KB="$BOOT_DISKUSED_KB"
BOOT_DISKUSED_PERC="$BOOT_DISKUSED_PERC"
DGB_DATA_TOTALDISK_KB="$DGB_DATA_TOTALDISK_KB"
DGB_DATA_DISKFREE_HR="$DGB_DATA_DISKFREE_HR"
DGB_DATA_DISKFREE_KB="$DGB_DATA_DISKFREE_KB"
DGB_DATA_DISKUSED_HR="$DGB_DATA_DISKUSED_HR"
DGB_DATA_DISKUSED_KB="$DGB_DATA_DISKUSED_KB"
DGB_DATA_DISKUSED_PERC="$DGB_DATA_DISKUSED_PERC"

DGB_DATA_DISKUSED_MAIN_HR="$DGB_DATA_DISKUSED_MAIN_HR"
DGB_DATA_DISKUSED_MAIN_KB="$DGB_DATA_DISKUSED_MAIN_KB"
DGB_DATA_DISKUSED_MAIN_PERC="$DGB_DATA_DISKUSED_MAIN_PERC"

DGB_DATA_DISKUSED_TEST_HR="$DGB_DATA_DISKUSED_TEST_HR"
DGB_DATA_DISKUSED_TEST_KB="$DGB_DATA_DISKUSED_TEST_KB"
DGB_DATA_DISKUSED_TEST_PERC="$DGB_DATA_DISKUSED_TEST_PERC"

DGB_DATA_DISKUSED_REGTEST_HR="$DGB_DATA_DISKUSED_REGTEST_HR"
DGB_DATA_DISKUSED_REGTEST_KB="$DGB_DATA_DISKUSED_REGTEST_KB"
DGB_DATA_DISKUSED_REGTEST_PERC="$DGB_DATA_DISKUSED_REGTEST_PERC"

DGB_DATA_DISKUSED_SIGNET_HR="$DGB_DATA_DISKUSED_SIGNET_HR"
DGB_DATA_DISKUSED_SIGNET_KB="$DGB_DATA_DISKUSED_SIGNET_KB"
DGB_DATA_DISKUSED_SIGNET_PERC="$DGB_DATA_DISKUSED_SIGNET_PERC"

IPFS_DATA_DISKUSED_HR="$IPFS_DATA_DISKUSED_HR"
IPFS_DATA_DISKUSED_KB="$IPFS_DATA_DISKUSED_KB"
IPFS_DATA_DISKUSED_PERC="$IPFS_DATA_DISKUSED_PERC"

# IP addresses (external IPs only rechecked once every 15 minutes)
IP4_INTERNAL="$IP4_INTERNAL"
IP4_EXTERNAL="$IP4_EXTERNAL"
IP6_LINKLOCAL="$IP6_LINKLOCAL"
IP6_ULA="$IP6_ULA"
IP6_GUA="$IP6_GUA"
IP6_EXTERNAL="$IP6_EXTERNAL"

# This records when DigiNode was last backed up to a USB stick
DGB_WALLET_BACKUP_DATE_ON_DIGINODE="$DGB_WALLET_BACKUP_DATE_ON_DIGINODE"
DGA_CONFIG_BACKUP_DATE_ON_DIGINODE="$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE"

# Stores when a DigiByte Core MAINNET port test last ran successfully.
# If you wish to re-enable the port test, change the DGB_MAINNET_PORT_TEST_ENABLED variable to YES.
DGB_MAINNET_PORT_TEST_ENABLED="$DGB_MAINNET_PORT_TEST_ENABLED"
DGB_MAINNET_PORT_FWD_STATUS="$DGB_MAINNET_PORT_FWD_STATUS"
DGB_MAINNET_PORT_TEST_PASS_DATE="$DGB_MAINNET_PORT_TEST_PASS_DATE"
DGB_MAINNET_PORT_TEST_EXTERNAL_IP="$DGB_MAINNET_PORT_TEST_EXTERNAL_IP"
DGB_MAINNET_PORT_NUMBER_SAVED="$DGB_MAINNET_PORT_NUMBER_SAVED"

# Stores when a DigiByte Core TESTNET port test last ran successfully for the testnet node
# If you wish to re-enable the port test, change the DGB_TESTNET_PORT_TEST_ENABLED variable to YES.
DGB_TESTNET_PORT_TEST_ENABLED="$DGB_TESTNET_PORT_TEST_ENABLED"
DGB_TESTNET_PORT_FWD_STATUS="$DGB_TESTNET_PORT_FWD_STATUS"
DGB_TESTNET_PORT_TEST_PASS_DATE="$DGB_TESTNET_PORT_TEST_PASS_DATE"
DGB_TESTNET_PORT_TEST_EXTERNAL_IP="$DGB_TESTNET_PORT_TEST_EXTERNAL_IP"
DGB_TESTNET_PORT_NUMBER_SAVED="$DGB_TESTNET_PORT_NUMBER_SAVED"

# Stores when an IPFS port test last ran successfully.
# If you wish to re-enable the IPFS port test, change the IPFS_PORT_TEST_ENABLED variable to YES.
IPFS_PORT_TEST_ENABLED="$IPFS_PORT_TEST_ENABLED"
IPFS_PORT_FWD_STATUS="$IPFS_PORT_FWD_STATUS"
IPFS_PORT_TEST_PASS_DATE="$IPFS_PORT_TEST_PASS_DATE"
IPFS_PORT_TEST_EXTERNAL_IP="$IPFS_PORT_TEST_EXTERNAL_IP"
IPFS_PORT_NUMBER_SAVED="$IPFS_PORT_NUMBER_SAVED"

# DigiByte MAINNET Node ID on digibyteseed.com
DGB_MAINNET_NODE_ID="$DGB_MAINNET_NODE_ID"
DGB_MAINNET_NODE_IP="$DGB_MAINNET_NODE_IP"
DGB_MAINNET_NODE_PORT="$DGB_MAINNET_NODE_PORT"

# DigiByte TESTNET Node ID on digibyteseed.com
DGB_TESTNET_NODE_ID="$DGB_TESTNET_NODE_ID"
DGB_TESTNET_NODE_IP="$DGB_TESTNET_NODE_IP"
DGB_TESTNET_NODE_PORT="$DGB_TESTNET_NODE_PORT"

# Do not display donation plea more than once every 15 mins (value should be YES or WAIT15)
DONATION_PLEA="$DONATION_PLEA"

# Store DigiByte blockchain sync progress
DGB_BLOCKSYNC_VALUE="$DGB_BLOCKSYNC_VALUE"
DGB2_BLOCKSYNC_VALUE="$DGB2_BLOCKSYNC_VALUE"

# User has chosen to enable/disable the DigiNode custom MOTD. This is set to ENABLED or DISABLED automatically by the script.
MOTD_STATUS="$MOTD_STATUS"

# Store number of available system updates so the script only checks this occasionally
SYSTEM_REGULAR_UPDATES="$SYSTEM_REGULAR_UPDATES"
SYSTEM_SECURITY_UPDATES="$SYSTEM_SECURITY_UPDATES"

# This number assigns this DigiNode to a random group for installing updates. Do not change it. 
# Using different groups allows the rollout of major updates to be staggered.
UPDATE_GROUP="$UPDATE_GROUP"

# This keeps track of wther the user has agreed to the disclaimer.
DIGINODE_DISCLAIMER="ASK"

# Tor Config
INSTALLED_TOR_GPG_KEY=$INSTALLED_TOR_GPG_KEY


###############################################
####### STATE VARIABLES #######################
###############################################

# These variables are periodically updated when there is a new release of DigiNode Tools
# These are used to display the current state of the DigiByte blockchain
# There is no need to change these values yourself. They will be updated automatically.

# These variables stores the approximate amount of space required to download the entire DigiByte blockchain
# This is used during the disk space check to ensure there is enough space on the drive to download the DigiByte blockchain.
# (Format date like so - e.g. "January 2023"). This is the approximate date when these values were updated.
DGB_DATA_REQUIRED_DATE="April 2025" 
DGB_DATA_REQUIRED_HR="55Gb"
DGB_DATA_REQUIRED_KB="55000000"

EOF

}

# Import the diginode.settings file it it exists
# check if diginode.settings file exists
diginode_tools_import_settings() {

local display_output="$1"

if [ -f "$DGNT_SETTINGS_FILE" ] && [ "$IS_DGNT_SETTINGS_FILE_NEW" != "YES" ] && [ "$display_output" = "silent" ]; then

    source $DGNT_SETTINGS_FILE

elif [ -f "$DGNT_SETTINGS_FILE" ] && [ "$IS_DGNT_SETTINGS_FILE_NEW" != "YES" ]; then

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
            local dgnt_ver_release_query=$(curl -sL https://api.github.com/repos/DigiNode-Tools/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')

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
            if [ "$DGNT_SETUP_OFFICIAL_URL" = "" ]; then
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
                DGNT_SETUP_URL=$DGNT_SETUP_OFFICIAL_URL
            fi
    fi
}


# These are only set after the intitial OS check since they cause an error on MacOS
set_sys_variables() {

    local str

    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b Looking up system variables...\\n" "${INFO}"
        echo ""
        echo "     ---Verbose Mode-----------"
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
        printf "%b Total RAM: ${RAMTOTAL_HR}b ( KB: ${RAMTOTAL_KB} )\\n" "${INDENT}"
        if [ "$SWAPTOTAL_HR" = "0B" ]; then
            printf "%b Total SWAP: none\\n" "${INDENT}"
        else
            printf "%b Total SWAP: ${SWAPTOTAL_HR}b ( KB: ${SWAPTOTAL_KB} )\\n" "${INDENT}"
        fi
    fi

    BOOT_DISKTOTAL_HR=$(df . -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    BOOT_DISKTOTAL_KB=$(df . --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    DGB_DATA_DISKTOTAL_HR=$(df $DGB_DATA_LOCATION -h --si --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    DGB_DATA_DISKTOTAL_KB=$(df $DGB_DATA_LOCATION --output=size | tail -n +2 | sed 's/^[ \t]*//;s/[ \t]*$//')

    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b Total Disk Space: ${BOOT_DISKTOTAL_HR}b ( KB: ${BOOT_DISKTOTAL_KB} )\\n" "${INDENT}"
    fi

 #   # No need to update the disk usage variables if running the DigiNode Dashboard, as it does it itself
 #   if [[ "$RUN_SETUP" != "NO" ]] ; then

        # Get internal IP address
        IP4_INTERNAL=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
        if [ -f "$DGNT_SETTINGS_FILE" ]; then
            sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"$IP4_INTERNAL\"|" $DGNT_SETTINGS_FILE
        fi

        # Lookup disk usage, and update diginode.settings if present
        update_disk_usage

        if [[ $VERBOSE_MODE = true ]]; then
            printf "%b Used Boot Disk Space: ${BOOT_DISKUSED_HR}b ( ${BOOT_DISKUSED_PERC}% )\\n" "${INDENT}"
            printf "%b Free Boot Disk Space: ${BOOT_DISKFREE_HR}b ( KB: ${BOOT_DISKFREE_KB} )\\n" "${INDENT}"
            printf "%b Used Data Disk Space: ${DGB_DATA_DISKUSED_HR}b ( ${DGB_DATA_DISKUSED_PERC}% )\\n" "${INDENT}"
            printf "%b Free Data Disk Space: ${DGB_DATA_DISKFREE_HR}b ( KB: ${DGB_DATA_DISKFREE_KB} )\\n" "${INDENT}"
            echo "     --------------------------"
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

generate_node_uid() {
    local crypto_symbol node_uid_timestamp random_id machine_id
    local node_uid_combined fallback_id fallback_file
    local decoded_uid stored_machine_id

    crypto_symbol="$CRYPTO_SYMBOL"
    fallback_file="$USER_HOME/.fallback_machine_id"

    # Determine machine_id
    if [[ -r /etc/machine-id ]]; then
        machine_id=$(cat /etc/machine-id)
    else
        # Check if fallback file exists and is valid (32 hex characters)
        if [[ -r "$fallback_file" ]]; then
            fallback_id=$(<"$fallback_file")
            if [[ "$fallback_id" =~ ^[a-f0-9]{32}$ ]]; then
                machine_id="$fallback_id"
            else
                printf "%b Invalid fallback machine ID detected. Regenerating...\n" "${WARN}"
                fallback_id=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
                echo "$fallback_id" > "$fallback_file"
                chmod 600 "$fallback_file"
                machine_id="$fallback_id"
            fi
        else
            # Generate and store a new fallback ID
            printf "%b No machine-id detected. Generating fallback machine ID...\n" "${WARN}"
            fallback_id=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
            echo "$fallback_id" > "$fallback_file"
            chmod 600 "$fallback_file"
            machine_id="$fallback_id"
        fi
    fi

    # Check existing NODE_UID
    if [[ -n "$NODE_UID" ]]; then
        # Decode Base64 URL
        decoded_uid=$(echo "$NODE_UID" | tr '_-' '/+' | base64 --decode 2>/dev/null)

        if [[ "$decoded_uid" =~ ^([A-Z]+)_([0-9]+)_([a-f0-9]{6})_([a-f0-9]+)$ ]]; then
            stored_machine_id="${BASH_REMATCH[4]}"
            if [[ "$stored_machine_id" == "$machine_id" ]]; then
                if [ $VERBOSE_MODE = true ]; then
                    printf "%b NODE_UID is valid and matches current machine-id.\n" "${TICK}"
                fi
                return 0
            else
                printf "%b NODE_UID machine-id mismatch — regenerating...\n" "${WARN}"
            fi
        else
            printf "%b NODE_UID format is invalid — regenerating...\n" "${WARN}"
        fi
    fi

    # Generate new NODE_UID
    node_uid_timestamp=$(date +%s)
    random_id=$(openssl rand -hex 3)  # 6-character random hex
    node_uid_combined="${crypto_symbol}_${node_uid_timestamp}_${random_id}_${machine_id}"

    # Base64 URL encode
    NODE_UID=$(echo -n "$node_uid_combined" | base64 | tr '+/' '-_' | tr -d '=')

    # Save to diginode.settings
    if [[ -f "$DGNT_SETTINGS_FILE" ]]; then
        sed -i -e "/^NODE_UID=/s|.*|NODE_UID=$NODE_UID|" "$DGNT_SETTINGS_FILE"
    fi

    printf "%b Generated new NODE_UID: %s\n" "${INFO}" "$NODE_UID"
}


# OLD VERSION_CODENAME

# Lookup disk usage, and store in diginode.settings if present
update_disk_usage() {

        # Update current disk usage variables
        BOOT_DISKUSED_HR=$(df $USER_HOME -h --output=used | tail -n +2)
        BOOT_DISKUSED_KB=$(df $USER_HOME --output=used | tail -n +2)
        BOOT_DISKUSED_PERC=$(df $USER_HOME --output=pcent | tail -n +2)
        BOOT_DISKFREE_HR=$(df $USER_HOME -h --si --output=avail | tail -n +2)
        BOOT_DISKFREE_KB=$(df $USER_HOME --output=avail | tail -n +2)

        # Update current data disk usage variables
        DGB_DATA_TOTALDISK_KB=$(df $DGB_DATA_LOCATION | tail -1 | awk '{print $2}')
        DGB_DATA_DISKUSED_HR=$(df $DGB_DATA_LOCATION -h --output=used | tail -n +2)
        DGB_DATA_DISKUSED_KB=$(df $DGB_DATA_LOCATION --output=used | tail -n +2)
        DGB_DATA_DISKUSED_PERC=$(df $DGB_DATA_LOCATION --output=pcent | tail -n +2)
        DGB_DATA_DISKFREE_HR=$(df $DGB_DATA_LOCATION -h --si --output=avail | tail -n +2)
        DGB_DATA_DISKFREE_KB=$(df $DGB_DATA_LOCATION --output=avail | tail -n +2)

        # DigiByte mainnet disk used
        if [ -d "$DGB_DATA_LOCATION" ]; then
            DGB_DATA_DISKUSED_MAIN_HR=$(du -sh --exclude=testnet4 --exclude=regtest --exclude=signet $DGB_DATA_LOCATION | awk '{print $1}')
            DGB_DATA_DISKUSED_MAIN_KB=$(du -sk --exclude=testnet4 --exclude=regtest --exclude=signet $DGB_DATA_LOCATION | awk '{print $1}')
            DGB_DATA_DISKUSED_MAIN_PERC=$(echo "scale=2; ($DGB_DATA_DISKUSED_MAIN_KB*100/$DGB_DATA_TOTALDISK_KB)" | bc)
        else
            DGB_DATA_DISKUSED_MAIN_HR=""
            DGB_DATA_DISKUSED_MAIN_KB=""
            DGB_DATA_DISKUSED_MAIN_PERC=""
        fi

        # DigiByte testnet disk used
        if [ -d "$DGB_DATA_LOCATION/testnet4" ]; then
            DGB_DATA_DISKUSED_TEST_HR=$(du -sh $DGB_DATA_LOCATION/testnet4 | awk '{print $1}')
            DGB_DATA_DISKUSED_TEST_KB=$(du -sk $DGB_DATA_LOCATION/testnet4 | awk '{print $1}')
            DGB_DATA_DISKUSED_TEST_PERC=$(echo "scale=2; ($DGB_DATA_DISKUSED_TEST_KB*100/$DGB_DATA_TOTALDISK_KB)" | bc)
        else
            DGB_DATA_DISKUSED_TEST_HR=""
            DGB_DATA_DISKUSED_TEST_KB=""
            DGB_DATA_DISKUSED_TEST_PERC=""
        fi

        # DigiByte regtest disk used
        if [ -d "$DGB_DATA_LOCATION/regtest" ]; then
            DGB_DATA_DISKUSED_REGTEST_HR=$(du -sh $DGB_DATA_LOCATION/regtest | awk '{print $1}')
            DGB_DATA_DISKUSED_REGTEST_KB=$(du -sk $DGB_DATA_LOCATION/regtest | awk '{print $1}')
            DGB_DATA_DISKUSED_REGTEST_PERC=$(echo "scale=2; ($DGB_DATA_DISKUSED_REGTEST_KB*100/$DGB_DATA_TOTALDISK_KB)" | bc)
        else
            DGB_DATA_DISKUSED_REGTEST_HR=""
            DGB_DATA_DISKUSED_REGTEST_KB=""
            DGB_DATA_DISKUSED_REGTEST_PERC=""
        fi

        # DigiByte signet disk used
        if [ -d "$DGB_DATA_LOCATION/signet" ]; then
            DGB_DATA_DISKUSED_SIGNET_HR=$(du -sh $DGB_DATA_LOCATION/signet | awk '{print $1}')
            DGB_DATA_DISKUSED_SIGNET_KB=$(du -sk $DGB_DATA_LOCATION/signet | awk '{print $1}')
            DGB_DATA_DISKUSED_SIGNET_PERC=$(echo "scale=2; ($DGB_DATA_DISKUSED_SIGNET_KB*100/$DGB_DATA_TOTALDISK_KB)" | bc)
        else
            DGB_DATA_DISKUSED_SIGNET_HR=""
            DGB_DATA_DISKUSED_SIGNET_KB=""
            DGB_DATA_DISKUSED_SIGNET_PERC=""
        fi

        # IPFS disk used
        if [ -d "$IPFS_SETTINGS_LOCATION" ]; then
            IPFS_DATA_DISKUSED_HR=$(du -sh $USER_HOME/.ipfs | awk '{print $1}')
            IPFS_DATA_DISKUSED_KB=$(du -sk $USER_HOME/.ipfs | awk '{print $1}')
            IPFS_DATA_DISKUSED_PERC=$(echo "scale=2; ($IPFS_DATA_DISKUSED_KB*100/$DGB_DATA_TOTALDISK_KB)" | bc)
        else
            IPFS_DATA_DISKUSED_HR=""
            IPFS_DATA_DISKUSED_KB=""
            IPFS_DATA_DISKUSED_PERC=""
        fi

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
            sed -i -e "/^BOOT_DISKFREE_HR=/s|.*|BOOT_DISKFREE_HR=\"$BOOT_DISKFREE_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKFREE_KB=/s|.*|BOOT_DISKFREE_KB=\"$BOOT_DISKFREE_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKUSED_HR=/s|.*|BOOT_DISKUSED_HR=\"$BOOT_DISKUSED_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKUSED_KB=/s|.*|BOOT_DISKUSED_KB=\"$BOOT_DISKUSED_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^BOOT_DISKUSED_PERC=/s|.*|BOOT_DISKUSED_PERC=\"$BOOT_DISKUSED_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_TOTALDISK_KB=/s|.*|DGB_DATA_TOTALDISK_KB=\"$DGB_DATA_TOTALDISK_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKFREE_HR=/s|.*|DGB_DATA_DISKFREE_HR=\"$DGB_DATA_DISKFREE_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKFREE_KB=/s|.*|DGB_DATA_DISKFREE_KB=\"$DGB_DATA_DISKFREE_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_HR=/s|.*|DGB_DATA_DISKUSED_HR=\"$DGB_DATA_DISKUSED_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_KB=/s|.*|DGB_DATA_DISKUSED_KB=\"$DGB_DATA_DISKUSED_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_PERC=/s|.*|DGB_DATA_DISKUSED_PERC=\"$DGB_DATA_DISKUSED_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_MAIN_HR=/s|.*|DGB_DATA_DISKUSED_MAIN_HR=\"$DGB_DATA_DISKUSED_MAIN_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_MAIN_KB=/s|.*|DGB_DATA_DISKUSED_MAIN_KB=\"$DGB_DATA_DISKUSED_MAIN_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_MAIN_PERC=/s|.*|DGB_DATA_DISKUSED_MAIN_PERC=\"$DGB_DATA_DISKUSED_MAIN_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_TEST_HR=/s|.*|DGB_DATA_DISKUSED_TEST_HR=\"$DGB_DATA_DISKUSED_TEST_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_TEST_KB=/s|.*|DGB_DATA_DISKUSED_TEST_KB=\"$DGB_DATA_DISKUSED_TEST_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_TEST_PERC=/s|.*|DGB_DATA_DISKUSED_TEST_PERC=\"$DGB_DATA_DISKUSED_TEST_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_REGTEST_HR=/s|.*|DGB_DATA_DISKUSED_REGTEST_HR=\"$DGB_DATA_DISKUSED_REGTEST_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_REGTEST_KB=/s|.*|DGB_DATA_DISKUSED_REGTEST_KB=\"$DGB_DATA_DISKUSED_REGTEST_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_REGTEST_PERC=/s|.*|DGB_DATA_DISKUSED_REGTEST_PERC=\"$DGB_DATA_DISKUSED_REGTEST_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_SIGNET_HR=/s|.*|DGB_DATA_DISKUSED_SIGNET_HR=\"$DGB_DATA_DISKUSED_SIGNET_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_SIGNET_KB=/s|.*|DGB_DATA_DISKUSED_SIGNET_KB=\"$DGB_DATA_DISKUSED_SIGNET_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGB_DATA_DISKUSED_SIGNET_PERC=/s|.*|DGB_DATA_DISKUSED_SIGNET_PERC=\"$DGB_DATA_DISKUSED_SIGNET_PERC\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^IPFS_DATA_DISKUSED_HR=/s|.*|IPFS_DATA_DISKUSED_HR=\"$IPFS_DATA_DISKUSED_HR\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^IPFS_DATA_DISKUSED_KB=/s|.*|IPFS_DATA_DISKUSED_KB=\"$IPFS_DATA_DISKUSED_KB\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^IPFS_DATA_DISKUSED_PERC=/s|.*|IPFS_DATA_DISKUSED_PERC=\"$IPFS_DATA_DISKUSED_PERC\"|" $DGNT_SETTINGS_FILE
        fi

}



# Scrape the contents of digibyte.conf and store the sections in variables
scrape_digibyte_conf() {

if [ -f "$DGB_CONF_FILE" ]; then

    # Define the section name to search for
    sectionMain="main"
    sectionTest="test"
    sectionRegtest="regtest"
    sectionRegtest="signet"

    # Initialize an associative array to store key-value pairs
    declare -A global_data
    declare -A main_data
    declare -A test_data
    declare -A regtest_data
    declare -A signet_data

    # Set a flag to indicate whether we are inside the desired section
    inside_main_section=false
    inside_test_section=false
    inside_regtest_section=false
    inside_signet_section=false

    # Read the file line by line
    while IFS= read -r line; do
        # Remove leading and trailing whitespace from the line
        line="${line##*([[:space:]])}"
        line="${line%%*([[:space:]])}"

        # Check if the line is not empty, does not start with #, and is not a section header
        if [[ ! -z "$line" && "$line" != \#* && ! "$line" =~ ^\[([^]]+)\]$ ]]; then
            # Check if we are inside a section
            if [[ $inside_main_section == false && $inside_test_section == false && $inside_regtest_section == false && $inside_signet_section == false ]]; then
                # Check if the line contains an '=' character
                if [[ "$line" =~ = ]]; then
                    # Split the line into key and value
                    key="${line%%=*}"
                    value="${line#*=}"
                    # Trim leading and trailing whitespace from the value
                    value="${value##*([[:space:]])}"
                    value="${value%%*([[:space:]])}"
                    # Store the key-value pair in the associative array
                    global_data["$key"]="$value"
                fi
            elif [[ $inside_main_section == true ]]; then
                # Check if the line contains an '=' character
                if [[ "$line" =~ = ]]; then
                    # Split the line into key and value
                    key="${line%%=*}"
                    value="${line#*=}"
                    # Trim leading and trailing whitespace from the value
                    value="${value##*([[:space:]])}"
                    value="${value%%*([[:space:]])}"
                    # Store the key-value pair in the associative array
                    main_data["$key"]="$value"
                fi
            elif [[ $inside_test_section == true ]]; then
                # Check if the line contains an '=' character
                if [[ "$line" =~ = ]]; then
                    # Split the line into key and value
                    key="${line%%=*}"
                    value="${line#*=}"
                    # Trim leading and trailing whitespace from the value
                    value="${value##*([[:space:]])}"
                    value="${value%%*([[:space:]])}"
                    # Store the key-value pair in the associative array
                    test_data["$key"]="$value"
                fi
            elif [[ $inside_regtest_section == true ]]; then
                # Check if the line contains an '=' character
                if [[ "$line" =~ = ]]; then
                    # Split the line into key and value
                    key="${line%%=*}"
                    value="${line#*=}"
                    # Trim leading and trailing whitespace from the value
                    value="${value##*([[:space:]])}"
                    value="${value%%*([[:space:]])}"
                    # Store the key-value pair in the associative array
                    regtest_data["$key"]="$value"
                fi
            elif [[ $inside_signet_section == true ]]; then
                # Check if the line contains an '=' character
                if [[ "$line" =~ = ]]; then
                    # Split the line into key and value
                    key="${line%%=*}"
                    value="${line#*=}"
                    # Trim leading and trailing whitespace from the value
                    value="${value##*([[:space:]])}"
                    value="${value%%*([[:space:]])}"
                    # Store the key-value pair in the associative array
                    signet_data["$key"]="$value"
                fi
            fi
        elif [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            # Check if the section matches the desired section
            if [[ "${BASH_REMATCH[1]}" == "$sectionMain" ]]; then
                inside_main_section=true
                inside_test_section=false
                inside_regtest_section=false
                inside_signet_section=false
            elif [[ "${BASH_REMATCH[1]}" == "$sectionTest" ]]; then
                inside_test_section=true
                inside_main_section=false
                inside_regtest_section=false
                inside_signet_section=false
            elif [[ "${BASH_REMATCH[1]}" == "$sectionRegtest" ]]; then
                inside_regtest_section=true
                inside_main_section=false
                inside_test_section=false
                inside_signet_section=false
            elif [[ "${BASH_REMATCH[1]}" == "$sectionSignet" ]]; then
                inside_signet_section=true
                inside_regtest_section=false
                inside_main_section=false
                inside_test_section=false
            else
                inside_main_section=false
                inside_test_section=false
                inside_regtest_section=false
                inside_signet_section=false
            fi
        fi
    done < $DGB_CONF_FILE

    # Store the key-value pairs for Global
    DIGIBYTE_CONFIG_GLOBAL=$(
    echo -e "# Global key value pairs:"
    for key in "${!global_data[@]}"; do
        echo "$key=${global_data[$key]}"
    done
    )

    # Print the key-value pairs for Main
    DIGIBYTE_CONFIG_MAIN=$(
    echo -e "# Main Section key value pairs:"
    for key in "${!main_data[@]}"; do
        echo "$key=${main_data[$key]}"
    done
    )

    # Print the key-value pairs for Test
    DIGIBYTE_CONFIG_TEST=$(
    echo -e "# Test Section key value pairs:"
    for key in "${!test_data[@]}"; do
        echo "$key=${test_data[$key]}"
    done
    )

    # Print the key-value pairs for Regtest
    DIGIBYTE_CONFIG_REGTEST=$(
    echo -e "# Regtest Section key value pairs:"
    for key in "${!regtest_data[@]}"; do
        echo "$key=${regtest_data[$key]}"
    done
    )

    # Print the key-value pairs for Regtest
    DIGIBYTE_CONFIG_SIGNET=$(
    echo -e "# Signet Section key value pairs:"
    for key in "${!signet_data[@]}"; do
        echo "$key=${signet_data[$key]}"
    done
    )

fi

}

# Calculate the recommeded dbcache value based on the system RAM
set_dbcache_value() {

        # Increase dbcache size if there is more than ~7Gb of RAM (Default: 450)
        # Initial sync times are significantly faster with a larger dbcache.
        if [ "$RAMTOTAL_KB" -ge "12582912" ]; then
            str="System RAM exceeds 12GB. Setting dbcache to 2Gb..."
            printf "%b %s" "${INFO}" "${str}"
            set_dbcache=2048
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$RAMTOTAL_KB" -ge "7340032" ]; then
            str="System RAM exceeds 7GB. Setting dbcache to 1Gb..."
            printf "%b %s" "${INFO}" "${str}"
            set_dbcache=1024
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            set_dbcache=450
        fi

}


# Create digibyte.config file if it does not already exist
create_digibyte_conf() {

    local str
    local reset_digibyte_conf


    # If we are in reset mode, ask the user if they want to reinstall DigiByte Core
    if [ "$RESET_MODE" = true ] && [ -f "$DGB_CONF_FILE" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --title "Reset Mode" --yesno "\n\Z4Do you want to re-create your digibyte.conf file?\Z0\n\nNote: This will delete your current DigiByte Core configuration file and re-create with default settings. Any customisations will be lost. Your DigiByte wallet will not be affected." 11 "${c}"; then
            reset_digibyte_conf=true
        else
            reset_digibyte_conf=false
        fi
    fi

    #Display section header
    if [ -f "$DGB_CONF_FILE" ] && [ "$RESET_MODE" = true ] && [ "$reset_digibyte_conf" = true ]; then
        printf " =============== Reset: digibyte.conf ==============================\\n\\n"
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


    # If the digibyte.conf file already exists, check if it needs upgrading to add [Sections]
    if [ -f "$DGB_CONF_FILE" ]; then

        # Upgrade digibyte.conf with the [main], [test], [regtest] and [signet] sections which are new in DigiByte v8
        # IMPORTANT: These sections must be preceded by a line that starts: # [Sections]
        # The sections will be automatically appended to the existing digibyte.conf if they do not already exist.

        # Fix [Sections] header if it already exists, in case it has been entered wrong
        # Make sure it starts with a # and only first letter is capitalized: # [Sections]
        # Also checks the user has spelt it "sections" and not "section" 
        if $(grep -q ^"# \[sections\]" $DGB_CONF_FILE); then
            sed -i -e "/^# \[sections\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        elif $(grep -q ^"# \[SECTIONS\]" $DGB_CONF_FILE); then
            sed -i -e "/^# \[SECTIONS\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[sections\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[sections\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[SECTIONS\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[SECTIONS\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        elif $(grep -q ^"# \[section\]" $DGB_CONF_FILE); then
            sed -i -e "/^# \[section\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        elif $(grep -q ^"# \[SECTION\]" $DGB_CONF_FILE); then
            sed -i -e "/^# \[SECTION\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[section\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[section\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[SECTION\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[SECTION\]/s|.*|# \[Sections\]|" $DGB_CONF_FILE
        fi

        # Also fix [test] to make sure it is not [testnet], [TESTNET] or [TEST]
        if $(grep -q ^"\[testnet\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[testnet\]/s|.*|# \[test\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[TESTNET\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[TESTNET\]/s|.*|# \[test\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[TEST\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[TEST\]/s|.*|# \[test\]|" $DGB_CONF_FILE
        fi

        # Also fix [main] to make sure it is not [mainnet], [mainet], [MAINNET], [MAINET] or [MAIN]
        if $(grep -q ^"\[mainnet\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[mainnet\]/s|.*|# \[main\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[mainet\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[mainet\]/s|.*|# \[main\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[MAINNET\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[MAINNET\]/s|.*|# \[main\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[MAINET\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[MAINET\]/s|.*|# \[main\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[MAIN\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[MAIN\]/s|.*|# \[main\]|" $DGB_CONF_FILE
        fi

        # Also fix [regtest] to make sure it is not [Regtest] or [REGTEST]
        if $(grep -q ^"\[Regtest\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[Regtest\]/s|.*|# \[regtest\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[REGTEST\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[REGTEST\]/s|.*|# \[regtest\]|" $DGB_CONF_FILE
        fi

        # Also fix [signet] to make sure it is not [Signet] or [SIGNET]
        if $(grep -q ^"\[Signet\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[Signet\]/s|.*|# \[signet\]|" $DGB_CONF_FILE
        elif $(grep -q ^"\[SIGNET\]" $DGB_CONF_FILE); then
            sed -i -e "/^\[SIGNET\]/s|.*|# \[signet\]|" $DGB_CONF_FILE
        fi

        str="Does digibyte.conf have the required DigiByte v8 sections? ..."
        printf "%b %s" "${INFO}" "${str}"
        if $(grep -q ^"# \[Sections\]" $DGB_CONF_FILE) && $(grep -q ^"\[test\]" $DGB_CONF_FILE) && $(grep -q ^"\[main\]" $DGB_CONF_FILE) && $(grep -q ^"\[regtest\]" $DGB_CONF_FILE) && $(grep -q ^"\[signet\]" $DGB_CONF_FILE); then
            printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"
        elif $(grep -q ^"# \[Sections\]" $DGB_CONF_FILE) || $(grep -q ^"\[test\]" $DGB_CONF_FILE) || $(grep -q ^"\[main\]" $DGB_CONF_FILE) || $(grep -q ^"\[regtest\]" $DGB_CONF_FILE) && $(grep -q ^"\[signet\]" $DGB_CONF_FILE); then
            printf "%b%b %s No!\\n" "${OVER}" "${CROSS}" "${str}"

            # If we are NOT in unattended mode, ask the user if they want to delete and recreate digibyte.conf, since the script is unable to upgrade it automatically
            if [ "$UNATTENDED_MODE" == false ]; then

                if dialog --no-shadow --keep-tite --colors --backtitle "digibyte.conf must be upgraded!" --title "digibyte.conf must be upgraded!" --yesno "\n\Z4Do you want to delete your digibyte.conf file and re-create it?\Z0\n\nYour existing digibyte.conf file needs to be upgraded to include the sections introduced in DigiByte v8. Since you have already customised the settings file yourself, this script is unable to upgrade it automatically.\n\nIf you answer YES, your existing digibyte.conf file will be deleted and re-created with default settings. Any customisations will be lost. Your DigiByte wallet will not be affected.\n\nAlternatively, you may answer NO, to quit and manually edit it to add the sections yourself." "${r}" "${c}"; then

                    manually_edit_dgbconf=false
                    # Delete the existing digibyte.conf
                    printf "%b You chose to delete digibyte.conf and recreate it.\\n" "${INFO}"
                    printf "%b DigiByte daemon will be stopped.\\n" "${INFO}"
                    stop_service digibyted
                    DGB_STATUS="stopped"
                    str="Deleting existing digibyte.conf file..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -f $DGB_CONF_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    DGB_NETWORK_IS_CHANGED="YES"
                    
                else
                    manually_edit_dgbconf=true
                fi
            else
                manually_edit_dgbconf=true
            fi

            # Exit if digibyte.conf needs to be edited manually to add [sections]
            if [ "$manually_edit_dgbconf" = true ]; then
                printf "\\n"
                printf "%b %bERROR: One or more required sections are missing from your digibyte.conf file!%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
                printf "\\n"
                printf "%b You need to add the following sections to the bottom of your digibyte.conf file:\\n" "${INFO}"
                printf "\\n"
                printf "%b# [Sections]%b\\n" "${COL_BOLD_WHITE}" "${COL_NC}"
                printf "\\n"
                printf "%b[main]%b\\n" "${COL_BOLD_WHITE}" "${COL_NC}"
                printf "\\n"
                printf "%b[test]%b\\n" "${COL_BOLD_WHITE}" "${COL_NC}"
                printf "\\n"
                printf "%b[regtest]%b\\n" "${COL_BOLD_WHITE}" "${COL_NC}"
                printf "\\n"
                printf "%b[signet]%b\\n" "${COL_BOLD_WHITE}" "${COL_NC}"
                printf "\\n"
                printf "%b Please refer to the template here: https://jlopp.github.io/bitcoin-core-config-generator/\\n" "${INDENT}"
                printf "\\n"
                printf "%b Edit the digibyte.conf file:\\n" "${INDENT}"
                printf "\\n"
                if [ -f $DGNT_MONITOR_SCRIPT ]; then
                    printf "%b   %bdiginode --dgbconf%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
                else
                    printf "%b   %b$TEXTEDITOR $DGB_CONF_FILE%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
                fi
                printf "\\n"
                printf "%b IMPORTANT: It is very important that you include the \"# [Sections]\" line exactly as is,\\n" "${INFO}"
                printf "%b            followed by the [main], [test], [regtest] and [signet] lines in that order. This is so\\n" "${INDENT}"
                printf "%b            that DigiNode Tools can find the values where it expects them. If you are running a\\n" "${INDENT}"
                printf "%b            TESTNET Node, be sure to set the port= and rpcport= values in the [test] section,\\n" "${INDENT}"
                printf "%b            or your DigiByte Node will not run.\\n" "${INDENT}"
                printf "\\n"
                printf "%b Restart DigiByte Core once you are done:\\n" "${INDENT}"
                printf "\\n"
                if [ -f $DGNT_MONITOR_SCRIPT ]; then
                    printf "%b   %bdiginode --dgbrestart%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
                else
                    if is_command systemctl ; then
                        printf "%b   %bsudo systemctl restart digibyted%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
                    else
                        printf "%b   %bsudo service digibyted restart%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
                    fi
                fi
                printf "\\n"
                exit 1
            fi

        else
            printf "%b%b %s No!\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b digibyte.conf will be upgraded to add support for DigiByte v8 sections...\\n" "${INFO}"

            # FIRST REMOVE ANY VARIABLES THAT WE NO LONGER WANT IN THE GLOBAL SECTION

            printf "%b Checking global section of digibyte.conf for unneeded variables...\\n" "${INFO}"

            # delete any line starting "port=" from main global section of digibyte.org. This will be added in the sections below.
            if grep -q ^"port=" $DGB_CONF_FILE; then
                sed -i '/^port=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: port=\\n" "${INFO}"
            fi
            if grep -q ^"# port=" $DGB_CONF_FILE; then
                sed -i '/^# port=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # port=\\n" "${INFO}"
            fi
            if grep -q ^"# Listen for incoming connections on non-default port." $DGB_CONF_FILE; then
                sed -i '/^# Listen for incoming connections on non-default port./d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: port comment 1\\n" "${INFO}"
            fi
            if grep -q ^"# Setting the port number here will override the default mainnet or testnet port numbers." $DGB_CONF_FILE; then
                sed -i '/^# Setting the port number here will override the default mainnet or testnet port numbers./d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: port comment 2\\n" "${INFO}"
            fi

            # delete any line starting "rpcport=" from main global section of digibyte.org. This will be added to the sections below.
            if grep -q ^"rpcport=" $DGB_CONF_FILE; then
                sed -i '/^rpcport=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: rpcport=\\n" "${INFO}"
            fi
            if grep -q ^"# rpcport=" $DGB_CONF_FILE; then
                sed -i '/^# rpcport=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # rpcport=\\n" "${INFO}"
            fi
            if grep -q ^"# Listen for JSON-RPC connections on this port." $DGB_CONF_FILE; then
                sed -i '/^# Listen for JSON-RPC connections on this port./d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: rpcport comment\\n" "${INFO}"
            fi

            # delete any line starting "rpcbind=" from main global section of digibyte.org. This will be added in the sections below.
            if grep -q ^"rpcbind=" $DGB_CONF_FILE; then
                sed -i '/^rpcbind=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: rpcbind=\\n" "${INFO}"
            fi
            if grep -q ^"# rpcbind=" $DGB_CONF_FILE; then
                sed -i '/^# rpcbind=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # rpcbind=\\n" "${INFO}"
            fi
            if grep -q ^"# Bind to given address to listen for JSON-RPC connections." $DGB_CONF_FILE; then
                sed -i '/^# Bind to given address to listen for JSON-RPC connections./d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: rpcbind comment 1\\n" "${INFO}"
            fi
            if grep -q ^"# -rpcallowip is also passed. Port is optional and overrides -rpcport." $DGB_CONF_FILE; then
                sed -i '/^# -rpcallowip is also passed. Port is optional and overrides -rpcport./d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: rpcbind comment 2\\n" "${INFO}"
            fi
            if grep -q ^"# for IPv6. This option can be specified multiple times." $DGB_CONF_FILE; then
                sed -i '/^# for IPv6. This option can be specified multiple times./d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: rpcbind comment 3\\n" "${INFO}"
            fi

            # delete any line starting "testnet=" from main global section of digibyte.org. The chain= variable will be used instead.
            if grep -q ^"testnet=" $DGB_CONF_FILE; then
                sed -i '/^testnet=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: testnet=\\n" "${INFO}"
            fi
            if grep -q ^"# testnet=" $DGB_CONF_FILE; then
                sed -i '/^# testnet=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # testnet=\\n" "${INFO}"
            fi
            if grep -q ^"# Run this node on the DigiByte Test Network. Equivalent to -chain=test." $DGB_CONF_FILE; then
                sed -i '/^# Run this node on the DigiByte Test Network. Equivalent to -chain=test./d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: testnet comment\\n" "${INFO}"
            fi

            # Delete any values from the global section relating to Tor. These will be added to the sections below.
            if grep -q ^"proxy=" $DGB_CONF_FILE; then
                sed -i '/^proxy=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: proxy=\\n" "${INFO}"
            fi
            if grep -q ^"# proxy=" $DGB_CONF_FILE; then
                sed -i '/^# proxy=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # proxy=\\n" "${INFO}"
            fi
            if grep -q ^"torcontrol=" $DGB_CONF_FILE; then
                sed -i '/^torcontrol=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: torcontrol=\\n" "${INFO}"
            fi
            if grep -q ^"# torcontrol=" $DGB_CONF_FILE; then
                sed -i '/^# torcontrol=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # torcontrol=\\n" "${INFO}"
            fi
            if grep -q ^"bind=" $DGB_CONF_FILE; then
                sed -i '/^bind=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: bind=\\n" "${INFO}"
            fi
            if grep -q ^"# bind=" $DGB_CONF_FILE; then
                sed -i '/^# bind=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # bind=\\n" "${INFO}"
            fi
            if grep -q ^"onlynet=" $DGB_CONF_FILE; then
                sed -i '/^onlynet=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: onlynet=\\n" "${INFO}"
            fi
            if grep -q ^"# onlynet=" $DGB_CONF_FILE; then
                sed -i '/^# onlynet=/d' $DGB_CONF_FILE
                printf "%b Deleting from digibyte.conf global section: # onlynet=\\n" "${INFO}"
            fi


            str="Appending sections to digibyte.conf: # [Sections], [main], [test], [regtest] and [signet] .."
            printf "%b %s" "${INFO}" "${str}"
            cat <<EOF >> $DGB_CONF_FILE


# [Sections]
# Most options automatically apply to mainnet, testnet, and regtest networks.
# If you want to confine an option to just one network, you should add it in the relevant section.
# EXCEPTIONS: The options addnode, connect, port, bind, rpcport, rpcbind and wallet
# only apply to mainnet unless they appear in the appropriate section below.
#
# WARNING: Do not remove these sections or DigiNode Dashboard may not work correctly.
# You must ensure the "# [Sections]" line exists above, followed by the four section headers: 
# [main], [test], [regtest] and [signet]. Do not remove any of these.

# Options only for mainnet
[main]

# Listen for incoming connections on non-default mainnet port. Mainnet default is 12024.
# Changing the port number here will override the default mainnet port number.
# port=12024

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
rpcbind=127.0.0.1

# Listen for JSON-RPC mainnet connections on this port. Mainnet default is 14022.
# rpcport=14022

# Connect through Tor SOCKS5 proxy
# proxy=127.0.0.1:9050

# Set the Tor control port for mainnet
# torcontrol=127.0.0.1:9151

# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections.
# bind=127.0.0.1=onion

# Only connect to peers via Tor. Generally not recommended.
# onlynet=onion

# Options only for testnet
[test]

# Listen for incoming connections on non-default testnet port. Testnet default is 12026.
# Changing the port number here will override the default testnet port numbers.
# port=12026

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
# rpcbind=127.0.0.1

# Listen for JSON-RPC testnet connections on this port. Testnet default is 14023.
# rpcport=14023

# Connect through Tor SOCKS5 proxy
# proxy=127.0.0.1:9050

# Set the Tor control port for testnet
# torcontrol=127.0.0.1:9151

# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections.
# bind=127.0.0.1=onion

# Only connect to peers via Tor. Generally not recommended.
# onlynet=onion

# Options only for regtest
[regtest]

# Listen for incoming connections on non-default regtest port. Regtest default is 18444.
# Changing the port number here will override the default regtest listening port.
# port=18444

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
# rpcbind=127.0.0.1

# Listen for JSON-RPC regtest connections on this port. Regtest default is 18443.
# rpcport=18443

# Connect through Tor SOCKS5 proxy
# proxy=127.0.0.1:9050

# Set the Tor control port for regtest
# torcontrol=127.0.0.1:9151

# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections.
# bind=127.0.0.1=onion

# Only connect to peers via Tor. Generally not recommended.
# onlynet=onion

# Options only for signet
[signet]

# Listen for incoming connections on non-default signet port. Signet default is 38443.
# Changing the port number here will override the default signet listening port.
# port=38443

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
# rpcbind=127.0.0.1

# Listen for JSON-RPC signet connections on this port. Signet default is 19443.
# rpcport=19443

# Connect through Tor SOCKS5 proxy
# proxy=127.0.0.1:9050

# Set the Tor control port for signet
# torcontrol=127.0.0.1:9151

# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections.
# bind=127.0.0.1=onion

# Only connect to peers via Tor. Generally not recommended.
# onlynet=onion

EOF
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi    

    fi

    # Do some intial setup before creating the digibyte.conf file for the first time
    if [ ! -f "$DGB_CONF_FILE" ]; then

        # Max connections are set from the diginode.settings file
        set_maxconnections=$DGB_MAX_CONNECTIONS

        # Increase dbcache size if there is more than ~7Gb of RAM (Default: 450)
        # Initial sync times are significantly faster with a larger dbcache.
        set_dbcache_value

        # generate a random rpc password, if the digibyte.conf file does not exist
 
        local set_rpcpassword
        str="Generating random RPC password..."
        printf "%b %s" "${INFO}" "${str}"
        set_rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Set the intial Tor values for TESTNET, if we are creating digibyte.conf

        TOR_ON_SETTINGS=$(cat <<EOF
# Connect through Tor SOCKS5 proxy
proxy=127.0.0.1:9050

# Set the Tor control port
torcontrol=127.0.0.1:9151

# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections.
bind=127.0.0.1=onion

# Only connect to peers via Tor. Generally not recommended.
# onlynet=onion

EOF
)
        TOR_OFF_SETTINGS=$(cat <<EOF
# Connect through Tor SOCKS5 proxy
# proxy=127.0.0.1:9050

# Set the Tor control port
# torcontrol=127.0.0.1:9151

# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections.
# bind=127.0.0.1=onion

# Only connect to peers via Tor. Generally not recommended.
# onlynet=onion

EOF
)

        if [ "$DGB_TOR_MAINNET" = "ON" ]; then
            DGB_TOR_MAINNET_SETTINGS=$TOR_ON_SETTINGS
        else
            DGB_TOR_MAINNET_SETTINGS=$TOR_OFF_SETTINGS
        fi

        if [ "$DGB_TOR_TESTNET" = "ON" ]; then
            DGB_TOR_TESTNET_SETTINGS=$TOR_ON_SETTINGS
        else
            DGB_TOR_TESTNET_SETTINGS=$TOR_OFF_SETTINGS
        fi

#        # Set the default rpcport
#        local set_rpcport
#        if [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then
#            set_rpcport=14023
#        elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then
#            set_rpcport=14022
#        elif [ "$DGB_NETWORK_FINAL" = "REGTEST" ]; then
#            set_rpcport=18443
#        fi

        # Set the default testnet rpcport
#        set_rpcport_testnet=14023

    # If the digibyte.conf file already exists
    elif [ -f "$DGB_CONF_FILE" ]; then
 

        # Import variables from global section of digibyte.conf
        str="Located digibyte.conf file. Importing..."
        printf "%b %s" "${INFO}" "${str}"
        scrape_digibyte_conf
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Import variables from global section of digibyte.conf
        str="Getting digibyte.conf global variables..."
        printf "%b %s" "${INFO}" "${str}"
        eval "$DIGIBYTE_CONFIG_GLOBAL"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    fi


    # Set the UPnP values, if we are enabling/disabling the UPnP status
    if [ "$DGB_ENABLE_UPNP" = "YES" ]; then
        upnp=1
    elif [ "$DGB_ENABLE_UPNP" = "NO" ]; then
        upnp=0
    fi

    # Disable UPnP if we are enabling Tor (UPnP messes with Tor)
    if [ "$upnp" = 1 ] && { [ "$DGB_TOR_MAINNET" = "ON" ] || [ "$DGB_TOR_TESTNET" = "ON" ]; }; then
        printf "%b UPnP has been disabled because Tor is enabled - they do not play nice together.\\n" "${WARN}"
        upnp=0
    fi

    # Set the dgb network values, if we are changing between testnet and mainnet
    if [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then
        chain=test
    elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$SETUP_DUAL_NODE" = "YES" ]; then
        chain=dualnode
    elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then
        chain=main
    elif [ "$DGB_NETWORK_FINAL" = "REGTEST" ]; then
        chain=regtest
    elif [ "$DGB_NETWORK_FINAL" = "SIGNET" ]; then
        chain=signet
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

        printf "%b Checking digibyte.conf global settings...\\n" "${INFO}"
        
        # Check for daemon=1 variable in digibyte.conf, otherwise update/append it
        if ! grep -q -Fx "daemon=1" $DGB_CONF_FILE; then
            if grep -q ^"daemon=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: daemon=1"
                sed -i -e "/^daemon=/s|.*|daemon=1|" $DGB_CONF_FILE
            elif grep -q ^"# daemon=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: daemon=1"
                sed -i -e "/^# daemon=/s|.*|daemon=1|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: daemon=1"
                sed -i '/# \[Sections\]/ i \
# Run in the background as a daemon and accept commands. \
daemon=1 \
' $DGB_CONF_FILE                
            fi
        fi

        # Check for listen=1 variable in digibyte.conf, otherwise update/append it
        if ! grep -q -Fx "listen=1" $DGB_CONF_FILE; then
            if grep -q ^"listen=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: listen=1"
                sed -i -e "/^listen=/s|.*|listen=1|" $DGB_CONF_FILE
            elif grep -q ^"# listen=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: listen=1"
                sed -i -e "/^# listen=/s|.*|listen=1|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: listen=1"
                sed -i '/# \[Sections\]/ i \
# Accept incoming connections from peers. Default is 1. \
listen=1 \
' $DGB_CONF_FILE                
            fi
        fi

        # Check for server=1 variable in digibyte.conf, otherwise update/append it
        if ! grep -q -Fx "server=1" $DGB_CONF_FILE; then
            if grep -q ^"# server=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: server=1"
                sed -i -e "/^# server=/s|.*|server=1|" $DGB_CONF_FILE
            elif grep -q ^"listen=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: server=1"
                sed -i -e "/^server=/s|.*|server=1|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: server=1"
                sed -i '/# \[Sections\]/ i \
# Accept command line and JSON-RPC commands. Default is 0. \
server=1 \
' $DGB_CONF_FILE                
            fi
        fi

        # If dbcache value is not already set in global section digibyte.conf, update it
        if [ "$dbcache" = "" ]; then
            set_dbcache_value # calculate the recommended dbcache value absed on system RAM
            if grep -q ^"dbcache=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: dbcache=$set_dbcache"
                sed -i -e "/^dbcache=/s|.*|dbcache=$set_dbcache|" $DGB_CONF_FILE
            elif grep -q ^"# dbcache=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: dbcache=$set_dbcache"
                sed -i -e "/^# dbcache=/s|.*|dbcache=$set_dbcache|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: dbache=$set_dbcache"
                sed -i "/# \[Sections\]/ i \\
# Set database cache size in megabytes; machines sync faster with a larger cache. \\
# Recommend setting as high as possible based upon available RAM. (default: 450) \\
dbcache=$set_dbcache \\
" $DGB_CONF_FILE                
            fi
        fi

        # If maxconnections value is not already set in global section of digibyte.conf, update it
        if [ "$maxconnections" = "" ]; then
            set_maxconnections=$DGB_MAX_CONNECTIONS # Max connections are set from the diginode.settings file
            if grep -q ^"maxconnections=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: maxconnections=$set_maxconnections"
                sed -i -e "/^maxconnections=/s|.*|maxconnections=$set_maxconnections|" $DGB_CONF_FILE
            elif grep -q ^"# maxconnections=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: maxconnections=$set_dbcache"
                sed -i -e "/^# maxconnections=/s|.*|maxconnections=$set_maxconnections|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: maxconnections=$set_maxconnections"
                sed -i "/# \[Sections\]/ i \\
# Maintain at most N connections to peers. (default: 125) \\
maxconnections=$set_maxconnections \\
" $DGB_CONF_FILE                
            fi
        fi

        # If rpcuser=digibyte variable is not already set in global section of digibyte.conf, update it
        if [ "$rpcuser" = "" ]; then
            if grep -q ^"rpcuser=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: rpcuser=digibyte"
                sed -i -e "/^rpcuser=/s|.*|rpcuser=digibyte|" $DGB_CONF_FILE
            elif grep -q ^"# rpcuser=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: rpcuser=digibyte"
                sed -i -e "/^# rpcuser=/s|.*|rpcuser=digibyte|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: rpcuser=digibyte"
                sed -i '/# \[Sections\]/ i \
# RPC user \
rpcuser=digibyte \
' $DGB_CONF_FILE                
            fi
        fi

        # If rpcpasword=<rpcpassword> variable is not already set in global section of digibyte.conf, update it
        if [ "$rpcpassword" = "" ]; then
            if grep -q ^"rpcpassword=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: rpcpassword=$set_rpcpassword"
                sed -i -e "/^rpcpassword=/s|.*|rpcpassword=$set_rpcpassword|" $DGB_CONF_FILE
            elif grep -q ^"# rpcpassword=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: rpcpassword=$set_rpcpassword"
                sed -i -e "/^# rpcpassword=/s|.*|rpcpassword=$set_rpcpassword|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: rpcpassword=$set_rpcpassword"
                sed -i "/# \[Sections\]/ i \\
# RPC password \\
rpcpassword=$set_rpcpassword \\
" $DGB_CONF_FILE                
            fi
        fi

        # If UPnP value is commented out, uncomment it
        if grep -q ^"# upnp=" $DGB_CONF_FILE; then
            if [ "$upnp" = "1" ]; then
                echo "$INDENT   UPnP will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^# upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            elif [ "$upnp" = "0" ]; then
                echo "$INDENT   UPnP will be disabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^# upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        # Change UPnP status from enabled to disabled
        elif grep -q ^"upnp=1" $DGB_CONF_FILE; then
            if [ "$upnp" = "0" ]; then
                echo "$INDENT   UPnP will be disabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        # Change UPnP status from disabled to enabled
        elif grep -q ^"upnp=0" $DGB_CONF_FILE; then
            if [ "$upnp" = "1" ]; then
                echo "$INDENT   UPnP will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^# upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        # Update UPnP status in settings if it exists and is blank, otherwise append it
        elif grep -q ^"upnp=" $DGB_CONF_FILE; then
            if [ "$upnp" = "1" ]; then
                echo "$INDENT   UPnP will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
            elif [ "$upnp" = "0" ]; then
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Appending to digibyte.conf: upnp=$upnp"
            sed -i "/# \[Sections\]/ i \\
# Use UPnP to map the listening port. \\
upnp=$upnp \\
" $DGB_CONF_FILE                
            fi    

        # If rpcallowip= variable is not already set in global section of digibyte.conf, update it
        if [ "$rpcallowip" = "" ]; then
            if grep -q ^"rpcallowip=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: rpcallowip=127.0.0.1"
                sed -i -e "/^rpcallowip=/s|.*|rpcallowip=digibyte|" $DGB_CONF_FILE
            elif grep -q ^"# rpcallowip=" $DGB_CONF_FILE; then
                echo "$INDENT   Updating digibyte.conf: rpcallowip=127.0.0.1"
                sed -i -e "/^# rpcallowip=/s|.*|rpcallowip=digibyte|" $DGB_CONF_FILE
            else
                echo "$INDENT   Appending to digibyte.conf: rpcallowip=127.0.0.1"
                sed -i '/# \[Sections\]/ i \
# Allow JSON-RPC connections from specified source. Valid for <ip> are a single IP (e.g. 1.2.3.4), \
# a network/netmask (e.g. 1.2.3.4/255.255.255.0) or a network/CIDR (e.g. 1.2.3.4/24). This option \
# can be specified multiple times. \
rpcallowip=127.0.0.1 \
' $DGB_CONF_FILE        
            fi
        fi    

        # SET THE CORRECT DIGIBYTE CHAIN

        if ! grep -q ^"chain=$chain" $DGB_CONF_FILE; then

            # If chain= declaration is commented out, uncomment it, and set it to the correct chain, provided we are NOT running a Dual Node
            if grep -q ^"# chain=" $DGB_CONF_FILE  && [ "$SETUP_DUAL_NODE" != "YES" ]; then
                echo "$INDENT   $DGB_NETWORK_FINAL chain will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: chain=$chain (Uncommented)" 
                sed -i -e "/^# chain=/s|.*|chain=$chain|" $DGB_CONF_FILE
                DGB_NETWORK_IS_CHANGED="YES"
                if [ $VERBOSE_MODE = true ]; then
                    printf "%b Verbose Mode: # chain= was uncommented.\\n" "${INFO}"
                fi

            # If chain= declaration exists, but is not set to the correct chain, update it
            elif grep -q ^"chain=" $DGB_CONF_FILE && ! grep -q ^"chain=$chain" $DGB_CONF_FILE && [ "$SETUP_DUAL_NODE" != "YES" ]; then
                echo "$INDENT   $DGB_NETWORK_FINAL chain will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: chain=$chain"
                sed -i -e "/^chain=/s|.*|chain=$chain|" $DGB_CONF_FILE
                DGB_NETWORK_IS_CHANGED="YES"
                if [ $VERBOSE_MODE = true ]; then
                    printf "%b Verbose Mode: chain= value was changed to $chain.\\n" "${INFO}"
                fi
            # If chain= declaration exists, and we are running a Dual Node, then comment it out
            elif grep -q ^"chain=" $DGB_CONF_FILE  && [ "$SETUP_DUAL_NODE" = "YES" ]; then
                echo "$INDENT   $DGB_NETWORK_FINAL chain will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: # chain=$chain (Commented out to support Dual Node.)"
                sed -i -e "/^chain=/s|.*|# chain=$chain|" $DGB_CONF_FILE
                DGB_NETWORK_IS_CHANGED="YES"
                if [ $VERBOSE_MODE = true ]; then
                    printf "%b Verbose Mode: chain= value was commented out.\\n" "${INFO}"
                fi
            else

                # Only append chain= values if we are not running a Dual Node
                if [ "$SETUP_DUAL_NODE" != "YES" ]; then

                    # If the chain= declaration does not exist in digibyte.conf, append it after: # [chain], if that line exists
                    if grep -q ^"# [chain]" $DGB_CONF_FILE; then
                        echo "$INDENT   Appending to digibyte.conf: chain=$chain - After: # [chain]"
                        sed -i "/# \[chain\]/ a \\
# Choose which DigiByte chain to use. Options: main, test, regtest, signet. (Default: main) \\
# (WARNING: Only set the current chain using the chain= variable below. Do not use \\
# testnet=1, regtest=1 or signet=1 to select the current chain or your node will not start.) \\
# When running a Dual Node, this must be commented out or the DigiByte daemon will not run.
chain=$chain \\
" $DGB_CONF_FILE
                    else
                        # If the chain= declaration does not exist in digibyte.conf, append it before the sections
                        echo "$INDENT   Appending to digibyte.conf: chain=$chain - Before: # [Sections]"
                        sed -i "/# \[Sections\]/ i \\
# Choose which DigiByte chain to use. Options: main, test, regtest, signet. (Default: main) \\
# (WARNING: Only set the current chain using the chain= variable below. Do not use \\
# testnet=1, regtest=1 or signet=1 to select the current chain or your node will not start.) \\
# When running a Dual Node, this must be commented out or the DigiByte daemon will not run. \\
chain=$chain \\
" $DGB_CONF_FILE
                    fi
                else
                    echo "$INDENT   Skipped appending chain=$chain to digibyte.conf - not required when running a Dual Node."
                fi
            fi 

        fi

        # If testnet variable already exists in digibyte.conf, comment it out.
        # We only want to use the chain= variable to select which chain to run.
        if grep -q ^"testnet=" $DGB_CONF_FILE; then
            echo "$INDENT   Updating digibyte.conf: # testnet=1  [ Commented out ]"
            sed -i -e "/^testnet=/s|.*|# testnet=1|" $DGB_CONF_FILE  
            DGB_NETWORK_IS_CHANGED="YES"     
        elif grep -q ^"# testnet=" $DGB_CONF_FILE && ! grep -q ^"# testnet=1" $DGB_CONF_FILE; then
            echo "$INDENT   Updating digibyte.conf: # testnet=1  [ Changed ]"  
            sed -i -e "/^# testnet=/s|.*|# testnet=1|" $DGB_CONF_FILE
        fi

        # If regtest variable already exists in digibyte.conf, comment it out.
        # We only want to use the chain= variable to select which chain to run.
        if grep -q ^"regtest=" $DGB_CONF_FILE; then
            echo "$INDENT   Updating digibyte.conf: # regtest=1  [ Commented out ]"
            sed -i -e "/^regtest=/s|.*|# regtest=1|" $DGB_CONF_FILE  
            DGB_NETWORK_IS_CHANGED="YES"     
        elif grep -q ^"# regtest=" $DGB_CONF_FILE && ! grep -q ^"# regtest=1" $DGB_CONF_FILE; then
            echo "$INDENT   Updating digibyte.conf: # regtest=1  [ Changed ]"  
            sed -i -e "/^# regtest=/s|.*|# regtest=1|" $DGB_CONF_FILE
        fi

        # If signet variable already exists in digibyte.conf, comment it out.
        # We only want to use the chain= variable to select which chain to run.
        if grep -q ^"signet=" $DGB_CONF_FILE; then
            echo "$INDENT   Updating digibyte.conf: # signet=1  [ Commented out ]"
            sed -i -e "/^signet=/s|.*|# signet=1|" $DGB_CONF_FILE  
            DGB_NETWORK_IS_CHANGED="YES"     
        elif grep -q ^"# signet=" $DGB_CONF_FILE && ! grep -q ^"# signet=1" $DGB_CONF_FILE; then
            echo "$INDENT   Updating digibyte.conf: # signet=1  [ Changed ]"  
            sed -i -e "/^# signet=/s|.*|# signet=1|" $DGB_CONF_FILE
        fi

        # SET THE TOR SETTINGS FOR DIGBYTE MAINNET - PROXY

        # If [main] proxy value is commented out: # proxy=
        if [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^# proxy=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: proxy=127.0.0.1:9050"

                input_line="# proxy="
                output_line="proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi
        # If [main] proxy value is commented out without a space: #proxy=
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^#proxy=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: proxy=127.0.0.1:9050"

                input_line="#proxy="
                output_line="proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi
        # Change Tor status from enabled to disabled for proxy=
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^proxy=127.0.0.1:9050/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_MAINNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: # proxy=127.0.0.1:9050"

                input_line="proxy=127.0.0.1:9050"
                output_line="# proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi    
        # Update Tor status if proxy= exists but is blank, or not set to proxy=127.0.0.1:9050
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^proxy=/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: proxy=127.0.0.1:9050"

                input_line="proxy="
                output_line="proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"

            elif [ "$DGB_TOR_MAINNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: # proxy=127.0.0.1:9050"

                input_line="proxy="
                output_line="# proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi   
        else
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Adding to digibyte.conf [main] section for Tor: proxy=127.0.0.1:9050"
                sed -i "/^\[main\]/a \\
\\
# Connect through Tor SOCKS5 proxy \\
proxy=127.0.0.1:9050" $DGB_CONF_FILE 
                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            else
                echo "$INDENT   Adding to digibyte.conf [main] section for Tor: # proxy=127.0.0.1:9050"
                sed -i "/^\[main\]/a \\
\\
# Connect through Tor SOCKS5 proxy \\
# proxy=127.0.0.1:9050" $DGB_CONF_FILE
            fi
        fi  

        # SET THE TOR SETTINGS FOR DIGBYTE MAINNET - TORCONTROL

        # If [main] torcontrol value is commented out: # torcontrol=
        if [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^# torcontrol=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: torcontrol=127.0.0.1:9151"

                input_line="# torcontrol="
                output_line="torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi
        # If [main] torcontrol value is commented out without a space: #torcontrol=
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^#torcontrol=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: torcontrol=127.0.0.1:9151"

                input_line="#torcontrol="
                output_line="torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi
        # Change Tor status from enabled to disabled for torcontrol=
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^torcontrol=127.0.0.1:9151/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_MAINNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: # torcontrol=127.0.0.1:9151"

                input_line="torcontrol=127.0.0.1:9151"
                output_line="# torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi    
        # Update Tor status if torcontrol= exists but is blank, or not set to torcontrol=127.0.0.1:9151
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^torcontrol=/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: torcontrol=127.0.0.1:9151"

                input_line="torcontrol="
                output_line="torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"

            elif [ "$DGB_TOR_MAINNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: # torcontrol=127.0.0.1:9151"

                input_line="torcontrol="
                output_line="# torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi   
        else
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Adding to digibyte.conf [main] section for Tor: torcontrol=127.0.0.1:9151"
                sed -i "/^\[main\]/a \\
\\
# Set the Tor control port for mainnet. \\
torcontrol=127.0.0.1:9151" $DGB_CONF_FILE 
                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            else
                echo "$INDENT   Adding to digibyte.conf [main] section for Tor: # torcontrol=127.0.0.1:9151"
                sed -i "/^\[main\]/a \\
\\
# Set the Tor control port for mainnet. \\
# torcontrol=127.0.0.1:9151" $DGB_CONF_FILE
            fi
        fi    

        # SET THE TOR SETTINGS FOR DIGBYTE MAINNET - BIND

        # If [main] bind value is commented out: # bind=
        if [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^# bind=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: bind=127.0.0.1=onion"

                input_line="# bind="
                output_line="bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi
        # If [main] bind value is commented out without a space: #bind=
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^#bind=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: bind=127.0.0.1=onion"

                input_line="#bind="
                output_line="bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi
        # Change Tor status from enabled to disabled for bind=
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^bind=127.0.0.1=onion/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_MAINNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: # bind=127.0.0.1=onion"

                input_line="bind=127.0.0.1=onion"
                output_line="# bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi    
        # Update Tor status if bind= exists but is blank, or not set to bind=127.0.0.1=onion
        elif [ -n "$(awk '/^\[main\]/ {found_main=1} /^\[test\]/ {found_main=0} found_main && /^bind=/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: bind=127.0.0.1=onion"

                input_line="bind="
                output_line="bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"

            elif [ "$DGB_TOR_MAINNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [main] section for Tor: # bind=127.0.0.1=onion"

                input_line="bind="
                output_line="# bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_main_section=0 }
                    /^\[main\]/ { in_main_section=1 }
                    /^\[test\]/ { in_main_section=0 }
                    in_main_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            fi   
        else
            if [ "$DGB_TOR_MAINNET" = "ON" ]; then
                echo "$INDENT   Adding to digibyte.conf [main] section for Tor: bind=127.0.0.1=onion"
                sed -i "/^\[main\]/a \\
\\
# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections. \\
bind=127.0.0.1=onion" $DGB_CONF_FILE 
                DGB_MAINNET_TOR_STATUS_UPDATED="YES"
            else
                echo "$INDENT   Adding to digibyte.conf [main] section for Tor: # bind=127.0.0.1=onion"
                sed -i "/^\[main\]/a \\
\\
# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections. \\
# bind=127.0.0.1=onion" $DGB_CONF_FILE
            fi
        fi   


        # SET THE TOR SETTINGS FOR DIGBYTE TESTNET - PROXY

        # If [test] proxy value is commented out: # proxy=
        if [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^# proxy=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: proxy=127.0.0.1:9050"

                input_line="# proxy="
                output_line="proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi
        # If [test] proxy value is commented out without a space: #proxy=
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^#proxy=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: proxy=127.0.0.1:9050"

                input_line="#proxy="
                output_line="proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi
        # Change Tor status from enabled to disabled for: proxy=
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^proxy=127.0.0.1:9050/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_TESTNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: # proxy=127.0.0.1:9050"

                input_line="proxy=127.0.0.1:9050"
                output_line="# proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi    
        # Update Tor status if proxy= exists but is blank, or not set to proxy=127.0.0.1:9050
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^bind=/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: proxy=127.0.0.1:9050"

                input_line="proxy="
                output_line="proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"

            elif [ "$DGB_TOR_TESTNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: # proxy=127.0.0.1:9050"

                input_line="proxy="
                output_line="# proxy=127.0.0.1:9050"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi   
        else
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Adding to digibyte.conf [test] section for Tor: proxy=127.0.0.1:9050"
                sed -i "/^\[test\]/a \\
\\
# Connect through Tor SOCKS5 proxy \\
proxy=127.0.0.1:9050" $DGB_CONF_FILE 
                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            else
                echo "$INDENT   Adding to digibyte.conf [test] section for Tor: # proxy=127.0.0.1:9050"
                sed -i "/^\[test\]/a \\
\\
# Connect through Tor SOCKS5 proxy \\
# proxy=127.0.0.1:9050" $DGB_CONF_FILE
            fi
        fi  

        # SET THE TOR SETTINGS FOR DIGBYTE TESTNET - TORCONTROL

        # If [test] torcontrol value is commented out: # torcontrol=
        if [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^# torcontrol=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: torcontrol=127.0.0.1:9151"

                input_line="# torcontrol="
                output_line="torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi
        # If [test] torcontrol value is commented out without a space: #torcontrol=
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^#torcontrol=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: torcontrol=127.0.0.1:9151"

                input_line="#torcontrol="
                output_line="torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi
        # Change Tor status from enabled to disabled for torcontrol=
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^torcontrol=127.0.0.1:9151/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_TESTNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: # torcontrol=127.0.0.1:9151"

                input_line="torcontrol=127.0.0.1:9151"
                output_line="# torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi    
        # Update Tor status if torcontrol= exists but is blank, or not set to torcontrol=127.0.0.1:9151
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^torcontrol=/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: torcontrol=127.0.0.1:9151"

                input_line="torcontrol="
                output_line="torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"

            elif [ "$DGB_TOR_TESTNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: # torcontrol=127.0.0.1:9151"

                input_line="torcontrol="
                output_line="# torcontrol=127.0.0.1:9151"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi   
        else
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Adding to digibyte.conf [test] section for Tor: torcontrol=127.0.0.1:9151"
                sed -i "/^\[test\]/a \\
\\
# Set the Tor control port for testnet. \\
torcontrol=127.0.0.1:9151" $DGB_CONF_FILE 
                DGB_TESTNET_TOR_STATUS_UPDATED="YES" 
            else
                echo "$INDENT   Adding to digibyte.conf [test] section for Tor: # torcontrol=127.0.0.1:9151"
                sed -i "/^\[test\]/a \\
\\
# Set the Tor control port for testnet. \\
# torcontrol=127.0.0.1:9151" $DGB_CONF_FILE
            fi
        fi    

        # SET THE TOR SETTINGS FOR DIGBYTE TESTNET - BIND

        # If [test] bind value is commented out: # bind=
        if [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^# bind=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: bind=127.0.0.1=onion"

                input_line="# bind="
                output_line="bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi
        # If [test] bind value is commented out without a space: #bind=
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^#bind=/' "$DGB_CONF_FILE")" ]; then 
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: bind=127.0.0.1=onion"

                input_line="#bind="
                output_line="bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi
        # Change Tor status from enabled to disabled for bind=
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^bind=127.0.0.1=onion/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_TESTNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: # bind=127.0.0.1=onion"

                input_line="bind=127.0.0.1=onion"
                output_line="# bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi    
        # Update Tor status if bind= exists but is blank, or not set to bind=127.0.0.1=onion
        elif [ -n "$(awk '/^\[test\]/ {found_test=1} /^\[regtest\]/ {found_test=0} found_test && /^bind=/' "$DGB_CONF_FILE")" ]; then
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: bind=127.0.0.1=onion"

                input_line="bind="
                output_line="bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"

            elif [ "$DGB_TOR_TESTNET" = "OFF" ]; then
                echo "$INDENT   Updating digibyte.conf [test] section for Tor: # bind=127.0.0.1=onion"

                input_line="bind="
                output_line="# bind=127.0.0.1=onion"

                awk -v input="$input_line" -v output="$output_line" '
                    BEGIN { in_test_section=0 }
                    /^\[test\]/ { in_test_section=1 }
                    /^\[regtest\]/ { in_test_section=0 }
                    in_test_section && $0 ~ "^" input { $0 = output }
                    { print }
                ' $DGB_CONF_FILE > temp && mv temp $DGB_CONF_FILE

                DGB_TESTNET_TOR_STATUS_UPDATED="YES"
            fi   
        else
            if [ "$DGB_TOR_TESTNET" = "ON" ]; then
                echo "$INDENT   Adding to digibyte.conf [test] section for Tor: bind=127.0.0.1=onion"
                sed -i "/^\[test\]/a \\
\\
# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections. \\
bind=127.0.0.1=onion" $DGB_CONF_FILE 
                DGB_TESTNET_TOR_STATUS_UPDATED="YES" 
            else
                echo "$INDENT   Adding to digibyte.conf [test] section for Tor: # bind=127.0.0.1=onion"
                sed -i "/^\[test\]/a \\
\\
# Bind to localhost to use Tor. Append =onion to tag any incoming connections to that address and port as incoming Tor connections. \\
# bind=127.0.0.1=onion" $DGB_CONF_FILE
            fi
        fi       

  



        # If upnp value is commented out, uncomment it
        if grep -q ^"# upnp=" $DGB_CONF_FILE; then
            if [ "$upnp" = "1" ]; then
                echo "$INDENT   UPnP will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^# upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            elif [ "$upnp" = "0" ]; then
                echo "$INDENT   UPnP will be disabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^# upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        # Change upnp status from enabled to disabled
        elif grep -q ^"upnp=1" $DGB_CONF_FILE; then
            if [ "$upnp" = "0" ]; then
                echo "$INDENT   UPnP will be disabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        # Change upnp status from disabled to enabled
        elif grep -q ^"upnp=0" $DGB_CONF_FILE; then
            if [ "$upnp" = "1" ]; then
                echo "$INDENT   UPnP will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^# upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
                DGB_UPNP_STATUS_UPDATED="YES"
            fi
        # Update upnp status in settings if it exists and is blank, otherwise append it
        elif grep -q ^"upnp=" $DGB_CONF_FILE; then
            if [ "$upnp" = "1" ]; then
                echo "$INDENT   UPnP will be enabled for DigiByte Core"
                echo "$INDENT   Updating digibyte.conf: upnp=$upnp"
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
            elif [ "$upnp" = "0" ]; then
                sed -i -e "/^upnp=/s|.*|upnp=$upnp|" $DGB_CONF_FILE
            fi
        else
            echo "$INDENT   Appending to digibyte.conf: upnp=$upnp"
            sed -i "/# \[Sections\]/ i \\
# Use UPnP to map the listening port. \\
upnp=$upnp \\
" $DGB_CONF_FILE                
            fi    






        printf "%b Completed digibyte.conf checks.\\n" "${TICK}"

        # Re-import variables from digibyte.conf in case they have changed
        str="Reimporting digibyte.conf values, as they may have changed..."
        printf "%b %s" "${INFO}" "${str}"
        scrape_digibyte_conf
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Import variables from global section of digibyte.conf
        str="Getting digibyte.conf global variables..."
        printf "%b %s" "${INFO}" "${str}"
        eval "$DIGIBYTE_CONFIG_GLOBAL"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    else

        # Create a new digibyte.conf file
        str="Creating ~/.digibyte/digibyte.conf file..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_CONF_FILE
        cat <<EOF > $DGB_CONF_FILE
# This config should be placed in the following path:
# ~/.digibyte/digibyte.conf

# This template is based on the Bitcoin Core Config Generator by Jameson Lopp
# https://jlopp.github.io/bitcoin-core-config-generator/


# [chain]

# Choose which DigiByte chain to use. Options: main. test, regtest, signet. (Default: main)
# (WARNING: Only set the current chain using the chain= variable below. Do not use 
# testnet=1, regtest=1 or signet=1 to select the current chain or your node will not start.)
# When running a Dual Node, this must be commented out or the DigiByte daemon will not run.
chain=$chain


# [core]
# Run in the background as a daemon and accept commands.
daemon=1

# Set database cache size in megabytes; machines sync faster with a larger cache.
# Recommend setting as high as possible based upon available RAM. (default: 450)
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

# Accept incoming connections from peers. Default is 1.
listen=1

# Use UPnP to map the listening port. Do not enable when running Tor.
upnp=$upnp


# [rpc]
# RPC user
rpcuser=digibyte

# RPC password
rpcpassword=$set_rpcpassword

# Accept command line and JSON-RPC commands. Default is 0.
server=1

# Allow JSON-RPC connections from specified source. Valid for <ip> are a single IP (e.g. 1.2.3.4),
# a network/netmask (e.g. 1.2.3.4/255.255.255.0) or a network/CIDR (e.g. 1.2.3.4/24). This option
# can be specified multiple times.
rpcallowip=127.0.0.1


# [wallet]
# Do not load the wallet and disable wallet RPC calls. (Default: 0 = wallet is enabled)
disablewallet=0


# [Sections]
# Most options automatically apply to mainnet, testnet, and regtest networks.
# If you want to confine an option to just one network, you should add it in the relevant section.
# EXCEPTIONS: The options addnode, connect, port, bind, rpcport, rpcbind and wallet
# only apply to mainnet unless they appear in the appropriate section below.
#
# WARNING: Do not remove these sections or DigiNode Dashboard may not work correctly.
# You must ensure the "# [Sections]" line exists above, followed by the four section headers: 
# [main], [test], [regtest] and [signet]. Do not remove any of these.

# Options only for mainnet
[main]

# Listen for incoming connections on non-default mainnet port. Mainnet default is 12024.
# Changing the port number here will override the default mainnet port number.
# port=12024

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
rpcbind=127.0.0.1

# Listen for JSON-RPC connections on this port. Mainnet default is 14022.
# rpcport=14022

$DGB_TOR_MAINNET_SETTINGS

# Options only for testnet
[test]

# Listen for incoming connections on non-default testnet port. Testnet default is 12026.
# Changing the port number here will override the default testnet port numbers.
# port=12026

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
rpcbind=127.0.0.1

# Listen for JSON-RPC testnet connections on this port. Testnet default is 14023.
# rpcport=14023

$DGB_TOR_TESTNET_SETTINGS

# Options only for regtest
[regtest]

# Listen for incoming connections on non-default regtest port. Regtest default is 18444.
# Changing the port number here will override the default regtest listening port.
# port=18444

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
# rpcbind=127.0.0.1

# Listen for JSON-RPC regtest connections on this port. Regtest default is 18443.
# rpcport=18443

# Connect through Tor SOCKS5 proxy
# proxy=127.0.0.1:9050

# Set the Tor control port for regtest
# torcontrol=127.0.0.1:9151

# Bind to given address and always listen on it. (default: 0.0.0.0). Use [host]:port notation for IPv6. Append =onion to tag any incoming connections to that address and port as incoming Tor connections
# bind=127.0.0.1=onion

# Only connect to peers via Tor.
# onlynet=onion

# Options only for signet
[signet]

# Listen for incoming connections on non-default signet port. Signet default is 38443.
# Changing the port number here will override the default signet listening port.
# port=38443

# Bind to given address to listen for JSON-RPC connections. This option is ignored unless
# -rpcallowip is also passed. Port is optional and overrides -rpcport. Use [host]:port notation
# for IPv6. This option can be specified multiple times. (default: 127.0.0.1 and ::1 i.e., localhost)
# rpcbind=127.0.0.1

# Listen for JSON-RPC regtest connections on this port. Signet default is 19443.
# rpcport=19443

# Connect through Tor SOCKS5 proxy
# proxy=127.0.0.1:9050

# Set the Tor control port for signet
# torcontrol=127.0.0.1:9151

# Bind to given address and always listen on it. (default: 0.0.0.0). Use [host]:port notation for IPv6. Append =onion to tag any incoming connections to that address and port as incoming Tor connections
# bind=127.0.0.1=onion

# Only connect to peers via Tor.
# onlynet=onion

EOF
printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # If chain=dualnode declaration exists, and we are running a Dual Node, then comment it out
        if grep -q ^"chain=dualnode" $DGB_CONF_FILE  && [ "$SETUP_DUAL_NODE" = "YES" ]; then

            str="Updating digibyte.conf: # chain=dualnode (Commented out to support Dual Node.)..."
            printf "%b %s" "${INFO}" "${str}"
            sed -i -e "/^chain=dualnode/s|.*|# chain=dualnode|" $DGB_CONF_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    printf "\\n"
}


# A simple function that just displays the title in a box
setup_title_box() {
     clear -x
     echo "  ╔═════════════════════════════════════════════════════════╗"
     echo "  ║                                                         ║"
     echo "  ║             ${txtbld}D I G I N O D E   S E T U P${txtrst}   $DGNT_VER_LIVE_FW     ║"
     echo "  ║                                                         ║"
     echo "  ║     Setup and manage your DigiByte & DigiAsset Node     ║"
     echo "  ║                                                         ║"
     echo "  ╚═════════════════════════════════════════════════════════╝" 
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
        printf "%b should be supported please contact $SOCIAL_BLUESKY_HANDLE on Bluesky including\\n" "${INDENT}"
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
            printf "%b Ubuntu Server 64-bit is recommended.\\n" "${INDENT}"
            printf "\\n"
            printf "%b If you believe your hardware, should be supported, then please contact\\n" "${INDENT}"
            printf "%b DigiNode Tools support on Telegram here: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
            printf "\\n"
            printf "%b Alternatively, contact $SOCIAL_BLUESKY_HANDLE on Bluesky here: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
            printf "\\n"
            purge_dgnt_settings
            exit 1
        elif [[ "$is_64bit" == "no" ]]; then
            printf "%b %bERROR: Unrecognised system architecture%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b DigiNode Setup requires a 64-bit OS (aarch64 or X86_64)\\n" "${INDENT}"
            printf "%b Ubuntu Server 64-bit is recommended.\\n" "${INDENT}"
            printf "\\n"
            printf "%b If you believe your hardware, should be supported, then please contact\\n" "${INDENT}"
            printf "%b DigiNode Tools support on Telegram here: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
            printf "\\n"
            printf "%b Alternatively, contact $SOCIAL_BLUESKY_HANDLE on Bluesky here: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
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


    ######### RPI MODEL DETECTION ###################################

    # Create local variables
    local pitype
    local pitype_check
    local mem_code
    local mem_category

    # Look for any mention of 'Raspberry Pi' so we at least know it is a Pi 
    pitype_check=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi" || echo "")
    if [[ $pitype_check == "Raspberry Pi" ]]; then
        pitype="pi"
    fi

    # Assuming it is a Pi, work out if it has enough memory
    # Reference: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#new-style-revision-codes-in-use
    if [ "$pitype" != "" ]; then

        if [ $VERBOSE_MODE = true ]; then
            echo "     ---Verbose Mode-----------"
            echo "      Revision Code: $revision" 
        fi

        # Convert the revision code from hexadecimal to decimal
        code=$((16#$revision))

        # Check if it's a new-style revision (bit 23 is set)
        new_style=$(( (code >> 23) & 0x1 ))

        if [[ $new_style -eq 1 ]]; then
            # NEW-STYLE (Pi 2 and later) - Extract memory bits (20-22)
            mem_code=$(( (code >> 20) & 0x7 ))

            # Determine memory category
            if [[ $mem_code -le 3 ]]; then # Less than 4GB
                mem_category="lowmem"
            elif [[ $mem_code -eq 4 ]]; then # 4gb RAM
                mem_category="4gb"
            else
                mem_category="8gbandup"
            fi

            if [ $VERBOSE_MODE = true ]; then
                echo "      Memory Code: $mem_code"  # Debugging line
                echo "      Memory Category: $mem_category"  # Debugging line
            fi

            # Determine RAM size based on memory code
            case $mem_code in
                0) MODELMEM="256MB" ;;
                1) MODELMEM="512MB" ;;
                2) MODELMEM="1GB" ;;
                3) MODELMEM="2GB" ;;
                4) MODELMEM="4GB" ;;
                5) MODELMEM="8GB" ;;
                6) MODELMEM="16GB" ;;
                7) MODELMEM="32GB" ;;  # Future-proofing
                8) MODELMEM="64GB" ;;  # Future-proofing
                *) MODELMEM="Unknown RAM Size" ;;  # Fallback for unexpected codes
            esac

            if [ $VERBOSE_MODE = true ]; then
                echo "      Model Memory: $MODELMEM"  # Debugging line
                
            fi

            # Detect model memory directly, if unknown
            if [ $MODELMEM = "Unknown RAM Size" ]; then
                MODELMEM=$(awk '/^MemTotal:/ { if ($2 < 1048576) printf "%.0fMB\n", $2 / 1024; else printf "%.0fGB\n", $2 / 1024 / 1024 }' /proc/meminfo)
                if [ $VERBOSE_MODE = true ]; then
                    echo "      Detecting model memory directly... $MODELMEM"
                fi
            fi

        else
            # OLD-STYLE (Pi 1, Model B, Pi Zero) - Fallback: Read memory from /proc/meminfo
            mem_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)

            if [[ $mem_kb -lt 4096000 ]]; then
                mem_category="lowmem"
            fi

            if [ $VERBOSE_MODE = true ]; then
                echo "      Fallback method..."  # Debugging line
                echo "      Memory Category: $mem_category"  # Debugging line
            fi
        fi

        if [ $VERBOSE_MODE = true ]; then
            echo "     --------------------------"
            echo ""
        fi

    fi

    # Generate Pi hardware read out
    if [ "$pitype" = "pi" ] && [ "$mem_category" = "8gbandup" ]; then
        printf "%b Raspberry Pi Detected\\n" "${TICK}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        if [[ "$RUN_SETUP" != "NO" ]] ; then
            printf "\\n"
            rpi_microsd_check
        fi
        printf "\\n"
    elif [ "$pitype" = "pi" ] && [ "$mem_category" = "4gb" ]; then
        printf "%b Raspberry Pi Detected   [ %bLOW MEMORY !!%b ]\\n" "${TICK}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        # hide this part if running DigiNode Dashboard
        if [[ "$RUN_SETUP" != "NO" ]] ; then
            printf "\\n"
            printf "%b %bWARNING: This Raspberry Pi only has 4Gb RAM%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b You should be able to run a single DigiByte node on this Raspberry Pi but\\n" "${INDENT}"   
            printf "%b performance will be sluggish. Do not attempt to run a dual node or it may crash.\\n" "${INDENT}"
            printf "%b A Raspberry Pi 4 or better with at least 8Gb RAM is recommended.\\n" "${INDENT}"
            printf "\\n"
            rpi_microsd_check
            sleep 5
        fi
        printf "\\n"
    elif [ "$pitype" = "pi" ] && [ "$mem_category" = "lowmem" ]; then
        printf "%b %bERROR: Incompatible Raspberry Pi Detected%b   [ %bLOW MEMORY !!%b ]\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b   Model: $MODEL $MODELMEM\\n" "${INDENT}"
        printf "\\n"
        printf "%b %bThis Raspberry Pi only has $MODELMEM RAM which is not enough to run a DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b A Raspberry Pi 4 or better with at least 4Gb RAM is required. 8Gb RAM is recommended.\\n" "${INDENT}"
        printf "\\n"
        purge_dgnt_settings
        exit 1
    elif [ "$pitype" = "pi" ]; then
        printf "\\n"
        printf "%b %bERROR: Unknown Raspberry Pi Detected%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b This script is currently unable to detect the memory in your Raspberry Pi.\\n" "${INDENT}"
        printf "%b Presumably this is because it is a new model that it has not seen before.\\n" "${INDENT}"
        printf "\\n"
        printf "%b Please share the information below in the DigiNode Tools Telegram group so that\\n" "${INDENT}"
        printf "%b support for your Raspberry Pi can be added:\\n" "${INDENT}"
        printf "\\n"
        printf "%b Model: %b$MODEL%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Memory: %b$MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Revision: %b$revision%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b You can find the DigiNode Tools Telegram Group here: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact $SOCIAL_BLUESKY_HANDLE on Bluesky here: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
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
        local nvme_drive=$(df | grep boot | grep -oa nvme)
        local microsd_drive=$(df | grep boot | grep -oa mmcblk0)

        str="Boot Check: "
        printf "%b %s" "${INFO}" "${str}"

        # Check for usb boot drive
        if [[ "$usb_drive" == "sda" ]]; then

            printf "%b%b %s %bPASSED%b   Raspberry Pi is booting from an external USB Drive\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"

            # If this is a Pi5 or Pi6, suggest using a PCIe NVME SSD
            pi6_check=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 6" || echo "")
            pi5_check=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 5" || echo "")
            pi4_check=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 4" || echo "")
            if [[ "$pi6_check" == "Raspberry Pi 6" ]]; then
                printf "%b   Tip: For best performance, it is recommended to use an NVME SSD connected to the PCIe port.\\n" "${INDENT}"
                printf "%b        The Pi 6 will run noticeably faster compared to the USB port.\\n" "${INDENT}"
            elif [[ "$pi5_check" == "Raspberry Pi 5" ]]; then
                printf "%b   Tip: For best performance, it is recommended to use an NVME SSD connected to the PCIe port.\\n" "${INDENT}"
                printf "%b        The Pi 5 will run noticeably faster compared to the USB port.\\n" "${INDENT}"
            elif [[ "$pi4_check" == "Raspberry Pi 4" ]]; then
                printf "%b   Tip: Booting from an SSD is stongly recommended. While a USB flash drive will\\n" "${INDENT}"
                printf "%b        work, an SSD will perform better and is less prone to data corruption.\\n" "${INDENT}"
            fi
            
            printf "\\n"
            IS_MICROSD="NO"
        fi
         # Check for nvme ssd boot drive
        if [[ "$nvme_drive" == "nvme" ]]; then
            printf "%b%b %s %bPASSED%b   Raspberry Pi is booting from a PCIe NVME SSD. 🚀\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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

    if dialog --no-shadow --keep-tite --colors --backtitle "Warning: Raspberry Pi is booting from microSD" --title "Warning: Raspberry Pi is booting from microSD" --yesno "\n\Z1WARNING: You are currently booting your Raspberry Pi from a microSD card.\Z0\n\nIt is strongly recommended to use a Solid State Drive (SSD) connected via USB for your DigiNode. MicroSD cards are prone to corruption and perform significantly slower than an SSD. For advice on recommended DigiNode hardware, visit:\n$DGBH_URL_HARDWARE\n\nSince your Raspberry Pi only has $MODELMEM RAM, if you want to proceed, you will need an empty USB stick to store the swap file. An 8Gb stick is sufficient, but 16Gb or larger is better. An SSD is still recommended, so proceed at you own risk.\n\n\nChoose Yes to indicate that you have understood this message, and wish to continue." "${r}" "${c}"; then

    #Nothing to do, continue
      printf "%b Raspberry Pi Warning: You accepted the risks of running a DigiNode from a microSD.\\n" "${INFO}"
      printf "%b You agreed to use a USB stick for your swap file, despite the risks.\\n" "${INFO}"
    else
      printf "%b DigiNode Setup exited at microSD warning message.\\n" "${INFO}"
      printf "\\n"
      exit
    fi

elif [[ "${IS_RPI}" = "YES" ]] && [[ "$IS_MICROSD" = "YES" ]]; then

    if dialog --no-shadow --keep-tite --colors --backtitle "Warning: Raspberry Pi is booting from microSD" --title "Warning: Raspberry Pi is booting from microSD" --yesno "\n\Z1WARNING: You are currently booting your Raspberry Pi from a microSD card.\Z0\n\nIt is strongly recommended to use a Solid State Drive (SSD) connected via USB for your DigiNode. A conventional Hard Disk Drive (HDD) will also work, but an SSD is preferred, being faster and more robust.\n\nMicroSD cards are prone to corruption and perform significantly slower than an SSD.\n\nFor advice on what hardware to get for your DigiNode, visit:\\n$DGBH_URL_HARDWARE\n\n\n\nChoose Yes to indicate that you have understood this message, and wish to continue installing on the microSD card." "${r}" "${c}"; then
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
        
        dialog --no-shadow --keep-tite --backtitle "Remove microSD card from the Raspberry Pi" --title "Remove microSD card from the Raspberry Pi" --msgbox "\nIf there is a microSD card in the slot on the Raspberry Pi, you can remove it. It will not be required." 8 ${c}
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
 
    # Packages required to perfom the system check (stored as an array)
    SYS_CHECK_DEPS=(grep dnsutils jq apt-transport-https)
    # Packages required to run this setup script (stored as an array)
    SETUP_DEPS=(sudo git iproute2 dialog bc gcc make ca-certificates curl gnupg wget tor)
    # Packages required to run DigiNode (stored as an array)
    DIGINODE_DEPS=(cron curl iputils-ping psmisc tmux sysstat)

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
    SYS_CHECK_DEPS=(grep bind-utils jq apt-transport-https)
    SETUP_DEPS=(git dialog iproute procps-ng which chkconfig gcc make ca-certificates curl gnupg wget tor)
    DIGINODE_DEPS=(cronie curl findutils sudo psmisc tmux sysstat)

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

    # Skip this if the --skippkgupdate flag is used
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
            printf "%b You can skip the package update check using the --skippkgupdate flag.\\n" "${INDENT}"
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
        # This function gets a list of supported OS versions from a TXT record at versions.diginode.tools
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
                printf "%b please get in touch via the contact details below.\\n" "${INDENT}"  
            fi
            printf "\\n"
            printf "%b If you wish to attempt to continue anyway, you can try one of the\\n" "${INDENT}" 
            printf "%b following commands to skip this check:\\n" "${INDENT}" 
            printf "\\n"
            printf "%b e.g: If you are seeing this message on a fresh install, you can run:\\n" "${INDENT}" 
            printf "%b   %bcurl -sSL $DGNT_SETUP_OFFICIAL_URL | bash -s -- --skiposcheck%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b It is possible that the installation will still fail at this stage\\n" "${INDENT}" 
            printf "%b due to an unsupported configuration.\\n" "${INDENT}"
            printf "\\n"
            printf "%b For help, contact $SOCIAL_BLUESKY_HANDLE on Bluesky: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
            printf "%b Alternatively, ask in the 'DigiNode Tools' Telegram group: ${SOCIAL_TELEGRAM_URL}\\n" "${INDENT}" 
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

# Function to check if the hostname of the machine is set to 'diginode' or 'diginode-testnet'
hostname_check() {

    printf " =============== Checking: Hostname ====================================\\n\\n"
    # ==============================================================================


# This is a new mainnet install, and the hostname is already 'diginode'
if [[ "$HOSTNAME" == "diginode" ]] && [[ "$NewInstall" = true ]] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then

    printf "%b Hostname Check: %bPASSED%b   Hostname is set to: $HOSTNAME\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    INSTALL_AVAHI="YES"
    HOSTNAME_DO_CHANGE="NO"

# This is a new testnet install, and the hostname is already 'diginode-testnet'
elif [[ "$HOSTNAME" == "diginode-testnet" ]] && [[ "$NewInstall" = true ]] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then

    printf "%b Hostname Check: %bPASSED%b   Hostname is set to: $HOSTNAME\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    INSTALL_AVAHI="YES"
    HOSTNAME_DO_CHANGE="NO"

# This is an existing mainnet install, and the hostname is already 'diginode'
elif [[ "$HOSTNAME" == "diginode" ]] && [ "$DGB_NETWORK_OLD" = "MAINNET" ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then

    printf "%b Hostname Check: %bPASSED%b   Hostname is set to: $HOSTNAME\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    INSTALL_AVAHI="YES"
    HOSTNAME_DO_CHANGE="NO"

# This is an existing testnet install, and the hostname is already 'diginode-testnet'
elif [[ "$HOSTNAME" == "diginode-testnet" ]] && [ "$DGB_NETWORK_OLD" = "TESTNET" ] && [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then

    printf "%b Hostname Check: %bPASSED%b   Hostname is set to: $HOSTNAME\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    INSTALL_AVAHI="YES"
    HOSTNAME_DO_CHANGE="NO"

# An existing mainnet install which has the hostname 'diginode' has been converted to testnet
elif [[ "$HOSTNAME" == "diginode" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_OLD" = "MAINNET" ] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then
 
    printf "%b Hostname Check: %bFAILED%b   Recommend changing Hostname to 'diginode-testnet'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    if [ "$UNATTENDED_MODE" == true ]; then
        printf "%b Important: It is recommended that you change your hostname to 'diginode-testnet'\\n"  "${INFO}"
        printf "%b Your hostname is currently '$HOSTNAME'. Since you have just switched to\\n"  "${INDENT}"
        printf "%b to running a DigiByte testnet node it is advisable to change the hostname\\n"  "${INDENT}"
        printf "%b to 'diginode-testnet'. This is optional but recommended, since it will ensure\\n"  "${INDENT}"
        printf "%b the current hostname does not conflict with another DigiByte mainnet node on\\n"  "${INDENT}"
        printf "%b your network. If you are planning to run two DigiNodes on your network,\\n"  "${INDENT}"
        printf "%b one on DigiByte MAINNET and the other on TESTNET, it is advisable to give\\n"  "${INDENT}"
        printf "%b them different hostnames on your network so they are easier to identify.\\n"  "${INDENT}"
        printf "\\n"
    else
        printf "%b Asking to change hostname from 'diginode' to 'diginode-testnet'...\\n"  "${INFO}"
        printf "\\n"
    fi
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

# An existing testnet install which has the hostname 'diginode-testnet' has been converted to mainnet
elif [[ "$HOSTNAME" == "diginode-testnet" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_OLD" = "TESTNET" ] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then
 
    printf "%b Hostname Check: %bFAILED%b   Recommend changing Hostname to 'diginode'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    if [ "$UNATTENDED_MODE" == true ]; then
        printf "%b Important: It is recommended that you change your hostname to 'diginode-testnet'\\n"  "${INFO}"
        printf "%b Your hostname is currently '$HOSTNAME'. Since you have just switched to\\n"  "${INDENT}"
        printf "%b running a DigiByte mainnet node, it is advisable to change the hostname\\n"  "${INDENT}"
        printf "%b to 'diginode' . This is optional but recommended, since it will ensure\\n"  "${INDENT}"
        printf "%b the current hostname does not conflict with another DigiByte testnet node on\\n"  "${INDENT}"
        printf "%b your network. If you are planning to run two DigiNodes on your network, one on\\n"  "${INDENT}"
        printf "%b DigiByte MAINNET and the other on TESTNET, it is advisable to give them different\\n"  "${INDENT}"
        printf "%b hostnames on your network so they are easier to identify.\\n"  "${INDENT}"
        printf "\\n"
    else
        printf "%b Asking to change hostname from 'diginode-testnet' to 'diginode'...\\n"  "${INFO}"
        printf "\\n"
    fi
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

# Unable to discover the hostname
elif [[ "$HOSTNAME" == "" ]]; then
    printf "%b Hostname Check: %bERROR%b   Unable to check hostname\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    printf "%b DigiNode Setup currently assumes it will always be able to discover the\\n" "${INDENT}"
    printf "%b current hostname. It is therefore assumed that noone will ever see this error message!\\n" "${INDENT}"
    printf "%b If you have, please contact $SOCIAL_BLUESKY_HANDLE on Bluesky: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
    printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
    printf "\\n"
    exit 1

# An existing install which has some random hostname has been converted to testnet
elif [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then
    printf "%b Hostname Check: %bFAILED%b   Recommend changing Hostname to 'diginode-testnet'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    if [ "$UNATTENDED_MODE" == true ]; then
        printf "%b Your hostname is currently '$HOSTNAME'. It is advisable to change this to 'diginode-testnet'.\\n"  "${INFO}"
        printf "%b This is optional but recommended, since it will make the DigiAssets website available at\\n"  "${INDENT}"
        printf "%b https://diginode-testnet.local which is obviously easier than remembering an IP address.\\n"  "${INDENT}"
        printf "%b If you are planning to run two DigiNodes on your network, one on the DigiByte MAINNET\\n"  "${INDENT}"
        printf "%b and the other on TESTNET, it is advisable to give them different hostnames on your\\n"  "${INDENT}"
        printf "%b network so they are easier to identify and do not conflict with one another.\\n"  "${INDENT}"
    else
        printf "%b Asking to change hostname from '$HOSTNAME' to 'diginode-testnet'...\\n"  "${INFO}"
    fi
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

# An existing install which has some random hostname has been converted to mainnet
elif [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then
    printf "%b Hostname Check: %bFAILED%b   Hostname is not set to 'diginode'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    if [ "$UNATTENDED_MODE" == true ]; then
        printf "%b Your hostname is currently '$HOSTNAME'. It is advisable to change this to 'diginode'.\\n"  "${INFO}"
        printf "%b This is optional but recommended, since it will make the DigiAssets website available at\\n"  "${INDENT}"
        printf "%b https://diginode.local which is obviously easier than remembering an IP address.\\n"  "${INDENT}"
    else
        printf "%b Asking to change hostname from '$HOSTNAME' to 'diginode'...\\n"  "${INFO}"
    fi
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

# A new testnet install, and the hostname is still 'diginode' from a previous install
elif [[ "$HOSTNAME" = "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then
    printf "%b Hostname Check: %bFAILED%b   Recommend changing Hostname to 'diginode-testnet'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    if [ "$UNATTENDED_MODE" == true ]; then
        printf "%b Your hostname is currently '$HOSTNAME'. It is recommended to change this to 'diginode-testnet'.\\n"  "${INFO}"
        printf "%b If you are running your DigiNode on a dedicated device on your local network, \\n"  "${INDENT}"
        printf "%b then this change is recommended. It will ensure that the hostname reflects that the\\n"  "${INDENT}"
        printf "%b DigiNode is running on testnet and not mainnet. Furthermore, if you are planning to\\n"  "${INDENT}"
        printf "%b run two DigiNodes on your network, one on the DigiByte mainnet and the other on\\n"  "${INDENT}"
        printf "%b testnet, this will ensure that they do not conflict with each other.\\n"  "${INDENT}"
    else
        printf "%b Asking to change hostname from '$HOSTNAME' to 'diginode-testnet'...\\n"  "${INFO}"
    fi
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

# A new mainnet install, and the hostname is still 'diginode-testnet' from a previous install
elif [[ "$HOSTNAME" = "diginode-testnet" ]] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then
    printf "%b Hostname Check: %bFAILED%b   Recommend changing Hostname to 'diginode'\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    if [ "$UNATTENDED_MODE" == true ]; then
        printf "%b Your hostname is currently '$HOSTNAME'. It is recommended to change this to 'diginode'.\\n"  "${INFO}"
        printf "%b If you are running your DigiNode on a dedicated device on your local network, \\n"  "${INDENT}"
        printf "%b then this change is recommended. It will ensure that the hostname reflects that the\\n"  "${INDENT}"
        printf "%b DigiNode is running on mainnet and not testnet. Furthermore, if you are planning to\\n"  "${INDENT}"
        printf "%b run two DigiNodes on your network, one on the DigiByte mainnet and the other on\\n"  "${INDENT}"
        printf "%b testnet, this will ensure that they do not conflict with each other.\\n"  "${INDENT}"
    else
        printf "%b Asking to change hostname from '$HOSTNAME' to 'diginode'...\\n"  "${INFO}"
    fi
    printf "\\n"
    HOSTNAME_ASK_CHANGE="YES"
    printf "\\n"

# We re running on MAINNET or SIGNET.
elif [[ "$DGB_NETWORK_FINAL" = "REGTEST" ]] || [[ "$DGB_NETWORK_FINAL" = "SIGNET" ]]; then
    printf "%b Hostname Check: %bFAILED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    printf "%b WARNING: You are currently running DigiByte Core on the $DGB_NETWORK_FINAL chain.\\n"  "${INFO}"
    printf "%b Your hostname is currently '$HOSTNAME'. If you are running another DigNode,\\n"  "${INDENT}"
    printf "%b on your network, make sure that it is not also using the same hostname.\\n"  "${INDENT}"
    printf "%b If you are, you may experience issues with ports clashing. \\n"  "${INDENT}"
    printf "\\n"
    HOSTNAME_DO_CHANGE="NO"
    printf "\\n"
fi

}

# Display a request to change the hostname, if needed
hostname_ask_change() {

if [ ! "$UNATTENDED_MODE" == true ]; then

    # An existing mainnet install which has the hostname 'diginode' has been converted to testnet
    if [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" == "diginode" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_OLD" = "MAINNET" ] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Changing your hostname to 'diginode-testnet' is recommended." --title "Changing your hostname to 'diginode-testnet' is recommended." --yesno "\nYour hostname is currently '$HOSTNAME'.\n\n\Z4Would you like to change your hostname to 'diginode-testnet'?\Z0\n\nIf you are running your DigiNode on a dedicated device on your local network, then this change is recommended. It will ensure that the hostname reflects that the DigiNode is running on testnet and not mainnet. Furthermore, if you are planning to run two DigiNodes on your network, one on DigiByte mainnet and the other on testnet, this change will ensure that they do not conflict with each other.\n\nNote: If you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you may not want to change its hostname." 21 "${c}"; then

            HOSTNAME_DO_CHANGE="YES"
            HOSTNAME_CHANGE_TO="diginode-testnet"
            INSTALL_AVAHI="YES"

            printf "%b You chose to change your hostname to: diginode-testnet\\n" "${INFO}"
            printf "\\n"
        else
            printf "%b You chose NOT to change your hostname to: diginode-testnet (it will remain as diginode).\\n" "${INFO}"
            printf "\\n"
        fi

    # An existing testnet install which has the hostname 'diginode-testnet' has been converted to mainnet
    elif [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" == "diginode-testnet" ]] && [[ "$DGB_NETWORK_IS_CHANGED" = "YES" ]] && [ "$DGB_NETWORK_OLD" = "TESTNET" ] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Changing your hostname to 'diginode' is recommended." --title "Changing your hostname to 'diginode' is recommended." --yesno "\nYour hostname is currently '$HOSTNAME'.\n\n\Z4Would you like to change your hostname to 'diginode'?\Z0\n\nIf you are running your DigiNode on a dedicated device on your local network, then this change is recommended. It will ensure that the hostname reflects that the DigiNode is running on mainnet and not testnet. Furthermore, if you are planning to run two DigiNodes on your network, one on DigiByte mainnet and the other on testnet, this change will ensure that they do not conflict with each other.\\n\\nNote: If you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you may not want to change its hostname." 21 "${c}"; then

            HOSTNAME_DO_CHANGE="YES"
            HOSTNAME_CHANGE_TO="diginode"
            INSTALL_AVAHI="YES"

            printf "%b You chose to change your hostname to: diginode\\n" "${INFO}"
            printf "\\n"
        else
            printf "%b You chose NOT to change your hostname to: diginode (it will remain as diginode-testnet).\\n" "${INFO}"
            printf "\\n"
        fi

    # An existing install which has some random hostname has been converted to testnet
    elif [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Changing your hostname to 'diginode-test' is recommended." --title "Changing your hostname to 'diginode-test' is recommended." --yesno "\nYour hostname is currently '$HOSTNAME'.\n\n\Z4Would you like to change your hostname to 'diginode-testnet'?\Z0\n\nIf you are running your DigiNode on a dedicated device on your local network, then this is recommended, since it will make the DigiAssets website available at http://diginode-testnet.local:8090 which is obviously easier than remembering an IP address.\n\nFurthermore, if you are planning to run two DigiNodes on your network, one on DigiByte mainnet and the other on testnet, this change will ensure that they do not conflict with each other.\\n\\nNote: If you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you may not want to change its hostname." 22 "${c}"; then

            HOSTNAME_DO_CHANGE="YES"
            HOSTNAME_CHANGE_TO="diginode-testnet"
            INSTALL_AVAHI="YES"

            printf "%b You chose to change your hostname to: diginode-testnet\\n" "${INFO}"
            printf "\\n"
        else
            printf "%b You chose NOT to change your hostname to: diginode-testnet.\\n" "${INFO}"
            printf "\\n"
        fi

    # An existing install which has some random hostname has been converted to mainnet
    elif [[ "$HOSTNAME_ASK_CHANGE" = "YES" ]] && [[ "$HOSTNAME" != "diginode-testnet" ]] && [[ "$HOSTNAME" != "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Changing your hostname to 'diginode' is recommended." --title "Changing your hostname to 'diginode' is recommended." --yesno "\nYour hostname is currently '$HOSTNAME'.\n\n\Z4Would you like to change your hostname to 'diginode'?\Z0\\n\\nIf you are running your DigiNode on a dedicated device on your local network, then this is recommended, since it will make the DigiAssets website available at http://diginode.local:8090 which is obviously easier than remembering an IP address.\n\nNote: If you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you likely do not want to change its hostname." 18 "${c}"; then

          HOSTNAME_DO_CHANGE="YES"
          HOSTNAME_CHANGE_TO="diginode"
          INSTALL_AVAHI="YES"

          printf "%b You chose to change your hostname to: diginode.\\n" "${INFO}"
          printf "\\n"
        else
          printf "%b You chose NOT to change your hostname to: diginode.\\n" "${INFO}"
          printf "\\n"
        fi

    # A new mainnet install, and the hostname is still 'diginode-testnet' from a previous install
    elif [[ "$HOSTNAME" = "diginode-testnet" ]] && [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Changing your hostname to 'diginode' is recommended." --title "Changing your hostname to 'diginode' is recommended." --yesno "\nYour hostname is currently '$HOSTNAME'.\n\n\Z4Would you like to change your hostname to 'diginode'?\Z0\n\nIf you are running your DigiNode on a dedicated device on your local network, then this is recommended. It will ensure that the hostname reflects that the DigiNode is running on mainnet and not testnet. Furthermore, if you are planning to run two DigiNodes on your network, one on the DigiByte mainnet and the other on testnet, this change will ensure that they do not conflict with each other.\n\nNote: If you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you likely do not want to change its hostname." 21 "${c}"; then

          HOSTNAME_DO_CHANGE="YES"
          HOSTNAME_CHANGE_TO="diginode"
          INSTALL_AVAHI="YES"

          printf "%b You chose to change your hostname to: diginode.\\n" "${INFO}"
          printf "\\n"
        else
          printf "%b You chose NOT to change your hostname to: diginode.\\n" "${INFO}"
          printf "\\n"
        fi

    # A new testnet install, and the hostname is still 'diginode' from a previous install
    elif [[ "$HOSTNAME" = "diginode" ]] && [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Changing your hostname to 'diginode-test' is recommended." --title "Changing your hostname to 'diginode-test' is recommended." --yesno "\nYour hostname is currently '$HOSTNAME'.\n\n\Z4Would you like to change your hostname to 'diginode-testnet'?\Z0\n\nIf you running your DigiNode on a dedicated device on your local network, then this is recommended. It will ensure that the hostname reflects that the DigiNode is running on testnet and not mainnet. Furthermore, if you are planning to run two DigiNodes on your network, one on the DigiByte mainnet and the other on testnet, this change will ensure that they do not conflict with each other.\n\nNote: If you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you likely do not want to change its hostname." 21 "${c}"; then

          HOSTNAME_DO_CHANGE="YES"
          HOSTNAME_CHANGE_TO="diginode-testnet"
          INSTALL_AVAHI="YES"

          printf "%b You chose to change your hostname to: diginode-testnet.\\n" "${INFO}"
          printf "\\n"
        else
          printf "%b You chose NOT to change your hostname to: diginode-testnet.\\n" "${INFO}"
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

if [[ "$NewInstall" = true ]] && [[ "$UNATTENDED_MODE" == true ]] && [[ "$UI_HOSTNAME_SET" = "YES" ]] && [ "$UI_DGB_CHAIN" = "MAINNET" ] && [[ "$HOSTNAME" != "diginode" ]]; then

        HOSTNAME_DO_CHANGE="YES"

elif [[ "$NewInstall" = true ]] && [[ "$UNATTENDED_MODE" == true ]] && [[ "$UI_HOSTNAME_SET" = "YES" ]] && [ "$UI_DGB_CHAIN" = "DUALNODE" ] && [[ "$HOSTNAME" != "diginode" ]]; then

        HOSTNAME_DO_CHANGE="YES"

elif [[ "$NewInstall" = true ]] && [[ "$UNATTENDED_MODE" == true ]] && [[ "$UI_HOSTNAME_SET" = "YES" ]] && [ "$UI_DGB_CHAIN" = "TESTNET" ] && [[ "$HOSTNAME" != "diginode-testnet" ]]; then

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

        if dialog --no-shadow --keep-tite --colors --backtitle "Installing as user 'digibyte' is recommended." --title "Installing as user 'digibyte' is recommended." --yes-label "Yes (Recommended)" --no-label "No" --yesno "\nIt is recommended that you login as 'digibyte' before installing your DigiNode.\n\nThis is optional but encouraged, since it will isolate your DigiByte wallet its own user account.\n\nFor more information visit:\n  $DGBH_URL_USERCHANGE\n\n\nThere is already a 'digibyte' user account on this machine, but you are not currently using it - you are signed in as '$USER_ACCOUNT'. Would you like to switch users now?\n\nChoose YES to exit and login as 'digibyte' from where you can run DigiNode Setup again.\n\nChoose NO to continue installation as '$USER_ACCOUNT'." "${r}" "${c}"; then

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

        if dialog --no-shadow --keep-tite --colors --backtitle "Creating a new 'digibyte' user is recommended." --title "Creating a new 'digibyte' user is recommended." --yes-label "Yes (Recommended)" --no-label "No" --yesno "\nIt is recommended that you create a new 'digibyte' user for your DigiNode.\n\nThis is optional but encouraged, since it will isolate your DigiByte wallet in its own user account.\n\nFor more information visit:\\n$DGBH_URL_USERCHANGE\n\n\nYou are currently signed in as user '$USER_ACCOUNT'. Would you like to create a new 'digibyte' user now?\n\nChoose YES to create and sign in to the new user account, from where you can run DigiNode Setup again.\\n\\nChoose NO to continue installation as '$USER_ACCOUNT'." "${r}" "${c}"; then

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

    DGB_USER_PASS1=$(dialog --no-shadow --keep-tite --colors --backtitle "Choose a password" --title "Choose a password" --insecure --passwordbox "\nPlease choose a password for the new 'digibyte' user.\n\nIMPORTANT: Don't forget this - you will need it to access your DigiNode! \n\n\n" 11 78 3>&1 1>&2 2>&3)
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

    DGB_USER_PASS2=$(dialog --no-shadow --keep-tite --colors --backtitle "Please re-enter the password to confirm." --title "Please re-enter the password to confirm." --insecure --passwordbox "\nPlease re-enter the password to confirm." 8 78 3>&1 1>&2 2>&3)
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
            dialog --no-shadow --keep-tite --backtitle "Passwords do not match!" --title "Passwords do not match!" --msgbox "\nThe passwords do not match. Please try again." 7 ${c}
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
        printf "%b Since a FULL DigiNode can require up to 10Gb RAM, as a bare minimum you should\\n" "${INDENT}"
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
            if dialog --no-shadow --keep-tite --colors --backtitle "Swap file is too small." --title "Swap file is too small." --yes-label "Continue" --no-label "Exit" --yesno "\n\Z1WARNING: Your swap file is too small.\Z0\n\nA DigiByte Node typically requires around 6Gb RAM but this can reach 8Gb or more during the intial sync. A DigiAsset Node requires around 3Gb RAM. In total, a FULL DigiNode running both can require up to 12Gb RAM.\n\nIt is always advisable to have a swap file even if your system has enough RAM. As a bare minimum you should ensure that your total memory (system RAM and swap file combined) is not less than 12Gb. 16Gb is recommended. \n\nWould you like to create a new swap file now?\n\n\nChoose CONTINUE to create a new swap file.\n\nChoose EXIT to quit DigiNode Setup." "${r}" "${c}"; then
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

            if dialog --no-shadow --keep-tite --colors --backtitle "Swap file not detected." --title "Swap file not detected." --yes-label "Continue" --no-label "Exit" --yesno "\n\Z1WARNING: You need to create a swap file.\Z0\n\nA DigiByte Node typically requires around 6Gb RAM but this can reach 8Gb or more during the intial sync. A DigiAsset Node requires around 3Gb RAM. In total, a FULL DigiNode running both can require up to 12Gb RAM.\\n\\nIt is always advisable to have a swap file even if your system has enough RAM. As a bare minimum you should ensure that your total memory (system RAM and swap file combined) is not less than 12Gb. 16Gb is recommended.\n\nChoose CONTINUE To have DigiNode Setup assist you in creating a new swap file.\n\nChoose EXIT to quit DigiNode Setup and create a new swap file manually." 23 "${c}"; then

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
                if dialog --no-shadow --keep-tite --colors --backtitle "USB stick required." --title "USB stick required." --yes-label "Continue" --no-label "Exit" --yesno "\nYou will need a USB stick to store your Swap file.\n\nSince you are running your system off a microSD card, and this Pi only has $MODELMEM RAM, you need to use a USB stick connected to your Pi to store your Swap file:\n\n - Minimum capacity is 16Gb.\n - For best performance it should support USB 3.0 or greater.\n\n\Z1WARNING: The existing contents of the USB stick will be erased. Do not insert it into the Pi yet. If it is already plugged in, please UNPLUG it now before continuing.\Z0\n\nChoose CONTINUE once you are ready, with the USB stick unplugged.\n\nChoose EXIT to quit DigiNode Setup and create a swap file manually." "${r}" "${c}"; then

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
                    dialog --no-shadow --keep-tite --backtitle "USB Swap Setup Cancelled" --title "USB Swap Setup Cancelled" --msgbox "\nYou cancelled the USB backup." 7 ${c}
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
        SWAP_TARG_SIZE_MB=$(dialog --no-shadow --keep-tite --backtitle "Enter swap file size" --title "Enter swap file size" --inputbox "\nPlease enter the desired swap file size in MB.\n\nNote: As a bare minimum, you should ensure that your total memory (system RAM + swap file) is at least 12GB, but 16GB is recommended to avoid any issues. Since your system has ${RAMTOTAL_HR}b RAM, it is recommended to create a swap file of at least $SWAP_REC_SIZE_HR.\n\nThe recommended size has been entered for you. If you are unsure, use this." "${r}" "${c}" "$SWAP_REC_SIZE_MB" 3>&1 1>&2 2>&3)


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
            dialog --no-shadow --keep-tite --backtitle "Swap file size is too small" --title "Swap file size is too small" --msgbox "\nThe swap file size you entered is not big enough." 7 ${c}
            printf "%b The swap file size you entered was too small.\\n" "${INFO}"
            skip_if_reentering_swap_size="yes"
            swap_ask_change
        fi

        SWAP_DO_CHANGE="YES"
        printf "\\n"

    fi

fi

}

# Check the DigiByte wallet folders exist, and default wallets are in the correct location, depending on the current DigiByte version
check_digibyte_wallets() {

    local restart_primary_node=""
    local restart_secondary_node=""

    # create ~/.digibyte/wallets folder if it does not exist
    if [ ! -d "$DGNT_SETTINGS_LOCATION/wallets" ]; then
        str="Creating ~/.digibyte/wallets folder..."
        printf "\\n%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mkdir $DGNT_SETTINGS_LOCATION/wallets
    fi

    # create ~/.digibyte/testnet4/wallets folder if it does not exist
    if [ ! -d "$DGNT_SETTINGS_LOCATION/testnet4/wallets" ]; then
        str="Creating ~/.digibyte/testnet4/wallets folder..."
        printf "\\n%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mkdir $DGNT_SETTINGS_LOCATION/testnet4/wallets
    fi

    # If the local DigiByte version is 7.17.3 make sure default wallet is in ~/.digibyte
    if [ "$DGB_VER_LOCAL" = "7.17.3" ]; then

        if [ ! -f ~/.digibyte/wallet.dat ] && [ -f ~/.digibyte/wallets/wallet.dat ]; then
            echo "temp"
        fi

    # If the local DigiByte version is 8.22.0-rcx or better (anything other than 7.17.3) make sure default wallet is in ~/.digibyte/wallets
    elif [ "$DGB_VER_LOCAL" != "7.17.3" ] && [ "$DGB_VER_LOCAL" != "" ]; then

        if [ -f ~/.digibyte/wallet.dat ] && [ ! -f ~/.digibyte/wallets/wallet.dat ]; then

            # If this is primary node running mainnet, unload the wallet
            if check_service_active "digibyted" && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then

                # Check if the default mainnet wallet is loaded
                query_wallets=$($DGB_CLI listwallets 2>/dev/null)
                if echo "$query_wallets" | jq -e '.[] | select(. == "")' > /dev/null; then

                    printf "%b Default Mainnet Wallet is loaded. Trying to unload it...\\n" "${INFO}"
                    
                    # Attempt to unload the default wallet
                    unload_result=$($DGB_CLI unloadwallet "" 2>&1)
                    if [[ $unload_result == *"error code:"* ]] || [[ $unload_result == *"error message:"* ]]; then
                        printf "%b Error unloading default wallet: $unload_result\\n" "${INFO}"
                        printf "%b Stopping DigiByte $DGB_NETWORK_CURRENT node ...\\n" "${INFO}"
                        stop_service digibyted
                        restart_primary_node="yes"
                    else
                        printf "%b Default Mainnet Wallet unloaded successfully.\\n" "${TICK}"
                    fi
                else
                    printf "%b Default Mainnet Wallet is not loaded.\\n" "${TICK}"
                fi
            else
                printf "%b DigiByte MAINNET Node is not running. Skipping default wallet check.\\n" "${INFO}"
            fi

            # Move the legacy wallet.dat file to the /wallets subfolder
            str="Moving ~/.digibyte/wallet.dat to ~/.digibyte/wallets/wallet.dat ..."
            printf "%b %s" "${INFO}" "${str}"
            mv ~/.digibyte/wallet.dat ~/.digibyte/wallets/wallet.dat
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Reload the wallet.dat in its new location, if the node is actually running
            if check_service_active "digibyted" && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
                printf "%b Reloading default mainnet wallet from new location...\\n" "${INFO}"
                load_result=$($DGB_CLI loadwallet "wallets/wallet.dat" 2>&1)
                if [[ $load_result == *"error code:"* ]] || [[ $load_result == *"error message:"* ]]; then
                    printf "%b Error loading default mainnet wallet: $load_result\\n" "${CROSS}"
                else
                    printf "%b Default Mainnet Wallet loaded successfully from new location.\\n" "${TICK}"
                fi
            fi

            # Restart the node if it was just stopped
            if [ "$restart_primary_node" = "yes" ]; then
                printf "%b Restarting DigiByte $DGB_NETWORK_CURRENT node ...\\n" "${INFO}"
                restart_service digibyted
            fi

        fi

        if [ -f ~/.digibyte/testnet4/wallet.dat ] && [ ! -f ~/.digibyte/testnet4/wallets/wallet.dat ]; then

            # If this is primary node running testnet, unload the wallet
            if check_service_active "digibyted" && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then

                # Check if the default testnet wallet is loaded
                query_wallets=$($DGB_CLI listwallets 2>/dev/null)
                if echo "$query_wallets" | jq -e '.[] | select(. == "")' > /dev/null; then

                    printf "%b Default Testnet Wallet is loaded. Trying to unload it...\\n" "${INFO}"
                    
                    # Attempt to unload the default wallet
                    unload_result=$($DGB_CLI unloadwallet "" 2>&1)
                    if [[ $unload_result == *"error code:"* ]] || [[ $unload_result == *"error message:"* ]]; then
                        printf "%b Error unloading default wallet: $unload_result\\n" "${INFO}"
                        printf "%b Stopping DigiByte $DGB_NETWORK_CURRENT node ...\\n" "${INFO}"
                        stop_service digibyted
                        restart_primary_node="yes"
                    else
                        printf "%b Default Testnet Wallet unloaded successfully.\\n" "${TICK}"
                    fi
                else
                    printf "%b Default Testnet Wallet is not loaded.\\n" "${TICK}"
                fi
            # Or, if this is secondary node running testnet, unload the wallet
            elif check_service_active "digibyted-testnet"; then

                # Check if the default testnet wallet is loaded
                query_wallets=$($DGB_CLI -testnet listwallets 2>/dev/null)
                if echo "$query_wallets" | jq -e '.[] | select(. == "")' > /dev/null; then

                    printf "%b Default Testnet Wallet is loaded. Trying to unload it...\\n" "${INFO}"
                    
                    # Attempt to unload the default wallet
                    unload_result=$($DGB_CLI -testnet unloadwallet "" 2>&1)
                    if [[ $unload_result == *"error code:"* ]] || [[ $unload_result == *"error message:"* ]]; then
                        printf "%b Error unloading default wallet: $unload_result\\n" "${INFO}"
                        printf "%b Stopping DigiByte TESTNET node ...\\n" "${INFO}"
                        stop_service digibyted-testnet
                        restart_secondary_node="yes"
                    else
                        printf "%b Default Testnet Wallet unloaded successfully.\\n" "${TICK}"
                    fi
                else
                    printf "%b Default Testnet Wallet is not loaded.\\n" "${TICK}"
                fi
            else
                printf "%b DigiByte TESTNET Node is not running. Skipping default wallet check.\\n" "${INFO}"
            fi

            # Move the legacy wallet.dat file to the /wallets subfolder
            str="Moving ~/.digibyte/wallet.dat to ~/.digibyte/wallets/wallet.dat ..."
            printf "%b %s" "${INFO}" "${str}"
            mv ~/.digibyte/wallet.dat ~/.digibyte/wallets/wallet.dat
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Reload the wallet.dat in its new location, if the node is still running
            if check_service_active "digibyted" && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
                printf "%b Reloading default testnet wallet from new location...\\n" "${INFO}"
                load_result=$($DGB_CLI loadwallet "wallets/wallet.dat" 2>&1)
                if [[ $load_result == *"error code:"* ]] || [[ $load_result == *"error message:"* ]]; then
                    printf "%b Error loading default testnet wallet: $load_result\\n" "${CROSS}"
                else
                    printf "%b Default Testnet Wallet loaded successfully from new location.\\n" "${TICK}"
                fi
            elif check_service_active "digibyted-testnet"; then
                printf "%b Reloading default testnet wallet from new location...\\n" "${INFO}"
                load_result=$($DGB_CLI -testnet loadwallet "wallets/wallet.dat" 2>&1)
                if [[ $load_result == *"error code:"* ]] || [[ $load_result == *"error message:"* ]]; then
                    printf "%b Error loading default Testnet wallet: $load_result\\n" "${CROSS}"
                else
                    printf "%b Default Testnet Wallet loaded successfully from new location.\\n" "${TICK}"
                fi
            fi

            # Restart the node if it was just stopped
            if [ "$restart_primary_node" = "yes" ]; then
                printf "%b Restarting DigiByte $DGB_NETWORK_CURRENT node ...\\n" "${INFO}"
                restart_service digibyted
            fi
            if [ "$restart_secondary_node" = "yes" ]; then
                printf "%b Restarting DigiByte TESTNET node ...\\n" "${INFO}"
                restart_service digibyted-testnet
            fi

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
                dialog --no-shadow --keep-tite --backtitle "Swap file created on USB stick" --title "Swap file created on USB stick" --msgbox "\nThe swap file has been setup on the USB stick. Do not unplug it or the DigiNode will not work." 8 ${c}
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
                dialog --no-shadow --keep-tite --backtitle "Swap file created on USB stick" --title "Swap file created on USB stick" --msgbox "\nThe swap file has been setup on the USB stick. Do not unplug it or the DigiNode will not work." 8 ${c}

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
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Backup" --title "DigiNode Backup" --yes-label "Continue" --no-label "Exit" --yesno "\nThis tool helps you backup your DigiByte wallet and/or DigiAsset Node settings to a USB stick.\n\nIt is recommended that you use a USB stick that is not used for anything else, and that you store it somewhere safe and secure.\n\nYou do not require a lot of space for the backup - any small USB stick is fine. For best results, make sure it is formatted with exFAT.\n\n\Z1IMPORTANT: To perform a backup, you need access to a free USB slot on your DigiNode. If your DigiNode is running in the cloud, you may not be able to use this tool.\Z0" 19 "${c}"; then
            printf "%b You chose to begin the backup process.\\n\\n" "${INFO}"
        else
            printf "%b You chose not to begin the backup process. Returning to menu...\\n" "${INFO}"
            printf "\\n"
            menu_existing_install 
        fi

        # Ask to backup DigiByte Core Wallet, if it exists
        if [ -f "$DGB_SETTINGS_LOCATION/wallet.dat" ]; then


            # Ask if the user wants to backup their DigiBytewallet
            if dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Wallet Backup" --title "DigiByte Wallet Backup" --yes-label "Yes (Recommended)" --no-label "No" --yesno "\n\Z4Would you like to backup your DigiByte wallet to the USB stick?\Z0\n\nThis is highly recomended, if you have not already done so. It will safeguard the contents of your DigiByte wallet and makes it easy to restore your DigiByte wallet in the event of a hardware failure, or to move your DigiNode to a new device." 12 "${c}"; then

                run_wallet_backup=true
            else
                run_wallet_backup=false
            fi
        else
            printf "%b No DigiByte Core wallet file currently exists. Returning to menu...\\n" "${INFO}"
            run_wallet_backup=false
            # Display a message saying that the wallet.dat file does not exist
            dialog --no-shadow --keep-tite --backtitle "DigiByte Wallet not found" --title "DigiByte Wallet not found" --msgbox "\nNo DigiByte Core wallet.dat file currently exists to backup. The script will exit." 8 ${c}
            printf "\\n"
            menu_existing_install   
            printf "\\n"
        fi

        # Ask to backup the DigiAsset Node _config folder, if it exists
        if [ -d "$DGA_SETTINGS_LOCATION" ]; then

            # Ask the user if they want to backup their DigiAsset Node settings
            if dialog --no-shadow --keep-tite --colors --backtitle "DigiAsset Node Backup" --title "DigiAsset Node Backup" --yes-label "Yes (Recommended)" --no-label "No" --yesno "\n\Z4Would you like to backup your DigiAsset Node settings to the USB stick?\Z0\n\nThis will backup your DigiAsset Node _config folder which stores your Amazon web services credentials, RPC password etc. It means you can quickly restore your DigiNode in the event of a hardware failure, or if you wish to move your DigiNode to a different device.\\n\\nNote: Before creating a backup, it is advisable to have first completed setting up your DigiAsset Node via the web UI." 17 "${c}"; then

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
        

            # Run the check_digibyte_core function, because we need to be sure that DigiByte Core is not only running, 
            # but has also completely finished starting up, and this function will wait until it has finished starting up before continuing.
            check_digibyte_core

            printf " =============== Checking: DigiByte Wallet =============================\\n\\n"
            # ==============================================================================

            # Check if the wallet is currently unencrypted
            IS_WALLET_ENCRYPTED=$(sudo -u $USER_ACCOUNT $DGB_CLI walletlock 2>&1 | grep -Eo "running with an unencrypted wallet")
            if [ "$IS_WALLET_ENCRYPTED" = "running with an unencrypted wallet" ]; then

                printf "%b DigiByte Wallet is NOT currently encrypted.\\n" "${CROSS}"

                # Ask the user if they want to encrypt with a password?
                if dialog --no-shadow --keep-tite --colors --backtitle "Encrypt DigiByte Wallet" --title "Encrypt DigiByte Wallet" --yes-label "Yes (Recommended)" --no-label "No" --yesno "\n\Z4Would you like to encrypt your DigiByte wallet with a passphrase?\Z0\n\nThis is highly recommended. It offers an additional level of security, since if someone finds the USB stick, they will not be able to access the wallet.dat file without the passphrase." 11 "${c}"; then

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

        WALLET_ENCRYT_PASS1=$(dialog --no-shadow --keep-tite --colors --backtitle "Enter an encryption passphrase" --title "Enter an encryption passphrase" --insecure --passwordbox "\nPlease enter a passphrase to encrypt your DigiByte Core wallet. It can be as long as you like and may include spaces.\\n\\n\Z1IMPORTANT: DO NOT FORGET THIS PASSPHRASE - you will need it every time you want to access your wallet. Should you forget it, there is no way to regain access to your money. You have been warned! \Z0" 13 78 3>&1 1>&2 2>&3)
            # A trick to swap stdout and stderr.
            # Again, you can pack this inside if, but it seems really long for some 80-col terminal users.
        exitstatus=$?
        if [ $exitstatus == 0 ]; then
            printf "%b Passphrase entered for encrypted wallet.\\n" "${INFO}"
        else
            printf "%b %bYou cancelled choosing a wallet encryption passphrase.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            # Display a message saying that the wallet.dat file does not exist
            dialog --no-shadow --keep-tite --backtitle "Backup cancelled" --title "Backup cancelled" --msgbox "\nYou cancelled entering an encryption passphrase. The script will exit." 8 ${c}
            printf "\\n"
            menu_existing_install  
        fi

        WALLET_ENCRYT_PASS2=$(dialog --no-shadow --keep-tite --colors --backtitle "Re-enter the passphrase to confirm" --title "Re-enter the passphrase to confirm" --insecure --passwordbox "\nPlease re-enter the passphrase to confirm.\\n\\n\Z1IMPORTANT: DO NOT FORGET THIS PASSPHRASE - you will need it every time you want to access your wallet. Should you forget it, there is no way to regain access to your money. You have been warned! \Z0" 13 78 3>&1 1>&2 2>&3)
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
                dialog --no-shadow --keep-tite --backtitle "Passwords do not match!" --title "Passwords do not match!" --msgbox "\nThe passwords do not match. Please try again." 7 ${c}
                printf "%b Passwords do not match. Please try again.\\n" "${CROSS}"
                skip_if_reentering_encryption_passphrases="yes"

                # re-do prompt for password
                usb_backup
            fi
        else
            printf "%b %bYou cancelled choosing an encryption password.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
            # Display a message saying that the wall.dat file does not exist
            dialog --no-shadow --keep-tite --backtitle "Backup cancelled" --title "Backup cancelled" --msgbox "\nYou cancelled entering a backup password. The script will exit." 7 ${c}
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
                dialog --no-shadow --keep-tite --backtitle "DigiByte Wallet is now encrypted" --title "DigiByte Wallet is now encrypted" --msgbox "\nYour DigiByte wallet is now encrypted. Do not forget the passphrase!" 8 ${c}
                
                # Restart the DigiByte service
                printf "%b Restarting DigiByte daemon systemd service...\\n\\n" "${INFO}"
                restart_service digibyted
            else
                dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Wallet encryption failed." --title "DigiByte Wallet encryption failed." --msgbox "\n\Z1ERROR: Your DigiByte wallet was not successfully encrypted.\Z0\n\nThe script will exit." 9 ${c}
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
        if dialog --no-shadow --keep-tite --colors --backtitle "Prepare USB Backup Stick" --title "Prepare USB Backup Stick" --yes-label "Continue" --no-label "Exit" --yesno "\n\Z4Are you ready to proceed with DigiNode backup?\Z0\n\nPlease have your backup USB stick ready - for best results make sure it is formatted in either exFAT or FAT32. NTFS may not work! \n\n\Z1IMPORTANT: Do not insert the USB stick into the DigiNode yet. If it is already plugged in, please UNPLUG it now before continuing.\Z0" 13 "${c}"; then

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
                sleep 0.5
 #              read -t 0.5 -n 1 keypress && cancel_insert_usb="yes" && break
            fi
        done

        # Return to menu if a keypress was detected to cancel inserting a USB
        if [ "$cancel_insert_usb" = "yes" ]; then
            dialog --no-shadow --keep-tite --colors --backtitle "USB Backup Cancelled" --title "USB Backup Cancelled" --msgbox "\nYou cancelled the USB backup." 7 ${c}
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
            if dialog --no-shadow --keep-tite --colors --backtitle "Inserted USB Stick is not writeable." --title "Inserted USB Stick is not writeable." --yes-label "Continue" --no-label "Exit" --yesno "\nWould you like to format the USB stick?\\n\\nThe stick you inserted does not appear to be writeable, and needs to be formatted before it can be used for the backup.\n\n\Z1WARNING: If you continue, any existing data on the USB stick will be erased. If you prefer to try a different USB stick, please choose Exit, and run this again from the main menu.\Z0" "${r}" "${c}"; then

                printf "%b You confirmed you want to format the USB stick.\\n" "${INFO}"
                printf "\\n"

                # FORMAT USB STICK HERE 

                printf " =============== Format USB Stick ======================================\\n\\n"
                # ==============================================================================

                opt1a="1 exFAT"
                opt1b="Format the USB stick as exFAT."
                
                opt2a="2 FAT32"
                opt2b="Format the USB stick as FAT32."


                # Display the information to the user
                UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "Format USB Stick" --title "Format USB Stick" --menu "\nPlease choose what file system you would like to format your USB stick.\n\n\Z1IMPORTANT: If you continue, any data currently on the stick will be erased.\Z0\n\n" "${r}" "${c}" 3 \
                "${opt1a}"  "${opt1b}" \
                "${opt2a}"  "${opt2b}" 4>&3 3>&2 2>&1 1>&3) || \
                { printf "%b %bCancel was selected. Returning to main menu.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; dialog --no-shadow --keep-tite --colors --backtitle "Remove the USB stick." --title "Remove the USB stick." --msgbox "\nPlease unplug the USB stick now." 7 ${c}; format_usb_stick_now=false; printf "\\n"; menu_existing_install; }

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
                    dialog --no-shadow --keep-tite --colors --backtitle "Creating GPT Partition Failed" --title "Creating GPT Partition Failed" --msgbox "\n\Z1ERROR: Your USB stick could not be partitioned. Try partioning it on another computer - exFAT or FAT32 are recommended.\Z0\\n\\nPlease unplug the USB stick now before continuing." 10 ${c}
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

                    dialog --no-shadow --keep-tite --colors --backtitle "Creating File System Failed" --title "Creating File System Failed" --msgbox "\n\Z1ERROR: The $USB_BACKUP_STICK_FORMAT file system could not be created. Try formatting it on another computer - exFAT or FAT32 are recommended.\Z0\\n\\nPlease unplug the USB stick now before continuing." 10 ${c}
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
                dialog --no-shadow --keep-tite --colors --backtitle "Remove the USB stick" --title "Remove the USB stick" --msgbox "\nPlease unplug the USB stick now." 7 ${c}
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
                    if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiByte Wallet backup found on USB stick" --title "Existing DigiByte Wallet backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of another DigiByte wallet.\Z0\n\nDo you want to overwrite it? It is unknown when this backup was created, and it may be that it was not created from this DigiNode. \n\nIf you continue the existing backup will be overwritten." "${r}" "${c}"; then

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
                    if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiByte Wallet backup found on USB stick" --title "Existing DigiByte Wallet backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of another DigiByte wallet.\Z0\n\nDo you want to overwrite it? The existing wallet backup was created:\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK \n\nIt is not known whether the backup was made from this DigiNode. If you continue the existing backup will be overwritten." "${r}" "${c}"; then

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
                    if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiByte Wallet backup found on USB stick" --title "Existing DigiByte Wallet backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of another DigiByte wallet.\Z0\n\nDo you want to overwrite it? It is unknown when this backup was created, or whether it was created from this DigiNode. This DigiNode was previously backed up to another stick on:\n  $DGB_WALLET_BACKUP_DATE_ON_DIGINODE\n\nIf you continue the existing wallet backup will be overwritten." "${r}" "${c}"; then

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
                        if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiByte Wallet backup found on USB stick" --title "Existing DigiByte Wallet backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of this DigiByte wallet.\Z0\n\nDo you want to overwrite it? This backup was previously created on:\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\n\nYou should not need to create a new backup unless you have recently encrypted the wallet. If you continue your existing wallet backup will be overwritten." "${r}" "${c}"; then

                            do_wallet_backup_now=true
                            printf "%b DigiByte Wallet: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                            echo "$NEW_BACKUP_DATE DigiByte Wallet: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        else
                            printf "%b DigiByte Wallet: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                            do_wallet_backup_now=false
                        fi

                    else

                        # Ask the user to prepare their backup USB stick
                        if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiByte Wallet backup found on USB stick" --title "Existing DigiByte Wallet backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a DigiByte wallet backup.\Z0\n\nDo you want to overwrite it? This DigiByte wallet backup was made on:\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\n\nA previous backup was made to a different USB stick on:\\n  $DGB_WALLET_BACKUP_DATE_ON_DIGINODE\n\nIf you continue the existing backup will be overwritten." "${r}" "${c}"; then

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
                    DGB_WALLET_OLD_BACKUP_DATE_ON_USB_STICK=$DGB_WALLET_BACKUP_DATE_ON_USB_STICK
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                fi

                # Copy "live" wallet to backup stick
                str="Backing up DigiByte wallet to USB stick ... "
                printf "%b %s" "${INFO}" "${str}" 
                cp $DGB_SETTINGS_LOCATION/wallet.dat /media/usbbackup/diginode_backup/
                if [ $? -eq 0 ]; then
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

                    # Genererate an MD5 hash of the local wallet
                    str="Getting checksum of current wallet.dat ... "
                    printf "%b %s" "${INFO}" "${str}" 
                    wallet_current_md5=$(md5sum $DGB_SETTINGS_LOCATION/wallet.dat | cut -d' ' -f1)
                    printf "%b%b %s: $wallet_current_md5\\n" "${OVER}" "${INFO}" "${str}"

                    # Genererate an MD5 hash of the backup wallet
                    str="Getting checksum of backup wallet.dat backup on USB stick ... "
                    printf "%b %s" "${INFO}" "${str}" 
                    wallet_new_backup_md5=$(md5sum /media/usbbackup/diginode_backup/wallet.dat | cut -d' ' -f1)
                    printf "%b%b %s: $wallet_new_backup_md5\\n" "${OVER}" "${INFO}" "${str}"

                    # Check if the local wallet matches the backup
                    str="Does the backup wallet.dat match the local wallet? ... "
                    printf "%b %s" "${INFO}" "${str}"

                    if [ "$wallet_current_md5" = "$wallet_new_backup_md5" ]; then

                        printf "%b%b %s YES! Checksums match!\\n" "${OVER}" "${TICK}" "${str}"

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

                        echo "$NEW_BACKUP_DATE DigiByte Wallet: Backup completed successfully." >> /media/usbbackup/diginode_backup/diginode_backup.log
                        local dgb_backup_result="ok"

                    else

                        printf "%b%b %s FAIL! Backup wallet.dat does not match local version.\\n" "${OVER}" "${CROSS}" "${str}"
                        echo "$NEW_BACKUP_DATE DigiByte Wallet: Backup failed as the backup wallet.dat does not match the local version." >> /media/usbbackup/diginode_backup/diginode_backup.log
                        local dgb_backup_result="failed"

                        # Delete wallet.dat backup on USB stick as the file is damaged
                        if [ -f "/media/usbbackup/diginode_backup/wallet.dat" ]; then
                            str="Deleting backup wallet.dat as it does not local version... "
                            printf "%b %s" "${INFO}" "${str}" 
                            rm /media/usbbackup/diginode_backup/wallet.dat
                            echo "$NOW_DATE DigiByte Wallet: Deleted backup wallet.dat as it did not match local version" >> /media/usbbackup/diginode_backup/diginode_backup.log
                            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                        fi

                        # Rename existing wallet backup to .old
                        if [ -f "/media/usbbackup/diginode_backup/wallet.dat.old" ]; then
                            # Rename existing wallet backup to .old
                            str="Renaming existing wallet.dat.old file on USB stick to wallet.dat ... "
                            printf "%b %s" "${INFO}" "${str}" 
                            mv /media/usbbackup/diginode_backup/wallet.dat.old /media/usbbackup/diginode_backup/wallet.dat
                            echo "$NEW_BACKUP_DATE DigiByte Wallet: Renaming existing wallet.dat backup to wallet.dat.old." >> /media/usbbackup/diginode_backup/diginode_backup.log
                            sed -i -e "/^DGB_WALLET_BACKUP_DATE_ON_USB_STICK=/s|.*|DGB_WALLET_BACKUP_DATE_ON_USB_STICK=\"$DGB_WALLET_OLD_BACKUP_DATE_ON_USB_STICK\"|" $DGNT_SETTINGS_FILE
                            sed -i -e "/^DGB_WALLET_OLD_BACKUP_DATE_ON_USB_STICK=/s|.*|DGB_WALLET_OLD_BACKUP_DATE_ON_USB_STICK=\"\"|" $DGNT_SETTINGS_FILE
                            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                        fi

                    fi

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
                    if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiAsset Node backup found on USB stick" --title "Existing DigiAsset Node backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of another DigiAsset Node.\Z0\n\nDo you want to overwrite it? It is unknown when this backup was created, and it appears that it was not created from this DigiNode. \\n\\nIf you continue the existing backup will be overwritten." "${r}" "${c}"; then

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
                    if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiAsset Node backup found on USB stick" --title "Existing DigiAsset Node backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of another DigiAsset Node.\Z0\n\nDo you want to overwrite it? The existing backup was created:\\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK \n\nIt is not known whether the backup was made from this DigiNode. If you continue the existing backup will be overwritten." "${r}" "${c}"; then

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
                    if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiAsset Node backup found on USB stick" --title "Existing DigiAsset Node backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of another DigiAsset Node.\Z0\n\nDo you want to overwrite it? It is unknown when this backup was created, or whether it was created from this DigiNode. This DigiNode was preciously backed up to another stick on:\n  $DGA_CONFIG_BACKUP_DATE_ON_DIGINODE\n\nIf you continue the existing DigiAsset settings backup will be overwritten." "${r}" "${c}"; then

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

                        if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiAsset Node backup found on USB stick" --title "Existing DigiAsset Node backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a backup of this DigiAsset Node.\Z0\n\nDo you want to overwrite it? This backup was previously created on:\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\n\nYou should not need to create a new DigiAsset Settings backup unless you have recently changed your configuration. If you continue your existing DigiAsset Settings backup will be overwritten." "${r}" "${c}"; then

                            do_dgaconfig_backup_now=true
                            printf "%b DigiAsset Settings: You agreed to overwrite the existing backup on the USB stick...\\n" "${INFO}"
                            echo "$NEW_BACKUP_DATE DigiAsset Settings: Existing backup will be overwritten" >> /media/usbbackup/diginode_backup/diginode_backup.log
                        else
                            printf "%b DigiAsset Settings: You chose not to proceed with overwriting the existing backup.\\n" "${INFO}"
                            do_dgaconfig_backup_now=false
                        fi

                    else

                        # Ask the user to prepare their backup USB stick
                        if dialog --no-shadow --keep-tite --colors --backtitle "Existing DigiAsset Node backup found on USB stick" --title "Existing DigiAsset Node backup found on USB stick" --yesno "\n\Z1WARNING: This USB stick already contains a DigiAsset Node backup.\Z0\n\nDo you want to overwrite it? This DigiAsset Node backup was made on:\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\n\nA previous backup was made to a different USB stick on:\n  $DGA_CONFIG_BACKUP_DATE_ON_DIGINODE\n\nIf you continue the current backup will be overwritten." "${r}" "${c}"; then

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
            dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Backup Completed Successfully" --title "DigiNode Backup Completed Successfully" --msgbox "\nYour DigiByte wallet and DigiAsset settings have been successfully backed up to the USB stick.\\n\\nPlease unplug the backup USB stick now. When you are done press OK." 11 ${c}
        elif [ "$dgb_backup_result" = "ok" ]; then
            dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Wallet Backup Completed Successfully" --title "DigiByte Wallet Backup Completed Successfully" --msgbox "\nYour DigiByte wallet has been successfully backed up to the USB stick.\\n\\nPlease unplug the backup USB stick now. When you are done press OK." 11 ${c}
        elif [ "$dga_backup_result" = "ok" ]; then
            dialog --no-shadow --keep-tite --colors --backtitle "DigiAsset Settings Backup Succeeded" --title "DigiAsset Settings Backup Succeeded" --msgbox "\nYour DigiAsset Settings have been successfully backed up to the USB stick.\\n\\nPlease unplug the backup USB stick now. When you are done press OK." 11 ${c}
        fi

        # Display backup failed messages

        if [ "$dgb_backup_result" = "failed" ] && [ "$dga_backup_result" = "failed" ]; then
            dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Backup Failed" --title "DigiNode Backup Failed" --msgbox "\n\Z1ERROR: Your DigiByte wallet and DigiAsset settings backup failed. Please check the USB stick.\Z0\\n\\nPlease unplug the USB stick. When you have done so, press OK." 10 ${c}
        elif [ "$dgb_backup_result" = "failed" ]; then
            dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Wallet Backup Failed" --title "DigiByte Wallet Backup Failed" --msgbox "\n\Z1ERROR: Your DigiByte wallet backup failed due to an error. Please check the USB stick.\Z0\\n\\nPlease unplug the USB stick. When you have done so, press OK." 10 ${c}
        elif [ "$dga_backup_result" = "failed" ]; then
            dialog --no-shadow --keep-tite --colors --backtitle "DigiAsset Settings Backup Failed" --title "DigiAsset Settings Backup Failed" --msgbox "\n\Z1ERROR: Your DigiAsset Settings backup failed. Please check the USB stick.\Z0\\n\\nPlease unplug the backup USB now. When you have done so, press OK." 10 ${c}
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
    if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Restore" --title "DigiNode Restore" --yes-label "Continue" --no-label "Exit" --yesno '\nThis tool will help you to restore your DigiByte wallet and/or DigiAsset Node settings from your USB Backup stick.\n\nThe USB backup must previously have been made from the DigNode Setup Backup menu. Please have your DigiNode USB backup stick ready before continuing. \n\n\Z1WARNING: If you continue, your current wallet and settings will be replaced with the ones from the USB backup. Any funds in the current wallet will be lost!!\Z0' 16 "${c}"; then
        printf "%b You chose to begin the restore process.\\n\\n" "${INFO}"
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
        dialog --no-shadow --keep-tite --colors --backtitle "USB Restore Cancelled" --title "USB Restore Cancelled" --msgbox "\nYou cancelled the USB restore." 7 ${c}
        printf "\\n"
        printf "%b You cancelled the USB restore.\\n" "${INFO}"
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
            dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Backup not found" --title "DigiNode Backup not found" --msgbox "\n\Z1ERROR: DigiNode backup not found on USB stick.\Z0\\n\\nPlease unplug the stick and choose OK to return to the main menu." 9 ${c}
            printf "\\n"
            printf "%b %bERROR: No DigiNode backup found on stick.%b Returning to menu.\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            cancel_insert_usb=""
            menu_existing_install
        fi

    else
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        dialog --no-shadow --keep-tite --colors --backtitle "Could not mount USB Stick" --title "Could not mount USB Stick" --msgbox "\n\Z1ERROR: The USB stick could not be mounted. Is this the correct DigiNode backup stick?\Z0\\n\\nPlease unplug the stick and choose OK to return to the main menu." 10 ${c}
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
        restore_str="\n\Z4Would you like to restore your DigiByte wallet from the USB backup?\Z0\n\nThis DigiByte wallet backup was made on:\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\n\nYour local DigiByte wallet was likely created:\n  $DGB_INSTALL_DATE\n\n\Z1WARNING: If you continue your local wallet will be replaced with the one from the USB backup stick and any funds will be lost.\Z0"
    elif [ "$IS_LOCAL_WALLET" = "NO" ]; then
        restore_str="\n\Z4Would you like to restore your DigiByte wallet from the USB backup?\Z0\n\nThis DigiByte wallet backup was made on:\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\n\nNote: There is currently no existing DigiByte wallet on this DigiNode."
    else
        restore_str="\n\Z4Would you like to restore your DigiByte wallet from the USB backup?\Z0\n\nThis DigiByte wallet backup was made on:\n  $DGB_WALLET_BACKUP_DATE_ON_USB_STICK\n\nYour local DigiByte wallet was previously backed up on:\n  $DGB_WALLET_BACKUP_DATE_ON_DIGINODE\n\n\Z1WARNING: If you continue your current wallet will be replaced with the one on the USB backup stick and any funds will be lost.\Z0"
    fi

    # Ask to restore the DigiByte Core Wallet backup, if it exists
    if [ -f /media/usbbackup/diginode_backup/wallet.dat ]; then

        # Ask if the user wants to restore their DigiByte wallet
        if dialog --no-shadow --keep-tite --colors --backtitle "Restore DigiByte Wallet" --title "Restore DigiByte Wallet" --yesno "$restore_str" "${r}" "${c}"; then

            run_wallet_restore=true
        else
            run_wallet_restore=false
        fi
    else
        printf "%b No DigiByte Core wallet backup was found on the USB stick.\\n" "${INFO}"
        run_wallet_restore=false
        # Display a message saying that the wallet.dat file does not exist
        dialog --no-shadow --keep-tite --colors --backtitle "DigiByte wallet backup not found" --title "DigiByte wallet backup not found" --msgbox "\n\Z1ERROR: No DigiByte Core wallet.dat was found on the USB backup stick so there is nothing to restore.\Z0" 8 ${c}
    fi

    # Ask to restore the DigiAsset Node _config folder, if it exists
    if [ -d /media/usbbackup/diginode_backup/dga_config_backup ]; then

        # Ask the user if they want to restore their DigiAsset Node settings
        if dialog --no-shadow --keep-tite --colors --backtitle "Restore DigiAsset Node Settings" --title "Restore DigiAsset Node Settings" --yesno "\n\Z4Would you like to also restore your DigiAsset Node settings?\Z0\n\nThis will replace your DigiAsset Node _config folder which stores your Amazon web services credentials, RPC password etc.\n\nThis DigiAsset settings backup was created:\n  $DGA_CONFIG_BACKUP_DATE_ON_USB_STICK\n\n\Z1WARNING: If you continue your current DigiAsset Node settings will be replaced with the ones from the USB backup stick.\Z0" "${r}" "${c}"; then
            run_dgaconfig_restore=true
        else
            run_dgaconfig_restore=false
        fi
    else
        printf "%b No DigiAsset Node settings backup was found on the USB stick.\\n" "${INFO}"
        run_dgaconfig_restore=false
        # Display a message saying that the wallet.dat file does not exist
        dialog --no-shadow --keep-tite --colors --backtitle "DigiAsset Node settings backup not found" --title "DigiAsset Node settings backup not found" --msgbox "\n\Z1ERROR: No DigiAsset Node settings backup was found on the USB backup stick so there is nothing to restore.\Z0" 8 ${c}
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

            # Genererate an MD5 hash of the backup wallet
            str="Getting checksum of backup wallet.dat backup on USB stick ... "
            printf "%b %s" "${INFO}" "${str}" 
            wallet_backup_md5=$(md5sum /media/usbbackup/diginode_backup/wallet.dat | cut -d' ' -f1)
            printf "%b%b %s: $wallet_backup_md5\\n" "${OVER}" "${INFO}" "${str}"

            # Genererate an MD5 hash of the restored wallet
            str="Getting checksum of restored wallet.dat ... "
            printf "%b %s" "${INFO}" "${str}" 
            wallet_restored_md5=$(md5sum $DGB_SETTINGS_LOCATION/wallet.dat | cut -d' ' -f1)
            printf "%b%b %s: $wallet_restored_md5\\n" "${OVER}" "${INFO}" "${str}"

            # Check if the restored wallet matches the backup
            str="Does the restored wallet.dat match the backup? ... "
            printf "%b %s" "${INFO}" "${str}"

            if [ "$wallet_restored_md5" = "$wallet_backup_md5" ]; then

                printf "%b%b %s YES! Checksums match!\\n" "${OVER}" "${TICK}" "${str}"

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

                local dgb_restore_result="ok"
                echo "$NOW_DATE DigiByte Wallet: Restore completed successfully." >> /media/usbbackup/diginode_backup/diginode_backup.log

            else

                printf "%b%b %s FAIL! Restored wallet.dat does not match USB backup.\\n" "${OVER}" "${CROSS}" "${str}"
                echo "$NOW_DATE DigiByte Wallet: Restore failed as the restored wallet.dat does not match the USB backup." >> /media/usbbackup/diginode_backup/diginode_backup.log
                local dgb_restore_result="failed"

                # Delete previous secondary backup of existing wallet, if it exists
                if [ -f "$DGB_SETTINGS_LOCATION/wallet.dat" ]; then
                    str="Deleting restored wallet.dat as it does not match backup... "
                    printf "%b %s" "${INFO}" "${str}" 
                    rm $DGB_SETTINGS_LOCATION/wallet.dat
                    echo "$NOW_DATE DigiByte Wallet: Deleted restored wallet.dat as it did not match backup" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                # Rename existing wallet backup to .old
                if [ -f "$DGB_SETTINGS_LOCATION/wallet.dat.old" ]; then
                    str="Renaming existing local wallet.dat.old to wallet.dat ... "
                    printf "%b %s" "${INFO}" "${str}" 
                    mv $DGB_SETTINGS_LOCATION/wallet.dat.old $DGB_SETTINGS_LOCATION/wallet.dat
                    echo "$NOW_DATE DigiByte Wallet: Renaming local wallet.dat.old to wallet.dat" >> /media/usbbackup/diginode_backup/diginode_backup.log
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi
            fi

        else
            printf "%b%b %s FAIL! File could not be copied!\\n" "${OVER}" "${CROSS}" "${str}"
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


        # Restart PM2 if it has not already been restarted.
        if [ "$DGA_SETTINGS_CREATE_TYPE" != "update" ]; then

            printf "%b Re-starting DigiAsset Node...\\n" "${INFO}"

            # Stop the DigiAsset Node now
            sudo -u $USER_ACCOUNT pm2 restart digiasset

        fi

    fi

    # Unmount USB stick
    str="Unmount the USB backup stick..."
    printf "%b %s" "${INFO}" "${str}"
    umount /dev/$mount_partition
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Display restore completed messages

    if [ "$dgb_restore_result" = "ok" ] && [ "$dga_restore_result" = "ok" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Restore Completed Successfully" --title "DigiNode Restore Completed Successfully" --msgbox "\nYour DigiByte wallet and DigiAsset settings have been successfully restored from the USB stick.\\n\\nPlease unplug the USB stick now. When you are done press OK." 10 ${c}
    elif [ "$dgb_restore_result" = "ok" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Wallet Restore Completed Successfully" --title "DigiByte Wallet Restore Completed Successfully" --msgbox "\nYour DigiByte wallet has been successfully restored from the USB stick.\\n\\nPlease unplug the USB stick now. When you are done press OK" 10 ${c}
    elif [ "$dga_restore_result" = "ok" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "DigiAsset Settings Successfully Restored" --title "DigiAsset Settings Successfully Restored" --msgbox "\nYour DigiAsset Settings have been successfully restored from the USB stick.\\n\\nPlease unplug the USB stick now. When you are done press OK." 10 ${c}
    fi

    # Display backup failed messages

    if [ "$dgb_restore_result" = "failed" ] && [ "$dga_restore_result" = "failed" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Restore Failed" --title "DigiNode Restore Failed" --msgbox "\n\Z1ERROR: Your DigiByte wallet and DigiAsset settings restore failed. Please check the USB stick.\Z0\\n\\nPlease unplug the USB stick. When you have done so, press OK." 10 ${c}
    elif [ "$dgb_restore_result" = "failed" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Wallet Restore Failed" --title "DigiByte Wallet Restore Failed" --msgbox "\n\Z1ERROR: Your DigiByte wallet restore failed due to an error. Please check the USB stick.\Z0\\n\\nPlease unplug the USB stick now. When you have done so, press OK." 10 ${c}
    elif [ "$dga_restore_result" = "failed" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "DigiAsset Settings Restore Failed" --title "DigiAsset Settings Restore Failed" --msgbox "\n\Z1ERROR: Your DigiAsset Settings restore failed due to an error. Please check the USB stick.\Z0\\n\\nPlease unplug the USB stick now. When you have done so, press OK." 10 ${c}
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
            printf "%b As of $DGB_DATA_REQUIRED_DATE, the full DigiByte blockchain requires approximately $DGB_DATA_REQUIRED_HR\\n" "${INDENT}"
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
            printf "%b Disk Space Check: %bPASSED%b   There is sufficient space for the DigiByte blockchain.\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
        if dialog --no-shadow --keep-tite --colors --backtitle "Not enough free disk space." --title "Not enough free disk space." --yesno "\n\Z1WARNING: There is not enough free space on this drive to download a full copy of the DigiByte blockchain.\Z0\n\nIf you continue, you will need to enable pruning the blockchain to prevent it from filling up the drive. You can do this by editing the digibyte.conf settings file.\n\nDo you wish to continue with the install now?\n\nChoose YES to indicate that you have understood this message, and wish to continue." "${r}" "${c}"; then

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

    printf " =============== INSTALL MENU ==========================================\n\n"
    # ==============================================================================

#!!    opt1="1 FULL DigiNode"
#!!     desc1="Install DigiByte & DigiAsset Node (Recommended)"
    
    opt2="1 DigiByte Node"
    desc2="Install DigiByte Node ONLY."

    opt3="2 DigiNode Tools ONLY"
    desc3="Use DigiNode Dashboard with an existing DigiByte Node."

    # Display the information to the user
#!!    UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Setup - Main Menu" --title "DigiNode Setup - Main Menu" --cancel-label "Exit" --menu "\nPlease choose what to install. A FULL DigiNode is recommended.\n\nRunning a DigiAsset Node supports the DigiByte network by helping to decentralize DigiAsset metadata. You can also use it to mint your own DigiAssets and earn \$DGB for hosting the community metadata.\n\nIf you already have a DigiByte Node on this machine, you can install DigiNode Tools ONLY to use the DigiNode Dashboard with it. Note: This may require you to tweak your setup to work.\n\nPlease choose an option:\n\n" 21 83 3 \
#!!        "${opt1}" "${desc1}" \
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Setup - Main Menu" --title "DigiNode Setup - Main Menu" --cancel-label "Exit" --menu "\nPlease choose what to install.\n\nIMPORTANT: The option to install a full DigiNode (DigiByte + DigiAsset Node) is temporaily unavailable. Support for the new DigiAsset Core will be added in an upcoming release.\n\nIf you already have a DigiByte Node on this machine, you can install DigiNode Tools ONLY to use the DigiNode Dashboard with it. Note: This may require you to tweak your setup to work.\n\nPlease choose an option:\n\n" 21 83 2 \
        "${opt2}" "${desc2}" \
        "${opt3}" "${desc3}" 3>&2 2>&1 1>&3 ) || \
    { printf "%b %bExit was selected.%b\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; printf "\n"; digifact_randomize; display_digifact_fixedwidth; printf "\n"; exit; }

    # Set the variable based on if the user chooses
    case "${UpdateCmd}" in
        # Install Full DigiNode
        ${opt1})
            DO_FULL_INSTALL=YES
            printf "%b You chose to install a FULL DiginNode.\n" "${INFO}"
            ;;
        # Install DigiByte Core ONLY
        ${opt2})
            DO_FULL_INSTALL=NO
            printf "%b You chose to install DigiByte Core ONLY.\n" "${INFO}"
            ;;
        # Install DigiNode Tools ONLY
        ${opt3})
            printf "%b You chose to install DigiNode Tools ONLY.\n" "${INFO}"
            printf "\n"
            dialog --no-shadow --keep-tite --colors --backtitle "Install DigiNode Tools ONLY" --title "Install DigiNode Tools ONLY" --msgbox "\nDigiNode Tools ONLY will now be installed.\\n\\nIf you are doing this because you wish to use DigiNode Dashboard with your existing DigiByte Node, then you will need to create a symbolic link named 'digibyte' in your home folder (~/digbyte) that points at the install folder of DigiByte Core. If you don't do this, DigiNode Dashboard will not be able to communicate with your node.\\n\\n\Z1IMPORTANT: If you want to use DigiNode Dashboard, it is strongly recommended to use DigiNode Setup to configure your DigiByte Node. This will ensure that everything is configured correctly and works as expected.\Z0" 19 ${c}
            install_diginode_tools_only
            ;;
        *)
            dialog --no-shadow --keep-tite --colors  --msgbox "\nOther option selected\n\n" 0 0
            ;;
    esac
    printf "\n"
}


# This function will install or upgrade the DigiNode Tools script on this machine
install_diginode_tools_only() {

    # Check and install/upgrade DigiNode Tools
    check_diginode_tools
    diginode_tools_do_install

    # Display closing message
    closing_banner_message

    # Choose a random DigiFact
    digifact_randomize

    # Display a random DigiFact
    display_digifact_fixedwidth

    # Display donation QR Code
    donation_qrcode

    printf "%b %bUse 'DigiNode Dashboard' to monitor your existing DigiByte Node, if you have one.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b To run it enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b %bUse 'DigiNode Setup' to upgrade DigiNode Tools or setup a DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b To run it enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
    printf "\\n"
    printf "%b Note: If this is your first time installing DigiNode Tools, these aliases\\n" "${INDENT}"
    printf "%b may not work yet. You will need to log out or restart before you can use them.\\n" "${INDENT}"
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

    opt1a="1 Update"
    opt1b="Check for updates to your DigiNode software."

    opt2a="2 Backup"
    opt2b="Backup your wallet & settings to a USB stick."

    opt3a="3 Restore"
    opt3b="Restore your wallet & settings from a USB stick."

    opt4a="5 Chain"
    opt4b="Change DigiByte chain - mainnet, testnet or dual node."

    opt5a="6 Tor"
    opt5b="Enable or disable running your nodes over Tor."

    opt6a="4 UPnP"
    opt6b="Enable or disable UPnP to automatically forward ports."

    opt7a="7 MOTD"
    opt7b="Enable or disable the DigiNode Custom MOTD."

    opt8a="8 Extras"
    opt8b="Install optional extras for your DigiNode."
    
    opt9a="9 Reset"
    opt9b="Reset all settings and reinstall DigiNode software."

    opt0a="0 Uninstall"
    opt0b="Remove DigiNode from your system."


    # Display the information to the user

    UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Setup - Main Menu" --title "DigiNode Setup - Main Menu" --cancel-label "Exit" --menu "\nAn existing DigiNode has been detected on this system.\n\nPlease choose from the following options:\n\n" 20 73 10 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" \
    "${opt3a}"  "${opt3b}" \
    "${opt4a}"  "${opt4b}" \
    "${opt5a}"  "${opt5b}" \
    "${opt6a}"  "${opt6b}" \
    "${opt7a}"  "${opt7b}" \
    "${opt8a}"  "${opt8b}" \
    "${opt9a}"  "${opt9b}" \
    "${opt0a}"  "${opt0b}" 3>&2 2>&1 1>&3 ) || \
    { printf "%b Exit was selected, exiting DigiNode Setup\\n" "${INDENT}"; echo ""; closing_banner_message; digifact_randomize; display_digifact_fixedwidth; donation_qrcode; display_system_updates_reminder; backup_reminder; exit; }


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
        # Change DigiByte Chain - mainnet, testnet or dual node
        ${opt4a})
            printf "%b You selected the DigiByte Chain option.\\n" "${INFO}"
            printf "\\n"
            change_dgb_network
            ;;
        # Change Tor
        ${opt5a})
            printf "%b You selected the Tor option.\\n" "${INFO}"
            printf "\\n"
            change_tor_status
            ;;
        # Change Port forwarding
        ${opt6a})
            printf "%b You selected the UPnP option.\\n" "${INFO}"
            printf "\\n"
            change_upnp_status
            ;;
        # DigiNode MOTD
        ${opt7a})
            printf "%b You selected the DigiNode MOTD option.\\n" "${INFO}"
            printf "\\n"
            MOTD_STATUS="ASK"
            CUSTOM_MOTD_MENU="existing_install_menu"
            motd_check
            menu_ask_motd
            motd_do_install_uninstall
            menu_existing_install
            ;;
        # Extras
        ${opt8a})
            printf "%b You selected the EXTRAS option.\\n" "${INFO}"
            printf "\\n"
            menu_extras
            ;;
        # Reset,
        ${opt9a})
            printf "%b You selected the RESET option.\\n" "${INFO}"
            printf "\\n"
            RESET_MODE=true
            install_or_upgrade
            ;;
        # Uninstall,
        ${opt0a})
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

    opt1a="1 Argon One Daemon"
    opt1b="Install fan software for Argon ONE RPi4 case."

    opt2a="2 Main Menu"
    opt2b="Return to the main menu."


    # Display the information to the user
    UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "Extras Menu" --title "Extras Menu" --cancel-label "Exit" --menu "\nPlease choose from the following options:\n\n" "${r}" "${c}" 3 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
    { printf "%b Exit was selected, exiting DigiNode Setup\\n" "${INDENT}"; echo ""; closing_banner_message; digifact_randomize; display_digifact_fixedwidth; donation_qrcode; backup_reminder; display_system_updates_reminder; exit; }


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

    # Check DigiByte Node to make sure it is finished starting up
    check_digibyte_core

    # Display warning dialog if Tor is running, and return to menu
    if [ "$DGB_USING_TOR" = "YES" ] || [ "$DGB2_USING_TOR" = "YES" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "UPnP is unavailable!" --title "UPnP is unavailable!" --msgbox "\n\Z1Warning: UPnP cannot be used when Tor is enabled.\Z0\n\nTor and UPnP do not play nice together. If you want to use UPnP you need to first disable Tor. Click OK to return to the main menu." 11 ${c}
        FORCE_DISPLAY_UPNP_MENU=false
        DGB_UPNP_STATUS_UPDATED=""
        IPFS_UPNP_STATUS_UPDATED=""
        jsipfs_upnp_updated=""
        DGB_USING_TOR=""
        DGB2_USING_TOR=""
        menu_existing_install
    fi

    # If this is a DUAL NODE
    if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
        DGB_NETWORK_OLD="MAINNET"
        DGB_NETWORK_FINAL="MAINNET"
        SETUP_DUAL_NODE="YES" 
    # or if it is just a regular MAINNET node
    elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
        DGB_NETWORK_OLD="MAINNET"
        DGB_NETWORK_FINAL="MAINNET"
        SETUP_DUAL_NODE="NO" 
    elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
        DGB_NETWORK_OLD="TESTNET"
        DGB_NETWORK_FINAL="TESTNET"
        SETUP_DUAL_NODE="NO" 
    elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
        DGB_NETWORK_OLD="REGTEST"
        DGB_NETWORK_FINAL="REGTEST"
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            SETUP_DUAL_NODE="YES" 
        else
            SETUP_DUAL_NODE="NO" 
        fi
    elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
        DGB_NETWORK_OLD="SIGNET"
        DGB_NETWORK_FINAL="SIGNET"
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            SETUP_DUAL_NODE="YES" 
        else
            SETUP_DUAL_NODE="NO" 
        fi
    fi

    printf "\\n"

    printf " =============== Checking: IPFS Node ===================================\\n\\n"
    # ==============================================================================

    # Get the local version number of IPFS Kubo (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Let's check if IPFS Kubo is already installed
    str="Is IPFS Kubo already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: IPFS Kubo v${IPFS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Next let's check if IPFS daemon is running with upstart
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
      str="Is IPFS Kubo daemon upstart service running?..."
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
        str="Is IPFS Kubo daemon systemd service running?..."
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
    create_digibyte_conf

    # Restart DigiByte daemon if upnp status has changed
    if [ "$DGB_UPNP_STATUS_UPDATED" = "YES" ]; then

        # Restart Digibyte primary node if the upnp status has just been changed
        if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ] || [ "$DGB_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core UPnP status has been changed. DigiByte daemon will be restarted...\\n" "${INFO}"
            restart_service digibyted
        fi

        # Restart Digibyte secondary node if the upnp status has just been changed
        if [ "$DGB2_STATUS" = "running" ] || [ "$DGB2_STATUS" = "startingup" ] || [ "$DGB2_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core UPnP status has been changed. DigiByte daemon will be restarted...\\n" "${INFO}"
            restart_service digibyted-testnet
        fi

    fi

    # Set the IPFS upnp values, if we are enabling/disabling the UPnP status
    if [ "$IPFS_ENABLE_UPNP" = "YES" ]; then
        if [ "$UPNP_IPFS_CURRENT" != "false" ]; then
            str="Enabling UPnP port forwarding for IPFS Kubo..."
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
            str="Disabling UPnP port forwarding for IPFS Kubo..."
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

        # Restart IPFS Kubo if the upnp status has just been changed
        if [ "$IPFS_STATUS" = "running" ] || [ "$IPFS_STATUS" = "stopped" ]; then

            # Restart IPFS if the upnp status has just been changed
            printf "%b IPFS Kubo UPnP status has been changed. IPFS daemon will be restarted...\\n" "${INFO}"
            restart_service ipfs
        fi

        # Restart DigiAsset Node if the JS-IPFS upnp status has just been changed
        if [ "$jsipfs_upnp_updated" = "yes" ]; then

            # Restart IPFS if the upnp status has just been changed
            printf "%b JS-IPFS UPnP status has been changed. DigiAsset Node will be restarted...\\n" "${INFO}"
            sudo -u $USER_ACCOUNT pm2 restart digiasset
        fi

    fi

    printf "\\n"


    FORCE_DISPLAY_UPNP_MENU=false
    DGB_UPNP_STATUS_UPDATED=""
    IPFS_UPNP_STATUS_UPDATED=""
    jsipfs_upnp_updated=""

    menu_existing_install

}

# Function to change the current tor status
change_tor_status() {

    FORCE_DISPLAY_TOR_MENU=true

    # If DigiAssets Node is installed, we already know this is a full install
    if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        DO_FULL_INSTALL=YES
    fi

    # Check DigiByte Node to make sure it is finished starting up
    check_digibyte_core

    # If this is a DUAL NODE
    if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
        DGB_NETWORK_OLD="MAINNET"
        DGB_NETWORK_FINAL="MAINNET"
        SETUP_DUAL_NODE="YES" 
    # or if it is just a regular MAINNET node
    elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
        DGB_NETWORK_OLD="MAINNET"
        DGB_NETWORK_FINAL="MAINNET"
        SETUP_DUAL_NODE="NO" 
    elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
        DGB_NETWORK_OLD="TESTNET"
        DGB_NETWORK_FINAL="TESTNET"
        SETUP_DUAL_NODE="NO" 
    elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
        DGB_NETWORK_OLD="REGTEST"
        DGB_NETWORK_FINAL="REGTEST"
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            SETUP_DUAL_NODE="YES" 
        else
            SETUP_DUAL_NODE="NO" 
        fi
    elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
        DGB_NETWORK_OLD="SIGNET"
        DGB_NETWORK_FINAL="SIGNET"
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            SETUP_DUAL_NODE="YES" 
        else
            SETUP_DUAL_NODE="NO" 
        fi
    fi

    printf "\\n"

    printf " =============== Checking: IPFS Node ===================================\\n\\n"
    # ==============================================================================

    # Get the local version number of IPFS Kubo (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Let's check if IPFS Kubo is already installed
    str="Is IPFS Kubo already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: IPFS Kubo v${IPFS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Next let's check if IPFS daemon is running with upstart
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
      str="Is IPFS Kubo daemon upstart service running?..."
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
        str="Is IPFS Kubo daemon systemd service running?..."
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

    # Prompt to change tor status
    menu_ask_tor

    # Update digibyte.conf
    create_digibyte_conf

    # Restart DigiByte mainnet daemon if Tor status has changed
    if [ "$DGB_MAINNET_TOR_STATUS_UPDATED" = "YES" ]; then

        # Restart Digibyted if the Tor status has just been changed
        if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ] || [ "$DGB_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core Tor status has been changed. DigiByte Mainnet daemon will be restarted...\\n" "${INFO}"
            stop_service digibyted
            if [ -f "$DGB_DATA_LOCATION/peers.dat" ]; then
                str="Deleting Mainnet peers.dat as Tor status has changed ..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $DGB_DATA_LOCATION/peers.dat 
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi
            restart_service digibyted
        fi

        # Reenable port tester as Tor status has changed
        str="Re-enabling DigiByte Core MAINNET Port Test ..."
        printf "%b %s" "${INFO}" "${str}"
        DGB_MAINNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    fi

    # Restart DigiByte testnet daemon if Tor status has changed (single node)
    if [ "$DGB_TESTNET_TOR_STATUS_UPDATED" = "YES" ] && [ "$DGB_DUAL_NODE" = "NO" ]; then

        # Restart Digibyted if the Tor status has just been changed
        if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ] || [ "$DGB_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core Tor status has been changed. DigiByte Testnet daemon will be restarted...\\n" "${INFO}"
            stop_service digibyted
            if [ -f "$DGB_DATA_LOCATION/testnet4/peers.dat" ]; then
                str="Deleting Testnet peers.dat as Tor status has changed ..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $DGB_DATA_LOCATION/testnet4/peers.dat 
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi
            restart_service digibyted
        fi

        # Reenable port tester as Tor status has changed
        str="Re-enabling DigiByte Core TESTNET Port Test ..."
        printf "%b %s" "${INFO}" "${str}"
        DGB_TESTNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    fi

    # Restart DigiByte testnet daemon if Tor status has changed (dual node)
    if [ "$DGB_TESTNET_TOR_STATUS_UPDATED" = "YES" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Restart Digibyted if the Tor status has just been changed
        if [ "$DGB2_STATUS" = "running" ] || [ "$DGB2_STATUS" = "startingup" ] || [ "$DGB2_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core Tor status has been changed. DigiByte Testnet daemon will be restarted...\\n" "${INFO}"
            stop_service digibyted-testnet
            if [ -f "$DGB_DATA_LOCATION/testnet4/peers.dat" ]; then
                str="Deleting Testnet peers.dat as Tor status has changed ..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f $DGB_DATA_LOCATION/testnet4/peers.dat 
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi
            restart_service digibyted-testnet
        fi

        # Reenable port tester as Tor status has changed
        str="Re-enabling DigiByte Core TESTNET Port Test ..."
        printf "%b %s" "${INFO}" "${str}"
        DGB_TESTNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE  
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"   

    fi

    # Set the IPFS Tor values, if we are enabling/disabling the UPnP status
    if [ "$IPFS_ENABLE_TOR" = "YES" ]; then
 #       if [ "$UPNP_IPFS_CURRENT" != "false" ]; then
 #           str="Enabling Tor for IPFS Kubo..."
 #           printf "%b %s" "${INFO}" "${str}"
 #           sudo -u $USER_ACCOUNT ipfs config --bool Swarm.DisableNatPortMap "false"
 #           printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_TOR_STATUS_UPDATED="YES"
 #       fi
    elif [ "$IPFS_ENABLE_TOR" = "NO" ]; then
 #       if [ "$UPNP_IPFS_CURRENT" != "true" ]; then
 #           str="Disabling UPnP port forwarding for IPFS Kubo..."
 #           printf "%b %s" "${INFO}" "${str}"
 #           sudo -u $USER_ACCOUNT ipfs config --bool Swarm.DisableNatPortMap "true"
 #           printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_TOR_STATUS_UPDATED="YES"
 #       fi
    fi 

    if [ "$IPFS_TOR_STATUS_UPDATED" = "YES" ]; then

        # Restart IPFS Kubo if the Tor status has just been changed
        if [ "$IPFS_STATUS" = "running" ] || [ "$IPFS_STATUS" = "stopped" ]; then

            # Restart IPFS if the upnp status has just been changed
            printf "%b IPFS Kubo Tor status has been changed. IPFS daemon will be restarted...\\n" "${INFO}"
            restart_service ipfs
        fi

    fi

    printf "\\n"


    FORCE_DISPLAY_TOR_MENU=false
    DGB_MAINNET_TOR_STATUS_UPDATED=""
    DGB_TESTNET_TOR_STATUS_UPDATED=""
    IPFS_TOR_STATUS_UPDATED=""

    menu_existing_install

}

# Function to change the current DigiByte Network between MAINNET and TESTNET
change_dgb_network() {

    FORCE_DISPLAY_DGB_NETWORK_MENU=true

    # If DigiAssets Node is installed, we already know this is a full install
    if [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
        DO_FULL_INSTALL=YES
    fi

    # Lookup disk usage, and update diginode.settings if present
    update_disk_usage

    # Check to see if DigiByte Core is running or not, and find out which network (mainnet/testnet) it is currently using
    check_digibyte_core

    # Prompt to change dgb network
    menu_ask_dgb_network

    # Update digibyte.conf
    create_digibyte_conf

    printf " =============== Update: DigiByte Chain ==============================\\n\\n"
    # ==============================================================================

    # If we are switching to a mainnet/testnet node from Dual Node, shut down, disable and delete the secondary DigiByte Node
    if [ "$SETUP_DUAL_NODE" = "NO" ]; then

        # Restart Digibyted if the network has just been changed
        if [ "$DGB2_STATUS" = "running" ] || [ "$DGB2_STATUS" = "startingup" ]; then
            printf "%b Stopping DigiByte Core testnet daemon for Dual Node...\\n" "${INFO}"
            stop_service digibyted-testnet
            disable_service digibyted-testnet
        fi
        if [ "$DGB2_STATUS" = "stopped" ]; then
            printf "%b Disabling DigiByte Core testnet daemon for Dual Node...\\n" "${INFO}"
            disable_service digibyted-testnet
        fi

        # Delete systemd service file
        if [ -f "$DGB2_SYSTEMD_SERVICE_FILE" ]; then
            str="Deleting DigiByte testnet systemd service file for Dual Node..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $DGB2_SYSTEMD_SERVICE_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Delete upstart service file
        if [ -f "$DGB2_UPSTART_SERVICE_FILE" ]; then
            str="Deleting DigiByte testnet upstart service file for Dual Node..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $DGB2_UPSTART_SERVICE_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        DGB2_STATUS="not_detected"

        DGB_DUAL_NODE="NO"
        sed -i -e "/^DGB_DUAL_NODE=/s|.*|DGB_DUAL_NODE=\"NO\"|" $DGNT_SETTINGS_FILE

    fi

    # Restart primary DigiByte node if dgb network has changed
    if [ "$DGB_NETWORK_IS_CHANGED" = "YES" ]; then

        # Restart Digibyted if the network has just been changed
        if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ] || [ "$DGB_STATUS" = "stopped" ]; then
            printf "%b DigiByte Core network has been changed. DigiByte daemon will be restarted...\\n" "${INFO}"
            restart_service digibyted
        fi

    fi

    # Get updated digibyte.conf
    scrape_digibyte_conf

    # Get current chain
    query_digibyte_chain

    # Lookup new ports
    query_digibyte_port

    # Lookup new rpc credentials
    query_digibyte_rpc

    printf "\\n"

    # If we are switching from only a mainnet/testnet node to a Dual Node, generate the service file, and start the DigiByte Node
    if [ "$SETUP_DUAL_NODE" = "YES" ]; then

        create_digibyte_service_dualnode

    fi    

    # Run IPFS cehck to discover the current ports that are being used
    ipfs_check

    # update IPFS ports
    ipfs_update_port

    if [ "$kuboipfs_port_has_changed" = "yes" ]; then

        ipfsport=$IPFS_PORT_IP4

        # Restart IPFS Kubo if the IPFS port has just been changed
        if [ "$IPFS_STATUS" = "running" ] || [ "$IPFS_STATUS" = "stopped" ]; then

            # Restart IPFS if the IPFS Kubo has just been changed
            printf "%b IPFS Kubo port has been changed. IPFS daemon will be restarted...\\n" "${INFO}"
            restart_service ipfs
        fi

    fi

    if [ "$jsipfs_port_has_changed" = "yes" ]; then

        ipfsport=$JSIPFS_PORT_IP4

        # Restart IPFS if the upnp status has just been changed
        printf "%b JS-IPFS port has been changed. DigiAsset Node will be restarted...\\n" "${INFO}"
        sudo -u $USER_ACCOUNT pm2 restart digiasset

    fi

    printf "\\n"


#banana


    if [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$SETUP_DUAL_NODE" = "YES" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "You are now running a DigiByte Dual Node!" --title "You are now running a DigiByte Dual Node!" --msgbox "\nYour DigiByte Node has been changed to run both a MAINNET node and TESTNET node simultaneously.\\n\\nYour DigiByte listening ports are now $DGB_LISTEN_PORT (Mainnet) and $DGB2_LISTEN_PORT (Testnet). If you have not already done so, please open both these ports on your router.\\n\\nYour DigiByte RPC ports are now $RPC_PORT (Mainnet) and $RPC2_PORT (Testnet)." 15 ${c}


    # Display alert box informing the user that listening port and rpcport have changed.
    elif [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "You are now running on the DigiByte testnet!" --title "You are now running on the DigiByte testnet!" --msgbox "\nYour DigiByte Node has been changed to run on TESTNET.\\n\\nYour DigiByte testnet listening port is $DGB_LISTEN_PORT. If you have not already done so, please open this port on your router.\\n\\nYour DigiByte RPC port is now $RPC_PORT. This will have been changed if you were previously using the default port 14022 on mainnet." 13 ${c}

        # Prompt to delete the mainnet blockchain data if it already exists
        if [ -d "$DGB_DATA_LOCATION/indexes" ] || [ -d "$DGB_DATA_LOCATION/chainstate" ] || [ -d "$DGB_DATA_LOCATION/blocks" ]; then

            # Delete DigiByte blockchain data
            if dialog --no-shadow --keep-tite --colors --backtitle "Delete mainnet blockchain data?" --title "Delete mainnet blockchain data?" --yesno "\n\Z4Would you like to delete the DigiByte MAINNET blockchain data, since you are now running on TESTNET?\Z0\n\nIt is currently taking up ${DGB_DATA_DISKUSED_MAIN_HR}b of space on your drive. Deleting it will free up disk space on your device, but if you later decide to switch back to running on mainnet, you will need to re-sync the entire mainnet blockchain from scratch.\\n\\nNote: Your mainnet wallet will be kept." 15 "${c}"; then

                if [ -d "$DGB_DATA_LOCATION" ]; then
                    str="Deleting DigiByte Core MAINNET blockchain data..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -rf $DGB_DATA_LOCATION/indexes
                    rm -rf $DGB_DATA_LOCATION/chainstate
                    rm -rf $DGB_DATA_LOCATION/blocks
                    rm -f $DGB_DATA_LOCATION/banlist.dat
                    rm -f $DGB_DATA_LOCATION/banlist.json
                    rm -f $DGB_DATA_LOCATION/digibyted.pid
                    rm -f $DGB_DATA_LOCATION/fee_estimates.dat
                    rm -f $DGB_DATA_LOCATION/.lock
                    rm -f $DGB_DATA_LOCATION/mempool.dat
                    rm -f $DGB_DATA_LOCATION/peers.dat
                    rm -f $DGB_DATA_LOCATION/settings.json
                    DGB_DATA_DISKUSED_MAIN_HR=""
                    DGB_DATA_DISKUSED_MAIN_KB=""
                    DGB_DATA_DISKUSED_MAIN_PERC=""
                    sed -i -e "/^DGB_DATA_DISKUSED_MAIN_HR=/s|.*|DGB_DATA_DISKUSED_MAIN_HR=\"$DGB_DATA_DISKUSED_MAIN_HR\"|" $DGNT_SETTINGS_FILE
                    sed -i -e "/^DGB_DATA_DISKUSED_MAIN_KB=/s|.*|DGB_DATA_DISKUSED_MAIN_KB=\"$DGB_DATA_DISKUSED_MAIN_KB\"|" $DGNT_SETTINGS_FILE
                    sed -i -e "/^DGB_DATA_DISKUSED_MAIN_PERC=/s|.*|DGB_DATA_DISKUSED_MAIN_PERC=\"$DGB_DATA_DISKUSED_MAIN_PERC\"|" $DGNT_SETTINGS_FILE
                    DGB_BLOCKSYNC_VALUE=""
                    sed -i -e "/^DGB_BLOCKSYNC_VALUE=/s|.*|DGB_BLOCKSYNC_VALUE=\"$DGB_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi
                printf "\\n"

            else
                printf "%b You chose to keep the existing DigiByte mainnet blockchain data.\\n" "${INFO}"
                printf "\\n"
            fi
        fi

    elif [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "You are now running on the DigiByte mainnet!" --title "You are now running on the DigiByte mainnet!" --msgbox "\nYour DigiByte Node has been changed to run on MAINNET.\\n\\nIt is currently taking up ${DGB_DATA_DISKUSED_MAIN_HR}b of space on your drive. Your DigiByte mainnet listening port is $DGB_LISTEN_PORT. If you have not already done so, please open this port on your router.\\n\\nYour DigiByte RPC port is now $RPC_PORT. This will have been changed if you were previously using the default port 14023 on testnet." 14 ${c}

        # Prompt to delete the testnet blockchain data if it already exists
        if [ -d "$DGB_DATA_LOCATION/testnet4/indexes" ] || [ -d "$DGB_DATA_LOCATION/testnet4/chainstate" ] || [ -d "$DGB_DATA_LOCATION/testnet4/blocks" ]; then

            # Delete DigiByte blockchain data
            if dialog --no-shadow --keep-tite --colors --backtitle "Delete testnet blockchain data?" --title "Delete testnet blockchain data?" --yesno "\n\Z4Would you like to delete the DigiByte TESTNET blockchain data, since you are now running on MAINNET?\Z0\n\nIt is currently taking up ${DGB_DATA_DISKUSED_TEST_HR}b of space on your drive. Deleting it will free up disk space on your device, but if you later decide to switch back to running on testnet, you will need to re-sync the entire testnet blockchain which can take several hours.\n\nNote: Your testnet wallet will be kept." 15 "${c}"; then

                if [ -d "$DGB_DATA_LOCATION/testnet4" ]; then
                    str="Deleting DigiByte Core TESTNET blockchain data..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -rf $DGB_DATA_LOCATION/testnet4/indexes
                    rm -rf $DGB_DATA_LOCATION/testnet4/chainstate
                    rm -rf $DGB_DATA_LOCATION/testnet4/blocks
                    rm -f $DGB_DATA_LOCATION/testnet4/banlist.dat
                    rm -f $DGB_DATA_LOCATION/testnet4/banlist.json
                    rm -f $DGB_DATA_LOCATION/testnet4/digibyted.pid
                    rm -f $DGB_DATA_LOCATION/testnet4/fee_estimates.dat
                    rm -f $DGB_DATA_LOCATION/testnet4/.lock
                    rm -f $DGB_DATA_LOCATION/testnet4/mempool.dat
                    rm -f $DGB_DATA_LOCATION/testnet4/peers.dat
                    rm -f $DGB_DATA_LOCATION/testnet4/settings.json
                    DGB_DATA_DISKUSED_TEST_HR=""
                    DGB_DATA_DISKUSED_TEST_KB=""
                    DGB_DATA_DISKUSED_TEST_PERC=""
                    sed -i -e "/^DGB_DATA_DISKUSED_TEST_HR=/s|.*|DGB_DATA_DISKUSED_TEST_HR=\"$DGB_DATA_DISKUSED_TEST_HR\"|" $DGNT_SETTINGS_FILE
                    sed -i -e "/^DGB_DATA_DISKUSED_TEST_KB=/s|.*|DGB_DATA_DISKUSED_TEST_KB=\"$DGB_DATA_DISKUSED_TEST_KB\"|" $DGNT_SETTINGS_FILE
                    sed -i -e "/^DGB_DATA_DISKUSED_TEST_PERC=/s|.*|DGB_DATA_DISKUSED_TEST_PERC=\"$DGB_DATA_DISKUSED_TEST_PERC\"|" $DGNT_SETTINGS_FILE
                    DGB2_BLOCKSYNC_VALUE=""
                    sed -i -e "/^DGB2_BLOCKSYNC_VALUE=/s|.*|DGB2_BLOCKSYNC_VALUE=\"$DGB2_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
                    DGB_BLOCKSYNC_VALUE=""
                    sed -i -e "/^DGB_BLOCKSYNC_VALUE=/s|.*|DGB_BLOCKSYNC_VALUE=\"$DGB_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi
                printf "\\n"

            else
                printf "%b You chose to keep the existing DigiByte mainnet blockchain data.\\n" "${INFO}"
                printf "\\n"
            fi
        fi  
    fi


    # Display alert box informing the user that the IPFS port changed.
    if [ "$kuboipfs_port_has_changed" = "yes" ] || [ "$jsipfs_port_has_changed" = "yes" ]; then
        dialog --no-shadow --keep-tite --colors --backtitle "Your IPFS port has been changed!" --title "Your IPFS port has been changed!" --msgbox "\nYour IPFS port has been changed to $ipfsport.\\n\\nIf you have not already done so, please open this port on your router.\\n\\nNote: This change is to ensure you can run both a mainnet DigiNode and a testnet DigiNode on the same network without them conflicting with each other." 14 ${c}
  
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
        display_digifact_fixedwidth

    fi

    # Display donation QR Code
    donation_qrcode

    # Show final messages - Display reboot message (and how to run DigiNode Dashboard)
    final_messages

    # Share backup reminder
    backup_reminder

    exit

}


# A function for displaying the dialogs the user sees when first running DigiNode Setup
welcomeDialogs() {
    # Display the welcome dialog using an appropriately sized window via the calculation conducted earlier in the script
    dialog --no-shadow --keep-tite --colors --backtitle "Welcome to DigiNode Setup" --title "Welcome to DigiNode Setup" --msgbox "\nDigiNode Setup will help you to setup and manage a DigiByte Node and a DigiAsset Node on this device.\n\nRunning a \Z4DigiByte Full Node\Z0 means you have a complete copy of the DigiByte blockchain on your device and are helping contribute to the decentralization and security of the blockchain network.\n\nWith a \Z4DigiAsset Node\Z0 you are helping to decentralize and redistribute DigiAsset metadata. It also gives you the ability to create your own DigiAssets via the built-in web UI, and additionally lets you earn DGB in exchange for hosting the DigiAsset metadata of others. \n\nTo learn more, visit: $DGBH_URL_INTRO\n\n\ZbTip: To open a link from the terminal, hold Cmd (Mac) or Ctrl (Windows) and click the URL.\ZB" 23 ${c}

    #!! Temp message re digiasset node not working
    dialog --no-shadow --keep-tite --colors --backtitle "IMPORTANT - Please Read!" --title "IMPORTANT - Please Read!" --msgbox "\n\Z1IMPORTANT: It is not currently possible to set up a DigiAsset Node.\Z0\\n\\nThis features has temporarily been removed as the legacy DigiAsset Node software is no longer functioing correctly. Support the new DigiAsset Core will be added in an upcoming release.\n\nFor now, you can still install a DigiByte Node." 14 ${c}

    # Use must agree to the softare disclaimer
    disclaimerDialog

    # Request that users donate if they find DigiNode Setup useful
    donationDialog

    # Explain the need for a static address
    if dialog --no-shadow --keep-tite --colors --backtitle "Your DigiNode needs a Static IP address." --title "Your DigiNode needs a Static IP address." --yes-label "Continue" --no-label "Exit" --yesno "\n\Z1IMPORTANT: Your DigiNode is a SERVER so it needs a STATIC IP ADDRESS to function properly.\Z0\n\nIf you have not already done so, you must ensure that this device has a static IP address on the network. This can be done through DHCP reservation, or by manually assigning one. Depending on your operating system, there are many ways to achieve this.\n\nThe current IP address is: $IP4_INTERNAL\n\nFor more help, please visit: $DGBH_URL_STATICIP\n\nChoose Continue to indicate that you have understood this message." 20 "${c}"; then
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

dialog --no-shadow --keep-tite --colors --backtitle "Please donate to support DigiNode Tools" --title "Please donate to support DigiNode Tools" --no-collapse --msgbox "
\Z4DigiNode Tools is DONATIONWARE.\Z0 Please donate to support future development:

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

           dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup" 26 70
}

# Request that users donate if they find DigiNode Setup useful
disclaimerDialog() {

if [ "$DIGINODE_DISCLAIMER" != "I Agree" ]; then

    # DigiNode Tools Disclaimer Text
    DISCLAIMER="\n
    \Z4DigiNode Tools Software Disclaimer\Z0\n\n
    By selecting 'I Agree', you acknowledge and agree to the following terms:\n\n
    1. \Z4No Warranty\Z0: The DigiNode Tools software is provided \"as is\", without warranty of any kind, express or implied. In no event shall the author, copyright holder, or distributor of this software be liable for any claim, damages, or other liabilities, arising from its use. DigiNode Tools is offered as donationware, meaning it is available for use free of charge and relies on donations from its users.\n\n
    2. \Z4No Liability for Loss of Funds\Z0: The creator of DigiNode Tools shall not be held liable for any losses, damages, or issues arising from the use of the integrated DigiByte wallet or any cryptocurrency transactions conducted through it. This includes, but is not limited to, losses due to fluctuations in cryptocurrency value, technical errors in the software, transaction failures, unauthorized access, security breaches, or any other issues related to the use, storage, or management of DigiByte within the wallet.\n\n
    3. \Z4User Responsibility\Z0: You, as the user, are solely responsible for the security and backup of your DigiByte and other digital assets. It is your responsibility to take appropriate measures to safeguard your funds, including maintaining reliable backups of your digital assets and private keys.\n\n
    4. \Z4Acceptance of Risk\Z0: You acknowledge that the use of DigiNode Tools and interaction with blockchain technology carries inherent risks. You hereby assume full responisbility for the risks associated with the use of DigiNode Tools and its DigiByte wallet.\n\n
    5. \Z4Compliance with Laws\Z0: You agree to use DigiNode Tools in compliance with all applicable laws and regulations.\n\n
    6. \Z4Software License\Z0: DigiNode Tools is licensed under the PolyForm Perimeter 1.0.0 license. For more information view the full licence at: https://diginode.tools/software-licence/\n\n
    7. \Z4Amendments\Z0: The creator of DigiNode Tools reserves the right to modify this disclaimer at any time. Continued use of the software after any such changes shall constitute your consent to such changes."

    # Display the disclaimer in a scrollable dialog box
    dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Tools Disclaimer" --title "DigiNode Tools Disclaimer" --yes-label "I Agree" --no-label "I Do Not Agree" --yesno "$DISCLAIMER" 29 "${c}"

    # Get the exit status
    response=$?

    case $response in
    0) printf "%b You agreed to the DigiNode Tools Software Disclaimer.\\n" "${INFO}"; DIGINODE_DISCLAIMER="I Agree"; sed -i -e "/^DIGINODE_DISCLAIMER=/s|.*|DIGINODE_DISCLAIMER=\"I Agree\"|" $DGNT_SETTINGS_FILE; printf "\\n";;
    1) printf "%b You did NOT agree to the DigiNode Tools Software Disclaimer.\\n" "${INFO}"; DIGINODE_DISCLAIMER="Ask"; sed -i -e "/^DIGINODE_DISCLAIMER=/s|.*|DIGINODE_DISCLAIMER=\"Ask\"|" $DGNT_SETTINGS_FILE; printf "\\n"; printf "\\n"; exit;;
    255) "%b You did NOT agree to the DigiNode Tools Software Disclaimer.\\n" "${INFO}"; DIGINODE_DISCLAIMER="Ask"; sed -i -e "/^DIGINODE_DISCLAIMER=/s|.*|DIGINODE_DISCLAIMER=\"Ask\"|" $DGNT_SETTINGS_FILE; printf "\\n"; printf "\\n"; exit;;
    esac

fi

}

# If this is the first time running DigiNode Setup, and the diginode.settings file has just been created,
# ask the user if they want to EXIT to customize their install settings.

ask_customize() {

if [ "$IS_DGNT_SETTINGS_FILE_NEW" = "YES" ]; then

    if dialog --no-shadow --keep-tite --colors --backtitle "Customize your DigiNode install (Optional)" --title "Customize your DigiNode install (Optional)" --yes-label "Continue" --no-label "Exit" --yesno "\nBefore proceeding, you may wish to edit the diginode.settings file that has just been created in the ~/.digibyte folder.\n\nThis is for advanced users who want to customize their install, such as to change the location of where the DigiByte blockchain data is stored.\n\nIn most cases, there should be no need to do this, and you can safely continue with the defaults.\n\nFor more information on customizing your installation, visit: $DGBH_URL_CUSTOM\n\nChoose 'Continue' to proceed with the defaults. (Recommended)\n\nChoose 'Exit' to first customize your install." 22 "${c}"; then

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
create_digibyte_service() {

# If you want to make changes to how DigiByte daemon services are created/managed for different systems, refer to this website:
#

# If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
if [ "$RESET_MODE" = true ]; then

    # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
    if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB_UPSTART_SERVICE_FILE" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --title "Reset Mode" --yesno "\nDo you want to re-create your digibyted.service file?\\n\\nNote: This will delete your current systemd service file and re-create with default settings. Any customisations will be lost.\\n\\nNote: The service file ensures that the DigiByte Core daemon starts automatically after a reboot or if it crashes." 13 "${c}"; then
            DGB_SERVICE_CREATE=YES
            DGB_SERVICE_INSTALL_TYPE="reset"
        else
            printf " =============== Reset: DigiByte daemon service ====================\\n\\n"
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

        str="Reset Mode: Deleting DigiByte daemon systemd service file..."
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

        str="Creating DigiByte daemon systemd service file... "
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
    -daemon \
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
        printf "%b For help, please contact $SOCIAL_BLUESKY_HANDLE on Bluesky: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
        exit 1

    fi

printf "\\n"

fi

}

# Create the secondary DigiByte service file for the testnet daemon, when runnning a DigiByte Dual Node
create_digibyte_service_dualnode() {

# Only run if we are setting up a Dual Node
if [ "$SETUP_DUAL_NODE" = "YES" ]; then

    # If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
    if [ "$RESET_MODE" = true ]; then

        # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
        if [ -f "$DGB2_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB2_UPSTART_SERVICE_FILE" ]; then

            if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --title "Reset Mode" --yesno "\n\Z4Do you want to re-create your digibyted-testnet.service file?\Z0\n\nNote: This will delete the testnet systemd service file used when running a Dual Node, and re-create it with default settings. Any customisations will be lost.\n\nNote: The service file ensures that the testnet DigiByte daemon starts automatically after a reboot or if it crashes." 14 "${c}"; then
                DGB2_SERVICE_CREATE=YES
                DGB2_SERVICE_INSTALL_TYPE="reset"
            else
                printf " =============== Reset: DigiByte Dual Node service file ============\\n\\n"
                # ==============================================================================
                printf "%b Reset Mode: You skipped re-configuring the DigiByte DUAL NODE daemon service for testnet.\\n" "${INFO}"
                printf "\\n"
                DGB2_SERVICE_CREATE=NO
                DGB2_SERVICE_INSTALL_TYPE="none"
                return
            fi
        fi
    fi

    # If the SYSTEMD service files do not yet exist, then assume this is a new install
    if [ ! -f "$DGB2_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then
                DGB2_SERVICE_CREATE="YES"
                DGB2_SERVICE_INSTALL_TYPE="new"
    fi

    # If the UPSTART service files do not yet exist, then assume this is a new install
    if [ ! -f "$DGB2_DAEMON_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
                DGB2_SERVICE_CREATE="YES"
                DGB2_SERVICE_INSTALL_TYPE="new"
    fi


    if [ "$DGB2_SERVICE_CREATE" = "YES" ]; then

        # Display section break
        if [ "$DGB2_SERVICE_INSTALL_TYPE" = "new" ]; then
            printf " =============== Install: DigiByte Dual Node service ===================\\n\\n"
            # ==============================================================================
        elif [ "$DGB2_SERVICE_INSTALL_TYPE" = "update" ]; then
            printf " =============== Update: DigiByte Dual Node service =======================\\n\\n"
            # ==============================================================================
        elif [ "$DGB2_SERVICE_INSTALL_TYPE" = "reset" ]; then
            printf " =============== Reset: DigiByte Dual Node service ========================\\n\\n"
            # ==============================================================================
        fi

        # If DigiByte testnet daemon systemd service file already exists, and we are in Reset Mode, stop it and delete it, since we will replace it
        if [ -f "$DGB2_SYSTEMD_SERVICE_FILE" ] && [ "$DGB2_SERVICE_INSTALL_TYPE" = "reset" ]; then

            printf "%b Reset Mode: You chose to re-create the digibyted-testnet systemd service file for Dual Node.\\n" "${INFO}"

            printf "%b Reset Mode: Stopping DigiByte testnet systemd service for Dual Node...\\n" "${INFO}"

            # Stop the service now
            systemctl stop digibyted-testnet

            printf "%b Reset Mode: Disabling DigiByte testnet systemd service for Dual Node...\\n" "${INFO}"

            # Disable the service now
            systemctl disable digibyted-testnet

            str="Reset Mode: Deleting DigiByte testnet systemd service file for Dual Node..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $DGB2_SYSTEMD_SERVICE_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If DigiByte testnet daemon upstart service file already exists, and we are in Reset Mode, stop it and delete it, since we will replace it
        if [ -f "$DGB2_UPSTART_SERVICE_FILE" ] && [ "$DGB2_SERVICE_INSTALL_TYPE" = "reset" ]; then

            printf "%b Reset Mode: You chose to re-create the digibyted-testnet upstart service file for Dual Node.\\n" "${INFO}"

            printf "%b Reset Mode: Stopping DigiByte testnet upstart service for Dual Node...\\n" "${INFO}"

            # Stop the service now
            service digibyted-testnet stop

            printf "%b Reset Mode: Disabling DigiByte testnet upstart service for Dual Node...\\n" "${INFO}"

            # Disable the service now
            service digibyted-testnet disable

            str="Reset Mode: Deleting DigiByte testnet systemd service file..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f $DGB2_UPSTART_SERVICE_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If using systemd and the DigiByte testnet daemon service file does not exist yet, let's create it
        if [ ! -f "$DGB2_SYSTEMD_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "systemd" ]; then

            # Create a new DigiByte daemon testnet service file for Dual Node

            str="Creating DigiByte testnet systemd service file for Dual Node... "
            printf "%b %s" "${INFO}" "${str}"
            touch $DGB2_SYSTEMD_SERVICE_FILE
            cat <<EOF > $DGB2_SYSTEMD_SERVICE_FILE
[Unit]
Description=DigiByte's distributed currency daemon - testnet on Dual Node
After=network.target

[Service]
User=$USER_ACCOUNT
Group=$USER_ACCOUNT

Type=forking
PIDFile=${DGB_SETTINGS_LOCATION}/testnet4/digibyted.pid
ExecStart=${DGB_DAEMON} -daemon -testnet -pid=${DGB_SETTINGS_LOCATION}/testnet4/digibyted.pid \\
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
            printf "%b Enabling DigiByte testnet systemd service for Dual Node...\\n" "${INFO}"
            systemctl enable digibyted-testnet

            # Start the service now
            printf "%b Starting DigiByte testnet systemd service for Dual Node...\\n" "${INFO}"
            systemctl start digibyted-testnet

            DGB_DUAL_NODE="YES"
            sed -i -e "/^DGB_DUAL_NODE=/s|.*|DGB_DUAL_NODE=\"YES\"|" $DGNT_SETTINGS_FILE

        fi


        # If using upstart and the DigiByte daemon service file does not exist yet, let's create it
        if [ ! -f "$DGB2_UPSTART_SERVICE_FILE" ] && [ "$INIT_SYSTEM" = "upstart" ]; then

            # Create a new DigiByte testnet upstart service file

            str="Creating DigiByte testnet upstart service file for Dual Node: $DGB2_UPSTART_SERVICE_FILE ... "
            printf "%b %s" "${INFO}" "${str}"
            touch $DGB2_UPSTART_SERVICE_FILE
            cat <<EOF > $DGB2_UPSTART_SERVICE_FILE
description "DigiByte Testnet Daemon for Dual Node"

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
    -daemon \
    -testnet \
    -pid="\$DIGIBYTED_PIDFILE" \
    -conf="\$DIGIBYTED_CONFIGFILE" \
    -datadir="\$DIGIBYTED_DATADIR" \

EOF
            printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"


            # Start the service now
            printf "%b Starting DigiByte testnet upstart service for Dual Node...\\n" "${INFO}"
            service digibyted start

            DGB_DUAL_NODE="YES"
            sed -i -e "/^DGB_DUAL_NODE=/s|.*|DGB_DUAL_NODE=\"YES\"|" $DGNT_SETTINGS_FILE

        fi

        # If using sysv-init or another unknown system, we don't yet support creating the DigiByte daemon service
        if [ "$INIT_SYSTEM" = "sysv-init" ] || [ "$INIT_SYSTEM" = "unknown" ]; then

            printf "%b Unable to create a DigiByte testnet service for Dual Node on your system - systemd/upstart not found.\\n" "${CROSS}"
            printf "%b For help, please contact $SOCIAL_BLUESKY_HANDLE on Bluesky: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
            printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
            exit 1

        fi

    printf "\\n"

    fi

fi

}

closing_banner_message() {  

    if [ "$NewInstall" = true ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
        printf " =======================================================================\\n"
        printf " ======== ${txtbgrn}Congratulations - Your DigiNode has been installed!${txtrst} ==========\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo "                    Thanks for supporting DigiByte!"
        echo ""
        echo "   Please let everyone know what you are helping support the DigiByte network"
        echo "   by sharing on social media using the hashtag #DigiNode"
        echo ""
    elif [ "$NewInstall" = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf " =======================================================================\\n"
        printf " ======== ${txtbgrn}DigiByte Node has been installed!${txtrst} ============================\\n"
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
        printf " ================== ${txtbgrn}DigiNode has been Reset!${txtrst} ===========================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo ""
    elif [ "$RESET_MODE" = true ] && [ "$DO_FULL_INSTALL" = "NO" ]; then
        printf " =======================================================================\\n"
        printf " ================== ${txtbgrn}DigiByte Node has been Reset!${txtrst} ======================\\n"
        printf " =======================================================================\\n\\n"
        # ==============================================================================
        echo ""
    elif [ "$DO_FULL_INSTALL" = "YES" ]; then
        if [ "$DIGINODE_UPGRADED" = "YES" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtbgrn}DigiNode has been Upgraded!${txtrst} ========================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        else
            if [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ];then
                printf " =======================================================================\\n"
                printf " =============== ${txtbgrn}DigiByte Core is now running on MAINNET!${txtrst} =============\\n"
                printf " =======================================================================\\n\\n"
                # ==============================================================================
            elif [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$DGB_NETWORK_FINAL" = "TESTNET" ];then
                printf " =======================================================================\\n"
                printf " =============== ${txtbgrn}DigiByte Core is now running on TESTNET!${txtrst} =============\\n"
                printf " =======================================================================\\n\\n"
                # ==============================================================================
            else
                printf " =======================================================================\\n"
                printf " ================== ${txtgrn}DigiNode is up to date!${txtrst} ============================\\n"
                printf " =======================================================================\\n\\n"
                # ==============================================================================
            fi
        fi
    elif [ "$DO_FULL_INSTALL" = "NO" ]; then
        if [ "$DIGINODE_UPGRADED" = "YES" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtbgrn}DigiByte Node has been Upgraded!${txtrst} ===================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        else
            if [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ];then
                printf " =======================================================================\\n"
                printf " =============== ${txtbgrn}DigiByte Core is now running on MAINNET!${txtrst} =============\\n"
                printf " =======================================================================\\n\\n"
                # ==============================================================================
            elif [ "$DGB_NETWORK_IS_CHANGED" = "YES" ] && [ "$DGB_NETWORK_FINAL" = "TESTNET" ];then
                printf " =======================================================================\\n"
                printf " =============== ${txtbgrn}DigiByte Core is now running on TESTNET!${txtrst} =============\\n"
                printf " =======================================================================\\n\\n"
                # ==============================================================================
            else
                printf " =======================================================================\\n"
                printf " ================== ${txtgrn}DigiNode is up to date!${txtrst} ============================\\n"
                printf " =======================================================================\\n\\n"
                # ==============================================================================
            fi
        fi
    else
        if [ "$DGNT_INSTALL_TYPE" = "new" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtbgrn}DigiNode Tools have been installed!${txtrst} ================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "upgrade" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtbgrn}DigiNode Tools have been upgraded!${txtrst} =================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "none" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtbgrn}DigiNode Tools are up to date!${txtrst} =====================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        elif [ "$DGNT_INSTALL_TYPE" = "reset" ];then
            printf " =======================================================================\\n"
            printf " ================== ${txtbgrn}DigiNode Tools have been reset!${txtrst} ====================\\n"
            printf " =======================================================================\\n\\n"
            # ==============================================================================
        fi
    fi
}


donation_qrcode() {  

    printf " ============== ${txtbylw}PLEASE DONATE TO SUPPORT DIGINODE TOOLS${txtrst} ================\\n\\n"
    # ==============================================================================

    echo "   I created DigiNode Tools to make it easy for everybody to run a"
    echo "   DigiByte Node and DigiAsset Node. I have devoted thousands of hours"
    echo "   working on this goal, all for the benefit of the DigiByte community."
    echo "   This software is DONATIONWARE. If you find it useful, you are kindly"
    echo "   requested to make a donation so that I can keep improving it."
    echo "   Thank you very much for your support, Olly"
    echo ""
    echo -e "                    >> Find me on Bluesky \e]8;;http://bsky.app.com/profile/olly.st\a@olly.st\e]8;;\a. <<"
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

# Get the wallet balance from the primary DigiByte Node, remove trailing zeroes and seperate into commas
get_dgb_wallet_balance() {
    DGB_WALLET_BALANCE=$($DGB_CLI getbalance 2>/dev/null)
    # If the wallet balance is 0, then set the value to "" so it is hidden
    if [ "$DGB_WALLET_BALANCE" = "0.00000000" ]; then
        DGB_WALLET_BALANCE=""
    elif [ "$DGB_WALLET_BALANCE" != "" ]; then
        # Remove any trailing zeroes and decimal point
        DGB_WALLET_BALANCE=$(echo "$DGB_WALLET_BALANCE" | sed '/\./ s/\.\{0,1\}0\{1,\}$//')

        if [[ "$DGB_WALLET_BALANCE" =~ ^[0-9]+$ ]]; then # If the balance is an integer format the number with commas
            DGB_WALLET_BALANCE=$(printf "%'d" $DGB_WALLET_BALANCE)
        else
            DGB_WALLET_BALANCE_DECIMAL=$(echo $DGB_WALLET_BALANCE | cut -d'.' -f2)
            DGB_WALLET_BALANCE_INTEGER=$(echo $DGB_WALLET_BALANCE | cut -d'.' -f1)
            DGB_WALLET_BALANCE_INTEGER=$(printf "%'d" $DGB_WALLET_BALANCE_INTEGER)
            DGB_WALLET_BALANCE=${DGB_WALLET_BALANCE_INTEGER}.${DGB_WALLET_BALANCE_DECIMAL}
        fi
    fi
}

# Get the wallet balance from the secondary DigiByte Node, remove trailing zeroes and seperate into commas
get_dgb2_wallet_balance() {
    DGB2_WALLET_BALANCE=$($DGB_CLI -testnet getbalance 2>/dev/null)
    # If the wallet balance is 0, then set the value to "" so it is hidden
    if [ "$DGB2_WALLET_BALANCE" = "0.00000000" ]; then
        DGB2_WALLET_BALANCE=""
    elif [ "$DGB2_WALLET_BALANCE" != "" ]; then
        # Remove any trailing zeroes and decimal point
        DGB2_WALLET_BALANCE=$(echo "$DGB2_WALLET_BALANCE" | sed '/\./ s/\.\{0,1\}0\{1,\}$//')

        if [[ "$DGB2_WALLET_BALANCE" =~ ^[0-9]+$ ]]; then # If the balance is an integer format the number with commas
            DGB2_WALLET_BALANCE=$(printf "%'d" $DGB2_WALLET_BALANCE)
        else
            DGB2_WALLET_BALANCE_DECIMAL=$(echo $DGB2_WALLET_BALANCE | cut -d'.' -f2)
            DGB2_WALLET_BALANCE_INTEGER=$(echo $DGB2_WALLET_BALANCE | cut -d'.' -f1)
            DGB2_WALLET_BALANCE_INTEGER=$(printf "%'d" $DGB2_WALLET_BALANCE_INTEGER)
            DGB2_WALLET_BALANCE=${DGB_WALLET_BALANCE_INTEGER}.${DGB2_WALLET_BALANCE_DECIMAL}
        fi
    fi
}

# Backup reminder
backup_reminder() { 

    # Only display this once DigiNode is already installed
    if [ "$NewInstall" != true ]; then

        # Lookup current wallet balance
        get_dgb_wallet_balance

        # If this is a full install, and no backup exists
        if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ] && [ "$DGA_CONFIG_BACKUP_DATE_ON_DIGINODE" = "" ] && [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ] && [ -f "$DGA_INSTALL_LOCATION/.officialdiginode" ] && [ "$DGB_WALLET_BALANCE" != "" ]; then

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
        if [ "$DGB_WALLET_BACKUP_DATE_ON_DIGINODE" = "" ] && [ -f "$DGB_INSTALL_LOCATION/.officialdiginode" ] && [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ] && [ "$DGB_WALLET_BALANCE" != "" ]; then

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
            printf "%b Access it at: ${txtbld}http://${HOSTNAME_AFTER_REBOOT}.local:8090${txtrst} or ${txtbld}http://${IP4_INTERNAL}:8090${txtrst}\\n" "${INDENT}"
        else
            printf "%b Access it at: ${txtbld}http://${IP4_INTERNAL}:8090${txtrst}\\n" "${INDENT}"       
        fi
        printf "\\n"
        if [ "$HOSTNAME_AFTER_REBOOT" != "diginode" ] || [ "$HOSTNAME_AFTER_REBOOT" != "diginode-testnet" ]; then
            if [ "$IP4_EXTERNAL" != "$IP4_INTERNAL" ]; then
                printf "%b If it is running in the cloud, try the external IP: ${txtbld}https://${IP4_EXTERNAL}:8090${txtrst}\\n" "${INDENT}"
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
        printf "%b To launch 'DigiNode Dashboard' enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b To launch 'DigiNode Setup' enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b Note: If this is your first time installing DigiNode Tools,\\n" "${INDENT}"
        printf "%b       these aliases will not work until you log out or reboot.\\n" "${INDENT}"
        printf "\\n"
    elif [ "$RESET_MODE" = true ]; then
        printf "%b %bAfter performing a reset, it is advisable to reboot your system.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To restart now enter: ${txtbld}sudo reboot${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b %b'DigiNode Tools' can be run locally from the command line.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        printf "%b To launch 'DigiNode Dashboard' enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
        printf "\\n"
        printf "%b To launch 'DigiNode Setup' enter: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
        printf "\\n"
    else
        if [ "$STATUS_MONITOR" = "false" ] && [ "$DGNT_RUN_LOCATION" = "remote" ]; then
            printf "%b %b'DigiNode Tools' can be run locally from the command line.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "%b To launch 'DigiNode Dashboard' enter: ${txtbld}diginode${txtrst}\\n" "${INDENT}"
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
            printf "\\n"
            printf "%b You can also try: ${txtbld}ssh ${USER_ACCOUNT}@${IP4_INTERNAL}${txtrst}\\n" "${INDENT}"
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
            printf "\\n"
            printf "%b You can also try: ${txtbld}ssh ${USER_ACCOUNT}@${IP4_INTERNAL}${txtrst}\\n" "${INDENT}"
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
            printf "\\n"
            printf "%b You can also try: ${txtbld}ssh ${USER_ACCOUNT}@${IP4_INTERNAL}${txtrst}\\n" "${INDENT}"
        else
            printf "%b Once rebooted, reconnect over SSH with: ${txtbld}ssh ${USER_ACCOUNT}@${IP4_INTERNAL}${txtrst}\\n" "${INDENT}"       
        fi
        printf "\\n"       
    fi

    if [ "$INSTALL_ERROR" = "YES" ] && [ $NewInstall = true ]; then
        printf "%b %bWARNING: One or more software downloads had errors!%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b Your DigiNode may not be fully functional. Try running DigiNode Setup again.\\n" "${INDENT}"
        printf "%b If the problem persists, please contact $SOCIAL_BLUESKY_HANDLE on Bluesky: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
        printf "\\n"
    fi

    if [ "$INSTALL_ERROR" = "YES" ] && [ $NewInstall = false ]; then
        printf "%b %bWARNING: One or more DigiNode updates could not be downloaded.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b There were errors when downloading updates. Try running DigiNode Setup again.\\n" "${INDENT}"
        printf "%b If the problem persists, please contact $SOCIAL_BLUESKY_HANDLE on Bluesky: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
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
# if [ -f "$DGB_CONF_FILE" ]; then

        # Update testnet status in settings if it exists and is blank, otherwise append it
#        if grep -q "testnet=1" $DGB_CONF_FILE; then
#            show_dgb_network_menu="maybe"
#        elif grep -q "testnet=0" $DGB_CONF_FILE; then
#            show_dgb_network_menu="maybe"
#        elif grep -q "testnet=" $DGB_CONF_FILE; then
#            show_dgb_network_menu="maybe"
#        else
#            show_dgb_network_menu="yes"
#        fi
# fi

# If this is a new install, prompt for mainnet or testnet
if [ "$NewInstall" = true ]; then
    show_dgb_network_menu="yes"
fi

# If we are running this from the main menu, always show the menu prompts
if [ "$show_dgb_network_menu" = "no" ] && [ "$FORCE_DISPLAY_DGB_NETWORK_MENU" = true ]; then
    show_dgb_network_menu="yes"
fi


if [ $VERBOSE_MODE = true ]; then
    echo "Verbose Mode - show_dgb_network_menu: $show_dgb_network_menu"
    echo "Verbose Mode - DGB_NETWORK_CURRENT: $DGB_NETWORK_CURRENT"
    echo "Verbose Mode - DGB_DUAL_NODE: $DGB_DUAL_NODE"
fi

# SHOW DGB NETWORK MENU

# Don't ask if we are running unattended
if [ ! "$UNATTENDED_MODE" == true ]; then

    # Display dgb network section break
    if [ "$show_dgb_network_menu" = "yes" ]; then

            printf " =============== DIGIBYTE CHAIN SELECTION ==============================\\n\\n"
            # ==============================================================================

    fi

    # Setup Menu options

    opt1a="1 MAINNET"
    opt1b=" Run DigiByte Core on Mainnet."

    opt2a="2 TESTNET"
    opt2b=" Run DigiByte Core on Testnet."

    opt3a="3 DUAL NODE"
    opt3b=" Run DigiByte Core on both Mainnet and Testnet."


    # SHOW THE DGB NETWORK MENU FOR A NEW INSTALL
    if [ "$show_dgb_network_menu" = "yes" ] && [ "$NewInstall" = true ]; then

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Chain Selection" --title "DigiByte Chain Selection" --cancel-label "Exit" --menu "\nPlease choose which DigiByte chain to run.\n\nUnless you are a developer, your first priority should always be to run a MAINNET node. However, to support developers building on DigiByte, consider also running a TESTNET node. The testnet is used by developers for testing - it is functionally identical to mainnet, except the DigiByte on it are worthless.\n\nTo best support the DigiByte blockchain, consider running a DUAL NODE. This will setup both a mainnet node and a testnet node to run simultaneously on this device.\n\n" 21 70 3 \
        "${opt1a}"  "${opt1b}" \
        "${opt2a}"  "${opt2b}" \
        "${opt3a}"  "${opt3b}" 3>&2 2>&1 1>&3) || \
        { printf "%b %bExit was selected.%b\\n\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; exit; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Setup DigiByte Core on Mainnet
            ${opt1a})
                printf "%b You chose to setup DigiByte Core on MAINNET.\\n" "${INFO}"
                DGB_NETWORK_OLD=""
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="NO"     
                ;;
            # Setup DigiByte Core on Testnet
            ${opt2a})
                printf "%b You chose to setup DigiByte Core on TESTNET.\\n" "${INFO}"
                DGB_NETWORK_OLD=""
                DGB_NETWORK_FINAL="TESTNET"
                SETUP_DUAL_NODE="NO"
                ;;
            # Setup DigiByte Core on Mainnet and Testnet (Dual Node)
            ${opt3a})
                printf "%b You chose to setup DigiByte Core as a DUAL NODE (Mainnet & Testnet).\\n" "${INFO}"
                DGB_NETWORK_OLD=""
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="YES"     
                ;;
        esac
        printf "\\n"

    # SHOW THE DGB NETWORK MENU FOR AN EXISTING TESTNET INSTALL
    elif [ "$show_dgb_network_menu" = "yes" ] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Chain Selection" --title "DigiByte Chain Selection" --no-label "Cancel" --radiolist "\nPlease choose which DigiByte chain to run.\n\nUnless you are a developer, your first priority should always be to run a MAINNET node. However, to support developers building on DigiByte, consider also running a TESTNET node. The testnet is used by developers for testing - it is functionally identical to mainnet, except the DigiByte on it are worthless.\n\nTo best support the DigiByte blockchain, consider running a DUAL NODE. This will setup both a mainnet node and a testnet node to run simultaneously on this device.\n\n\Z4Note: DigiByte Core is currently running a TESTNET node.\Z0\n\nUse the arrow keys and tap space bar to select an option:\n\n" 25 70 3 \
        "${opt1a}"  "${opt1b}" OFF \
        "${opt2a}"  "${opt2b}" ON \
        "${opt3a}"  "${opt3b}" OFF 3>&2 2>&1 1>&3) || \
        { printf "%b %bCancel was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; FORCE_DISPLAY_DGB_NETWORK_MENU=false; menu_existing_install; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Switch DigiByte Core from Testnet to Mainnet
            ${opt1a})
                printf "%b You chose to switch DigiByte Core from running TESTNET to running MAINNET.\\n" "${INFO}"
                DGB_NETWORK_OLD="TESTNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="NO"
                ;;
            # Leave DigiByte Core on Testnet
            ${opt2a})
                printf "%b You chose to leave DigiByte Core on TESTNET. Returning to menu...\\n" "${INFO}"
                DGB_NETWORK_OLD="TESTNET"
                DGB_NETWORK_FINAL="TESTNET"
                SETUP_DUAL_NODE="NO"
                menu_existing_install 
                ;;
            # Setup DigiByte Core as a Dual Node
            ${opt3a})
                printf "%b You chose to switch DigiByte Core from running TESTNET to a DUAL NODE\\n" "${INFO}"
                DGB_NETWORK_OLD="TESTNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="YES"     
                ;;
        esac
        printf "\\n"

    # SHOW THE DGB NETWORK MENU FOR AN EXISTING MAINNET INSTALL
    elif [ "$show_dgb_network_menu" = "yes" ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" != "YES" ]; then

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Chain Selection" --title "DigiByte Chain Selection" --no-label "Cancel" --radiolist "\nPlease choose which DigiByte chain to run.\n\nUnless you are a developer, your first priority should always be to run a MAINNET node. However, to support developers building on DigiByte, consider also running a TESTNET node. The testnet is used by developers for testing - it is functionally identical to mainnet, except the DigiByte on it are worthless.\n\nTo best support the DigiByte blockchain, consider running a DUAL NODE. This will setup both a mainnet node and a testnet node to run simultaneously on this device.\n\n\Z4Note: DigiByte Core is currently running a MAINNET node.\Z0\n\nUse the arrow keys and tap space bar to select an option:\n\n" 25 70 3 \
        "${opt1a}"  "${opt1b}" ON \
        "${opt2a}"  "${opt2b}" OFF \
        "${opt3a}"  "${opt3b}" OFF 3>&2 2>&1 1>&3) || \
        { printf "%b %bCancel was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; FORCE_DISPLAY_DGB_NETWORK_MENU=false; menu_existing_install; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Leave DigiByte Core on Mainnet
            ${opt1a})
                printf "%b You chose to leave DigiByte Core on MAINNET. Returning to menu...\\n" "${INFO}"
                DGB_NETWORK_OLD="MAINNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="NO"
                menu_existing_install 
                ;;
            # Switch DigiByte Core from Mainnet to Testnet
            ${opt2a})
                printf "%b You chose to switch DigiByte Core from running MAINNET to running TESTNET.\\n" "${INFO}"
                DGB_NETWORK_OLD="MAINNET"
                DGB_NETWORK_FINAL="TESTNET"
                SETUP_DUAL_NODE="NO"
                ;;
            # Setup DigiByte Core as a Dual Node
            ${opt3a})
                printf "%b You chose to switch DigiByte Core from running MAINNET to a DUAL NODE\\n" "${INFO}"
                DGB_NETWORK_OLD="TESTNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="YES"     
                ;;
        esac
        printf "\\n"

    # SHOW THE DGB NETWORK MENU FOR AN EXISTING DUAL NODE INSTALL
    elif [ "$show_dgb_network_menu" = "yes" ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Chain Selection" --title "DigiByte Chain Selection" --no-label "Cancel" --radiolist "\nPlease choose which DigiByte chain to run.\n\nUnless you are a developer, your first priority should always be to run a MAINNET node. However, to support developers building on DigiByte, consider also running a TESTNET node. The testnet is used by developers for testing - it is functionally identical to mainnet, except the DigiByte on it are worthless.\n\nTo best support the DigiByte blockchain, consider running a DUAL NODE. This will setup both a mainnet node and a testnet node to run simultaneously on this device.\n\n\Z4Note: DigiByte Core is currently running a DUAL NODE.\Z0\n\nUse the arrow keys and tap space bar to select an option:\n\n" 25 70 3 \
        "${opt1a}"  "${opt1b}" OFF \
        "${opt2a}"  "${opt2b}" OFF \
        "${opt3a}"  "${opt3b}" ON 3>&2 2>&1 1>&3) || \
        { printf "%b %bCancel was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; FORCE_DISPLAY_DGB_NETWORK_MENU=false; menu_existing_install; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Leave DigiByte Core on Mainnet
            ${opt1a})
                printf "%b You chose to switch DigiByte Core from running a DUAL NODE to running MAINNET.\\n" "${INFO}"
                DGB_NETWORK_OLD="MAINNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="NO"
                ;;
            # Switch DigiByte Core from Mainnet to Testnet
            ${opt2a})
                printf "%b You chose to switch DigiByte Core from running a DUAL NODE to running TESTNET.\\n" "${INFO}"
                DGB_NETWORK_OLD="MAINNET"
                DGB_NETWORK_FINAL="TESTNET"
                SETUP_DUAL_NODE="NO"
                ;;
            # Setup DigiByte Core as a Dual Node
            ${opt3a})
                printf "%b You chose to leave DigiByte Core running a DUAL NODE. Returning to menu...\\n" "${INFO}"
                DGB_NETWORK_OLD="MAINNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="YES"     
                menu_existing_install 
                ;;
        esac
        printf "\\n"

    elif [ "$show_dgb_network_menu" = "no" ]; then

        # If this is a DUAL NODE
        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
            DGB_NETWORK_OLD="MAINNET"
            DGB_NETWORK_FINAL="MAINNET"
            SETUP_DUAL_NODE="YES" 
        # or if it is just a regular MAINNET node
        elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
            DGB_NETWORK_OLD="MAINNET"
            DGB_NETWORK_FINAL="MAINNET"
            SETUP_DUAL_NODE="NO" 
        elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
            DGB_NETWORK_OLD="TESTNET"
            DGB_NETWORK_FINAL="TESTNET"
            SETUP_DUAL_NODE="NO" 
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
            DGB_NETWORK_OLD="REGTEST"
            DGB_NETWORK_FINAL="REGTEST"
            if [ "$DGB_DUAL_NODE" = "YES" ]; then
                SETUP_DUAL_NODE="YES" 
            else
                SETUP_DUAL_NODE="NO" 
            fi
        elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
            DGB_NETWORK_OLD="SIGNET"
            DGB_NETWORK_FINAL="SIGNET"
            if [ "$DGB_DUAL_NODE" = "YES" ]; then
                SETUP_DUAL_NODE="YES" 
            else
                SETUP_DUAL_NODE="NO" 
            fi
        fi

    fi

else


    # If we are running unattended, and the script wants to prompt the user with the dgb network menu, then get the values from diginode.settings

    # Display digibyte network section break
    if [ "$show_dgb_network_menu" = "yes" ]; then

        printf " =============== Unattended Mode: Set DigiByte Core Network ============\\n\\n"
        # ==============================================================================


        if [ "$UI_DGB_CHAIN" = "MAINNET" ]; then

            printf "%b Unattended Mode: DigiByte Core will run MAINNET chain\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_CHAIN value in diginode.settings)\\n" "${INDENT}"

            DGB_NETWORK_OLD=""
            DGB_NETWORK_FINAL="MAINNET"
            SETUP_DUAL_NODE="NO"

        elif [ "$UI_DGB_CHAIN" = "TESTNET" ]; then

            printf "%b Unattended Mode: DigiByte Core will run TESTNET chain\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_CHAIN value in diginode.settings)\\n" "${INDENT}"

            DGB_NETWORK_OLD=""
            DGB_NETWORK_FINAL="TESTNET"
            SETUP_DUAL_NODE="NO" 

        elif [ "$UI_DGB_CHAIN" = "DUALNODE" ]; then

            printf "%b Unattended Mode: DigiByte Core will run a DUAL NODE (Mainnet & Testnet) \\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_CHAIN value in diginode.settings)\\n" "${INDENT}"

            DGB_NETWORK_OLD=""
            DGB_NETWORK_FINAL="MAINNET"
            SETUP_DUAL_NODE="YES" 

        else

            if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
                printf "%b Unattended Mode: Skipping changing the DigiByte Core chain. It will remain running a DUAL NODE.\\n" "${INFO}"
            else
                printf "%b Unattended Mode: Skipping changing the DigiByte Core chain. It will remain on $DGB_NETWORK_CURRENT.\\n" "${INFO}"
            fi

            # If this is a DUAL NODE
            if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
                DGB_NETWORK_OLD="MAINNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="YES" 
            # or if it is just a regular MAINNET node
            elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
                DGB_NETWORK_OLD="MAINNET"
                DGB_NETWORK_FINAL="MAINNET"
                SETUP_DUAL_NODE="NO" 
            elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
                DGB_NETWORK_OLD="TESTNET"
                DGB_NETWORK_FINAL="TESTNET"
                SETUP_DUAL_NODE="NO" 
            elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
                DGB_NETWORK_OLD="REGTEST"
                DGB_NETWORK_FINAL="REGTEST"
                if [ "$DGB_DUAL_NODE" = "YES" ]; then
                    SETUP_DUAL_NODE="YES" 
                else
                    SETUP_DUAL_NODE="NO" 
                fi
            elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
                DGB_NETWORK_OLD="SIGNET"
                DGB_NETWORK_FINAL="SIGNET"
                if [ "$DGB_DUAL_NODE" = "YES" ]; then
                    SETUP_DUAL_NODE="YES" 
                else
                    SETUP_DUAL_NODE="NO" 
                fi
            fi

        fi

        printf "\\n"

    else

        printf " =============== Unattended Mode: Set DigiByte Core Network ============\\n\\n"
        # ==============================================================================        

        # If we are not changing the DigiByte network, then set the final as current

        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b Unattended Mode: Skipping changing the DigiByte Core chain. It will remain running a DUAL NODE.\\n" "${INFO}"
        else
            printf "%b Unattended Mode: Skipping changing the DigiByte Core chain. It will remain on $DGB_NETWORK_CURRENT.\\n" "${INFO}"
        fi

        # If this is a DUAL NODE
        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
            DGB_NETWORK_OLD="MAINNET"
            DGB_NETWORK_FINAL="MAINNET"
            SETUP_DUAL_NODE="YES" 
        # or if it is just a regular MAINNET node
        elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
            DGB_NETWORK_OLD="MAINNET"
            DGB_NETWORK_FINAL="MAINNET"
            SETUP_DUAL_NODE="NO" 
        elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
            DGB_NETWORK_OLD="TESTNET"
            DGB_NETWORK_FINAL="TESTNET"
            SETUP_DUAL_NODE="NO" 
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
            DGB_NETWORK_OLD="REGTEST"
            DGB_NETWORK_FINAL="REGTEST"
            if [ "$DGB_DUAL_NODE" = "YES" ]; then
                SETUP_DUAL_NODE="YES" 
            else
                SETUP_DUAL_NODE="NO" 
            fi
        elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
            DGB_NETWORK_OLD="SIGNET"
            DGB_NETWORK_FINAL="SIGNET"
            if [ "$DGB_DUAL_NODE" = "YES" ]; then
                SETUP_DUAL_NODE="YES" 
            else
                SETUP_DUAL_NODE="NO" 
            fi
        fi
  
        printf "\\n"

    fi

fi

}



# This function will ask the user if they want to enable or disable upnp for digibyte core and/or ipfs
menu_ask_upnp() {

local show_dgb_upnp_menu="no"
local show_ipfs_upnp_menu="no"

# FIRST DECIDE WHTHER TO SHOW THE UPNP MENU

# If digibyte.conf file does not exist yet, show the DGB upnp menu
if [ ! -f "$DGB_CONF_FILE" ]; then
    show_dgb_upnp_menu="yes"
fi

# If digibyte.conf file already exists, show the upnp menu if it does not contain upnp variables
if [ -f "$DGB_CONF_FILE" ]; then

        # Update upnp status in settings if it exists and is blank, otherwise append it
        if grep -q "^upnp=1" $DGB_CONF_FILE; then
            show_dgb_upnp_menu="maybe"
            UPNP_DGB_CURRENT=1
        elif grep -q "^upnp=0" $DGB_CONF_FILE; then
            show_dgb_upnp_menu="maybe"
            UPNP_DGB_CURRENT=0
        elif grep -q "^upnp=" $DGB_CONF_FILE; then
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

# Disable the DigiByte UPnP menu if Tor is enabled
if [ "$DGB_TOR_MAINNET" = "ON" ] || [ "$DGB_TOR_TESTNET" = "ON" ]; then
    show_dgb_upnp_menu="no"
fi

# IF THIS IS A FULL INSTALL CHECK FOR IPFS Kubo

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    local try_for_jsipfs="no"

    # If there are not any IPFS config files, show the menu
    if [ ! -f "$USER_HOME/.ipfs/config" ] && [ ! -f "$USER_HOME/.jsipfs/config" ]; then
        show_ipfs_upnp_menu="yes"
    fi

    # Is there a working version of IPFS Kubo available?
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
#    if [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
#        show_ipfs_upnp_menu="yes"
#    fi

    # If we are running this from the main menu, always show the menu prompts
    if [ "$FORCE_DISPLAY_UPNP_MENU" = true ]; then
        show_ipfs_upnp_menu="yes"
    fi

fi

    # Get current digibyte listen port
    port=""
    DGB_LISTEN_PORT=$(sudo -u $USER_ACCOUNT $DGB_CLI getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)
    if  [ "$DGB_LISTEN_PORT" = "" ] || [ "$DGB_LISTEN_PORT" = "null" ]; then
        # Re-source config file
        if [ -f "$DGB_CONF_FILE" ]; then
            # Import variables from global section of digibyte.conf
            str="Located digibyte.conf file. Importing..."
            printf "%b %s" "${INFO}" "${str}"
            scrape_digibyte_conf
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Import variables from global section of digibyte.conf
            str="Getting digibyte.conf global variables..."
            printf "%b %s" "${INFO}" "${str}"
            eval "$DIGIBYTE_CONFIG_GLOBAL"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
        if [ "$DGB_NETWORK_FINAL" = "TESTNET" ] && [ "$port" = "" ]; then
            DGB_LISTEN_PORT="12026"
        elif [ "$DGB_NETWORK_FINAL" = "TESTNET" ] && [ "$port" = "12024" ]; then
            DGB_LISTEN_PORT="12026"
        elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$port" = "" ]; then
            DGB_LISTEN_PORT="12024"
        elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$port" = "12026" ]; then
            DGB_LISTEN_PORT="12024"
        elif [ "$DGB_NETWORK_FINAL" = "REGTEST" ] && [ "$port" = "" ]; then
            DGB_LISTEN_PORT="18444"
        elif [ "$DGB_NETWORK_FINAL" = "SIGNET" ] && [ "$port" = "" ]; then
            DGB_LISTEN_PORT="38443"
        else
            DGB_LISTEN_PORT="$port"   
        fi
    fi


    # If we will be running mainnet, get current listening port from [main] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_FINAL" = "MAINNET" ]; then
        DGB_LISTEN_PORT_MAIN=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^port= | cut -d'=' -f 2)
        if [ "$DGB_LISTEN_PORT_MAIN" != "" ]; then
            DGB_LISTEN_PORT="$DGB_LISTEN_PORT_MAIN"
        fi
    fi

    # If we will be running testnet, get current listening port from [test] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_FINAL" = "TESTNET" ]; then
        DGB_LISTEN_PORT_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^port= | cut -d'=' -f 2)
        if [ "$DGB_LISTEN_PORT_TEST" != "" ]; then
            DGB_LISTEN_PORT="$DGB_LISTEN_PORT_TEST"
        fi
    fi

    # If we will be running regtest, get current listening port from [regtest] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_FINAL" = "REGTEST" ]; then
        DGB_LISTEN_PORT_REGTEST=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^port= | cut -d'=' -f 2)
        if [ "$DGB_LISTEN_PORT_REGTEST" != "" ]; then
            DGB_LISTEN_PORT="$DGB_LISTEN_PORT_REGTEST"
        fi
    fi

    # If we will be running signet, get current listening port from [signet] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_FINAL" = "SIGNET" ]; then
        DGB_LISTEN_PORT_SIGNET=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^port= | cut -d'=' -f 2)
        if [ "$DGB_LISTEN_PORT_SIGNET" != "" ]; then
            DGB_LISTEN_PORT="$DGB_LISTEN_PORT_SIGNET"
        fi
    fi

    # banana

    # If we will be running a Dual Node, we also need to get the current testnet listening port
    if [ "$SETUP_DUAL_NODE" = "YES" ]; then

        if [ "$DGB_LISTEN_PORT_GLOBAL" = "" ]; then
            DGB2_LISTEN_PORT="12026"
            DGB2_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        else
            DGB2_LISTEN_PORT="$DGB_LISTEN_PORT_GLOBAL"   
            DGB2_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        fi

        # Get current listening port from [test] section of digibyte.conf, if available
        DGB2_LISTEN_PORT_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^port= | cut -d'=' -f 2)
        if [ "$DGB2_LISTEN_PORT_TEST" != "" ]; then
            DGB2_LISTEN_PORT="$DGB_LISTEN_PORT_TEST"
        fi

    fi


    # Get current ipfs listen port

    # Lookup the current IPFS Kubo ports
    if test -f "$USER_HOME/.ipfs/config"; then
        IPFS_PORT_IP4=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[0] | sed 's/"//g' | cut -d'/' -f5)
    fi

    # Lookup the current JS-IPFS ports
    if test -f "$USER_HOME/.jsipfs/config"; then
        JSIPFS_PORT_IP4=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[0] | sed 's/"//g' | cut -d'/' -f5)
    fi

    IPFS_LISTEN_PORT=""

    if [ "$IPFS_PORT_IP4" != "" ]; then
        IPFS_LISTEN_PORT=$IPFS_PORT_IP4
    fi
    if [ "$IPFS_LISTEN_PORT" != "" ] && [ "$JSIPFS_PORT_IP4" != "" ]; then
        IPFS_LISTEN_PORT=$JSIPFS_PORT_IP4
    fi

    if [ "$DGB_NETWORK_FINAL" = "TESTNET" ] && [ "$IPFS_LISTEN_PORT" = "" ]; then
        IPFS_LISTEN_PORT="4004"
    elif [ "$DGB_NETWORK_FINAL" = "TESTNET" ] && [ "$IPFS_LISTEN_PORT" = "4001" ]; then
        IPFS_LISTEN_PORT="4004"
    elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$IPFS_LISTEN_PORT" = "" ]; then
        IPFS_LISTEN_PORT="4001"
    elif [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$IPFS_LISTEN_PORT" = "4004" ]; then
        IPFS_LISTEN_PORT="4001"
    else
        IPFS_LISTEN_PORT="$IPFS_LISTEN_PORT"   
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
        upnp_current_status_1="Current Status:\\n"
    fi

    if [ "$UPNP_DGB_CURRENT" = "1" ]; then
        upnp_current_status_2=" - \Z4UPnP is ENABLED for DigiByte Core\Z0\\n"
    elif [ "$UPNP_DGB_CURRENT" = "0" ]; then
        upnp_current_status_2=" - \Z4UPnP is DISABLED for DigiByte Core\Z0\\n"
    fi

    if [ "$UPNP_IPFS_CURRENT" = "false" ]; then
        upnp_current_status_3=" - \Z4UPnP is ENABLED for IPFS\Z0\\n"
    elif [ "$UPNP_IPFS_CURRENT" = "true" ]; then
        upnp_current_status_3=" - \Z4UPnP is DISABLED for IPFS\Z0\\n"
    fi

    if [ "$upnp_current_status_2" != "" ] || [ "$upnp_current_status_3" != "" ]; then
        upnp_current_status="$upnp_current_status_1$upnp_current_status_2$upnp_current_status_3\\n"
    fi

    # Format dgb port message
    if [ "$SETUP_DUAL_NODE" = "YES" ]; then
        dgb_port_msg="  DigiByte Primary Node:    $DGB_LISTEN_PORT TCP\\n  DigiByte Secondary Node:  $DGB2_LISTEN_PORT TCP\\n"
    else
        dgb_port_msg="  DigiByte Node:    $DGB_LISTEN_PORT TCP\\n"
    fi


    # SHOW THE DGB + IPFS UPnP MENU
    if [ "$show_dgb_upnp_menu" = "yes" ] && [ "$show_ipfs_upnp_menu" = "yes" ]; then
        
        if dialog --no-shadow --keep-tite --colors --backtitle "Port Forwarding" --title "Port Forwarding" --yes-label "Setup Manually" --no-label "Use UPnP" --yesno "\n\Z4How would you like to setup port forwarding?\Z0\n\nTo make your device discoverable by other nodes on the Internet, you need to forward the following ports on your router:\n\n${dgb_port_msg}  DigiAsset Node:   $IPFS_LISTEN_PORT TCP\n\nIf you are comfortable configuring your router, it is recommended to do this manually. The alternative is to enable UPnP to automatically open the ports for you, though this can sometimes have issues depending on your router.\n\n${upnp_current_status}For help:\n$DGBH_URL_PORTFWD" 21 "${c}"; then
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

        if dialog --no-shadow --keep-tite --colors --backtitle "Port Forwarding" --title "Port Forwarding" --yes-label "Setup Manually" --no-label "Use UPnP" --yesno "\n\Z4How would you like to setup port forwarding?\Z0\n\nTo make your device discoverable by other nodes on the Internet, you need to forward the following port on your router:\n\n${dgb_port_msg}\nIf you are comfortable configuring your router, it is recommended to do this manually. The alternative is to enable UPnP to automatically open the ports for you, though this can sometimes have issues depending on your router.\n\n${upnp_current_status}For help:\n$DGBH_URL_PORTFWD" 23 "${c}"; then
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

    elif [ "$show_dgb_upnp_menu" = "no" ] && [ "$show_ipfs_upnp_menu" = "no" ]; then

        DGB_ENABLE_UPNP="SKIP"
        IPFS_ENABLE_UPNP="SKIP"

        # Disable UPnP
        if [ "$DGB_TOR_MAINNET" = "ON" ] || [ "$DGB_TOR_TESTNET" = "ON" ]; then
            DGB_ENABLE_UPNP="NO"
        fi

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

            printf "%b Unattended Mode: UPnP will be DISABLED for DigiByte Core\\n" "${INFO}"
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
            IPFS_ENABLE_UPNP="SKIP"

        fi
    fi

    # Insert blank row if anything was displayed above
    if [ "$show_dgb_upnp_menu" = "yes" ] || [ "$show_ipfs_upnp_menu" = "yes" ]; then  
        printf "\\n"
    fi


fi

}





# This function will ask the user if they want to enable or disable Tor for digibyte core and/or ipfs
menu_ask_tor() {

local show_dgb_tor_menu="no"
local show_ipfs_tor_menu="no"

# FIRST DECIDE WHTHER TO SHOW THE TOR MENU

# If digibyte.conf file does not exist yet, show the DGB tor menu
if [ ! -f "$DGB_CONF_FILE" ]; then
    local show_dgb_tor_menu="yes"
fi

# If this is a new install and the Tor values already exist
if [ "$NewInstall" = true ]; then
    local show_dgb_tor_menu="yes"
fi

# If we are running this from the main menu, always show the menu prompts
if [ "$show_dgb_tor_menu" = "no" ] && [ "$FORCE_DISPLAY_TOR_MENU" = true ]; then
    local show_dgb_tor_menu="yes"
fi




# IF THIS IS A FULL INSTALL CHECK FOR IPFS Kubo

#! if [ "$DO_FULL_INSTALL" = "YES" ]; then

#!     local try_for_jsipfs="no"

    # If there are not any IPFS config files, show the menu
#!     if [ ! -f "$USER_HOME/.ipfs/config" ] && [ ! -f "$USER_HOME/.jsipfs/config" ]; then
#!         show_ipfs_upnp_menu="yes"
#!     fi

    # Is there a working version of IPFS Kubo available?
#!     if [ -f "$USER_HOME/.ipfs/config" ]; then

#!         local test_kubo_query

#!         test_kubo_query=$(curl -X POST http://127.0.0.1:5001/api/v0/id 2>/dev/null)
#!         test_kubo_query=$(echo $test_kubo_query | jq .AgentVersion | grep -Eo kubo)

#!         # If this is Kubo, check the current UPNP status, otherwise test for JS-IPFS
#!         if [ "$test_kubo_query" = "kubo" ]; then

            # Is Kubo installed and running, and what is the upnp status?
#!             query_ipfs_upnp_status=$(sudo -u $USER_ACCOUNT ipfs config show 2>/dev/null | jq .Swarm.DisableNatPortMap)

#!             if [ "$query_ipfs_upnp_status" != "" ]; then
#!                 UPNP_IPFS_CURRENT=$query_ipfs_upnp_status
#!             else
#!                 try_for_jsipfs="yes"
#!             fi

#!         fi

#!     fi

    # If this is a new install, show the upnp prompt menu regardless
#    if [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
#        show_ipfs_upnp_menu="yes"
#    fi

    # If we are running this from the main menu, always show the menu prompts
 #!   if [ "$FORCE_DISPLAY_TOR_MENU" = true ]; then
 #!       show_ipfs_tor_menu="yes"
 #!   fi

#! fi

    # Get current Digibyte Tor status
    DGB_MAINNET_USING_TOR=""
    DGB_TESTNET_USING_TOR=""
    DGB_TOR_DUALNODE_FLAG=""
    DGB_TOR_MAINNET_ONLY_FLAG=""
    DGB_TOR_TESTNET_ONLY_FLAG=""
    DGB_TOR_NEITHER_FLAG=""
    DGB_TOR_MAINNET_TOR_FLAG=""
    DGB_TOR_MAINNET_CLEARNET_FLAG=""
    DGB_TOR_TESTNET_TOR_FLAG=""
    DGB_TOR_TESTNET_CLEARNET_FLAG=""
    DGB_TOR_MAIN_PROXY=""
    DGB_TOR_MAIN_TORCONTROL=""
    DGB_TOR_MAIN_BIND=""
    DGB_TOR_TEST_PROXY=""
    DGB_TOR_TEST_TORCONTROL=""
    DGB_TOR_TEST_BIND=""


    # Scrape digibyte.conf
    scrape_digibyte_conf

    DGB_TOR_MAIN_PROXY=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^proxy=127.0.0.1:9050)
    DGB_TOR_MAIN_TORCONTROL=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^torcontrol=127.0.0.1:9151)
    DGB_TOR_MAIN_BIND=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^bind=127.0.0.1=onion)
    if [ "$DGB_TOR_MAIN_PROXY" = "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_MAIN_TORCONTROL" = "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_MAIN_BIND" = "bind=127.0.0.1=onion" ]; then
        DGB_MAINNET_USING_TOR="YES"
    elif [ "$DGB_TOR_MAIN_PROXY" != "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_MAIN_TORCONTROL" != "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_MAIN_BIND" != "bind=127.0.0.1=onion" ]; then
        DGB_MAINNET_USING_TOR="NO"
    else
        DGB_MAINNET_USING_TOR=""
        local show_dgb_tor_menu="yes"
    fi

    DGB_TOR_TEST_PROXY=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^proxy=127.0.0.1:9050)
    DGB_TOR_TEST_TORCONTROL=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^torcontrol=127.0.0.1:9151)
    DGB_TOR_TEST_BIND=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^bind=127.0.0.1=onion)
    if [ "$DGB_TOR_TEST_PROXY" = "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_TEST_TORCONTROL" = "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_TEST_BIND" = "bind=127.0.0.1=onion" ]; then
        DGB_TESTNET_USING_TOR="YES"
    elif [ "$DGB_TOR_TEST_PROXY" != "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_TEST_TORCONTROL" != "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_TEST_BIND" != "bind=127.0.0.1=onion" ]; then
        DGB_TESTNET_USING_TOR="NO"
    else
        DGB_TESTNET_USING_TOR=""
        local show_dgb_tor_menu="yes"
    fi

    if [ "$VERBOSE_MODE" = true ]; then
        echo "DGB_TOR_MAIN_PROXY: $DGB_TOR_MAIN_PROXY"
        echo "DGB_TOR_MAIN_TORCONTROL: $DGB_TOR_MAIN_TORCONTROL"
        echo "DGB_TOR_MAIN_BIND: $DGB_TOR_MAIN_BIND"
        echo ""
        echo "DGB_MAINNET_USING_TOR: $DGB_MAINNET_USING_TOR"
        echo ""
        echo "DGB_TOR_TEST_PROXY: $DGB_TOR_TEST_PROXY"
        echo "DGB_TOR_TEST_TORCONTROL: $DGB_TOR_TEST_TORCONTROL"
        echo "DGB_TOR_TEST_BIND: $DGB_TOR_TEST_BIND"
        echo ""
        echo "DGB_TESTNET_USING_TOR: $DGB_TESTNET_USING_TOR"
        echo ""
        echo ""
    fi

    # Set Tor current status flags - dual node using tor
    if [ "$DGB_MAINNET_USING_TOR" = "YES" ] && [ "$DGB_TESTNET_USING_TOR" = "YES" ]; then
        DGB_TOR_DUALNODE_FLAG="ON"
    else
        DGB_TOR_DUALNODE_FLAG="OFF"
    fi
    # Set Tor current status flags - mainnet only
    if [ "$DGB_MAINNET_USING_TOR" = "YES" ] && [ "$DGB_TESTNET_USING_TOR" = "NO" ]; then
        DGB_TOR_MAINNET_ONLY_FLAG="ON"
    else
        DGB_TOR_MAINNET_ONLY_FLAG="OFF"
    fi
    # Set Tor current status flags - testnet only
    if [ "$DGB_MAINNET_USING_TOR" = "NO" ] && [ "$DGB_TESTNET_USING_TOR" = "YES" ]; then
        DGB_TOR_TESTNET_ONLY_FLAG="ON"
    else
        DGB_TOR_TESTNET_ONLY_FLAG="OFF"
    fi
    # Set Tor current status flags - neither using tor
    if [ "$DGB_MAINNET_USING_TOR" = "NO" ] && [ "$DGB_TESTNET_USING_TOR" = "NO" ]; then
        DGB_TOR_NEITHER_FLAG="ON"
    else
        DGB_TOR_NEITHER_FLAG="OFF"
    fi
    # Set Tor current status flag for Mainnet
    if [ "$DGB_MAINNET_USING_TOR" = "YES" ]; then
        DGB_TOR_MAINNET_TOR_FLAG="ON"
        DGB_TOR_MAINNET_CLEARNET_FLAG="OFF"
    else
        DGB_TOR_MAINNET_TOR_FLAG="OFF"
        DGB_TOR_MAINNET_CLEARNET_FLAG="ON"
    fi
    # Set Tor current status flag for Testnet
    if [ "$DGB_TESTNET_USING_TOR" = "YES" ]; then
        DGB_TOR_TESTNET_TOR_FLAG="ON"
        DGB_TOR_TESTNET_CLEARNET_FLAG="OFF"
    else
        DGB_TOR_TESTNET_TOR_FLAG="OFF"
        DGB_TOR_TESTNET_CLEARNET_FLAG="ON"
    fi

    if [ "$VERBOSE_MODE" = true ]; then
        echo "DGB_TOR_DUALNODE_FLAG: $DGB_TOR_DUALNODE_FLAG"
        echo "DGB_TOR_MAINNET_ONLY_FLAG: $DGB_TOR_MAINNET_ONLY_FLAG"
        echo "DGB_TOR_TESTNET_ONLY_FLAG: $DGB_TOR_TESTNET_ONLY_FLAG"
        echo "DGB_TOR_NEITHER_FLAG: $DGB_TOR_NEITHER_FLAG"
        echo ""
        echo "DGB_TOR_MAINNET_TOR_FLAG: $DGB_TOR_MAINNET_TOR_FLAG"
        echo "DGB_TOR_MAINNET_CLEARNET_FLAG: $DGB_TOR_MAINNET_CLEARNET_FLAG"
        echo "DGB_TOR_TESTNET_TOR_FLAG: $DGB_TOR_TESTNET_TOR_FLAG"
        echo "DGB_TOR_TESTNET_CLEARNET_FLAG: $DGB_TOR_TESTNET_CLEARNET_FLAG"
    fi


# SHOW TOR MENU

# Don't ask if we are running unattended
if [ ! "$UNATTENDED_MODE" == true ]; then

     # Configure Tor service
    enable_tor_service

    # Display Tor section break
    if [ "$show_dgb_tor_menu" = "yes" ] || [ "$show_ipfs_tor_menu" = "yes" ]; then

            printf " =============== TOR MENU ==============================================\\n\\n"
            # ==============================================================================

    fi

    # FOR A NEW INSTALL, DUAL NODE, SHOW THE DGB TOR MENU
    if [ "$show_dgb_tor_menu" = "yes" ]  && [ "$NewInstall" = true ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$SETUP_DUAL_NODE" = "YES" ]; then

        opt1a="1 BOTH"
        opt1b=" Run DigiByte Mainnet & Testnet Nodes over Tor. (Recommended)"

        opt2a="2 MAINNET ONLY"
        opt2b=" Run DigiByte Mainnet over Tor. Testnet runs on clearnet."

        opt3a="3 TESTNET ONLY"
        opt3b=" Run DigiByte Testnet over Tor. Mainnet runs on clearnet."

        opt4a="4 NEITHER"
        opt4b=" Neither DigiByte Mainnet or Testnet run over Tor. Both on clearnet."

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Tor Selection" --title "DigiByte Tor Selection" --cancel-label "Exit" --menu "\nPlease choose whether to run your DigiByte Nodes over Tor.\n\nRunning a DigiByte node over Tor hides your IP address, enhancing privacy and security by making it harder for others to trace your blockchain activity. In contrast, running a node over clearnet uses the regular internet, exposing your IP address and location, but generally offers faster connectivity.\n\nFor the Digibyte network, having more Tor nodes increases the overall privacy and security of the network, making it more resilient against surveillance and attacks.\n\nLearn more about Tor: https://www.torproject.org/\n\n" 22 95 4 \
        "${opt1a}"  "${opt1b}" \
        "${opt2a}"  "${opt2b}" \
        "${opt3a}"  "${opt3b}" \
        "${opt4a}"  "${opt4b}" 3>&2 2>&1 1>&3) || \
        { printf "%b %bExit was selected.%b\\n\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; exit; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Enable Tor for DigiByte Core on Mainnet & Testnet
            ${opt1a})
                printf "%b You chose to setup both DigiByte Mainnet and DigiByte Testnet to run over Tor.\\n" "${INFO}"
                DGB_TOR_MAINNET="ON"
                DGB_TOR_TESTNET="ON"   
                ;;
            # Enable Tor for DigiByte Core Mainnet ONLY
            ${opt2a})
                printf "%b You chose to setup DigiByte Mainnet to run over Tor. DigiByte Testnet will run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="ON"
                DGB_TOR_TESTNET="OFF"   
                ;;
            # Enable Tor for DigiByte Core Mainnet ONLY
            ${opt3a})
                printf "%b You chose to setup DigiByte Testnet to run over Tor. DigiByte Mainnet will run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="OFF"
                DGB_TOR_TESTNET="ON"     
                ;;
            # Enable Tor for DigiByte Core on Mainnet & Testnet
            ${opt4a})
                printf "%b You chose to setup both DigiByte Mainnet and DigiByte Testnet to run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="OFF"
                DGB_TOR_TESTNET="OFF"     
                ;;
        esac
        printf "\\n"

    # FOR A NEW INSTALL, TESTNET NODE ONLY, SHOW THE DGB TOR MENU
    elif [ "$show_dgb_tor_menu" = "yes" ]  && [ "$NewInstall" = true ] && [ "$DGB_NETWORK_FINAL" = "TESTNET" ] && [ "$SETUP_DUAL_NODE" = "NO" ]; then

        opt1a="1 TOR"
        opt1b=" Run DigiByte Testnet Node over Tor. (Recommended)"

        opt2a="2 CLEARNET"
        opt2b=" Run DigiByte Testnet over clearnet."

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Tor Selection" --title "DigiByte Tor Selection" --cancel-label "Exit" --menu "\nPlease choose whether to run your DigiByte Testnet Node over Tor.\n\nRunning a DigiByte node over Tor hides your IP address, enhancing privacy and security by making it harder for others to trace your blockchain activity. In contrast, running a node over clearnet uses the regular internet, exposing your IP address and location, but generally offers faster connectivity.\n\nFor the Digibyte network, having more Tor nodes increases the overall privacy and security of the network, making it more resilient against surveillance and attacks.\n\nLearn more about Tor: https://www.torproject.org/\n\n" 22 75 2 \
        "${opt1a}"  "${opt1b}" \
        "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
        { printf "%b %bExit was selected.%b\\n\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; exit; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Enable Tor for DigiByte Testnet
            ${opt1a})
                printf "%b You chose to setup DigiByte Testnet to run over Tor.\\n" "${INFO}"
                DGB_TOR_TESTNET="ON"  
                if [ "$DGB_MAINNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_MAINNET="ON"
                else
                    DGB_TOR_MAINNET="OFF"
                fi
                ;;
            # Disable Tor for DigiByte Testnet
            ${opt2a})
                printf "%b You chose to setup DigiByte Testnet to run over clearnet.\\n" "${INFO}"
                DGB_TOR_TESTNET="OFF"  
                if [ "$DGB_MAINNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_MAINNET="ON"
                else
                    DGB_TOR_MAINNET="OFF"
                fi
                ;;
        esac
        printf "\\n"

    # FOR A NEW INSTALL, MAINNET NODE ONLY, SHOW THE DGB TOR MENU
    elif [ "$show_dgb_tor_menu" = "yes" ]  && [ "$NewInstall" = true ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$SETUP_DUAL_NODE" = "NO" ]; then

        opt1a="1 TOR"
        opt1b=" Run DigiByte Mainnet Node over Tor. (Recommended)"

        opt2a="2 CLEARNET"
        opt2b=" Run DigiByte Mainnet over clearnet."

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Tor Selection" --title "DigiByte Tor Selection" --cancel-label "Exit" --menu "\nPlease choose whether to run your DigiByte Mainnet Node over Tor.\n\nRunning a DigiByte node over Tor hides your IP address, enhancing privacy and security by making it harder for others to trace your blockchain activity. In contrast, running a node over clearnet uses the regular internet, exposing your IP address and location, but generally offers faster connectivity.\n\nFor the Digibyte network, having more Tor nodes increases the overall privacy and security of the network, making it more resilient against surveillance and attacks.\n\nLearn more about Tor: https://www.torproject.org/\n\n" 22 75 2 \
        "${opt1a}"  "${opt1b}" \
        "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
        { printf "%b %bExit was selected.%b\\n\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; exit; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Enable Tor for DigiByte Mainnet
            ${opt1a})
                printf "%b You chose to setup DigiByte Mainnet to run over Tor.\\n" "${INFO}"
                DGB_TOR_MAINNET="ON"  
                if [ "$DGB_TESTNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_TESTNET="ON"
                else
                    DGB_TOR_TESTNET="OFF"
                fi
                ;;
            # Disable Tor for DigiByte Mainnet
            ${opt2a})
                printf "%b You chose to setup DigiByte Mainnet to run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="OFF"  
                if [ "$DGB_TESTNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_TESTNET="ON"
                else
                    DGB_TOR_TESTNET="OFF"
                fi
                ;;
        esac
        printf "\\n"

    # FOR AN EXISTING INSTALL, DUAL NODE, SHOW THE DGB TOR MENU
    elif [ "$show_dgb_tor_menu" = "yes" ]  && [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$SETUP_DUAL_NODE" = "YES" ]; then

        opt1a="1 BOTH"
        opt1b=" Run DigiByte Mainnet & Testnet Nodes over Tor. (Recommended)"

        opt2a="2 MAINNET ONLY"
        opt2b=" Run DigiByte Mainnet node over Tor. Testnet runs on clearnet."

        opt3a="3 TESTNET ONLY"
        opt3b=" Run DigiByte Testnet node over Tor. Mainnet runs on clearnet."

        opt4a="4 NEITHER"
        opt4b=" Neither DigiByte Mainnet or Testnet run over Tor. Both on clearnet."

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Tor Selection" --title "DigiByte Tor Selection" --no-label "Cancel" --radiolist "\nPlease choose whether to run your DigiByte Nodes over Tor.\n\nRunning a DigiByte node over Tor hides your IP address, enhancing privacy and security by making it harder for others to trace your blockchain activity. In contrast, running a node over clearnet uses the regular internet, exposing your IP address and location, but generally offers faster connectivity.\n\nFor the Digibyte network, having more Tor nodes increases the overall privacy and security of the network, making it more resilient against surveillance and attacks.\n\nLearn more about Tor: https://www.torproject.org/\n\n" 22 95 4 \
        "${opt1a}"  "${opt1b}" "${DGB_TOR_DUALNODE_FLAG}" \
        "${opt2a}"  "${opt2b}" "${DGB_TOR_MAINNET_ONLY_FLAG}" \
        "${opt3a}"  "${opt3b}" "${DGB_TOR_TESTNET_ONLY_FLAG}" \
        "${opt4a}"  "${opt4b}" "${DGB_TOR_NEITHER_FLAG}" 3>&2 2>&1 1>&3) || \
        { printf "%b %bCancel was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; FORCE_DISPLAY_TOR_MENU=false; menu_existing_install; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Enable Tor for DigiByte Core on Mainnet & Testnet
            ${opt1a})
                printf "%b You chose to setup both DigiByte Mainnet and DigiByte Testnet to run over Tor.\\n" "${INFO}"
                DGB_TOR_MAINNET="ON"
                DGB_TOR_TESTNET="ON"
                if [ "$DGB_TOR_DUALNODE_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi
                ;;
            # Enable Tor for DigiByte Core Mainnet ONLY
            ${opt2a})
                printf "%b You chose to setup DigiByte Mainnet to run over Tor. DigiByte Testnet will run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="ON"
                DGB_TOR_TESTNET="OFF"   
                if [ "$DGB_TOR_MAINNET_ONLY_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi
                ;;
            # Enable Tor for DigiByte Core Mainnet ONLY
            ${opt3a})
                printf "%b You chose to setup DigiByte Testnet to run over Tor. DigiByte Mainnet will run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="OFF"
                DGB_TOR_TESTNET="ON"    
                if [ "$DGB_TOR_TESTNET_ONLY_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi   
                ;;
            # Enable Tor for DigiByte Core on Mainnet & Testnet
            ${opt4a})
                printf "%b You chose to setup both DigiByte Mainnet and DigiByte Testnet to run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="OFF"
                DGB_TOR_TESTNET="OFF"    
                if [ "$DGB_TOR_NEITHER_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi       
                ;;
        esac
        printf "\\n"

    # FOR AN EXISTING INSTALL, TESTNET NODE, SHOW THE DGB TOR MENU
    elif [ "$show_dgb_tor_menu" = "yes" ] && [ "$DGB_NETWORK_FINAL" = "TESTNET" ] && [ "$SETUP_DUAL_NODE" = "NO" ]; then

        opt1a="1 TOR"
        opt1b=" Run DigiByte Testnet Node over Tor. (Recommended)"

        opt2a="2 CLEARNET"
        opt2b=" Run DigiByte Testnet over clearnet."

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Tor Selection" --title "DigiByte Tor Selection" --no-label "Cancel" --radiolist "\nPlease choose whether to run your DigiByte TESTNET Node over Tor.\n\nRunning a DigiByte node over Tor hides your IP address, enhancing privacy and security by making it harder for others to trace your blockchain activity. In contrast, running a node over clearnet uses the regular internet, exposing your IP address and location, but generally offers faster connectivity.\n\nFor the Digibyte network, having more Tor nodes increases the overall privacy and security of the network, making it more resilient against surveillance and attacks.\n\nLearn more about Tor: https://www.torproject.org/\n\n" 22 75 2 \
        "${opt1a}"  "${opt1b}" $DGB_TOR_TESTNET_TOR_FLAG \
        "${opt2a}"  "${opt2b}" $DGB_TOR_TESTNET_CLEARNET_FLAG 3>&2 2>&1 1>&3) || \
        { printf "%b %bCancel was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; FORCE_DISPLAY_TOR_MENU=false; menu_existing_install; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Enable Tor for DigiByte Testnet
            ${opt1a})
                printf "%b You chose to switch DigiByte Testnet to run over Tor.\\n" "${INFO}"
                DGB_TOR_TESTNET="ON"  
                if [ "$DGB_MAINNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_MAINNET="ON"
                else
                    DGB_TOR_MAINNET="OFF"
                fi
                if [ "$DGB_TOR_TESTNET_TOR_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi  
                ;;
            # Disable Tor for DigiByte Testnet
            ${opt2a})
                printf "%b You chose to switch DigiByte Testnet to run over clearnet.\\n" "${INFO}"
                DGB_TOR_TESTNET="OFF"  
                if [ "$DGB_MAINNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_MAINNET="ON"
                else
                    DGB_TOR_MAINNET="OFF"
                fi
                if [ "$DGB_TOR_TESTNET_CLEARNET_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi 
                ;;
        esac
        printf "\\n"

    # FOR AN EXISTING INSTALL, MAINNET NODE, SHOW THE DGB TOR MENU
    elif [ "$show_dgb_tor_menu" = "yes" ] && [ "$DGB_NETWORK_FINAL" = "MAINNET" ] && [ "$SETUP_DUAL_NODE" = "NO" ]; then

        opt1a="1 TOR"
        opt1b=" Run DigiByte Mainnet Node over Tor. (Recommended)"

        opt2a="2 CLEARNET"
        opt2b=" Run DigiByte Mainnet over clearnet."

        # Display the information to the user
        UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Tor Selection" --title "DigiByte Tor Selection" --no-label "Cancel" --radiolist "\nPlease choose whether to run your DigiByte MAINNET Node over Tor.\n\nRunning a DigiByte node over Tor hides your IP address, enhancing privacy and security by making it harder for others to trace your blockchain activity. In contrast, running a node over clearnet uses the regular internet, exposing your IP address and location, but generally offers faster connectivity.\n\nFor the Digibyte network, having more Tor nodes increases the overall privacy and security of the network, making it more resilient against surveillance and attacks.\n\nLearn more about Tor: https://www.torproject.org/\n\n" 22 75 2 \
        "${opt1a}"  "${opt1b}" $DGB_TOR_MAINNET_TOR_FLAG \
        "${opt2a}"  "${opt2b}" $DGB_TOR_MAINNET_CLEARNET_FLAG 3>&2 2>&1 1>&3) || \
        { printf "%b %bCancel was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; FORCE_DISPLAY_TOR_MENU=false; menu_existing_install; }

        # Set the variable based on if the user chooses
        case ${UpdateCmd} in
            # Enable Tor for DigiByte Mainnet
            ${opt1a})
                printf "%b You chose to switch DigiByte Mainnet to run over Tor.\\n" "${INFO}"
                DGB_TOR_MAINNET="ON"  
                if [ "$DGB_TESTNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_TESTNET="ON"
                else
                    DGB_TOR_TESTNET="OFF"
                fi
                if [ "$DGB_TOR_MAINNET_TOR_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi  
                ;;
            # Disable Tor for DigiByte Mainnet
            ${opt2a})
                printf "%b You chose to switch DigiByte Mainnet to run over clearnet.\\n" "${INFO}"
                DGB_TOR_MAINNET="OFF"  
                if [ "$DGB_TESTNET_USING_TOR" = "YES" ];then 
                    DGB_TOR_TESTNET="ON"
                else
                    DGB_TOR_TESTNET="OFF"
                fi
                if [ "$DGB_TOR_MAINNET_CLEARNET_FLAG" = "ON" ];then 
                    FORCE_DISPLAY_TOR_MENU=false
                    menu_existing_install
                fi 
                ;;
        esac
        printf "\\n"

    elif [ "$show_dgb_tor_menu" = "no" ] && [ "$show_ipfs_tor_menu" = "no" ]; then

        if [ "$DGB_MAINNET_USING_TOR" = "YES" ];then 
            DGB_TOR_MAINNET="ON"
        else
            DGB_TOR_MAINNET="OFF"
        fi
        if [ "$DGB_TESTNET_USING_TOR" = "YES" ];then 
            DGB_TOR_TESTNET="ON"
        else
            DGB_TOR_TESTNET="OFF"
        fi

        IPFS_ENABLE_TOR="SKIP"

    fi

else

    # If we are running unattended, and the script wants to prompt the user with the Tor menu, then get the values from diginode.settings

    # Configure Tor service
    enable_tor_service

    # Display Tor section break
    if [ "$show_dgb_tor_menu" = "yes" ] || [ "$show_ipfs_tor_menu" = "yes" ]; then

            printf " =============== Unattended Mode: Configuring Tor ======================\\n\\n"
            # ==============================================================================

    fi

    if [ "$show_dgb_tor_menu" = "yes" ]; then

        if [ "$UI_DGB_MAINNET_ENABLE_TOR" = "YES" ]; then

            printf "%b Unattended Mode: Tor will be ENABLED for DigiByte Core Mainnet\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_MAINNET_ENABLE_TOR value in diginode.settings)\\n" "${INDENT}"
            DGB_TOR_MAINNET="ON"

        elif [ "$UI_DGB_MAINNET_ENABLE_TOR" = "NO" ]; then

            printf "%b Unattended Mode: Tor will be DISABLED for DigiByte Core Mainnet\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_MAINNET_ENABLE_TOR value in diginode.settings)\\n" "${INDENT}"
            DGB_TOR_MAINNET="OFF"

        else

            printf "%b Unattended Mode: Skipping setting up Tor for DigiByte Core Mainnet. It is already configured.\\n" "${INFO}"
            if [ "$DGB_MAINNET_USING_TOR" = "YES" ];then 
                DGB_TOR_MAINNET="ON"
            else
                DGB_TOR_MAINNET="OFF"
            fi

        fi

        if [ "$UI_DGB_TESTNET_ENABLE_TOR" = "YES" ]; then

            printf "%b Unattended Mode: Tor will be ENABLED for DigiByte Core Testnet\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_TESTNET_ENABLE_TOR value in diginode.settings)\\n" "${INDENT}"
            DGB_TOR_TESTNET="ON"

        elif [ "$UI_DGB_TESTNET_ENABLE_TOR" = "NO" ]; then

            printf "%b Unattended Mode: Tor will be DISABLED for DigiByte Core Testnet\\n" "${INFO}"
            printf "%b                  (Set from UI_DGB_TESTNET_ENABLE_TOR value in diginode.settings)\\n" "${INDENT}"
            DGB_TOR_TESTNET="OFF"

        else

            printf "%b Unattended Mode: Skipping setting up Tor for DigiByte Core Testnet. It is already configured.\\n" "${INFO}"
            if [ "$DGB_TESTNET_USING_TOR" = "YES" ];then 
                DGB_TOR_TESTNET="ON"
            else
                DGB_TOR_TESTNET="OFF"
            fi

        fi

    fi

    if [ "$show_ipfs_tor_menu" = "yes" ]; then

        if [ "$UI_IPFS_ENABLE_TOR" = "YES" ]; then

            printf "%b Unattended Mode: Tor will be ENABLED for IPFS" "${INFO}"
            printf "%b                  (Set from UI_IPFS_ENABLE_TOR value in diginode.settings)\\n" "${INDENT}"
            IPFS_ENABLE_TOR="YES"

        elif [ "$UI_IPFS_ENABLE_TOR" = "NO" ]; then

            printf "%b Unattended Mode: Tor will be DISABLED for IPFS" "${INFO}"
            printf "%b                  (Set from UI_IPFS_ENABLE_TOR value in diginode.settings)\\n" "${INDENT}"

            IPFS_ENABLE_TOR="NO"

        else

            printf "%b Unattended Mode: Skipping setting up Tor for IPFS. It is already configured.\\n" "${INFO}"
            IPFS_ENABLE_TOR="SKIP"

        fi
    fi

    # Insert blank row if anything was displayed above
    if [ "$show_dgb_tor_menu" = "yes" ] || [ "$show_ipfs_tor_menu" = "yes" ]; then  
        printf "\\n"
    fi


fi

}




# This functions looks up the current network chain being used for DigiByte Core - mainnet, testnet or regtest
# If DigiByte Core is not available it gets the value from digibyte.conf

query_digibyte_chain() {
    DGB_NETWORK_CHAIN=""
    local dgb_network_chain_query
    dgb_network_chain_query=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockchaininfo 2>/dev/null | grep -m1 chain | cut -d '"' -f4)
    if [ "$dgb_network_chain_query" != "" ]; then
        DGB_NETWORK_CHAIN=$dgb_network_chain_query
    fi

    if [ "$DGB_NETWORK_CHAIN" = "test" ]; then 
        DGB_NETWORK_CURRENT="TESTNET"
        DGB_NETWORK_CURRENT_LIVE="YES"
    elif [ "$DGB_NETWORK_CHAIN" = "main" ]; then 
        DGB_NETWORK_CURRENT="MAINNET"
        DGB_NETWORK_CURRENT_LIVE="YES"
    elif [ "$DGB_NETWORK_CHAIN" = "regtest" ]; then 
        DGB_NETWORK_CURRENT="REGTEST"
        DGB_NETWORK_CURRENT_LIVE="YES"
    elif [ "$DGB_NETWORK_CHAIN" = "signet" ]; then 
        DGB_NETWORK_CURRENT="SIGNET"
        DGB_NETWORK_CURRENT_LIVE="YES"
    else
        # If there is no response from digibyte-cli, check digibyte.conf
        if [ -f "$DGB_CONF_FILE" ]; then

                # Get network chain status from digibyte.conf
                if grep -q "^regtest=1" $DGB_CONF_FILE || grep -q "^chain=regtest" $DGB_CONF_FILE; then
                    DGB_NETWORK_CURRENT="REGTEST"
                    DGB_NETWORK_CURRENT_LIVE="NO"
                    DGB_NETWORK_CHAIN="regtest"
                elif grep -q "^signet=1" $DGB_CONF_FILE || grep -q "^chain=signet" $DGB_CONF_FILE; then
                    DGB_NETWORK_CURRENT="SIGNET"
                    DGB_NETWORK_CURRENT_LIVE="NO"
                    DGB_NETWORK_CHAIN="signet"
                elif grep -q "^testnet=1" $DGB_CONF_FILE || grep -q "^chain=test" $DGB_CONF_FILE; then
                    DGB_NETWORK_CURRENT="TESTNET"
                    DGB_NETWORK_CURRENT_LIVE="NO"
                    DGB_NETWORK_CHAIN="test"
                elif grep -q "^chain=main" $DGB_CONF_FILE; then
                    DGB_NETWORK_CURRENT="MAINNET"
                    DGB_NETWORK_CURRENT_LIVE="NO"
                    DGB_NETWORK_CHAIN="main"
                else
                    DGB_NETWORK_CURRENT="MAINNET"
                    DGB_NETWORK_CURRENT_LIVE="NO"
                    DGB_NETWORK_CHAIN="main"
                fi
        fi
    fi
}

# Query DigiByte Core to find out if it is running on Tor
# If DigiByte Core is not running, lookup the Tor status from digibyte.conf

query_digibyte_tor() {

    # Check if tor is running, and if either DigiByte node is running on it
    systemctl is-active --quiet tor && TOR_STATUS="running" || TOR_STATUS="not_running"

    # Check if primary DigiByte Node has an onion address (i.e. it is running on Tor)
    DGB_TOR_QUERY=$(sudo -u $USER_ACCOUNT $DGB_CLI getnetworkinfo 2>/dev/null | jq -r 'if any(.localaddresses[]; .address | endswith(".onion")) then "YES" else "NO" end')
    if [ "$DGB_TOR_QUERY" != "" ]; then
        DGB_USING_TOR=$DGB_TOR_QUERY
        DGB_USING_TOR_LIVE="YES" # We have a live value direct from digibyte-cli
    fi

    # If we failed to get a result from digibyte-cli for primary node, check digibyte.conf instead
    if  [ "$DGB_TOR_QUERY" = "" ] || [ "$DGB_TOR_QUERY" = "null" ]; then

        # Make sure we have already scraped digibyte.conf
        if [ "$DIGIBYTE_CONFIG_GLOBAL" = "" ]; then
            scrape_digibyte_conf
        fi

        # Make sure we have already checked which network chain we are using - mainnet, testnet or regtest
        if [ "$DGB_NETWORK_CURRENT" = "" ]; then
            query_digibyte_chain
        fi

        # If we are running mainnet, get current Tor ports from [main] section of digibyte.conf, to check if Tor is enabled
        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
            DGB_TOR_MAIN_PROXY=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^proxy=127.0.0.1:9050)
            DGB_TOR_MAIN_TORCONTROL=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^torcontrol=127.0.0.1:9151)
            DGB_TOR_MAIN_BIND=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^bind=127.0.0.1=onion)
            if [ "$DGB_TOR_MAIN_PROXY" = "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_MAIN_TORCONTROL" = "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_MAIN_BIND" = "bind=127.0.0.1=onion" ]; then
                DGB_USING_TOR="YES"
            else
                DGB_USING_TOR="NO"
            fi
            DGB_USING_TOR_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        fi

        # If we are running testnet, get current Tor ports from [test] section of digibyte.conf, to check if Tor is enabled
        if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
            DGB_TOR_TEST_PROXY=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^proxy=127.0.0.1:9050)
            DGB_TOR_TEST_TORCONTROL=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^torcontrol=127.0.0.1:9151)
            DGB_TOR_TEST_BIND=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^bind=127.0.0.1=onion)
            if [ "$DGB_TOR_TEST_PROXY" = "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_TEST_TORCONTROL" = "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_TEST_BIND" = "bind=127.0.0.1=onion" ]; then
                DGB_USING_TOR="YES"
            else
                DGB_USING_TOR="NO"
            fi
            DGB_USING_TOR_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        fi

        # If we are running regtest, get current Tor ports from [regtest] section of digibyte.conf, to check if Tor is enabled
        if [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
            DGB_TOR_REGTEST_PROXY=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^proxy=127.0.0.1:9050)
            DGB_TOR_REGTEST_TORCONTROL=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^torcontrol=127.0.0.1:9151)
            DGB_TOR_REGTEST_BIND=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^bind=127.0.0.1=onion)
            if [ "$DGB_TOR_REGTEST_PROXY" = "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_REGTEST_TORCONTROL" = "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_REGTEST_BIND" = "bind=127.0.0.1=onion" ]; then
                DGB_USING_TOR="YES"
            else
                DGB_USING_TOR="NO"
            fi
            DGB_USING_TOR_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        fi

        # If we are running signet, get current Tor ports from [signet] section of digibyte.conf, to check if Tor is enabled
        if [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
            DGB_TOR_SIGNET_PROXY=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^proxy=127.0.0.1:9050)
            DGB_TOR_SIGNET_TORCONTROL=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^torcontrol=127.0.0.1:9151)
            DGB_TOR_SIGNET_BIND=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^bind=127.0.0.1=onion)
            if [ "$DGB_TOR_SIGNET_PROXY" = "proxy=127.0.0.1:9050" ] && [ "$DGB_TOR_SIGNET_TORCONTROL" = "torcontrol=127.0.0.1:9151" ] && [ "$DGB_TOR_SIGNET_BIND" = "bind=127.0.0.1=onion" ]; then
                DGB_USING_TOR="YES"
            else
                DGB_USING_TOR="NO"
            fi
            DGB_USING_TOR_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        fi
    fi

    # If we are running a Dual Node, or setting one up, we also need to check if Tor is enabled for the secondary testnet node
    if [ "$SETUP_DUAL_NODE" = "YES" ] || [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Check if secondary DigiByte Node has an onion address (i.e. it is running on Tor)
        DGB2_TOR_QUERY=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet getnetworkinfo 2>/dev/null | jq -r 'if any(.localaddresses[]; .address | endswith(".onion")) then "YES" else "NO" end')
        if [ "$DGB2_TOR_QUERY" != "" ]; then
            DGB2_USING_TOR=$DGB2_TOR_QUERY
            DGB2_USING_TOR_LIVE="YES" # We have a live value direct from digibyte-cli
        fi

        # If we failed to get a result from digibyte-cli for secondary node, check digibyte.conf instead
        if  [ "$DGB2_TOR_QUERY" = "" ] || [ "$DGB2_TOR_QUERY" = "null" ]; then

            # Make sure we have already scraped digibyte.conf
            if [ "$DIGIBYTE_CONFIG_GLOBAL" = "" ]; then
                scrape_digibyte_conf
            fi

            # Make sure we have already checked which network chain we are using - mainnet, testnet or regtest
            if [ "$DGB_NETWORK_CURRENT" = "" ]; then
                query_digibyte_chain
            fi

            # If we are running testnet, get current Tor ports from [test] section of digibyte.conf, to check if Tor is enabled
            DGB2_TOR_TEST_PROXY=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^proxy=127.0.0.1:9050)
            DGB2_TOR_TEST_TORCONTROL=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^torcontrol=127.0.0.1:9151)
            DGB2_TOR_TEST_BIND=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^bind=127.0.0.1=onion)
            if [ "$DGB2_TOR_TEST_PROXY" = "proxy=127.0.0.1:9050" ] && [ "$DGB2_TOR_TEST_TORCONTROL" = "torcontrol=127.0.0.1:9151" ] && [ "$DGB2_TOR_TEST_BIND" = "bind=127.0.0.1=onion" ]; then
                DGB2_USING_TOR="YES"
            else
                DGB2_USING_TOR="NO"
            fi
            DGB2_USING_TOR_LIVE="NO" # Not a live value as retrieved from digibyte.conf

        fi

    fi

}

# Query DigiByte Core for the current listening port
# If DigiByte Core is not available it gets the value from digibyte.conf

query_digibyte_port() {

    # Get primary DigiByte Node listening port
    DGB_LISTEN_PORT_QUERY=$(sudo -u $USER_ACCOUNT $DGB_CLI getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)
    if [ "$DGB_LISTEN_PORT_QUERY" != "" ]; then
        DGB_LISTEN_PORT=$DGB_LISTEN_PORT_QUERY
        DGB_LISTEN_PORT_LIVE="YES" # We have a live value direct from digibyte-cli
    fi

    # If we failed to get a result from digibyte-cli for primary node, check digibyte.conf instead
    if  [ "$DGB_LISTEN_PORT_QUERY" = "" ] || [ "$DGB_LISTEN_PORT_QUERY" = "null" ]; then

        # Make sure we have already scraped digibyte.conf
        if [ "$DIGIBYTE_CONFIG_GLOBAL" = "" ]; then
            scrape_digibyte_conf
        fi

        # Make sure we have already checked which network chain we are using - mainnet, testnet or regtest
        if [ "$DGB_NETWORK_CURRENT" = "" ]; then
            query_digibyte_chain
        fi

        DGB_LISTEN_PORT_GLOBAL=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^port= | cut -d'=' -f 2)

        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_LISTEN_PORT_GLOBAL" = "" ]; then
            DGB_LISTEN_PORT="12024"
            DGB_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_LISTEN_PORT_GLOBAL" = "" ]; then
            DGB_LISTEN_PORT="12026"
            DGB_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ] && [ "$DGB_LISTEN_PORT_GLOBAL" = "" ]; then
            DGB_LISTEN_PORT="18444"
            DGB_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ] && [ "$DGB_LISTEN_PORT_GLOBAL" = "" ]; then
            DGB_LISTEN_PORT="38443"
            DGB_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        else
            DGB_LISTEN_PORT="$DGB_LISTEN_PORT_GLOBAL"   
            DGB_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
        fi

        # If we are running mainnet, get current listening port from [main] section of digibyte.conf, if available
        if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
            DGB_LISTEN_PORT_MAIN=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^port= | cut -d'=' -f 2)
            if [ "$DGB_LISTEN_PORT_MAIN" != "" ]; then
                DGB_LISTEN_PORT="$DGB_LISTEN_PORT_MAIN"
            fi
        fi

        # If we are running testnet, get current listening port from [test] section of digibyte.conf, if available
        if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
            DGB_LISTEN_PORT_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^port= | cut -d'=' -f 2)
            if [ "$DGB_LISTEN_PORT_TEST" != "" ]; then
                DGB_LISTEN_PORT="$DGB_LISTEN_PORT_TEST"
            fi
        fi

        # If we are running regtest, get current listening port from [regtest] section of digibyte.conf, if available
        if [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
            DGB_LISTEN_PORT_REGTEST=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^port= | cut -d'=' -f 2)
            if [ "$DGB_LISTEN_PORT_REGTEST" != "" ]; then
                DGB_LISTEN_PORT="$DGB_LISTEN_PORT_REGTEST"
            fi
        fi

        # If we are running signet, get current listening port from [signet] section of digibyte.conf, if available
        if [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
            DGB_LISTEN_PORT_SIGNET=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^port= | cut -d'=' -f 2)
            if [ "$DGB_LISTEN_PORT_SIGNET" != "" ]; then
                DGB_LISTEN_PORT="$DGB_LISTEN_PORT_SIGNET"
            fi
        fi

    fi

    # If we are running a Dual Node, or setting one up, we also need to get the current testnet listening port
    if [ "$SETUP_DUAL_NODE" = "YES" ] || [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Get secondary DigiByte Node listening port
        DGB2_LISTEN_PORT_QUERY=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)
        if [ "$DGB2_LISTEN_PORT_QUERY" != "" ]; then
            DGB2_LISTEN_PORT=$DGB2_LISTEN_PORT_QUERY
            DGB2_LISTEN_PORT_LIVE="YES" # We have a live value direct from digibyte-cli
        fi

        # If we failed to get a result from digibyte-cli for the secondary node, check digibyte.conf instead
        if  [ "$DGB2_LISTEN_PORT_QUERY" = "" ] || [ "$DGB2_LISTEN_PORT_QUERY" = "null" ]; then

            # Make sure we have already scraped digibyte.conf
            if [ "$DIGIBYTE_CONFIG_GLOBAL" = "" ]; then
                scrape_digibyte_conf
            fi

            # Make sure we have already checked which network chain we are using - mainnet, testnet or regtest
            if [ "$DGB_NETWORK_CURRENT" = "" ]; then
                query_digibyte_chain
            fi

            DGB_LISTEN_PORT_GLOBAL=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^port= | cut -d'=' -f 2)

            if [ "$DGB_LISTEN_PORT_GLOBAL" = "" ]; then
                DGB2_LISTEN_PORT="12026"
                DGB2_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
            else
                DGB2_LISTEN_PORT="$DGB_LISTEN_PORT_GLOBAL"   
                DGB2_LISTEN_PORT_LIVE="NO" # Not a live value as retrieved from digibyte.conf
            fi

            # Get current listening port from [test] section of digibyte.conf, if available
            DGB2_LISTEN_PORT_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^port= | cut -d'=' -f 2)
            if [ "$DGB2_LISTEN_PORT_TEST" != "" ]; then
                DGB2_LISTEN_PORT="$DGB2_LISTEN_PORT_TEST"
            fi

        fi

    fi

}


# Get the maxconnections value from digibyte.conf

query_digibyte_maxconnections() {

if [ -f "$DGB_CONF_FILE" ]; then

    # Make sure we have already scraped digibyte.conf
    if [ "$DIGIBYTE_CONFIG_GLOBAL" = "" ]; then
        scrape_digibyte_conf
    fi

    # Make sure we have already checked which network chain we are using - mainnet, testnet or regtest
    if [ "$DGB_NETWORK_CURRENT" = "" ]; then
        query_digibyte_chain
    fi

    # Look maxconnections from the global section of digibyte.conf and set default of 125 if not found
    DGB_MAXCONNECTIONS_GLOBAL=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^maxconnections= | cut -d'=' -f 2)
    if [ "$DGB_MAXCONNECTIONS_GLOBAL" = "" ]; then
        DGB_MAXCONNECTIONS="125" # use default value
    else
        DGB_MAXCONNECTIONS="$DGB_MAXCONNECTIONS_GLOBAL"   
    fi

    # If we are running mainnet, get maxconnections value from [main] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
        DGB_MAXCONNECTIONS_MAIN=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^maxconnections= | cut -d'=' -f 2)
        if [ "$DGB_MAXCONNECTIONS_MAIN" != "" ]; then
            DGB_MAXCONNECTIONS="$DGB_MAXCONNECTIONS_MAIN"
        fi
    fi

    # If we are running testnet, get maxconnections value from [test] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
        DGB_MAXCONNECTIONS_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^maxconnections= | cut -d'=' -f 2)
        if [ "$DGB_MAXCONNECTIONS_TEST" != "" ]; then
            DGB_MAXCONNECTIONS="$DGB_MAXCONNECTIONS_TEST"
        fi
    fi

    # If we are running regtest, get maxconnections value from [regtest] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
        DGB_MAXCONNECTIONS_REGTEST=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^maxconnections= | cut -d'=' -f 2)
        if [ "$DGB_MAXCONNECTIONS_REGTEST" != "" ]; then
            DGB_MAXCONNECTIONS="$DGB_MAXCONNECTIONS_REGTEST"
        fi
    fi

    # If we are running signet, get maxconnections value from [signet] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
        DGB_MAXCONNECTIONS_SIGNET=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^maxconnections= | cut -d'=' -f 2)
        if [ "$DGB_MAXCONNECTIONS_SIGNET" != "" ]; then
            DGB_MAXCONNECTIONS="$DGB_MAXCONNECTIONS_SIGNET"
        fi
    fi

    # If we are running a Dual Node, or setting one up, we also need to get the current testnet maxconnections
    if [ "$SETUP_DUAL_NODE" = "YES" ] || [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Look maxconnections from the global section of digibyte.conf and set default of 125 if not found
        DGB2_MAXCONNECTIONS_GLOBAL=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^maxconnections= | cut -d'=' -f 2)
        if [ "$DGB2_MAXCONNECTIONS_GLOBAL" = "" ]; then
            DGB2_MAXCONNECTIONS="125" # use default value
        else
            DGB2_MAXCONNECTIONS="$DGB2_MAXCONNECTIONS_GLOBAL"   
        fi

        # Look up maxconnections from the [test] section of digibyte.conf, if available
        DGB2_MAXCONNECTIONS_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^maxconnections= | cut -d'=' -f 2)
        if [ "$DGB2_MAXCONNECTIONS_TEST" != "" ]; then
            DGB2_MAXCONNECTIONS="$DGB2_MAXCONNECTIONS_TEST"
        fi

    fi

fi

}

# Get the rpc credentials - rpcuser, rpcuser and rpcpassword - from digibyte.conf

query_digibyte_rpc() {

if [ -f "$DGB_CONF_FILE" ]; then

    # Make sure we have already scraped digibyte.conf
    if [ "$DIGIBYTE_CONFIG_GLOBAL" = "" ]; then
        scrape_digibyte_conf
    fi

    # Make sure we have already checked which network chain we are using - mainnet, testnet or regtest
    if [ "$DGB_NETWORK_CURRENT" = "" ]; then
        query_digibyte_chain
    fi

    # Look up rpcuser from the global section of digibyte.conf
    RPC_USER=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^rpcuser= | cut -d'=' -f 2)

    # Look up rpcpassword from the global section of digibyte.conf
    RPC_PASSWORD=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^rpcpassword= | cut -d'=' -f 2)

    # Look up rpcport from the global section of digibyte.conf
    RPC_PORT=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^rpcport= | cut -d'=' -f 2)

    # Look up rpcbind from the global section of digibyte.conf
    RPC_BIND=$(echo "$DIGIBYTE_CONFIG_GLOBAL" | grep ^rpcbind= | cut -d'=' -f 2)


    # If we are running MAINNET, get rpc credentials from [main] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
        # Look up rpcuser from the [main] section of digibyte.conf
        RPC_USER_MAIN=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^rpcuser= | cut -d'=' -f 2)
        if [ "$RPC_USER_MAIN" != "" ]; then
            RPC_USER="$RPC_USER_MAIN"
        fi
        # Look up rpcpassword from the [main] section of digibyte.conf
        RPC_PASSWORD_MAIN=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^rpcpassword= | cut -d'=' -f 2)
        if [ "$RPC_PASSWORD_MAIN" != "" ]; then
            RPC_PASSWORD="$RPC_PASSWORD_MAIN"
        fi
        # Look up rpcport from the [main] section of digibyte.conf
        RPC_PORT_MAIN=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^rpcport= | cut -d'=' -f 2)
        if [ "$RPC_PORT_MAIN" != "" ]; then
            RPC_PORT="$RPC_PORT_MAIN"
        else
            # If mainnet rpcport was not set anywhere else, then set the mainnet default
            if [ "$RPC_PORT" = "" ]; then 
                RPC_PORT="14022"
            fi
        fi
        # Look up rpcbind from the [main] section of digibyte.conf
        RPC_BIND_MAIN=$(echo "$DIGIBYTE_CONFIG_MAIN" | grep ^rpcbind= | cut -d'=' -f 2)
        if [ "$RPC_BIND_MAIN" != "" ]; then
            RPC_BIND="$RPC_BIND_MAIN"
        fi
    fi

    # If we are running TESTNET, get rpc credentials from [test] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
        # Look up rpcuser from the [test] section of digibyte.conf
        RPC_USER_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^rpcuser= | cut -d'=' -f 2)
        if [ "$RPC_USER_TEST" != "" ]; then
            RPC_USER="$RPC_USER_TEST"
        fi
        # Look up rpcpassword from the [test] section of digibyte.conf
        RPC_PASSWORD_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^rpcpassword= | cut -d'=' -f 2)
        if [ "$RPC_PASSWORD_TEST" != "" ]; then
            RPC_PASSWORD="$RPC_PASSWORD_TEST"
        fi
        # Look up rpcport from the [test] section of digibyte.conf
        RPC_PORT_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^rpcport= | cut -d'=' -f 2)
        if [ "$RPC_PORT_TEST" != "" ]; then
            RPC_PORT="$RPC_PORT_TEST"
        else
            # If testnet rpcport was not set anywhere else, then set the testnet default
            if [ "$RPC_PORT" = "" ]; then 
                RPC_PORT="14023"
            else # If it was already set in the global section, but not in the testnet section, then remove it as it won't work
                RPC_PORT=""
            fi
        fi
        # Look up rpcbind from the [test] section of digibyte.conf
        RPC_BIND_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^rpcbind= | cut -d'=' -f 2)
        if [ "$RPC_BIND_TEST" != "" ]; then
            RPC_BIND="$RPC_BIND_TEST"
        else
            # If testnet rpcbind was set globally, but it is not set in the testset section, then report an error (DigiByte won't run without this being set)
            if [ "$RPC_BIND" != "" ]; then 
                RPC_BIND="error"
            fi
        fi
    fi

    # If we are running REGTEST, get rpc credentials from [regtest] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
        # Look up rpcuser from the [regtest] section of digibyte.conf
        RPC_USER_REGTEST=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^rpcuser= | cut -d'=' -f 2)
        if [ "$RPC_USER_REGTEST" != "" ]; then
            RPC_USER="$RPC_USER_REGTEST"
        fi
        # Look up rpcpassword from the [regtest] section of digibyte.conf
        RPC_PASSWORD_REGTEST=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^rpcpassword= | cut -d'=' -f 2)
        if [ "$RPC_PASSWORD_REGTEST" != "" ]; then
            RPC_PASSWORD="$RPC_PASSWORD_REGTEST"
        fi
        # Look up rpcport from the [regtest] section of digibyte.conf
        RPC_PORT_REGTEST=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^rpcport= | cut -d'=' -f 2)
        if [ "$RPC_PORT_REGTEST" != "" ]; then
            RPC_PORT="$RPC_PORT_REGTEST"
        else
            # If regtest rpcport was not set anywhere else, then set the regtest default
            if [ "$RPC_PORT" = "" ]; then 
                RPC_PORT="18443"
            else # If it was already set in the global section, but not in the [regtest] section, then remove it as it won't work
                RPC_PORT=""
            fi
        fi
        # Look up rpcbind from the [regtest] section of digibyte.conf
        RPC_BIND_REGTEST=$(echo "$DIGIBYTE_CONFIG_REGTEST" | grep ^rpcbind= | cut -d'=' -f 2)
        if [ "$RPC_BIND_REGTEST" != "" ]; then
            RPC_BIND="$RPC_BIND_REGTEST"
        else
            # If regtest rpcbind was set globally, but it is not in the [regtest] section, then report an error (DigiByte won't run without this being set)
            if [ "$RPC_BIND" != "" ]; then 
                RPC_BIND="error"
            fi
        fi
    fi

    # If we are running SIGNET, get rpc credentials from [signet] section of digibyte.conf, if available
    if [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
        # Look up rpcuser from the [signet] section of digibyte.conf
        RPC_USER_SIGNET=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^rpcuser= | cut -d'=' -f 2)
        if [ "$RPC_USER_SIGNET" != "" ]; then
            RPC_USER="$RPC_USER_SIGNET"
        fi
        # Look up rpcpassword from the [signet] section of digibyte.conf
        RPC_PASSWORD_SIGNET=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^rpcpassword= | cut -d'=' -f 2)
        if [ "$RPC_PASSWORD_SIGNET" != "" ]; then
            RPC_PASSWORD="$RPC_PASSWORD_SIGNET"
        fi
        # Look up rpcport from the [signet] section of digibyte.conf
        RPC_PORT_SIGNET=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^rpcport= | cut -d'=' -f 2)
        if [ "$RPC_PORT_SIGNET" != "" ]; then
            RPC_PORT="$RPC_PORT_SIGNET"
        else
            # If signet rpcport was not set anywhere else, then set the signet default
            if [ "$RPC_PORT" = "" ]; then 
                RPC_PORT="19443"
            else # If it was already set in the global section, but not in the [signet] section, then remove it as it won't work
                RPC_PORT=""
            fi
        fi
        # Look up rpcbind from the [signet] section of digibyte.conf
        RPC_BIND_SIGNET=$(echo "$DIGIBYTE_CONFIG_SIGNET" | grep ^rpcbind= | cut -d'=' -f 2)
        if [ "$RPC_BIND_SIGNET" != "" ]; then
            RPC_BIND="$RPC_BIND_SIGNET"
        else
            # If signet rpcbind was set globally, but it is not set in the [signet] section, then report an error (DigiByte won't run without this being set)
            if [ "$RPC_BIND" != "" ]; then 
                RPC_BIND="error"
            fi
        fi
    fi

    # If we are running a Dual Node, or setting one up, we also need to get the current testnet RPC port
    if [ "$SETUP_DUAL_NODE" = "YES" ] || [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Look up rpcport from the [test] section of digibyte.conf
        RPC2_PORT_TEST=$(echo "$DIGIBYTE_CONFIG_TEST" | grep ^rpcport= | cut -d'=' -f 2)
        if [ "$RPC2_PORT_TEST" != "" ]; then
            RPC2_PORT="$RPC2_PORT_TEST"
        else
            # If testnet rpcport was not set anywhere else, then set the testnet default
            if [ "$RPC2_PORT" = "" ]; then 
                RPC2_PORT="14023"
            else # If it was already set in the global section, but not in the testnet section, then remove it as it won't work
                RPC2_PORT=""
            fi
        fi

    fi

fi

}


# -----------------------------------------------------------------------------
# is_dgb_newer_version: Compares two version strings to determine if the remote 
# version is newer than the local version of DigiByte Core.
#
# The function can handle standard versions as well as pre-release versions.
# Standard versions are of the format: major.minor.patch (e.g., 7.17.2).
# Pre-release versions can be of two formats: 
# 1. major.minor.patch-rc# (e.g., 8.22.0-rc1)
# 2. major.minor.patch-rc#-suffix (e.g., 8.22.0-rc3-fastcode), where the suffix 
#    denotes a specialized or test variant of that release candidate.
# 
# The ordering logic is:
# 1. major.minor.patch versions are ordered numerically.
# 2. For the same major.minor.patch, a version with -rc#-suffix is considered 
#    newer than one with a lower rc number but older than the same rc number 
#    without the suffix.
#
# The function is also case-insensitive to variations like "RC" and "rc".
#
# Usage:
#     result=$(is_newer_version <local_version> <remote_version>)
# 
# Parameters:
#     local_version: The current version string.
#     remote_version: The version string to compare against.
#
# Returns:
#     "update_available" if the remote version is newer than the local version.
#     "update_not_available" otherwise.
# 
# Example:
#     local_v="8.22.0-rc2"
#     remote_v="8.22.0-rc3-fastcode"
#     result=$(is_newer_version "$local_v" "$remote_v")
#     echo "$result"  # Outputs: "update_available"
# -----------------------------------------------------------------------------

is_dgb_newer_version() {
    local local_version="$1"
    local remote_version="$2"

    # Extract major, minor, patch, rc, and suffix
    local regex="([0-9]+)\.([0-9]+)\.([0-9]+)(-rc([0-9]+))?(-([a-zA-Z0-9]+))?"
    if [[ $local_version =~ $regex ]]; then
        local_major=${BASH_REMATCH[1]}
        local_minor=${BASH_REMATCH[2]}
        local_patch=${BASH_REMATCH[3]}
        local_rc=${BASH_REMATCH[5]:-0}  # Default to 0 if no -rc part
        local_suffix=${BASH_REMATCH[7]}
    fi

    if [[ $remote_version =~ $regex ]]; then
        remote_major=${BASH_REMATCH[1]}
        remote_minor=${BASH_REMATCH[2]}
        remote_patch=${BASH_REMATCH[3]}
        remote_rc=${BASH_REMATCH[5]:-0}  # Default to 0 if no -rc part
        remote_suffix=${BASH_REMATCH[7]}
    fi

    # Compare versions
    if (( remote_major > local_major )); then
        echo "update_available"
        return
    elif (( remote_major == local_major && remote_minor > local_minor )); then
        echo "update_available"
        return
    elif (( remote_major == local_major && remote_minor == local_minor && remote_patch > local_patch )); then
        echo "update_available"
        return
    fi

    # If remote is a stable release and local is an RC of that release
    if (( remote_major == local_major && remote_minor == local_minor && remote_patch == local_patch && remote_rc == 0 && local_rc > 0 )); then
        echo "update_available"
        return
    fi

    # Handle the case where RC versions are involved
    if (( remote_major == local_major && remote_minor == local_minor && remote_patch == local_patch && remote_rc > local_rc )); then
        echo "update_available"
        return
    fi

    # Handle the case where RC versions and suffixes are involved
    if (( remote_major == local_major && remote_minor == local_minor && remote_patch == local_patch && remote_rc == local_rc )); then
        if [[ -z "$remote_suffix" && -n "$local_suffix" ]]; then
            echo "update_available"
            return
        elif [[ -n "$remote_suffix" && -z "$local_suffix" ]]; then
            echo "update_not_available"
            return
        fi
    fi

    # If none of the above conditions are met
    echo "update_not_available"
}

# If it is not already known, get the contents of the relevant hash file from diginode.tools and store it in variable HASH_FILE

get_hash_file() {

    if [ "$HASH_FILE" = "" ]; then 

        if [ "$SKIP_HASH" = false ] || [ "$SKIP_HASH" = "" ]; then 
            if [ "$UPDATE_TEST" = true ]; then 
                HASH_FILE_URL="https://diginode.tools/hash0.json"
                printf "%b ${txtbylw}Update Test requested using --updatetest flag. Using staging hash file.${txtrst}\\n" "${INFO}"
            else
                HASH_FILE_URL="https://diginode.tools/hash${UPDATE_GROUP}.json"
                if [ $VERBOSE_MODE = true ]; then
                    printf "%b DigiNode Tools Update Group: ${UPDATE_GROUP}\\n" "${INFO}"
                fi
            fi
        else
            printf "%b ${txtbylw}Skipping sha256 hash verification - requested using --skiphash flag.${txtrst}\\n" "${INFO}"
        fi

        HASH_FILE=$(curl -sL $HASH_FILE_URL 2>/dev/null)
    fi
}


# This function will check if DigiByte Node is installed, and if it is, check if there is an update available

check_digibyte_core() {

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

    # If we don't already know, let's check if this is a pre-release version?
    if [ "$DGB_PRERELEASE" = "" ] && [ "$DGB_STATUS" = "installed" ]; then
        str="Is installed DigiByte Core the pre-release version?..."
        printf "%b %s" "${INFO}" "${str}"
        if [ -f "$DGB_INSTALL_LOCATION/.prerelease" ]; then
            DGB_PRERELEASE="YES"
            sed -i -e "/^DGB_PRERELEASE=/s|.*|DGB_PRERELEASE=\"$DGB_PRERELEASE\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s YES! [ .prerelease file located ] \\n" "${OVER}" "${TICK}" "${str}"
        else
            DGB_PRERELEASE="NO"
            sed -i -e "/^DGB_PRERELEASE=/s|.*|DGB_PRERELEASE=\"$DGB_PRERELEASE\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi

    # If this is a pre-release version, and we don't already know the version number, get it from inside the .prerelease file 
    if [ "$DGB_PRERELEASE" = "YES" ] && [ "$DGB_VER_LOCAL" = "" ] && [ "$DGB_STATUS" = "installed" ]; then
        str="Getting the version number from .prerelease file..."
        printf "%b %s" "${INFO}" "${str}"
        if [ -f "$DGB_INSTALL_LOCATION/.prerelease" ]; then
            source "$DGB_INSTALL_LOCATION/.prerelease"
            sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
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

      # Is Dual Node detected?
      str="Is a DigiByte Dual Node detected?..."
      printf "%b %s" "${INFO}" "${str}"
      if [ -f "$DGB2_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB2_UPSTART_SERVICE_FILE" ]; then
          DGB2_STATUS="installed"
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
          DGB_DUAL_NODE="YES"
          sed -i -e "/^DGB_DUAL_NODE=/s|.*|DGB_DUAL_NODE=\"YES\"|" $DGNT_SETTINGS_FILE
      else
          DGB2_STATUS="not_detected"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
          DGB_DUAL_NODE="NO"
          sed -i -e "/^DGB_DUAL_NODE=/s|.*|DGB_DUAL_NODE=\"NO\"|" $DGNT_SETTINGS_FILE
      fi

    # Next let's check if DigiByte daemon is running
    if [ "$DGB_STATUS" = "installed" ]; then
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            str="Is the primary DigiByte Node running?..."
        else
            str="Is the DigiByte Node running?..."
        fi
      printf "%b %s" "${INFO}" "${str}"
      if check_service_active "digibyted"; then
          DGB_STATUS="running"
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
      else
          DGB_STATUS="notrunning"
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
      fi

      # If available, is the secondary DigiByte Node running?
      if [ "$DGB_DUAL_NODE" = "YES" ]; then
          str="Is the secondary DigiByte Node running?..."
          printf "%b %s" "${INFO}" "${str}"
          if check_service_active "digibyted-testnet"; then
              DGB2_STATUS="running"
              printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
          else
              DGB2_STATUS="notrunning"
              printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
          fi
      fi

    fi

    # Restart primary DigiByte Node if the RPC port has changed and it can't connect
    if [ "$DGB_STATUS" = "running" ]; then
        IS_RPC_PORT_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Could not connect to the server")
        if [ "$IS_RPC_PORT_CHANGED" = "Could not connect to the server" ]; then
            printf "%b RPC port has been changed. DigiByte daemon will be restarted.\\n" "${INFO}"
            restart_service digibyted
        fi
    fi

    # Restart secondary DigiByte Node if the RPC port has changed and it can't connect
    if [ "$DGB2_STATUS" = "running" ]; then
        IS_RPC2_PORT_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet getblockcount 2>&1 | grep -Eo "Could not connect to the server")
        if [ "$IS_RPC2_PORT_CHANGED" = "Could not connect to the server" ]; then
            printf "%b RPC port has been changed. Secondary DigiByte daemon will be restarted.\\n" "${INFO}"
            restart_service digibyted-testnet
        fi
    fi

   # Restart primary DigiByte Node if the RPC listening port has changed and it can't connect
    if [ "$DGB_STATUS" = "running" ]; then
        IS_RPC_PORT_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Could not connect to the server")
        if [ "$IS_RPC_PORT_CHANGED" = "Could not connect to the server" ]; then
            printf "%b RPC port has been changed. DigiByte daemon will be restarted.\\n" "${INFO}"
            restart_service digibyted
        fi
    fi

   # Restart secondary DigiByte Node if the RPC listening port has changed and it can't connect
    if [ "$DGB2_STATUS" = "running" ]; then
        IS_RPC2_PORT_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet getblockcount 2>&1 | grep -Eo "Could not connect to the server")
        if [ "$IS_RPC2_PORT_CHANGED" = "Could not connect to the server" ]; then
            printf "%b RPC port has been changed. Seondary DigiByte daemon will be restarted.\\n" "${INFO}"
            restart_service digibyted-testnet
        fi
    fi

    # If primary DigiByte Node is running, is it in the process of starting up, and not yet ready to respond to requests?
    if [ "$DGB_STATUS" = "running" ]; then
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            str="Is the primary DigiByte Node finished starting up?..."
        else
            str="Is the DigiByte Node finished starting up?..."
        fi
        printf "%b %s" "${INFO}" "${str}"
        IS_DGB_STARTED_UP=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>/dev/null)
        if [ "$IS_DGB_STARTED_UP" = "" ]; then
          printf "%b%b %s NOT YET...\\n" "${OVER}" "${CROSS}" "${str}"
          DGB_STATUS="startingup"
        else
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # If secondary "Dual Node" DigiByte Node is running, is it in the process of starting up, and not yet ready to respond to requests?
    if [ "$DGB2_STATUS" = "running" ]; then
        str="Is the secondary DigiByte node finished starting up?..."
        printf "%b %s" "${INFO}" "${str}"
        IS_DGB2_STARTED_UP=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet getblockcount 2>/dev/null)
        if [ "$IS_DGB2_STARTED_UP" = "" ]; then
          printf "%b%b %s NOT YET...\\n" "${OVER}" "${CROSS}" "${str}"
          DGB2_STATUS="startingup"
        else
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # Check if any at least one chain is running
    if [ "$DGB_STATUS" = "running" ] && [ "$DGB2_STATUS" = "running" ]; then
        query_which_dgb_node="primary"
    elif [ "$DGB_STATUS" = "running" ]; then
        query_which_dgb_node="primary"
    elif [ "$DGB2_STATUS" = "running" ]; then
        query_which_dgb_node="secondary"

    # If primary DigiByte Node is currently in the process of starting up, we need to wait until it
    # can actually respond to requests so we can get the current version number from digibyte-cli
    elif [ "$DGB_STATUS" = "startingup" ]; then
        every10secs=0
        progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
        printf "%b %bDigiByte Core is in the process of starting up. This can take 10 mins or more.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        str="Please wait..."
        printf "%b %s" "${INDENT}" "${str}"
        tput civis
        # Query if digibyte has finished starting up. Display error. Send success to null.
        is_dgb_live_query=$(sudo -u $USER_ACCOUNT $DGB_CLI uptime 2>&1 1>/dev/null)
        if [ "$is_dgb_live_query" != "" ]; then
            dgb_error_msg=$(echo $is_dgb_live_query | cut -d ':' -f3)
            dgb_error_msg=$(sed 's/%/%%/g' <<<"$dgb_error_msg")
            dgb_error_msg="${dgb_error_msg/…/...}"
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

            if [ "$every10secs" -ge 20 ]; then
                # Query if digibyte has finished starting up. Display error. Send success to null.
                is_dgb_live_query=$(sudo -u $USER_ACCOUNT $DGB_CLI uptime 2>&1 1>/dev/null)
                if [ "$is_dgb_live_query" != "" ]; then
                    dgb_error_msg=$(echo $is_dgb_live_query | cut -d ':' -f3)
                    dgb_error_msg=$(sed 's/%/%%/g' <<<"$dgb_error_msg")
                    dgb_error_msg="${dgb_error_msg/…/...}"
                    printf "%b%b %s $dgb_error_msg  $progress Querying..." "${OVER}" "${INDENT}" "${str}"
                    every10secs=0
                    sleep 0.5
                else
                    DGB_STATUS="running"
                    query_which_dgb_node="primary"
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    tput cnorm
                fi
            else
                every10secs=$((every10secs + 1))
                printf "%b%b %s $dgb_error_msg  $progress" "${OVER}" "${INDENT}" "${str}"
                sleep 0.5
            fi
        done

    # If secondary DigiByte Node is currently in the process of starting up, we need to wait until it
    # can actually respond to requests so we can get the current version number from digibyte-cli
    elif [ "$DGB2_STATUS" = "startingup" ]; then
        every10secs=0
        progress="[${COL_BOLD_WHITE}◜ ${COL_NC}]"
        printf "%b %bDigiByte secondary node is in the process of starting up. This can take 10 mins or more.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        str="Please wait..."
        printf "%b %s" "${INDENT}" "${str}"
        tput civis
        # Query if digibyte has finished starting up. Display error. Send success to null.
        is_dgb_live_query=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet uptime 2>&1 1>/dev/null)
        if [ "$is_dgb_live_query" != "" ]; then
            dgb_error_msg=$(echo $is_dgb_live_query | cut -d ':' -f3)
            dgb_error_msg=$(sed 's/%/%%/g' <<<"$dgb_error_msg")
            dgb_error_msg="${dgb_error_msg/…/...}"
        fi
        while [ $DGB2_STATUS = "startingup" ]; do

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

            if [ "$every10secs" -ge 20 ]; then
                # Query if digibyte has finished starting up. Display error. Send success to null.
                is_dgb_live_query=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet uptime 2>&1 1>/dev/null)
                if [ "$is_dgb_live_query" != "" ]; then
                    dgb_error_msg=$(echo $is_dgb_live_query | cut -d ':' -f3)
                    dgb_error_msg=$(sed 's/%/%%/g' <<<"$dgb_error_msg")
                    dgb_error_msg="${dgb_error_msg/…/...}"
                    printf "%b%b %s $dgb_error_msg $progress Querying..." "${OVER}" "${INDENT}" "${str}"
                    every10secs=0
                    sleep 0.5
                else
                    DGB2_STATUS="running"
                    query_which_dgb_node="secondary"
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    tput cnorm
                fi
            else
                every10secs=$((every10secs + 1))
                printf "%b%b %s $dgb_error_msg $progress" "${OVER}" "${INDENT}" "${str}"
                sleep 0.5
            fi
        done


    fi

    # Find out the current  DGB network chain
    if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "notrunning" ] || [ "$DGB_STATUS" = "startingup" ]; then

        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            str="Checking primary DigiByte Node chain..."
        else
            str="Checking DigiByte Node chain..."
        fi

        printf "%b %s" "${INFO}" "${str}"

        # Query if DigiByte Core is running the mainnet, testnet or regtest chain
        query_digibyte_chain

        if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
            printf "%b%b %s TESTNET (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
            printf "%b%b %s REGTEST (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
            printf "%b%b %s MAINNET (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
            printf "%b%b %s TESTNET (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
            printf "%b%b %s REGTEST (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
            printf "%b%b %s MAINNET (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi

    # Get Tor Status
    query_digibyte_tor

    if [ "$SETUP_DUAL_NODE" = "YES" ] || [ "$DGB_DUAL_NODE" = "YES" ]; then
        str="Is primary DigiByte $DGB_NETWORK_CURRENT Node using Tor?..."
    else
        str="Is DigiByte $DGB_NETWORK_CURRENT Node using Tor?..."
    fi

    # Display Tor status for primary Node
    if [ "$DGB_USING_TOR" = "YES" ] && [ "$DGB_USING_TOR_LIVE" = "YES" ]; then 
        printf "%b%b %s Yes (live)\\n" "${OVER}" "${TICK}" "${str}"
    elif [ "$DGB_USING_TOR" = "NO" ] && [ "$DGB_USING_TOR_LIVE" = "YES" ]; then 
        printf "%b%b %s No (live)\\n" "${OVER}" "${TICK}" "${str}"
    elif [ "$DGB_USING_TOR" = "YES" ] && [ "$DGB_USING_TOR_LIVE" = "NO" ]; then 
        printf "%b%b %s Yes (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
    elif [ "$DGB_USING_TOR" = "NO" ] && [ "$DGB_USING_TOR_LIVE" = "NO" ]; then 
        printf "%b%b %s No (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
    fi

    if [ "$SETUP_DUAL_NODE" = "YES" ] || [ "$DGB_DUAL_NODE" = "YES" ]; then
        str="Is secondary DigiByte TESTNET Node using Tor?..."

        # Display Tor status for primary Node
        if [ "$DGB2_USING_TOR" = "YES" ] && [ "$DGB2_USING_TOR_LIVE" = "YES" ]; then 
            printf "%b%b %s Yes (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB2_USING_TOR" = "NO" ] && [ "$DGB2_USING_TOR_LIVE" = "YES" ]; then 
            printf "%b%b %s No (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB2_USING_TOR" = "YES" ] && [ "$DGB2_USING_TOR_LIVE" = "NO" ]; then 
            printf "%b%b %s Yes (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB2_USING_TOR" = "NO" ] && [ "$DGB2_USING_TOR_LIVE" = "NO" ]; then 
            printf "%b%b %s No (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi

    # Get the version number of the current DigiByte Node and write it to to the settings file
    # Use whichever node is running to find this out (primary node, or the secondary testnet node, if we are running a Dual Node)
    if [ "$DGB_STATUS" = "running" ] || [ "$DGB2_STATUS" = "running" ]; then

        str="Current Version:"
        printf "%b %s" "${INFO}" "${str}"

        # If this is a pre-release version just use the version number from diginode.settings, otherwise query for it
        if [ "$DGB_PRERELEASE" = "YES" ]; then
            printf "%b%b %s DigiByte Core v${DGB_VER_LOCAL}  [ Pre-release ]\\n" "${OVER}" "${INFO}" "${str}"
        else
            if [ "$query_which_dgb_node" = "primary" ]; then
                DGB_VER_LOCAL=$(sudo -u $USER_ACCOUNT $DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
            elif [ "$query_which_dgb_node" = "secondary" ]; then
                DGB_VER_LOCAL=$(sudo -u $USER_ACCOUNT $DGB_CLI -testnet getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
            fi

            sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s DigiByte Core v${DGB_VER_LOCAL}\\n" "${OVER}" "${INFO}" "${str}"
        fi

    elif [ "$DGB_STATUS" = "notrunning" ] || [ "$DGB2_STATUS" = "notrunning" ]; then

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

    fi

    # If this is a new install, and the user did not choose to install the pre-release, then instruct it to install the release version
    if [ "$DGB_STATUS" = "not_detected" ] && [ "$REQUEST_DGB_RELEASE_TYPE" = "" ]; then
        INSTALL_DGB_RELEASE_TYPE="release"
        DGB_PRERELEASE=""
        printf "%b New install. DigiByte Core release version will be used.\\n" "${INFO}"
    fi

    # If the user requested the latest pre-release version of DigiByte Core, display a message, and set install variable
    if [ "$REQUEST_DGB_RELEASE_TYPE" = "prerelease" ]; then
        printf "%b ${txtbylw}DigiByte Core pre-release version requested using --dgbpre flag.${txtrst}\\n" "${INFO}"
        INSTALL_DGB_RELEASE_TYPE="prerelease"
    fi

    # If the user requested the latest release version of DigiByte Core, set install variable
    if [ "$REQUEST_DGB_RELEASE_TYPE" = "release" ]; then
        INSTALL_DGB_RELEASE_TYPE="release"
    fi

    # Set the verification hash file to use
    get_hash_file

    # Check for latest pre-release version if it is currently being used or has been requested
    if [ "$INSTALL_DGB_RELEASE_TYPE" = "prerelease" ] || [ "$DGB_PRERELEASE" = "YES" ]; then

        # Check Github repo for DigiByte Core release JSON
        str="Getting DigiByte Core release info from Github..."
        printf "%b %s" "${INFO}" "${str}"

        DGB_RELEASE_JSON_QUERY=$(curl --silent https://api.github.com/repos/digibyte-core/digibyte/releases 2>/dev/null)

        local dgb_json_error_msg=$(echo "$DGB_RELEASE_JSON_QUERY" | jq -r '.message // "No message field"' 2>/dev/null)

        # If we don't get a response from Github, or the repo is not found, cancel
        if [ "$DGB_RELEASE_JSON_QUERY" = "" ] || [ "$dgb_json_error_msg" = "Not Found" ]; then
            printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b Unable to check for pre-release version of DigiByte Core. Is the Internet down?.\\n" "${CROSS}"
            printf "\\n"
            if [ "$DGB_STATUS" = "not_detected" ]; then
                printf "%b DigiByte Core cannot be installed. Skipping...\\n" "${INFO}"
            else
                printf "%b DigiByte Core cannot be upgraded. Skipping...\\n" "${INFO}"
            fi
            printf "\\n"
            DGB_DO_INSTALL=NO
            DGB_INSTALL_TYPE="none"
            DGB_UPDATE_AVAILABLE=NO
            return
        else
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            DGB_RELEASE_JSON=$DGB_RELEASE_JSON_QUERY
        fi

        # Check the variable containing the JSON from Github to find the version number of the latest DigiByte Core pre-release
        str="Checking for latest DigiByte Core pre-release..."
        printf "%b %s" "${INFO}" "${str}"

        # if the most recent release is a pre-release then store the pre-release version number. if the newest release is a regular release then just return 'null'
        DGB_VER_PRERELEASE=$(echo "$DGB_RELEASE_JSON" | jq -r '.[0] | if .prerelease then .tag_name else "null" end' | sed 's/v//g')


        #########################################################
        ########### TESTING: LATEST PRE-RELEASE #################
        #########################################################
        # DGB_VER_PRERELEASE="null"
        #########################################################
        #########################################################

        # If there is no pre-release version
        if [ "$DGB_VER_PRERELEASE" = "null" ]; then
            sed -i -e "/^DGB_VER_PRERELEASE=/s|.*|DGB_VER_PRERELEASE=|" $DGNT_SETTINGS_FILE
            # Display dialog if DigiByte pre-release was requested but it is unavalable (and if we not running unattended)
            if [ "$REQUEST_DGB_RELEASE_TYPE" = "prerelease" ] && [ ! "$UNATTENDED_MODE" == true ]; then
                printf "%b%b %s ${txtred}NOT AVAILABLE${txtrst}\\n" "${OVER}" "${INFO}" "${str}"
                if [ "$DGB_STATUS" = "not_detected" ]; then
                    dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core pre-release is unavailable!" --title "DigiByte Core pre-release is unavailable!" --msgbox "\n\Z1Warning: No DigiByte Core pre-release is currently available.\Z0\n\nYou requested to install a pre-release version of DigiByte Core using the --dgbpre flag but there is no pre-release version currently available. The current release will be installed instead." 11 ${c}
                else
                    dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core pre-release is unavailable!" --title "DigiByte Core pre-release is unavailable!" --msgbox "\n\Z1Warning: No DigiByte Core pre-release is currently available.\Z0\n\nYou requested to upgrade to a pre-release version of DigiByte Core using the --dgbpre flag but there is no pre-release version currently available. Upgrade will be skipped." 11 ${c}
                    printf "%b Pre-release version of DigiByte Core is not available. Upgrade skipped.\\n" "${INFO}"
                    printf "\\n"
                    return
                fi
            else
                printf "%b%b %s None!\\n" "${OVER}" "${INFO}" "${str}"
            fi
            # Since there is no available pre-release, we will switch to the latest release
            INSTALL_DGB_RELEASE_TYPE="release"
            printf "%b Pre-release version of DigiByte Core is not available. Switching to latest release...\\n" "${INFO}"
        else
            printf "%b%b %s Found: v${DGB_VER_PRERELEASE}\\n" "${OVER}" "${TICK}" "${str}"
            sed -i -e "/^DGB_VER_PRERELEASE=/s|.*|DGB_VER_PRERELEASE=\"$DGB_VER_PRERELEASE\"|" $DGNT_SETTINGS_FILE

            if [ "$SKIP_HASH" = false ]; then
                # Check diginode.tools website for SHA256 hash of the latest DigiByte Core release
                str="Checking diginode.tools for SHA256 hash of DigiByte Core v${DGB_VER_PRERELEASE}..."
                printf "%b %s" "${INFO}" "${str}"
                # Check if a hash for this pre-release exists in chosen diginode.tools hash file
                DGB_VER_PRERELEASE_HASH=$(echo "$HASH_FILE" | jq --arg v "digibyte-$DGB_VER_PRERELEASE" '.[$v]' 2>/dev/null)
            fi

            # If we don't get a result from diginode.tools (perhaps website is down?)
            if [ "$DGB_VER_PRERELEASE_HASH" = "" ] && [ "$SKIP_HASH" = false ]; then
                printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                printf "%b Unable to get SHA256 hash of DigiByte Core v${DGB_VER_PRERELEASE}. Is the Internet down?.\\n" "${CROSS}"
                printf "\\n"
                if [ "$DGB_STATUS" = "not_detected" ]; then
                    printf "%b DigiByte Core cannot be installed. Skipping...\\n" "${INFO}"
                else
                    printf "%b DigiByte Core cannot be upgraded. Skipping...\\n" "${INFO}"
                fi
                printf "\\n"
                DGB_DO_INSTALL=NO
                DGB_INSTALL_TYPE="none"
                DGB_UPDATE_AVAILABLE=NO
                return 
            # If there is NO hash for this DigiByte pre-release
            elif [ "$DGB_VER_PRERELEASE_HASH" = "null" ] && [ "$SKIP_HASH" = false ]; then
                printf "%b%b %s ${txtred}HASH NOT FOUND${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                printf "%b SHA256 hash of DigiByte Core v${DGB_VER_PRERELEASE} is not available.\\n" "${INFO}"

                ############################################################################

                # If this there is no hash for the current pre-release, we will instead try and install
                # the previous pre-release which presumably does have a hash

                # Check Github repo to find the version number of the previous DigiByte Core pre-release
                str="Checking for previous DigiByte Core pre-release..."
                printf "%b %s" "${INFO}" "${str}"

                DGB_VER_PRERELEASE=$(echo $DGB_RELEASE_JSON | jq -r '[.[] | select(.prerelease == true) | {tag_name, published_at}] | sort_by(.published_at) | reverse | .[1] as $prev_pr | [.[] | select(.prerelease == false) | {tag_name, published_at}] | sort_by(.published_at) | reverse | .[0] as $latest_r | if ($prev_pr.published_at > $latest_r.published_at) then $prev_pr.tag_name else empty end' | sed 's/v//g')

                #########################################################
                ########### TESTING: PREVIOUS PRE-RELEASE ###############
                #########################################################
                # DGB_VER_PRERELEASE="8.22.0-rc2"
                #########################################################
                #########################################################

                # If there is no previous pre-release version
                if [ "$DGB_VER_PRERELEASE" = "" ]; then
                    sed -i -e "/^DGB_VER_PRERELEASE=/s|.*|DGB_VER_PRERELEASE=|" $DGNT_SETTINGS_FILE
                    printf "%b%b %s ${txtred}NOT AVAILABLE${txtrst}\\n" "${OVER}" "${INFO}" "${str}"

                    if [ "$DGB_STATUS" = "not_detected" ]; then
                        printf "%b Previous pre-release version of DigiByte Core is not available. Install release version instead..\\n" "${INFO}"
                        INSTALL_DGB_RELEASE_TYPE="release"
                        # Display dialog if DigiByte pre-release was requested but it is unavalable (and if we not running unattended)
                        if [ "$REQUEST_DGB_RELEASE_TYPE" = "prerelease" ] && [ ! "$UNATTENDED_MODE" == true ]; then
                            dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core pre-release is unavailable!" --title "DigiByte Core pre-release is unavailable!" --msgbox "\n\Z1Warning: No DigiByte Core pre-release is currently available.\Z0\n\nYou requested to install the pre-release version of DigiByte Core using the --dgbpre flag but there is no pre-release currently available. The latest release will be installed instead." 11 ${c}
                        fi
                    else
                        printf "%b Previous pre-release version of DigiByte Core is not available either. Skipping...\\n" "${INFO}"
                        if [ "$REQUEST_DGB_RELEASE_TYPE" = "prerelease" ] && [ ! "$UNATTENDED_MODE" == true ]; then
                            dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core pre-release is unavailable!" --title "DigiByte Core pre-release is unavailable!" --msgbox "\n\Z1Warning: No DigiByte Core pre-release is currently available.\Z0\n\nYou requested to upgrade to the pre-release version of DigiByte Core using the --dgbpre flag but there is no pre-release currently available. Upgrade will be skipped." 11 ${c}
                        fi
                        printf "\\n"
                        DGB_DO_INSTALL=NO
                        DGB_INSTALL_TYPE="none"
                        DGB_UPDATE_AVAILABLE=NO
                        return 
                    fi

                else

                    printf "%b%b %s Found: v${DGB_VER_PRERELEASE}\\n" "${OVER}" "${TICK}" "${str}"
                    sed -i -e "/^DGB_VER_PRERELEASE=/s|.*|DGB_VER_PRERELEASE=\"$DGB_VER_PRERELEASE\"|" $DGNT_SETTINGS_FILE

                    # Check diginode.tools website for SHA256 hash of the previous DigiByte Core pre-release
                    str="Checking diginode.tools for SHA256 hash of DigiByte Core v${DGB_VER_PRERELEASE}..."
                    printf "%b %s" "${INFO}" "${str}"

                    # Check if a hash for the previous pre-release exists in the diginode.tools hash file
                    DGB_VER_PRERELEASE_HASH=$(echo "$HASH_FILE" | jq --arg v "digibyte-$DGB_VER_PRERELEASE" '.[$v]' 2>/dev/null)

                    # If we don't get a result from diginode.tools (perhaps website is down?)
                    if [ "$DGB_VER_PRERELEASE_HASH" = "" ]; then
                        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                        printf "%b Unable to get SHA256 hash of DigiByte Core v${DGB_VER_PRERELEASE}. Is the Internet down?.\\n" "${CROSS}"
                        printf "\\n"
                        if [ "$DGB_STATUS" = "not_detected" ]; then
                            printf "%b DigiByte Core cannot be installed. Skipping...\\n" "${INFO}"
                        else
                            printf "%b DigiByte Core cannot be upgraded. Skipping...\\n" "${INFO}"
                        fi
                        printf "\\n"
                        DGB_DO_INSTALL=NO
                        DGB_INSTALL_TYPE="none"
                        DGB_UPDATE_AVAILABLE=NO
                        return 
                    # If there is NO hash for the previous DigiByte pre-release either, then forget it
                    elif [ "$DGB_VER_PRERELEASE_HASH" = "null" ]; then
                        printf "%b%b %s ${txtred}HASH NOT FOUND${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                        printf "%b SHA256 hash of DigiByte Core v${DGB_VER_PRERELEASE} is not available.\\n" "${INFO}"
                        printf "\\n"
                        if [ "$DGB_STATUS" = "not_detected" ]; then
                            printf "%b DigiByte Core previous pre-release cannot be installed either. Skipping...\\n" "${INFO}"
                            # Display dialog if DigiByte pre-release was requested but it is unavalable (and if we not running unattended)
                            if [ "$REQUEST_DGB_RELEASE_TYPE" = "prerelease" ] && [ ! "$UNATTENDED_MODE" == true ]; then
                                dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core pre-release cannot be verified!" --title "DigiByte Core pre-release cannot be verified!" --msgbox "\n\Z1Warning: DigiByte Core v$DGB_VER_PRERELEASE cannot be installed.\Z0\n\nYou requested to upgrade to the latest pre-release version of DigiByte Core using the --dgbpre flag but v$DGB_VER_PRERELEASE has not yet been verified for use.\n\nFor help, ask in the 'DigiNode Tools' Telegram group: $SOCIAL_TELEGRAM_URL" 14 ${c}
                            fi
                        else
                            printf "%b DigiByte Core cannot be upgraded. Skipping...\\n" "${INFO}"
                            if [ "$REQUEST_DGB_RELEASE_TYPE" = "prerelease" ] && [ ! "$UNATTENDED_MODE" == true ]; then
                                dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core pre-release cannot be verified!" --title "DigiByte Core pre-release cannot be verified!" --msgbox "\n\Z1Warning: DigiByte Core v$DGB_VER_PRERELEASE cannot be installed.\Z0\n\nYou requested to upgrade to the latest pre-release version of DigiByte Core using the --dgbpre flag but v$DGB_VER_PRERELEASE has not yet been verified for use.\n\nFor help, ask in the 'DigiNode Tools' Telegram group: $SOCIAL_TELEGRAM_URL" 14 ${c}
                            fi
                        fi
                        printf "\\n"
                        DGB_DO_INSTALL=NO
                        DGB_INSTALL_TYPE="none"
                        DGB_UPDATE_AVAILABLE=NO
                        return 
                    # If there is a hash for the previous DigiByte pre-release
                    else
                        printf "%b%b %s Found!\\n" "${OVER}" "${TICK}" "${str}"

                        if [ "$REQUEST_DGB_RELEASE_TYPE" = "" ]; then
                            INSTALL_DGB_RELEASE_TYPE="prerelease"
                        fi
                    fi

                fi

                ######################################################

            # If there is a hash for this DigiByte pre-release
            else
                if [ "$SKIP_HASH" = false ]; then
                    printf "%b%b %s Found!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                if [ "$REQUEST_DGB_RELEASE_TYPE" = "" ]; then
                    INSTALL_DGB_RELEASE_TYPE="prerelease"
                elif [ "$REQUEST_DGB_RELEASE_TYPE" = "release" ];then
                    printf "%b ${txtbylw}Downgrade to previous release version requested using --dgbnopre flag...${txtrst}\\n" "${INFO}"
                    INSTALL_DGB_RELEASE_TYPE="release"
                    dgb_downgrade_requested=true
                fi
            fi
        fi

    fi

    # Check for latest release version if it is currently being used or has been requested
    if [ "$INSTALL_DGB_RELEASE_TYPE" = "release" ] || [ "$DGB_PRERELEASE" = "NO" ]; then

        # Check Github repo to find the version number of the latest DigiByte Core release
        str="Checking GitHub repo for latest DigiByte Core release..."
        printf "%b %s" "${INFO}" "${str}"
        DGB_VER_RELEASE=$(curl -sfL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//g')

        #########################################################
        ########### TESTING: LATEST RELEASE #####################
        #########################################################
        # DGB_VER_RELEASE="8.22.0"
        #########################################################
        #########################################################

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

            if [ "$SKIP_HASH" = false ]; then 
                # Check diginode.tools website for SHA256 hash of the latest DigiByte Core release
                str="Checking diginode.tools for SHA256 hash of DigiByte Core v${DGB_VER_RELEASE}..."
                printf "%b %s" "${INFO}" "${str}"

                # Check if a hash for this pre-release exists in chosen diginode.tools hash file
                DGB_VER_RELEASE_HASH=$(echo "$HASH_FILE" | jq --arg v "digibyte-$DGB_VER_RELEASE" '.[$v]' 2>/dev/null)
            fi

            # If we don't get a result from diginode.tools (perhaps website is down?)
            if [ "$DGB_VER_RELEASE_HASH" = "" ] && [ "$SKIP_HASH" = false ]; then
                printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                printf "%b Unable to get SHA256 hash of DigiByte Core v${DGB_VER_RELEASE}. Is the Internet down?.\\n" "${CROSS}"
                printf "\\n"
                if [ "$DGB_STATUS" = "not_detected" ]; then
                    printf "%b DigiByte Core cannot be installed. Skipping...\\n" "${INFO}"
                else
                    printf "%b DNSU cannot be upgraded. Skipping...\\n" "${INFO}"
                fi
                printf "\\n"
                DGB_DO_INSTALL=NO
                DGB_INSTALL_TYPE="none"
                DGB_UPDATE_AVAILABLE=NO
                return 
            # If there is NO hash for CURRRENT DigiByte release, we will try and get the PREVIOUS release
            elif [ "$DGB_VER_RELEASE_HASH" = "null" ] && [ "$SKIP_HASH" = false ]; then

                ###################################################

                printf "%b%b %s ${txtred}HASH NOT FOUND${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                printf "%b SHA256 hash of DigiByte Core v${DGB_VER_RELEASE} is not available.\\n" "${INFO}"

                # If this is a new install and there is no hash for the current release, 
                # we will try and install the previous release which presumably does have a hash
                if [ "$DGB_STATUS" = "not_detected" ]; then

                    # Check Github repo to find the version number of the previous DigiByte Core release
                    str="Checking GitHub repo for previous DigiByte Core release..."
                    printf "%b %s" "${INFO}" "${str}"
                    DGB_VER_RELEASE=$(curl --silent "https://api.github.com/repos/digibyte-core/digibyte/releases" | jq -r '[.[] | select(.prerelease == false)][1].tag_name' | sed 's/v//g')

                    #########################################################
                    ########### TESTING: PREVIOUS RELEASE ###################
                    #########################################################
                    # DGB_VER_RELEASE="7.17.2"
                    #########################################################
                    #########################################################
                    
                    # If we can't get Github version number for previous release
                    if [ "$DGB_VER_RELEASE" = "" ]; then
                        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                        printf "%b Unable to check for previous version of DigiByte Core. Is the Internet down?.\\n" "${CROSS}"
                        printf "\\n"
                        printf "%b DigiByte Core cannot be installed. Skipping...\\n" "${INFO}"
                        printf "\\n"
                        DGB_DO_INSTALL=NO
                        DGB_INSTALL_TYPE="none"
                        DGB_UPDATE_AVAILABLE=NO
                        return     
                    else

                        printf "%b%b %s Found: v${DGB_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
                        sed -i -e "/^DGB_VER_RELEASE=/s|.*|DGB_VER_RELEASE=\"$DGB_VER_RELEASE\"|" $DGNT_SETTINGS_FILE

                        # Check diginode.tools website for SHA256 hash of the previous DigiByte Core release
                        str="Checking diginode.tools for SHA256 hash of DigiByte Core v${DGB_VER_RELEASE}..."
                        printf "%b %s" "${INFO}" "${str}"

                        # Check if a hash for the previous release exists in the diginode.tools hash file
                        DGB_VER_RELEASE_HASH=$(echo "$HASH_FILE" | jq --arg v "digibyte-$DGB_VER_RELEASE" '.[$v]' 2>/dev/null)

                        # If we don't get a result from diginode.tools (perhaps website is down?)
                        if [ "$DGB_VER_RELEASE_HASH" = "" ]; then
                            printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                            printf "%b Unable to get SHA256 hash of DigiByte Core v${DGB_VER_RELEASE}. Is the Internet down?.\\n" "${CROSS}"
                            printf "\\n"
                            printf "%b DigiByte Core cannot be installed. Skipping...\\n" "${INFO}"
                            printf "\\n"
                            DGB_DO_INSTALL=NO
                            DGB_INSTALL_TYPE="none"
                            DGB_UPDATE_AVAILABLE=NO
                            return 
                        # If there is NO hash for the previous DigiByte release either, then forget it
                        elif [ "$DGB_VER_RELEASE_HASH" = "null" ]; then
                            printf "%b%b %s ${txtred}HASH NOT FOUND${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
                            printf "%b SHA256 hash of DigiByte Core v${DGB_VER_RELEASE} is not available.\\n" "${INFO}"
                            printf "\\n"
                            printf "%b DigiByte Core cannot be installed. Skipping...\\n" "${INFO}"
                            printf "\\n"
                            DGB_DO_INSTALL=NO
                            DGB_INSTALL_TYPE="none"
                            DGB_UPDATE_AVAILABLE=NO
                            return 
                        # If there is a hash for the previous DigiByte release
                        else
                            printf "%b%b %s Found!\\n" "${OVER}" "${TICK}" "${str}"

                            if [ "$REQUEST_DGB_RELEASE_TYPE" = "" ]; then
                                INSTALL_DGB_RELEASE_TYPE="release"
                            fi
                        fi

                    fi

                else
                    printf "%b DigiByte Core cannot be upgraded. Skipping...\\n" "${INFO}"
                    printf "\\n"
                    DGB_DO_INSTALL=NO
                    DGB_INSTALL_TYPE="none"
                    DGB_UPDATE_AVAILABLE=NO
                    return 
                fi

                ######################################################

            # If there is a hash for this DigiByte release
            else
                if [ "$SKIP_HASH" = false ]; then 
                    printf "%b%b %s Found!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                if [ "$REQUEST_DGB_RELEASE_TYPE" = "" ]; then
                    INSTALL_DGB_RELEASE_TYPE="release"
                fi
            fi

        fi

    fi


    # Set DGB_VER_GITHUB to the version we are comparing against
    if [ "$INSTALL_DGB_RELEASE_TYPE" = "release" ]; then
        DGB_VER_GITHUB=$DGB_VER_RELEASE
    elif [ "$INSTALL_DGB_RELEASE_TYPE" = "prerelease" ]; then
        DGB_VER_GITHUB=$DGB_VER_PRERELEASE
    fi

    # If a local version already exists.... (i.e. we have a local version number)
    if [ ! $DGB_VER_LOCAL = "" ]; then

        #########################################################
        ########### TESTING: LOCAL VERSION ######################
        #########################################################
        # DGB_VER_LOCAL="8.22.0-rc1"
        # echo "TESTING - LOCAL VER SET TO: $DGB_VER_LOCAL"
        #########################################################
        #########################################################

        # ....then check if a DigiByte Core upgrade is required

        dgb_update_status=$(is_dgb_newer_version "$DGB_VER_LOCAL" "$DGB_VER_GITHUB")

        if [ "$dgb_update_status" = "update_not_available" ] || [ "$dgb_downgrade_requested" = true ]; then
            if [ "$RESET_MODE" = true ]; then
                printf "%b Reset Mode is Enabled. You will be asked if you want to re-install DigiByte Core v${DGB_VER_GITHUB}.\\n" "${INFO}"
                DGB_INSTALL_TYPE="askreset"
            else
                printf "%b Upgrade not required.\\n" "${INFO}"
                DGB_DO_INSTALL=NO
                DGB_INSTALL_TYPE="none"
                DGB_UPDATE_AVAILABLE=NO
 #              printf "\\n"
 #              return
            fi

            if [ "$INSTALL_DGB_RELEASE_TYPE" = "release" ] && [ "$REQUEST_DGB_RELEASE_TYPE" = "release" ]; then # --dgbnopre
                printf "%b %bDigiByte Core can be downgraded from v${DGB_VER_LOCAL} to v${DGB_VER_GITHUB}.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
                DGB_INSTALL_TYPE="upgrade"
                DGB_ASK_UPGRADE=YES
            fi


        else
            printf "%b %bDigiByte Core can be upgraded from v${DGB_VER_LOCAL} to v${DGB_VER_GITHUB}.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DGB_INSTALL_TYPE="upgrade"
            DGB_ASK_UPGRADE=YES
        fi

    fi 

    # If no current version is installed, then do a clean install
    if [ $DGB_STATUS = "not_detected" ]; then
      printf "%b %bDigiByte Core v${DGB_VER_GITHUB} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      DGB_INSTALL_TYPE="new"
      DGB_DO_INSTALL=YES
    fi

    printf "\\n"

    #########################################################
    ####### TESTING: EXIT AFTER CHECKING DIGIBYTE CORE ######
    #########################################################
    # echo "TEST EXIT"
    # exit
    #########################################################
    #########################################################

}

# This function will install DigiByte Core if it not yet installed, and if it is, upgrade it to the latest release
# Note: It does not (re)start the digibyted.service automatically when done
do_digibyte_install_upgrade() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$DGB_ASK_UPGRADE" = "YES" ]; then
    DGB_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall DigiByte Core
if [ "$DGB_INSTALL_TYPE" = "askreset" ]; then

    if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --title "Reset Mode" --yesno "\n\Z4Do you want to re-install DigiByte Core v${DGB_VER_RELEASE}?\Z0\n\nNote: This will delete your current DigiByte Core folder at $DGB_INSTALL_LOCATION and re-install it. Your DigiByte settings and wallet will not be affected." 11 "${c}"; then
    
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


    # Stop primary DigiByte Node if it is running, as we need to upgrade or reset it
    if [ "$DGB_STATUS" = "running" ] && [ $DGB_INSTALL_TYPE = "upgrade" ]; then
       stop_service digibyted
       DGB_STATUS="stopped"
    elif [ "$DGB_STATUS" = "running" ] && [ $DGB_INSTALL_TYPE = "reset" ]; then
       stop_service digibyted
       DGB_STATUS="stopped"
    fi

    # Stop secondary DigiByte Node (Dual Node) if it is running, as we need to upgrade or reset it
    if [ "$DGB2_STATUS" = "running" ] && [ $DGB_INSTALL_TYPE = "upgrade" ]; then
       stop_service digibyted-testnet
       DGB2_STATUS="stopped"
    elif [ "$DGB2_STATUS" = "running" ] && [ $DGB_INSTALL_TYPE = "reset" ]; then
       stop_service digibyted-testnet
       DGB2_STATUS="stopped"
    fi
    
   # Delete old DigiByte Core tar files, if present
    if compgen -G "$USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz" > /dev/null; then
        str="Deleting old DigiByte Core tar.gz files from home folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # display the download URL
    if [ $VERBOSE_MODE = true ]; then
        printf "DigiByte binary URL: https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_GITHUB}/digibyte-${DGB_VER_GITHUB}-${ARCH}-linux-gnu.tar.gz" "${INFO}"
    fi

    # Downloading latest DigiByte Core binary from GitHub
    str="Downloading DigiByte Core v${DGB_VER_GITHUB} from Github repo..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT wget -q https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_GITHUB}/digibyte-${DGB_VER_GITHUB}-${ARCH}-linux-gnu.tar.gz -P $USER_HOME

    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        use_dgb_alt_download=false
    else
        # Try alternative download
        sudo -u $USER_ACCOUNT wget -q https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_GITHUB}/digibyte-v${DGB_VER_GITHUB}-${ARCH}-linux-gnu.tar.gz -P $USER_HOME

        if [ $? -eq 0 ]; then
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            use_dgb_alt_download=true
        else
            printf "\\n"
            printf "%b%b ${txtbred}ERROR: DigiByte Core Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
            printf "\\n"
            printf "%b The new version of DigiByte Core could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
            printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so that a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
            printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
            printf "%b For now the existing version will be restarted.\\n\\n" "${INDENT}"

            # Re-enable and re-start DigiByte digibyted.service as the download failed
            if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
                printf "%b Upgrade Failed: Re-enabling and re-starting digibyted.service ...\\n" "${INFO}"
                enable_service digibyted
                restart_service digibyted
                DGB_STATUS="running"
            elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
                printf "%b Reset Failed: Re-enabling and restarting digibyted.service ...\\n" "${INFO}"
                enable_service digibyted
                restart_service digibyted
                DGB_STATUS="running"
            fi

            # Re-enable and re-start DigiByte digibyted-testnet.service as the download failed
            if [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
                printf "%b Upgrade Failed: Re-enabling and re-starting digibyted-testnet.service ...\\n" "${INFO}"
                enable_service digibyted-testnet
                restart_service digibyted-testnet
                DGB2_STATUS="running"
            elif [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
                printf "%b Reset Failed: Re-enabling and restarting digibyted-testnet.service ...\\n" "${INFO}"
                enable_service digibyted-testnet
                restart_service digibyted-testnet
                DGB2_STATUS="running"
            fi

            printf "\\n"
            INSTALL_ERROR="YES"
            return 1
        fi
    fi

    # Perform hash verficiation of download, unless the user chose to skip it with the --skiphash flag
    if [ "$SKIP_HASH" = false ]; then 

        # Check diginode.tools website for SHA256 hash of the latest DigiByte Core release
        str="Checking diginode.tools for SHA256 hash of DigiByte Core v${DGB_VER_GITHUB}..."
        printf "%b %s" "${INFO}" "${str}"

        # Check if a hash for this pre-release exists in diginode.tools hash file
        DGB_VER_GITHUB_HASH=$(echo "$HASH_FILE" | jq -r --arg v "digibyte-$DGB_VER_GITHUB" --arg a "$ARCH" '.[$v]|.[$a]' 2>/dev/null)

        # If we don't get a result from diginode.tools (perhaps website is down?)
        if [ "$DGB_VER_GITHUB_HASH" = "" ]; then
            printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b Unable to get SHA256 hash of DigiByte Core v${DGB_VER_GITHUB}. Is the Internet down?.\\n" "${CROSS}"
            printf "\\n"
            hash_verification_failed="yes"
        # If there is NO hash for this DigiByte pre-release
        elif [ "$DGB_VER_GITHUB_HASH" = "null" ]; then
            printf "%b%b %s ${txtred}HASH NOT FOUND${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b SHA256 hash of DigiByte Core v${DGB_VER_PRERELEASE} is not available.\\n" "${INFO}"
            printf "\\n"
            hash_verification_failed="yes"
        # If there is a hash for this DigiByte pre-release
        else
            printf "%b%b %s Found!\\n" "${OVER}" "${TICK}" "${str}"

            # Hashing downloaded DigiByte Core tar.gz file
            str="Hashing downloaded DigiByte Core v$DGB_VER_GITHUB binary..."
            printf "%b %s" "${INFO}" "${str}"
            # If this is the alt url download, we need to add a v in the URL
            if [ "$use_dgb_alt_download" == true ]; then
                DGB_VER_LOCAL_HASH=$(sha256sum $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz | awk '{print $1}')
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            else
                DGB_VER_LOCAL_HASH=$(sha256sum $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz | awk '{print $1}')
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            str="Checking SHA256 hashes are a match for DigiByte Core $DGB_VER_GITHUB ..."
            printf "%b %s" "${INFO}" "${str}"

            # Check if the hash on diginode.tools matches the hash of the downloaded DigiByte Core release (i.e. it has not been tampered with)
            if [ "$DGB_VER_LOCAL_HASH" = "$DGB_VER_GITHUB_HASH" ]; then
                printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
                hash_verification_failed=""
            else
                printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
                hash_verification_failed="yes"
            fi

        fi

        # If hash verification failed
        if [ "$hash_verification_failed" = "yes" ]; then

            if [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
                printf "%b DigiByte Core v$DGB_VER_GITHUB download cannot be verified. Rolling back...\\n" "${INFO}"
                printf "\\n"
            elif [ "$DGB_INSTALL_TYPE" = "new" ]; then
                printf "%b DigiByte Core v$DGB_VER_GITHUB download cannot be verified.\\n" "${INFO}"
                printf "\\n"
            fi

            # Display dialog if DigiByte verificantion failed
            if [ ! "$UNATTENDED_MODE" == true ]; then
                if [ "$DGB_INSTALL_TYPE" = "new" ]; then
                    dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core download cannot be verified." --title "DigiByte Core download cannot be verified." --msgbox "\n\Z1ERROR: DigiByte Core v$DGB_VER_GITHUB download could not be verified.\Z0\n\nThe verification has does no match." 9 ${c}
                else
                    dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core download cannot be verified." --title "DigiByte Core download cannot be verified." --msgbox "\n\Z1ERROR: DigiByte Core v$DGB_VER_GITHUB download could not be verified.\Z0\n\nThe verification hash does not match. DigiByte Core v$DGB_VER_LOCAL will be restored." 10 ${c}
                fi
            fi

            # Delete DigiByte Core tar.gz file
            str="Deleting install file: digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz ..."
            printf "%b %s" "${INFO}" "${str}"
            # If this is the alt url download, we need to add a v in the URL
            if [ "$use_dgb_alt_download" == true ]; then
                rm -f $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            else
                rm -f $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Re-enable and re-start DigiByte digibyted.service as the download failed
            if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
                printf "%b Upgrade Failed: Re-enabling and re-starting digibyted.service ...\\n" "${INFO}"
                enable_service digibyted
                restart_service digibyted
                DGB_STATUS="running"
            elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
                printf "%b Reset Failed: Re-enabling and restarting digibyted.service ...\\n" "${INFO}"
                enable_service digibyted
                restart_service digibyted
                DGB_STATUS="running"
            fi

            # Re-enable and re-start DigiByte digibyted-testnet.service as the download failed
            if [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
                printf "%b Upgrade Failed: Re-enabling and re-starting digibyted-testnet.service ...\\n" "${INFO}"
                enable_service digibyted-testnet
                restart_service digibyted-testnet
                DGB2_STATUS="running"
            elif [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
                printf "%b Reset Failed: Re-enabling and restarting digibyted-testnet.service ...\\n" "${INFO}"
                enable_service digibyted-testnet
                restart_service digibyted-testnet
                DGB2_STATUS="running"
            fi

            printf "\\n"
            hash_verification_failed=""
            INSTALL_ERROR="YES"
            return 1
        fi

    else
        printf "%b ${txtbylw}Skipping SHA256 hash verification - requested using --skiphash flag.${txtrst}\\n" "${INFO}"
    fi



    # If there is an old backup of DigiByte Core, delete it
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backup" ]; then
        str="Deleting old backup of DigiByte Core v${DGB_VER_LOCAL}..."
        printf "%b %s" "${INFO}" "${str}"
        rm -rf $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If an there is an existing DigiByte install folder, move it to backup
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}" ]; then
        str="Backing up DigiByte Core v$DGB_VER_LOCAL ..."
        printf "%b %s" "${INFO}" "${str}"
        mv $USER_HOME/digibyte-${DGB_VER_LOCAL} $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Extracting DigiByte Core binary
    # If this is the alt url download, we need to add a v in the URL
    if [ "$use_dgb_alt_download" == true ]; then
        str="Extracting DigiByte Core v${DGB_VER_GITHUB} ..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT tar -xf $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz -C $USER_HOME
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        str="Extracting DigiByte Core v${DGB_VER_GITHUB} ..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT tar -xf $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz -C $USER_HOME
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # WORKAROUND: If this is 8.22.0-rc2, we need to manually rename the extracted directory name, since it is incorrect
    if [ -d "$USER_HOME/digibyte-af42429717ac" ] && [ "$DGB_VER_GITHUB" = "8.22.0-rc2" ]; then
        str="Renaming 8.22.0-rc2 download folder..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mv $USER_HOME/digibyte-af42429717ac $USER_HOME/digibyte-8.22.0-rc2
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # WORKAROUND: If this is 8.22.0-rc3, we need to manually rename the extracted directory name, since it is incorrect
    if [ -d "$USER_HOME/digibyte-af6d4e3cdef0" ] && [ "$DGB_VER_GITHUB" = "8.22.0-rc3" ]; then
        str="Renaming 8.22.0-rc3 download folder..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mv $USER_HOME/digibyte-af6d4e3cdef0 $USER_HOME/digibyte-8.22.0-rc3
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # WORKAROUND: If this is 8.22.0-rc4, we need to manually rename the extracted directory name, since it is incorrect
    if [ -d "$USER_HOME/digibyte-527219d69dd9" ] && [ "$DGB_VER_GITHUB" = "8.22.0-rc4" ]; then
        str="Renaming 8.22.0-rc4 download folder..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mv $USER_HOME/digibyte-527219d69dd9 $USER_HOME/digibyte-8.22.0-rc4
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # WORKAROUND: If this is 8.22.1, we need to manually rename the extracted directory name, since it is incorrect
    if [ -d "$USER_HOME/digibyte-664c6a372bd2" ] && [ "$DGB_VER_GITHUB" = "8.22.1" ]; then
        str="Renaming 8.22.1 download folder..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mv $USER_HOME/digibyte-664c6a372bd2 $USER_HOME/digibyte-8.22.1
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If we can't find the extracted folder because it is not using the standard folder name,
    # then we need to cancel the install and restore the previous version from backup
    if [ ! -d "$USER_HOME/digibyte-${DGB_VER_GITHUB}" ]; then
        printf "\\n"
        printf "%b%b ${txtbred}ERROR: DigiByte Core v$DGB_VER_GITHUB Install Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b The extracted folder could not be located at ~/digibyte-$DGB_VER_GITHUB. This release may be using a non-standard name.\\n" "${INFO}"
        printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so that a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
        printf "%b For now the existing version will be restarted.\\n\\n" "${INDENT}"

        # Delete DigiByte Core tar.gz file
        str="Deleting DigiByte Core install file: digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz ..."
        printf "%b %s" "${INFO}" "${str}"
        # If this is the alt url download, we need to add a v in the URL
        if [ "$use_dgb_alt_download" == true ]; then
            rm -f $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            rm -f $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If an there is an existing DigiByte Core backup folder, resture it
        if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backup" ]; then
            str="Restoring the backup version of DigiByte Core v$DGB_VER_LOCAL ..."
            printf "%b %s" "${INFO}" "${str}"
            mv $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup $USER_HOME/digibyte-${DGB_VER_LOCAL}
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Re-enable and re-start DigiByte daemon service as the download failed
        if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Upgrade Failed: Re-enabling and re-starting digibyted.service ...\\n" "${INFO}"
            enable_service digibyted
            restart_service digibyted
            DGB_STATUS="running"
        elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Failed: Re-enabling and restarting digibyted.service ...\\n" "${INFO}"
            enable_service digibyted
            restart_service digibyted
            DGB_STATUS="running"
        fi

        # Re-enable and re-start digibyted-testnet.service as the download failed
        if [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Upgrade Failed: Re-enabling and re-starting digibyted-testnet.service ...\\n" "${INFO}"
            enable_service digibyted-testnet
            restart_service digibyted-testnet
            DGB2_STATUS="running"
        elif [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Failed: Re-enabling and restarting digibyted-testnet.service ...\\n" "${INFO}"
            enable_service digibyted-testnet
            restart_service digibyted-testnet
            DGB2_STATUS="running"
        fi

        printf "\\n"
        INSTALL_ERROR="YES"
        return 1

    fi

    # Delete old ~/digibyte symbolic link
    if [ -h "$USER_HOME/digibyte" ]; then
        str="Deleting old '~/digibyte' symbolic link from home folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/digibyte
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Create new symbolic link
    str="Creating '~/digibyte' symbolic link for DigiByte Core v$DGB_VER_GITHUB ..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT ln -s $USER_HOME/digibyte-$DGB_VER_GITHUB $USER_HOME/digibyte
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Delete the backup version, now the new version has been installed
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backup" ]; then
        str="Deleting backup of DigiByte Core v$DGB_VER_LOCAL ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -rf $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    
    # Delete DigiByte Core tar.gz file
    str="Deleting install file: digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz ..."
    printf "%b %s" "${INFO}" "${str}"
    # If this is the alt url download, we need to add a v in the URL
    if [ "$use_dgb_alt_download" == true ]; then
        rm -f $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        rm -f $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Update diginode.settings with new DigiByte Core local version number and the install/upgrade date
    DGB_VER_LOCAL=$DGB_VER_GITHUB
    sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    if [ "$DGB_INSTALL_TYPE" = "new" ]; then
        sed -i -e "/^DGB_INSTALL_DATE=/s|.*|DGB_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        sed -i -e "/^DGB_UPGRADE_DATE=/s|.*|DGB_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Update diginode.settings to store whether this is the pre-release version
    if [ "$INSTALL_DGB_RELEASE_TYPE" = "release" ]; then
        DGB_PRERELEASE="NO"
        sed -i -e "/^DGB_PRERELEASE=/s|.*|DGB_PRERELEASE=\"$DGB_PRERELEASE\"|" $DGNT_SETTINGS_FILE
    elif [ "$INSTALL_DGB_RELEASE_TYPE" = "prerelease" ]; then
        DGB_PRERELEASE="YES"
        sed -i -e "/^DGB_PRERELEASE=/s|.*|DGB_PRERELEASE=\"$DGB_PRERELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # Create hidden file to denote this is a pre-release version and add version number to it
    # This file is used to have a local reference of which pre-release version this is since
    # DigiByte Core typically does not know this precisely. This is used as backup for the value in diginode.settings
    # for the rare situations where that file gets deleted,
    if [ ! -f "$DGB_INSTALL_LOCATION/.prerelease" ] && [ "$DGB_PRERELEASE" = "YES" ]; then
        str="Labeling as DigiByte Core pre-release version..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_INSTALL_LOCATION/.prerelease
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

       # Create a new digibyte.conf file
        str="Logging pre-release version number in .prerelease file..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_CONF_FILE
        cat <<EOF > $DGB_INSTALL_LOCATION/.prerelease
# This file is used to store the local version number of a pre-release version of DigiByte Core.
# Given that DigiByte Core pre-releases typically do not know their precise version number,
# this file is used as a workaround to remember which version is currently installed. 
# Do not delete this file or upgrades will break.

# Example: "8.22.0-rc3"

DGB_VER_LOCAL="$DGB_VER_LOCAL"

EOF
printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Re-enable and re-start digibyted.service after reset/upgrade
    if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf "%b Upgrade Completed: Re-enabling and re-starting digibyted.service ...\\n" "${INFO}"
        enable_service digibyted
        restart_service digibyted
        DGB_STATUS="running"
        DIGINODE_UPGRADED="YES"
    elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf "%b Reset Completed: Re-enabling and restarting digibyted.service ...\\n" "${INFO}"
        enable_service digibyted
        restart_service digibyted
        DGB_STATUS="running"
    fi

    # Re-enable and re-start digibyted-testnet.service after reset/upgrade
    if [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf "%b Upgrade Completed: Re-enabling and re-starting digibyted-testnet.service ...\\n" "${INFO}"
        enable_service digibyted-testnet
        restart_service digibyted-testnet
        DGB2_STATUS="running"
        DIGINODE_UPGRADED="YES"
    elif [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf "%b Reset Completed: Re-enabling and restarting digibyted-testnet.service ...\\n" "${INFO}"
        enable_service digibyted-testnet
        restart_service digibyted-testnet
        DGB2_STATUS="running"
    fi

    # Reset DGB Install and Upgrade Variables
    DGB_INSTALL_TYPE=""
    DGB_UPDATE_AVAILABLE=NO
    DGB_POSTUPDATE_CLEANUP=YES
    INSTALL_DGB_RELEASE_TYPE=""

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

check_diginode_tools() {

printf " =============== Checking: DigiNode Tools ==============================\\n\\n"
# ==============================================================================

    local str

    #lookup latest release version on Github (need jq installed for this query)
    local dgnt_ver_release_query=$(curl -sL https://api.github.com/repos/DigiNode-Tools/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')

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
                    printf "%b Reset Mode is Enabled. You will be asked if you want to re-install DigiNode Tools v${DGNT_VER_RELEASE}.\\n" "${INFO}"
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

    if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --title "Reset Mode" --yesno "\n\Z4Do you want to re-install DigiNode Tools v${DGNT_VER_RELEASE}?\Z0\n\nNote: This will delete your current DigiNode Tools folder at $DGNT_LOCATION and re-install it." 10 "${c}"; then
        printf "%b Reset Mode: You chose to re-install DigiNode Tools\\n" "${INFO}"
        DGNT_DO_INSTALL=YES
        DGNT_INSTALL_TYPE="reset"
    else
        printf " =============== Reset: DigNode Tools ==============================\\n\\n"
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
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch develop https://github.com/DigiNode-Tools/diginode-tools/
            DGNT_BRANCH_LOCAL="develop"
            sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"develop\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        # Clone the develop version if develop flag is set
        elif [ "$DGNT_BRANCH_REMOTE" = "main" ]; then
            str="Installing DigiNode Tools main branch..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch main https://github.com/DigiNode-Tools/diginode-tools/
            DGNT_BRANCH_LOCAL="main"
            sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"main\"|" $DGNT_SETTINGS_FILE
            sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGNT_BRANCH_REMOTE" = "release" ]; then
            str="Installing DigiNode Tools v${DGNT_VER_RELEASE}..."
            printf "%b %s" "${INFO}" "${str}"
            sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch v${DGNT_VER_RELEASE} https://github.com/DigiNode-Tools/diginode-tools/ 2>/dev/null
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

        # Update the DigiNode custom MOTD, if it is already installed
        if [ -f "/etc/update-motd.d/50-diginode" ]; then

            # Copy MOTD file to correct location
            str="Updating DigiNode Custom MOTD file in /etc/update-motd.d..."
            printf "%b %s" "${INFO}" "${str}"
            cp -f $DGNT_LOCATION/motd/50-diginode /etc/update-motd.d
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

            # Change MOTD file owner to root
            if [ -f "/etc/update-motd.d/50-diginode" ]; then
                str="Changing updated Custom DigiNode MOTD file owner to root..."
                printf "%b %s" "${INFO}" "${str}"
                chown root:root /etc/update-motd.d/50-diginode
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Make DigiNode MOTD file executable
            if [ -f "/etc/update-motd.d/50-diginode" ]; then
                str="Make updated Custom DigiNode MOTD file executable..."
                printf "%b %s" "${INFO}" "${str}"
                chmod +x /etc/update-motd.d/50-diginode
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

        fi

        # Reset DGNT Install and Upgrade Variables
        DGNT_UPDATE_AVAILABLE=NO
        DGNT_POSTUPDATE_CLEANUP=YES

        printf "\\n"

        # Download digifacts.json
        download_digifacts        
    fi
}

# This function will install or upgrade the local version of the 'DigiByte Node Status Updater (DNSU)'.
# By default, it will always install the latest release version from GitHub.

check_dnsu() {

    printf " =============== Checking: DNSU (DigiByte Node Status Updater) =========\\n\\n"
    # ==============================================================================

    # Let's check if DNSU is already installed
    str="Is DNSU already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ -f "$DNSU_INSTALL_LOCATION/.version" ]; then
        DNSU_STATUS="installed"
        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
    else
        DNSU_STATUS="not_detected"
    fi

    # If we don't already know the local version number, get it from inside the .version file 
    if [ "$DNSU_VER_LOCAL" = "" ] && [ "$DNSU_STATUS" = "installed" ]; then
        str="Getting the local version number from .version file..."
        printf "%b %s" "${INFO}" "${str}"
        if [ -f "$DNSU_INSTALL_LOCATION/.version" ]; then
            source "$DNSU_INSTALL_LOCATION/.version"
            sed -i -e "/^DNSU_VER_LOCAL=/s|.*|DNSU_VER_LOCAL=\"$DNSU_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            DNSU_VER_LOCAL=""
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
            sed -i -e "/^DNSU_VER_LOCAL=/s|.*|DNSU_VER_LOCAL=\"$DNSU_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        fi
    fi

    # Next let's check if DNSU binary is running
    if [ "$DNSU_STATUS" = "installed" ]; then
        str="Is DNSU running?..."
        printf "%b %s" "${INFO}" "${str}"
        if check_service_active "dnsu"; then
            DNSU_STATUS="running"
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        else
            DNSU_STATUS="notrunning"
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi

    # Get the hash file contents, if not already known
    get_hash_file

    # Check Github repo to find the version number of the latest DigiByte Core release
    str="Checking GitHub repository for the latest DNSU release..."
    printf "%b %s" "${INFO}" "${str}"

    #lookup latest release version on Github (need jq installed for this query)
    local dnsu_ver_release_query=$(curl -sfL https://api.github.com/repos/jongjan88/DNSU/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')

    # If can't get Github version number
    if [ "$dnsu_ver_release_query" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for release version of DNSU. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b DNSU remote version cannot be found. Skipping...\\n" "${INFO}"
        printf "\\n"
        DNSU_DO_INSTALL=NO
        DNSU_UPDATE_AVAILABLE=NO
        return     
    else
        DNSU_VER_RELEASE=$dnsu_ver_release_query
        printf "%b%b %s Found: v${DNSU_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^DNSU_VER_RELEASE=/s|.*|DNSU_VER_RELEASE=\"$DNSU_VER_RELEASE\"|" $DGNT_SETTINGS_FILE


        if [ "$SKIP_HASH" = false ]; then 
            # Check diginode.tools website for SHA256 hash of the latest DNSU release
            str="Checking diginode.tools for SHA256 hash of DNSU v${DNSU_VER_RELEASE}..."
            printf "%b %s" "${INFO}" "${str}"

            # Check if a hash for this pre-release exists in chosen diginode.tools hash file
            DNSU_VER_RELEASE_HASH=$(echo "$HASH_FILE" 2>/dev/null | jq --arg v "v$DNSU_VER_RELEASE" '.[$v]' 2>/dev/null)
        fi

        # If we did not get a result from diginode.tools (perhaps website is down?)
        if [ "$DNSU_VER_RELEASE_HASH" = "" ] && [ "$SKIP_HASH" = false ]; then
            printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b Unable to get SHA256 hash of DNSU v${DNSU_VER_RELEASE}. Is the Internet down?.\\n" "${CROSS}"
            printf "\\n"
            if [ "$DNSU_STATUS" = "not_detected" ]; then
                printf "%b DNSU cannot be installed. Skipping...\\n" "${INFO}"
            else
                printf "%b DNSU cannot be upgraded. Skipping...\\n" "${INFO}"
            fi
            printf "\\n"
            DNSU_DO_INSTALL=NO
            DNSU_INSTALL_TYPE="none"
            DNSU_UPDATE_AVAILABLE=NO
            return 
        # If there is NO hash for this DNSU release
        elif [ "$DNSU_VER_RELEASE_HASH" = "null" ] && [ "$SKIP_HASH" = false ]; then
            printf "%b%b %s ${txtred}HASH NOT FOUND${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b SHA256 hash of DNSU v${DNSU_VER_RELEASE} is not available.\\n" "${INFO}"
            printf "\\n"
            if [ "$DNSU_STATUS" = "not_detected" ]; then
                printf "%b DNSU cannot be installed. Skipping...\\n" "${INFO}"
            else
                printf "%b DNSU cannot be upgraded. Skipping...\\n" "${INFO}"
            fi
            printf "\\n"
            DNSU_DO_INSTALL=NO
            DNSU_INSTALL_TYPE="none"
            DNSU_UPDATE_AVAILABLE=NO
            return 
        # If there is a hash for this DNSU release
        else
            if [ "$SKIP_HASH" = false ]; then 
                printf "%b%b %s Found!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            if [ "$REQUEST_DGB_RELEASE_TYPE" = "" ]; then
                INSTALL_DGB_RELEASE_TYPE="release"
            fi
        fi




        
    fi


    # If a local version already exists.... (i.e. we have a local version number)
    if [ ! $DNSU_VER_LOCAL = "" ]; then

        # ....then check if a DNSU upgrade is required

        if  [ $(version $DNSU_VER_LOCAL) -ge $(version $DNSU_VER_RELEASE) ]; then

            if [ "$RESET_MODE" = true ]; then
                printf "%b Reset Mode is Enabled. You will be asked if you want to re-install DNSU v${DNSU_VER_RELEASE}.\\n" "${INFO}"
                DNSU_INSTALL_TYPE="askreset"
            else
                printf "%b Upgrade not required.\\n" "${INFO}"
                DNSU_INSTALL_TYPE="none"
            fi

        else        
            printf "%b %bDNSU can be upgraded from v${DNSU_VER_LOCAL} to v${DNSU_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            DNSU_INSTALL_TYPE="upgrade"
            DNSU_ASK_UPGRADE=YES
        fi

    fi 

    # If no current version is installed, then do a clean install
    if [ $DNSU_STATUS = "not_detected" ]; then
      printf "%b %bDNSU v${DNSU_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      DNSU_INSTALL_TYPE="new"
      DNSU_DO_INSTALL=YES
    fi

    printf "\\n"

}


# This function will install DNSU if it not yet installed, and if it is, upgrade it to the latest release
do_dnsu_install_upgrade() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$DNSU_ASK_UPGRADE" = "YES" ]; then
    DNSU_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall DigiByte Core
if [ "$DNSU_INSTALL_TYPE" = "askreset" ]; then

    if whiptail --backtitle "" --title "RESET MODE" --yesno "Do you want to re-install DNSU (DigiByte Node Status Updater) v${DNSU_VER_RELEASE}?\\n\\nNote: This will delete your current DNSU folder at $DNSU_INSTALL_LOCATION and re-install it." "${r}" "${c}"; then
        DNSU_DO_INSTALL=YES
        DNSU_INSTALL_TYPE="reset"
    else 
        DNSU_DO_INSTALL=NO
        DNSU_INSTALL_TYPE="skipreset"
        DNSU_UPDATE_AVAILABLE=NO
    fi

fi

if [ "$DNSU_INSTALL_TYPE" = "skipreset" ]; then
    printf " =============== Reset: DNSU (DigiByte Node Status Updater) ============\\n\\n"
    # ==============================================================================
    printf "%b Reset Mode: You skipped re-installing DNSU.\\n" "${INFO}"
    printf "\\n"
    return
fi

if [ "$DNSU_DO_INSTALL" = "YES" ]; then

    # Display section break
    if [ "$DNSU_INSTALL_TYPE" = "new" ]; then
        printf " ================ Install: DNSU (DigiByte Node Status Updater) =========\\n\\n"
        # ==============================================================================
    elif [ "$DNSU_INSTALL_TYPE" = "upgrade" ]; then
        printf " =============== Upgrade: DNSU (DigiByte Node Status Updater) ==========\\n\\n"
        # ==============================================================================
    elif [ "$DNSU_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: DNSU (DigiByte Node Status Updater) ============\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose to re-install DNSU.\\n" "${INFO}"
    fi


    # Stop DNSU if it is running, as we need to upgrade or reset it
    if [ "$DNSU_STATUS" = "running" ] && [ $DNSU_INSTALL_TYPE = "upgrade" ]; then
       stop_service dnsu
       DNSU_STATUS="stopped"
    elif [ "$DNSU_STATUS" = "running" ] && [ $DNSU_INSTALL_TYPE = "reset" ]; then
       stop_service dnsu
       DNSU_STATUS="stopped"
    fi

    # first delete the current installed version of DNSU (if it exists)
    if [[ -d $DNSU_INSTALL_LOCATION ]]; then
        str="Removing DNSU current version..."
        printf "%b %s" "${INFO}" "${str}"
        rm -rf $DNSU_INSTALL_LOCATION
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        DNSU_VER_LOCAL=""
        sed -i -e "/^DNSU_VER_LOCAL=/s|.*|DNSU_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    fi

    # Next install the newest version
    cd $USER_HOME

    # Clone the main branch version if main flag is set
    if [ "$DNSU_BRANCH_REMOTE" = "main" ]; then
        str="Installing DNSU main branch..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch main https://github.com/DigiNode-Tools/diginode-tools/
        DGNT_BRANCH_LOCAL="main"
        sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"main\"|" $DGNT_SETTINGS_FILE
        sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        str="Installing DigiNode Tools v${DGNT_VER_RELEASE}..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT git clone --depth 1 --quiet --branch v${DGNT_VER_RELEASE} https://github.com/DigiNode-Tools/diginode-tools/ 2>/dev/null
        DGNT_BRANCH_LOCAL="release"
        sed -i -e "/^DGNT_BRANCH_LOCAL=/s|.*|DGNT_BRANCH_LOCAL=\"release\"|" $DGNT_SETTINGS_FILE
        DGNT_VER_LOCAL=$DGNT_VER_RELEASE
        sed -i -e "/^DGNT_VER_LOCAL=/s|.*|DGNT_VER_LOCAL=\"$DGNT_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi


########################################


    
   # Delete old DigiByte Core tar files, if present
    if compgen -G "$USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz" > /dev/null; then
        str="Deleting old DigiByte Core tar.gz files from home folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $USER_HOME/digibyte-*-${ARCH}-linux-gnu.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # display the download URL
    if [ $VERBOSE_MODE = true ]; then
        printf "DigiByte binary URL: https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_GITHUB}/digibyte-${DGB_VER_GITHUB}-${ARCH}-linux-gnu.tar.gz" "${INFO}"
    fi

    # Downloading latest DigiByte Core binary from GitHub
    str="Downloading DigiByte Core v${DGB_VER_GITHUB} from Github repository..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT wget -q https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_GITHUB}/digibyte-${DGB_VER_GITHUB}-${ARCH}-linux-gnu.tar.gz -P $USER_HOME

    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        use_dgb_alt_download=false
    else
        # Try alternative download
        sudo -u $USER_ACCOUNT wget -q https://github.com/DigiByte-Core/digibyte/releases/download/v${DGB_VER_GITHUB}/digibyte-v${DGB_VER_GITHUB}-${ARCH}-linux-gnu.tar.gz -P $USER_HOME

        if [ $? -eq 0 ]; then
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            use_dgb_alt_download=true
        else
            printf "\\n"
            printf "%b%b ${txtbred}ERROR: DigiByte Core Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
            printf "\\n"
            printf "%b The new version of DigiByte Core could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
            printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so that a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
            printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
            printf "%b For now the existing version will be restarted.\\n\\n" "${INDENT}"

            # Re-enable and re-start DigiByte digibyted.service as the download failed
            if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
                printf "%b Upgrade Failed: Re-enabling and re-starting digibyted.service ...\\n" "${INFO}"
                enable_service digibyted
                restart_service digibyted
                DGB_STATUS="running"
            elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
                printf "%b Reset Failed: Re-enabling and restarting digibyted.service ...\\n" "${INFO}"
                enable_service digibyted
                restart_service digibyted
                DGB_STATUS="running"
            fi

            # Re-enable and re-start DigiByte digibyted-testnet.service as the download failed
            if [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
                printf "%b Upgrade Failed: Re-enabling and re-starting digibyted-testnet.service ...\\n" "${INFO}"
                enable_service digibyted-testnet
                restart_service digibyted-testnet
                DGB2_STATUS="running"
            elif [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
                printf "%b Reset Failed: Re-enabling and restarting digibyted-testnet.service ...\\n" "${INFO}"
                enable_service digibyted-testnet
                restart_service digibyted-testnet
                DGB2_STATUS="running"
            fi

            printf "\\n"
            INSTALL_ERROR="YES"
            return 1
        fi
    fi

    # If there is an old backup of DigiByte Core, delete it
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backup" ]; then
        str="Deleting old backup of DigiByte Core v${DGB_VER_LOCAL}..."
        printf "%b %s" "${INFO}" "${str}"
        rm -rf $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If an there is an existing DigiByte install folder, move it to backup
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}" ]; then
        str="Backing up the existing version of DigiByte Core: $USER_HOME/digibyte-$DGB_VER_LOCAL ..."
        printf "%b %s" "${INFO}" "${str}"
        mv $USER_HOME/digibyte-${DGB_VER_LOCAL} $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Extracting DigiByte Core binary
    # If this is the alt url download, we need to add a v in the URL
    if [ "$use_dgb_alt_download" == true ]; then
        str="Extracting DigiByte Core v${DGB_VER_GITHUB} ..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT tar -xf $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz -C $USER_HOME
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        str="Extracting DigiByte Core v${DGB_VER_GITHUB} ..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT tar -xf $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz -C $USER_HOME
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # WORKAROUND: If this is 8.22.0-rc2, we need to manually rename the extracted directory name, since it is incorrect
    if [ -d "$USER_HOME/digibyte-af42429717ac" ] && [ "$DGB_VER_GITHUB" = "8.22.0-rc2" ]; then
        str="Renaming 8.22.0-rc2 download folder..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mv $USER_HOME/digibyte-af42429717ac $USER_HOME/digibyte-8.22.0-rc2
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If we can't find the extracted folder because it is not using the standard folder name,
    # then we need to cancel the install and restore the previous version from backup
    if [ ! -d "$USER_HOME/digibyte-${DGB_VER_GITHUB}" ]; then
        printf "\\n"
        printf "%b%b ${txtbred}ERROR: DigiByte Core v$DGB_VER_GITHUB Install Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b The extracted folder could not be located at ~/digibyte-$DGB_VER_GITHUB. This release may be using a non-standard name.\\n" "${INFO}"
        printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so that a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
        printf "%b For now the existing version will be restarted.\\n\\n" "${INDENT}"

        # Delete DigiByte Core tar.gz file
        str="Deleting DigiByte Core install file: digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz ..."
        printf "%b %s" "${INFO}" "${str}"
        # If this is the alt url download, we need to add a v in the URL
        if [ "$use_dgb_alt_download" == true ]; then
            rm -f $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            rm -f $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If an there is an existing DigiByte Core backup folder, resture it
        if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backup" ]; then
            str="Restoring the backup version of DigiByte Core v$DGB_VER_LOCAL ..."
            printf "%b %s" "${INFO}" "${str}"
            mv $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup $USER_HOME/digibyte-${DGB_VER_LOCAL}
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Re-enable and re-start DigiByte daemon service as the download failed
        if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Upgrade Failed: Re-enabling and re-starting digibyted.service ...\\n" "${INFO}"
            enable_service digibyted
            restart_service digibyted
            DGB_STATUS="running"
        elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Failed: Re-enabling and restarting digibyted.service ...\\n" "${INFO}"
            enable_service digibyted
            restart_service digibyted
            DGB_STATUS="running"
        fi

        # Re-enable and re-start digibyted-testnet.service as the download failed
        if [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Upgrade Failed: Re-enabling and re-starting digibyted-testnet.service ...\\n" "${INFO}"
            enable_service digibyted-testnet
            restart_service digibyted-testnet
            DGB2_STATUS="running"
        elif [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Failed: Re-enabling and restarting digibyted-testnet.service ...\\n" "${INFO}"
            enable_service digibyted-testnet
            restart_service digibyted-testnet
            DGB2_STATUS="running"
        fi

        printf "\\n"
        INSTALL_ERROR="YES"
        return 1

    fi

    # Delete old ~/digibyte symbolic link
    if [ -h "$USER_HOME/digibyte" ]; then
        str="Deleting old 'digibyte' symbolic link from home folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/digibyte
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Create new symbolic link
    str="Creating new ~/digibyte symbolic link pointing at $USER_HOME/digibyte-$DGB_VER_GITHUB ..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT ln -s $USER_HOME/digibyte-$DGB_VER_GITHUB $USER_HOME/digibyte
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Delete the backup version, now the new version has been installed
    if [ -d "$USER_HOME/digibyte-${DGB_VER_LOCAL}-backup" ]; then
        str="Deleting previous version of DigiByte Core: $USER_HOME/digibyte-$DGB_VER_LOCAL-backup ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -rf $USER_HOME/digibyte-${DGB_VER_LOCAL}-backup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    
    # Delete DigiByte Core tar.gz file
    str="Deleting DigiByte Core install file: digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz ..."
    printf "%b %s" "${INFO}" "${str}"
    # If this is the alt url download, we need to add a v in the URL
    if [ "$use_dgb_alt_download" == true ]; then
        rm -f $USER_HOME/digibyte-v$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        rm -f $USER_HOME/digibyte-$DGB_VER_GITHUB-$ARCH-linux-gnu.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Update diginode.settings with new DigiByte Core local version number and the install/upgrade date
    DGB_VER_LOCAL=$DGB_VER_GITHUB
    sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    if [ "$DGB_INSTALL_TYPE" = "new" ]; then
        sed -i -e "/^DGB_INSTALL_DATE=/s|.*|DGB_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        sed -i -e "/^DGB_UPGRADE_DATE=/s|.*|DGB_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Update diginode.settings to store whether this is the pre-release version
    if [ "$INSTALL_DGB_RELEASE_TYPE" = "release" ]; then
        DGB_PRERELEASE="NO"
        sed -i -e "/^DGB_PRERELEASE=/s|.*|DGB_PRERELEASE=\"$DGB_PRERELEASE\"|" $DGNT_SETTINGS_FILE
    elif [ "$INSTALL_DGB_RELEASE_TYPE" = "prerelease" ]; then
        DGB_PRERELEASE="YES"
        sed -i -e "/^DGB_PRERELEASE=/s|.*|DGB_PRERELEASE=\"$DGB_PRERELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # Create hidden file to denote this is a pre-release version and add version number to it
    # This file is used to have a local reference of which pre-release version this is since
    # DigiByte Core typically does not know this precisely. This is used as backup for the value in diginode.settings
    # for the rare situations where that file gets deleted,
    if [ ! -f "$DGB_INSTALL_LOCATION/.prerelease" ] && [ "$DGB_PRERELEASE" = "YES" ]; then
        str="Labeling as DigiByte Core pre-release version..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_INSTALL_LOCATION/.prerelease
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

       # Create a new digibyte.conf file
        str="Logging pre-release version number in .prerelease file..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT touch $DGB_CONF_FILE
        cat <<EOF > $DGB_INSTALL_LOCATION/.prerelease
# This file is used to store the local version number of a pre-release version of DigiByte Core.
# Given that DigiByte Core pre-releases typically do not know their precise version number,
# this file is used as a workaround to remember which version is currently installed. 
# Do not delete this file or upgrades will break.

# Example: "8.22.0-rc3"

DGB_VER_LOCAL="$DGB_VER_LOCAL"

EOF
printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Re-enable and re-start digibyted.service after reset/upgrade
    if [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf "%b Upgrade Completed: Re-enabling and re-starting digibyted.service ...\\n" "${INFO}"
        enable_service digibyted
        restart_service digibyted
        DGB_STATUS="running"
        DIGINODE_UPGRADED="YES"
    elif [ "$DGB_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf "%b Reset Completed: Re-enabling and restarting digibyted.service ...\\n" "${INFO}"
        enable_service digibyted
        restart_service digibyted
        DGB_STATUS="running"
    fi

    # Re-enable and re-start digibyted-testnet.service after reset/upgrade
    if [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "upgrade" ]; then
        printf "%b Upgrade Completed: Re-enabling and re-starting digibyted-testnet.service ...\\n" "${INFO}"
        enable_service digibyted-testnet
        restart_service digibyted-testnet
        DGB2_STATUS="running"
        DIGINODE_UPGRADED="YES"
    elif [ "$DGB2_STATUS" = "stopped" ] && [ "$DGB_INSTALL_TYPE" = "reset" ]; then
        printf "%b Reset Completed: Re-enabling and restarting digibyted-testnet.service ...\\n" "${INFO}"
        enable_service digibyted-testnet
        restart_service digibyted-testnet
        DGB2_STATUS="running"
    fi

    # Reset DGB Install and Upgrade Variables
    DGB_INSTALL_TYPE=""
    DGB_UPDATE_AVAILABLE=NO
    DGB_POSTUPDATE_CLEANUP=YES
    INSTALL_DGB_RELEASE_TYPE=""

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


# This function will check if IPFS is installed, and if it is, check if there is an update available

ipfs_check() {

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    printf " =============== Checking: IPFS Kubo ===================================\\n\\n"
    # ==============================================================================

    # Check for latest IPFS Kubo release online
    str="Checking Github for the latest IPFS Kubo release..."
    printf "%b %s" "${INFO}" "${str}"
    # Gets latest IPFS Kubo version, disregarding releases candidates (they contain 'rc' in the name).
    IPFS_VER_RELEASE=$(curl -sfL https://api.github.com/repos/ipfs/kubo/releases/latest | jq -r ".tag_name" | sed 's/v//g')

    # If can't get Github version number
    if [ "$IPFS_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for new version of Kubo. Is the Internet down?.\\n" "${CROSS}"
        printf "\\n"
        printf "%b IPFS Kubo cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"
        IPFS_DO_INSTALL=NO
        IPFS_INSTALL_TYPE="none"
        IPFS_UPDATE_AVAILABLE=NO
        return     
    else
        printf "%b%b %s Found: IPFS Kubo v${IPFS_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^IPFS_VER_RELEASE=/s|.*|IPFS_VER_RELEASE=\"$IPFS_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # WORKAROUND: This is temporary to get around the Kubo release glitch
    if [ "$IPFS_VER_RELEASE" = "0.21.1" ]; then
        IPFS_VER_RELEASE="0.22.0"
        printf "%b Temporary Workaround for IPFS Kubo release glitch - switching v0.21.1 to v0.22.0\\n" "${WARN}"
    fi

    # Get the local version number of IPFS Kubo (this will also tell us if it is installed)
    IPFS_VER_LOCAL=$(ipfs --version 2>/dev/null | cut -d' ' -f3)

    # Let's check if Kubo is already installed
    str="Is IPFS Kubo already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$IPFS_VER_LOCAL" = "" ]; then
        IPFS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        IPFS_VER_LOCAL=""
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        IPFS_STATUS="installed"
        sed -i -e "/^IPFS_VER_LOCAL=/s|.*|IPFS_VER_LOCAL=\"$IPFS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: IPFS Kubo v${IPFS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Next let's check if IPFS daemon is running with upstart
    if [ "$IPFS_STATUS" = "installed" ] && [ "$INIT_SYSTEM" = "upstart" ]; then
      str="Is IPFS Kubo daemon upstart service running?..."
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
        str="Is IPFS Kubo daemon systemd service running?..."
        printf "%b %s" "${INFO}" "${str}"

        # Check if it is running or not #CHECKLATER
        systemctl is-active --quiet ipfs && IPFS_STATUS="running" || IPFS_STATUS="stopped"

        if [ "$IPFS_STATUS" = "running" ]; then
          printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$IPFS_STATUS" = "stopped" ]; then
          printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi

    # Lookup the current IPFS Kubo ports
    if test -f "$USER_HOME/.ipfs/config"; then
        printf "%b Retrieving current port numbers for IPFS Kubo...\\n" "${INFO}"

        str="IPFS Kubo IP4 Port:"
        printf "  %b %s" "${INFO}" "${str}"
        IPFS_PORT_IP4=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[0] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $IPFS_PORT_IP4\\n" "${OVER}" "${INFO}" "${str}"
        
        str="IPFS Kubo IP6 Port:"
        printf "  %b %s" "${INFO}" "${str}"
        IPFS_PORT_IP6=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[1] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $IPFS_PORT_IP6\\n" "${OVER}" "${INFO}" "${str}"

        str="IPFS Kubo IP4 Quic Port:"
        printf "  %b %s" "${INFO}" "${str}"
        IPFS_PORT_IP4_QUIC=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[2] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $IPFS_PORT_IP4_QUIC\\n" "${OVER}" "${INFO}" "${str}"
        
        str="IPFS Kubo IP6 Quic Port:"
        printf "  %b %s" "${INFO}" "${str}"
        IPFS_PORT_IP6_QUIC=$(cat $USER_HOME/.ipfs/config | jq .Addresses.Swarm[3] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $IPFS_PORT_IP6_QUIC\\n" "${OVER}" "${INFO}" "${str}"

    fi

    # Lookup the current JS-IPFS ports
    if test -f "$USER_HOME/.jsipfs/config"; then
        printf "%b Retrieving current port numbers for JS-IPFS...\\n" "${INFO}"

        str="JS-IPFS IP4 Port:"
        printf "  %b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP4=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[0] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $JSIPFS_PORT_IP4\\n" "${OVER}" "${INFO}" "${str}"
        
        str="JS-IPFS IP6 Port:"
        printf "  %b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP6=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[1] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $JSIPFS_PORT_IP6\\n" "${OVER}" "${INFO}" "${str}"

        str="JS-IPFS IP4 Quic Port:"
        printf "  %b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP4_QUIC=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[2] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $JSIPFS_PORT_IP4_QUIC\\n" "${OVER}" "${INFO}" "${str}"
        
        str="JS-IPFS IP6 Quic Port:"
        printf "  %b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP6_QUIC=$(cat $USER_HOME/.jsipfs/config | jq .Addresses.Swarm[3] | sed 's/"//g' | cut -d'/' -f5)
        printf "  %b%b %s $JSIPFS_PORT_IP6_QUIC\\n" "${OVER}" "${INFO}" "${str}"

    fi


    # If a IPFS Kubo local version already exists.... (i.e. we have a local version number)
    if [ ! $IPFS_VER_LOCAL = "" ]; then
      # ....then check if an upgrade is required
      if [ $(version $IPFS_VER_LOCAL) -ge $(version $IPFS_VER_RELEASE) ]; then
          printf "%b IPFS Kubo is already up to date.\\n" "${TICK}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to reinstall IPFS Kubo v${IPFS_VER_RELEASE}.\\n" "${INFO}"
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
          printf "%b %bIPFS Kubo can be upgraded from v${IPFS_VER_LOCAL} to v${IPFS_VER_RELEASE}.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          IPFS_INSTALL_TYPE="upgrade"
          IPFS_ASK_UPGRADE=YES
      fi
    fi 


    # If no current version is installed, then do a clean install
    if [ "$IPFS_STATUS" = "not_detected" ]; then
      printf "%b %bIPFS Kubo v${IPFS_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      IPFS_INSTALL_TYPE="new"
      IPFS_DO_INSTALL="if_doing_full_install"
    fi

    printf "\\n"

fi

}

# This function will install IPFS Kubo if it not yet installed, and if it is, upgrade it to the latest release
ipfs_do_install() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
    IPFS_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to reinstall IPFS
if [ "$IPFS_INSTALL_TYPE" = "askreset" ]; then

    if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --title "Reset Mode" --yesno "\n\Z4Do you want to re-install IPFS Kubo v${IPFS_VER_RELEASE}?\Z0\n\nNote: IPFS Kubo is used by the DigiAsset Node to distribute DigiAsset metadata." 10 "${c}"; then
        IPFS_DO_INSTALL=YES
        IPFS_INSTALL_TYPE="reset"
    else        
        printf " =============== Reset: IPFS Kubo ==================================\\n\\n"
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
        printf " =============== Install: IPFS Kubo ====================================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_INSTALL_TYPE" = "upgrade" ]; then
        printf " =============== Upgrade: IPFS Kubo ====================================\\n\\n"
        # ==============================================================================
    elif [ "$IPFS_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: IPFS Kubo ======================================\\n\\n"
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
        str="Reset Mode: Deleting IPFS Kubo v${IPFS_VER_LOCAL} ..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f /usr/local/bin/ipfs
        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"

        # Delete IPFS settings
        if [ -d "$USER_HOME/.ipfs" ]; then
            if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --title "Reset Mode" --yesno "\n\Z4Would you like to reset your IPFS settings folder?\Z0\n\nThis will delete the folder: ~/.ipfs" 9 "${c}"; then
                str="Reset Mode: Deleting ~/.ipfs settings folder..."
                printf "%b %s" "${INFO}" "${str}"
                rm -rf $USER_HOME/.ipfs
                printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b Reset Mode: You chose not to reset the IPFS settings folder (~/.ipfs).\\n" "${INFO}"
            fi
        fi
    fi

    # If there is an existing go-IPFS install tar file, delete it [Legacy code - can be removed at some point]
    if [ -f "$USER_HOME/go-ipfs_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz" ]; then
        str="Deleting existing Go-IPFS install file: go-ipfs_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/go-ipfs_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If there is an existing IPFS Kubo install tar file, delete it
    if [ -f "$USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz" ]; then
        str="Deleting existing IPFS Kubo install file: kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Downloading latest IPFS Kubo install file from GitHub
    str="Downloading IPFS Kubo v${IPFS_VER_RELEASE} from Github repository..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT wget -q https://github.com/ipfs/kubo/releases/download/v${IPFS_VER_RELEASE}/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz -P $USER_HOME


    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "%b%b %s Failed!\\n" "${OVER}" "${CROSS}" "${str}"
        printf "\\n"
        printf "%b%b ${txtbred}ERROR: IPFS Kubo v${IPFS_VER_RELEASE} Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b IPFS Kubo could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
        if [ "$IPFS_STATUS" = "stopped" ]; then
            printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so that a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
            printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
            printf "%b For now the existing version will be restarted.\\n\\n" "${INDENT}"
        else
            printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so that a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
            printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
            printf "%b DigiAsset Node installation will be skipped for now.\\n\\n" "${INDENT}"
        fi

        if [ "$INIT_SYSTEM" = "systemd" ] && [ "$IPFS_STATUS" = "stopped" ]; then

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

        if [ "$INIT_SYSTEM" = "upstart" ] && [ "$IPFS_STATUS" = "stopped" ]; then

            # Enable the service to run at boot
            str="Re-starting IPFS upstart service..."
            printf "%b %s" "${INFO}" "${str}"
            service ipfs start
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            IPFS_STATUS="running"

        fi

        printf "\\n"
        INSTALL_ERROR="YES"
        SKIP_DGA_INSTALLATION="YES"
        return 1
    fi

    # If there is an existing Go-IPFS install folder, delete it
    if [ -d "$USER_HOME/go-ipfs" ]; then
        str="Deleting existing ~/go-ipfs folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r $USER_HOME/go-ipfs
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If there is an existing IPFS Kubo install folder, delete it
    if [ -d "$USER_HOME/kubo" ]; then
        str="Deleting existing ~/kubo folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r $USER_HOME/kubo
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Extracting IPFS Kubo install files
    str="Extracting IPFS Kubo v${IPFS_VER_RELEASE} ..."
    printf "%b %s" "${INFO}" "${str}"
    sudo -u $USER_ACCOUNT tar -xf $USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz -C $USER_HOME
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # Delete Kubo install tar file, delete it
    if [ -f "$USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz" ]; then
        str="Deleting IPFS Kubo install file: kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz..."
        printf "%b %s" "${INFO}" "${str}"
        rm $USER_HOME/kubo_v${IPFS_VER_RELEASE}_linux-${ipfsarch}.tar.gz
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Install Kubo to bin folder
    printf "%b Installing IPFS Kubo v${IPFS_VER_RELEASE} ...\\n" "${INFO}"
    (cd $USER_HOME/kubo; ./install.sh)

    # If the command completed without error, then assume IPFS installed correctly
    if [ $? -eq 0 ]; then
        printf "%b IPFS Kubo appears to have been installed correctly.\\n" "${INFO}"
        
        if [ "$IPFS_STATUS" = "not_detected" ];then
            IPFS_STATUS="installed"
        fi
        DIGINODE_UPGRADED="YES"
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: IPFS Kubo Installation Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
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


    # Set default IPFS ports if this is the first time running IPFS Kubo, and the config files do not exist
    if [ ! -f "$USER_HOME/.ipfs/config" ]; then
        str="IPFS Kubo config file does not exist. Storing default ports in variables..."
        printf "%b %s" "${INFO}" "${str}"
        IPFS_PORT_IP4="4001"
        IPFS_PORT_IP6="4001"
        IPFS_PORT_IP4_QUIC="4001"
        IPFS_PORT_IP6_QUIC="4001"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ ! -f "$USER_HOME/.jsipfs/config" ]; then
        str="JS-IPFS config file does not exist. Storing default ports in variables..."
        printf "%b %s" "${INFO}" "${str}"
        JSIPFS_PORT_IP4="4001"
        JSIPFS_PORT_IP6="4001"
        JSIPFS_PORT_IP4_QUIC="4001"
        JSIPFS_PORT_IP6_QUIC="4001"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
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
            if dialog --no-shadow --keep-tite --colors --backtitle "Use IPFS Server Profile?" --defaultno --title "Use IPFS Server Profile?" --yesno "\n\Z4Do you want to use the IPFS server profile?\Z0\n\nThe server profile disables local host discovery, and is recommended when running IPFS on machines with a public IPv4 address, such as on a cloud VPS.\n\nChoose NO if you are running your DigiNode on a device on your local network.\n\nChoose YES if you are running your DigiNode in the cloud i.e. on a device with its own public IP.\\n\\nLearn more:\nhttps://medium.com/textileio/tutorial-setting-up-an-ipfs-peer-part-iv-1595d4ba221b" 21 "${c}"; then 
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
#            if [ "$IS_RPI" = "YES" ]; then
#                printf "%b Raspberry Pi Detected! Initializing IPFS daemon with the lowpower profile.\\n" "${INFO}"
#                sudo -u $USER_ACCOUNT ipfs init --profile=lowpower
#            else
                # Just in case we are are DigiAsset Node Mode ONLY and we never performed the Pi checks
                # Look for any mention of 'Raspberry Pi' so we at least know it is a Pi 
#                pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi" || echo "")
#                if [[ $pigen == "Raspberry Pi" ]]; then
#                    IS_RPI="YES"
#                fi
#                if [ "$IS_RPI" = "YES" ]; then
#                    printf "%b We are in DigiAsset Mode ONLY.\\n" "${INFO}"
#                    printf "%b Raspberry Pi Detected! Initializing IPFS daemon with the lowpower profile.\\n" "${INFO}"
#                    sudo -u $USER_ACCOUNT ipfs init --profile=lowpower
#                else
                    sudo -u $USER_ACCOUNT ipfs init
#                fi
#            fi

        fi

        # Test IPFS
#        sudo -u $USER_ACCOUNT ipfs cat /ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG/readme
        
        printf "\\n"
    fi

    # Set the upnp values, if we are enabling/disabling the UPnP status
    if [ "$IPFS_ENABLE_UPNP" = "YES" ]; then
        str="Enabling UPnP port forwarding for IPFS Kubo..."
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
        str="Disabling UPnP port forwarding for IPFS Kubo..."
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

    # If we are using IPFS Kubo

        printf "\\n"
        printf " =============== Starting: IPFS ========================================\\n\\n"
        # ==============================================================================

#        if [ "$VERBOSE_MODE" = true ]; then
#            printf "%b Verbose Mode: DGB_NETWORK_FINAL - $DGB_NETWORK_FINAL\\n" "${INFO}"
#            printf "%b Verbose Mode: IPFS_PORT_IP4 - $IPFS_PORT_IP4\\n" "${INFO}"
#            printf "%b Verbose Mode: IPFS_PORT_IP6 - $IPFS_PORT_IP6\\n" "${INFO}"
#            printf "%b Verbose Mode: IPFS_PORT_IP4_QUIC - $IPFS_PORT_IP4_QUIC\\n" "${INFO}"
#            printf "%b Verbose Mode: IPFS_PORT_IP6_QUIC - $IPFS_PORT_IP6_QUIC\\n" "${INFO}"
#            printf "\\n"
#        fi

    if [ -f "$USER_HOME/.ipfs/config" ]; then

        # If using DigiByte testnet, change default IPFS Kubo port to 4004

        local update_ipfsport_now

        printf "%b Checking IPFS Kubo ports...\\n" "${INFO}"

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP4" = "4001" ]]; then
            printf "%b Using DigiByte testnet. Updating Kobo IPFS ports...\\n" "${INFO}"
            str="Changing IPFS Kubo IP4 port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4004\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP4="4004"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP6" = "4001" ]]; then
            str="Changing IPFS Kubo IP6 port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4004\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP6="4004"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP4_QUIC" = "4001" ]]; then
            str="Changing IPFS Kubo IP4 quic port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4004/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP4_QUIC="4004"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$IPFS_PORT_IP6_QUIC" = "4001" ]]; then
            str="Changing IPFS Kubo IP6 quic port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4004/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP6_QUIC="4004"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If using DigiByte mainnet, change default IPFS Kubo port to 4001

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP4" = "4004" ]]; then
            printf "%b Using DigiByte mainnet. Updating Kobo IPFS ports...\\n" "${INFO}"
            str="Changing IPFS Kubo IP4 port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4001\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP4="4001"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP6" = "4004" ]]; then
            str="Changing IPFS Kubo IP6 port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4001\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP6="4001"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP4_QUIC" = "4004" ]]; then
            str="Changing IPFS Kubo IP4 quic port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4001/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP4_QUIC="4001"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$IPFS_PORT_IP6_QUIC" = "4004" ]]; then
            str="Changing IPFS Kubo IP6 quic port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4001/quic\"" $USER_HOME/.ipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.ipfs/config
            kuboipfs_port_has_changed="yes"
            IPFS_PORT_IP6_QUIC="4001"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi

    # If we are using JS-IPFS

    if [ -f "$USER_HOME/.jsipfs/config" ]; then

        # If using DigiByte testnet, change default JS-IPFS port to 4004

        printf "%b Checking JS-IPFS ports...\\n" "${INFO}"

        local update_ipfsport_now

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP4" = "4001" ]]; then
            printf "%b Using DigiByte testnet. Updating JS-IPFS ports...\\n" "${INFO}"
            str="Changing JS-IPFS IP4 port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4004\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP6" = "4001" ]]; then
            str="Changing JS-IPFS IP6 port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4004\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP4_QUIC" = "4001" ]]; then
            str="Changing JS-IPFS IP4 quic port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4004/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "TESTNET" ]] && [[ "$JSIPFS_PORT_IP6_QUIC" = "4001" ]]; then
            str="Changing JS-IPFS IP6 quic port from 4001 to 4004..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4004/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If using DigiByte mainnet, change default JS-IPFS port to 4001

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP4" = "4004" ]]; then
            printf "%b Using DigiByte mainnet. Updating JS-IPFS ports...\\n" "${INFO}"
            str="Changing JS-IPFS IP4 port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[0] = \"/ip4/0.0.0.0/tcp/4001\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP6" = "4004" ]]; then
            str="Changing JS-IPFS IP6 port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[1] = \"/ip6/::/tcp/4001\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP4_QUIC" = "4004" ]]; then
            str="Changing JS-IPFS IP4 quic port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[2] = \"/ip4/0.0.0.0/udp/4001/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        if [[ "$DGB_NETWORK_FINAL" = "MAINNET" ]] && [[ "$JSIPFS_PORT_IP6_QUIC" = "4004" ]]; then
            str="Changing JS-IPFS IP6 quic port from 4004 to 4001..."
            printf "  %b %s" "${INFO}" "${str}"
            update_ipfsport_now="$(jq ".Addresses.Swarm[3] = \"/ip6/::/udp/4001/quic\"" $USER_HOME/.jsipfs/config)" && \
            echo -E "${update_ipfsport_now}" > $USER_HOME/.jsipfs/config
            jsipfs_port_has_changed="yes"
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

    fi

}


# Create service so that IPFS will run at boot
ipfs_create_service() {

# If you want to make changes to how IPFS services are created/managed for different systems, refer to this website:
# https://github.com/ipfs/kobo/tree/master/misc 


# If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
if [ "$RESET_MODE" = true ]; then

    # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
    if [ test -f "$IPFS_SYSTEMD_SERVICE_FILE" ] || [ test -f "$IPFS_UPSTART_SERVICE_FILE" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --defaultno --title "Reset Mode" --yesno "\n\Z4Do you want to re-configure the IPFS service?\Z0\n\nThe IPFS service ensures that your IPFS daemon starts automatically at boot, and stays running 24/7. This will delete your existing IPFS service file and recreate it." 11 "${c}"; then 
            IPFS_CREATE_SERVICE=YES
            IPFS_SERVICE_INSTALL_TYPE="reset"
        else
            printf " =============== Reset: IPFS Daemon Service ========================\\n\\n"
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
        printf "%b For help, please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so that a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
        exit 1

    fi

    printf "\\n"

fi

}



# This function will check if Node.js is installed, and if it is, check if there is an update available
# LAtest distrbutions can be checked here: https://github.com/nodesource/distributions 

nodejs_check() {

if [ "$DO_FULL_INSTALL" = "YES" ]; then

    printf " =============== Checking: Node.js =====================================\\n\\n"
    # ==============================================================================

    # Get the local version number of Node.js (this will also tell us if it is installed)
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')

    # Later versions use purely the 'node --version' command, (rather than Node.js)
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
    fi

    # Let's check if Node.js is already installed
    str="Is Node.js already installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_STATUS="not_detected"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        NODEJS_STATUS="installed"
        sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s YES!   Found: Node.js v${NODEJS_VER_LOCAL}\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Get current Node.js major version
    str="Is Node.js at least version 16?..."
    NODEJS_VER_LOCAL_MAJOR=$(echo $NODEJS_VER_LOCAL | cut -d'.' -f 1)
    if [ "$NODEJS_VER_LOCAL_MAJOR" != "" ]; then
        printf "%b %s" "${INFO}" "${str}"
        if [ "$NODEJS_VER_LOCAL_MAJOR" -lt "16" ]; then
            NODEJS_REPO_ADDED="NO"
            printf "%b%b %s NO! NodeSource repo will be re-added.\\n" "${OVER}" "${CROSS}" "${str}"
        else
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi

    # If this is the first time running the Node.js check, and we are doing a full install, let's add 
    # the new official repositories to ensure we get the latest version
    if [ "$NODEJS_REPO_ADDED" = "" ] || [ "$NODEJS_REPO_ADDED" = "NO" ]; then

        # Get version codename
        LINUX_ID=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
        LINUX_VERSION_CODENAME=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)
        printf "%b Linux ID: $LINUX_ID\\n" "${INFO}"
        printf "%b Linux Version Codename: $LINUX_VERSION_CODENAME\\n" "${INFO}"

        # Deleting deb repository
        if [ -f /etc/apt/sources.list.d/nodesource.list ]; then 
            str="Preparing Node.js repository: Deleting old repo..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f /etc/apt/sources.list.d/nodesource.list
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Deleting gpg key
        if [ -f /etc/apt/keyrings/nodesource.gpg ]; then 
            str="Preparing Node.js repository: Deleting old GPG key..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f /etc/apt/keyrings/nodesource.gpg
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Set correct Node.js 20 repository for Debian or Ubuntu
        if [ "$LINUX_ID" = "ubuntu" ] || [ "$LINUX_ID" = "debian" ]; then

            # create /etc/apt/keyrings folder if it does not already exist
            if [ ! -d /etc/apt/keyrings ]; then #
                str="Preparing Node.js repository: Creating /etc/apt/keyrings folder..."
                printf "%b %s" "${INFO}" "${str}"
                mkdir -p /etc/apt/keyrings
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # install gpg key
            if [ ! -f /etc/apt/keyrings/nodesource.gpg ]; then 
                str="Preparing Node.js repository: Installing GPG key..."
                printf "%b %s" "${INFO}" "${str}"
                sudo -u $USER_ACCOUNT curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Figure out which version of Node.js to install
            if [ "$LINUX_VERSION_CODENAME" = "jessie" ] || [ "$LINUX_VERSION_CODENAME" = "stretch" ] || [ "$LINUX_VERSION_CODENAME" = "bionic" ]; then
                NODE_MAJOR=16
            else
                # At the moment the DigiAsset Node won't work with any version later than 16 but this may change in future. This could later be changed to 18, 20 or later.
                NODE_MAJOR=16
            fi
            printf "%b Node.js ${NODE_MAJOR} will be used.\\n" "${INFO}"

            # Create deb repository
            if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then 
                printf "%b Preparing Node.js repository: Creating repo for Debian/Ubuntu...\\n" "${INFO}"
                sudo -u $USER_ACCOUNT echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
                NODEJS_REPO_ADDED=YES
            fi

            # Update package cache
            update_package_cache

        else

            # Setup Node.js repositories for Enterprise Linux - Fedora, Redhat
            str="Preparing Node.js repository: Creating repo for Enterprise Linux..."
            printf "%b %s" "${INFO}" "${str}"
            yum install https://rpm.nodesource.com/pub_20.x/nodistro/repo/nodesource-release-nodistro-1.noarch.rpm -y
            NODEJS_REPO_ADDED=YES
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Update variable in diginode.settings so this does not run again
        sed -i -e "/^NODEJS_REPO_ADDED=/s|.*|NODEJS_REPO_ADDED=\"$NODEJS_REPO_ADDED\"|" $DGNT_SETTINGS_FILE

    else
        printf "%b NodeSource repository has already been added or is not required.\\n" "${TICK}"
        printf "%b If needed, you can have this script attempt to add it, by editing the diginode.settings\\n" "${INDENT}"
        printf "%b file in the ~/.digibyte folder and changing the NODEJS_REPO_ADDED value to NO. \\n" "${INDENT}"
    fi

    # Look up the latest candidate release
    str="Checking for the latest Node.js release..."
    printf "%b %s" "${INFO}" "${str}"

    if [ "$PKG_MANAGER" = "apt-get" ]; then
        # Gets latest Node.js release version, disregarding releases candidates (they contain 'rc' in the name).
        NODEJS_VER_RELEASE=$(apt-cache policy nodejs | grep Candidate | cut -d' ' -f4 | cut -d'-' -f1 | cut -d'~' -f1)
    fi

    if [ "$PKG_MANAGER" = "dnf" ]; then
        # Gets latest Node.js release version, disregarding releases candidates (they contain 'rc' in the name).
        printf "%b ERROR: DigiNode Setup is not yet able to check for Node.js releases with dnf.\\n" "${CROSS}"
        printf "\\n"
        printf "%b Please get in touch via the DigiNode Tools Telegram group: $SOCIAL_TELEGRAM_URL\\n" "${INFO}"
        printf "%b You may be able to help me to add support for this. Olly\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    if [ "$PKG_MANAGER" = "yum" ]; then
        # Gets latest Node.js release version, disregarding releases candidates (they contain 'rc' in the name).
        printf "%b ERROR: DigiNode Setup is not yet able to check for Node.js releases with yum.\\n" "${CROSS}"
        printf "\\n"
        printf "%b Please get in touch via the DigiNode Tools Telegram group: $SOCIAL_TELEGRAM_URL\\n" "${INFO}"
        printf "%b You may be able to help me to add support for this. Olly\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    if [ "$NODEJS_VER_RELEASE" = "" ]; then
        printf "%b%b %s ${txtred}ERROR${txtrst}\\n" "${OVER}" "${CROSS}" "${str}"
        printf "%b Unable to check for release version of Node.js.\\n" "${CROSS}"
        printf "\\n"
        printf "%b Node.js cannot be upgraded at this time. Skipping...\\n" "${INFO}"
        printf "\\n"
        NODEJS_DO_INSTALL=NO
        NODEJS_INSTALL_TYPE="none"
        NODEJS_UPDATE_AVAILABLE=NO
        return
    else
        printf "%b%b %s Found: v${NODEJS_VER_RELEASE}\\n" "${OVER}" "${TICK}" "${str}"
        sed -i -e "/^NODEJS_VER_RELEASE=/s|.*|NODEJS_VER_RELEASE=\"$NODEJS_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
    fi

    # If a Node.js local version already exists.... (i.e. we have a local version number)
    if [ "$NODEJS_VER_LOCAL" != "" ]; then
      # ....then check if an upgrade is required
      if [ $(version $NODEJS_VER_LOCAL) -ge $(version $NODEJS_VER_RELEASE) ]; then
          printf "%b Node.js is already up to date.\\n" "${TICK}"
          if [ "$RESET_MODE" = true ]; then
            printf "%b Reset Mode is Enabled. You will be asked if you want to re-install Node.js v${NODEJS_VER_RELEASE}.\\n" "${INFO}"
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
          printf "%b %bNode.js can be upgraded from v${NODEJS_VER_LOCAL} to v${NODEJS_VER_RELEASE}%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
      printf "%b %bNode.js v${NODEJS_VER_RELEASE} will be installed.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      NODEJS_INSTALL_TYPE="new"
      NODEJS_DO_INSTALL="if_doing_full_install"
    fi

    printf "\\n"

fi

}

# This function will install Node.js if it not yet installed, and if it is, upgrade it to the latest release
nodejs_do_install() {

# If we are in unattended mode and an upgrade has been requested, do the install
if [ "$UNATTENDED_MODE" == true ] && [ "$NODEJS_ASK_UPGRADE" = "YES" ]; then
    NODEJS_DO_INSTALL=YES
fi

# If we are in reset mode, ask the user if they want to re-install Node.js
if [ "$NODEJS_INSTALL_TYPE" = "askreset" ]; then

    if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --defaultno --title "Reset Mode" --yesno "\nDo you want to re-install Node.js v${NODEJS_VER_RELEASE}\n\nNote: This will delete Node.js and re-install it." 9 "${c}"; then 
        NODEJS_DO_INSTALL=YES
        NODEJS_INSTALL_TYPE="reset"
    else
        printf " =============== Reset: Node.js ====================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You skipped re-installing Node.js.\\n" "${INFO}"
        printf "\\n"
        NODEJS_DO_INSTALL=NO
        NODEJS_INSTALL_TYPE="none"
        NODEJS_UPDATE_AVAILABLE=NO
        return
    fi

fi

# If this is a new install of Node.js, and the user has opted to do a full DigiNode install, then proceed, If the user is doing a full install, and this is a new install, then proceed
if  [ "$NODEJS_INSTALL_TYPE" = "new" ] && [ "$NODEJS_DO_INSTALL" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    NODEJS_DO_INSTALL=YES
fi

if [ "$NODEJS_DO_INSTALL" = "YES" ]; then

    # Display section break
    printf "\\n"
    if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
        printf " =============== Install: Node.js ======================================\\n\\n"
        # ==============================================================================
    elif [ "$NODEJS_INSTALL_TYPE" = "majorupgrade" ] || [ $NODEJS_INSTALL_TYPE = "upgrade" ]; then
        printf " =============== Upgrade: Node.js ======================================\\n\\n"
        # ==============================================================================
    elif [ "$NODEJS_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: Node.js ========================================\\n\\n"
        # ==============================================================================
        printf "%b Reset Mode: You chose re-install Node.js.\\n" "${INFO}"
    fi


    # Do apt-get installation of Node.js
    if [ "$PKG_MANAGER" = "apt-get" ]; then

        # Install Node.js if it does not exist
        if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
            printf "%b Installing Node.js v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            printf "\\n"
        fi

        # If Node.js 14 exists, upgrade it
        if [ "$NODEJS_INSTALL_TYPE" = "upgrade" ]; then
            printf "%b Updating to Node.js v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

        # If Node.js exists, but needs a major upgrade, remove the old versions first as there can be conflicts
        if [ "$NODEJS_INSTALL_TYPE" = "majorupgrade" ]; then
            printf "%b Since this is a major upgrade, the old versions of Node.js will be removed first, to ensure there are no conflicts.\\n" "${INFO}"
            printf "%b Purging old versions of Node.js v${NODEJS_VER_LOCAL} ...\\n" "${INFO}"
            sudo apt-get purge nodejs-legacy nodejs -y -q
            sudo apt-get autoremove -y -q
            printf "\\n"
            printf "%b Installing Node.js v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

        # If we are in Reset Mode, remove and re-install
        if [ "$NODEJS_INSTALL_TYPE" = "reset" ]; then
            printf "%b Reset Mode is ENABLED. Removing Node.js v${NODEJS_VER_RELEASE} with apt-get...\\n" "${INFO}"
            sudo apt-get purge nodejs-legacy nodejs -y -q
            sudo apt-get autoremove -y -q
            printf "\\n"
            printf "%b Re-installing Node.js v${NODEJS_VER_RELEASE} ...\\n" "${INFO}"
            sudo apt-get install nodejs -y -q
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

    fi

    # Do yum installation of Node.js
    if [ "$PKG_MANAGER" = "yum" ]; then
            # Install Node.js if it does not exist
        if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
            printf "%b Installing Node.js v${NODEJS_VER_RELEASE} with yum..\\n" "${INFO}"
            sudo yum install nodejs -y --setopt=nodesource-nodejs.module_hotfixes=1
            DIGINODE_UPGRADED="YES"
            printf "\\n"
        fi

    fi

    # Do dnf installation of Node.js
    if [ "$PKG_MANAGER" = "dnf" ]; then
        # Install Node.js if it does not exist
        if [ "$NODEJS_INSTALL_TYPE" = "new" ]; then
            printf "%b Installing Node.js v${NODEJS_VER_RELEASE} with dnf..\\n" "${INFO}"
            dnf module install nodejs:12
            printf "\\n"
            DIGINODE_UPGRADED="YES"
        fi

    fi


    # Get the new version number of the Node.js install
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')

    # Later versions use purely the 'node --version' command, (rather than Node.js)
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
    fi

    # Update diginode.settings with new Node.js local version number and the install/upgrade date
    sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    if [ "$NODEJS_INSTALL_TYPE" = "new" ] || [ "$NODEJS_INSTALL_TYPE" = "reset" ]; then
        NODEJS_INSTALL_DATE="$(date)"
        sed -i -e "/^NODEJS_INSTALL_DATE=/s|.*|NODEJS_INSTALL_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    elif [ "$NODEJS_INSTALL_TYPE" = "upgrade" ] || [ "$NODEJS_INSTALL_TYPE" = "majorupgrade" ]; then
        NODEJS_UPGRADE_DATE="$(date)"
        sed -i -e "/^NODEJS_UPGRADE_DATE=/s|.*|NODEJS_UPGRADE_DATE=\"$(date)\"|" $DGNT_SETTINGS_FILE
    fi

    # Reset Node.js Install and Upgrade Variables
    NODEJS_INSTALL_TYPE=""
    NODEJS_UPDATE_AVAILABLE=NO
    NODEJS_POSTUPDATE_CLEANUP=YES

    printf "\\n"

fi

# If there is no install date (i.e. Node.js was already installed when this script was first run) add it now, since it was up-to-date at this time
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

# If there was an error installing Kubo, skip installation
if  [ "$SKIP_DGA_INSTALLATION" = "YES" ]; then
    DGA_DO_INSTALL=NO
    DGA_INSTALL_TYPE="none"
    return 
fi

# If we are in reset mode, ask the user if they want to reinstall DigiAsset Node
if [ "$DGA_INSTALL_TYPE" = "askreset" ]; then

    if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --defaultno --title "Reset Mode" --yesno "\n\Z4Do you want to re-install DigiAsset Node v${DGA_VER_RELEASE}?\Z0\n\nNote: This will delete your current DigiAsset Node folder at $DGA_INSTALL_LOCATION and re-install it. Your DigiAsset settings folder at ~/digiasset_node/_config will be kept." 11 "${c}"; then
        DGA_DO_INSTALL=YES
        DGA_INSTALL_TYPE="reset"
    else
        printf " =============== Reset: DigiAsset Node =============================\\n\\n"
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

    # Get the local version number of Node.js (this will also tell us if it is installed)
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')

    # Later versions use purely the 'node --version' command, (rather than Node.js)
    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_VER_LOCAL=$(node -v 2>/dev/null | sed 's/v//g')
    fi

    # Get current Node.js major version
    str="Is Node.js installed and at least version 16?..."
    NODEJS_VER_LOCAL_MAJOR=$(echo $NODEJS_VER_LOCAL | cut -d'.' -f 1)
    if [ "$NODEJS_VER_LOCAL_MAJOR" != "" ]; then
        printf "%b %s" "${INFO}" "${str}"
        if [ "$NODEJS_VER_LOCAL_MAJOR" -lt "16" ]; then
            printf "\\n"
            printf "%b%b ${txtred}ERROR: Node.js 16.x or greater is required to run a DigiAsset Node!${txtrst}\\n" "${OVER}" "${CROSS}"
            printf "\\n"
            printf "%b You need to install the correct Nodesource PPA for your distro.\\n" "${INFO}"
            printf "%b Please get in touch via the 'DigiNode Tools' Telegram group so a fix can be made for your distro.\\n" "${INDENT}"
            printf "\\n"
            exit 1
        else
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: Node.js is not installed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b You need to install Node.js. It should have been installed before this, but there was likely an error.\\n" "${INFO}"
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

    # If there was an error installing Kubo, skip installation
    if  [ "$SKIP_DGA_INSTALLATION" = "YES" ]; then
        DGA_SETTINGS_CREATE=NO
        DGA_SETTINGS_CREATE_TYPE="none"
        return
    fi

    local str

    # If we are in reset mode, ask the user if they want to recreate the entire DigiAssets settings folder if it already exists
    if [ "$RESET_MODE" = true ] && [ -f "$DGA_SETTINGS_FILE" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --defaultno --title "Reset Mode" --yesno "\n\Z4Do you want to reset your DigiAsset Node settings?\Z0\n\nThis will delete your current DigiAsset Node settings located in ~/digiasset_node/_config and then recreate them with the default settings." 11 "${c}"; then
            DGA_SETTINGS_CREATE=YES
            DGA_SETTINGS_CREATE_TYPE="reset"
        else
            printf " =============== Reset: DigiAsset Node settings ====================\\n\\n"
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
    elif [ "$RESET_MODE" != true ]; then
        printf " =============== Checking: DigiByte RPC credentials ====================\\n\\n"
        # ==============================================================================
    fi

    # Let's get the latest RPC credentials from digibyte.conf if it exists
    if [ -f $DGB_CONF_FILE ]; then
        if [ -f $DGA_SETTINGS_FILE ] || [ -f $DGA_SETTINGS_BACKUP_FILE ]; then
            printf "%b Getting latest RPC credentials from digibyte.conf\\n" "${INFO}"
        fi
 
        # Import variables from global section of digibyte.conf
        str="Located digibyte.conf file. Importing..."
        printf "%b %s" "${INFO}" "${str}"
        scrape_digibyte_conf
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Find out the current  DGB network chain
        str="Checking current DigiByte chain..."
        printf "%b %s" "${INFO}" "${str}"

        # Query if DigiByte Core is running the mainnet, testnet or regtest chain
        query_digibyte_chain

        if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
            printf "%b%b %s TESTNET (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
            printf "%b%b %s REGTEST (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
            printf "%b%b %s MAINNET (live)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
            printf "%b%b %s TESTNET (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
            printf "%b%b %s REGTEST (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
            printf "%b%b %s MAINNET (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Import variables from global section of digibyte.conf
        str="Querying RPC credentials..."
        printf "%b %s" "${INFO}" "${str}"
        query_digibyte_rpc
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Setting RPC variables
        rpcuser=$RPC_USER
        rpcpassword=$RPC_PASSWORD
        rpcport=$RPC_PORT

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

    # Display discovered RPC credentials from digibyte.conf
    if [ "$VERBOSE_MODE" = true ]; then
        printf "%b Verbose Mode: RPC User - $rpcuser\\n" "${INFO}"
        printf "%b Verbose Mode: RPC Pass - $rpcpassword\\n" "${INFO}"
        printf "%b Verbose Mode: RPC Port - $rpcport\\n" "${INFO}"
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

    # If live main.json file already exists, and we are not doing a reset, let's check if the IPFS Kubo URL needs adding
    if [ -f $DGA_SETTINGS_FILE ] && [ "$DGA_SETTINGS_CREATE_TYPE" != "reset" ]; then

        str="Checking if IPFS Kubo API URL needs updating..."
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

    # If backup main.json file already exists, and we are not doing a reset, let's check if the IPFS Kubo URL needs adding
    if [ -f $DGA_SETTINGS_BACKUP_FILE ] && [ "$DGA_SETTINGS_CREATE_TYPE" != "reset" ]; then

        str="Checking if IPFS Kubo API URL needs updating..."
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
            printf " =============== Create: DigiAsset Node settings =====================\\n\\n"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "update" ]; then
            # ==============================================================================
            printf " =============== Update: DigiAsset Node settings =====================\\n\\n"
            printf "%b RPC credentials in digibyte.conf have changed. The main.json file will be updated.\\n" "${INFO}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "restore" ]; then
            # ==============================================================================
            printf " =============== Restore: DigiAsset Node settings ====================\\n\\n"
            printf "%b Your DigiAsset Node backup settings will be restored.\\n" "${INFO}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "update_restore" ]; then
            # ==============================================================================
            printf " =============== Update & Restore: DigiAsset Node settings =========\\n\\n"
            printf "%b RPC credentials in digibyte.conf have changed. DigiAsset backup settings will be updated and restored.\\n" "${INFO}"
        elif [ "$DGA_SETTINGS_CREATE_TYPE" = "reset" ]; then
            # ==============================================================================
            printf " =============== Reset: DigiAsset Node settings ====================\\n\\n"
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

# If there was an error installing Kubo, skip installation
if  [ "$SKIP_DGA_INSTALLATION" = "YES" ]; then
    PM2_SERVICE_DO_INSTALL=NO
    PM2_SERVICE_INSTALL_TYPE="none"
    return 
fi

# If we are in reset mode, ask the user if they want to re-create the DigiNode Service...
if [ "$RESET_MODE" = true ]; then

    # ...but only ask if a service file has previously been created. (Currently can check for SYSTEMD and UPSTART)
    if [ -f "$PM2_UPSTART_SERVICE_FILE" ] || [ -f "$PM2_SYSTEMD_SERVICE_FILE" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Reset Mode" --defaultno --title "Reset Mode" --yesno "\n\Z4Do you want to re-configure the DigiAsset Node PM2 service?\Z0\n\nThe PM2 service ensures that your DigiAsset Node starts automatically at boot, and stays running 24/7. This will delete your existing PM2 service file and recreate it." 11 "${c}"; then
            PM2_SERVICE_DO_INSTALL=YES
            PM2_SERVICE_INSTALL_TYPE="reset"
        else
            printf " =============== Reset: Node.js PM2 Service ========================\\n\\n"
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

# If this is a new install of Node.js PM2 service file, and the user has opted to do a full DigiNode install, then proceed
if  [ "$PM2_SERVICE_INSTALL_TYPE" = "new" ] && [ "$PM2_SERVICE_DO_INSTALL" = "if_doing_full_install" ] && [ "$DO_FULL_INSTALL" = "YES" ]; then
    PM2_SERVICE_DO_INSTALL=YES
fi


if [ "$PM2_SERVICE_DO_INSTALL" = "YES" ]; then

    # Display section break
    printf "\\n"
    if [ "$PM2_SERVICE_INSTALL_TYPE" = "new" ]; then
        printf " =============== Install: Node.js PM2 Service ==========================\\n\\n"
        # ==============================================================================
    elif [ "$PM2_SERVICE_INSTALL_TYPE" = "reset" ]; then
        printf " =============== Reset: Node.js PM2 Service ============================\\n\\n"
        printf "%b Reset Mode: You chose re-configure the DigiAsset Node PM2 service.\\n" "${INFO}"
        # ==============================================================================
    fi

    # If SYSTEMD service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
    if [ -f "$PM2_SYSTEMD_SERVICE_FILE" ] && [ "$PM2_SERVICE_INSTALL_TYPE" = "reset" ]; then

        # Stop the service now
        systemctl stop "pm2-$USER_ACCOUNT"

        # Disable the service now
        systemctl disable "pm2-$USER_ACCOUNT"

        str="Deleting PM2 systemd service file..."
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
        printf "%b Unable to create a PM2 service for your system - systemd/upstart not found.\\n\\n" "${CROSS}"
        printf "%b For help, please contact $SOCIAL_BLUESKY_HANDLE on Bluesky: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
        exit 1
    fi

    printf "\\n"

fi

}

# If there is an update to DigiNode Tools AND one of the other sofwtare packages, install the DigiNode 
install_diginode_tools_update_first() {

    DGNT_DO_INSTALL=YES
    DGNT_REQ_INSTALL=YES
    printf "%b DigiNode Tools v$DGNT_VER_RELEASE must be installed first before you can install the other updates.\\n" "${INFO}"
    printf "\\n"

    # Install the DigiNode Tools update
    diginode_tools_do_install

    printf "\\n"
    printf "%b %bThere are additional updates available for your DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b To install them now run DigiNode Setup again: ${txtbld}diginode-setup${txtrst}\\n" "${INDENT}"
    printf "\\n"

    exit

}


# This function will ask the user if they want to install the system upgrades that have been found
menu_ask_install_updates() {

# TESTING UPGRADES (TROUBLESHOOTING)
# DGB_ASK_UPGRADE="YES"
# DGA_ASK_UPGRADE="YES"
# IPFS_ASK_UPGRADE="YES"
# DGNT_ASK_UPGRADE="YES"
# NODEJS_ASK_UPGRADE="YES"

# echo "DGB_REQ_INSTALL: $DGB_REQ_INSTALL"
# echo "DGA_REQ_INSTALL: $DGA_REQ_INSTALL"
# echo "IPFS_REQ_INSTALL: $IPFS_REQ_INSTALL"
# echo "NODEJS_REQ_INSTALL: $NODEJS_REQ_INSTALL"
# echo "DGNT_REQ_INSTALL: $DGNT_REQ_INSTALL"

# DGB_VER_GITHUB="8.22.0"
# INSTALL_DGB_RELEASE_TYPE="release"

# This variable gets set to 'yes' if there is an update to any of the included DigiNode software, except DigiNode Tools itself.
local diginode_software_update
is_diginode_software_update="no"


# If there is an upgrade available for DigiByte Core, IPFS, Node.js, DigiAsset Node or DigiNode Tools, ask the user if they want to install them
if [[ "$DGB_ASK_UPGRADE" = "YES" ]] || [[ "$DGA_ASK_UPGRADE" = "YES" ]] || [[ "$IPFS_ASK_UPGRADE" = "YES" ]] || [[ "$NODEJS_ASK_UPGRADE" = "YES" ]] || [[ "$DGNT_ASK_UPGRADE" = "YES" ]]; then

    # Are there are updates for anything other than DigiNode Tools itself?
    if [[ "$DGB_ASK_UPGRADE" = "YES" ]] || [[ "$DGA_ASK_UPGRADE" = "YES" ]] || [[ "$IPFS_ASK_UPGRADE" = "YES" ]] || [[ "$NODEJS_ASK_UPGRADE" = "YES" ]]; then
        is_diginode_software_update="yes"
    fi

    # If we are running unattended AND...
    # If we are running DigiNode Setup locally, and there is an DigiNode Tools update available, we need to install it first, before installing any other updates
    if [ "$UNATTENDED_MODE" == true ] && [ "$DGNT_RUN_LOCATION" = "local" ] && [ "$DGNT_ASK_UPGRADE" = "YES" ]; then

        # We only need to do this if there are also other updates that also need to be installed (in addition to the DigiNode Tools update)
        # Note: If there are new software tools to add here in future, this needs updating below as well
        if [ "$is_diginode_software_update" = "yes" ]; then

            # Install the DigiNode Tools update first
            install_diginode_tools_update_first

        fi

    fi

    # Don't ask if we are running unattended
    if [ ! "$UNATTENDED_MODE" == true ]; then

        local vert_space=10

        printf " =============== UPDATE MENU ===========================================\\n\\n"
        # ==============================================================================

        if [ "$DGB_ASK_UPGRADE" = "YES" ] && [ "$dgb_downgrade_requested" = true ]; then
            local upgrade_msg_dgb="      DigiByte Core v$DGB_VER_LOCAL  >>  v$DGB_VER_GITHUB (Downgrade)\\n"
            vert_space=$(($vert_space + 1))
        elif [ "$DGB_ASK_UPGRADE" = "YES" ] && [ "$INSTALL_DGB_RELEASE_TYPE" = "prerelease" ]; then
            local upgrade_msg_dgb="      DigiByte Core v$DGB_VER_LOCAL  >>  v$DGB_VER_GITHUB (Pre-Release)\\n"
            vert_space=$(($vert_space + 1))
        elif [ "$DGB_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dgb="      DigiByte Core v$DGB_VER_LOCAL  >>  v$DGB_VER_GITHUB\\n"
            vert_space=$(($vert_space + 1))
        fi
        if [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_ipfs="     IPFS Kubo v$IPFS_VER_LOCAL  >>  v$IPFS_VER_RELEASE\\n"
            vert_space=$(($vert_space + 1))
        fi
        if [ "$NODEJS_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_nodejs="      Node.js v$NODEJS_VER_LOCAL  >>  v$NODEJS_VER_RELEASE\\n"
            vert_space=$(($vert_space + 1))
        fi
        if [ "$DGA_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dga="      DigiAsset Node v$DGA_VER_LOCAL  >>  v$DGA_VER_RELEASE\\n"
            vert_space=$(($vert_space + 1))
        fi
        if [ "$DGNT_ASK_UPGRADE" = "YES" ]; then
            local upgrade_msg_dgnt="      DigiNode Tools v$DGNT_VER_LOCAL  >>  v$DGNT_VER_RELEASE\\n"
            vert_space=$(($vert_space + 1))
        fi

        # Change update message from singular to plural
        local updates_msg
        local updates_msg2
        if [ "$vert_space" -eq 11 ]; then
            printf "%b There is a DigiNode software update available...\\n" "${INFO}"
            updates_msg="There is an update available for your DigiNode:"
            updates_msg2="Would you like to install it?"
        else
            printf "%b There are DigiNode software updates available...\\n" "${INFO}"
            updates_msg="The following updates are available for your DigiNode:"
            updates_msg2="Would you like to install them?"
        fi

        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Software Update" --title "DigiNode Software Update" --yes-label "Yes" --yesno "\n$updates_msg\n\n$upgrade_msg_dgb$upgrade_msg_ipfs$upgrade_msg_nodejs$upgrade_msg_dga$upgrade_msg_dgnt\n$updates_msg2" "${vert_space}" "${c}"; then

            # If we are running DigiNode Setup locally, and there is an DigiNode Tools update available, we need to install it first, before installing any other updates
            # This is skipped when in development mode. The user must run DigiNode Setup again to install the other updates
            if [ "$DGNT_RUN_LOCATION" = "local" ] && [ "$DGNT_ASK_UPGRADE" = "YES" ]; then

                # We only need to do this if there are also other updates that also need to be installed (in addition to the DigiNode Tools update)
                if [ "$is_diginode_software_update" = "yes" ]; then

                    # Show an alert explaining that the diginode tools update must be installed first
                    dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Tools must be updated seperately!" --title "DigiNode Tools must be updated seperately!" --msgbox "\n\Z1IMPORTANT: DigiNode Setup must be updated before you can install the other updates.\Z0\\n\\nWhen you click OK, the latest version of DigiNode Tools will be installed.\\n\\nPlease run DigiNode Setup again in a moment to install the other updates." 15 ${c}

                    # Install the DigiNode Tools update first
                    install_diginode_tools_update_first

                fi

            fi

            #Nothing to do, continue
            if [ "$DGB_ASK_UPGRADE" = "YES" ]; then
                if [ "$vert_space" -ge 12 ]; then
                    if dialog --no-shadow --keep-tite --colors --backtitle "DigiByte Core Upgrade" --title "DigiByte Core Upgrade" --yesno "\nDo you want to install DigiByte Core v$DGB_VER_GITHUB now?" 7 "${c}"; then
                        DGB_DO_INSTALL=YES
                        DGB_REQ_INSTALL=YES
                        printf "%b You chose to install DigiByte Core v$DGB_VER_GITHUB\\n" "${INFO}"
                    else
                        DGB_DO_INSTALL=NO
                        DGB_REQ_INSTALL=NO
                        printf "%b You chose NOT to install DigiByte Core v$DGB_VER_GITHUB\\n" "${INFO}"
                    fi
                else
                    DGB_DO_INSTALL=YES
                    DGB_REQ_INSTALL=YES
                    printf "%b You chose to install DigiByte Core v$DGB_VER_GITHUB\\n" "${INFO}"
                fi
            fi
            if [ "$IPFS_ASK_UPGRADE" = "YES" ]; then
                if [ "$vert_space" -ge 12 ]; then
                    if dialog --no-shadow --keep-tite --colors --backtitle "IPFS Kubo Upgrade" --title "IPFS Kubo Upgrade" --yesno "\nDo you want to install IPFS Kubo v$IPFS_VER_RELEASE now?" 7 "${c}"; then
                        IPFS_DO_INSTALL=YES
                        IPFS_REQ_INSTALL=YES
                        printf "%b You chose to install IPFS Kubo v$IPFS_VER_RELEASE\\n" "${INFO}"
                    else
                        IPFS_DO_INSTALL=NO
                        IPFS_REQ_INSTALL=NO
                        printf "%b You chose NOT to install IPFS Kubo v$IPFS_VER_RELEASE\\n" "${INFO}"
                    fi
                else
                    IPFS_DO_INSTALL=YES
                    IPFS_REQ_INSTALL=YES
                    printf "%b You chose to install IPFS Kubo v$IPFS_VER_RELEASE\\n" "${INFO}"
                fi
            fi
            if [ "$NODEJS_ASK_UPGRADE" = "YES" ]; then
                if [ "$vert_space" -ge 12 ]; then
                    if dialog --no-shadow --keep-tite --colors --backtitle "Node.js Upgrade" --title "Node.js Upgrade" --yesno "\nDo you want to install Node.js v$NODEJS_VER_RELEASE now?" 7 "${c}"; then
                        NODEJS_DO_INSTALL=YES
                        NODEJS_REQ_INSTALL=YES
                        printf "%b You chose to install Node.js v$NODEJS_VER_RELEASE\\n" "${INFO}"
                    else
                        NODEJS_DO_INSTALL=NO
                        NODEJS_REQ_INSTALL=NO
                        printf "%b You chose NOT to install Node.js v$NODEJS_VER_RELEASE\\n" "${INFO}"
                    fi
                else
                    NODEJS_DO_INSTALL=YES
                    NODEJS_REQ_INSTALL=YES
                    printf "%b You chose to install Node.js v$NODEJS_VER_RELEASE\\n" "${INFO}"
                fi
            fi
            if [ "$DGA_ASK_UPGRADE" = "YES" ]; then
                if [ "$vert_space" -ge 12 ]; then
                    if dialog --no-shadow --keep-tite --colors --backtitle "DigiAsset Node Upgrade" --title "DigiAsset Node Upgrade" --yesno "\nDo you want to install DigiAsset Node v$DGA_VER_RELEASE now?" 7 "${c}"; then
                        DGA_DO_INSTALL=YES
                        DGA_REQ_INSTALL=YES
                        printf "%b You chose to install DigiAsset Node v$DGA_VER_RELEASE\\n" "${INFO}"
                    else
                        DGA_DO_INSTALL=NO
                        DGA_REQ_INSTALL=NO
                        printf "%b You chose NOT to install DigiAsset Node v$DGA_VER_RELEASE\\n" "${INFO}"
                    fi
                else
                    DGA_DO_INSTALL=YES
                    DGA_REQ_INSTALL=YES
                    printf "%b You chose to install DigiAsset Node v$DGA_VER_RELEASE\\n" "${INFO}"
                fi
            fi
            if [ "$DGNT_ASK_UPGRADE" = "YES" ]; then
                if [ "$vert_space" -ge 12 ]; then
                    if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Tools Upgrade" --title "DigiNode Tools Upgrade" --yesno "\nDo you want to install DigiNode Tools v$DGNT_VER_RELEASE now?" 7 "${c}"; then
                        DGNT_DO_INSTALL=YES
                        DGNT_REQ_INSTALL=YES
                        printf "%b You chose to install DigiNode Tools v$DGNT_VER_RELEASE\\n" "${INFO}"
                    else
                        printf "%b You chose NOT to install DigiNode Tools v$DGNT_VER_RELEASE\\n" "${INFO}"
                        DGNT_DO_INSTALL=NO
                        DGNT_REQ_INSTALL=NO
                    fi
                else
                    DGNT_DO_INSTALL=YES
                    DGNT_REQ_INSTALL=YES
                    printf "%b You chose to install DigiNode Tools v$DGNT_VER_RELEASE\\n" "${INFO}"
                fi
            fi
        else
            if [ "$vert_space" -eq 11 ]; then
                printf "%b You chose NOT to install the available update:\\n$upgrade_msg_dgb$upgrade_msg_ipfs$upgrade_msg_nodejs$upgrade_msg_dga$upgrade_msg_dgnt" "${INFO}"
            else
                printf "%b You chose NOT to install the available updates:\\n$upgrade_msg_dgb$upgrade_msg_ipfs$upgrade_msg_nodejs$upgrade_msg_dga$upgrade_msg_dgnt" "${INFO}"
            fi
            printf "\\n"
            display_system_updates_reminder
            exit
        fi

        # Troubleshooting
        #    echo "DGB_REQ_INSTALL: $DGB_REQ_INSTALL"
        #    echo "DGA_REQ_INSTALL: $DGA_REQ_INSTALL"
        #    echo "NODEJS_REQ_INSTALL: $NODEJS_REQ_INSTALL"
        #    echo "IPFS_REQ_INSTALL: $IPFS_REQ_INSTALL"
        #    echo "DGNT_REQ_INSTALL: $DGNT_REQ_INSTALL"

        # If the user has chosen to install one or more updates, then proceed. Otherwise exit.
        if [[ "$DGB_REQ_INSTALL" = "YES" ]] || [[ "$DGA_REQ_INSTALL" = "YES" ]] || [[ "$IPFS_REQ_INSTALL" = "YES" ]] || [[ "$NODEJS_REQ_INSTALL" = "YES" ]] || [[ "$DGNT_REQ_INSTALL" = "YES" ]]; then
            printf "%b Proceeding to install chosen updates...\\n" "${INFO}"
        else
          printf "%b You chose NOT to install any of the available updates.\\n" "${INFO}"
          printf "\\n"
          display_system_updates_reminder
          exit
        fi

        printf "\\n"

    fi

fi

# TESTING UPDATE MECHANISM
# exit

}

# This function will ask the user if they want to install DigiAssets Node
menu_ask_install_digiasset_node() {

# Provided we are not in unnatteneded mode, and it is not already installed, ask the user if they want to install a DigiAssets Node
if [ ! -f $DGA_INSTALL_LOCATION/.officialdiginode ] && [ "$UNATTENDED_MODE" == false ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Install DigiAsset Node?" --defaultno --title "Install DigiAsset Node?" --yesno "\n\Z4Would you like to install a DigiAsset Node?\Z0\n\nYou do not currently have a DigiAsset Node installed. Running a DigiAsset Node along side your DigiByte Full Node helps to support the network by decentralizing DigiAsset metadata.\n\nYou can earn \$DGB for hosting other people's metadata, and it also gives you the ability to create your own DigiAssets from the web interface." 15 "${c}"; then
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



# This function will check if the motd is currently enabled

motd_check() {

    printf " =============== Checking: DigiNode MOTD ===============================\\n\\n"
    # ==============================================================================

    # Let's check if DigiByte Node is already installed
    str="Is the DigiNode custom MOTD installed?..."
    printf "%b %s" "${INFO}" "${str}"
    if [ -f "/etc/update-motd.d/50-diginode" ]; then
        MOTD_STATUS_CURRENT="ENABLED"
        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
    else
        MOTD_STATUS_CURRENT="DISABLED"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
    fi

    #

    printf "\\n"

}


# This function will ask the user if they want to install a DigiByte testnode node or just a mainnet node
menu_ask_motd() {

local show_motd_menu="no"

# If this is a brand new install, then display the motd menu
if [ ! -f "$DGB_INSTALL_LOCATION/.officialdiginode" ] && [ ! -f "$DGA_INSTALL_LOCATION/.officialdiginode" ]; then
    show_motd_menu="yes"
fi


# If we don't know what the current MOTD status is (perhaps diginode.settings got deleted)
if [ "$MOTD_STATUS" = "" ]; then
    show_motd_menu="yes"
fi

# If this is being run from the main menu then always enable the menu
if [ "$MOTD_STATUS" = "ASK" ]; then
    show_motd_menu="yes"
fi



# SHOW MOTD MENU

# Don't ask if we are running unattended
if [ ! "$UNATTENDED_MODE" == true ]; then

    # Display dgb network section break
    if [ "$show_motd_menu" = "yes" ]; then

            printf " =============== DigiNode Custom MOTD ==================================\\n\\n"
            # ==============================================================================

    fi


    # ASK TO INSTALL THE MOTD (displays during a new install or when accessed from the main menu)
    if [ "$show_motd_menu" = "yes" ] && [ "$MOTD_STATUS_CURRENT" = "DISABLED" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Enable DigiNode Custom MOTD?" --title "Enable DigiNode Custom MOTD?" --yes-label "Yes" --no-label "No" --yesno "\n\Z4Would you like to enable the custom DigiNode MOTD?\Z0\n\nThe MOTD (Message of the Day) is displayed whenever you login to the system via the terminal.\n\nIf you answer YES, the default system MOTD will be backed up and replaced with a custom DigiNode MOTD which displays the DigiNode logo and usage instructions.\n\nIf you are running your DigiNode on a dedicated device on local network, such as a Raspberry Pi, then this change is recommended. \n\nIf you are running your DigiNode remotely (e.g. on a VPS) or on a multi-purpose server then you may not want to change the MOTD." 20 "${c}"; then
            printf "%b You chose to install the DigiNode Custom MOTD.\\n" "${INFO}"
            MOTD_DO_INSTALL="YES"
            MOTD_DO_UNINSTALL=""
        #Nothing to do, continue
        else
            printf "%b You chose not to install the DigiNode Custom MOTD.\\n" "${INFO}"
            MOTD_DO_INSTALL=""
            MOTD_DO_UNINSTALL=""
            MOTD_STATUS="DISABLED"
            sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"DISABLED\"|" $DGNT_SETTINGS_FILE

            if [ "$CUSTOM_MOTD_MENU" = "existing_install_menu" ]; then
                CUSTOM_MOTD_MENU=""
                menu_existing_install
            fi

        fi
        printf "\\n"

    # ASK TO UNINSTALL THE MOTD (if accessed from the existing install menu, or the DigiNode only menu)
    elif [ "$show_motd_menu" = "yes" ] && [ "$MOTD_STATUS_CURRENT" = "ENABLED" ] && [ "$CUSTOM_MOTD_MENU" != "" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Disable DigiNode Custom MOTD?" --title "Disable DigiNode Custom MOTD?" --yes-label "Yes" --no-label "No" --yesno "\n\Z4Would you like to disable the custom DigiNode MOTD?\Z0\n\nThe MOTD (Message of the Day) is displayed whenever you login to the system via the terminal.\n\nIf you answer YES, the custom DigiNode MOTD will be removed, amd the default system MOTD will be restored from the backup." 13 "${c}"; then
            printf "%b You chose to uninstall the DigiNode Custom MOTD.\\n" "${INFO}"
            MOTD_DO_INSTALL=""
            MOTD_DO_UNINSTALL="YES"
        #Nothing to do, continue
        else
            printf "%b You chose not to uninstall the DigiNode Custom MOTD.\\n" "${INFO}"
            MOTD_DO_INSTALL=""
            MOTD_DO_UNINSTALL=""
            MOTD_STATUS="ENABLED"
            sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"ENABLED\"|" $DGNT_SETTINGS_FILE

            if [ "$CUSTOM_MOTD_MENU" = "existing_install_menu" ]; then
                CUSTOM_MOTD_MENU=""
                menu_existing_install
            fi
        fi
        printf "\\n"

    # ASK WHETHER TO USE THE MOTD (if this is a new install, but the custom MOTD is already installed)
    elif [ "$show_motd_menu" = "yes" ] && [ "$MOTD_STATUS_CURRENT" = "ENABLED" ] && [ "$CUSTOM_MOTD_MENU" = "" ]; then

        if dialog --no-shadow --keep-tite --colors --backtitle "Keep DigiNode Custom MOTD?" --title "Keep DigiNode Custom MOTD?" --yes-label "Yes" --no-label "No" --yesno "\n\Z4Would you like to keep the custom DigiNode MOTD?\Z0\n\nThe MOTD (Message of the Day) is displayed whenever you login to the system via the terminal. You already have the DigiNode custom MOTD installed.\n\nIf you answer YES, the DigiNode custom MOTD will be kept.\n\nIf you choose NO, the custom DigiNode MOTD will be removed, amd the default system MOTD will be restored." 16 "${c}"; then
            printf "%b You chose to keep the DigiNode Custom MOTD.\\n" "${INFO}"
            MOTD_DO_INSTALL=""
            MOTD_DO_UNINSTALL=""
            MOTD_STATUS="ENABLED"
            sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"ENABLED\"|" $DGNT_SETTINGS_FILE
        #Nothing to do, continue
        else
            printf "%b You chose not to install the DigiNode Custom MOTD.\\n" "${INFO}"
            MOTD_DO_INSTALL=""
            MOTD_DO_UNINSTALL="YES"

        fi
        printf "\\n"

    elif [ "$show_dgb_network_menu" = "no" ]; then

        MOTD_DO_INSTALL=""
        MOTD_DO_UNINSTALL=""

    fi

else


    # If we are running unattended, and the script wants to prompt the user with the motd menu, then get the values from diginode.settings

    printf " =============== Unattended Mode: DigiNode Custom MOTD =================\\n\\n"
    # ==============================================================================


    if [ "$UI_SETUP_DIGINODE_MOTD" = "YES" ] && [ "$MOTD_STATUS_CURRENT" = "DISABLED" ] && [ "$show_motd_menu" = "yes" ]; then

        printf "%b Unattended Mode: DigiNode Custom MOTD will be ENABLED\\n" "${INFO}"
        printf "%b                  (Set from UI_SETUP_DIGINODE_MOTD value in diginode.settings)\\n" "${INDENT}"
        MOTD_DO_INSTALL="YES"
        MOTD_DO_UNINSTALL=""

    elif [ "$UI_SETUP_DIGINODE_MOTD" = "NO" ] && [ "$MOTD_STATUS_CURRENT" = "ENABLED" ] && [ "$show_motd_menu" = "yes" ]; then

        printf "%b Unattended Mode: DigiNode Custom MOTD will be DISABLED\\n" "${INFO}"
        printf "%b                  (Set from UI_SETUP_DIGINODE_MOTD value in diginode.settings)\\n" "${INDENT}"
        MOTD_DO_INSTALL=""
        MOTD_DO_UNINSTALL="YES"

    else

        printf "%b Unattended Mode: Skipping changing the MOTD message. It will remain $MOTD_STATUS_CURRENT.\\n" "${INFO}"
        MOTD_DO_INSTALL=""
        MOTD_DO_UNINSTALL=""

        if [ "$MOTD_STATUS_CURRENT" = "ENABLED" ]; then
            MOTD_STATUS="ENABLED"
            sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"ENABLED\"|" $DGNT_SETTINGS_FILE
        elif [ "$MOTD_STATUS_CURRENT" = "DISABLED" ]; then
            MOTD_STATUS="DISABLED"
            sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"DISABLED\"|" $DGNT_SETTINGS_FILE
        fi

    fi

    printf "\\n"


fi

}

# This function will install or uninstall the custom DigiNode MOTD
motd_do_install_uninstall() {


if [ "$MOTD_DO_INSTALL" = "YES" ]; then

    printf " =============== Install: DigiNode Custom MOTD =========================\\n\\n"
    # ==============================================================================


    str="Is DigiNode MOTD install file available?..."
    printf "%b %s" "${INFO}" "${str}"

    # Is DigiNode MOTD install file available?
    if [  -f "$DGNT_LOCATION/motd/50-diginode" ]; then
        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
        dialog --no-shadow --keep-tite --backtitle "DigiNode MOTD install file not found!" --title "DigiNode MOTD install file not found!" --msgbox "\nThe DigiNode MOTD install file was not found. Please upgrade DigiNode Tools and then try again." 10 ${c}
        printf "\\n"
        return
    fi

    # Copy MOTD file to correct location
    if [ ! -f "/etc/update-motd.d/50-diginode" ]; then
        str="Copying DigiNode Custom MOTD file to /etc/update-motd.d..."
        printf "%b %s" "${INFO}" "${str}"
        cp -f $DGNT_LOCATION/motd/50-diginode /etc/update-motd.d
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Change MOTD file owner to root
    if [ -f "/etc/update-motd.d/50-diginode" ]; then
        str="Changing Custom DigiNode MOTD file owner to root..."
        printf "%b %s" "${INFO}" "${str}"
        chown root:root /etc/update-motd.d/50-diginode
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Make DigiNode MOTD file executable
    if [ -f "/etc/update-motd.d/50-diginode" ]; then
        str="Make Custom DigiNode MOTD file executable..."
        printf "%b %s" "${INFO}" "${str}"
        chmod +x /etc/update-motd.d/50-diginode
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Create backup folder for system MOTD
    if [ ! -d "$USER_HOME/.motdbackup" ]; then
        str="Create backup folder for system MOTD..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT mkdir $USER_HOME/.motdbackup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Backup system MOTD
    if [ -f "/etc/motd" ]; then
        str="Backup system MOTD file..."
        printf "%b %s" "${INFO}" "${str}"
        cp -f /etc/motd $USER_HOME/.motdbackup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete system MOTD
    if [ -f "/etc/motd" ]; then
        str="Delete system MOTD file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f /etc/motd
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    printf "\\n"

    MOTD_STATUS="ENABLED"
    sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"ENABLED\"|" $DGNT_SETTINGS_FILE

    if [ "$CUSTOM_MOTD_MENU" = "existing_install_menu" ] && [ -f "/etc/update-motd.d/50-diginode" ]; then
        dialog --no-shadow --keep-tite --backtitle "DigiNode MOTD has been installed!" --title "DigiNode MOTD has been installed!" --msgbox "\nThe DigiNode MOTD has been successfully installed." 7 ${c}
        return
    fi

fi


if [ "$MOTD_DO_UNINSTALL" = "YES" ]; then

    printf " =============== Uninstall: DigiNode Custom MOTD =======================\\n\\n"
    # ==============================================================================

    # Restore system MOTD from backup
    if [ -f "$USER_HOME/.motdbackup/motd" ]; then
        str="Restore system MOTD file from backup..."
        printf "%b %s" "${INFO}" "${str}"
        cp -f $USER_HOME/.motdbackup/motd /etc
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Change system MOTD file owner to root
    if [ -f "/etc/motd" ]; then
        str="Changing system MOTD file owner to root..."
        printf "%b %s" "${INFO}" "${str}"
        chown root:root /etc/motd
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete backup folder for system MOTD
    if [ -d "$USER_HOME/.motdbackup" ]; then
        str="Delete backup folder for system MOTD..."
        printf "%b %s" "${INFO}" "${str}"
        sudo -u $USER_ACCOUNT rm -rf $USER_HOME/.motdbackup
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Delete the custom MOTD file
    if [ -f "/etc/update-motd.d/50-diginode" ]; then
        str="Deleting the DigiNode Custom MOTD file in /etc/update-motd.d..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f /etc/update-motd.d/50-diginode
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    printf "\\n"

    MOTD_STATUS="DISABLED"
    sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"DISABLED\"|" $DGNT_SETTINGS_FILE

    if [ "$CUSTOM_MOTD_MENU" = "existing_install_menu" ] && [ ! -f "/etc/update-motd.d/50-diginode" ]; then
        dialog --no-shadow --keep-tite --backtitle "DigiNode MOTD has been uninstalled!" --title "DigiNode MOTD has been uninstalled!" --msgbox "\nThe DigiNode MOTD file has been successfully uninstalled." 7 ${c}
        return
    fi

fi    


}







# Perform uninstall if requested
uninstall_do_now() {

    # Get version codename
    LINUX_ID=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
    LINUX_VERSION_CODENAME=$(cat /etc/os-release | grep VERSION_CODENAME | cut -d'=' -f2)

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
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Remove DigiAsset Node" --title "DigiNode Uninstall: Remove DigiAsset Node" --yesno "\n\Z4Would you like to uninstall DigiAsset Node v${DGA_VER_LOCAL}?\Z0\n\nThis will remove the DigiAsset Node software only - your DigiAsset Node settings will be kept." 10 "${c}"; then

            local delete_dga=yes

        else
            local delete_dga=no
            printf "%b You chose not to uninstall DigiAsset Node v${DGA_VER_LOCAL}.\\n" "${INFO}"
        fi
    fi

    # Ask to delete DigiAsset Node config folder if it exists
    if [ -d "$DGA_SETTINGS_LOCATION" ] && [ "$delete_dga" = "yes" ]; then

        # Do you want to delete DigiAsset settings folder?
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete DigiAsset settings" --title "DigiNode Uninstall: Delete DigiAsset settings" --yesno "\n\Z4Would you like to also delete your DigiAsset Node settings folder: ~/digiasset_node/_config ?\Z0\n\n(If you choose No, the configuration folder will be backed up to your home folder, and automatically restored to its original location, when you reinstall the DigiAsset Node software.)" 12 "${c}"; then
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
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete JS-IPFS settings folder" --title "DigiNode Uninstall: Delete JS-IPFS settings folder" --yesno "\n\Z4Would you like to also delete your JS-IPFS settings folder?\Z0\n\nThis will delete the folder: ~/.jsipfs\n\nThis folder contains all the settings and metadata related to the IPFS implementation built into the DigiAsset Node software." 12 "${c}"; then
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
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete PM2 service file" --title "DigiNode Uninstall: Delete PM2 service file" --yesno "\n\Z4Would you like to delete your PM2 service file?\Z0\n\nNote: This ensures that the DigiAsset Node starts at launch, and relaunches if it crashes for some reason. You can safely delete this if you do not use PM2 for anything else." 11 "${c}"; then

                # If SYSTEMD service file already exists, and we doing a Reset, stop it and delete it, since we will re-create it
            if [ -f "$PM2_SYSTEMD_SERVICE_FILE" ]; then

                # Stop the service now
                systemctl stop "pm2-$USER_ACCOUNT"

                # Disable the service now
                systemctl disable "pm2-$USER_ACCOUNT"

                str="Deleting PM2 systemd service file..."
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

                str="Deleting PM2 upstart service file..."
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

    ################## UNINSTALL NODE.JS #################################################

    # Only uninstall Node.js if DigiAsset Node has already been uninstalled
    if [ "$uninstall_dga" = "yes" ]; then

        # Get the local version number of Node.js (this will also tell us if it is installed)
        NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')

        if [ "$NODEJS_VER_LOCAL" = "" ]; then
            NODEJS_STATUS="not_detected"
            sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
        else
            NODEJS_STATUS="installed"
            sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
        fi


        # Ask to uninstall Node.js if it exists
        if [ -f /etc/apt/keyrings/nodesource.gpg ] || [ -f /etc/apt/sources.list.d/nodesource.list ] || [ "$NODEJS_STATUS" = "installed" ]; then

            printf " =============== Uninstall: Node.js ====================================\\n\\n"
            # ==============================================================================

            # Delete Node.js
            if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Remove Node.js" --title "DigiNode Uninstall: Remove Node.js" --yesno "\n\Z4Would you like to uninstall Node.js v${NODEJS_VER_LOCAL}?\Z0\n\nYou can safely uninstall it if you do not use Node.js for anything else." 10 "${c}"; then

                printf "%b You chose to uninstall Node.js v${NODEJS_VER_LOCAL}.\\n" "${INFO}"

                # Deleting deb repository
                if [ -f /etc/apt/sources.list.d/nodesource.list ]; then 
                    str="Deleting Nodesource deb repository..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -f /etc/apt/sources.list.d/nodesource.list
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                # Deleting gpg key
                if [ -f /etc/apt/keyrings/nodesource.gpg ]; then 
                    str="Deleting Nodesource GPG key..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -f /etc/apt/keyrings/nodesource.gpg
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                # Delete Node.js packages
                if [ "$NODEJS_STATUS" = "installed" ]; then
                    if [ "$LINUX_ID" = "ubuntu" ] || [ "$LINUX_ID" = "debian" ]; then
                        printf "%b Uninstalling Node.js packages...\\n" "${INFO}"
                        sudo apt-get purge nodejs -y -q
                    elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
                        printf "%b Uninstalling Node.js packages...\\n" "${INFO}"
                        yum remove nodejs -y
                        str="Deleting Nodesource key for Enterprise Linux..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf /etc/yum.repos.d/nodesource*.repo
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                        yum clean all -y
                    fi
                    NODEJS_STATUS="not_detected"
                    NODEJS_VER_LOCAL=""
                    delete_nodejs="yes"
                    sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
                    NODEJS_INSTALL_DATE=""
                    sed -i -e "/^NODEJS_INSTALL_DATE=/s|.*|NODEJS_INSTALL_DATE=|" $DGNT_SETTINGS_FILE
                    NODEJS_UPGRADE_DATE=""
                    sed -i -e "/^NODEJS_UPGRADE_DATE=/s|.*|NODEJS_UPGRADE_DATE=|" $DGNT_SETTINGS_FILE
                fi

                # Reset Nodesource repo variable in diginode.settings so it will run again
                sed -i -e "/^NODEJS_REPO_ADDED=/s|.*|NODEJS_REPO_ADDED=\"NO\"|" $DGNT_SETTINGS_FILE

                # Delete .npm settings
                if [ -d "$USER_HOME/.npm" ]; then
 #                   if whiptail --backtitle "" --title "UNINSTALL" --yesno "Would you like to also delete your Node.js settings folder?\\n\\nThis will delete the folder: ~/.npm\\n\\nThis folder contains all the settings related to the Node package manager." "${r}" "${c}"; then
                        str="Deleting ~/.npm settings folder..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -r $USER_HOME/.npm
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
#                    else
#                        printf "%b You chose not to delete the Node.js settings folder (~/.npm).\\n" "${INFO}"
#                    fi
                fi

            else
                printf "%b You chose not to uninstall Node.js.\\n" "${INFO}"
                delete_nodejs="no"
            fi    

        printf "\\n"
        fi
    fi


    ################## UNINSTALL IPFS #################################################

    # Get the local version number of IPFS Kubo (this will also tell us if it is installed)
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

    printf " =============== Uninstall: IPFS Kubo ==================================\\n\\n"
    # ==============================================================================

        # Delete IPFS
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Remove IPFS Kubo" --title "DigiNode Uninstall: Remove IPFS Kubo" --yesno "\n\Z4Would you like to uninstall IPFS Kubo v${IPFS_VER_LOCAL}?\Z0\n\nThis will uninstall the IPFS software." 9 "${c}"; then

            printf "%b You chose to uninstall IPFS Kubo v${IPFS_VER_LOCAL}.\\n" "${INFO}"


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
                str="Deleting current IPFS Kubo binary: /usr/local/bin/ipfs..."
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
                if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete IPFS Kubo settings" --title "DigiNode Uninstall: Delete IPFS Kubo settings" --yesno "\n\Z4Would you like to also delete your IPFS Kubo settings folder?\Z0\\n\\nThis will delete the folder: ~/.ipfs\n\nThis folder contains all the settings and metadata related to your IPFS Kubo node." 12 "${c}"; then
                    str="Deleting ~/.ipfs settings folder..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -r $USER_HOME/.ipfs
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                else
                    printf "%b You chose not to delete the IPFS Kubo settings folder (~/.ipfs).\\n" "${INFO}"
                fi
            fi

            # Restart the DigiAsset Node, if we uninstalled Kobu. This is to force it to switch over to using JS-IPFS
            if [ "$delete_kubo" = "yes" ] && [ "$delete_dga" = "no" ]; then
                str="Restarting DigiAsset Node so it switches from using IPFS Kubo to JS-IPFS..."
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
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Remove DigiByte Core" --title "DigiNode Uninstall: Remove DigiByte Core" --yesno "\n\Z4Would you like to uninstall DigiByte Core v${DGB_VER_LOCAL}?\Z0\n\nThis will uninstall the DigiByte Core software only - your wallet, digibyte.conf settings and blockchain data will not be affected." 11 "${c}"; then

            printf "%b You chose to uninstall DigiByte Core.\\n" "${INFO}"

            printf "%b Stopping DigiByte Core daemon...\\n" "${INFO}"
            stop_service digibyted
            disable_service digibyted
            DGB_STATUS="stopped"

            # Delete systemd service file
            if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ]; then
                str="Deleting DigiByte daemon systemd service file..."
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

            # If we are running a Dual Node, stop the service and delete it
            if [ "$DGB_DUAL_NODE" = "YES" ]; then

                printf "%b Stopping DigiByte Core testnet daemon for Dual Node...\\n" "${INFO}"
                stop_service digibyted-testnet
                disable_service digibyted-testnet
                DGB2_STATUS="stopped"

                # Delete systemd service file
                if [ -f "$DGB2_SYSTEMD_SERVICE_FILE" ]; then
                    str="Deleting DigiByte testnet systemd service file for Dual Node..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -f $DGB2_SYSTEMD_SERVICE_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi

                # Delete upstart service file
                if [ -f "$DGB2_UPSTART_SERVICE_FILE" ]; then
                    str="Deleting DigiByte testnet upstart service file for Dual Node..."
                    printf "%b %s" "${INFO}" "${str}"
                    rm -f $DGB2_UPSTART_SERVICE_FILE
                    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                fi

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
                DGB_PRERELEASE=""
                sed -i -e "/^DGB_PRERELEASE=/s|.*|DGB_PRERELEASE=|" $DGNT_SETTINGS_FILE
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
                if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete digibyte.conf" --title "DigiNode Uninstall: Delete digibyte.conf" --yesno "\n\Z4Would you like to also delete your digibyte.conf settings file?\Z0\\n\\nThis will remove any customisations you made to your DigiByte install." 10 "${c}"; then

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

                # Delete DigiByte blockchain MAINNET data
               if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete DigiByte MAINNET blockchain" --title "DigiNode Uninstall: Delete DigiByte MAINNET blockchain" --yesno "\n\Z4Would you like to also delete the DigiByte MAINNET blockchain data?\Z0\n\nIt is currently taking up ${DGB_DATA_DISKUSED_MAIN_HR}b of space on your drive. If you delete it, and later re-install DigiByte Core, it will need to re-download the entire blockchain which can take many hours.\n\nNote: Your mainnet wallet will be kept." 14 "${c}"; then

                    # Delete systemd service file
                    if [ -d "$DGB_DATA_LOCATION" ]; then
                        str="Deleting DigiByte Core MAINNET blockchain data..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf $DGB_DATA_LOCATION/indexes
                        rm -rf $DGB_DATA_LOCATION/chainstate
                        rm -rf $DGB_DATA_LOCATION/blocks
                        rm -f $DGB_DATA_LOCATION/banlist.dat
                        rm -f $DGB_DATA_LOCATION/banlist.json
                        rm -f $DGB_DATA_LOCATION/digibyted.pid
                        rm -f $DGB_DATA_LOCATION/fee_estimates.dat
                        rm -f $DGB_DATA_LOCATION/.lock
                        rm -f $DGB_DATA_LOCATION/mempool.dat
                        rm -f $DGB_DATA_LOCATION/peers.dat
                        rm -f $DGB_DATA_LOCATION/settings.json
                        DGB_DATA_DISKUSED_MAIN_HR=""
                        DGB_DATA_DISKUSED_MAIN_KB=""
                        DGB_DATA_DISKUSED_MAIN_PERC=""
                        DGB_BLOCKSYNC_VALUE=""
                        sed -i -e "/^DGB_DATA_DISKUSED_MAIN_HR=/s|.*|DGB_DATA_DISKUSED_MAIN_HR=\"$DGB_DATA_DISKUSED_MAIN_HR\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_MAIN_KB=/s|.*|DGB_DATA_DISKUSED_MAIN_KB=\"$DGB_DATA_DISKUSED_MAIN_KB\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_MAIN_PERC=/s|.*|DGB_DATA_DISKUSED_MAIN_PERC=\"$DGB_DATA_DISKUSED_MAIN_PERC\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_BLOCKSYNC_VALUE=/s|.*|DGB_BLOCKSYNC_VALUE=\"$DGB_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi


                else
                    printf "%b You chose not to keep the existing DigiByte MAINNET blockchain data.\\n" "${INFO}"
                fi

            fi

            # Only prompt to delete the testnet blockchain data if it already exists
            if [ -d "$DGB_DATA_LOCATION/testnet4/indexes" ] || [ -d "$DGB_DATA_LOCATION/testnet4/chainstate" ] || [ -d "$DGB_DATA_LOCATION/testnet4/blocks" ]; then

                # Delete DigiByte blockchain TESTNET data
                if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete DigiByte TESTNET blockchain" --title "DigiNode Uninstall: Delete DigiByte TESTNET blockchain" --yesno "\n\Z4Would you like to also delete the DigiByte TESTNET blockchain data?\Z0\n\nIt is currently taking up ${DGB_DATA_DISKUSED_TEST_HR}b of space on your drive. If you delete it, and later re-install DigiByte Core, it will need to re-download the entire blockchain which can take many hours.\n\nNote: Your testnet wallet will be kept." 14 "${c}"; then

                    # Delete testnet blockchain data
                    if [ -d "$DGB_DATA_LOCATION/testnet4" ]; then
                        str="Deleting DigiByte Core TESTNET blockchain data..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf $DGB_DATA_LOCATION/testnet4/indexes
                        rm -rf $DGB_DATA_LOCATION/testnet4/chainstate
                        rm -rf $DGB_DATA_LOCATION/testnet4/blocks
                        rm -f $DGB_DATA_LOCATION/testnet4/banlist.dat
                        rm -f $DGB_DATA_LOCATION/testnet4/banlist.json
                        rm -f $DGB_DATA_LOCATION/testnet4/digibyted.pid
                        rm -f $DGB_DATA_LOCATION/testnet4/fee_estimates.dat
                        rm -f $DGB_DATA_LOCATION/testnet4/.lock
                        rm -f $DGB_DATA_LOCATION/testnet4/mempool.dat
                        rm -f $DGB_DATA_LOCATION/testnet4/peers.dat
                        rm -f $DGB_DATA_LOCATION/testnet4/settings.json
                        DGB_DATA_DISKUSED_TEST_HR=""
                        DGB_DATA_DISKUSED_TEST_KB=""
                        DGB_DATA_DISKUSED_TEST_PERC=""
                        sed -i -e "/^DGB_DATA_DISKUSED_TEST_HR=/s|.*|DGB_DATA_DISKUSED_TEST_HR=\"$DGB_DATA_DISKUSED_TEST_HR\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_TEST_KB=/s|.*|DGB_DATA_DISKUSED_TEST_KB=\"$DGB_DATA_DISKUSED_TEST_KB\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_TEST_PERC=/s|.*|DGB_DATA_DISKUSED_TEST_PERC=\"$DGB_DATA_DISKUSED_TEST_PERC\"|" $DGNT_SETTINGS_FILE
                        DGB2_BLOCKSYNC_VALUE=""
                        sed -i -e "/^DGB2_BLOCKSYNC_VALUE=/s|.*|DGB2_BLOCKSYNC_VALUE=\"$DGB2_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
                        DGB_BLOCKSYNC_VALUE=""
                        sed -i -e "/^DGB_BLOCKSYNC_VALUE=/s|.*|DGB_BLOCKSYNC_VALUE=\"$DGB_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi

                else
                    printf "%b You chose to keep the existing DigiByte TESTNET blockchain data.\\n" "${INFO}"
                fi

            fi

            # Only prompt to delete the regtest blockchain data if it already exists
            if [ -d "$DGB_DATA_LOCATION/regtest/indexes" ] || [ -d "$DGB_DATA_LOCATION/regtest/chainstate" ] || [ -d "$DGB_DATA_LOCATION/regtest/blocks" ]; then

                # Delete DigiByte blockchain data
                if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete DigiByte REGTEST blockchain" --title "DigiNode Uninstall: Delete DigiByte REGTEST blockchain" --yesno "\n\Z4Would you like to also delete the DigiByte REGTEST blockchain data?\Z0\\n\\nNote: Your regtest wallet will be kept." 10 "${c}"; then

                    # Delete systemd service file
                    if [ -d "$DGB_DATA_LOCATION/regtest" ]; then
                        str="Deleting DigiByte Core REGTEST blockchain data..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf $DGB_DATA_LOCATION/regtest/indexes
                        rm -rf $DGB_DATA_LOCATION/regtest/chainstate
                        rm -rf $DGB_DATA_LOCATION/regtest/blocks
                        rm -f $DGB_DATA_LOCATION/regtest/banlist.dat
                        rm -f $DGB_DATA_LOCATION/regtest/banlist.json
                        rm -f $DGB_DATA_LOCATION/regtest/digibyted.pid
                        rm -f $DGB_DATA_LOCATION/regtest/fee_estimates.dat
                        rm -f $DGB_DATA_LOCATION/regtest/.lock
                        rm -f $DGB_DATA_LOCATION/regtest/mempool.dat
                        rm -f $DGB_DATA_LOCATION/regtest/peers.dat
                        rm -f $DGB_DATA_LOCATION/regtest/settings.json
                        DGB_DATA_DISKUSED_REGTEST_HR=""
                        DGB_DATA_DISKUSED_REGTEST_KB=""
                        DGB_DATA_DISKUSED_REGTEST_PERC=""
                        sed -i -e "/^DGB_DATA_DISKUSED_REGTEST_HR=/s|.*|DGB_DATA_DISKUSED_REGTEST_HR=\"$DGB_DATA_DISKUSED_REGTEST_HR\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_REGTEST_KB=/s|.*|DGB_DATA_DISKUSED_REGTEST_KB=\"$DGB_DATA_DISKUSED_REGTEST_KB\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_REGTEST_PERC=/s|.*|DGB_DATA_DISKUSED_REGTEST_PERC=\"$DGB_DATA_DISKUSED_REGTEST_PERC\"|" $DGNT_SETTINGS_FILE
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi

                else
                    printf "%b You chose to keep the existing DigiByte REGTEST blockchain data.\\n" "${INFO}"
                fi

            fi

            # Only prompt to delete the signet blockchain data if it already exists
            if [ -d "$DGB_DATA_LOCATION/signet/indexes" ] || [ -d "$DGB_DATA_LOCATION/signet/chainstate" ] || [ -d "$DGB_DATA_LOCATION/signet/blocks" ]; then

                # Delete DigiByte blockchain data
                if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete DigiByte SIGNET blockchain" --title "DigiNode Uninstall: Delete DigiByte SIGNET blockchain" --yesno "\n\Z4Would you like to also delete the DigiByte SIGNET blockchain data?\Z0\\n\\nNote: Your regtest wallet will be kept." 10 "${c}"; then

                    # Delete systemd service file
                    if [ -d "$DGB_DATA_LOCATION/signet" ]; then
                        str="Deleting DigiByte Core SIGNET blockchain data..."
                        printf "%b %s" "${INFO}" "${str}"
                        rm -rf $DGB_DATA_LOCATION/signet/indexes
                        rm -rf $DGB_DATA_LOCATION/signet/chainstate
                        rm -rf $DGB_DATA_LOCATION/signet/blocks
                        rm -f $DGB_DATA_LOCATION/signet/banlist.dat
                        rm -f $DGB_DATA_LOCATION/signet/banlist.json
                        rm -f $DGB_DATA_LOCATION/signet/digibyted.pid
                        rm -f $DGB_DATA_LOCATION/signet/fee_estimates.dat
                        rm -f $DGB_DATA_LOCATION/signet/.lock
                        rm -f $DGB_DATA_LOCATION/signet/mempool.dat
                        rm -f $DGB_DATA_LOCATION/signet/peers.dat
                        rm -f $DGB_DATA_LOCATION/signet/settings.json
                        DGB_DATA_DISKUSED_SIGNET_HR=""
                        DGB_DATA_DISKUSED_SIGNET_KB=""
                        DGB_DATA_DISKUSED_SIGNET_PERC=""
                        sed -i -e "/^DGB_DATA_DISKUSED_SIGNET_HR=/s|.*|DGB_DATA_DISKUSED_SIGNET_HR=\"$DGB_DATA_DISKUSED_SIGNET_HR\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_SIGNET_KB=/s|.*|DGB_DATA_DISKUSED_SIGNET_KB=\"$DGB_DATA_DISKUSED_SIGNET_KB\"|" $DGNT_SETTINGS_FILE
                        sed -i -e "/^DGB_DATA_DISKUSED_SIGNET_PERC=/s|.*|DGB_DATA_DISKUSED_SIGNET_PERC=\"$DGB_DATA_DISKUSED_SIGNET_PERC\"|" $DGNT_SETTINGS_FILE
                        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                    fi

                else
                    printf "%b You chose to keep the existing DigiByte SIGNET blockchain data.\\n" "${INFO}"
                fi

            fi

        else
            printf "%b You chose not to uninstall DigiByte Core.\\n" "${INFO}"
        fi

        printf "\\n"

    fi


    ################## UNINSTALL DIGINODE TOOLS #################################################

    uninstall_motd

    uninstall_diginode_tools_now

    printf " =======================================================================\\n"
    printf " ================== ${txtbgrn}DigiNode Uninstall Completed!${txtrst} ======================\\n"
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
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Remove DigiNode Tools" --title "DigiNode Uninstall: Remove DigiNode Tools" --yesno "\n\Z4Would you like to uninstall DigiNode Tools?\Z0\n\nThis will delete the 'DigiNode Dashboard' and 'DigiNode Setup' scripts." 10 "${c}"; then

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
                if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Delete diginode.settings" --title "DigiNode Uninstall: Delete diginode.settings" --yesno "\n\Z4Would you like to also delete your diginode.settings file?\Z0\n\nThis will remove any customisations you have made to your DigiNode Install." 10 "${c}"; then

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


# Uninstall Custom DigiNode MOTD
uninstall_motd() {

    # Show MOTD uninstall menu if it is installed
    if [ -f "/etc/update-motd.d/50-diginode" ]; then

        printf " =============== Uninstall: DigiNode Custom MOTD =======================\\n\\n"
        # ==============================================================================

        # Remove DigiNode Custom MOTD
        if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Uninstall: Remove DigiNode Custom MOTD" --title "DigiNode Uninstall: Remove DigiNode Custom MOTD" --yesno "\n\Z4Would you like to remove the DigiNode Custom MOTD (Message of the Day)?\Z0\n\nThis is the DigiNode logo that you see whenever you log in to your DigiNode via the terminal. Choosing YES will restore the default system MOTD." 12 "${c}"; then

            printf "%b You chose to remove the DigiNode Custom MOTD.\\n" "${INFO}"

            # Restore system MOTD from backup
            if [ -f "$USER_HOME/.motdbackup/motd" ]; then
                str="Restore system MOTD file from backup..."
                printf "%b %s" "${INFO}" "${str}"
                cp -f $USER_HOME/.motdbackup/motd /etc
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Change system MOTD file owner to root
            if [ -f "/etc/motd" ]; then
                str="Changing system MOTD file owner to root..."
                printf "%b %s" "${INFO}" "${str}"
                chown root:root /etc/motd
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete backup folder for system MOTD
            if [ -d "$USER_HOME/.motdbackup" ]; then
                str="Delete backup folder for system MOTD..."
                printf "%b %s" "${INFO}" "${str}"
                sudo -u $USER_ACCOUNT rm -rf $USER_HOME/.motdbackup
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            # Delete the custom MOTD file to correct location
            if [ -f "/etc/update-motd.d/50-diginode" ]; then
                str="Deleting the DigiNode Custom MOTD file in /etc/update-motd.d..."
                printf "%b %s" "${INFO}" "${str}"
                rm -f /etc/update-motd.d/50-diginode
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
            fi

            MOTD_STATUS="DISABLED"
            sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"DISABLED\"|" $DGNT_SETTINGS_FILE

        else
            printf "%b You chose to keep the DigiNode Custom MOTD.\\n" "${INFO}"

            MOTD_STATUS="DISABLED"
            sed -i -e "/^MOTD_STATUS=/s|.*|MOTD_STATUS=\"ENABLED\"|" $DGNT_SETTINGS_FILE
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

# Download the DigiFacts file from Github (at most once every 24 hours)
download_digifacts() {

    local digifacts_url="https://digifacts.diginode.tools/?lang=en&format=social"
    local digifacts_file="$DGNT_LOCATION/digifacts.json"
    local digifacts_backup_file="$DGNT_LOCATION/digifacts.json.backup"
    local digifacts_temp_file="$DGNT_LOCATION/digifacts.json.temp"
    local diginode_help_file="$DGNT_LOCATION/diginode-help.json"

    if test -f "$digifacts_file"; then
        printf " =============== Checking: DigiFacts ===================================\\n\\n"
        # ==============================================================================
    else
        printf " =============== Installing: DigiFacts =================================\\n\\n"
        # ==============================================================================
    fi

    # If the last download time file doesn't exist, create one with an old timestamp
    if [ "$SAVED_TIME_DIGIFACTS" = "" ]; then
        SAVED_TIME_DIGIFACTS=0
        sed -i -e "/^SAVED_TIME_DIGIFACTS=/s|.*|SAVED_TIME_DIGIFACTS=0|" $DGNT_SETTINGS_FILE
    fi

    local current_time=$(date +%s)  # in seconds

    printf "%b Checking for digifacts.json ...\\n" "${INFO}"

    # Function to download and process the digifacts.json
    download_and_process() {

        # If a temp file exists, delete it
        if test -f "$digifacts_temp_file"; then
            str="Delete existing digifacts.json.temp ..."
            printf "%b %s" "${INFO}" "${str}" 
            sudo -u $USER_ACCOUNT rm -f "$digifacts_temp_file"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # If a backup exists, delete it
        if test -f "$digifacts_backup_file"; then
            str="Delete existing digifacts.json.backup ..."
            printf "%b %s" "${INFO}" "${str}" 
            sudo -u $USER_ACCOUNT rm -f "$digifacts_backup_file"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Rename the existing digifacts.json to digifacts.json.backup, if it exists
        if test -f "$digifacts_file"; then
            str="Create backup of existing digifacts.json ..."
            printf "%b %s" "${INFO}" "${str}" 
            sudo -u $USER_ACCOUNT mv "$digifacts_file" "$digifacts_backup_file"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Download the digifacts.json file
        str="Downloading DigiFacts from DigiByte DigiFacts JSON service ..."
        printf "%b %s" "${INFO}" "${str}"          
        sudo -u $USER_ACCOUNT curl -s -o "$digifacts_file" "$digifacts_url"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # Check if the downloaded file is valid JSON
        str="Is downloaded digifacts.json okay? ..."
        printf "%b %s" "${INFO}" "${str}"
        if test ! -s "$digifacts_file"; then
            if [ -f "$digifacts_file" ]; then
                rm "$digifacts_file"
            fi
            if [ -f "$digifacts_backup_file" ]; then
                mv "$digifacts_backup_file" "$digifacts_file"
            fi
            printf "%b%b %s No! File empty! Backup restored!\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b %bERROR: DigiFacts web server may be down!%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            return 1

        # New: Check for HTML response from Cloudflare
        elif grep -q -i "<!DOCTYPE html>" "$digifacts_file" || grep -q -i "<html" "$digifacts_file"; then
            rm "$digifacts_file"
            if [ -f "$digifacts_backup_file" ]; then
                mv "$digifacts_backup_file" "$digifacts_file"
            fi
            printf "%b%b %s No! Received HTML instead of JSON. Backup restored!\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b %bERROR: DigiFacts service may be unreachable or returning a Cloudflare error.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            return 1

        else
            # If the JSON is valid, delete the backup file (if it exists)
            if [ -f "$digifacts_backup_file" ]; then
                sudo -u $USER_ACCOUNT rm -f "$digifacts_backup_file"
                printf "%b%b %s Yes! Backup deleted!\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"
            fi
        fi

        # Check if the downloaded file is valid JSON
        str="Is downloaded digifacts.json valid json? ..."
        printf "%b %s" "${INFO}" "${str}"
        if sudo -u $USER_ACCOUNT ! jq empty "$digifacts_file" &> /dev/null; then
            rm "$digifacts_file"
            if [ -f "$digifacts_backup_file" ]; then
                mv "$digifacts_backup_file" "$digifacts_file"
            fi
            printf "%b%b %s No! Bad JSON! Backup restored!\\n" "${OVER}" "${CROSS}" "${str}"
            printf "%b %bERROR: DigiFacts.json was bad json. Is service down?%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            return 1
        else
            # If the JSON is valid, delete the backup file (if it exists)
            if [ -f "$digifacts_backup_file" ]; then
                sudo -u $USER_ACCOUNT rm -f "$digifacts_backup_file"
                printf "%b%b %s Yes! Backup deleted!\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"
            fi
        fi

        # Check if the diginode-help.json file is valid JSON
        str="Is the diginode-help.json file valid json? ..."
        printf "%b %s" "${INFO}" "${str}"
        if sudo -u $USER_ACCOUNT ! jq empty "$diginode_help_file" &> /dev/null; then
            printf "%b%b %s No! diginode-help.json file is bad JSON! Please fix it and run again!\\n" "${OVER}" "${CROSS}" "${str}"
            exit 1
        else
            # If the JSON is valid, continue
            printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Remove DigiFact 78 since this promotes DigiNode Tools itself
        str="Remove digifact78, as this describes DigiNode Tools ..."
        printf "%b %s" "${INFO}" "${str}" 
        sudo -u $USER_ACCOUNT jq 'del(.digifact78)' "$digifacts_file" > "$digifacts_temp_file"
        sudo -u $USER_ACCOUNT mv "$digifacts_temp_file" "$digifacts_file"
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

        # If diginode-help.json exists, append its values to digifacts.json
        if [[ -f $diginode_help_file ]]; then
            str="Appending diginode-help.json to digifacts.json ..."
            printf "%b %s" "${INFO}" "${str}" 
            sudo -u $USER_ACCOUNT rm -f "$digifacts_temp_file"
            sudo -u $USER_ACCOUNT touch "$digifacts_temp_file"
            sudo -u $USER_ACCOUNT jq -s '.[0] + .[1]' "$digifacts_file" "$diginode_help_file" > "$digifacts_temp_file"
            sudo -u $USER_ACCOUNT rm -f "$digifacts_file"
            sudo -u $USER_ACCOUNT mv "$digifacts_temp_file" "$digifacts_file"
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Update the last download timestamp
        SAVED_TIME_DIGIFACTS=$current_time
         sed -i -e "/^SAVED_TIME_DIGIFACTS=/s|.*|SAVED_TIME_DIGIFACTS=\"$SAVED_TIME_DIGIFACTS\"|" $DGNT_SETTINGS_FILE
    }

    # Important Note: If you are testing this using the --dgntdev flag, remember that the DigiNode Tools folder
    # gets deleted every time the script runs, also deleting the digifacts.json file along with it. This means
    # that the DigiFacts will be re-downloaded from scratch every time. It will never be upgraded.

    if test ! -e "$digifacts_file"; then
        printf "%b digifacts.json does not exist and will be downloaded...\\n" "${INFO}"
        download_and_process
    elif (( current_time - SAVED_TIME_DIGIFACTS >= 3600 )); then
        printf "%b digifacts.json will be upgraded...\\n" "${INFO}"
        download_and_process
    else
        printf "%b digifacts.json will not be updated - updates occur at most once every hour.\\n" "${INFO}"
    fi

    printf "\\n"

}


# Choose a random digifact and store the result in two variables - digifact_title and digifact_content
digifact_randomize() {

    local digifacts_file="$DGNT_LOCATION/digifacts.json"

    if [[ -f $digifacts_file ]]; then

        # Get all keys from the JSON file into a bash array
        local keys=($(jq -r 'keys[]' "$digifacts_file"))

        # Count the number of keys (digifacts) in the JSON file
        local count=${#keys[@]}

        # Generate a random number between 0 (inclusive) and the number of keys (exclusive)
        local random_index=$(( RANDOM % count ))

        # Fetch the key corresponding to the random index
        local random_key="${keys[$random_index]}"

        # Ensure the new random digifact doesn't match the previous one
        while [ "$random_key" == "$last_digifact_key" ]; do
            random_index=$(( RANDOM % count ))
            random_key="${keys[$random_index]}"
        done

        # Update the last shown digifact key
        last_digifact_key="$random_key"  # changed from local to global to remember the last key

        # Update the global digifact_title and digifact_content variables
        digifact_title=$(jq -r ".\"$random_key\".title" "$digifacts_file")
        digifact_content=$(jq -r ".\"$random_key\".content" "$digifacts_file")

        # Replace \n in string with <br> temporaily so it does not get interpreted prematurely
        digifact_content="${digifact_content//<br>/\\n}"

        # Declare the variable inside the function, right at the end
        generate_digifact_box="yes"

    fi
}


# format_bordered_paragraph (used for DigiFacts)
#
# Formats a given text to fit within a bordered box. The box adjusts based on either
# the terminal width or a user-defined fixed width. The function ensures that the right
# border of the box is always visible, even if the terminal width is smaller than the box width.
# Additionally, the content can optionally be centered within the terminal.
#
# Usage:
#     format_bordered_paragraph <text> <first_left_str> <subsequent_left_str> <right_str> [<width_mode>] [<fixed_width>] [<alignment>]
#
# Arguments:
#     text                : The main content that will be displayed within the box.
#     first_left_str      : The left border string for the first line.
#     subsequent_left_str : The left border string for all lines after the first.
#     right_str           : The right border string for all lines.
#     width_mode          : (Optional) Can be 'terminal_width' or 'fixed_width'. 
#                           Defaults to 'terminal_width' if not provided.
#     fixed_width         : (Optional) Specifies the total width of the box when width_mode is 'fixed_width'.
#                           If width_mode is 'fixed_width' and this argument isn't provided, it defaults to terminal width.
#     alignment           : (Optional) Can be 'left' or 'center'. Specifies the alignment of the box 
#                           relative to the terminal. If 'center' and the terminal width is greater 
#                           than the fixed width, the box will be centered. Defaults to 'left'.
#
# Examples:
#     format_bordered_paragraph "$digifact_content" " ║ HEADER ║  " " ║       ║  " "  ║ " "fixed_width" 120
#     format_bordered_paragraph "$digifact_content" " ║ HEADER ║  " " ║       ║  " "  ║ " "fixed_width" 120 "center"
#     format_bordered_paragraph "$digifact_content" " ║ HEADER ║  " " ║       ║  " "  ║ "


format_bordered_paragraph() {
    local text="$1"
    local first_left_str="$2"
    local subsequent_left_str="$3"
    local right_str="$4"
    local width_mode="${5:-terminal_width}"  # Default to terminal_width
    local fixed_width="${6:-100}"            # Default fixed width if not provided
    local alignment="${7:-left}"             # Default alignment is left

    declare -a LINES
    local idx=0

    # Replace \n with <br> temporarily
    text="${text//\\n/<br>}"

    # Handle variable replacement using parameter expansion
    while [[ "$text" =~ \$([a-zA-Z_][a-zA-Z_0-9]*) ]]; do
        local varname="${BASH_REMATCH[1]}"
        local varvalue=$(eval "echo \$$varname")
        text="${text//\$$varname/$varvalue}"
    done

    # Convert <br> back to new lines to break text into segments
    mapfile -t segments <<< "${text//<br>/$'\n'}"

    local isFirstLine=true

    for segment in "${segments[@]}"; do
        idx=0
        LINES=()  # Clear the LINES array for each segment

        local terminal_width
        if [[ "$width_mode" == "terminal_width" ]]; then
            terminal_width=$(tput cols)
        else
            terminal_width=$fixed_width
        fi

        local space_for_text_first=$(( terminal_width - ${#first_left_str} - ${#right_str} ))
        local space_for_text_subsequent=$(( terminal_width - ${#subsequent_left_str} - ${#right_str} ))

        if [[ "$alignment" == "center" ]]; then
            local padding=$(( (terminal_width - fixed_width) / 2 ))
            padding=$(( padding > 0 ? padding : 0 ))

            first_left_str=$(printf "%${padding}s%s" "" "$first_left_str")
            subsequent_left_str=$(printf "%${padding}s%s" "" "$subsequent_left_str")
            right_str=$(printf "%s%${padding}s" "$right_str" "")
        else
            if (( $terminal_width > $(tput cols) )); then
                terminal_width=$(tput cols)
                space_for_text_first=$(( terminal_width - ${#first_left_str} - ${#right_str} ))
                space_for_text_subsequent=$(( terminal_width - ${#subsequent_left_str} - ${#right_str} ))
            fi
        fi

        read -ra words <<< "$segment"
        local line=""
        local current_space_for_text=$space_for_text_first

        for word in "${words[@]}"; do
            if (( ${#line} + ${#word} + 1 <= current_space_for_text )); then
                [ -n "$line" ] && line="$line $word" || line="$word"
            else
                while (( ${#line} < current_space_for_text )); do
                    line="$line "
                done
                LINES[idx++]="$line"
                line="$word"
                current_space_for_text=$space_for_text_subsequent
            fi
        done
        while (( ${#line} < current_space_for_text )); do
            line="$line "
        done
        [ -n "$line" ] && LINES[idx++]="$line"

        if $isFirstLine; then
            echo "$first_left_str${LINES[0]}$right_str"
            isFirstLine=false
        else
            echo "$subsequent_left_str${LINES[0]}$right_str"
        fi

        for i in $(seq 1 $((idx-1))); do
            echo "$subsequent_left_str${LINES[i]}$right_str"
        done
    done
}


#######################################
# Formats and prints a centered title with borders.
# Arguments:
#   1. Title string to be displayed.
#   2. Left border string.
#   3. Right border string.
#   4. Width mode (optional, default: "terminal_width"). Use "fixed_width" to specify a fixed width.
#   5. Fixed width (optional, default: 100). Specify width if using "fixed_width" mode.
# Example:
#   format_bordered_title "$digifact_title" "║ " " ║"
# Output:
#   ║     DIGIFACT TITLE     ║
#######################################
format_bordered_title() {
    local title="$1"
    local left_str="$2"
    local right_str="$3"
    local width_mode="${4:-terminal_width}"  # Default to terminal_width
    local fixed_width="${5:-100}"            # Default fixed width if not provided

    local terminal_width
    if [[ "$width_mode" == "terminal_width" ]]; then
        terminal_width=$(tput cols)
    else
        terminal_width=$fixed_width
    fi

    # Calculate total available space for the title (subtracting space taken up by left and right strings)
    local space_for_text=$(( terminal_width - ${#left_str} - ${#right_str} ))

    # Calculate the amount of padding needed on each side of the title to center it
    local padding_left=$(( (space_for_text - ${#title}) / 2 ))
    local padding_right=$(( space_for_text - padding_left - ${#title} ))

    # Construct the padded title string
    local padded_title=$(printf "%${padding_left}s%s%${padding_right}s" "" "$title" "")

    # Print the final bordered title
    echo "$left_str$padded_title$right_str"
}


# Display the DigiFact fixed width box
display_digifact_fixedwidth() {

if [ "$digifact_content" != "" ]; then
    printf "  ╔═════════════════════════════════════════════════════════════════════╗\\n"
    printf "  ║ " && printf "%-66s %-4s\n" "              $digifact_title" " ║"
    printf "  ╠═════════════════════════════════════════════════════════════════════╣\\n"

    format_bordered_paragraph "$digifact_content" "  ║ " "  ║ " "  ║ " "fixed_width" 74

    printf "  ╚═════════════════════════════════════════════════════════════════════╝\\n"

    printf "\\n"

fi

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
    if dialog --no-shadow --keep-tite --colors --backtitle "Install Argon One Daemon" --title "Install Argon One Daemon" --yes-label "Continue" --no-label "Exit"  --yesno "\n\Z4Would you like to install the Argon One Daemon?\Z0\n\nThis software is used to manage the fan on the Argon ONE M.2 Case for the Raspberry Pi 4. It will also work with the Argon Artik Fan Hat. If are not using these devices, do not install the software.\n\nMore info: https://github.com/iandark/argon-one-daemon" 13 "${c}"; then
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
    if dialog --no-shadow --keep-tite --colors --backtitle "Upgrade Argon One Daemon" --title "Upgrade Argon One Daemon" --yes-label "Continue" --no-label "Exit"  --yesno "\n\Z4Would you like to upgrade the Argon One Daemon?\Z0\n\nThis software is used to manage the fan on the Argon ONE M.2 Case for the Raspberry Pi 4.\n\nMore info: https://github.com/iandark/argon-one-daemon" 12 "${c}"; then
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
    sudo -u $USER_ACCOUNT git clone --depth 1 --quiet https://github.com/kowalski7cc/argon-one-daemon $USER_HOME/argon-one-daemon 2>/dev/null

    # If the command completed without error, then assume IPFS downloaded correctly
    if [ $? -eq 0 ]; then
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "\\n"
        printf "%b%b ${txtred}ERROR: Argone One Daemon Download Failed!${txtrst}\\n" "${OVER}" "${CROSS}"
        printf "\\n"
        printf "%b Argon One Daemon could not be downloaded. Perhaps the download URL has changed?\\n" "${INFO}"
        printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
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
        printf "%b Please contact $SOCIAL_BLUESKY_HANDLE on Bluesky so a fix can be issued: $SOCIAL_BLUESKY_URL\\n" "${INDENT}"
        printf "%b Alternatively, contact DigiNode Tools support on Telegram: $SOCIAL_TELEGRAM_URL\\n" "${INDENT}"
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

# Script to purge the old digiasset node

purge_old_digiasset_node() {

    printf " =============== PURGING LEGACY DIGIASSET NODE =========================\\n\\n"
    # ==============================================================================

    printf "%b If present, the legacy DigiAsset Node will be removed.\\n" "${INFO}"

    # Display the uninstall DigiNode title if it needs to be uninstalled
    if [ -f "$DGA_SETTINGS_FILE" ] || [ -d "$DGA_INSTALL_LOCATION" ]; then

        # If we are NOT running unattended, display the message that DigiAsset Node legacy will be removed
 #       if [[ "${UnattendedUpgrade}" == false ]]; then

            dialog --no-shadow --keep-tite --colors --backtitle "IMPORTANT - Please Read!" --title "IMPORTANT - Please Read!" --msgbox "\n\Z1IMPORTANT: The existing DigiAsset Node will now be uninstalled. \Z0\\n\\nThe legacy DigiAsset Node software has not been functioning correctly for some time and has therefore been retired - it will now be removed from your DigiNode. Support for the new DigiAsset Core, which is a complete rewrite of the DigiAsset software, will be added in an upcoming release." 13 ${c}

 #       fi

        printf "%b DigiAsset Node will be purged from the system since it has been retired.\\n" "${INFO}"
        printf "%b DigiAsset Core will added in a future update.\\n" "${INFO}"
        printf "\\n"

        printf " =============== Uninstall: DigiAsset Node =============================\\n\\n"
        # ==============================================================================

        # Stop digiasset PM2 service
        printf "Deleting DigiAsset Node PM2 service...\\n"
        sudo -u $USER_ACCOUNT pm2 delete digiasset
        printf "\\n"

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
        str="Deleting ~/.jsipfs settings folder..."
        printf "%b %s" "${INFO}" "${str}"
        rm -r $USER_HOME/.jsipfs
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If SYSTEMD service file already exists, stop it and delete it
    if [ -f "$PM2_SYSTEMD_SERVICE_FILE" ]; then

        # Stop the service now
        systemctl stop "pm2-$USER_ACCOUNT"

        # Disable the service now
        systemctl disable "pm2-$USER_ACCOUNT"

        str="Deleting PM2 systemd service file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $PM2_SYSTEMD_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # If UPSTART service file already exists, stop it and delete it
    if [ -f "$PM2_UPSTART_SERVICE_FILE" ]; then

        # Stop the service now
        service "pm2-$USER_ACCOUNT" stop

        # Disable the service now
        service "pm2-$USER_ACCOUNT" disable

        str="Deleting PM2 upstart service file..."
        printf "%b %s" "${INFO}" "${str}"
        rm -f $PM2_UPSTART_SERVICE_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Get the local version number of Node.js (this will also tell us if it is installed)
    NODEJS_VER_LOCAL=$(nodejs --version 2>/dev/null | sed 's/v//g')

    if [ "$NODEJS_VER_LOCAL" = "" ]; then
        NODEJS_STATUS="not_detected"
        sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
    else
        NODEJS_STATUS="installed"
        sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=\"$NODEJS_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
    fi


    # Ask to uninstall Node.js if it exists
    if [ -f /etc/apt/keyrings/nodesource.gpg ] || [ -f /etc/apt/sources.list.d/nodesource.list ] || [ "$NODEJS_STATUS" = "installed" ]; then

        # Deleting deb repository
        if [ -f /etc/apt/sources.list.d/nodesource.list ]; then 

            printf " =============== Uninstall: Node.js ====================================\\n\\n"
            # ==============================================================================

            str="Deleting Nodesource deb repository..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f /etc/apt/sources.list.d/nodesource.list
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Deleting gpg key
        if [ -f /etc/apt/keyrings/nodesource.gpg ]; then 
            str="Deleting Nodesource GPG key..."
            printf "%b %s" "${INFO}" "${str}"
            rm -f /etc/apt/keyrings/nodesource.gpg
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        # Delete Node.js packages
        if [ "$NODEJS_STATUS" = "installed" ]; then
            if [ "$LINUX_ID" = "ubuntu" ] || [ "$LINUX_ID" = "debian" ]; then
                printf "%b Uninstalling Node.js packages...\\n" "${INFO}"
                sudo apt-get purge nodejs -y -q
            elif [ "$PKG_MANAGER" = "yum" ] || [ "$PKG_MANAGER" = "dnf" ]; then
                printf "%b Uninstalling Node.js packages...\\n" "${INFO}"
                yum remove nodejs -y
                str="Deleting Nodesource key for Enterprise Linux..."
                printf "%b %s" "${INFO}" "${str}"
                rm -rf /etc/yum.repos.d/nodesource*.repo
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
                yum clean all -y
            fi
            NODEJS_STATUS="not_detected"
            NODEJS_VER_LOCAL=""
            delete_nodejs="yes"
            sed -i -e "/^NODEJS_VER_LOCAL=/s|.*|NODEJS_VER_LOCAL=|" $DGNT_SETTINGS_FILE
            NODEJS_INSTALL_DATE=""
            sed -i -e "/^NODEJS_INSTALL_DATE=/s|.*|NODEJS_INSTALL_DATE=|" $DGNT_SETTINGS_FILE
            NODEJS_UPGRADE_DATE=""
            sed -i -e "/^NODEJS_UPGRADE_DATE=/s|.*|NODEJS_UPGRADE_DATE=|" $DGNT_SETTINGS_FILE
        fi

        # Reset Nodesource repo variable in diginode.settings so it will run again
        sed -i -e "/^NODEJS_REPO_ADDED=/s|.*|NODEJS_REPO_ADDED=\"NO\"|" $DGNT_SETTINGS_FILE

        # Delete .npm settings
        if [ -d "$USER_HOME/.npm" ]; then
                str="Deleting ~/.npm settings folder..."
                printf "%b %s" "${INFO}" "${str}"
                rm -r $USER_HOME/.npm
                printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi 

    printf "\\n"
    fi

    ################## UNINSTALL IPFS #################################################

    # Get the local version number of IPFS Kubo (this will also tell us if it is installed)
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

        printf " =============== Uninstall: IPFS Kubo ==================================\\n\\n"
        # ==============================================================================

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
            str="Deleting current IPFS Kubo binary: /usr/local/bin/ipfs..."
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

        # Delete IPFS settings
        if [ -d "$USER_HOME/.ipfs" ]; then
            str="Deleting ~/.ipfs settings folder..."
            printf "%b %s" "${INFO}" "${str}"
            rm -r $USER_HOME/.ipfs
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi

        printf "\\n"
    fi

}


add_tor_repository() {

    # This need to be updated if/when the Tor GPG public key changes
    LATEST_TOR_GPG_KEY="A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc"

    # Install the Tor Project gpg key, if it does not already exist OR if Tor is using a new Key
    if [ ! -f "/usr/share/keyrings/torproject-archive-keyring.gpg" ] || [ "$INSTALLED_TOR_GPG_KEY" != "$LATEST_TOR_GPG_KEY" ]; then
        
        # Delete old GPG if it exists
        if [ -f "/usr/share/keyrings/torproject-archive-keyring.gpg" ]; then
            rm -f /usr/share/keyrings/torproject-archive-keyring.gpg
            printf "%b Deleted existing Tor Project GPG key.\\n" "${INFO}"
        fi

        wget -qO- https://deb.torproject.org/torproject.org/$LATEST_TOR_GPG_KEY | gpg --dearmor | tee /usr/share/keyrings/torproject-archive-keyring.gpg >/dev/null

        # Remember installed Tor GPG key
        INSTALLED_TOR_GPG_KEY="A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc"
        sed -i -e "/^INSTALLED_TOR_GPG_KEY=/s|.*|INSTALLED_TOR_GPG_KEY=\"$INSTALLED_TOR_GPG_KEY\"|" $DGNT_SETTINGS_FILE

        printf "%b Installed Tor Project GPG public key.\\n" "${INFO}"
    fi

    # Determine the distribution codename
    DIST_CODENAME=$(lsb_release -sc)

    # Determine the architecture
    TORARCH=$(dpkg --print-architecture)

    # Define the repository entry based on architecture
    if [ "$TORARCH" == "arm64" ]; then
        REPO_ENTRY="deb [arch=arm64 signed-by=/usr/share/keyrings/torproject-archive-keyring.gpg] https://deb.torproject.org/torproject.org/ $DIST_CODENAME main"
    elif [ "$TORARCH" == "amd64" ]; then
        REPO_ENTRY="deb [arch=amd64 signed-by=/usr/share/keyrings/torproject-archive-keyring.gpg] https://deb.torproject.org/torproject.org/ $DIST_CODENAME main"
    else
        printf "%b Unsupported architecture: $TORARCH. Exiting.\\n" "${ERROR}"
        exit 1
    fi

    # Define the file path
    FILE_PATH="/etc/apt/sources.list.d/torproject.list"

    # Check if the file exists and contains the repository entry
    if ! grep -Fxq "$REPO_ENTRY" $FILE_PATH 2>/dev/null; then
        # Add the repository entry if it does not exist
        echo "$REPO_ENTRY" | sudo tee $FILE_PATH
        printf "%b Tor Project repository added.\\n" "${INFO}"
    else
        printf "%b Tor Project repository is already added.\\n" "${INFO}"
    fi

    printf "\\n"

}

# Update the Tor config file to enable the Tor Control Port (if needed) and start the Tor service, if it is not running
enable_tor_service() {

    printf " =============== Checking: Tor System Service ==========================\\n\\n"
    # ==============================================================================

    TOR_CONFIG_FILE=/etc/tor/torrc
    TOR_CONFIG_UPDATED="NO"
    local torrc_controlport_ok=""
    local torrc_cookieauth_ok=""
    local torrc_cookieauthgr_ok=""
    local is_user_in_tor_group=""

    # Check if tor is running, and if either DigiByte node is running on it
    systemctl is-active --quiet tor && TOR_STATUS="running" || TOR_STATUS="not_running" 

    # Create Torrc config file if it does not exist
    if [ ! -f "$TOR_CONFIG_FILE" ]; then
        str="Creating $TOR_CONFIG_FILE config file..."
        printf "%b %s" "${INFO}" "${str}"
        touch $TOR_CONFIG_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Check for "ControlPort 9151" line in torrc, otherwise uncomment/append it
    if ! grep -q -Fx "ControlPort 9151" $TOR_CONFIG_FILE; then
        if grep -q ^"#ControlPort 9151" $TOR_CONFIG_FILE; then
            echo "$INDENT   Updating torrc: ControlPort 9151"
            sed -i -e "/^#ControlPort 9151/s|.*|ControlPort 9151|" $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"
        elif grep -q ^"# ControlPort 9151" $TOR_CONFIG_FILE; then
            echo "$INDENT   Updating torrc: ControlPort 9151"
            sed -i -e "/^# ControlPort 9151/s|.*|ControlPort 9151|" $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"
        else
            echo "$INDENT   Appending to torrc: ControlPort 9151"
            sed -i '$a ControlPort 9151' $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"              
        fi
    else
        torrc_controlport_ok="yes"
    fi

    # Check for "CookieAuthentication 1" line in torrc, otherwise uncomment/append it
    if ! grep -q -Fx "CookieAuthentication 1" $TOR_CONFIG_FILE; then
        if grep -q ^"#CookieAuthentication 1" $TOR_CONFIG_FILE; then
            echo "$INDENT   Updating torrc: CookieAuthentication 1"
            sed -i -e "/^#CookieAuthentication 1/s|.*|CookieAuthentication 1|" $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"
        elif grep -q ^"# CookieAuthentication 1" $TOR_CONFIG_FILE; then
            echo "$INDENT   Updating torrc: CookieAuthentication 1"
            sed -i -e "/^# CookieAuthentication 1/s|.*|CookieAuthentication 1|" $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"
        else
            echo "$INDENT   Appending to torrc: CookieAuthentication 1"
            sed -i '$a CookieAuthentication 1' $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"               
        fi
    else
        torrc_cookieauth_ok="yes"
    fi

    # Check for "CookieAuthFileGroupReadable 1" line in torrc, otherwise uncomment/append it
    if ! grep -q -Fx "CookieAuthFileGroupReadable 1" $TOR_CONFIG_FILE; then
        if grep -q ^"#CookieAuthFileGroupReadable 1" $TOR_CONFIG_FILE; then
            echo "$INDENT   Updating torrc: CookieAuthFileGroupReadable 1"
            sed -i -e "/^#CookieAuthFileGroupReadable 1/s|.*|CookieAuthFileGroupReadable 1|" $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"
        elif grep -q ^"# CookieAuthFileGroupReadable 1" $TOR_CONFIG_FILE; then
            echo "$INDENT   Updating torrc: CookieAuthFileGroupReadable 1"
            sed -i -e "/^# CookieAuthFileGroupReadable 1/s|.*|CookieAuthFileGroupReadable 1|" $TOR_CONFIG_FILE
            TOR_CONFIG_UPDATED="YES"
        else
            echo "$INDENT   Appending to torrc: CookieAuthFileGroupReadable 1"
            sed -i '/CookieAuthentication 1/ i \
CookieAuthFileGroupReadable 1' $TOR_CONFIG_FILE 
            TOR_CONFIG_UPDATED="YES"               
        fi
    else
        torrc_cookieauthgr_ok="yes"
    fi

    # Is the Tor service already correctly configured?
    if [ "$torrc_controlport_ok" = "yes" ] && [ "$torrc_cookieauth_ok" = "yes" ] && [ "$torrc_cookieauthgr_ok" = "yes" ]; then
        printf "%b Torrc configuration is correct. Tor Control port is Enabled.\\n" "${TICK}"
    fi

    # Is the user account in the debian-tor group
    str="Is the user account ($USER_ACCOUNT) already added to the debian-tor user group?..."
    printf "%b %s" "${INFO}" "${str}"
    is_user_in_tor_group=$(groups $USER_ACCOUNT | grep -Eo "debian-tor")
    if [ "$is_user_in_tor_group" = "debian-tor" ]; then
        is_user_in_tor_group="yes"
        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
    else
        is_user_in_tor_group="no"
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
    fi 

    # Add user to debian-tor group, if needed
    if [ "$is_user_in_tor_group" = "no" ]; then
        str="Adding user account ($USER_ACCOUNT) to debian-tor user group ..."
        printf "%b %s" "${INFO}" "${str}"
        usermod -aG debian-tor $USER_ACCOUNT
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        if [ "$TOR_STATUS" = "running" ] && [ "$TOR_CONFIG_UPDATED" != "YES" ]; then
            str="Restarting Tor service..."
            printf "%b %s" "${INFO}" "${str}"
            systemctl restart tor
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        fi
    fi


    # Stop the Tor service if it has been changed, and it is running
    if [ "$TOR_STATUS" = "running" ] && [ "$TOR_CONFIG_UPDATED" = "YES" ]; then
        str="Restarting Tor service..."
        printf "%b %s" "${INFO}" "${str}"
        systemctl restart tor
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    if [ "$TOR_STATUS" = "not_running" ]; then
        str="Enabling and starting Tor service..."
        printf "%b %s" "${INFO}" "${str}"
        systemctl enable --now -q tor
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    # Check Tor service is running
    str="Is the Tor service running?..."
    printf "%b %s" "${INFO}" "${str}"
    systemctl is-active --quiet tor && TOR_STATUS="running" || TOR_STATUS="not_running" 
    if [ "$TOR_STATUS" = "running" ]; then
        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
    else
        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
    fi

    printf "\\n"

}


#####################################################################################################
### FUNCTIONS - MAIN - THIS IS WHERE THE HEAVY LIFTING HAPPENS
#####################################################################################################


main() {

    # Display the help screen if the --help or -h flags have been used
    display_help

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

        # Display if the release/pre-release version of DigiByte Core has been specifically requested
        is_dgb_prerelease_mode

        # Display a message if Verbose Mode is enabled
        is_verbose_mode

        # Display a message if Reset Mode is enabled. Quit if Reset and Unattended Modes are enable together.
        is_reset_mode 

        # Display a message if DigiAsset Node developer mode is enabled
        is_dgadev_mode

        # Display a message if Update Test was requested. Strictly for DigiNode development only. (Do not use! It might break stuff!)
        is_update_test

        # Display a message if the user has requested to skip hash verifcation of downloaded binarys. For emergency use only.
        is_skip_hash

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
        printf "%b requirement. Make sure to run this script from a trusted source.\\n\\n" "${INDENT}"
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

    # Check for Raspberry Pi hardware
    rpi_check

    # Add Tor repository
    add_tor_repository

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
        printf "%b An existing install of DigiByte Core was discovered, but it was not\\n" "${INDENT}"
        printf "%b originally installed using DigiNode Setup and so cannot be upgraded.\\n" "${INDENT}"
        printf "%b Please start with with a clean Linux installation.\\n" "${INDENT}"
        printf "\\n"
        printf "%b DigiByte Node Location: $UNOFFICIAL_DIGIBYTE_NODE_LOCATION\\n" "${INFO}"
        printf "\\n"

        # If DigiNode Tools is installed, offer to check for an update
        if [ -f "$DGNT_MONITOR_SCRIPT" ]; then
            
            printf " =============== DIGINODE SETUP - MAIN MENU ============================\\n\\n"
            # ==============================================================================

            opt1a="1 Update"
            opt1b="Check for updates to DigiNode Tools"
            
            opt2a="2 Uninstall"
            opt2b="Remove DigiNode Tools from your system"


            # Display the information to the user
            UpdateCmd=$(dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Setup - Main Menu" --title "DigiNode Setup - Main Menu" --cancel-label "Exit" --menu "\nAn existing DigiByte Node was discovered on this system, but since DigiNode Setup was not used to set it up originally, it cannot be used to manage it.\n\nDigiByte Node Location: $UNOFFICIAL_DIGIBYTE_NODE_LOCATION\n\nYou can check for updates to DigiNode Tools itself to upgrade the DigiNode Dashboard. You can also choose to Uninstall DigiNode Tools.\n\nTo learn more about DigiNode Tools, and how it can be used to setup and manage a DigiByte & DigiAsset Node, visit: $DGNT_WEBSITE_URL\n\nPlease choose an option:\n\n" 23 "${c}" 2 \
            "${opt1a}"  "${opt1b}" \
            "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
            { printf "%b %bExit was selected.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"; printf "\\n"; digifact_randomize; display_digifact_fixedwidth; printf "\\n"; exit; }

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
                    display_digifact_fixedwidth
                    donation_qrcode
                    printf "\\n"
                    exit
                    ;;
            esac
            printf "\\n"

        # If DigiNode Tools is not installed), offer to install them
        else
            if dialog --no-shadow --keep-tite --colors --backtitle "DigiNode Setup - Main Menu" --title "DigiNode Setup - Main Menu"  --yesno "\nWould you like to install DigiNode Tools?\\n\\nAn existing DigiByte Node was discovered on this system, but since DigiNode Setup was not used to set it up originally, it cannot be used to manage it.\\n\\nDigiByte Node Location: $UNOFFICIAL_DIGIBYTE_NODE_LOCATION\\n\\nYou can install DigiNode Tools, so you can use the DigiNode Dashboard with your existing DigiByte Node. Would you like to do that now?" 17 "${c}"; then

                install_diginode_tools_only

            else
                printf "%b Exiting: You chose not to install DigiNode Tools.\\n" "${INFO}"
                printf "\\n"
                digifact_randomize
                display_digifact_fixedwidth
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

    # Display Disclaimer
    disclaimerDialog

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
 #!!   if [[ "${UnattendedUpgrade}" == false ]]; then

        # Ask to install DigiAssets Node, it is not already installed
 #!!       menu_ask_install_digiasset_node

  #!!  fi

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
    check_digibyte_core

    # Check if DNSU is installed, and if there is an upgrade available
#!!   check_dnsu

    # Check if IPFS installed, and if there is an upgrade available
#!!    ipfs_check

    # Check if NodeJS is installed
#!!    nodejs_check

    # Check if DigiAssets Node is installed, and if there is an upgrade available
#!!    digiasset_node_check

    # Check if DigiNode Tools are installed (i.e. these scripts), and if there is an upgrade available
    check_diginode_tools

    # Check if the DigiNode custom MOTD is already installed
    motd_check

    ### UPDATES MENU - ASK TO INSTALL ANY UPDATES ###

    # Ask to install any upgrades, if there are any
    menu_ask_install_updates


    ### ASK SETUP QUESTIONS ###

    # If this is a new install, ask if you user wants to setup a testnet or mainnet DigiByte Node, or a Dual Node
    menu_ask_dgb_network

    # If this is a new install, ask the user if they want to enable or disable tor
    menu_ask_tor

    # If this is a new install, ask the user if they want to enable or disable UPnP for port forwarding
    menu_ask_upnp

    # If this is a new install, ask to install the DigiNode MOTD
    menu_ask_motd


    ### INSTALL/UPGRADE DIGIBYTE CORE ###

    # Create/update digibyte.conf file
    create_digibyte_conf

    # Install/upgrade DigiByte Core
    do_digibyte_install_upgrade

    # Create digibyted.service
    create_digibyte_service

    # Create digibyted.service (if running Dual Node)
    create_digibyte_service_dualnode

    ### INSTALL/UPGRADE DIGINODE TOOLS ###

    # Install DigiNode Tools
    diginode_tools_do_install


    ### INSTALL/UPGRADE DIGIASSETS NODE ###

    # purge old digiasset node software
    purge_old_digiasset_node

    # Install/upgrade IPFS
 #!!   ipfs_do_install

    # Create IPFS service
#!!    ipfs_create_service

    # Install/upgrade NodeJS
#!!    nodejs_do_install

    # Create or update main.json file with RPC credentials
#!!    digiasset_node_create_settings

    # Install DigiAssets along with IPFS
#!!    digiasset_node_do_install

    # Setup PM2 init service
#!!    digiasset_node_create_pm2_service


    ##### INSTALL THE MOTD MESSAGE ########

    # This will install or uninstall the motd message, based on what the user selected in the menu_ask_motd function
    motd_do_install_uninstall


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
        display_digifact_fixedwidth

    fi

    # Display donation QR Code
    donation_qrcode

    # Show final messages - Display reboot message (and how to run DigiNode Dashboard)
    final_messages

    # Share backup reminder
    backup_reminder

    exit

}


if [[ "$RUN_SETUP" != "NO" ]] ; then
    main "$@"
fi
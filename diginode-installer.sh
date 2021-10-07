#!/bin/bash
#
# Name:    DigiNode Installer
# Purpose: Install a DigiByte Node and DigiAsset Metadata server on a compatible linux device.
#          Script has initially been designed to support the Raspberry Pi 4 4Gb & 8Gb models.
#
# Author:  Olly Stedall @saltedlolly
#
# Usage:   Install with this command (from your Linux machine):
#
#          curl http://diginode-installer.digibyte.help | bash 
#
# Updated: October 7 2021 5:53pm GMT
#
# -----------------------------------------------------------------------------------------------------

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# We do not want users to end up with a partially working install, so we exit the script
# instead of continuing the installation with something broken
set -e

# Append common folders to the PATH to ensure that all basic commands are available.
# When using "su" an incomplete PATH could be passed.
export PATH+=':/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

######## VARIABLES #########
# For better maintainability, we store as much information that can change in variables
# This allows us to make a change in one place that can propagate to all instances of the variable
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions
# It's still a work in progress, so you may see some variance in this guideline until it is complete

# Set this to YES to get more verbose feedback. Very useful for debugging.
# Don't set this if sourcing from digimon.sh - it has its own VERBOSE_MODE setting
if [[ "$RUN_INSTALLER" != "NO" ]] ; then
    VERBOSE_MODE="YES"
fi

DGB_INSTALL_FOLDER=$HOME/digibyte/       # Typically this is a symbolic link that points at the actual install folder
DGB_SETTINGS_FOLDER=$HOME/.digibyte/
DGB_CONF_FILE=$DGB_SETTINGS_FOLDER/digibyte.conf

DGA_INSTALL_FOLDER=$HOME/digiasset_node
DGA_CONFIG_FILE=$DGA_INSTALL_FOLDER/_config/main.json

DGN_SCRIPTS_FOLDER=$HOME/diginode
DGN_SETTINGS_FILE=$DGB_SETTINGS_FOLDER/diginode.settings 

# Location for final installation log storage
installLogLoc=$DGN_SCRIPTS_FOLDER/install.log

# This is the URLs where the script is hosted
DGN_INSTALLER_OFFICIAL_URL=https://diginode-installer.digibyte.help
DGN_INSTALLER_GITHUB_REL_URL=https://raw.githubusercontent.com/saltedlolly/diginode/release/diginode-installer.sh
DGN_INSTALLER_GITHUB_DEV_URL=https://raw.githubusercontent.com/saltedlolly/diginode/develop/diginode-installer.sh
DGN_INSTALLER_URL=$DGN_INSTALLER_GITHUB_DEV_URL

DGN_VERSIONS_URL=diginode-versions.digibyte.help    # Used to query TXT record containing compatible OS'es

# This is the command people will enter to run the install script
DGN_INSTALLER_OFFICIAL_CMD="curl $DGN_INSTALLER_OFFICIAL_URL | bash"

# We clone (or update) the DigiNode git repository during the install. This helps to make sure that we always have the latest versions of the relevant files.
DGN_GITHUB_URL="https://github.com/saltedlolly/diginode.git"

# Store total system RAM as variables
RAMTOTAL_KB=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
RAMTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)

# Store current total swap file size as variables
SWAPTOTAL_KB=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
SWAPTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f2)

# Store user in variable
if [ -z "${USER}" ]; then
  USER="$(id -un)"
fi

# If update variable isn't specified, set to false
if [ -z "$useUpdateVars" ]; then
  useUpdateVars=false
fi

# whiptail dialog dimensions: 20 rows and 70 chars width assures to fit on small screens and is known to hold all content.
r=20
c=70


# Set these values so the installer can still run in color
COL_NC='\e[0m' # No Color
COL_LIGHT_GREEN='\e[1;32m'
COL_LIGHT_RED='\e[1;31m'
COL_LIGHT_CYAN='\e[1;96m'
COL_BOLD_WHITE='\e[1;37m'
TICK="  [${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="  [${COL_LIGHT_RED}✗${COL_NC}]"
WARN="  [${COL_LIGHT_CYAN}!${COL_NC}]"
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



#####################################################################################################
### FUNCTIONS
#####################################################################################################

# A simple function that just the installer title in a box
installer_title_box() {
     echo ""
     echo " ╔════════════════════════════════════════════════════════╗"
     echo " ║                                                        ║"
     echo " ║         ${txtbld}D I G I N O D E   I N S T A L L E R${txtrst}            ║ "
     echo " ║                                                        ║"
     echo " ║  Install and configure your DigiByte & DigiAsset Node  ║"
     echo " ║                                                        ║"
     echo " ╚════════════════════════════════════════════════════════╝" 
}

diginode_logo() {
echo ""
echo -e "${txtblu}
                          ƊƊ                       
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
       ƊƊƊƊƊƊƊ    ƊƊ   *ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ     
         ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ       
            ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ          
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   ${COL_NC}"
echo -e "${COL_BOLD_WHITE}       ____   _         _   _   __            __     ${COL_NC}"
echo -e "${COL_BOLD_WHITE}      / __ \ (_)____ _ (_) / | / /____   ____/ /___  ${COL_NC}"
echo -e "${COL_BOLD_WHITE}     / / / // // __ '// / /  |/ // __ \ / __  // _ \ ${COL_NC}"
echo -e "${COL_BOLD_WHITE}    / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/ ${COL_NC}"
echo -e "${COL_BOLD_WHITE}   /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/  ${COL_NC}"
echo -e "${COL_BOLD_WHITE}              /____/                                 ${COL_NC}"
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

    if [ $is_linux = "no" ]; then 
        printf "\\n"
        printf "  %b %bOS is unrecognised or incompatible%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf " %b Running a DigiNode requires a 64-bit OS (aarch64 or X86_64).\\n" "${INFO}"
        printf "%b Ubuntu Server 64-bit is recommended.\\n" "${INDENT}"
        printf "\\n"
        printf "%b If you believe your OS should be supported please contact @saltedlolly\\n" "${INDENT}"
        printf "%b on Twitter including your reported OS type: $OSTYPE\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi

    # Try to establish system architecture, and only continue if it is 64 bit
    local sysarch
    local is_64bit
    sysarch=$(arch)

    # Try and identify 64bit OS's
    if [ "$sysarch" = "aarch64" ]; then
        printf "%b Architecture: %b$sysarch%b" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        ARCH="aarch64"
        is_64bit="yes"
    elif [ "$sysarch" = "arm" ]; then
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
        printf "\\n"
        printf "%b ERROR: %b32-bit OS detected%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b DigiNode Installer requires a 64bit OS (aarch64 or X86_64)" "${INFO}"
        printf "%b Ubuntu Server 64bit is recommended." "${INDENT}"
        printf "\\n"
        printf "%b If you believe your hardware should be supported please contact @saltedlolly" "${INDENT}"
        printf "%b on Twitter letting me know the reported system architecture above." "${INDENT}"
        printf "\\n"
        exit 1
    elif [[ "$is_64bit" == "no" ]]; then
        printf "\\n"
        printf "%b ERROR: %bSystem Architecture unrecognised%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b DigiNode Installer requires a 64bit OS (aarch64 or X86_64)" "${INFO}"
        printf "%b Ubuntu Server 64bit is recommended." "${INDENT}"
        printf "\\n"
        printf "%b If you believe your hardware should be supported please contact @saltedlolly" "${INDENT}"
        printf "%b on Twitter letting me know the reported system architecture above." "${INDENT}"
        printf "\\n"
        exit 1
    fi
}


# Function to check for compatible Raspberry Pi hardware
rpi_check() {

if [ "$VERBOSE_MODE" = "YES" ]; then
    printf "%b Running Raspberry Pi checks..." "${INFO}"
fi

sysarch=$(arch)

if [[ "$sysarch" == "aarch"* ]] || [[ "$sysarch" == "arm"* ]]; then

    if [ "$VERBOSE_MODE" = "YES" ]; then
        printf " ARM hardware detected    [ VERBOSE MODE ]\\n"
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
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi")
    if [ "$pigen" = "Raspberry Pi" ]; then
        pitype="pi"
    fi
   
    # Look for any mention of 'Raspberry Pi 5' so we can narrow it to Pi 5
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 5")
    if [ "$pigen" = "Raspberry Pi 5" ]; then
        pitype="pi5"

    fi

    if [ "$VERBOSE_MODE" = "YES" ]; then
        printf "%b Pi Type: $pitype     [ VERBOSE MODE ]\\n" "${INFO}"
    fi

    # Look for any mention of 'Raspberry Pi 4' so we can narrow it to a Pi 4 
    # even if it is a model we have not seen before
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 4")
    if [ "$pigen" = "Raspberry Pi 4" ]; then
        pitype="pi4"
    fi

    # Assuming it is likely a Pi, lookup the known models of Rasberry Pi hardware 
    if [ "$pitype" != "" ]; then
        if [ "$VERBOSE_MODE" = "YES" ]; then
            printf "%b Looking up known Pi models     [ VERBOSE MODE ]\\n" "${INFO}"
        fi
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
            rpi_ssd_warning
        fi
    elif [ "$pitype" = "pi4" ]; then
        printf "%b Raspberry Pi 4 Detected\\n" "${TICK}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        IS_RPI="YES"
        if [[ "$RUN_INSTALLER" != "NO" ]] ; then
            rpi_ssd_warning
        fi
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
            rpi_ssd_warning
        fi
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
            rpi_ssd_warning
        fi
        
    elif [ "$pitype" = "piold" ]; then
        printf "%b %bRaspberry Pi 2 (or older) Detected%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %b$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bERROR: This Raspberry Pi is too old to run a DigiNode.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b A Raspberry Pi 4 with at least 4Gb is recommended. 8Gb or more is preferred.\\n" "${INDENT}"
        printf "\\n"
        exit 1
    elif [ "$pitype" = "pi" ]; then
        printf "\\n"
        printf "%b %bUnknown Raspberry Pi Detected%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b %bERROR: This Raspberry Pi model cannot be recognised%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b This script is currently unable to recognise your Raspberry Pi.\\n" "${INDENT}"
        printf "%b Presumably this is because it is a new model that it has not seen before.\\n" "${INDENT}"
        printf "\\n"
        printf "%b Please contact @saltedlolly on Twitter including the following information\\n" "${INDENT}"
        printf "%b so that support for it can be added:\\n" "${INDENT}"
        printf "\\n"
        printf "%b Model: %b$MODEL%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Memory: %b$MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Revision: %b$revision%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        exit 1
    fi
else
    if [ "$VERBOSE_MODE" = "YES" ]; then
        printf " ARM hardware not found    [ VERBOSE MODE ]\\n"
    fi
fi
}

# This will display a warning that the Pi must be booting from an SSD card not a microSD
rpi_ssd_warning() {
    # Only display this message if running this install script directly (not when running digimon.sh)
    if [[ "$RUN_INSTALLER" != "NO" ]] ; then
        printf "\\n"
        printf "%b %bIMPORTANT: Make sure you are booting from USB (NOT microSD)!%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b For this installer to work correctly, you must be booting your\\n" "${INDENT}"
        printf "%b Raspberry Pi from an external SSD over USB. Booting from a microSD\\n" "${INDENT}"
        printf "%b card is not supported. If using a Pi 4 or newer, make sure your drive\\n" "${INDENT}"
        printf "%b is connected to a blue USB3 port.\\n" "${INDENT}"
        printf "\\n"
        STARTPAUSE="yes"
    fi
}


#####################################################################################################
### FUNCTIONS - MAIN
#####################################################################################################

main() {

    # show installer title box
    installer_title_box

    ######## FIRST CHECK ########
    # Must be root to install
    local str="Root user check"
    printf "\\n"

    # If the user's id is zero,
    if [[ "${EUID}" -eq 0 ]]; then
        # they are root and all is good
        printf "  %b %s\\n" "${TICK}" "${str}"
        # Show the DigiNode logo
        diginode_logo
        make_temporary_log
    else
        # Otherwise, they do not have enough privileges, so let the user know
        printf "%b %s\\n" "${INFO}" "${str}"
        printf "%b %bScript called with non-root privileges%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b DigiNode Installer requires elevated privileges to get started.\\n" "${INDENT}"
        printf "%b Please review the source code on GitHub for any concerns regarding this requirement\\n" "${INDENT}"
        printf "%b Make sure to download this script from a trusted source\\n\\n" "${INDENT}"
        printf "%b Sudo utility check" "${INFO}"

        # If the sudo command exists, try rerunning as admin
        if is_command sudo ; then
            printf "%b  %b Sudo utility check\\n" "${OVER}"  "${TICK}"

            # when run via curl piping
            if [[ "$0" == "bash" ]]; then
                # Download the install script and run it with admin rights
                exec curl -sSL $DGN_INSTALLER_URL | sudo bash "$@"
            else
                # when run via calling local bash script
                exec sudo bash "$0" "$@"
            fi

            exit $?
        else
            # Otherwise, tell the user they need to run the script as root, and bail
            printf "%b  %b Sudo utility check\\n" "${OVER}" "${CROSS}"
            printf "%b Sudo is needed for the Web Interface to run pihole commands\\n\\n" "${INFO}"
            printf "%b %bPlease re-run this installer as root${COL_NC}\\n" "${INFO}" "${COL_LIGHT_RED}"
            exit 1
        fi
    fi

    # Perform basic OS check and lookup hardware architecture
    sys_check

    # Check for Raspberry Pi hardware
    rpi_check


    #####################################
    echo "Exit script early during testing"
    exit # EXIT HERE DURING TEST
    #####################################

    # Check for supported package managers so that we may install dependencies
    package_manager_detect

    # Notify user of package availability
    notify_package_updates_available

    # Install packages necessary to perform os_check
    printf "%b Checking for / installing Required dependencies for OS Check...\\n" "${INFO}"
    install_dependent_packages "${SYS_CHECK_DEPS[@]}"

    # Check that the installed OS is officially supported - display warning if not
    os_check

    # Install packages used by this installation script
    printf "%b Checking for / installing Required dependencies for this install script...\\n" "${INFO}"
    install_dependent_packages "${INSTALLER_DEPS[@]}"

    #In case of RPM based distro, select the proper PHP version
    if [[ "$PKG_MANAGER" == "yum" || "$PKG_MANAGER" == "dnf" ]] ; then
      select_rpm_php
    fi

    # Check if SELinux is Enforcing
    checkSelinux

    # If the setup variable file exists,
    if [[ -f "${setupVars}" ]]; then
        # if it's running unattended,
        if [[ "${runUnattended}" == true ]]; then
            printf "  %b Performing unattended setup, no whiptail dialogs will be displayed\\n" "${INFO}"
            # Use the setup variables
            useUpdateVars=true
            # also disable debconf-apt-progress dialogs
            export DEBIAN_FRONTEND="noninteractive"
        else
            # If running attended, show the available options (repair/reconfigure)
            update_dialogs
        fi
    fi

    if [[ "${useUpdateVars}" == false ]]; then
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

    # Install packages used by the actual software
    printf "  %b Checking for / installing Required dependencies for Pi-hole software...\\n" "${INFO}"
    install_dependent_packages "${dep_install_list[@]}"
    unset dep_install_list

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





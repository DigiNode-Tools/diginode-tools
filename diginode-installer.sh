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
# Updated: October 7 2021 12:32am GMT
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

DGB_INSTALL_FOLDER=$HOME/digibyte/       # Typically this is a symbolic link that points at the actual install folder
DGB_SETTINGS_FOLDER=$HOME/.digibyte/
DGB_CONF_FILE=$DGB_SETTINGS_FOLDER/digibyte.conf

DGA_INSTALL_FOLDER=$HOME/digiasset_ipfs_metadata_server
DGA_SETTINGS_FILE=$DGA_INSTALL_FOLDER/_config/main.json

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


# A simple function that just the installer title in a box
installer_title_box() {
     clear -x
     echo " ╔════════════════════════════════════════════════════════╗"
     echo " ║                                                        ║"
     echo " ║         ${txtbld}D I G I N O D E   I N S T A L L E R${txtrst}            ║ "
     echo " ║                                                        ║"
     echo " ║     Auto configure your DigiByte & DigiAsset Node      ║"
     echo " ║                                                        ║"
     echo " ╚════════════════════════════════════════════════════════╝" 
     echo ""
}

# Show a disclaimer text during testing phase
installer_disclaimer() {

    # Otherwise, they do not have enough privileges, so let the user know
    printf "%b %bWARNING: This script is still under active development%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b Expect bugs and for it to break things - at times it may\\n" "${INDENT}"
    printf "%b not even run. Currently I recommend running your DigiNode\\n" "${INDENT}"
    printf "%b on a Raspberry Pi 4 8Gb. Start with a clean install of Ubuntu\\n" "${INDENT}"
    printf "%b 64-bit booting from an external SSD driver over USB.\\n" "${INDENT}"
    printf "%b This installer does not support Pi's booting from a microSD card.\\n" "${INDENT}"
    printf "%b %bQUIT NOW if you are running this on anything other than a test system.%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    printf "%b             < Press Ctrl-C to Quit>\\n" "${INDENT}"
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
        printf "  [ %b64-bit OS%b ]\n" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
    else
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


# This will display a warning that the Pi must be booting from an SSD card not a microSD
rpi_ssd_warning() {
     # Only display this message if running this install script directly (not when running digimon.sh)
     if [[ "$RUN_INSTALLER" != "NO" ]] ; then
        printf "\\n"
        printf "%b WARNING: %bMake sure you are booting from USB (NOT microSD)!%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b For this installer to work correctly, you must be booting your" "${INFO}"
        printf "%b Raspberry Pi from an external SSD over USB. Booting from a microSD" "${INDENT}"
        printf "%b card is not supported. For best performance, make sure your drive" "${INDENT}"
        printf "%b is connected to a blue USB3 ports on your Pi." "${INDENT}"
        printf "\\n"
        STARTPAUSE="yes"
    main "$@"
fi
}

# Script to check for compatible Raspberry Pi hardware
rpi_check() {

sysarch=$(arch)

if [ "$sysarch" == "aarch"* ] || [ "$sysarch" == "arm"* ];then

    # Store device model in variable
    MODEL=$(tr -d '\0' < /proc/device-tree/model)

    # Store device revision in local variable (used to work out which Pi model it is)
    local revision
    revision=$(cat /proc/cpuinfo | grep Revision | cut -d' ' -f2)

    # Store total system RAM in whole Gb. Append Gb to number.. (Used for future Pi models we don't know about yet)
    MODELMEM="$(free --giga | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)Gb"

    ######### RPI MODEL DETECTION ###################################

    # Look for any mention of [Raspberry Pi] so we at least know it is a Pi 
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi")
    if [ "$pigen" = "Raspberry Pi" ]; then
        pitype="piunknown"
    fi

    # Look for any mention of [Raspberry Pi 5] so we can narrow it to Pi 5
    # Obviously it doesn't exist yet but we can at least be ready for it
    pigen=$(tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 5")
    if [ "$pigen" = "Raspberry Pi 5" ]; then
        pitype="pi5"
    fi

    # Look for any mention of [Raspberry Pi 4] so we can narrow it to a Pi 4 
    # even if it is a model we have not seen before
    tr -d '\0' < /proc/device-tree/model | grep -Eo "Raspberry Pi 4"
    if [ "$pigen" = "Raspberry Pi 4" ]; then
        pitype="pi4"
    fi

    # Assuming it is likely a Pi, lookup the known models of Rasberry Pi hardware 
    if [ "$pitype" != "" ];then
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
        printf "%b   Model: %$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        rpi_ssd_warning
    elif [ "$pitype" = "pi4" ]; then
        printf "%b Raspberry Pi 4 Detected\\n" "${TICK}"
        printf "%b   Model: %$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        rpi_ssd_warning
    elif [ "$pitype" = "pi4_lowmem" ]; then
        printf "%b Raspberry Pi 4 Detected   [ %bLOW MEMORY DEVICE!!%b ]\\n" "${TICK}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        # hide this part if running digimon
        if [[ "$RUN_INSTALLER" != "NO" ]] ; then
            printf "\\n"
            printf "%b You should be able to run a DigiNode on this Pi but performance may suffer" "${INFO}"   
            printf "%b due to this model only having $MODELMEM RAM. You will need a swap file." "${INDENT}"
            printf "%b A Raspberry Pi 4 with at least 4Gb is recommended. 8Gb or more is preferred." "${INDENT}"
        fi
        rpi_ssd_warning
    elif [ "$pitype" = "pi3" ]; then
        printf "%b Raspberry Pi 3 Detected   [ %bLOW MEMORY DEVICE!!%b ]\\n" "${TICK}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        # hide this part if running digimon
        if [[ "$RUN_INSTALLER" != "NO" ]] ; then
            printf "\\n"
            printf "%b You should be able to run a DigiNode on this Pi but performance may suffer" "${INFO}"   
            printf "%b due to this model only having $MODELMEM RAM. You will need a swap file." "${INDENT}"
            printf "%b A Raspberry Pi 4 with at least 4Gb is recommended. 8Gb or more is preferred." "${INDENT}"
        fi
        rpi_ssd_warning
    elif [ "$pitype" = "piold" ]; then
        printf "%b ERROR: %bIncompatible Raspberry Detected%b ]\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b   Model: %$MODEL $MODELMEM%b\\n" "${INDENT}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b This Raspberry Pi is too old to run a DigiNode." "${INFO}"   
        printf "%b A Raspberry Pi 4 with at least 4Gb is recommended. 8Gb or more is preferred." "${INDENT}"
        printf "\\n"
        exit 1
    elif [ "$pitype" = "piunknown" ]; then
        printf "\\n"
        printf "%b ERROR: %bUnknown Raspberry Pi Detected%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "\\n"
        printf "%b Your Raspberry Pi model cannot be recognised by" "${INFO}"
        printf "%b this script. Please contact @saltedlolly on Twitter" "${INDENT}"
        printf "%b including the following information so it can be added:" "${INDENT}"
        printf "\\n"
        printf "%b Device: %b$MODEL%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Revision: %b$revision%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Memory: %b$MODEL%b\\n" "${INDENT}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "\\n"
        exit 1
    fi
fi
}

is_command() {
    # Checks to see if the given command (passed as a string argument) exists on the system.
    # The function returns 0 (success) if the command exists, and 1 if it doesn't.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}


swap_check() {

    # Store total system RAM in whole Mb.
    SYSMEMMB=$(free --mega | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)

    SYSMEMKB=$(cat /proc/meminfo | tr -s ' ' | sed '/^MemTotal/!d' | cut -d" " -f2)

# Check for swap file if there is less than 8Gb RAM

swaptotal=$(free --mega -h | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f2)
memtotal=

# Workout reccomended Swap file size

if [ $SYSMEM = "1Gb" ]; then
  swaprec=xxx
elif [ $sysmem = "2Gb" ]; then
  swaprec=xxx
elif [ $sysmem = "4Gb" ]; then
  swaprec=xxx
fi

#if [ $sysmem = "1Gb" ]; then  

#  if [ $swaptotaln = '0' ]; then
#    echo "[${txtgrn}✓${txtrst}] RAM Memory - Check for swap file"
#    echo "    RAM: $sysmem   Swap: not found"
#    echo "    Since your system has only $sysmem RAM you need"
#    echo "    to create a swap file in order to run DigiByte Core."
#    echo "    Your swap file of at least."
#    echo ""
#    exit
#  elif [ $swaptotaln -lt '5000' ]; then
#    echo "[${txtgrn}✓${txtrst}] Low RAM - Check for swap file"
#    echo "    RAM: $sysmem   Swap: $swaptotal"
#    echo "    Your swap file is too small for DigiByte Core."
#    echo "    is too small. Please increase it to at least Gb."
#    echo ""
#    exit
#   elif [ $swaptotaln -ge '5000' ]; then
#    echo "[${txtgrn}✓${txtrst}] Low RAM  - Check for swap file"
#    echo "    RAM: $sysmem   Swap: $swaptotal"
#   else 
#  fi 

# elif [ $sysmem = '2Gb' ]; then 

# elif [ $sysmem = '4Gb' ]; then 
   
# else

# fi # end of $sysmem = ?

}


os_check() {
    if [ "$DIGINODE_SKIP_OS_CHECK" != true ]; then
        # This function gets a list of supported OS versions from a TXT record at diginode-versions.digibyte.help
        # and determines whether or not the script is running on one of those systems
        local remote_os_domain valid_os valid_version valid_response detected_os detected_version display_warning cmdResult digReturnCode response
        remote_os_domain=${OS_CHECK_DOMAIN_NAME:-"$DGN_VERSIONS_URL"}

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
                printf "  %b %bRetrieval of supported OS list failed. %s. %b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${errStr}" "${COL_NC}"
                printf "      %bUnable to determine if the detected OS (%s %s) is supported%b\\n" "${COL_LIGHT_RED}" "${detected_os^}" "${detected_version}" "${COL_NC}"
                printf "      Possible causes for this include:\\n"
                printf "        - Firewall blocking certain DNS lookups from DigiNode device\\n"
                printf "        - Google DNS (8.8.8.8) being blocked (required to obtain TXT record from $$DGN_VERSIONS_URL containing supported operating systems)\\n"
                printf "        - Other internet connectivity issues\\n"
            else
                printf "  %b %bUnsupported OS detected: %s %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${detected_os^}" "${detected_version}" "${COL_NC}"
                printf "      If you are seeing this message and you do have a supported OS, please contact @saltedlolly on Twitter.\\n"
            fi
            printf "\\n"
            printf "      %bhttps://digibyte.help\\n" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "      If you wish to attempt to continue anyway, you can try one of the following commands to skip this check:\\n"
            printf "\\n"
            printf "      e.g: If you are seeing this message on a fresh install, you can run:\\n"
            printf "             %bcurl -sSL $DGN_INSTALLER_URL | DIGINODE_SKIP_OS_CHECK=true sudo -E bash%b\\n" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "      It is possible that the installation will still fail at this stage due to an unsupported configuration.\\n"
            printf "      If that is the case, you can feel free to ask @saltedlolly on Twitter.\\n" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            exit 1

        else
            printf "  %b %bSupported OS detected%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        fi
    else
        printf "  %b %bDIGINODE_SKIP_OS_CHECK env variable set to true - installer will continue%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
        printf "  %b Aborting installation: iproute2 and iproute packages were not found in APT repository.\\n" "${CROSS}"
        exit 1
    fi
 
    # Packages required to perfom the system check (stored as an array)
    SYS_CHECK_DEPS=(grep dnsutils)
    # Packages required to run this install script (stored as an array)
    INSTALLER_DEPS=(git "${iproute_pkg}" whiptail ca-certificates jq qrencode)
    # Packages required to run DigiNode (stored as an array)
    DIGINODE_DEPS=(cron curl iputils-ping lsof netcat psmisc sudo unzip idn2 sqlite3 libcap2-bin dns-root-data libcap2 avahi-daemon)

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
    INSTALLER_DEPS=(git iproute newt procps-ng which chkconfig ca-certificates jq qrencode)
    DIGINODE_DEPS=(cronie curl findutils nmap-ncat sudo unzip libidn2 psmisc sqlite libcap lsof avahi-daemon)

# If neither apt-get or yum/dnf package managers were found
else
    # it's not an OS we can support,
    printf "  %b OS distribution not supported\\n" "${CROSS}"
    # so exit the installer
    exit
fi
}


# A function for checking if a directory is a git repository
is_repo() {
    # Use a named, local variable instead of the vague $1, which is the first argument passed to this function
    # These local variables should always be lowercase
    local directory="${1}"
    # A variable to store the return code
    local rc
    # If the first argument passed to this function is a directory,
    if [[ -d "${directory}" ]]; then
        # move into the directory
        pushd "${directory}" &> /dev/null || return 1
        # Use git to check if the directory is a repo
        # git -C is not used here to support git versions older than 1.8.4
        git status --short &> /dev/null || rc=$?
    # If the command was not successful,
    else
        # Set a non-zero return code if directory does not exist
        rc=1
    fi
    # Move back into the directory the user started in
    popd &> /dev/null || return 1
    # Return the code; if one is not set, return 0
    return "${rc:-0}"
}

# A function to clone a repo
make_repo() {
    # Set named variables for better readability
    local directory="${1}"
    local remoteRepo="${2}"

    # The message to display when this function is running
    str="Clone ${remoteRepo} into ${directory}"
    # Display the message and use the color table to preface the message with an "info" indicator
    printf "  %b %s..." "${INFO}" "${str}"
    # If the directory exists,
    if [[ -d "${directory}" ]]; then
        # Return with a 1 to exit the installer. We don't want to overwrite what could already be here in case it is not ours
        str="Unable to clone ${remoteRepo} into ${directory} : Directory already exists"
        printf "%b  %b%s\\n" "${OVER}" "${CROSS}" "${str}"
        return 1
    fi
    # Clone the repo and return the return code from this command
    git clone -q --depth 20 "${remoteRepo}" "${directory}" &> /dev/null || return $?
    # Move into the directory that was passed as an argument
    pushd "${directory}" &> /dev/null || return 1
    # Check current branch. If it is master, then reset to the latest available tag.
    # In case extra commits have been added after tagging/release (i.e in case of metadata updates/README.MD tweaks)
    curBranch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "${curBranch}" == "master" ]]; then
        # If we're calling make_repo() then it should always be master, we may not need to check.
        git reset --hard "$(git describe --abbrev=0 --tags)" || return $?
    fi
    # Show a colored message showing it's status
    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    # Data in the repositories is public anyway so we can make it readable by everyone (+r to keep executable permission if already set by git)
    chmod -R a+rX "${directory}"
    # Move back into the original directory
    popd &> /dev/null || return 1
    return 0
}

# We need to make sure the repos are up-to-date so we can effectively install Clean out the directory if it exists for git to clone into
update_repo() {
    # Use named, local variables
    # As you can see, these are the same variable names used in the last function,
    # but since they are local, their scope does not go beyond this function
    # This helps prevent the wrong value from being assigned if you were to set the variable as a GLOBAL one
    local directory="${1}"
    local curBranch

    # A variable to store the message we want to display;
    # Again, it's useful to store these in variables in case we need to reuse or change the message;
    # we only need to make one change here
    local str="Update repo in ${1}"
    # Move into the directory that was passed as an argument
    pushd "${directory}" &> /dev/null || return 1
    # Let the user know what's happening
    printf "  %b %s..." "${INFO}" "${str}"
    # Stash any local commits as they conflict with our working code
    git stash --all --quiet &> /dev/null || true # Okay for stash failure
    git clean --quiet --force -d || true # Okay for already clean directory
    # Pull the latest commits
    git pull --quiet &> /dev/null || return $?
    # Check current branch. If it is master, then reset to the latest available tag.
    # In case extra commits have been added after tagging/release (i.e in case of metadata updates/README.MD tweaks)
    curBranch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "${curBranch}" == "master" ]]; then
         git reset --hard "$(git describe --abbrev=0 --tags)" || return $?
    fi
    # Show a completion message
    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    # Data in the repositories is public anyway so we can make it readable by everyone (+r to keep executable permission if already set by git)
    chmod -R a+rX "${directory}"
    # Move back into the original directory
    popd &> /dev/null || return 1
    return 0
}


# A function that combines the previous git functions to update or clone a repo
getGitFiles() {
    # Setup named variables for the git repos
    # We need the directory
    local directory="${1}"
    # as well as the repo URL
    local remoteRepo="${2}"
    # A local variable containing the message to be displayed
    local str="Check for existing repository in ${1}"
    # Show the message
    printf "  %b %s..." "${INFO}" "${str}"
    # Check if the directory is a repository
    if is_repo "${directory}"; then
        # Show that we're checking it
        printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
        # Update the repo, returning an error message on failure
        update_repo "${directory}" || { printf "\\n  %b: Could not update local repository. Contact support.%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"; exit 1; }
    # If it's not a .git repo,
    else
        # Show an error
        printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        # Attempt to make the repository, showing an error on failure
        make_repo "${directory}" "${remoteRepo}" || { printf "\\n  %bError: Could not update local repository. Contact support.%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"; exit 1; }
    fi
    echo ""
    # Success via one of the two branches, as the commands would exit if they failed.
    return 0
}

# Reset a repo to get rid of any local changed
resetRepo() {
    # Use named variables for arguments
    local directory="${1}"
    # Move into the directory
    pushd "${directory}" &> /dev/null || return 1
    # Store the message in a variable
    str="Resetting repository within ${1}..."
    # Show the message
    printf "  %b %s..." "${INFO}" "${str}"
    # Use git to remove the local changes
    git reset --hard &> /dev/null || return $?
    # Data in the repositories is public anyway so we can make it readable by everyone (+r to keep executable permission if already set by git)
    chmod -R a+rX "${directory}"
    # And show the status
    printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    # Return to where we came from
    popd &> /dev/null || return 1
    # Function succeeded, as "git reset" would have triggered a return earlier if it failed
    return 0
}

find_IPv4_information() {
    # Detects IPv4 address used for communication to WAN addresses.
    # Accepts no arguments, returns no values.

    # Named, local variables
    local route
    local IPv4bare

    # Find IP used to route to outside world by checking the the route to Google's public DNS server
    route=$(ip route get 8.8.8.8)

    # Get just the interface IPv4 address
    # shellcheck disable=SC2059,SC2086
    # disabled as we intentionally want to split on whitespace and have printf populate
    # the variable with just the first field.
    printf -v IPv4bare "$(printf ${route#*src })"
    # Get the default gateway IPv4 address (the way to reach the Internet)
    # shellcheck disable=SC2059,SC2086
    printf -v IPv4gw "$(printf ${route#*via })"

    if ! valid_ip "${IPv4bare}" ; then
        IPv4bare="127.0.0.1"
    fi

    # Append the CIDR notation to the IP address, if valid_ip fails this should return 127.0.0.1/8
    IPV4_ADDRESS=$(ip -oneline -family inet address show | grep "${IPv4bare}/" |  awk '{print $4}' | awk 'END {print}')
}

# Get available interfaces that are UP
get_available_interfaces() {
    # There may be more than one so it's all stored in a variable
    availableInterfaces=$(ip --oneline link show up | grep -v "lo" | awk '{print $2}' | cut -d':' -f1 | cut -d'@' -f1)
}

# A function for displaying the dialogs the user sees when first running the installer
welcomeDialogs() {
    # Display the welcome dialog using an appropriately sized window via the calculation conducted earlier in the script
    whiptail --msgbox --backtitle "Welcome" --title "DigiNode Automated Installer" "\\n\\nThis installer will setup DigiByte & DigiAsset nodes on your device!" "${r}" "${c}"

    # Request that users donate if they enjoy the software since we all work on it in our free time
    whiptail --msgbox --backtitle "Plea" --title "Free and open source" "\\n\\nDigiNode Installer is free, but powered by your donations:  https://www.digibyte.help/donate/" "${r}" "${c}"

    # Explain the need for a static address
    if whiptail --defaultno --backtitle "Initiating network interface" --title "Static IP Needed" --yesno "\\n\\nYour DigiNode is a SERVER so it needs a STATIC IP ADDRESS to function properly.

IMPORTANT: If you have not already done so, you must ensure that this device has a static IP. Either through DHCP reservation, or by manually assigning one. Depending on your operating system, there are many ways to achieve this.

Choose yes to indicate that you have understood this message, and wish to continue" "${r}" "${c}"; then
#Nothing to do, continue
  echo
else
  printf "  %b Installer exited at static IP message.\\n" "${INFO}"
  exit 1
fi
}

# A function that lets the user pick an interface to use with DigiNode
chooseInterface() {
    # Turn the available interfaces into an array so it can be used with a whiptail dialog
    local interfacesArray=()
    # Number of available interfaces
    local interfaceCount
    # Whiptail variable storage
    local chooseInterfaceCmd
    # Temporary Whiptail options storage
    local chooseInterfaceOptions
    # Loop sentinel variable
    local firstLoop=1

    # Find out how many interfaces are available to choose from
    interfaceCount=$(wc -l <<< "${availableInterfaces}")

    # If there is one interface,
    if [[ "${interfaceCount}" -eq 1 ]]; then
        # Set it as the interface to use since there is no other option
        DIGINODE_INTERFACE="${availableInterfaces}"
    # Otherwise,
    else
        # While reading through the available interfaces
        while read -r line; do
            # Use a variable to set the option as OFF to begin with
            mode="OFF"
            # If it's the first loop,
            if [[ "${firstLoop}" -eq 1 ]]; then
                # set this as the interface to use (ON)
                firstLoop=0
                mode="ON"
            fi
            # Put all these interfaces into an array
            interfacesArray+=("${line}" "available" "${mode}")
        # Feed the available interfaces into this while loop
        done <<< "${availableInterfaces}"
        # The whiptail command that will be run, stored in a variable
        chooseInterfaceCmd=(whiptail --separate-output --radiolist "Choose An Interface (press space to toggle selection)" "${r}" "${c}" "${interfaceCount}")
        # Now run the command using the interfaces saved into the array
        chooseInterfaceOptions=$("${chooseInterfaceCmd[@]}" "${interfacesArray[@]}" 2>&1 >/dev/tty) || \
        # If the user chooses Cancel, exit
        { printf "  %bCancel was selected, exiting installer%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"; exit 1; }
        # For each interface
        for desiredInterface in ${chooseInterfaceOptions}; do
            # Set the one the user selected as the interface to use
            DIGINODE_INTERFACE=${desiredInterface}
            # and show this information to the user
            printf "  %b Using interface: %s\\n" "${INFO}" "${DIGINODE_INTERFACE}"
        done
    fi
}


getStaticIPv4Settings() {
    # Local, named variables
    local ipSettingsCorrect
    # Ask if the user wants to use DHCP settings as their static IP
    # This is useful for users that are using DHCP reservations; then we can just use the information gathered via our functions
    if whiptail --backtitle "Calibrating network interface" --title "Static IP Address" --yesno "Do you want to use your current network settings as a static address?
          IP address:    ${IPV4_ADDRESS}
          Gateway:       ${IPv4gw}" "${r}" "${c}"; then
        # If they choose yes, let the user know that the IP address will not be available via DHCP and may cause a conflict.
        whiptail --msgbox --backtitle "IP information" --title "FYI: IP Conflict" "It is possible your router could still try to assign this IP to a device, which would cause a conflict.  But in most cases the router is smart enough to not do that.
If you are worried, either manually set the address, or modify the DHCP reservation pool so it does not include the IP you want.
It is also possible to use a DHCP reservation, but if you are going to do that, you might as well set a static address." "${r}" "${c}"
    # Nothing else to do since the variables are already set above
    else
    # Otherwise, we need to ask the user to input their desired settings.
    # Start by getting the IPv4 address (pre-filling it with info gathered from DHCP)
    # Start a loop to let the user enter their information with the chance to go back and edit it if necessary
    until [[ "${ipSettingsCorrect}" = True ]]; do

        # Ask for the IPv4 address
        IPV4_ADDRESS=$(whiptail --backtitle "Calibrating network interface" --title "IPv4 address" --inputbox "Enter your desired IPv4 address" "${r}" "${c}" "${IPV4_ADDRESS}" 3>&1 1>&2 2>&3) || \
        # Canceling IPv4 settings window
        { ipSettingsCorrect=False; echo -e "  ${COL_LIGHT_RED}Cancel was selected, exiting installer${COL_NC}"; exit 1; }
        printf "  %b Your static IPv4 address: %s\\n" "${INFO}" "${IPV4_ADDRESS}"

        # Ask for the gateway
        IPv4gw=$(whiptail --backtitle "Calibrating network interface" --title "IPv4 gateway (router)" --inputbox "Enter your desired IPv4 default gateway" "${r}" "${c}" "${IPv4gw}" 3>&1 1>&2 2>&3) || \
        # Canceling gateway settings window
        { ipSettingsCorrect=False; echo -e "  ${COL_LIGHT_RED}Cancel was selected, exiting installer${COL_NC}"; exit 1; }
        printf "  %b Your static IPv4 gateway: %s\\n" "${INFO}" "${IPv4gw}"

        # Give the user a chance to review their settings before moving on
        if whiptail --backtitle "Calibrating network interface" --title "Static IP Address" --yesno "Are these settings correct?
            IP address: ${IPV4_ADDRESS}
            Gateway:    ${IPv4gw}" "${r}" "${c}"; then
                # After that's done, the loop ends and we move on
                ipSettingsCorrect=True
        else
            # If the settings are wrong, the loop continues
            ipSettingsCorrect=False
        fi
    done
    # End the if statement for DHCP vs. static
    fi
}

# Configure networking via dhcpcd
setDHCPCD() {
    # Check if the IP is already in the file
    if grep -q "${IPV4_ADDRESS}" /etc/dhcpcd.conf; then
        printf "  %b Static IP already configured\\n" "${INFO}"
    # If it's not,
    else
        # we can append these lines to dhcpcd.conf to enable a static IP
        echo "interface ${DIGINODE_INTERFACE}
        static ip_address=${IPV4_ADDRESS}
        static routers=${IPv4gw}
        static domain_name_servers=${DIGINODE_DNS_1} ${DIGINODE_DNS_2}" | tee -a /etc/dhcpcd.conf >/dev/null
        # Then use the ip command to immediately set the new address
        ip addr replace dev "${DIGINODE_INTERFACE}" "${IPV4_ADDRESS}"
        # Also give a warning that the user may need to reboot their system
        printf "  %b Set IP address to %s\\n" "${TICK}" "${IPV4_ADDRESS%/*}"
        printf "  %b You may need to restart after the install is complete\\n" "${INFO}"
    fi
}

# Check an IP address to see if it is a valid one
valid_ip() {
    # Local, named variables
    local ip=${1}
    local stat=1

    # Regex matching one IPv4 component, i.e. an integer from 0 to 255.
    # See https://tools.ietf.org/html/rfc1340
    local ipv4elem="(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)";
    # Regex matching an optional port (starting with '#') range of 1-65536
    local portelem="(#(6553[0-5]|655[0-2][0-9]|65[0-4][0-9]{2}|6[0-4][0-9]{3}|[1-5][0-9]{4}|[1-9][0-9]{0,3}|0))?";
    # Build a full IPv4 regex from the above subexpressions
    local regex="^${ipv4elem}\.${ipv4elem}\.${ipv4elem}\.${ipv4elem}${portelem}$"

    # Evaluate the regex, and return the result
    [[ $ip =~ ${regex} ]]

    stat=$?
    return "${stat}"
}

valid_ip6() {
    local ip=${1}
    local stat=1

    # Regex matching one IPv6 element, i.e. a hex value from 0000 to FFFF
    local ipv6elem="[0-9a-fA-F]{1,4}"
    # Regex matching an IPv6 CIDR, i.e. 1 to 128
    local v6cidr="(\\/([1-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8])){0,1}"
    # Regex matching an optional port (starting with '#') range of 1-65536
    local portelem="(#(6553[0-5]|655[0-2][0-9]|65[0-4][0-9]{2}|6[0-4][0-9]{3}|[1-5][0-9]{4}|[1-9][0-9]{0,3}|0))?";
    # Build a full IPv6 regex from the above subexpressions
    local regex="^(((${ipv6elem}))*((:${ipv6elem}))*::((${ipv6elem}))*((:${ipv6elem}))*|((${ipv6elem}))((:${ipv6elem})){7})${v6cidr}${portelem}$"

    # Evaluate the regex, and return the result
    [[ ${ip} =~ ${regex} ]]

    stat=$?
    return "${stat}"
}

# Allow the user to enable/disable logging
setLogging() {
    # Local, named variables
    local LogToggleCommand
    local LogChooseOptions
    local LogChoices

    # Ask if the user wants to log queries
    LogToggleCommand=(whiptail --separate-output --radiolist "Do you want to log queries?" "${r}" "${c}" 6)
    # The default selection is on
    LogChooseOptions=("On (Recommended)" "" on
        Off "" off)
    # Get the user's choice
    LogChoices=$("${LogToggleCommand[@]}" "${LogChooseOptions[@]}" 2>&1 >/dev/tty) || (printf "  %bCancel was selected, exiting installer%b\\n" "${COL_LIGHT_RED}" "${COL_NC}" && exit 1)
    case ${LogChoices} in
        # If it's on,
        "On (Recommended)")
            printf "  %b Logging On.\\n" "${INFO}"
            # set the GLOBAL variable setting to true
            QUERY_LOGGING=true
            ;;
        # Otherwise, it's off,
        Off)
            printf "  %b Logging Off.\\n" "${INFO}"
            # set the GLOBAL variable setting to false
            QUERY_LOGGING=false
            ;;
    esac
}

stop_service() {
    # Stop service passed in as argument.
    # Can softfail, as process may not be installed when this is called
    local str="Stopping ${1} service"
    printf "  %b %s..." "${INFO}" "${str}"
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
    printf "  %b %s..." "${INFO}" "${str}"
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
    printf "  %b %s..." "${INFO}" "${str}"
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
    printf "  %b %s..." "${INFO}" "${str}"
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
        systemctl is-enabled "${1}" &> /dev/null
    else
        # Otherwise, fall back to service command
        service "${1}" status &> /dev/null
    fi
}


update_package_cache() {
    # Running apt-get update/upgrade with minimal output can cause some issues with
    # requiring user input (e.g password for phpmyadmin see #218)

    # Update package cache on apt based OSes. Do this every time since
    # it's quick and packages can be updated at any time.

    # Local, named variables
    local str="Update local cache of available packages"
    printf "  %b %s..." "${INFO}" "${str}"
    # Create a command from the package cache variable
    if eval "${UPDATE_PKG_CACHE}" &> /dev/null; then
        printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
    else
        # Otherwise, show an error and exit
        printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        printf "  %bError: Unable to update package cache. Please try \"%s\"%b" "${COL_LIGHT_RED}" "sudo ${UPDATE_PKG_CACHE}" "${COL_NC}"
        return 1
    fi
}

# Let user know if they have outdated packages on their system and
# advise them to run a package update at soonest possible.
notify_package_updates_available() {
    # Local, named variables
    local str="Checking ${PKG_MANAGER} for upgraded packages"
    printf "\\n  %b %s..." "${INFO}" "${str}"
    # Store the list of packages in a variable
    updatesToInstall=$(eval "${PKG_COUNT}")

    if [[ -d "/lib/modules/$(uname -r)" ]]; then
        if [[ "${updatesToInstall}" -eq 0 ]]; then
            printf "%b  %b %s... up to date!\\n\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%b  %b %s... %s updates available\\n" "${OVER}" "${TICK}" "${str}" "${updatesToInstall}"
            printf "  %b %bIt is recommended to update your OS after installing the Pi-hole!%b\\n\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        fi
    else
        printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
        printf "      Kernel update detected. If the install fails, please reboot and try again\\n"
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
            printf "  %b Checking for %s..." "${INFO}" "${i}"
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
            printf "  %b Processing %s install(s) for: %s, please wait...\\n" "${INFO}" "${PKG_MANAGER}" "${installArray[*]}"
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
        printf "  %b Processing %s install(s) for: %s, please wait...\\n" "${INFO}" "${PKG_MANAGER}" "${installArray[*]}"
        printf '%*s\n' "$columns" '' | tr " " -;
        "${PKG_INSTALL[@]}" "${installArray[@]}"
        printf '%*s\n' "$columns" '' | tr " " -;
        return
    fi
    printf "\\n"
    return 0
}

# Check if the digibyte user exists and create if it does not
create_digibyte_user() {
    local str="Checking for user 'digibyte'"
    printf "  %b %s..." "${INFO}" "${str}"
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
        printf "%b  %b %s..." "${OVER}" "${INFO}" "${str}"
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

# Install DigiNode scripts including DigiMon
install_diginode_scripts() {
    cd~
    git clone https://github.com/saltedlolly/diginode
    cd diginode
    chmod +x digimon.sh
    chmod +x diginode-installer.sh
}

create_diginode_settings() {
# Get saved variables from diginode.settings file. Create it if it does not exist.
if test -f $DGN_SETTINGS_FILE; then
  # import saved variables from settings file
  echo "$INFO Importing diginode.settings file..."
  source $DGN_SETTINGS_FILE
else
  # create settings folder if it does not exist
  if [ -d "$DGB_SETTINGS_FOLDER" ]; then
    echo "$INFO Creating .diginode settings folder"
    mkdir $DGB_SETTINGS_FOLDER
  fi
  # create diginode.settings file
  echo "$INFO Creating diginode.settings file"
  touch $DGN_SETTINGS_FILE
  cat <<EOF > $DGN_SETTINGS_FILE
#!/bin/bash

# This settings file is used to store variables for the DigiNode Installer and DigiNode Status Monitor

# Setup timer variables
savedtime15sec=
savedtime1min=
savedtime15min=
savedtime1day=
savedtime1week=

# store diginode installation details
official_install=
install_date=
update_date=
statusmonitor_last_run=
dams_first_run=

Store IP addresses to ensure they are only rechecked once every 15 minute.
externalip=
internalip=

# Store number of available system updates so the script only checks once every 24 hours.
system_updates=
security_updates=

Store local version numbers so the local node is not hammered with requests every second.
dgb_ver_local=
dga_ver_local=
ipfs_ver_local=

# Store software release version numbers in settings file so Github only needs to be queried once a day.
dgb_ver_github=
dga_ver_github=
dnt_ver_github=

# Store when an open port test last ran.
ipfs_port_test_status=
ipfs_port_test_date=
dgb_port_test_status=
dgb_port_test_date=
EOF

fi
}

# Create digibyte.config file if it does not already exist
create_digibyte_conf() {

   # Set max connections to higher if running a dedicated server (Default: 125)
    local set_maxconnections
    set_maxconnections=300

    # Increase dbcache size if there is more than ~7Gb of RAM (Default: 450)
    # Initial sync times are significantly faster with a larger dbcache.
    local set_dbcache
    if [ $RAMTOTAL_KB -ge "7340032" ]; then
        set_dbcache=2048
    else
        set_dbcache=450
    fi

    # generate a random rpc password
    local set_rpcpassword
    echo "$INFO Generating random RPC password"
    set_rpcpassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

    # create .digibyte settings folder if it does not already exist
    if [ ! -d $DGB_SETTINGS_FOLDER ]; then
        echo "$INFO Creating ~/.digibyte folder"
        mkdir $DGB_SETTINGS_FOLDER
    fi

    # If digibyte.conf settings file already exists, append any missing values. Otherwise create it.
    if test -f "$DGB_CONF_FILE"; then
        # Import variables from diginode.conf settings file
        echo "$INFO Retrieving diginode.settings file"
        source $DGB_CONF_FILE

        echo "$INFO Verifying existing digibyte.conf settings"
        

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
            echo "rpcuser=$set_rpcpassword" >> $DGB_CONF_FILE
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


    else
        # Create a new digibyte.conf file
        echo "$INFO Creating digibyte.conf file"
        cat <<EOF > $DGB_CONF_FILE
# This config should be placed in following path:
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
# Keep at most <n> unconnectable transactions in memory.
maxorphantx=
# Keep the transaction memory pool below <n> megabytes.
maxmempool=

# [network]
# Maintain at most N connections to peers. (default: 125)
maxconnections=$set_maxconnections
# Tries to keep outbound traffic under the given target (in MiB per 24h), 0 = no limit.
maxuploadtarget=
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
    fi

}




# Install base files and web interface
installDigiNode() {
    # If the user wants to install the Web interface,

    # For updates and unattended install.
    if [[ "${useUpdateVars}" == true ]]; then
        accountForRefactor
    fi
    # Install base files and web interface
    if ! installScripts; then
        printf "  %b Failure in dependent script copy function.\\n" "${CROSS}"
        exit 1
    fi
    # Install config files
    if ! installConfigs; then
        printf "  %b Failure in dependent config copy function.\\n" "${CROSS}"
        exit 1
    fi


    # Update setupvars.conf with any variables that may or may not have been changed during the install
    finalExports
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

copy_to_install_log() {
    # Copy the contents of file descriptor 3 into the install log
    # Since we use color codes such as '\e[1;33m', they should be removed
    sed 's/\[[0-9;]\{1,5\}m//g' < /proc/$$/fd/3 > "${installLogLoc}"
    chmod 644 "${installLogLoc}"
}

# Function to create two hidden files so that the DigiNode Status Monitor can know that this is an official install
set_official() {
    touch $HOME/digibyte/.officialdiginode
    touch $HOME/digiasset_ipfs_metadata_server/.officialdiginode" ]; then
    echo "$INFO Verifying Official DigiNode Installation
}

donation_qrcode() {       
    echo "    If you found this tool useful,"
    echo " donations in DGB are much appreciated:"             
    echo "     ▄▄▄▄▄▄▄  ▄    ▄ ▄▄▄▄▄ ▄▄▄▄▄▄▄"  
    echo "     █ ▄▄▄ █ ▀█▄█▀▀██  █▄█ █ ▄▄▄ █"  
    echo "     █ ███ █ ▀▀▄▀▄▀▄ █▀▀▄█ █ ███ █"  
    echo "     █▄▄▄▄▄█ █ █ ▄ ▄▀▄▀▄ █ █▄▄▄▄▄█"  
    echo "     ▄▄▄▄▄ ▄▄▄▄▄ █▄▄▀▄▄▄ ▄▄ ▄ ▄ ▄ "  
    echo "     █ ▄▀ ▄▄▄▀█ ▄▄ ▄▄▀  ▀█▄▀██▄ ▄▀"  
    echo "      ▀▀ ▄▀▄  █▀█ ▄ ▀ ▄  █  ▀▀█▄█▀"  
    echo "      █ █▀▄▄▀█ █ ▀▄▀▄██▄▀▄██▀▀▄ ▀▀"  
    echo "     ▄█▀ █▀▄▄    █▄█▀▄▄▀▀▄ ▀  █▄ ▀"  
    echo "     █ ▄██ ▄▀▀█ ▄▄█ ▄█▀▄▀▄█▀▀█▀▄▀▀"  
    echo "     █ ██▄ ▄▄ ▄▀█ ▄███▄▄▀▄▄▄▄▄▄▄▀ "  
    echo "     ▄▄▄▄▄▄▄ █▀▄ ▀ █▄▄▄ ██ ▄ █ ▀▀▀"  
    echo "     █ ▄▄▄ █ ▄█▀ █▄█▀▄▄▀▀█▄▄▄██▄▄█"  
    echo "     █ ███ █ █ ▀▄▄ ▀▄ ███  ▄█▄  █▀"  
    echo "     █▄▄▄▄▄█ █  █▄  █▄▄ ▀▀  ▀▄█▄▀ "  
    echo ""
    echo "dgb1qv8psxjeqkau5s35qwh75zy6kp95yhxxw0d3kup"
}

main() {

    # clear the screen and display the title box
    installer_title_box

    # Perform basic OS check and lookup hardware architecture
    sys_check

    # display the disclaimer
    installer_disclaimer

    ######## FIRST CHECK ########
    # Must be root to install
    local str="Root user check"
    printf "\\n"

    # If the user's id is zero,
    if [[ "${EUID}" -eq 0 ]]; then
        # they are root and all is good
        printf "  %b %s\\n" "${TICK}" "${str}"
        # Show the DigiNode Installer title box
        installer_title_box
        make_temporary_log
    else
        # Otherwise, they do not have enough privileges, so let the user know
        printf "%b %s\\n" "${INFO}" "${str}"
        printf "%b %bScript called with non-root privileges%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b The installer requires elevated privileges to setup your DigiNode.\\n" "${INDENT}"
        printf "%b Please check the review the source code for any concerns regarding this requirement\\n" "${INDENT}"
        printf "%b Make sure to download this script from a trusted source\\n\\n" "${INDENT}"
        printf "%b Sudo utility check" "${INFO}"

        # If the sudo command exists, try rerunning as admin
        if is_command sudo ; then
            printf "%b  %b Sudo utility check\\n" "${OVER}"  "${TICK}"

            # when run via curl piping
            if [[ "$0" == "bash" ]]; then
                # Download the install script and run it with admin rights
                exec curl -sSL $DigiNodeInstallURL | sudo bash "$@"
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
    # Create the pihole user
    create_pihole_user

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





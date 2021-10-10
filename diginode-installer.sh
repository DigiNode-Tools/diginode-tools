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
# Updated: October 10 2021 6:01pm GMT
#
# -----------------------------------------------------------------------------------------------------

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# We do not want users to end up with a partially working install, so we exit the script
# instead of continuing the installation with something broken
set -e

# Append common folders to the PATH to ensure that all basic commands are available.
# When using "su" an incomplete PATH could be passed.
export PATH+=':/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

######## VARIABLES START HERE #########
# For better maintainability, we store as much information that can change in variables
# This allows us to make a change in one place that can propagate to all instances of the variable
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions

######### IMPORTANT NOTE ###########
# Both the DigiNode Installer and Status Monitor scripts make use of a setting file
# located at ~/.diginode/diginode.settings
# It want to make changes to folder locations, please edit this file.
# e.g. To move you data file to an external drive.
#
# NOTE: This variable sets the default location of the diginode.settings file. 
# There should be no reason to change this, and it is unadvisable to do.
DGN_SETTINGS_FOLDER=$HOME/.diginode
DGN_SETTINGS_FILE=$DGN_SETTINGS_FOLDER/diginode.settings

# This is the URLs where the install script is hosted
DGN_VERSIONS_URL=diginode-versions.digibyte.help    # Used to query TXT record containing compatible OS'es
DGN_INSTALLER_OFFICIAL_URL=https://diginode-installer.digibyte.help
DGN_INSTALLER_GITHUB_REL_URL=https://raw.githubusercontent.com/saltedlolly/diginode/release/diginode-installer.sh
DGN_INSTALLER_GITHUB_DEV_URL=https://raw.githubusercontent.com/saltedlolly/diginode/develop/diginode-installer.sh
DGN_INSTALLER_URL=$DGN_INSTALLER_GITHUB_DEV_URL

# These are the commands that the use pastes into the terminal to run the installer
DGN_INSTALLER_OFFICIAL_CMD="curl $DGN_INSTALLER_OFFICIAL_URL | bash"

# We clone (or update) the DigiNode git repository during the install. This helps to make sure that we always have the latest versions of the relevant files.
DGN_GITHUB_URL="https://github.com/saltedlolly/diginode.git"

# THis ensures that this VERBOSE_MODE setting is ignored if running the Status Monitor script - it has its own VERBOSE_MODE setting
if [[ "$RUN_INSTALLER" != "NO" ]] ; then
    # INSTRUCTIONS: Set this to YES to get more verbose feedback. Very useful for troubleshooting.
    VERBOSE_MODE="YES"
fi

######## VARIABLES END HERE #########
# -----------------------------------------------------------------------------------------------------

# Store user in variable
if [ -z "${USER}" ]; then
  USER="$(id -un)"
fi

# If update variable isn't specified, set to false
if [ -z "$useUpdateVars" ]; then
  useUpdateVars=false
fi

# whiptail dialog dimensions: 20 rows and 70 chars width assures to fit on small screens and is known to hold all content.
r=24
c=70

######## Undocumented Flags. Shhh ########
# These are undocumented flags; some of which we can use when repairing an installation
# The runUnattended flag is one example of this
reconfigure=false
runUnattended=false
# Check arguments for the undocumented flags
for var in "$@"; do
    case "$var" in
        "--reconfigure" ) reconfigure=true;;
        "--unattended" ) runUnattended=true;;
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
WARN="  [${COL_LIGHT_CYAN}!${COL_NC}]"
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



# Load variables from diginode.settings file. Create the file first if it does not exit.
import_diginode_settings() {

local str

# check if diginode.settings file exists
if [ ! -f "$DGN_SETTINGS_FILE" ]; then

  # create .diginode settings folder if it does not exist
  if [ ! -d "$DGN_SETTINGS_FOLDER" ]; then
    str="Creating .diginode settings folder: $DGN_SETTINGS_FOLDER   "
    printf "\\n%b %s" "${INFO}" "${str}"
    mkdir $DGN_SETTINGS_FOLDER
    printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
  fi

  # create diginode.settings file
  str="Creating diginode.settings file... $DGN_SETTINGS_FILE   "
  printf "\\n%b %s" "${INFO}" "${str}"
  touch $DGN_SETTINGS_FILE
  cat <<EOF > $DGN_SETTINGS_FILE
#!/bin/bash
# This settings file is used to store variables for the DigiNode Installer and DigiNode Status Monitor

# DEFAULT FOLDER AND FILE LOCATIONS
# If you want to change the default location of folders you can edit them here

# DIGINODE TOOLS:
DGN_SCRIPTS_FOLDER=\$HOME/diginode
DGN_INSTALL_LOG=\$DGN_SETTINGS_FOLDER/install.log

# DIGIBYTE NODE:
DGB_INSTALL_LOCATION=\$HOME/digibyte/       # Typically this is a symbolic link that points at the actual install folder
DGB_DATA_FODLER=\$DGB_DATA_FOLDER/digibyte.conf
DGB_CONF_FILE=\$DGB_DATA_FOLDER/digibyte.conf

# DIGIASSETS NODE:
DGA_INSTALL_FOLDER=\$HOME/digiasset_node
DGA_CONFIG_FILE=\$DGA_INSTALL_FOLDER/_config/main.json


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
printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"

fi

# The settings file exists, so source it
str="Importing diginode.settings file: $DGN_SETTINGS_FILE   "
printf "\\n%b %s" "${INFO}" "${str}"
source $DGN_SETTINGS_FILE
printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"

}



# These are only set after the intitial OS check since they cause an error on MacOS
set_mem_variables() {

    # Store total system RAM as variables
    RAMTOTAL_KB=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
    RAMTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Mem/!d' | cut -d" " -f2)

    # Store current total swap file size as variables
    SWAPTOTAL_KB=$(cat /proc/meminfo | grep MemTotal: | tr -s ' ' | cut -d' ' -f2)
    SWAPTOTAL_HR=$(free -h --si | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f2)
}


# A simple function that just the installer title in a box
installer_title_box() {
     clear -x
     echo ""
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
                ƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊƊ   ${txtrst}${txtbld}"
echo -e "       ____   _         _   _   __            __     "             
echo -e "      / __ \ (_)____ _ (_) / | / /____   ____/ /___  "
echo -e "     / / / // // __ '// / /  |/ // __ \ / __  // _ \ "
echo -e "    / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/ "
echo -e "   /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/  "
echo -e "              /____/                                 ${txtrst}"
echo    ""
sleep 0.5
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
        printf "%b %bERROR: OS is unsupported%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b DigiNode Installer requires a 64-bit linux OS (aarch64 or X86_64)\\n" "${INDENT}"
        printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
        printf "%b should be supported please contact @saltedlolly on Twitter letting me\\n" "${INDENT}"
        printf "%b know the OS type: $OSTYPE\\n" "${INDENT}"
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
            printf "%b %bERROR: Unsupported 32-bit OS%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b DigiNode Installer requires a 64-bit OS (aarch64 or X86_64)\\n" "${INDENT}"
            printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
            printf "%b should be supported please contact @saltedlolly on Twitter letting me\\n" "${INDENT}"
            printf "%b know the reported system architecture above.\\n" "${INDENT}"
            printf "\\n"
            exit 1
        elif [[ "$is_64bit" == "no" ]]; then
            printf "%b %bERROR: System architecture is unrecognised%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "%b DigiNode Installer requires a 64-bit OS (aarch64 or X86_64)\\n" "${INDENT}"
            printf "%b Ubuntu Server 64-bit is recommended. If you believe your hardware\\n" "${INDENT}"
            printf "%b should be supported please contact @saltedlolly on Twitter letting me\\n" "${INDENT}"
            printf "%b know the reported system architecture above.\\n" "${INDENT}"
            printf "\\n"
            exit 1
        fi
    else
        if [ "$VERBOSE_MODE" = "YES" ]; then
            printf "%b %b$WARNING: Unable to check for 64-bit OS - arch command is not present  [ VERBOSE MODE ]%b" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        fi
    fi
}


# Function to check for compatible Raspberry Pi hardware
rpi_check() {

sysarch=$(arch)

if [[ "$sysarch" == "aarch"* ]] || [[ "$sysarch" == "arm"* ]]; then

    # check the 'tr' command is available
    if ! is_command tr ; then
        printf "%b %bERROR: Unable to check for No Raspberry Pi hardware - 'tr' command not found%b  [ VERBOSE MODE ]\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
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
        printf "%b No Raspberry Pi Detected - ARM processor not found  [ VERBOSE MODE ]\\n" "${INFO}"
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
        printf "%b is connected to a USB3 port (i.e. a blue one).\\n" "${INDENT}"
        printf "\\n"
        STARTPAUSE="yes"
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
    SYS_CHECK_DEPS=(grep dnsutils)
    # Packages required to run this install script (stored as an array)
    INSTALLER_DEPS=(git "${iproute_pkg}" jq whiptail ca-certificates)
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
    INSTALLER_DEPS=(git iproute newt procps-ng which chkconfig ca-certificates jq)
    DIGINODE_DEPS=(cronie curl findutils nmap-ncat sudo unzip libidn2 psmisc sqlite libcap lsof avahi-daemon)

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
                printf "%b %bRetrieval of supported OS list failed. %s. %b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${errStr}" "${COL_NC}"
                printf "    %bUnable to determine if the detected OS (%s %s) is supported%b\\n" "${COL_LIGHT_RED}" "${detected_os^}" "${detected_version}" "${COL_NC}"
                printf "    Possible causes for this include:\\n"
                printf "      - Firewall blocking certain DNS lookups from DigiNode device\\n"
                printf "      - Google DNS (8.8.8.8) being blocked (required to obtain TXT record from $$DGN_VERSIONS_URL containing supported operating systems)\\n"
                printf "      - Other internet connectivity issues\\n"
            else
                printf "  %b %bUnsupported OS detected: %s %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${detected_os^}" "${detected_version}" "${COL_NC}"
                printf "    If you are seeing this message and you believe your OS should be supported, please contact @saltedlolly on Twitter.\\n"
            fi
            printf "\\n"
            printf "    %bhttps://digibyte.help\\n" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "    If you wish to attempt to continue anyway, you can try one of the following commands to skip this check:\\n"
            printf "\\n"
            printf "    e.g: If you are seeing this message on a fresh install, you can run:\\n"
            printf "           %bcurl -sSL $DGN_INSTALLER_URL | DIGINODE_SKIP_OS_CHECK=true sudo -E bash%b\\n" "${COL_LIGHT_GREEN}" "${COL_NC}"
            printf "\\n"
            printf "    It is possible that the installation will still fail at this stage due to an unsupported configuration.\\n"
            printf "    If that is the case, feel free to ask @saltedlolly on Twitter.\\n" "${COL_LIGHT_RED}" "${COL_NC}"
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
                printf "%b %bDefault SELinux: %s%b\\n" "${CROSS}" "${COL_RED}" "${DEFAULT_SELINUX}" "${COL_NC}"
                SELINUX_ENFORCING=1
                ;;
            *)  # 'permissive' and 'disabled'
                printf "%b %bDefault SELinux: %s%b\\n" "${TICK}" "${COL_GREEN}" "${DEFAULT_SELINUX}" "${COL_NC}"
                ;;
        esac
        # Check the current state of SELinux
        CURRENT_SELINUX=$(getenforce)
        case "${CURRENT_SELINUX,,}" in
            enforcing)
                printf "%b %bCurrent SELinux: %s%b\\n" "${CROSS}" "${COL_RED}" "${CURRENT_SELINUX}" "${COL_NC}"
                SELINUX_ENFORCING=1
                ;;
            *)  # 'permissive' and 'disabled'
                printf "%b %bCurrent SELinux: %s%b\\n" "${TICK}" "${COL_GREEN}" "${CURRENT_SELINUX}" "${COL_NC}"
                ;;
        esac
    else
        echo -e "${INFO} ${COL_GREEN}SELinux not detected${COL_NC}";
    fi
    # Exit the installer if any SELinux checks toggled the flag
    if [[ "${SELINUX_ENFORCING}" -eq 1 ]] && [[ -z "${DIGINODE_SELINUX}" ]]; then
        printf "  DigiNode does not provide an SELinux policy as the required changes modify the security of your system.\\n"
        printf "  Please refer to https://wiki.centos.org/HowTos/SELinux if SELinux is required for your deployment.\\n"
        printf "      This check can be skipped by setting the environment variable %bDIGINODE_SELINUX%b to %btrue%b\\n" "${COL_LIGHT_RED}" "${COL_NC}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "      e.g: export DIGINODE_SELINUX=true\\n"
        printf "      By setting this variable to true you acknowledge there may be issues with DigiNode during or after the install\\n"
        printf "\\n  %bSELinux Enforcing detected, exiting installer%b\\n" "${COL_LIGHT_RED}" "${COL_NC}";
        exit 1;
    elif [[ "${SELINUX_ENFORCING}" -eq 1 ]] && [[ -n "${PIHOLE_SELINUX}" ]]; then
        printf "%b %bSELinux Enforcing detected%b. DIGINODE_SELINUX env variable set - installer will continue\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
    fi
}

# Check for swap file if using a device with low memory, and make sure it is large enough
swap_check() {

    local swap_current_size

    if [ "$SWAPTOTAL_HR" = "0B" ]; then
      swap_current_size="${COL_LIGHT_RED}none${COL_NC}"
    else
      swap_current_size="${COL_LIGHT_GREEN}${SWAPTOTAL_HR}b${COL_NC}"
    fi

    printf "%b System Memory:     Total RAM: %b${RAMTOTAL_HR}b%b     Total SWAP: $swap_current_size\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
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
        SWAP_REC_SIZE="7Gb"
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "5859375" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE="6Gb"
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "4882813" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE="5Gb"
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "3906250" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE="4Gb"
    elif [ "$RAMTOTAL_KB" -le "5000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "2929688" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE="3Gb"
    elif [ "$RAMTOTAL_KB" -le "6000000" ] && [ "$SWAPTOTAL_KB" -gt "0" ] && [ "$SWAPTOTAL_KB" -le "976562" ];  then
        SWAP_TOO_SMALL="YES"
        SWAP_REC_SIZE="2Gb"

    # If there is no swap file present, calculate recomended swap file size
    elif [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE="7Gb"
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE="6Gb"
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE="5Gb"
    elif [ "$RAMTOTAL_KB" -le "4000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE="4Gb"
    elif [ "$RAMTOTAL_KB" -le "3000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE="5Gb"
    elif [ "$RAMTOTAL_KB" -le "2000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE="6Gb"
    elif [ "$RAMTOTAL_KB" -le "1000000" ] && [ "$SWAPTOTAL_KB" = "0" ]; then
        SWAP_NEEDED="YES"
        SWAP_REC_SIZE="7Gb"
    fi

    if [ "$SWAP_NEEDED" = "YES" ]; then
        printf "%b %bWARNING: No Swap file detected%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Running a DigiNode requires approximately 5Gb RAM. Since your device only\\n" "${INDENT}"
        printf "%b has ${RAMTOTAL_HR}b RAM, it is recommended to create a swap file of at least $swap_rec_size or more.\\n" "${INDENT}"
        printf "%b This will give your system at least 8Gb of total memory to work with.\\n" "${INDENT}"
        # Only display this line when using digimon.sh
        if [[ "$RUN_INSTALLER" = "NO" ]] ; then
            printf "%b The official DigiNode installer can setup the swap file for you.\\n" "${INDENT}"
        fi
        printf "\\n"
    fi

    if [ "$SWAP_TOO_SMALL" = "YES" ]; then
        printf "%b %bWARNING: Your swap file is too small%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "%b Running a DigiNode requires approximately 5Gb RAM. Since your device only\\n" "${INDENT}"
        printf "%b has ${RAMTOTAL_HR}b RAM, it is recommended to increase your swap size to at least $swap_rec_size or more.\\n" "${INDENT}"
        printf "%b This will give your system at least 8Gb of total memory to work with.\\n" "${INDENT}"
        # Only display this line when using digimon.sh
        if [[ "$RUN_INSTALLER" = "NO" ]] ; then
            printf "%b The official DigiNode installer can setup the swap file for you.\\n" "${INDENT}"
        fi
        printf "\\n"
    fi
}

# This function will setup a swap file for your device
swap_setup() {

    #create local variable
    local str

    if [ "$SWAP_NEEDED" = "YES" ]; then
        # Local, named variables
        str="Creating $SWAP_REC_SIZE swap file..."
        printf "\\n%b %s..." "${INFO}" "${str}"

        sleep 2

        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"
    fi

    if [ "$SWAP_TOO_SMALL" = "YES" ]; then
        str="Increasing swap file from ${RAMTOTAL_HR}b to $SWAP_REC_SIZE..."
        printf "\\n%b %s..." "${INFO}" "${str}"

        sleep 2

        printf "%b%b %s Done!\\n\\n" "${OVER}" "${TICK}" "${str}"
        printf "\\n"
    fi

}


update_dialogs() {
    # If diginode -r "reconfigure" option was selected,
    if [[ "${reconfigure}" = true ]]; then
        # set some variables that will be used
        opt1a="Repair"
        opt1b="This will retain existing settings including your local DigiByte wallet."
        strAdd="You will remain on the same version"
    else
        # Otherwise, set some variables with different values
        opt1a="Update"
        opt1b="This will retain existing settings including your local DigiByte wallet."
        strAdd="You will be updated to the latest version."
    fi
    opt2a="Reconfigure"
    opt2b="Resets your DigiNode and allows re-selecting settings. "

    # Display the information to the user
    UpdateCmd=$(whiptail --title "Existing DigiNode Detected!" --menu "\\n\\nWe have detected an existing install.\\n\\nPlease choose from the following options: \\n($strAdd)" "${r}" "${c}" 2 \
    "${opt1a}"  "${opt1b}" \
    "${opt2a}"  "${opt2b}" 3>&2 2>&1 1>&3) || \
    { printf "%bCancel was selected, exiting installer%b\\n" "${COL_LIGHT_RED}" "${COL_NC}"; exit 1; }

    # Set the variable based on if the user chooses
    case ${UpdateCmd} in
        # repair, or
        ${opt1a})
            printf "%b %s option selected\\n" "${INFO}" "${opt1a}"
            useUpdateVars=true
            ;;
        # reconfigure,
        ${opt2a})
            printf "%b %s option selected\\n" "${INFO}" "${opt2a}"
            useUpdateVars=false
            ;;
    esac
}

# A function for displaying the dialogs the user sees when first running the installer
welcomeDialogs() {
    # Display the welcome dialog using an appropriately sized window via the calculation conducted earlier in the script
    whiptail --msgbox --backtitle "" --title "DigiNode Installer" "\\n\\nDigiNode Installer will install and configure a DigiByte and DigiAsset Node on this device!

    To learn more, visit https://www.digibyte.help/diginode" "${r}" "${c}"

    # Request that users donate if they enjoy the software since we all work on it in our free time
#   whiptail --msgbox --backtitle "Plea" --title "Free and open source" "\\n\\nThis DigiNode Installer is free, but powered by your donations:  https://pi-hole.net/donate/" "${r}" "${c}"
    whiptail --msgbox --backtitle "" --title "Free and open source" "DigiNode Installer is free, but donations in DGB are appreciated:
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


    # If this is a Raspberry Pi, explain the need for booting from a SSD
    if [[ "${IS_RPI}" = "YES" ]]; then
    if whiptail --backtitle "" --title "Raspberry Pi Detected" --yesno "Are you booting your Raspberry Pi from an external SSD or a microSD card?
   
For this installer to work correctly, you must be booting your Raspberry Pi from an external SSD* connected via USB. 

Booting from a microSD card is not supported. 

If using a Pi 4 or newer, make sure your drive is connected to a USB3 port (i.e. a blue one).

(*NOTE: An HDD will also work, but an SSD is recommended.) " --no-button "microSD card" --yes-button "External SSD" "${r}" "${c}"; then
#Nothing to do, continue
  echo
else
  printf "%b Installer exited at microSD warning message.\\n" "${INFO}"
  exit 1
fi

    # Warn user to unplug the microSD card (just to double check that they are booting from SSD!)
    whiptail --msgbox --backtitle "" --title "Raspberry Pi Detected" "\\n\\nBefore proceeding, please remove the microSD card from the Raspberry Pi, if there is one." "${r}" "${c}"

    fi

    # Explain the need for a static address
    if whiptail --defaultno --backtitle "" --title "Static IP Needed" --yesno "\\n\\nYour DigiNode is a SERVER so it needs a STATIC IP ADDRESS to function properly.

IMPORTANT: If you have not already done so, you must ensure that this device has a static IP. Either through DHCP reservation, or by manually assigning one. Depending on your operating system, there are many ways to achieve this.

Choose yes to indicate that you have understood this message, and wish to continue" "${r}" "${c}"; then
#Nothing to do, continue
  echo
else
  printf "%b Installer exited at static IP message.\\n" "${INFO}"
  exit 1
fi
}

donation_qrcode() {       
    echo "    If you find this tool useful,"
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
        printf "  %b %s\\n" "${TICK}" "${str}"
        # Show the DigiNode logo
        diginode_logo
        make_temporary_log
    else
        # show installer title box
        installer_title_box

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
            printf "%b Sudo is needed for the DigiNode installer to proceed.\\n\\n" "${INFO}"
            printf "%b %bPlease re-run as root.${COL_NC}\\n" "${INFO}" "${COL_LIGHT_RED}"
            exit 1
        fi
    fi

    # Perform basic OS check and lookup hardware architecture
    sys_check

    # Set the memory variables once we know we are on linux
    set_mem_variables

    # Check for Raspberry Pi hardware
    rpi_check

    # Check for supported package managers so that we may install dependencies
    package_manager_detect

    # Notify user of package availability
    notify_package_updates_available

    # Install packages necessary to perform os_check
    printf "%b Checking for / installing required dependencies for OS Check...\\n" "${INFO}"
    install_dependent_packages "${SYS_CHECK_DEPS[@]}"

    # Check that the installed OS is officially supported - display warning if not
    os_check

    # Install packages used by this installation script
    printf "%b Checking for / installing required dependencies for installer...\\n" "${INFO}"
    install_dependent_packages "${INSTALLER_DEPS[@]}"

    # Check if SELinux is Enforcing
    checkSelinux

    # Import diginode.settings file because it contains variables we need for the install
    import_diginode_settings

    # Check swap requirements
    swap_check

    # if it's running unattended,
    if [[ "${runUnattended}" == true ]]; then
        printf "%b Performing unattended setup, no whiptail dialogs will be displayed\\n" "${INFO}"
        # Use the setup variables
        useUpdateVars=true
        # also disable debconf-apt-progress dialogs
        export DEBIAN_FRONTEND="noninteractive"
    else
        # If running attended, show the available options (repair/reconfigure)
        update_dialogs
    fi


    if [[ "${useUpdateVars}" == false ]]; then

        # pause for a moment beofe displaying menu
        sleep 3

        # Display welcome dialogs
        welcomeDialogs

        #####################################
        echo ""
        printf "%b Exiting script early during testing!!" "${INFO}"
        echo ""
        exit # EXIT HERE DURING TEST
        #####################################

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
    printf "  %b Checking for / installing required dependencies for DigiNode software...\\n" "${INFO}"
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





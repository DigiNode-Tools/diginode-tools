#!/bin/bash
#
#           Name:  DigiNode Dashboard v0.9.5
#
#        Purpose:  Monitor and manage the status of you DigiByte Node and DigiAsset Node.
#          
#  Compatibility:  Supports x86_86 or arm64 hardware with Ubuntu or Debian 64-bit distros.
#                  Other distros may not work at present. Please help test so that support can be added.
#                  A Raspberry Pi 4 8Gb running Raspberry Pi OS Lite 64-bit is recommended.
#
#         Author:  Olly Stedall [ Bluesky: @olly.st / Twitter: @saltedlolly ]
#
#        Website:  https://diginode.tools
#
#        Support:  Telegram - https://t.me/DigiNodeTools
#                  Bluesky -  https://bsky.app/profile/digibyte.help
#                  Twitter -  https://twitter.com/diginodetools
#
#    Get Started:  curl http://setup.diginode.tools | bash  
#  
#                  Alternatively clone the repo to your home folder:
#
#                  cd ~
#                  git clone https://github.com/saltedlolly/diginode-tools/
#                  chmod +x ~/diginode-tools/diginode.sh
#
#                  To run DigiNode Dashboard:
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
# Both DigiNode Setup and Dashboard scripts make use of a settings file
# located at: ~/.digibyte/diginode.settings
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
# Whenever there is a new release, this number gets updated to match the release number on GitHub.
# The version number should be three numbers seperated by a period
# Do not change this number or the mechanism for installing updates may no longer work.
DGNT_VER_LOCAL=0.9.5
# Last Updated: 2024-01-12

# This is the command people will enter to run the install script.
DGNT_SETUP_OFFICIAL_CMD="curl -sSL setup.diginode.tools | bash"

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
COL_LIGHT_YEL='\e[1;33m'
TICK="  [${COL_LIGHT_GREEN}✓${COL_NC}]"
CROSS="  [${COL_LIGHT_RED}✗${COL_NC}]"
WARN="  [${COL_LIGHT_RED}!${COL_NC}]"
INFO="  [${COL_BOLD_WHITE}i${COL_NC}]"
SKIP="  [${COL_BOLD_WHITE}-${COL_NC}]"
INDENT="     "
# shellcheck disable=SC2034
DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
OVER="\\r\\033[K"

## Set ANSI code variables for colors and formatting

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

# Dashboard colors
dbcol_bwht="\e[97m"        # Bright White
dbcol_bred="\e[91m"        # Bright Red
dbcol_bylw="\e[93m"        # Bright Yellow
dbcol_bgrn="\e[92m"        # Bright Green
dbcol_bblu="\e[94m"        # Bright Blue
#########
dbcol_bld="\e[1m"          # Bold Text
dbcol_rst="\e[0m"          # Text Reset
#########
dbcol_bld_bwht="\e[1;37m"  # Bold Bright White Text


######## Undocumented Flags. Shhh ########
# These are undocumented flags; 
VERBOSE_MODE=false       # Set this to true to get more verbose feedback. Very useful for debugging.
UNINSTALL=false
LOCATE_DIGIBYTE=false
DISPLAY_HELP=false
EDIT_DGBCFG=false
EDIT_DGNTSET=false
VIEW_DGBLOG=false
VIEW_DGB2LOG=false
VIEW_DGBLOGMN=false
VIEW_DGBLOGTN=false
VIEW_DGBLOGRT=false
VIEW_DGBLOGSN=false
DGBCORE_RESTART=false
DGBCORE_STOP=false
DGB2CORE_RESTART=false
DGB2CORE_STOP=false
DGBPEERS=false
DGB2PEERS=false
VIEW_RPC_CREDENTIALS=false
UNKNOWN_FLAG=false
REENABLE_PORT_TEST=false
# Check arguments for the undocumented flags
# --dgndev (-d) will use and install the develop branch of DigiNode Tools (used during development)
for var in "$@"; do
    case "$var" in
        "--uninstall" ) UNINSTALL=true;;
        "--verbose" ) VERBOSE_MODE=true;;
        "--verboseoff" ) VERBOSE_MODE=false;;
        "--locatedgb" ) LOCATE_DIGIBYTE=true;;
        "--help" ) DISPLAY_HELP=true;;
        "-h" ) DISPLAY_HELP=true;;
        "--dgbcfg" ) EDIT_DGBCFG=true;;
        "--dgntset" ) EDIT_DGNTSET=true;;
        "--dgblog" ) VIEW_DGBLOG=true;;
        "--dgb2log" ) VIEW_DGB2LOG=true;;
        "--dgblogmn" ) VIEW_DGBLOGMN=true;;
        "--dgblogtn" ) VIEW_DGBLOGTN=true;;
        "--dgblogrt" ) VIEW_DGBLOGRT=true;;
        "--dgblogsn" ) VIEW_DGBLOGSN=true;;
        "--dgbrestart" ) DGBCORE_RESTART=true;;
        "--dgbstop" ) DGBCORE_STOP=true;;
        "--dgb2restart" ) DGB2CORE_RESTART=true;;
        "--dgb2stop" ) DGB2CORE_STOP=true;;
        "--dgbpeers" ) DGBPEERS=true;;
        "--dgb2peers" ) DGB2PEERS=true;;
        "--rpc" ) VIEW_RPC_CREDENTIALS=true;;
        "--porttest" ) REENABLE_PORT_TEST=true;;
        # If an unknown flag is used...
        *) UNKNOWN_FLAG=true;;
    esac
done



######################################################
######### FUNCTIONS ##################################
######################################################

# Run a command via a launch flag
flag_commands() {
if [ $UNKNOWN_FLAG = true ] || \
   [ $EDIT_DGBCFG = true ] || \
   [ $EDIT_DGNTSET = true ] || \
   [ $VIEW_DGBLOG = true ] || \
   [ $VIEW_DGB2LOG = true ] || \
   [ $VIEW_DGBLOGMN = true ] || \
   [ $VIEW_DGBLOGTN = true ] || \
   [ $VIEW_DGBLOGRT = true ] || \
   [ $VIEW_DGBLOGSN = true ] || \
   [ $DGBCORE_RESTART = true ] || \
   [ $DGBCORE_STOP = true ] || \
   [ $DGB2CORE_RESTART = true ] || \
   [ $DGB2CORE_STOP = true ] || \
   [ $DGB2CORE_STOP = true ] || \
   [ $DGBPEERS = true ] || \
   [ $DGB2PEERS = true ] || \
   [ $VIEW_RPC_CREDENTIALS = true ] || \
   [ $REENABLE_PORT_TEST = true ]; then
    printf "\\n"
    get_script_location              # Find which folder this script is running in (in case this is an unnoficial DigiNode)
    import_setup_functions           # Import diginode-setup.sh file because it contains functions we need

    # If this is an unknown flag, warn and quit
    if [ $UNKNOWN_FLAG = true ]; then # 
        printf "%b ERROR: Unrecognised flag used: $var\\n" "${WARN}"
        printf "\\n"
        printf "%b For help, enter:\\n" "${INDENT}"
        printf "\\n"
        printf "%b$ %bdiginode --help%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
        exit
    fi

    # Work out which DigiByte log file to display based on which chain is in use
    if [ $VIEW_DGBLOG = true ]; then # --dgblog
        diginode_tools_import_settings silent
        query_digibyte_chain
        if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
            VIEW_DGBLOGTN=true
        elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
            VIEW_DGBLOGRT=true
        elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
            VIEW_DGBLOGSN=true
        elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
            VIEW_DGBLOGMN=true
        fi
    fi

    if [ $EDIT_DGBCFG = true ]; then # --dgbcfg
        diginode_tools_import_settings silent
        set_text_editor
        if test -f $DGB_CONF_FILE; then
            exec $TEXTEDITOR $DGB_CONF_FILE
        else
            printf "%bError: digibyte.conf file does not exist\\n\\n" "${INDENT}"
            exit 1
        fi
    elif [ $EDIT_DGNTSET = true ]; then # --dgntset
        diginode_tools_import_settings silent
        set_text_editor  
        if test -f $DGNT_SETTINGS_FILE ; then
            exec $TEXTEDITOR $DGNT_SETTINGS_FILE 
        else
            printf "%bError: diginode.settings file does not exist\\n\\n" "${INDENT}"
        fi
    elif [ $VIEW_DGBLOGMN = true ]; then # --dgblogmn
        if [ "$DGB_SETTINGS_LOCATION" = "" ]; then
            diginode_tools_import_settings silent
        fi
        if test -f $DGB_SETTINGS_LOCATION/debug.log ; then
            echo "      ====================================="
            echo "         DigiByte Core MAINNET debug.log"
            echo "      ====================================="
            echo ""
            echo "    Displaying the last 50 lines from mainnet log file. Press Ctrl-C to Stop."
            echo ""
            exec tail -n50 -f $DGB_SETTINGS_LOCATION/debug.log
        else
            printf "%bError: DigiByte Core MAINNET log file does not exist\\n\\n" "${INDENT}"
            exit 1
        fi
    elif [ $VIEW_DGBLOGTN = true ] || [ $VIEW_DGB2LOG = true ]; then # --dgblogtn
        if [ "$DGB_SETTINGS_LOCATION" = "" ]; then
            diginode_tools_import_settings silent
        fi
        if test -f $DGB_SETTINGS_LOCATION/testnet4/debug.log ; then
            echo "      ====================================="
            echo "         DigiByte Core TESTNET debug.log"
            echo "      ====================================="
            echo ""
            echo "    Displaying the last 50 lines from testnet log file. Press Ctrl-C to Stop."
            echo ""
            exec tail -n50 -f $DGB_SETTINGS_LOCATION/testnet4/debug.log
        else
            printf "%bError: DigiByte Core TESTNET log file does not exist\\n\\n" "${INDENT}"
            exit 1
        fi
    elif [ $VIEW_DGBLOGRT = true ]; then # --dgblogrt
        if [ "$DGB_SETTINGS_LOCATION" = "" ]; then
            diginode_tools_import_settings silent
        fi
        if test -f $DGB_SETTINGS_LOCATION/regtest/debug.log ; then
            echo "      ====================================="
            echo "         DigiByte Core REGTEST debug.log"
            echo "      ====================================="
            echo ""
            echo "    Displaying the last 50 lines from regtest log file. Press Ctrl-C to Stop."
            echo ""
            exec tail -n50 -f $DGB_SETTINGS_LOCATION/regtest/debug.log
        else
            printf "%bError: DigiByte Core REGTEST log file does not exist\\n\\n" "${INDENT}"
            exit 1
        fi
    elif [ $VIEW_DGBLOGSN = true ]; then # --dgblogrt
        if [ "$DGB_SETTINGS_LOCATION" = "" ]; then
            diginode_tools_import_settings silent
        fi
        if test -f $DGB_SETTINGS_LOCATION/signet/debug.log ; then
            echo "      ====================================="
            echo "         DigiByte Core SIGNET debug.log"
            echo "      ====================================="
            echo ""
            echo "    Displaying the last 50 lines from signet log file. Press Ctrl-C to Stop."
            echo ""
            exec tail -n50 -f $DGB_SETTINGS_LOCATION/signet/debug.log
        else
            printf "%bError: DigiByte Core SIGNET log file does not exist\\n\\n" "${INDENT}"
            exit 1
        fi
    elif [ $DGBCORE_RESTART = true ]; then # --dgbrestart
        local str="Restarting digibyted service"
        printf "%b %s..." "${INFO}" "${str}"
        # If systemctl exists,
        if $(command -v systemctl >/dev/null 2>&1); then
            sudo systemctl restart digibyted &> /dev/null
        else
            # Otherwise, fall back to the service command
            sudo service digibyted restart &> /dev/null
        fi
        printf "%b%b %s...\\n\\n" "${OVER}" "${TICK}" "${str}"
        exit
     elif [ $DGBCORE_STOP = true ]; then # --stopdgb
        local str="Stopping digibyted service"
        printf "%b %s..." "${INFO}" "${str}"
        # If systemctl exists,
        if $(command -v systemctl >/dev/null 2>&1); then
            sudo systemctl stop digibyted &> /dev/null
        else
            # Otherwise, fall back to the service command
            sudo service digibyted stop &> /dev/null
        fi
        printf "%b%b %s...\\n\\n" "${OVER}" "${TICK}" "${str}"
        exit
    elif [ $DGB2CORE_RESTART = true ]; then # --dgbrestart
        diginode_tools_import_settings silent
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            local str="Restarting digibyted-testnet service"
            printf "%b %s..." "${INFO}" "${str}"
            # If systemctl exists,
            if $(command -v systemctl >/dev/null 2>&1); then
                sudo systemctl restart digibyted-testnet &> /dev/null
            else
                # Otherwise, fall back to the service command
                sudo service digibyted-testnet restart &> /dev/null
            fi
            printf "%b%b %s...\\n\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%bError: DigiByte Dual Node not installed.\\n\\n" "${INDENT}"
        fi
        exit
     elif [ $DGB2CORE_STOP = true ]; then # --stopdgb
        diginode_tools_import_settings silent
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            local str="Stopping digibyted-testnet service"
            printf "%b %s..." "${INFO}" "${str}"
            # If systemctl exists,
            if $(command -v systemctl >/dev/null 2>&1); then
                sudo systemctl stop digibyted-testnet &> /dev/null
            else
                # Otherwise, fall back to the service command
                sudo service digibyted-testnet stop &> /dev/null
            fi
            printf "%b%b %s...\\n\\n" "${OVER}" "${TICK}" "${str}"
        else
            printf "%bError: DigiByte Dual Node not installed.\\n\\n" "${INDENT}"
        fi
        exit
    elif [ $DGBPEERS = true ]; then # --dgbpeers
        diginode_tools_import_settings silent
        query_digibyte_chain
        if check_service_active "digibyted"; then
            printf "DigiByte $DGB_NETWORK_CURRENT Peers:\\n\\n"
            printf "IP4 Peers:\\n"
            ip4peers=$(digibyte-cli getpeerinfo | jq -r '.[] | {ip: .addr, port: .port} | "\(.ip):\(.port)"' | sed 's/:null$//' | grep -v '^\[')
            if [ -z "$ip4peers" ]; then
                echo "none"
            else
                echo "$ip4peers"
            fi
            printf "\\n"
            printf "IP6 Peers:\\n"
            ip6peers=$(digibyte-cli getpeerinfo | jq -r '.[] | {ip: .addr, port: .port} | "\(.ip):\(.port)"' | sed 's/:null$//'  | grep --color=never -E '^\[')
            if [ -z "$ip6peers" ]; then
                echo "none"
            else
                echo "$ip6peers"
            fi
            printf "\\n"
            exit
        else
            printf "%b %bERROR: DigiByte $DGB_NETWORK_CURRENT Node is not running.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            exit 1
        fi
    elif [ $DGB2PEERS = true ]; then # --dgb2peers
        if check_service_active "digibyted-testnet"; then
            printf "DigiByte TESTNET Node Peers:\\n\\n"
            printf "IP4 Peers:\\n"
            ip4peers=$(digibyte-cli -testnet getpeerinfo | jq -r '.[] | {ip: .addr, port: .port} | "\(.ip):\(.port)"' | sed 's/:null$//' | grep -v '^\[')
            if [ -z "$ip4peers" ]; then
                echo "none"
            else
                echo "$ip4peers"
            fi
            printf "\\n"
            printf "IP6 Peers:\\n"
            ip6peers=$(digibyte-cli -testnet getpeerinfo | jq -r '.[] | {ip: .addr, port: .port} | "\(.ip):\(.port)"' | sed 's/:null$//'  | grep --color=never -E '^\[')
            if [ -z "$ip6peers" ]; then
                echo "none"
            else
                echo "$ip6peers"
            fi
            printf "\\n"
            exit
        else
            printf "%b %bERROR: DigiByte TESTNET Node is not running.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            exit 1
        fi
    elif [ $VIEW_RPC_CREDENTIALS = true ]; then # --rpc
        diginode_tools_import_settings silent
        scrape_digibyte_conf
        query_digibyte_chain
        digibyte_rpc_query
        printf "DigiByte Core RPC Credentials:\\n\\n"
        printf "      RPC User: $RPC_USER\\n\\n"
        printf "  RPC Password: $RPC_PASSWORD\\n\\n"
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
        printf "     RPC Ports: $RPC_PORT (%s)   $RPC2_PORT (Testnet)\\n\\n" "$(echo "${DGB_NETWORK_CURRENT,,}" | sed 's/./\U&/1')"
        else
        printf "     RPC Ports: $RPC_PORT (%s)\\n\\n" "$(echo "${DGB_NETWORK_CURRENT,,}" | sed 's/./\U&/1')"
        fi
        exit
    elif [ $REENABLE_PORT_TEST = true ]; then # --porttest
        diginode_tools_import_settings silent

        printf "%b Re-enabling DigiByte Core MAINNET Port Test...\n" "${INFO}"
        DGB_MAINNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_FWD_STATUS=""
        sed -i -e "/^DGB_MAINNET_PORT_FWD_STATUS=/s|.*|DGB_MAINNET_PORT_FWD_STATUS=\"$DGB_MAINNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_TEST_PASS_DATE=""
        sed -i -e "/^DGB_MAINNET_PORT_TEST_PASS_DATE=/s|.*|DGB_MAINNET_PORT_TEST_PASS_DATE=\"$DGB_MAINNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_TEST_EXTERNAL_IP=""
        sed -i -e "/^DGB_MAINNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_MAINNET_PORT_TEST_EXTERNAL_IP=\"$DGB_MAINNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_NUMBER_SAVED=""
        sed -i -e "/^DGB_MAINNET_PORT_NUMBER_SAVED=/s|.*|DGB_MAINNET_PORT_NUMBER_SAVED=\"$DGB_MAINNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE
        
        printf "%b Re-enabling DigiByte Core TESTNET Port Test...\n" "${INFO}"
        DGB_TESTNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_FWD_STATUS=""
        sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_TEST_PASS_DATE=""
        sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=\"$DGB_TESTNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_TEST_EXTERNAL_IP=""
        sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_NUMBER_SAVED=""
        sed -i -e "/^DGB_TESTNET_PORT_NUMBER_SAVED=/s|.*|DGB_TESTNET_PORT_NUMBER_SAVED=\"$DGB_TESTNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        printf "%b Re-enabling IPFS Port Test...\n" "${INFO}"
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

        sleep 2

    fi



fi 

}

# Display DigiNode Setup help screen if the --help or -h flags was used
display_help() {
    if [ "$DISPLAY_HELP" = true ]; then
        echo ""
        get_script_location                     # Find which folder this script is running in (in case this is an unnoficial DigiNode)
        import_setup_functions                  # Import diginode-setup.sh file because it contains functions we need
        diginode_tools_import_settings silent
        query_digibyte_chain

        # Is Dual Node detected?
        if [ -f "$DGB2_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB2_UPSTART_SERVICE_FILE" ]; then
          DGB_DUAL_NODE="YES"
        else
          DGB_DUAL_NODE="NO"
        fi

        echo ""
        echo "  ╔════════════════════════════════════════════════════════╗"
        echo "  ║                                                        ║"
        echo "  ║          ${txtbld}D I G I N O D E   D A S H B O A R D${txtrst}           ║ "
        echo "  ║                                                        ║"
        echo "  ║         Monitor your DigiByte & DigiAsset Node         ║"
        echo "  ║                                                        ║"
        echo "  ╚════════════════════════════════════════════════════════╝" 
        echo ""
        printf "%bOptional flags when running DigiNode Dashboard:\\n" "${INDENT}"
        printf "\\n"
        printf "%b%b--help%b or %b-h%b    - Display this help screen.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b%b--dgbrestart%b    - Restart primary DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "%b%b--dgbstop%b       - Stop primary DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "%b%b--dgbpeers%b      - List peers for primary DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        else
            printf "%b%b--dgbrestart%b    - Restart DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "%b%b--dgbstop%b       - Stop DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "%b%b--dgbpeers%b      - List peers for DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        fi
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b%b--dgb2restart%b   - Restart secondary DigiByte Node (TESTNET).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "%b%b--dgb2stop%b      - Stop secondary DigiByte Node (TESTNET).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "%b%b--dgb2peers%b     - List peers for secondary DigiByte Node (TESTNET).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        fi
        printf "\\n"
        printf "%b%b--dgbcfg%b        - Edit digibyte.config file.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b%b--dgntset%b       - Edit diginode.settings file.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b%b--rpc%b           - View DigiByte Core RPC credentials.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b%b--porttest%b      - Re-enable the port tests.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"

        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b%b--dgblog%b        - View log file for primary DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        else
            printf "%b%b--dgblog%b        - View log file for DigiByte Node ($DGB_NETWORK_CURRENT).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        fi
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b%b--dgb2log%b       - View log file for secondary DigiByte Node (TESTNET).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        fi
        printf "%b                  You can also view the specific log files for each chain with: %b--dgblogmn%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "%b                  %b--dgblogtn%b (Testnet), %b--dgblogrt%b (Regtest) and %b--dgblogsn%b (Signet).\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}" "${COL_BOLD_WHITE}" "${COL_NC}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
        printf "%b%b--verbose%b       - Enable verbose mode. Provides more detailed feedback.\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
        printf "%bAppend the desired %b--flag%b to use:\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
        printf "%b$ %bdiginode --flag%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
        printf "\\n"
        exit
    fi
}

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
        printf "%b It contains functions we need to run the DigiNode Dashboard.\\n" "${INDENT}"
        printf "\\n"
        printf "%b If you have not already setup your DigiNode, please use\\n" "${INDENT}"
        printf "%b the official DigiNode Setup script:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   $DGNT_SETUP_OFFICIAL_CMD\\n" "${INDENT}"
        printf "\\n"
        printf "%b Alternatively, to use 'DigiNode Dashboard' with your existing\\n" "${INDENT}"
        printf "%b DigiByte node, clone the official repo to your home folder:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   cd ~ \\n" "${INDENT}"
        printf "%b   git clone https://github.com/saltedlolly/diginode-tools/ \\n" "${INDENT}"
        printf "%b   chmod +x ~/diginode-tools/diginode.sh \\n" "${INDENT}"
        printf "\\n"
        printf "%b To run it:\\n" "${INDENT}"
        printf "\\n"
        printf "%b   ~/diginode-tools/diginode.sh\\n" "${INDENT}"
        printf "\\n"
        exit 1
    fi
}

# A simple function that clears the sreen and displays the Dashboard title in a box
digimon_title_box() {
    clear -x
    tput civis
    tput smcup
    echo ""
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║                                                        ║"
    echo "  ║          ${txtbld}D I G I N O D E   D A S H B O A R D${txtrst}           ║ "
    echo "  ║                                                        ║"
    echo "  ║         Monitor your DigiByte & DigiAsset Node         ║"
    echo "  ║                                                        ║"
    echo "  ╚════════════════════════════════════════════════════════╝" 
    echo ""
}

# Show a disclaimer text during testing phase
digimon_disclaimer() {
    printf "%b %bWARNING: This script is currently in public beta.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "%b Please join the Telegram support group to report any bugs and share feedback.\\n" "${INDENT}"
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
        printf "%b 3. ${txtbld}Skip locating an existing DigiByte Node${txtrst}\\n" "${INDENT}"
        printf "%b    If there is an existing DigiByte Node installed on this system,\\n" "${INDENT}"
        printf "%b    it will not be monitored.\\n" "${INDENT}"
        printf "\\n"
        printf "%b 4. ${txtbld}EXIT${txtrst}\\n" "${INDENT}"
        printf "%b    Exit DigiNode Dashboard.\\n" "${INDENT}"
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
            exec curl -sSL setup.diginode.tools | bash -s -- --fulldiginode
        elif [ "$DGNT_RUN_LOCATION" = "local" ]; then
            ~/diginode-tools/diginode-setup.sh --fulldiginode
        fi  
        exit
      elif [[ $REPLY =~ ^[1]$ ]]; then
        printf "\\n" 
        printf "%b Prompting for absoute path of digibyte core install folder...\\n" "${INFO}"

        DGB_CORE_PATH=$(whiptail --inputbox "Please enter the absolute path of your DigiByte Core install folder.\\n\\nExample: /usr/bin/digibyted" 10 78 --title "Enter the absolute path of your DigiByte Node." 3>&1 1>&2 2>&3)
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

    # Check if digibyte core is configured to run as a service

    if [ -f "$DGB_SYSTEMD_SERVICE_FILE" ] || [ -f "$DGB_UPSTART_SERVICE_FILE" ]; then
      find_dgb_service="yes"
      if [ $VERBOSE_MODE = true ]; then
          if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b Primary DigiByte Node service file is installed\\n" "${TICK}"
          else
            printf "%b DigiByte Node service file is installed\\n" "${TICK}"
          fi
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
        printf "%b digibyte.conf file located.\\n" "${TICK}"
        scrape_digibyte_conf
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

    # If digibyed service is failing, then display the error
    if [ $(systemctl is-active digibyted) = 'failed' ] && [ "$is_dgb_installed" = "yes" ]; then

        local known_dgb_service_error
        known_dgb_service_error="no"

        IS_CHAIN_CONFIG_VALID=$(digibyted stop 2>&1 | grep -Eo "Invalid combination of -regtest, -signet, -testnet and -chain.")
        if [ "$IS_CHAIN_CONFIG_VALID" = "Invalid combination of -regtest, -signet, -testnet and -chain." ]; then
            known_dgb_service_error="yes"
            printf "\\n"
            printf "%b %bERROR: Invalid combination of -regtest, -signet, -testnet and -chain.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b Your digibyte.conf file contains an invalid combination -regtest, -signet,\\n" "${INDENT}"
            printf "%b -testnet and -chain. You can use at most one. For this reason, the DigiByte daemon.\\n" "${INDENT}"
            printf "%b is unable to start. Please edit your digibyte.conf to fix this:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   %bdiginode --dgbcfg%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
            printf "%b Restart DigiByte daemon when done:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   %bdiginode --dgbrestart%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
            exit 1
        fi

        if [ $known_dgb_service_error = "no" ]; then
            printf "\\n"
            printf "%b %bERROR: digibyted service does not appear to be running.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            DGB_STATUS="stopped"
        fi

        # Kill digibyted in case it started running by accident
 #       dgb_process_id=$(pgrep digibyted)
 #       if [ "$dgb_process_id" != "" ]; then
 #           kill -9 $dgb_process_id
 #       fi
 #       printf "\\n"
 #       exit 1

    fi

    # Find out which DGB network is running - main, test, regtest, signet
    if [ "$DGB_DUAL_NODE" = "YES" ]; then
        str="Checking primary DigiByte Node chain..."
    else
        str="Checking DigiByte Node chain..."
    fi
    printf "%b %s" "${INFO}" "${str}"

    # Query if DigiByte Core is running the mainn, test, regtest ro signet chain
    query_digibyte_chain

    if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
        printf "%b%b %s %bTESTNET%b (live)\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_YEL}" "${COL_NC}"
    elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
        printf "%b%b %s %bREGTEST%b (live)\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_YEL}" "${COL_NC}"
    elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
        printf "%b%b %s %SIGNET%b (live)\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_YEL}" "${COL_NC}"
    elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "YES" ]; then 
        printf "%b%b %s MAINNET (live)\\n" "${OVER}" "${TICK}" "${str}"
    elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
        printf "%b%b %s %bTESTNET%b (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_YEL}" "${COL_NC}"
    elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
        printf "%b%b %s %bREGTEST%b (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_YEL}" "${COL_NC}"
    elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
        printf "%b%b %s %SIGNET%b (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}" "${COL_LIGHT_YEL}" "${COL_NC}"
    elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$DGB_NETWORK_CURRENT_LIVE" = "NO" ]; then 
        printf "%b%b %s MAINNET (from digibyte.conf)\\n" "${OVER}" "${TICK}" "${str}"
    fi



    # Get current listening port
    digibyte_port_query

    # Show current listening port of primary DigiByte Node
    if [ "$DGB_LISTEN_PORT" != "" ] && [ "$DGB_LISTEN_PORT_LIVE" = "YES" ]; then
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b Primary DigiByte Node listening port: $DGB_LISTEN_PORT (live)\\n" "${INFO}"
        else
            printf "%b DigiByte Node listening port: $DGB_LISTEN_PORT (live)\\n" "${INFO}"
        fi
    elif [ "$DGB_LISTEN_PORT" != "" ] && [ "$DGB_LISTEN_PORT_LIVE" = "NO" ]; then
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b Primary DigiByte Node listening port: $DGB_LISTEN_PORT (from digibyte.conf)\\n" "${INFO}"
        else
            printf "%b DigiByte Node listening port: $DGB_LISTEN_PORT (from digibyte.conf)\\n" "${INFO}"
        fi
    fi

    # Show current listening port of secondary DigiByte Node
    if [ "$DGB_DUAL_NODE" = "YES" ]; then
        if [ "$DGB2_LISTEN_PORT" != "" ] && [ "$DGB2_LISTEN_PORT_LIVE" = "YES" ]; then
            printf "%b Secondary DigiByte Node listening port: $DGB2_LISTEN_PORT (live)\\n" "${INFO}"
        elif [ "$DGB2_LISTEN_PORT" != "" ] && [ "$DGB2_LISTEN_PORT_LIVE" = "NO" ]; then
            printf "%b Secondary DigiByte Node listening port: $DGB2_LISTEN_PORT (from digibyte.conf)\\n" "${INFO}"
        fi
    fi


    # Get maxconnections from digibyte.conf
    digibyte_maxconnections_query
    if [ "$DGB_MAXCONNECTIONS" != "" ]; then
      printf "%b DigiByte Core max connections: $DGB_MAXCONNECTIONS\\n" "${INFO}"
    fi

    printf "\\n"

    # Run checks to see DigiByte Core is running

    # Check if digibyte daemon is running as a service.
    if [ $(systemctl is-active digibyted) = 'active' ]; then
       if [ $VERBOSE_MODE = true ]; then
          if [ "$DGB_DUAL_NODE" = "YES" ]; then
                printf "  %b Primary DigiByte Node is running as a service\\n" "${TICK}"
            else
                printf "  %b DigiByte Node is running as a service\\n" "${TICK}"
            fi
       fi
       DGB_STATUS="running"
    else
      # Check if digibyted is running (but not as a service).
      if [ "" != "$(pgrep digibyted)" ] && [ "$DGB_DUAL_NODE" = "NO" ]; then
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
        if [ "" != "$(pgrep digibyte-qt)" ]; then
            if [ $VERBOSE_MODE = true ]; then
              printf "%b digibyte-qt is running\\n" "${TICK}"
            fi
            DGB_STATUS="running"
        # Exit if digibyted is not running
        else
#          printf "\\n"
#          printf "%b %bERROR: DigiByte daemon is not running.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
#          printf "%b DigiNode Dashboard cannot start as your DigiByte Node is not currently running.\\n" "${INDENT}"
#          printf "%b Please start digibyted and then relaunch the Dashboard.\\n" "${INDENT}"
#          printf "%b DigiNode Setup can help you to setup DigiByte daemon to run as a service\\n" "${INDENT}"
#          printf "%b so that it launches automatically at boot.\\n" "${INDENT}"
#          printf "\\n"
          DGB_STATUS="stopped"
        fi
      fi
    fi

    # Tell user to reboot if the RPC username or password in digibyte.conf have recently been changed
    if [ "$DGB_STATUS" = "running" ]; then
        IS_RPC_CREDENTIALS_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Incorrect rpcuser or rpcpassword")
        if [ "$IS_RPC_CREDENTIALS_CHANGED" = "Incorrect rpcuser or rpcpassword" ]; then
            printf "\\n"
            printf "%b %bERROR: Incorrect rpcuser or rpcpassword.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b The RPC credentials have been changed. You need to run DigiNode Setup\\n" "${INDENT}"
            printf "%b and choose 'Update' from the menu to update your settings.\\n" "${INDENT}"
            printf "%b To do this now enter:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   %bdiginode-setup%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
            exit
        fi
        IS_RPC_PORT_CHANGED=$(sudo -u $USER_ACCOUNT $DGB_CLI getblockcount 2>&1 | grep -Eo "Could not connect to the server")
        if [ "$IS_RPC_PORT_CHANGED" = "Could not connect to the server" ]; then
            printf "\\n"
            printf "%b %bERROR: Could not connect to the digibyed server.%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            printf "\\n"
            printf "%b The RPC credentials have been changed. Try restarting the DigiByte daemon:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   %bdiginode --dgbrestart%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
            printf "%b If that fails, you need to run DigiNode Setup and choose 'Update' from\\n" "${INDENT}"
            printf "%b the menu to update your settings. To do this now enter:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   %bdiginode-setup%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
            exit
        fi
    fi

    # Display message if the DigiByte Node is running okay

    if [ "$find_dgb_folder" = "yes" ] && [ "$find_dgb_binaries" = "yes" ] && [ "$find_dgb_settings_folder" = "yes" ] && [ "$find_dgb_conf_file" = "yes" ] && [ "$DGB_STATUS" = "running" ]; then
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b %bPrimary DigiByte Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        else
            printf "%b %bDigiByte Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        fi
    elif [ "$find_dgb_folder" = "yes" ] && [ "$find_dgb_binaries" = "yes" ] && [ "$find_dgb_settings_folder" = "yes" ] && [ "$find_dgb_conf_file" = "yes" ]; then
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
            printf "%b %bPrimary DigiByte Node Status: STOPPED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            DGB_STATUS="stopped"
        else
            printf "%b %bDigiByte Node Status: STOPPED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            DGB_STATUS="stopped"
        fi
    fi

    # If available, is the secondary DigiByte Node running?
    if [ "$find_dgb_folder" = "yes" ] && [ "$find_dgb_binaries" = "yes" ] && [ "$find_dgb_settings_folder" = "yes" ] && [ "$find_dgb_conf_file" = "yes" ]; then
        if [ "$DGB_DUAL_NODE" = "YES" ]; then
          if check_service_active "digibyted-testnet"; then
              DGB2_STATUS="running"
              printf "\\n"
              printf "%b %bSecondary DigiByte Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
          else
              DGB2_STATUS="notrunning"
              printf "\\n"
              printf "%b %bSecondary DigiByte Node Status: STOPPED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
          fi
        fi
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
    if [ "$NODEJS_STATUS" = "installed" ]; then
        str="Is Node.js at least version 16?..."
        NODEJS_VER_LOCAL_MAJOR=$(echo $NODEJS_VER_LOCAL | cut -d'.' -f 1)
        if [ "$NODEJS_VER_LOCAL_MAJOR" != "" ]; then
            printf "%b %s" "${INFO}" "${str}"
            if [ "$NODEJS_VER_LOCAL_MAJOR" -lt "16" ]; then
                printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}"
                nodejs_installed="no"
                STARTWAIT="yes"
            else
                printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"
                DGA_STATUS="nodejsinstalled"
                nodejs_installed="yes"
            fi
        fi
    else
        nodejs_installed="no"
        STARTWAIT="yes"
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

      if [ "$nodejs_installed" = "yes" ] && [ "$ipfs_installed" = "yes" ]; then 
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
          if [ "$nodejs_installed" = "no" ]; then
              printf "%b NodeJS is required to run a DigiAsset Node and is not currently installed.\\n" "${INFO}"
          fi
          if [ "$ipfs_installed" = "no" ]; then
              printf "%b Kubo is not installed. JS-IPFS will be used.\\n" "${INFO}"
          fi

          STARTWAIT="yes"
        fi

      # Check if ipfs service is running. Required for DigiAssets server.

      # ps aux | grep ipfs

      # If Kubo is installed, check if the daemon is running
      if [ "$ipfs_installed" = "yes" ]; then

          if [ "" = "$(pgrep ipfs)" ]; then
              printf "%b IPFS Kubo daemon is NOT running\\n" "${CROSS}"
              ipfs_running="no"
              DGA_STATUS="not_detected"
          else
              printf "%b IPFS Kubo daemon is running\\n" "${TICK}"
              if [ "$DGA_STATUS" = "ipfsinstalled" ]; then
                DGA_STATUS="ipfsrunning"
              fi
              ipfs_running="yes"
          fi

      fi

        # Check to see if the DigiAsset Node is running, even if IPFS isn't running or installed (this means it is likely using js-IPFS)
        if [ "$ipfs_running" = "no" ] || [ "$DGA_STATUS" = "not_detected" ]; then

            DGA_CONSOLE_QUERY=$(curl --max-time 4 localhost:8090/api/status/console.json 2>/dev/null)
            if [ "$DGA_CONSOLE_QUERY" != "" ]; then
                ipfs_running="yes"
                DGA_STATUS="ipfsrunning"
                printf "%b js-IPFS is likely being used\\n" "${TICK}"
            fi
        fi


      # Check for 'digiasset_node' index.js file

      if [ -f "$DGA_INSTALL_LOCATION/index.js" ]; then
        DGA_STATUS="installed" 
        printf "%b DigiAsset Node software is installed.\\n" "${TICK}"
      else
          printf "%b DigiAsset Node software cannot be found.\\n" "${CROSS}"
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
            do_pm2_check=false
            printf "%b DigiAsset Node is running with 'node index.js'\\n\\n" "${INFO}"
            printf "%b %bDigiAsset Node Status: RUNNING%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        else
            printf "%b DigiAsset Node is not running with 'node index.js'\\n" "${INFO}"
            do_pm2_check=true
        fi

         # If that didn't work, check if it is running using PM2

        if [ "$do_pm2_check" = true ]; then
           
            IS_PM2_RUNNING=$(pm2 pid digiasset 2>/dev/null)

            # In case it has not been named, double check
            if [ "$IS_PM2_RUNNING" = "" ]; then
                IS_PM2_RUNNING=$(pm2 pid index 2>/dev/null)
            fi

            if [ "$IS_PM2_RUNNING" = "" ]; then
                DGA_STATUS="stopped"
                STARTWAIT="yes"
                printf "%b DigiAsset Node PM2 Service does not exist.\\n\\n" "${INFO}"
                printf "%b %bDigiAsset Node Status: NOT RUNNING%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            elif [ "$IS_PM2_RUNNING" = "0" ]; then
                DGA_STATUS="stopped"
                STARTWAIT="yes"
                printf "%b DigiAsset Node PM2 Service is stopped.\\n\\n" "${INFO}"
                printf "%b %bDigiAsset Node Status: NOT RUNNING%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
            else
                DGA_STATUS="running"
                printf "%b DigiAsset Node PM2 Service is running.\\n\\n" "${INFO}"
                printf "%b %bDigiAsset Node Status: RUNNING%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
            fi    
        fi
    elif [ "$DGA_STATUS" = "not_detected" ]; then
        printf "%b %bDigiAsset Node Status: NOT DETECTED%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        STARTWAIT="yes"
    elif [ "$DGA_STATUS" != "" ]; then
        printf "%b %bDigiAsset Node Status: NOT RUNNING%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        STARTWAIT="yes"
    fi

    printf "\\n"

}

# Get RPC CREDENTIALS from digibyte.conf
check_dgb_rpc_credentials() {

    if [ -f "$DGB_CONF_FILE" ]; then

        # Store the DigiByte Core verion as a single digit
        DGB_LOCAL_VER_DIGIT_QUERY="${DGB_LOCAL_VER:0:1}"
        if [ "$DGB_LOCAL_VER_DIGIT_QUERY" != "" ]; then
            DGB_LOCAL_VER_DIGIT=$DGB_LOCAL_VER_DIGIT_QUERY
        fi

        # Get RPC credentials
        digibyte_rpc_query

      if [ "$RPC_USER" != "" ] && [ "$RPC_PASSWORD" != "" ] && [ "$RPC_PORT" != "" ] && [ "$RPC_BIND" != "error" ]; then
        RPC_CREDENTIALS_OK="yes"
        printf "%b DigiByte RPC credentials found: ${TICK} Username     ${TICK} Password\\n" "${TICK}"
        printf "                                      ${TICK} RPC Port     ${TICK} Bind\\n\\n" "${TICK}"
      else
        RPC_CREDENTIALS_OK="NO"
        printf "%b %bERROR: DigiByte RPC credentials are missing:%b" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        if [ "$RPC_USER" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Username     "
        if [ "$RPC_PASSWORD" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " Password\\n"
        printf "                                                  "
        if [ "$RPC_PORT" != "" ]; then
          printf "${TICK}"
        else
          printf "${CROSS}"
        fi
        printf " RPC Port     "
        if [ "$RPC_BIND" = "error" ]; then
          printf "${CROSS}"
        else
          printf "${TICK}"
        fi
        printf " Bind\n"
        printf "\\n"

        # Exit if there a missing RPC credentials and the DigiAsset Node is running
        if [ "$DGA_STATUS" = "running" ]; then
            printf "%b You need to add the missing DigiByte Core RPC credentials to your digibyte.conf file.\\n" "${INFO}"
            printf "%b Without them your DigiAsset Node is unable to communicate with your DigiByte Node.\\n" "${INDENT}"
            printf "\\n"
            printf "%b Edit the digibyte.conf file:\\n" "${INDENT}"
            printf "\\n"
            printf "%b   %bdiginode --dgbcfg%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
            printf "%b Check that the following is included in the [${DGB_NETWORK_CHAIN}] section:\\n" "${INDENT}"
            printf "\\n"
            if [ "$RPC_USER" = "" ]; then
                printf "%b   rpcuser=desiredusername      # change 'desiredusername' to something else\\n" "${INDENT}"
            fi
            if [ "$RPC_PASSWORD" = "" ]; then
                printf "%b   rpcpassword=desiredpassword  # change 'desiredpassword' to something else\\n" "${INDENT}"
            fi
            if [ "$RPC_PORT" = "" ] && [ "$DGB_NETWORK_CHAIN" = "main" ]; then
                printf "%b   rpcport=14022# best to leave this as is\\n" "${INDENT}"
            fi
            if [ "$RPC_PORT" = "" ] && [ "$DGB_NETWORK_CHAIN" = "test" ]; then
                printf "%b   rpcport=14023\\n" "${INDENT}"
            fi
            if [ "$RPC_PORT" = "" ] && [ "$DGB_NETWORK_CHAIN" = "regtest" ]; then
                printf "%b   rpcport=18443\\n" "${INDENT}"
            fi
            if [ "$RPC_BIND" = "error" ]; then
                printf "%b   rpcbind=127.0.0.1            \\n" "${INDENT}"
            fi
            printf "\\n"
            printf "%b Restart DigiByte Core when you are done: \\n" "${INDENT}"
            printf "\\n"
            printf "%b   %bdiginode --dgbrestart%b\\n" "${INDENT}" "${COL_BOLD_WHITE}" "${COL_NC}"
            printf "\\n"
            exit 1
        fi
      fi
    fi
}

# Query the DigiAsset Node console for the current status
update_dga_console() {

if [ "$DGA_STATUS" = "running" ] || [ "$DGA_STATUS" = "stopped" ]; then

    DGA_CONSOLE_QUERY=$(curl --max-time 4 localhost:8090/api/status/console.json 2>/dev/null)

    if [ "$DGA_CONSOLE_QUERY" != "" ]; then

        DGA_STATUS="running"

        DGA_PORT_QUERY=$(curl --max-time 0.01 localhost:8090/api/status/port.json 2>/dev/null)
        DGA_PAYOUT_ADDRESS=$(cat $DGA_SETTINGS_FILE | jq .optIn.payout | sed 's/"//g')

        DGA_CONSOLE_WALLET=$(echo "$DGA_CONSOLE_QUERY" | jq | grep Wallet: | cut -d'm' -f 2 | cut -d'\' -f 1)
        DGA_CONSOLE_STREAM=$(echo "$DGA_CONSOLE_QUERY" | jq | grep Stream: | cut -d'm' -f 3 | cut -d'\' -f 1)
        DGA_CONSOLE_SECURITY=$(echo "$DGA_CONSOLE_QUERY" | jq | grep Security: | cut -d'm' -f 2 | cut -d'\' -f 1)
        DGA_CONSOLE_IPFS=$(echo "$DGA_CONSOLE_QUERY" | jq | grep IPFS: | cut -d'm' -f 2- | cut -d'\' -f 1)
        DGA_CONSOLE_BLOCK_HEIGHT=$(echo "$DGA_CONSOLE_QUERY" | jq | grep "Block Height:" | cut -d'm' -f 2- | cut -d'\' -f 1)

        IPFS_PORT_NUMBER=$(echo $DGA_CONSOLE_IPFS | sed 's/[^0-9]//g')

        # If the console didn't provide a port number, get it direct from the port query
        if [ "$IPFS_PORT_NUMBER" = "" ] && [ "$DGA_PORT_QUERY" != "" ]; then
            IPFS_PORT_NUMBER=$DGA_PORT_QUERY
        fi

        is_blocked=$(echo "$DGA_CONSOLE_IPFS" | grep -Eo Blocked)
        is_running=$(echo "$DGA_CONSOLE_IPFS" | grep -Eo Running)
        is_sync_system_failed=$(echo "$DGA_CONSOLE_BLOCK_HEIGHT" | grep -Eo "Sync System Failed")

        # If DGA_CONSOLE_BLOCK_HEIGHT is an iteger (i.e. it is displaying the block height), format it with commas to make it easily readable
        if [[ $DGA_CONSOLE_BLOCK_HEIGHT =~ ^-?[0-9]+$ ]]; then
            DGA_CONSOLE_BLOCK_HEIGHT=$(printf "%'d" $DGA_CONSOLE_BLOCK_HEIGHT)
        fi


        # Is the IPFS port blocked
        if [ "$is_blocked" = "Blocked" ]; then
            IPFS_PORT_STATUS_CONSOLE="BLOCKED"
            IPFS_PORT_STATUS_COLOR=""
        elif [ "$is_running" = "Running" ]; then
            IPFS_PORT_STATUS_CONSOLE="OPEN"
            IPFS_PORT_STATUS_COLOR=""
        else
            IPFS_PORT_STATUS_CONSOLE="OPEN"
            IPFS_PORT_STATUS_COLOR="YELLOW"
        fi

        # Is the sync system failed
        if [ "$is_sync_system_failed" = "Sync System Failed" ]; then
            DGA_BLOCK_HEIGHT_COLOR="RED"
        elif [ "$DGA_CONSOLE_BLOCK_HEIGHT" = "Initializing" ]; then
            DGA_CONSOLE_BLOCK_HEIGHT="Initializing..."
            DGA_BLOCK_HEIGHT_COLOR="YELLOW"
        else
            DGA_BLOCK_HEIGHT_COLOR=""
        fi

    else
        DGA_STATUS="stopped"
    fi

fi  

}

# Format the DigiAsset Node console data
format_dga_console() {

# Format Stream
if [ "$DGA_CONSOLE_STREAM" = "Connected" ]; then
    DGA_CONSOLE_STREAM="[✓]"
else
    DGA_CONSOLE_STREAM="[✗]"
fi

# Format Security (PAssword)
if [ "$DGA_CONSOLE_SECURITY" = "Connected" ]; then
    DGA_CONSOLE_SECURITY="[✓]"
else
    DGA_CONSOLE_SECURITY="[✗]"
fi

# Format Wallet
if [ "$DGA_CONSOLE_WALLET" = "Connected" ]; then
    DGA_CONSOLE_WALLET="[✓]"
else
    DGA_CONSOLE_WALLET="[✗]"
fi

if [ "$DGA_PAYOUT_ADDRESS" = "null" ] || [ "$DGA_PAYOUT_ADDRESS" = "" ]; then
    DGA_PAYOUT_ADDRESS_STATUS="[✗]"
else
    DGA_PAYOUT_ADDRESS_STATUS="[✓]"
fi

#IPFS_PORT_STATUS_CONSOLE="BLOCKED"
#IPFS_PORT_STATUS_COLOR="YELLOW"
#DGA_BLOCK_HEIGHT_COLOR="YELLOW"

# Display IPFS Status in red if the port is blocked
if [ "$IPFS_PORT_STATUS_CONSOLE" = "BLOCKED" ]; then
    printf " ║ DIGIASSET NODE ║    IPFS STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbred}$DGA_CONSOLE_IPFS${txtrst}" " ║ "
elif [ "$IPFS_PORT_STATUS_COLOR" = "YELLOW" ]; then
    printf " ║ DIGIASSET NODE ║    IPFS STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbylw}$DGA_CONSOLE_IPFS${txtrst}" " ║ "
else
    printf " ║ DIGIASSET NODE ║    IPFS STATUS ║  " && printf "%-${col_width_dgb_uptime}s %-3s\n" "$DGA_CONSOLE_IPFS" " ║ "
fi

echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
if [ $term_width -gt 124 ]; then 
    printf " ║                ║    NODE STATUS ║  " && printf "%-${col_width_dga_status}s %-3s\n" "$DGA_CONSOLE_WALLET DigiByte Wallet Connection   $DGA_CONSOLE_STREAM Stream   $DGA_CONSOLE_SECURITY Password   $DGA_PAYOUT_ADDRESS_STATUS DGB Payout Address" " ║ "
elif [ $term_width -gt 111 ]; then 
    printf " ║                ║    NODE STATUS ║  " && printf "%-${col_width_dga_status}s %-3s\n" "$DGA_CONSOLE_WALLET Wallet Connection   $DGA_CONSOLE_STREAM Stream   $DGA_CONSOLE_SECURITY Password   $DGA_PAYOUT_ADDRESS_STATUS Payout Address" " ║ "
else
    printf " ║                ║    NODE STATUS ║  " && printf "%-${col_width_dga_status}s %-3s\n" "$DGA_CONSOLE_WALLET Wallet   $DGA_CONSOLE_STREAM Stream   $DGA_CONSOLE_SECURITY Password   $DGA_PAYOUT_ADDRESS_STATUS Payout" " ║ "
fi

echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
if [ "$DGA_BLOCK_HEIGHT_COLOR" = "RED" ]; then
    printf " ║                ║   BLOCK HEIGHT ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "ERROR: ${txtbred}$DGA_CONSOLE_BLOCK_HEIGHT${txtrst}" " ║ "
elif [ "$DGA_BLOCK_HEIGHT_COLOR" = "YELLOW" ]; then
    printf " ║                ║   BLOCK HEIGHT ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbylw}$DGA_CONSOLE_BLOCK_HEIGHT${txtrst}" " ║ "
else
    printf " ║                ║   BLOCK HEIGHT ║  " && printf "%-${col_width_dgb_uptime}s %-3s\n" "$DGA_CONSOLE_BLOCK_HEIGHT Blocks" " ║ "
fi

echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
if [ "$IS_AVAHI_INSTALLED" = "yes" ]; then

    # Setup IP6 display array
    webui_leftcol=" ║                ║         WEB UI ║  "
    webui_leftcol2=" ║                ║                ║  "
    webui_bothurl="http://$HOSTNAME.local:8090   http://$IP4_INTERNAL:8090"
    webui_bothurl_width=${#webui_bothurl}
    webui_bothurl1="http://$HOSTNAME.local:8090"
    webui_bothurl2="http://$IP4_INTERNAL:8090"

    # Display web UI urls
    if [ $term_width -gt $(( webui_bothurl_width + 41 )) ]; then
        db_content_c1_c2_c3f "$webui_leftcol" "$webui_bothurl"
    else
        db_content_c1_c2_c3f "$webui_leftcol" "$webui_bothurl1"
        db_content_c1_c2_c3f "$webui_leftcol2" "$webui_bothurl2"
    fi

else
    printf " ║                ║         WEB UI ║  " && printf "%-${col_width_dgb_uptime}s %-3s\n" "http://$IP4_INTERNAL:8090" " ║ "
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
      printf "%b avahi-daemon is installed. URL: http://${HOSTNAME}.local:8090\\n"  "${TICK}"
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
      printf "%b jq is a required package and will be installed. It is required for\\n"  "${INFO}"
      printf "%b manipulating JSON files.\\n"  "${INDENT}"
      install_jq="yes"
      printf "\\n"
    else
      printf "%b jq is installed.\\n"  "${TICK}"
    fi
    printf "\\n"
}

##  Check if jq package is installed
is_sysstat_installed() {
    REQUIRED_PKG="sysstat"
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
    if [ "" = "$PKG_OK" ]; then
      printf "%b sysstat is NOT installed.\\n"  "${CROSS}"
      printf "\\n"
      printf "%b sysstat is a required package and will be installed. It contains\\n"  "${INFO}"
      printf "%b mpstat that is used for monitoring CPU usage.\\n"  "${INDENT}"
      install_sysstat="yes"
      printf "\\n"
    else
      printf "%b sysstat is installed.\\n"  "${TICK}"
    fi
    printf "\\n"
}


# Check if digibyte core wallet is enabled
is_wallet_enabled() {

if [ "$DGB_STATUS" = "running" ]; then

    printf " =============== Checking: DigiByte Wallet ==============================\\n\\n"
    # ===============================================================================

    if [ -f "$DGB_CONF_FILE" ]; then
      DGB_WALLET_STATUS=$(cat $DGB_CONF_FILE | grep disablewallet | cut -d'=' -f 2)
      if [ "$DGB_WALLET_STATUS" = "1" ]; then
        DGB_WALLET_STATUS="disabled"
        printf "%b %bDigiByte Wallet Status: DISABLED%b\\n"  "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        if [ "$DGA_STATUS" = "running" ]; then
            printf "\\n"
            printf "%b The DigiByte Core wallet is required if you want to create DigiAssets\\n" "${INFO}"
            printf "%b from within the web UI. You can enable it by editing the digibyte.conf\\n" "${INDENT}"
            printf "%b file and removing the disablewallet=1 flag.\\n" "${INDENT}"
        fi
        STARTWAIT="yes"
      else
        DGB_WALLET_STATUS="enabled"
        printf "%b %bDigiByte Wallet Status: ENABLED%b\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      fi
      printf "\\n"
    fi
fi

}

# Install needed packages
install_required_pkgs() {
    if [ "$install_jq" = "yes" ] || [ "$install_sysstat" = "yes" ]; then
      printf "\\n"
      printf "%b Enter your password to install required packages. Press Ctrl-C to cancel.\n" "${INFO}"
      printf "\\n"
    fi
    if [ "$install_jq" = "yes" ]; then
      sudo apt-get --yes install jq
    fi
    if [ "$install_sysstat" = "yes" ]; then
      sudo apt-get --yes install sysstat
    fi
}

# Quit message - this functions runs automatically before exiting
quit_message() {

    kill $bg_cpu_stats_pid
    rm -f "$cpu1_file" "$cpu2_file" "$avg_file"

    tput rmcup
    stty echo
    tput sgr0

    # Enabling line wrapping.
    printf '\e[?7h'

    #Set this so the backup reminder works
    NewInstall=False

    # On quit, if there are updates available, ask the user if they want to install them
    if [ "$DGB_UPDATE_AVAILABLE" = "yes" ] || [ "$DGA_UPDATE_AVAILABLE" = "yes" ] || [ "$DGNT_UPDATE_AVAILABLE" = "yes" ] || [ "$IPFS_UPDATE_AVAILABLE" = "yes" ] && [ "$auto_quit" != true ]; then

      # Install updates now

      printf "\\n"

      # Choose a random DigiFact
#      digifact_randomize

      # Display a random DigiFact
      display_digifact_fixedwidth

      printf "  %b %bThere are software updates available for your DigiNode.%b\\n"  "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
      printf "\\n"
      read -n 1 -r -s -p "         Would you like to install them now? (Y/N)"
      printf "\\n"

      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        printf "%b Installing updates...\\n" "${INFO}"
        echo ""
        exec curl -sSL setup.diginode.tools | bash -s -- --unattended --statusmonitor
        
        # Display cursor again
        tput cnorm
        updates_installed="yes"

        # Enabling line wrapping.
        printf '\e[?7h'

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

      # Display a random DigiFact
      display_digifact_fixedwidth

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
 #     digifact_randomize

      # Display a random DigiFact
      display_digifact_fixedwidth

      printf "\\n"

      #Share backup reminder
      backup_reminder

      # Display reminder that you can manually specify the location of the DigiByte install folder
      exit_locate_digibyte_reminder
  fi

if [ "$auto_quit" = true ]; then
    echo ""
    printf "%b DigiNode Dashboard quit automatically as it was left running\\n" "${INFO}"
    printf "%b for more than $SM_AUTO_QUIT minutes. You can increase the auto-quit duration\\n" "${INDENT}"
    printf "%b by changing the SM_AUTO_QUIT value in diginode.settings\\n" "${INDENT}"
    echo ""
    printf "%b To edit it: ${txtbld}diginode --dgntset${txtrst}\\n" "${INDENT}"
    echo ""
fi

  # Display cursor again
#  tput cnorm

# Showing the cursor.
printf '\e[?25h'

# Enabling line wrapping.
printf '\e[?7h'

}

exit_locate_digibyte_reminder() {

if [ "$DGB_STATUS" = "not_detected" ]; then # Only display if digibyted is NOT running
    printf "  %b %bNote: A DigiByte Node could not be detected. %b\\n"  "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
    printf "\\n"
    printf "%b If your system is already running a DigiByte Node, use the --locatedgb flag\\n" "${INDENT}"
    printf "%b to manually set the location of the DigiByte Core install folder.\\n" "${INDENT}"
    printf "\\n"
    printf "%b i.e. Enter: ${txtbld}diginode --locatedgb${txtrst}\\n" "${INDENT}"
    printf "\\n"          
fi


}

startup_waitpause() {

# Optionally require a key press to continue, or a long 5 second pause. Otherwise wait 3 seconds before starting monitoring. 

if [ "$STARTPAUSE" = "yes" ]; then
  echo ""
  read -n 1 -s -r -p "      < Press any key to continue >"
fi

}

get_country_name() {
    local code="$1"
    case "$code" in
        "ae") echo "United Arab Emirates" ;;
        "af") echo "Afghanistan" ;;
        "am") echo "Armenia" ;;
        "ao") echo "Angola" ;;
        "ar") echo "Argentina" ;;
        "at") echo "Austria" ;;
        "au") echo "Australia" ;;
        "az") echo "Azerbaijan" ;;
        "bd") echo "Bangladesh" ;;
        "be") echo "Belgium" ;;
        "bf") echo "Burkina Faso" ;;
        "bg") echo "Bulgaria" ;;
        "bh") echo "Bahrain" ;;
        "bi") echo "Burundi" ;;
        "br") echo "Brazil" ;;
        "bt") echo "Bhutan" ;;
        "bw") echo "Botswana" ;;
        "by") echo "Belarus" ;;
        "ca") echo "Canada" ;;
        "cd") echo "Democratic Republic of the Congo" ;;
        "cf") echo "Central African Republic" ;;
        "cg") echo "Congo" ;;
        "ch") echo "Switzerland" ;;
        "ci") echo "Côte d'Ivoire" ;;
        "cm") echo "Cameroon" ;;
        "cn") echo "China" ;;
        "cz") echo "Czech Republic" ;;
        "de") echo "Germany" ;;
        "dj") echo "Djibouti" ;;
        "dk") echo "Denmark" ;;
        "dz") echo "Algeria" ;;
        "eg") echo "Egypt" ;;
        "eh") echo "Western Sahara" ;;
        "er") echo "Eritrea" ;;
        "es") echo "Spain" ;;
        "et") echo "Ethiopia" ;;
        "fi") echo "Finland" ;;
        "fj") echo "Fiji" ;;
        "fm") echo "Micronesia" ;;
        "fr") echo "France" ;;
        "ga") echo "Gabon" ;;
        "gb") echo "Great Britain" ;;
        "ge") echo "Georgia" ;;
        "gh") echo "Ghana" ;;
        "gm") echo "Gambia" ;;
        "gn") echo "Guinea" ;;
        "gq") echo "Equatorial Guinea" ;;
        "gr") echo "Greece" ;;
        "gw") echo "Guinea-Bissau" ;;
        "hu") echo "Hungary" ;;
        "id") echo "Indonesia" ;;
        "ie") echo "Ireland" ;;
        "il") echo "Israel" ;;
        "in") echo "India" ;;
        "iq") echo "Iraq" ;;
        "ir") echo "Iran" ;;
        "it") echo "Italy" ;;
        "jo") echo "Jordan" ;;
        "jp") echo "Japan" ;;
        "ke") echo "Kenya" ;;
        "kg") echo "Kyrgyzstan" ;;
        "kh") echo "Cambodia" ;;
        "ki") echo "Kiribati" ;;
        "km") echo "Comoros" ;;
        "kp") echo "North Korea" ;;
        "kr") echo "South Korea" ;;
        "kw") echo "Kuwait" ;;
        "kz") echo "Kazakhstan" ;;
        "la") echo "Laos" ;;
        "lb") echo "Lebanon" ;;
        "lk") echo "Sri Lanka" ;;
        "lr") echo "Liberia" ;;
        "ls") echo "Lesotho" ;;
        "ly") echo "Libya" ;;
        "ma") echo "Morocco" ;;
        "mg") echo "Madagascar" ;;
        "mh") echo "Marshall Islands" ;;
        "mm") echo "Myanmar" ;;
        "mn") echo "Mongolia" ;;
        "mr") echo "Mauritania" ;;
        "mu") echo "Mauritius" ;;
        "mv") echo "Maldives" ;;
        "mw") echo "Malawi" ;;
        "mx") echo "Mexico" ;;
        "my") echo "Malaysia" ;;
        "mz") echo "Mozambique" ;;
        "na") echo "Namibia" ;;
        "ne") echo "Niger" ;;
        "ng") echo "Nigeria" ;;
        "nl") echo "Netherlands" ;;
        "no") echo "Norway" ;;
        "np") echo "Nepal" ;;
        "nr") echo "Nauru" ;;
        "nz") echo "New Zealand" ;;
        "om") echo "Oman" ;;
        "pg") echo "Papua New Guinea" ;;
        "ph") echo "Philippines" ;;
        "pk") echo "Pakistan" ;;
        "pl") echo "Poland" ;;
        "ps") echo "Palestine" ;;
        "pt") echo "Portugal" ;;
        "pw") echo "Palau" ;;
        "qa") echo "Qatar" ;;
        "ro") echo "Romania" ;;
        "ru") echo "Russia" ;;
        "rw") echo "Rwanda" ;;
        "sa") echo "Saudi Arabia" ;;
        "sb") echo "Solomon Islands" ;;
        "sc") echo "Seychelles" ;;
        "sd") echo "Sudan" ;;
        "se") echo "Sweden" ;;
        "sg") echo "Singapore" ;;
        "sl") echo "Sierra Leone" ;;
        "sn") echo "Senegal" ;;
        "so") echo "Somalia" ;;
        "ss") echo "South Sudan" ;;
        "sy") echo "Syria" ;;
        "sz") echo "Eswatini" ;;
        "td") echo "Chad" ;;
        "th") echo "Thailand" ;;
        "tj") echo "Tajikistan" ;;
        "tl") echo "Timor-Leste" ;;
        "tm") echo "Turkmenistan" ;;
        "tn") echo "Tunisia" ;;
        "to") echo "Tonga" ;;
        "tr") echo "Turkey" ;;
        "tv") echo "Tuvalu" ;;
        "tz") echo "Tanzania" ;;
        "ua") echo "Ukraine" ;;
        "ug") echo "Uganda" ;;
        "uk") echo "United Kingdom" ;;
        "us") echo "United States" ;;
        "uz") echo "Uzbekistan" ;;
        "vn") echo "Vietnam" ;;
        "vu") echo "Vanuatu" ;;
        "ws") echo "Samoa" ;;
        "ye") echo "Yemen" ;;
        "za") echo "South Africa" ;;
        "zm") echo "Zambia" ;;
        "zw") echo "Zimbabwe" ;;
        # Add more cases for other country codes and names here
        *) echo "$code" | tr '[:lower:]' '[:upper:]' ;;
    esac
}

firstrun_monitor_configs() {

# If this is the first time running the Dashboard, set the variables that update periodically
if [ "$DGNT_MONITOR_FIRST_RUN" = "" ]; then

    printf "%b First time running DigiNode Dashboard. Performing initial setup...\\n" "${INFO}"

    # Log date of Dashboard first run to diginode.settings
    str="Logging date of first run to diginode.settings file..."
    printf "  %b %s" "${INFO}" "${str}"
    DGNT_MONITOR_FIRST_RUN=$(date)
    sed -i -e "/^DGNT_MONITOR_FIRST_RUN=/s|.*|DGNT_MONITOR_FIRST_RUN=\"$DGNT_MONITOR_FIRST_RUN\"|" $DGNT_SETTINGS_FILE
    printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

    # When the user quits, enable showing a donation plea
    DONATION_PLEA="YES"
    sed -i -e "/^DONATION_PLEA=/s|.*|DONATION_PLEA=$DONATION_PLEA|" $DGNT_SETTINGS_FILE

    printf "\\n"

fi

}

firstrun_dganode_configs() {

  # Set DigiAssets Node version veriables (if it is has just been installed)
  if [ "$DGA_STATUS" = "running" ] && [ "$DGA_FIRST_RUN" = ""  ]; then
      printf "%b First time running DigiAssets Node. Performing initial setup...\\n" "${INFO}"

    # Next let's try and get the minor version, which may or may not be available yet
    # If DigiAsset Node is running we can get it directly from the web server

      DGA_VER_MNR_LOCAL_QUERY=$(curl --max-time 4 localhost:8090/api/version/list.json 2>/dev/null | jq .current | sed 's/"//g')
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

      printf "\\n"

  fi

}

# Cleans the DigiByte Core startup messages of strange characters (e.g. ellipsis) that mess up the position of the right side border
clean_dgb_error_msg() {

    # Replace single elipsis charcter with three dots
    DGB_ERROR_MSG="${DGB_ERROR_MSG/…/...}"

    # Replace single elipsis charcter with three dots
    DGB2_ERROR_MSG="${DGB2_ERROR_MSG/…/...}"
}


# displays the current DigiByte Core listening port
display_listening_port() {
if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ]; then # Only show listening port if DigiByte Node is running or starting up
    if [ "$DGB_CONNECTIONS" = "" ]; then
        DGB_CONNECTIONS=0
    fi
    if [ $DGB_CONNECTIONS -le 8 ] && [ "$DGB_NETWORK_CURRENT" != "REGTEST" ]; then # Only show if connection count is less or equal to 8 since it is clearly working with a higher count
        printf "  ╠════════════════╬════════════════════════════════════════════════════╣\\n"
        if grep -q ^"upnp=1" $DGB_CONF_FILE; then
            printf "  ║ DGB PORT       ║  " && printf "%-26s %24s %-4s\n" "Listening Port: ${txtbylw}${DGB_LISTEN_PORT}${txtrst}" "[ UPnP: Enabled" "]  ║"
        else
            printf "  ║ DGB PORT       ║  " && printf "%-26s %24s %-4s\n" "Listening Port: ${txtbylw}${DGB_LISTEN_PORT}${txtrst}" "[ UPnP: Disabled" "]  ║"
        fi
    fi
fi

}


# check for a digibyte update
check_digibyte_update() {

    # Check for latest pre-release version of DigiByte Core if it is currently being used
    if [ "$DGB_PRERELEASE" = "YES" ]; then

        DGB_VER_PRERELEASE=$(jq -r 'map(select(.prerelease)) | first | .tag_name' <<< $(curl --max-time 4 https://api.github.com/repos/digibyte-core/digibyte/releases) | sed 's/v//g')

        # If there is no pre-release version, then we will lookup the release version
        if [ "$DGB_VER_PRERELEASE" = "null" ]; then
            sed -i -e "/^DGB_VER_PRERELEASE=/s|.*|DGB_VER_PRERELEASE=|" $DGNT_SETTINGS_FILE
            INSTALL_DGB_RELEASE_TYPE="release"
        else
            sed -i -e "/^DGB_VER_PRERELEASE=/s|.*|DGB_VER_PRERELEASE=\"$DGB_VER_PRERELEASE\"|" $DGNT_SETTINGS_FILE
            INSTALL_DGB_RELEASE_TYPE="prerelease"
        fi
    fi


    # Check for latest release version of DigiByte Core on Github
    if [ "$INSTALL_DGB_RELEASE_TYPE" = "release" ] || [ "$DGB_PRERELEASE" = "NO" ]; then
        DGB_VER_RELEASE_QUERY=$(curl --max-time 4 -sfL https://api.github.com/repos/digibyte-core/digibyte/releases/latest | jq -r ".tag_name" | sed 's/v//g')
        if [ "$DGB_VER_RELEASE_QUERY" != "" ]; then
          DGB_VER_RELEASE=$DGB_VER_RELEASE_QUERY
          sed -i -e "/^DGB_VER_RELEASE=/s|.*|DGB_VER_RELEASE=\"$DGB_VER_RELEASE\"|" $DGNT_SETTINGS_FILE
        fi
    fi


    # Set DGB_VER_GITHUB to the version we are comparing against
    if [ "$INSTALL_DGB_RELEASE_TYPE" = "release" ]; then
        DGB_VER_GITHUB=$DGB_VER_RELEASE
    elif [ "$INSTALL_DGB_RELEASE_TYPE" = "prerelease" ]; then
        DGB_VER_GITHUB=$DGB_VER_PRERELEASE
    fi

    # Compare current DigiByte Core version with Github version to know if there is a new version available
    dgb_update_status=$(is_dgb_newer_version "$DGB_VER_LOCAL" "$DGB_VER_GITHUB")
    if [ "$dgb_update_status" = "update_available" ]; then
        DGB_VER_LOCAL_CHECK_FREQ="10secs"
        sed -i -e "/^DGB_VER_LOCAL_CHECK_FREQ=/s|.*|DGB_VER_LOCAL_CHECK_FREQ=\"$DGB_VER_LOCAL_CHECK_FREQ\"|" $DGNT_SETTINGS_FILE
        DGB_UPDATE_AVAILABLE="yes"
    else
        DGB_UPDATE_AVAILABLE="no"
    fi


    
#    if [ "$DGB_VER_LOCAL" = "$DGB_VER_GITHUB" ]; then
#      DGB_UPDATE_AVAILABLE="no"
#    else
#      DGB_VER_LOCAL_CHECK_FREQ="10secs"
#      sed -i -e "/^DGB_VER_LOCAL_CHECK_FREQ=/s|.*|DGB_VER_LOCAL_CHECK_FREQ=\"$DGB_VER_LOCAL_CHECK_FREQ\"|" $DGNT_SETTINGS_FILE
#      DGB_UPDATE_AVAILABLE="yes"
#    fi


}

# Function to gather CPU stats in the background
get_cpu_stats() {
    while true; do
        stats=$(mpstat -P ALL 1 1 | awk '/Average:/ && $2 ~ /[0-9]/ {print $2, 100-$NF}')

        num_cores=$(echo "$stats" | wc -l)
        split_point=$(( (num_cores + 1) / 2 ))

        cpu_usage_1=""
        cpu_usage_2=""
        total_usage=0
        counter=1

        while IFS= read -r line; do
            core=$(echo "$line" | awk '{print $1}')
            usage=$(echo "$line" | awk '{printf "%.0f", $2}')
            
            total_usage=$(echo "$total_usage + $usage" | bc)

            if [ "$counter" -le "$split_point" ]; then
                cpu_usage_1+="#${core}: ${usage}%    "
            else
                cpu_usage_2+="#${core}: ${usage}%    "
            fi

            counter=$((counter + 1))
        done <<< "$stats"

        average_usage=$(echo "scale=0; $total_usage / $num_cores" | bc)

        echo "$cpu_usage_1" > "$cpu1_file"
        echo "$cpu_usage_2" > "$cpu2_file"
        echo "$average_usage" > "$avg_file"
        sleep 0.95
    done
}

pre_loop() {

    printf " =============== Performing Startup Checks ==============================\\n\\n"
    # ===============================================================================

    # Setup loopcounter - used for debugging
    loopcounter=0

    # Set timenow variable with the current time
    TIME_NOW=$(date)
    TIME_NOW_UNIX=$(date +%s)

    # Check timers in case they have been tampered with, and repair if necessary

    if [ "$SAVED_TIME_10SEC" = "" ]; then
        str="Repairing 10 Second timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 10 sec timer and save to settings file
        SAVED_TIME_10SEC="$(date +%s)"
        sed -i -e "/^SAVED_TIME_10SEC=/s|.*|SAVED_TIME_10SEC=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_1MIN" = "" ]; then
        str="Repairing 1 Minute timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 1 min timer and save to settings file
        SAVED_TIME_1MIN="$(date +%s)"
        sed -i -e "/^SAVED_TIME_1MIN=/s|.*|SAVED_TIME_1MIN=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_15MIN" = "" ]; then
        str="Repairing 15 Minute timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 15 min timer and save to settings file
        SAVED_TIME_15MIN="$(date +%s)"
        sed -i -e "/^SAVED_TIME_15MIN=/s|.*|SAVED_TIME_15MIN=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_1DAY" = "" ]; then
        str="Repairing 1 Day timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 15 min timer and save to settings file
        SAVED_TIME_1DAY="$(date +%s)"
        sed -i -e "/^SAVED_TIME_1DAY=/s|.*|SAVED_TIME_1DAY=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi
    if [ "$SAVED_TIME_1WEEK" = "" ]; then
        str="Repairing 1 Week timer..."
        printf "%b %s" "${INFO}" "${str}"
        # set 1 week timer and save to settings file
        SAVED_TIME_1WEEK="$(date +%s)"
        sed -i -e "/^SAVED_TIME_1WEEK=/s|.*|SAVED_TIME_1WEEK=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi


    # update external IP address and save to settings file
    if [ "$IP4_EXTERNAL" = "" ]; then
        str="Looking up IP4 external address..."
        printf "%b %s" "${INFO}" "${str}"
        IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short 2>/dev/null)
        if [ $IP4_EXTERNAL_QUERY != "" ]; then
            IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
            sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            IP4_EXTERNAL="OFFLINE"
            sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"OFFLINE\"|" $DGNT_SETTINGS_FILE
            printf "%b%b %s Offline!\\n" "${OVER}" "${CROSS}" "${str}"
        fi
    fi

    # update internal IP address and save to settings file
    str="Looking up IP4 internal address..."
    printf "%b %s" "${INFO}" "${str}"
    IP4_INTERNAL_QUERY=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
    if [ "$IP4_INTERNAL_QUERY" != "" ]; then
        IP4_INTERNAL=$IP4_INTERNAL_QUERY
        sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"$IP4_INTERNAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        IP4_INTERNAL="OFFLINE"
        sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"OFFLINE\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Offline!\\n" "${OVER}" "${CROSS}" "${str}"
    fi


    # update IP6 link-local address and save to settings file
    str="Looking up IP6 link-local address..."
    printf "%b %s" "${INFO}" "${str}"
    IP6_LINKLOCAL_QUERY=$(ip -6 addr show | grep 'inet6 fe80:' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    if [ $IP6_LINKLOCAL_QUERY != "" ]; then
        IP6_LINKLOCAL=$IP6_LINKLOCAL_QUERY
        sed -i -e "/^IP6_LINKLOCAL=/s|.*|IP6_LINKLOCAL=\"$IP6_LINKLOCAL\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        IP6_LINKLOCAL=""
        sed -i -e "/^IP6_LINKLOCAL=/s|.*|IP6_LINKLOCAL=\"\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Not Available!\\n" "${OVER}" "${CROSS}" "${str}"
    fi

    # update IP6 ULA address and save to settings file
    str="Looking up IP6 unique local address (ULA) address..."
    printf "%b %s" "${INFO}" "${str}"
    IP6_ULA_QUERY=$(ip -6 addr show | grep -E 'inet6 fd[0-9a-f]{2}:' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    if [ "$IP6_ULA_QUERY" != "" ]; then
        IP6_ULA=$IP6_ULA_QUERY
        sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"$IP6_ULA\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        IP6_ULA=""
        sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Not Available!\\n" "${OVER}" "${CROSS}" "${str}"
    fi

    # update IP6 GUA address and save to settings file
    str="Looking up IP6 global unicast address (GUA) address..."
    printf "%b %s" "${INFO}" "${str}"
    IP6_GUA_QUERY=$(ip -6 addr show scope global | grep -Eo 'inet6 ([a-f0-9:]+)' | awk '{print $2}' | head -n 1)
    if [ $IP6_GUA_QUERY != "" ]; then
        IP6_GUA=$IP6_GUA_QUERY
        sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"$IP6_GUA\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    else
        IP6_GUA=""
        sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"\"|" $DGNT_SETTINGS_FILE
        printf "%b%b %s Not Available!\\n" "${OVER}" "${CROSS}" "${str}"
    fi

    # update IP6 public address and save to settings file (sometimes this is different from GUA)
    if [ "$IP6_EXTERNAL" = "" ]; then
        str="Looking up IP6 public address..."
        printf "  %b %s" "${INFO}" "${str}"
        IP6_EXTERNAL_QUERY=$(curl -6 --max-time 4 -sfL icanhazip.com)
        if [ "$IP6_EXTERNAL_QUERY" != "" ]; then
            IP6_EXTERNAL=$IP6_EXTERNAL_QUERY
            sed -i -e "/^IP6_EXTERNAL=/s|.*|IP6_EXTERNAL=\"$IP6_EXTERNAL\"|" $DGNT_SETTINGS_FILE
            printf "  %b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
        else
            IP6_EXTERNAL=""
            sed -i -e "/^IP6_EXTERNAL=/s|.*|IP6_EXTERNAL=\"\"|" $DGNT_SETTINGS_FILE
            printf "  %b%b %s Not Available!\\n" "${OVER}" "${CROSS}" "${str}"
        fi  
    fi  

    printf "\\n"


    # Check the current version of DigiByte Core, as well as the release type, if we don't already know them

      if [ "$DGB_STATUS" = "running" ] || [ "$DGB2_STATUS" = "running" ]; then
        printf "%b Checking DigiByte Core...\\n" "${INFO}"
      fi

    # If we don't already know, let's check if this is a pre-release version?
    if [ "$DGB_PRERELEASE" = "" ] && [ "$DGB_STATUS" != "not_detected" ]; then
        str="Is DigiByte Core the pre-release version?..."
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


    # If this is a pre-release version, get the current version from inside the .prerelease file 
    if [ "$DGB_PRERELEASE" = "YES" ] && [ "$DGB_STATUS" != "not_detected" ]; then
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


      # Is primary DigiByte Node starting up?
      if [ "$DGB_STATUS" = "running" ]; then
        DGB_BLOCKCOUNT_LOCAL_QUERY=$($DGB_CLI getblockcount 2>/dev/null)
        if [ "$DGB_BLOCKCOUNT_LOCAL_QUERY" = "" ]; then
          DGB_STATUS="startingup"
        else
          DGB_BLOCKCOUNT_LOCAL=$DGB_BLOCKCOUNT_LOCAL_QUERY
          DGB_BLOCKCOUNT_FORMATTED=$(printf "%'d" $DGB_BLOCKCOUNT_LOCAL)

          # Query current version number of DigiByte Core
          DGB_VER_LOCAL_QUERY=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
          if [ "$DGB_VER_LOCAL_QUERY" != "" ] && [ "$DGB_PRERELEASE" = "NO" ]; then
            DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
            sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
          fi

        fi
      fi

      # Check if primary DigiByte Node is successfully responding to requests yet while starting up. If not, get the current error.
      if [ "$DGB_STATUS" = "startingup" ]; then
          
          # Query if digibyte has finished starting up. Display error. Send success to null.
          is_dgb_live_query=$($DGB_CLI uptime 2>&1 1>/dev/null)
          if [ "$is_dgb_live_query" != "" ]; then
              DGB_ERROR_MSG=$(echo $is_dgb_live_query | cut -d ':' -f3)
              clean_dgb_error_msg
          else
              DGB_STATUS="running"
          fi

      fi

      # Is secondary DigiByte Node starting up?
      if [ "$DGB2_STATUS" = "running" ]; then
        DGB2_BLOCKCOUNT_LOCAL_QUERY=$($DGB_CLI -testnet getblockcount 2>/dev/null)
        if [ "$DGB2_BLOCKCOUNT_LOCAL_QUERY" = "" ]; then
          DGB2_STATUS="startingup"
        else
          DGB2_BLOCKCOUNT_LOCAL=$DGB2_BLOCKCOUNT_LOCAL_QUERY
          DGB2_BLOCKCOUNT_FORMATTED=$(printf "%'d" $DGB2_BLOCKCOUNT_LOCAL)

            # Query current version number of DigiByte Core, if the primary Node is not running
            if [ "$DGB_STATUS" != "running" ]; then
              DGB_VER_LOCAL_QUERY=$($DGB_CLI -testnet getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
              if [ "$DGB_VER_LOCAL_QUERY" != "" ] && [ "$DGB_PRERELEASE" = "NO" ]; then
                DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
                sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
              fi
            fi

        fi
      fi

      # Check if secondary DigiByte Node is successfully responding to requests yet while starting up. If not, get the current error.
      if [ "$DGB2_STATUS" = "startingup" ]; then
          
          # Query if digibyte has finished starting up. Display error. Send success to null.
          is_dgb2_live_query=$($DGB_CLI -testnet uptime 2>&1 1>/dev/null)
          if [ "$is_dgb2_live_query" != "" ]; then
              DGB2_ERROR_MSG=$(echo $is_dgb2_live_query | cut -d ':' -f3)
              clean_dgb_error_msg
          else
              DGB2_STATUS="running"
          fi

      fi


      # Compare sored software versions to check if there are any updates

      printf "%b Checking Software Versions...\\n" "${INFO}"

      # Are we running a pre-release or a release version of DigiByte Core?
      # Refer to the stored variables in diginode.settings
        if [ "$DGB_PRERELEASE" = "NO" ]; then
            DGB_VER_GITHUB=$DGB_VER_RELEASE
        elif [ "$DGB_PRERELEASE" = "YES" ] && [ "$DGB_VER_PRERELEASE" = "" ]; then
            DGB_VER_GITHUB=$DGB_VER_RELEASE
        elif [ "$DGB_PRERELEASE" = "YES" ]; then
            DGB_VER_GITHUB=$DGB_VER_PRERELEASE
        fi

      # If there is actually a local version of DigiByte Core, and a stored remote version, check for an update
      if [ "$DGB_VER_LOCAL" != "" ] && [ "$DGB_VER_GITHUB" != "" ]; then

           dgb_update_status=$(is_dgb_newer_version "$DGB_VER_LOCAL" "$DGB_VER_GITHUB")

          if [ "$dgb_update_status" = "update_available" ]; then
            DGB_UPDATE_AVAILABLE="yes"
          else
            DGB_UPDATE_AVAILABLE="no"
          fi
      fi

      # Check remotely for release versions if there is not already one stored
      # This can happen when the script if running for the first time, or the diginode.settings file has been deleted

      if [ "$DGB_VER_GITHUB" = "" ]; then

            check_digibyte_update

    fi

    # Get the current network chain
    if [ "$DGB_STATUS" = "startingup" ] && [ "$DGB_STATUS" = "running" ]; then
        # scrape digibyte.conf
        scrape_digibyte_conf

        # query for digibyte network
        query_digibyte_chain
    fi


      ##### CHECK FOR UPDATES BY COMPARING VERSION NUMBERS #######

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
          # Log date of this Dashboard run to diginode.settings
          str="No value detected for displaying DigiByte wallet balance. Setting to YES..."
          printf "%b %s" "${INFO}" "${str}"
          SM_DISPLAY_BALANCE=YES
          sed -i -e "/^SM_DISPLAY_BALANCE=/s|.*|SM_DISPLAY_BALANCE=YES|" $DGNT_SETTINGS_FILE
          printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    fi

    if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$DGB_WALLET_STATUS" = "enabled" ]; then
        # Lookup current wallet balance
        get_dgb_wallet_balance
    fi

    if [ "$DGA_STATUS" = "running" ]; then
        printf "%b Checking DigiAsset Node...\\n" "${INFO}"
    fi

    # Query the DigiAsset Node console
    update_dga_console

    # Choose a random DigiFact
    digifact_randomize

    printf "\\n"

    # Enable the DigiByte Core mainnet port test (primary node) if it seems it has never run before
    if [ "$DGB_MAINNET_PORT_TEST_ENABLED" != "YES" ] && [ "$DGB_MAINNET_PORT_TEST_ENABLED" != "NO" ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then

        
        printf "%b Enabling DigiByte Core MAINNET Port Test...\n" "${INFO}"

        DGB_MAINNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
    fi

    # Enable the DigiByte Core testnet port test (primary node) if it seems it has never run before
    if [ "$DGB_TESTNET_PORT_TEST_ENABLED" != "YES" ] && [ "$DGB_TESTNET_PORT_TEST_ENABLED" != "NO" ] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then

        
        printf "%b Enabling DigiByte Core TESTNET Port Test...\n" "${INFO}"

        DGB_TESTNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
    fi

    # Enable the DigiByte Core testnet port test (secondary node) if it seems it has never run before
    if [ "$DGB_TESTNET_PORT_TEST_ENABLED" != "YES" ] && [ "$DGB_TESTNET_PORT_TEST_ENABLED" != "NO" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then

        
        printf "%b Enabling DigiByte Core TESTNET Port Test...\n" "${INFO}"

        DGB_TESTNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
    fi

    # Enable the IPFS port test if it seems it has never run before
    if [ "$IPFS_PORT_TEST_ENABLED" != "YES" ] && [ "$IPFS_PORT_TEST_ENABLED" != "NO" ]; then

        printf "%b Enabling IPFS Port Test...\n" "${INFO}"

        IPFS_PORT_TEST_ENABLED="YES"
        sed -i -e "/^IPFS_PORT_TEST_ENABLED=/s|.*|IPFS_PORT_TEST_ENABLED=\"$IPFS_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
    fi

    # If the DigiByte Core MAINNET port test (primary node) is disabled, check if the external IP address has changed
    if [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "NO" ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then

        # If the External IP address has changed since the last port test was run, reset and re-enable the port test
        if [ "$DGB_MAINNET_PORT_TEST_EXTERNAL_IP" != "$IP4_EXTERNAL" ]; then

            printf "%b External IP address has changed. Re-enabling DigiByte Core MAINNET Port Test...\n" "${INFO}"

            DGB_MAINNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_FWD_STATUS=""
            sed -i -e "/^DGB_MAINNET_PORT_FWD_STATUS=/s|.*|DGB_MAINNET_PORT_FWD_STATUS=\"$DGB_MAINNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_TEST_PASS_DATE=""
            sed -i -e "/^DGB_MAINNET_PORT_TEST_PASS_DATE=/s|.*|DGB_MAINNET_PORT_TEST_PASS_DATE=\"$DGB_MAINNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_MAINNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_MAINNET_PORT_TEST_EXTERNAL_IP=\"$DGB_MAINNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_NUMBER_SAVED=""
            sed -i -e "/^DGB_MAINNET_PORT_NUMBER_SAVED=/s|.*|DGB_MAINNET_PORT_NUMBER_SAVED=\"$DGB_MAINNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        # If the current DigiByte port has changed since the last port test was run, reset and re-enable the port test
        elif [ "$DGB_LISTEN_PORT" != "$DGB_MAINNET_PORT_NUMBER_SAVED" ]; then

            printf "%b DigiByte Core MAINNET listening port number has changed. Enabling Port Test...\n" "${INFO}"

            DGB_MAINNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_FWD_STATUS=""
            sed -i -e "/^DGB_MAINNET_PORT_FWD_STATUS=/s|.*|DGB_MAINNET_PORT_FWD_STATUS=\"$DGB_MAINNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_TEST_PASS_DATE=""
            sed -i -e "/^DGB_MAINNET_PORT_TEST_PASS_DATE=/s|.*|DGB_MAINNET_PORT_TEST_PASS_DATE=\"$DGB_MAINNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_MAINNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_MAINNET_PORT_TEST_EXTERNAL_IP=\"$DGB_MAINNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_NUMBER_SAVED=""
            sed -i -e "/^DGB_MAINNET_PORT_NUMBER_SAVED=/s|.*|DGB_MAINNET_PORT_NUMBER_SAVED=\"$DGB_MAINNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        fi

    fi

    # If the DigiByte Core TESTNET port test (primary node) is disabled, check if the external IP address has changed
    if [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "NO" ] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then

        # If the External IP address has changed since the last port test was run, reset and re-enable the port test
        if [ "$DGB_TESTNET_PORT_TEST_EXTERNAL_IP" != "$IP4_EXTERNAL" ]; then

            printf "%b External IP address has changed. Re-enabling DigiByte Core TESTNET Port Test...\n" "${INFO}"

            DGB_TESTNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_FWD_STATUS=""
            sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_PASS_DATE=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=\"$DGB_TESTNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_NUMBER_SAVED=""
            sed -i -e "/^DGB_TESTNET_PORT_NUMBER_SAVED=/s|.*|DGB_TESTNET_PORT_NUMBER_SAVED=\"$DGB_TESTNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        # If the current DigiByte port has changed since the last port test was run, reset and re-enable the port test
        elif [ "$DGB_LISTEN_PORT" != "$DGB_TESTNET_PORT_NUMBER_SAVED" ]; then

            printf "%b DigiByte Core TESTNET listening port number has changed. Enabling Port Test...\n" "${INFO}"

            DGB_TESTNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_FWD_STATUS=""
            sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_PASS_DATE=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=\"$DGB_TESTNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_NUMBER_SAVED=""
            sed -i -e "/^DGB_TESTNET_PORT_NUMBER_SAVED=/s|.*|DGB_TESTNET_PORT_NUMBER_SAVED=\"$DGB_TESTNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        fi

    fi

    # If the DigiByte Core TESTNET port test (secondary node) is disabled, check if the external IP address has changed
    if [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "NO" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then

        # If the External IP address has changed since the last port test was run, reset and re-enable the port test
        if [ "$DGB_TESTNET_PORT_TEST_EXTERNAL_IP" != "$IP4_EXTERNAL" ]; then

            printf "%b External IP address has changed. Re-enabling DigiByte Core TESTNET Port Test...\n" "${INFO}"

            DGB_TESTNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_FWD_STATUS=""
            sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_PASS_DATE=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=\"$DGB_TESTNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_NUMBER_SAVED=""
            sed -i -e "/^DGB_TESTNET_PORT_NUMBER_SAVED=/s|.*|DGB_TESTNET_PORT_NUMBER_SAVED=\"$DGB_TESTNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        # If the current DigiByte port has changed since the last port test was run, reset and re-enable the port test
        elif [ "$DGB_LISTEN_PORT" != "$DGB_TESTNET_PORT_NUMBER_SAVED" ]; then

            printf "%b DigiByte Core TESTNET listening port number has changed. Enabling Port Test...\n" "${INFO}"

            DGB_TESTNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_FWD_STATUS=""
            sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_PASS_DATE=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=\"$DGB_TESTNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_NUMBER_SAVED=""
            sed -i -e "/^DGB_TESTNET_PORT_NUMBER_SAVED=/s|.*|DGB_TESTNET_PORT_NUMBER_SAVED=\"$DGB_TESTNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE

        fi

    fi

    # If the IPFS port test is disabled, check if the external IP address has changed
    if [ "$IPFS_PORT_TEST_ENABLED" = "NO" ]; then

        # If the External IP address has changed since the last port test was run, reset and re-enable the port test
        if [ "$IPFS_PORT_TEST_EXTERNAL_IP" != "$IP4_EXTERNAL" ]; then

            printf "%b External IP address has changed. Enabling IPFS Port Test...\n" "${INFO}"

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

            printf "%b IPFS port number has changed. Enabling IPFS Port Test...\n" "${INFO}"

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

    str="Is Argon One Fan software installed?..."
    printf "%b %s" "${INFO}" "${str}"

    which argonone-cli 2>/dev/null
    if [ $? -eq 0 ]; then
        printf "%b%b %s Yes!\\n" "${OVER}" "${TICK}" "${str}"
        ARGON_FAN="yes"
    else
        printf "%b%b %s No!\\n" "${OVER}" "${INFO}" "${str}"
        ARGON_FAN="no"
    fi

#    if [ "$ARGON_FAN" = "yes" ]; then
#        str="Getting Argon One fan setttings..."
#        printf "%b %s" "${INFO}" "${str}"
# 
         # Query fan speeds and temps from argonone-cli
 #       argon_fan_speeds=$(argonone-cli --decode | grep "Fan Speeds set to" | awk -F 'set to ' '{print $2}')
 #       argon_fan_temps=$(argonone-cli --decode | grep "Fan Temps set to" | awk -F 'set to ' '{print $2}')

        # Convert fan speeds and temps to arrays
 #       IFS=' ' read -ra argon_speeds <<< "$argon_fan_speeds"
 #       IFS=' ' read -ra argon_temps <<< "$argon_fan_speeds"

 #       printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"

 #   fi

    #banana

    str="Starting background process for CPU stats..."
    printf "%b %s" "${INFO}" "${str}"

    # Get number of CPU cores
    cpu_cores=$(nproc)

    # Paths for temporary files to store CPU usage values
    cpu1_file=$(mktemp)
    cpu2_file=$(mktemp)
    avg_file=$(mktemp)

    # Start the get_cpu_stats function in the background
    get_cpu_stats &

    bg_cpu_stats_pid=$!

    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"


    # Enable displaying startup messaging for first loop
    STARTUP_LOOP=true

    # Declare the associative array to store the table variables
    declare -A global_variables_table

    # Get the current terminal width
    term_width=$(tput cols)

}

TEST_CONDITION=0

######################################################################################
############## THE LOOP STARTS HERE - ENTIRE LOOP RUNS ONCE A SECOND #################
######################################################################################

status_loop() {

while :
do

# Optional loop counter - useful for debugging
# echo "Loop Count: $loopcounter"

# Quit Dashboard automatically based on the time set in diginode.settings
# Dashboard will run indefinitely if the value is set to 0

# First convert SM_AUTO_QUIT from minutes into seconds

if [ $SM_AUTO_QUIT -gt 0 ]; then
  auto_quit_seconds=$(( $SM_AUTO_QUIT*60 ))
  auto_quit_half_seconds=$(( $auto_quit_seconds*2 ))
  if [ $loopcounter -gt $auto_quit_half_seconds ]; then
      auto_quit=true
      exit
  fi
fi

if [ "$STARTUP_LOOP" = true ]; then
    printf "%b Updating Status: 1 Second Loop...\\n" "${INFO}"
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
SWAPAVAIL_HR=$(free --mega -h | tr -s ' ' | sed '/^Swap/!d' | cut -d" " -f4)

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
#    UPDATE EVERY 1 SECOND - CPU USAGE 
# ------------------------------------------------------------------------------


# This all runs as a background process now. See get_cpu_stats function



# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - PRIMARY DIGIBYTE NODE 
# ------------------------------------------------------------------------------

# Check if primary DigiByte Node is actually installed
if [ $DGB_STATUS != "not_detected" ]; then

    # Is digibyted running as a service?
    systemctl is-active --quiet digibyted && DGB_STATUS="running" || DGB_STATUS="checkagain"

    # If it is not running as a service, check if digibyted is running via the command line
    if [ "$DGB_STATUS" = "checkagain" ] && [ "$DGB_DUAL_NODE" = "NO" ]; then
      if [ "" != "$(pgrep digibyted)" ]; then
        DGB_STATUS="running"
      fi
    fi

    # If digibyted is not running via the command line, check if digibyte-qt is running
    if [ "$DGB_STATUS" = "checkagain" ] && [ "$DGB_DUAL_NODE" = "NO" ]; then
        if [ "" != "$(pgrep digibyte-qt)" ]; then
            DGB_STATUS="running"
        fi
    fi

    if [ "$DGB_STATUS" = "checkagain" ]; then
            DGB_STATUS="stopped"
            DGB_BLOCKSYNC_PROGRESS=""
            DGB_ERROR_MSG=""
            RPC_PORT=""
    fi

    # If we think the blockchain is running, check the blockcount
    if [ "$DGB_STATUS" = "running" ]; then

        # If the blockchain is not yet synced, get blockcount
        if [ "$DGB_BLOCKSYNC_PROGRESS" = "" ] || [ "$DGB_BLOCKSYNC_PROGRESS" = "notsynced" ]; then
          DGB_BLOCKCOUNT_LOCAL=$($DGB_CLI getblockcount 2>/dev/null)
          DGB_BLOCKCOUNT_FORMATTED=$(printf "%'d" $DGB_BLOCKCOUNT_LOCAL)

          # If we don't get a response, assume it is starting up
          if [ "$DGB_BLOCKCOUNT_LOCAL" = "" ]; then
            DGB_STATUS="startingup"
            # scrape digibyte.conf
            scrape_digibyte_conf
            # query for digibyte network
            query_digibyte_chain
            # query for digibyte listening port
            digibyte_port_query
            # update rpc credentials
            digibyte_rpc_query
            DGB_TROUBLESHOOTING_MSG="1sec: running>startingup"
          fi
        fi
    fi

fi

# THE REST OF THIS ONLY RUNS NOTE IF THE PRIMARY DIGIBYTE NODE IS RUNNING

if [ "$DGB_STATUS" = "running" ]; then

  # This will update the blockchain sync progress every second until it is fully synced
  if [ "$DGB_BLOCKSYNC_PROGRESS" = "notsynced" ] || [ "$DGB_BLOCKSYNC_PROGRESS" = "" ]; then

    # Lookup the sync progress value from debug.log. 
    if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
        DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/testnet4/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
    elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
        DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/regtest/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
    elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
        DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/signet/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
    elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
        DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
    fi
 
    # Is the returned value numerical?
    re='^[0-9]+([.][0-9]+)?$'
    if ! [[ $DGB_BLOCKSYNC_VALUE_QUERY =~ $re ]] ; then
       DGB_BLOCKSYNC_VALUE_QUERY=""
    fi

    # Only update the variable, if a new value is found
    if [ "$DGB_BLOCKSYNC_VALUE_QUERY" != "" ]; then
       DGB_BLOCKSYNC_VALUE=$DGB_BLOCKSYNC_VALUE_QUERY
       sed -i -e "/^DGB_BLOCKSYNC_VALUE=/s|.*|DGB_BLOCKSYNC_VALUE=\"$DGB_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
    fi

    # Calculate blockchain sync percentage
    if [ "$DGB_BLOCKSYNC_VALUE" = "" ] || [ "$DGB_BLOCKSYNC_VALUE" = "0" ]; then
        DGB_BLOCKSYNC_PERC="0.00"
    else
        DGB_BLOCKSYNC_PERC=$(echo "scale=2 ;$DGB_BLOCKSYNC_VALUE*100"|bc)
    fi

    # Round blockchain sync percentage to two decimal places
    DGB_BLOCKSYNC_PERC=$(printf "%.2f \n" $DGB_BLOCKSYNC_PERC)

    # Detect if the blockchain is fully synced
    if [ "$DGB_BLOCKSYNC_PERC" = "100.00 " ]; then
      DGB_BLOCKSYNC_PERC="100 "
      DGB_BLOCKSYNC_PROGRESS="synced"
    fi
    
  fi

  # Get primary DigiByted Node Uptime
  dgb_uptime_seconds=$($DGB_CLI uptime 2>/dev/null)
  dgb_uptime=$(eval "echo $(date -ud "@$dgb_uptime_seconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")

  # Calculate when it was first online
  current_time=$(date +"%s")
  dgb_start_time=$((current_time - dgb_uptime_seconds))
  dgb_online_since=$(date -d "@$dgb_start_time" +"%H:%M %d %b %Y %Z")

  # Show port warning if connections are less than or equal to 7
  DGB_CONNECTIONS=$($DGB_CLI getconnectioncount 2>/dev/null)
  if [ $DGB_CONNECTIONS -le 8 ]; then
    DGB_CONNECTIONS_MSG="Warning: Low Connections!"
  fi
  if [ $DGB_CONNECTIONS -ge 9 ]; then
    DGB_CONNECTIONS_MSG="Maximum: $DGB_MAXCONNECTIONS"
  fi

fi

# ------------------------------------------------------------------------------
#    UPDATE EVERY 1 SECOND - SECONDARY DIGIBYTE NODE 
# ------------------------------------------------------------------------------

# Check if secondary DigiByte Node is actually installed
if [ $DGB2_STATUS != "not_detected" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then

    # Is digibyted running as a service?
    systemctl is-active --quiet digibyted-testnet && DGB2_STATUS="running" || DGB2_STATUS="stopped"

    # If digibyted is not running via the command line, check if digibyte-qt is running
    if [ "$DGB2_STATUS" = "stopped" ]; then
        DGB2_STATUS="stopped"
        DGB2_BLOCKSYNC_PROGRESS=""
        DGB2_ERROR_MSG=""
        RPC2_PORT=""
    fi

    # If we think the secondary blockchain is running, check the blockcount
    if [ "$DGB2_STATUS" = "running" ]; then

        # If the blockchain is not yet synced, get blockcount
        if [ "$DGB2_BLOCKSYNC_PROGRESS" = "" ] || [ "$DGB2_BLOCKSYNC_PROGRESS" = "notsynced" ]; then
          DGB2_BLOCKCOUNT_LOCAL=$($DGB_CLI -testnet getblockcount 2>/dev/null)
          DGB2_BLOCKCOUNT_FORMATTED=$(printf "%'d" $DGB2_BLOCKCOUNT_LOCAL)

          # If we don't get a response, assume it is starting up
          if [ "$DGB2_BLOCKCOUNT_LOCAL" = "" ]; then
            DGB2_STATUS="startingup"
            # scrape digibyte.conf
            scrape_digibyte_conf
            # query for digibyte network
            query_digibyte_chain
            # query for digibyte listening port
            digibyte_port_query
            # update rpc credentials
            digibyte_rpc_query
            DGB2_TROUBLESHOOTING_MSG="1sec: running>startingup"
          fi
        fi
    fi

fi

# THE REST OF THIS ONLY RUNS NOTE IF THE SECONDARY DIGIBYTE NODE IS RUNNING

if [ "$DGB2_STATUS" = "running" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then

  # This will update the blockchain sync progress every second until it is fully synced
  if [ "$DGB2_BLOCKSYNC_PROGRESS" = "notsynced" ] || [ "$DGB2_BLOCKSYNC_PROGRESS" = "" ]; then

    # Lookup the testnet sync progress value from debug.log. 
    DGB2_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/testnet4/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
 
    # Is the returned value numerical?
    re='^[0-9]+([.][0-9]+)?$'
    if ! [[ $DGB2_BLOCKSYNC_VALUE_QUERY =~ $re ]] ; then
       DGB2_BLOCKSYNC_VALUE_QUERY=""
    fi

    # Only update the variable, if a new value is found
    if [ "$DGB2_BLOCKSYNC_VALUE_QUERY" != "" ]; then
       DGB2_BLOCKSYNC_VALUE=$DGB2_BLOCKSYNC_VALUE_QUERY
       sed -i -e "/^DGB2_BLOCKSYNC_VALUE=/s|.*|DGB2_BLOCKSYNC_VALUE=\"$DGB2_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
    fi

    # Calculate blockchain sync percentage
    if [ "$DGB2_BLOCKSYNC_VALUE" = "" ] || [ "$DGB2_BLOCKSYNC_VALUE" = "0" ]; then
        DGB2_BLOCKSYNC_PERC="0.00"
    else
        DGB2_BLOCKSYNC_PERC=$(echo "scale=2 ;$DGB2_BLOCKSYNC_VALUE*100"|bc)
    fi

    # Round blockchain sync percentage to two decimal places
    DGB2_BLOCKSYNC_PERC=$(printf "%.2f \n" $DGB2_BLOCKSYNC_PERC)

    # Detect if the blockchain is fully synced
    if [ "$DGB2_BLOCKSYNC_PERC" = "100.00 " ]; then
      DGB2_BLOCKSYNC_PERC="100 "
      DGB2_BLOCKSYNC_PROGRESS="synced"
    fi
    

  fi

  # Get secondary DigiByted Node Uptime
  dgb2_uptime_seconds=$($DGB_CLI -testnet uptime 2>/dev/null)
  dgb2_uptime=$(eval "echo $(date -ud "@$dgb2_uptime_seconds" +'$((%s/3600/24)) days %H hours %M minutes %S seconds')")

  # Calculate when it was first online
  current_time=$(date +"%s")
  dgb2_start_time=$((current_time - dgb2_uptime_seconds))
  dgb2_online_since=$(date -d "@$dgb2_start_time" +"%H:%M %d %b %Y %Z")

# Show port warning if connections are less than or equal to 7
  DGB2_CONNECTIONS=$($DGB_CLI -testnet getconnectioncount 2>/dev/null)
  if [ $DGB2_CONNECTIONS -le 8 ]; then
    DGB2_CONNECTIONS_MSG="Warning: Low Connections!"
  fi
  if [ $DGB2_CONNECTIONS -ge 9 ]; then
    DGB2_CONNECTIONS_MSG="Maximum: $DGB2_MAXCONNECTIONS"
  fi

fi

# ------------------------------------------------------------------------------
#    Run once every 10 seconds
#    Every 10 seconds lookup the latest block from the online block exlorer to calculate sync progress.
# ------------------------------------------------------------------------------

TIME_DIF_10SEC=$(($TIME_NOW_UNIX-$SAVED_TIME_10SEC))

if [ $TIME_DIF_10SEC -ge 10 ]; then 

    if [ "$STARTUP_LOOP" = true ]; then
        printf "%b Updating Status: 10 Second Loop...\\n" "${INFO}"
    fi


    # PRIMARY DIGIBYTE NODE ---->

    # Check if primary DigiByte Node is successfully responding to requests yet while starting up. If not, get the current error.
    if [ "$DGB_STATUS" = "startingup" ]; then

        # Refresh diginode.settings to get the latest value of DGB_VER_LOCAL
        source $DGNT_SETTINGS_FILE

        # Are we running a pre-release or a release version of DigiByte Core?
        if [ "$DGB_PRERELEASE" = "NO" ]; then
            DGB_VER_GITHUB=$DGB_VER_RELEASE
        elif [ "$DGB_PRERELEASE" = "YES" ] && [ "$DGB_VER_PRERELEASE" = "" ]; then
            DGB_VER_GITHUB=$DGB_VER_RELEASE
        elif [ "$DGB_PRERELEASE" = "YES" ]; then
            DGB_VER_GITHUB=$DGB_VER_PRERELEASE
        fi
      
        # Query if digibyte has finished starting up. Display error. Send success to null.
        is_dgb_live_query=$($DGB_CLI uptime 2>&1 1>/dev/null)
        if [ "$is_dgb_live_query" != "" ]; then
            DGB_ERROR_MSG=$(echo $is_dgb_live_query | cut -d ':' -f3)
            clean_dgb_error_msg
        else
            TROUBLESHOOTING_MSG="10sec: startingup > running"
            DGB_STATUS="running"

            # Get current listening port
            DGB_LISTEN_PORT=$($DGB_CLI getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)

            # scrape digibyte.conf
            scrape_digibyte_conf

            # query for digibyte network
            query_digibyte_chain

            # update max connections
            digibyte_maxconnections_query

            # update rpc credentials
            digibyte_rpc_query

        fi

    fi

    # Update local block count every 10 seconds (approx once per block)
    # Is digibyted in the process of starting up, and not ready to respond to requests?
    if [ "$DGB_STATUS" = "running" ] && [ "$DGB_BLOCKSYNC_PROGRESS" = "synced" ]; then
        DGB_BLOCKCOUNT_LOCAL=$($DGB_CLI getblockcount 2>/dev/null)
        DGB_BLOCKCOUNT_FORMATTED=$(printf "%'d" $DGB_BLOCKCOUNT_LOCAL)
        if [ "$DGB_BLOCKCOUNT_LOCAL" = "" ]; then
            DGB_STATUS="startingup"
            DGB_LISTEN_PORT=""
            # scrape digibyte.conf
            scrape_digibyte_conf
            # query for digibyte network
            query_digibyte_chain
            # query for digibyte listening port
            digibyte_port_query
            # update rpc credentials
            digibyte_rpc_query
            DGB_TROUBLESHOOTING_MSG="10sec: running > startingup"
        else
            # Get the algo used for the current block (mainnet or testnet)
            if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
                DGB_BLOCK_CURRENT_ALGO=$(tail $DGB_SETTINGS_LOCATION/testnet4/debug.log 2>/dev/null | grep $DGB_BLOCKCOUNT_LOCAL | cut -d'(' -f 2 | cut -d')' -f 1)
            else
                DGB_BLOCK_CURRENT_ALGO=$(tail $DGB_SETTINGS_LOCATION/debug.log 2>/dev/null | grep $DGB_BLOCKCOUNT_LOCAL | cut -d'(' -f 2 | cut -d')' -f 1)
            fi
        fi
    fi



    # If there is a new DigiByte Core release available, check every 10 seconds until it has been installed
    if [ $DGB_STATUS = "running" ]; then

      if [ "$DGB_VER_LOCAL_CHECK_FREQ" = "" ] || [ "$DGB_VER_LOCAL_CHECK_FREQ" = "10secs" ] || [ "$DGB_VER_LOCAL_CHECK_FREQ" = "15secs" ]; then

        # Refresh diginode.settings to get the latest value of DGB_VER_LOCAL
        source $DGNT_SETTINGS_FILE

        # Query current version number of DigiByte Core, and write to diginode.settings (unless running pre-release version)
        if [ "$DGB_PRERELEASE" = "NO" ]; then
            DGB_VER_LOCAL_QUERY=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
            if [ "$DGB_VER_LOCAL_QUERY" != "" ]; then
              DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
              sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
            fi
        fi

        # Are we running a pre-release or a release version of DigiByte Core?
        if [ "$DGB_PRERELEASE" = "NO" ]; then
            DGB_VER_GITHUB=$DGB_VER_RELEASE
        elif [ "$DGB_PRERELEASE" = "YES" ] && [ "$DGB_VER_PRERELEASE" = "" ]; then
            DGB_VER_GITHUB=$DGB_VER_RELEASE
        elif [ "$DGB_PRERELEASE" = "YES" ]; then
            DGB_VER_GITHUB=$DGB_VER_PRERELEASE
        fi

          # If there is actually a local version of DigiByte Core, and a stored remote version, check for an update
          if [ "$DGB_VER_LOCAL" != "" ] && [ "$DGB_VER_GITHUB" != "" ]; then

                dgb_update_status=$(is_dgb_newer_version "$DGB_VER_LOCAL" "$DGB_VER_GITHUB")

              if [ "$dgb_update_status" = "update_available" ]; then
                DGB_UPDATE_AVAILABLE="yes"
              else
                DGB_UPDATE_AVAILABLE="no"
              fi
          fi

      fi

    fi


    # SECONDARY DIGIBYTE NODE ---->

    if [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Check if secondary DigiByte Node is successfully responding to requests yet while starting up. If not, get the current error.
        if [ "$DGB2_STATUS" = "startingup" ]; then

            # Refresh diginode.settings to get the latest value of DGB_VER_LOCAL
            source $DGNT_SETTINGS_FILE

            # Are we running a pre-release or a release version of DigiByte Core?
            if [ "$DGB_PRERELEASE" = "NO" ]; then
                DGB_VER_GITHUB=$DGB_VER_RELEASE
            elif [ "$DGB_PRERELEASE" = "YES" ] && [ "$DGB_VER_PRERELEASE" = "" ]; then
                DGB_VER_GITHUB=$DGB_VER_RELEASE
            elif [ "$DGB_PRERELEASE" = "YES" ]; then
                DGB_VER_GITHUB=$DGB_VER_PRERELEASE
            fi
          
            # Query if digibyte has finished starting up. Display error. Send success to null.
            is_dgb2_live_query=$($DGB_CLI -testnet uptime 2>&1 1>/dev/null)
            if [ "$is_dgb2_live_query" != "" ]; then
                DGB2_ERROR_MSG=$(echo $is_dgb2_live_query | cut -d ':' -f3)
                clean_dgb_error_msg
            else
                DGB2_TROUBLESHOOTING_MSG="10sec: startingup > running"
                DGB2_STATUS="running"

                # Get current listening port
                DGB2_LISTEN_PORT=$($DGB_CLI -testnet getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)

                # scrape digibyte.conf
                scrape_digibyte_conf

                # query for digibyte network
                query_digibyte_chain

                # update max connections
                digibyte_maxconnections_query

                # update rpc credentials
                digibyte_rpc_query

            fi

        fi

        # Update local block count every 10 seconds (approx once per block)
        # Is digibyted in the process of starting up, and not ready to respond to requests?
        if [ "$DGB2_STATUS" = "running" ] && [ "$DGB2_BLOCKSYNC_PROGRESS" = "synced" ]; then
            DGB2_BLOCKCOUNT_LOCAL=$($DGB_CLI -testnet getblockcount 2>/dev/null)
            DGB2_BLOCKCOUNT_FORMATTED=$(printf "%'d" $DGB2_BLOCKCOUNT_LOCAL)
            if [ "$DGB2_BLOCKCOUNT_LOCAL" = "" ]; then
                DGB2_STATUS="startingup"
                DGB2_LISTEN_PORT=""
                # scrape digibyte.conf
                scrape_digibyte_conf
                # query for digibyte network
                query_digibyte_chain
                # query for digibyte listening port
                digibyte_port_query
                # update rpc credentials
                digibyte_rpc_query
                DGB2_TROUBLESHOOTING_MSG="10sec: running > startingup"
            else
                # Get the algo used for the current block (mainnet or testnet)
                DGB2_BLOCK_CURRENT_ALGO=$(tail $DGB_SETTINGS_LOCATION/testnet4/debug.log 2>/dev/null | grep $DGB2_BLOCKCOUNT_LOCAL | cut -d'(' -f 2 | cut -d')' -f 1)
            fi
        fi



        # If there is a new DigiByte Core release available, check every 10 seconds until it has been installed
        # Only run this check if the primary DigiByte Node is not running, since it will check this above
        if [ $DGB2_STATUS = "running" ] && [ $DGB_STATUS != "running" ]; then

          if [ "$DGB_VER_LOCAL_CHECK_FREQ" = "" ] || [ "$DGB_VER_LOCAL_CHECK_FREQ" = "10secs" ] || [ "$DGB_VER_LOCAL_CHECK_FREQ" = "15secs" ]; then

            # Refresh diginode.settings to get the latest value of DGB_VER_LOCAL
            source $DGNT_SETTINGS_FILE

            # Query current version number of DigiByte Core, and write to diginode.settings (unless running pre-release version)
            if [ "$DGB_PRERELEASE" = "NO" ]; then
                DGB_VER_LOCAL_QUERY=$($DGB_CLI -testnet getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
                if [ "$DGB_VER_LOCAL_QUERY" != "" ]; then
                  DGB_VER_LOCAL=$DGB_VER_LOCAL_QUERY
                  sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
                fi
            fi

            # Are we running a pre-release or a release version of DigiByte Core?
            if [ "$DGB_PRERELEASE" = "NO" ]; then
                DGB_VER_GITHUB=$DGB_VER_RELEASE
            elif [ "$DGB_PRERELEASE" = "YES" ] && [ "$DGB_VER_PRERELEASE" = "" ]; then
                DGB_VER_GITHUB=$DGB_VER_RELEASE
            elif [ "$DGB_PRERELEASE" = "YES" ]; then
                DGB_VER_GITHUB=$DGB_VER_PRERELEASE
            fi



            # Compare current DigiByte Core version with Github version to know if there is a new version available
            dgb_update_status=$(is_dgb_newer_version "$DGB_VER_LOCAL" "$DGB_VER_GITHUB")
            if [ "$dgb_update_status" = "update_available" ]; then
                DGB_UPDATE_AVAILABLE="yes"
            else
                DGB_VER_LOCAL_CHECK_FREQ="daily"
                sed -i -e "/^DGB_VER_LOCAL_CHECK_FREQ=/s|.*|DGB_VER_LOCAL_CHECK_FREQ=\"$DGB_VER_LOCAL_CHECK_FREQ\"|" $DGNT_SETTINGS_FILE
                DGB_UPDATE_AVAILABLE="no"
            fi

          fi

        fi

    fi


    # update external IP if it is offline
    if [ "$IP4_EXTERNAL" = "OFFLINE" ]; then

        # Check if the DigiNode has gone offline
        wget -q --connect-timeout=0.5 --spider http://google.com
        if [ $? -eq 0 ]; then

            IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short 2>/dev/null)
            if [ $IP4_EXTERNAL_QUERY != "" ]; then
                IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
                sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $DGNT_SETTINGS_FILE
            fi

            IP6_EXTERNAL_QUERY=$(curl -6 --max-time 4 -sfL icanhazip.com)
            if [ "$IP6_EXTERNAL_QUERY" != "" ]; then
                IP6_EXTERNAL=$IP6_EXTERNAL_QUERY
                sed -i -e "/^IP6_EXTERNAL=/s|.*|IP6_EXTERNAL=\"$IP6_EXTERNAL\"|" $DGNT_SETTINGS_FILE
            else
                IP6_EXTERNAL=""
                sed -i -e "/^IP6_EXTERNAL=/s|.*|IP6_EXTERNAL=\"\"|" $DGNT_SETTINGS_FILE
            fi

        fi

    fi

    # update external IP, unless it is offline
    if [ "$IP4_INTERNAL" = "OFFLINE" ]; then

          IP4_INTERNAL_QUERY=$(ip -6 addr show scope global | grep -Eo 'inet6 ([a-f0-9:]+)' | awk '{print $2}' | head -n 1)
          if [ $IP4_INTERNAL_QUERY != "" ]; then
            IP4_INTERNAL=$IP4_INTERNAL_QUERY
            sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"$IP4_INTERNAL\"|" $DGNT_SETTINGS_FILE
          else
            IP4_INTERNAL="OFFLINE"
            sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"OFFLINE\"|" $DGNT_SETTINGS_FILE
          fi

          IP6_LINKLOCAL_QUERY=$(ip -6 addr show | grep 'inet6 fe80:' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
          if [ $IP6_ULA_QUERY != "" ]; then
            IP6_LINKLOCAL=$IP6_LINKLOCAL_QUERY
            sed -i -e "/^IP6_LINKLOCAL=/s|.*|IP6_LINKLOCAL=\"$IP6_LINKLOCAL\"|" $DGNT_SETTINGS_FILE
          else
            IP6_LINKLOCAL=""
            sed -i -e "/^IP6_LINKLOCAL=/s|.*|IP6_LINKLOCAL=\"\"|" $DGNT_SETTINGS_FILE
          fi

          IP6_ULA_QUERY=$(ip -6 addr show | grep -E 'inet6 fd[0-9a-f]{2}:' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
          if [ $IP6_ULA_QUERY != "" ]; then
            IP6_ULA=$IP6_ULA_QUERY
            sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"$IP6_ULA\"|" $DGNT_SETTINGS_FILE
          else
            IP6_ULA=""
            sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"\"|" $DGNT_SETTINGS_FILE
          fi

          IP6_GUA_QUERY=$(ip -6 addr show scope global | grep -Eo 'inet6 ([a-f0-9:]+)' | awk '{print $2}' | head -n 1)
          if [ $IP6_GUA_QUERY != "" ]; then
            IP6_GUA=$IP6_GUA_QUERY
            sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"$IP6_GUA\"|" $DGNT_SETTINGS_FILE
          else
            IP6_GUA=""
            sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"\"|" $DGNT_SETTINGS_FILE
          fi

    fi

    # Lookup disk usage, and store in diginode.settings if present
    update_disk_usage

    # Query the DigiAsset Node console
    update_dga_console

    SAVED_TIME_10SEC="$(date +%s)"
    sed -i -e "/^SAVED_TIME_10SEC=/s|.*|SAVED_TIME_10SEC=\"$(date +%s)\"|" $DGNT_SETTINGS_FILE
fi


# ------------------------------------------------------------------------------
#    Run once every 1 minute
#    Every minute lookup the latest block from the online block exlorer to calculate sync progress.
# ------------------------------------------------------------------------------

TIME_DIF_1MIN=$(($TIME_NOW_UNIX-$SAVED_TIME_1MIN))

if [ $TIME_DIF_1MIN -ge 60 ]; then

    if [ "$STARTUP_LOOP" = true ]; then
    printf "%b Updating Status: 1 Minute Loop...\\n" "${INFO}"
    fi


    # PRIMARY DIGIBYTE NODE ---->

    # Update primary DigiByte Node sync progress every minute, if it is running
    if [ "$DGB_STATUS" = "running" ]; then

        # Get current listening port
        DGB_LISTEN_PORT=$($DGB_CLI getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)

        # Lookup sync progress value from debug.log. Use previous saved value if no value is found.
        if [ "$DGB_BLOCKSYNC_PROGRESS" = "synced" ]; then

            # Lookup the sync progress value from debug.log (mainnet, testnet, regtest, signet)
            if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
                DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/testnet4/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
            elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
                DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/regtest/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
            elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
                DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/signet/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
            elif [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
                DGB_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
            fi
         
            # Is the returned value numerical?
            re='^[0-9]+([.][0-9]+)?$'
            if ! [[ $DGB_BLOCKSYNC_VALUE_QUERY =~ $re ]] ; then
               DGB_BLOCKSYNC_VALUE_QUERY=""
            fi

            # Ok, we got a number back. Update the variable.
            if [ "$DGB_BLOCKSYNC_VALUE_QUERY" != "" ]; then
               DGB_BLOCKSYNC_VALUE=$DGB_BLOCKSYNC_VALUE_QUERY
               sed -i -e "/^DGB_BLOCKSYNC_VALUE=/s|.*|DGB_BLOCKSYNC_VALUE=\"$DGB_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
            fi

            # Calculate blockchain sync percentage
            DGB_BLOCKSYNC_PERC=$(echo "scale=2 ;$DGB_BLOCKSYNC_VALUE*100"|bc)

            # Round blockchain sync percentage to two decimal places
            DGB_BLOCKSYNC_PERC=$(printf "%.2f \n" $DGB_BLOCKSYNC_PERC)

            # If it's at 100.00, get rid of the decimal zeros
            if [ "$DGB_BLOCKSYNC_PERC" = "100.00 " ]; then
              DGB_BLOCKSYNC_PERC="100 "
            fi

            # Check if sync progress is not 100%
            if [ "$DGB_BLOCKSYNC_PERC" = "100 " ]; then
                DGB_BLOCKSYNC_PROGRESS="synced"
                if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$DGB_WALLET_STATUS" = "enabled" ]; then
                    # get the wallet balance
                    get_dgb_wallet_balance
                fi
            else
               DGB_BLOCKSYNC_PROGRESS="notsynced"
               WALLET_BALANCE=""
            fi

        fi

    fi


   # SECONDARY DIGIBYTE NODE ---->

    # Update secondary DigiByte Node sync progress every minute, if it is running
    if [ "$DGB2_STATUS" = "running" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then

        # Get current listening port
        DGB2_LISTEN_PORT=$($DGB_CLI -testnet getnetworkinfo 2>/dev/null | jq .localaddresses[0].port)

        # Lookup sync progress value from debug.log. Use previous saved value if no value is found.
        if [ "$DGB2_BLOCKSYNC_PROGRESS" = "synced" ]; then

            # Lookup the sync progress value from debug.log for testnet
            DGB2_BLOCKSYNC_VALUE_QUERY=$(tail -n 1 $DGB_SETTINGS_LOCATION/testnet4/debug.log | cut -d' ' -f12 | cut -d'=' -f2)
         
            # Is the returned value numerical?
            re='^[0-9]+([.][0-9]+)?$'
            if ! [[ $DGB2_BLOCKSYNC_VALUE_QUERY =~ $re ]] ; then
               DGB2_BLOCKSYNC_VALUE_QUERY=""
            fi

            # Ok, we got a number back. Update the variable.
            if [ "$DGB2_BLOCKSYNC_VALUE_QUERY" != "" ]; then
               DGB2_BLOCKSYNC_VALUE=$DGB2_BLOCKSYNC_VALUE_QUERY
               sed -i -e "/^DGB2_BLOCKSYNC_VALUE=/s|.*|DGB2_BLOCKSYNC_VALUE=\"$DGB2_BLOCKSYNC_VALUE\"|" $DGNT_SETTINGS_FILE
            fi

            # Calculate blockchain sync percentage
            DGB2_BLOCKSYNC_PERC=$(echo "scale=2 ;$DGB2_BLOCKSYNC_VALUE*100"|bc)

            # Round blockchain sync percentage to two decimal places
            DGB2_BLOCKSYNC_PERC=$(printf "%.2f \n" $DGB2_BLOCKSYNC_PERC)

            # If it's at 100.00, get rid of the decimal zeros
            if [ "$DGB2_BLOCKSYNC_PERC" = "100.00 " ]; then
              DGB2_BLOCKSYNC_PERC="100 "
            fi

            # Check if sync progress is not 100%
            if [ "$DGB2_BLOCKSYNC_PERC" = "100 " ]; then
                DGB2_BLOCKSYNC_PROGRESS="synced"
                if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$DGB_WALLET_STATUS" = "enabled" ]; then
                    # get the wallet balance
                    get_dgb2_wallet_balance
                fi
            else
               DGB2_BLOCKSYNC_PROGRESS="notsynced"
               WALLET_BALANCE=""
            fi

        fi

    fi

    # Choose a new random DigiFact
    digifact_randomize

    # update internal IP, unless it is offline
    if [ "$IP4_INTERNAL" != "OFFLINE" ]; then

          IP4_INTERNAL_QUERY=$(ip a | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' 2>/dev/null| grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n 1)
          if [ "$IP4_INTERNAL_QUERY" != "" ]; then
            IP4_INTERNAL=$IP4_INTERNAL_QUERY
            sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"$IP4_INTERNAL\"|" $DGNT_SETTINGS_FILE
          else
            IP4_INTERNAL="OFFLINE"
            sed -i -e "/^IP4_INTERNAL=/s|.*|IP4_INTERNAL=\"OFFLINE\"|" $DGNT_SETTINGS_FILE
          fi

        # update IP6 link-local address and save to settings file
        IP6_LINKLOCAL_QUERY=$(ip -6 addr show | grep 'inet6 fe80:' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
        if [ "$IP6_LINKLOCAL_QUERY" != "" ]; then
            IP6_LINKLOCAL=$IP6_LINKLOCAL_QUERY
            sed -i -e "/^IP6_LINKLOCAL=/s|.*|IP6_LINKLOCAL=\"$IP6_LINKLOCAL\"|" $DGNT_SETTINGS_FILE
        else
            IP6_LINKLOCAL=""
            sed -i -e "/^IP6_LINKLOCAL=/s|.*|IP6_LINKLOCAL=\"\"|" $DGNT_SETTINGS_FILE
        fi

        # update IP6 ULA address and save to settings file
        IP6_ULA_QUERY=$(ip -6 addr show | grep -E 'inet6 fd[0-9a-f]{2}:' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
        if [ "$IP6_ULA_QUERY" != "" ]; then
            IP6_ULA=$IP6_ULA_QUERY
            sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"$IP6_ULA\"|" $DGNT_SETTINGS_FILE
        else
            IP6_ULA=""
            sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"\"|" $DGNT_SETTINGS_FILE
        fi

        # update IP6 GUA address and save to settings file
        IP6_GUA_QUERY=$(ip -6 addr show scope global | grep -Eo 'inet6 ([a-f0-9:]+)' | awk '{print $2}' | head -n 1)
        if [ "$IP6_GUA_QUERY" != "" ]; then
            IP6_GUA=$IP6_GUA_QUERY
            sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"$IP6_GUA\"|" $DGNT_SETTINGS_FILE
        else
            IP6_GUA=""
            sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"\"|" $DGNT_SETTINGS_FILE
        fi

    fi


    # Check if the DigiNode has gone offline
    wget -q --connect-timeout=0.5 --spider http://google.com
    if [ $? -ne 0 ]; then
        IP4_EXTERNAL="OFFLINE"
        sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"OFFLINE\"|" $DGNT_SETTINGS_FILE
    fi


    # Update diginode.settings with when Dashboard last ran
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

if [ $TIME_DIF_15MIN -ge 900 ]; then

    if [ "$STARTUP_LOOP" = true ]; then
    printf "%b Updating Status: 15 Minute Loop...\\n" "${INFO}"
    fi

    # update external IP, unless it is offline
    if [ "$IP4_EXTERNAL" != "OFFLINE" ]; then

        IP4_EXTERNAL_QUERY=$(dig @resolver4.opendns.com myip.opendns.com +short +timeout=5 2>/dev/null)
        if [ "$IP4_EXTERNAL_QUERY" != "" ]; then
            IP4_EXTERNAL=$IP4_EXTERNAL_QUERY
            sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"$IP4_EXTERNAL\"|" $DGNT_SETTINGS_FILE
        else
            IP4_EXTERNAL="OFFLINE"
            sed -i -e "/^IP4_EXTERNAL=/s|.*|IP4_EXTERNAL=\"OFFLINE\"|" $DGNT_SETTINGS_FILE
        fi

        IP6_EXTERNAL_QUERY=$(curl -6 --max-time 4 -sfL icanhazip.com)
        if [ "$IP6_EXTERNAL_QUERY" != "" ]; then
            IP6_EXTERNAL=$IP6_EXTERNAL_QUERY
            sed -i -e "/^IP6_EXTERNAL=/s|.*|IP6_EXTERNAL=\"$IP6_EXTERNAL\"|" $DGNT_SETTINGS_FILE
        else
            IP6_EXTERNAL=""
            sed -i -e "/^IP6_EXTERNAL=/s|.*|IP6_EXTERNAL=\"\"|" $DGNT_SETTINGS_FILE
        fi

        IP6_ULA_QUERY=$(ip -6 addr show | grep -E 'inet6 fd[0-9a-f]{2}:' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
        if [ "$IP6_ULA_QUERY" != "" ]; then
            IP6_ULA=$IP6_ULA_QUERY
            sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"$IP6_ULA\"|" $DGNT_SETTINGS_FILE
        else
            IP6_ULA=""
            sed -i -e "/^IP6_ULA=/s|.*|IP6_ULA=\"\"|" $DGNT_SETTINGS_FILE
        fi

        IP6_GUA_QUERY=$(ip -6 addr show scope global | grep -Eo 'inet6 ([a-f0-9:]+)' | awk '{print $2}' | head -n 1)
        if [ "$IP6_GUA_QUERY" != "" ]; then
            IP6_GUA=$IP6_GUA_QUERY
            sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"$IP6_GUA\"|" $DGNT_SETTINGS_FILE
        else
            IP6_GUA=""
            sed -i -e "/^IP6_GUA=/s|.*|IP6_GUA=\"\"|" $DGNT_SETTINGS_FILE
        fi

    fi

    # If DigiAssets server is running, lookup local version number of DigiAssets server IP
    if [ "$DGA_STATUS" = "running" ]; then

      # Next let's try and get the minor version, which may or may not be available yet
      # If DigiAsset Node is running we can get it directly from the web server

      DGA_VER_MNR_LOCAL_QUERY=$(curl --max-time 4 localhost:8090/api/version/list.json 2>/dev/null | jq .current | sed 's/"//g')
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

    if [ "$STARTUP_LOOP" = true ]; then
    printf "%b Updating Status: 24 Hour Loop...\\n" "${INFO}"
    fi

    # items to repeat every 24 hours go here

    # check for system updates
  #  SYSTEM_SECURITY_UPDATES=$(/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 1)
  #  SYSTEM_REGULAR_UPDATES=$(/usr/lib/update-notifier/apt-check 2>&1 | cut -d ';' -f 2)
  #  sed -i -e "/^SYSTEM_SECURITY_UPDATES=/s|.*|SYSTEM_SECURITY_UPDATES=\"$SYSTEM_SECURITY_UPDATES\"|" $DGNT_SETTINGS_FILE
  #  sed -i -e "/^SYSTEM_REGULAR_UPDATES=/s|.*|SYSTEM_REGULAR_UPDATES=\"$SYSTEM_REGULAR_UPDATES\"|" $DGNT_SETTINGS_FILE



    # If there is a new DigiByte Core release available, check every 15 seconds until it has been installed
    if [ "$DGB_VER_LOCAL_CHECK_FREQ" = "daily" ]; then
        if [ "$DGB_STATUS" = "running" ] || [ "$DGB2_STATUS" = "running" ]; then


            # Get current software version, and write to diginode.settings (unless pre-release)
            if [ "$DGB_PRERELEASE" = "NO" ]; then
                if [ "$DGB_STATUS" = "running" ]; then
                    DGB_VER_LOCAL=$($DGB_CLI getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)
                else
                    DGB_VER_LOCAL=$($DGB_CLI -testnet getnetworkinfo 2>/dev/null | grep subversion | cut -d ':' -f3 | cut -d '/' -f1)   
                fi
                sed -i -e "/^DGB_VER_LOCAL=/s|.*|DGB_VER_LOCAL=\"$DGB_VER_LOCAL\"|" $DGNT_SETTINGS_FILE
            fi

            # Check for an update to DigiBye Core
            check_digibyte_update

        fi
    fi

    # Check for new release of DigiNode Tools on Github
    dgnt_ver_release_query=$(curl --max-time 4 -sfL https://api.github.com/repos/saltedlolly/diginode-tools/releases/latest 2>/dev/null | jq -r ".tag_name" | sed 's/v//')
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
    DGA_VER_RELEASE_QUERY=$(curl --max-time 4 -sfL https://versions.digiassetx.com/digiasset_node/versions.json 2>/dev/null | jq last | sed 's/"//g')
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
    IPFS_VER_RELEASE_QUERY=$(curl --max-time 4 -sfL https://api.github.com/repos/ipfs/kubo/releases/latest | jq -r ".tag_name" | sed 's/v//g')
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

if [ "$STARTUP_LOOP" = true ]; then
    printf "%b Generating dashboard...\\n" "${INFO}"
fi


###################################################################
#### GENERATE DISPLAY OUTPUT ######################################
###################################################################

# Store the previous terminal width (in case it has been resized since the previous loop)
term_width_previous=$term_width

# Get the width of the terminal
term_width=$(tput cols)

# Has the table been rezized since previous loop?
if [ "$term_width" != "$term_width_previous" ]; then
    terminal_resized="yes"
else
    terminal_resized="no"
fi

###################################################################
# DISPLAY REGENERATING SCREEN WHEN THE TERMINAL WIDTH HAS CHANGED #
###################################################################

if [ "$terminal_resized" = "yes" ] && [ "$STARTUP_LOOP" = false ]; then

    # Define the strings with line breaks
    string1="        Tip: If you find the dashboard suddenly gets duplicated down the\n             screen, you can fix this by scrolling to the bottom of the\n             window. This is caused by a limitation of the terminal.\n"
    string2="           Tip: To launch a website URL from the terminal,\n                use Cmd-click (Mac) or Ctrl-click (Windows)."
    string3="         Tip: To make the dashboard text bigger or smaller, press\n              Ctrl-+ or Ctrl-- (Windows) and Cmd-+ or Cmd-- (MacOS)."

    # Create an array from the individual strings
    strings=("$string1" "$string2" "$string3")

    # Get the current time
#    current_time=$(date +%s)

    # Check if 60 seconds have passed since the last selection
#    if ((current_time - last_tip_selection_time >= 500)) || [ "$change_tip" = "yes" ]; then
    if [ "$change_tip" = "yes" ]; then

        # Use shuf to generate a random index
        random_index=$(shuf -i 0-2 -n 1)

        # Use the random index to select a random string from the array
        random_tip="${strings[random_index]}"

        # Update the last tip selection time
 #       last_tip_selection_time=$current_time   

        change_tip="no"
    else

        # Display the random string
        printf "$random_tip"

    fi

    # Gernerate out to display when regenerating dashboard after the terminal is resized
    output_regenerating=$(printf '\e[2J\e[H';

    #echo -e "${txtbld}"
    echo -e "${txtbld}        ____   _         _   _   __            __     "             
    echo -e "       / __ \ (_)____ _ (_) / | / /____   ____/ /___   "
    echo -e "      / / / // // __ '// / /  |/ // __ \ / __  // _ \  ${txtrst}┳┓   ┓ ┓        ┓${txtbld}"
    echo -e "     / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/  ${txtrst}┃┃┏┓┏┣┓┣┓┏┓┏┓┏┓┏┫${txtbld}"
    echo -e "    /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/   ${txtrst}┻┛┗┻┛┛┗┗┛┗┛┗┻┛ ┗┻${txtbld}"
    echo -e "               /____/                                  ${txtrst}"                    
    #echo ""  
    echo ""
    echo ""
    echo ""
    echo "               ╔═══════════════════════════════════════════╗ "
    echo "               ║                                           ║"
    echo "               ║   ${txtbld}Regenerating dashboard. Please wait...${txtrst}  ║"
    echo "               ║                                           ║"
    echo "               ╚═══════════════════════════════════════════╝"
    echo ""
    echo ""
    echo ""
    echo ""
    echo ""

    # Display the random tip
    printf "$random_tip"

    )

    echo "$output_regenerating"
fi

#####################################
### GENERATE DIGINODE DASHBOARD #####
#####################################

# Calculate column widths based on terminal width
col1_width=16
col2_width=16
col3_width=$((term_width - col1_width - col2_width - 6))  # 13 is for padding and borders
col4_width=10

generate_table_border() {
    # Using printf's repetition functionality to fill space or other characters

    local col1_content col2_content col3_content

    # Determine content for column 1
    if [ "$2" = "═" ]; then
        col1_content=$(printf "%0.s═" $(seq 1 $col1_width))
    else
        col1_content=$(printf "%-*s" $col1_width "$2")
    fi

    # Determine content for column 2
    if [ "$4" = "═" ]; then
        col2_content=$(printf "%0.s═" $(seq 1 $col2_width))
    else
        col2_content=$(printf "%-*s" $col2_width "$4")
    fi

    # Determine content for column 3
    col3_content=$(printf "%0.s$6" $(seq 1 $col3_width))

    # Construct the full row, with a leading space, and print it
    printf " %s%s%s%s%s%s%s\n" "$1" "$col1_content" "$3" "$col2_content" "$5" "$col3_content" "$7"
}


# Recalculate the Dashboard layout if the width of the terminal has changed
if [ "$terminal_resized" = "yes" ] || [ "$STARTUP_LOOP" = true ]; then

    # Generate table border rows
    sm_row_01=$(generate_table_border "╔" "═" "╦" "═" "╦" "═" "╗")
    sm_row_02_mainnet=$(generate_table_border "║" " (MAINNET)" "╠" "═" "╬" "═" "╣")
    sm_row_02_testnet=$(generate_table_border "║" " (TESTNET)" "╠" "═" "╬" "═" "╣")
    sm_row_02_regtest=$(generate_table_border "║" " (REGTEST)" "╠" "═" "╬" "═" "╣")
    sm_row_02_signet=$(generate_table_border "║" " (SIGNET)" "╠" "═" "╬" "═" "╣")
    sm_row_03=$(generate_table_border "╠" "═" "╬" "═" "╬" "═" "╣")
    sm_row_04=$(generate_table_border "║" " " "╠" "═" "╬" "═" "╣")
    sm_row_05=$(generate_table_border "╚" "═" "╩" "═" "╩" "═" "╝")
    sm_row_06=$(generate_table_border "╔" "═" "╦" "═" "═" "═" "╗")
    sm_row_07=$(generate_table_border "║" "═" "╬" "═" "═" "═" "╣")
    sm_row_08=$(generate_table_border "╚" "═" "╩" "═" "═" "═" "╝")
    sm_row_digifact_topbar=$(generate_table_border "╔" "═" "═" "═" "═" "═" "╗")
    sm_row_digifact_middle=$(generate_table_border "╠" "═" "═" "═" "═" "═" "╣")
    sm_row_digifact_bottom=$(generate_table_border "╚" "═" "═" "═" "═" "═" "╝")

    # Calculate the column widths based on terminal width
    col_width_dgb_connections_low=$((term_width - 38 - 29 - 3 - 2)) 
    col_width_dgb_connections_max=$((term_width - 38 - 29 - 3 - 2))
    col_width_dgb_blockheight=$((term_width - 38 - 19 - 3 - 2)) 
    col_width_dgb_uptime=$((term_width - 38 - 3 - 1)) 
    col_width_dgb_uptime_long=$((term_width - 38 - 39 - 3 - 2)) 
    col_width_dgb_ports=$((term_width - 38 - 3 - 1)) 
    col_width_dgb_ports_long=$((term_width - 38 - 17 - 3 - 3)) 
    col_width_dgb_wallet_balance=$((term_width - 38 - 3 - 1)) 
    col_width_dgb_status=$((term_width - 38 - 3 - 1 + 11)) 
    col_width_dgb_startingup=$((term_width - 38 - 14 - 3 - 2 + 11)) 
    col_width_dga_status=$((term_width - 38 - 3 - 1 + 8)) 

    col_width_software_wide=$((term_width - 21 - 50 - 2)) 
    col_width_software=$((term_width - 21 - 35 - 3 + 4)) 
    col_width_software_narrow=$((term_width - 21 - 27 - 3 - 2 + 8)) 
    col_width_software_noupdate=$((term_width - 21 - 3 - 1)) 

    col_width_software_dgnt_wide=$((term_width - 21 - 50 + 1)) 

    col_width_software_dgbpr_wide=$((term_width - 21 - 50 - 3 + 1)) 
    col_width_software_dgbpr=$((term_width - 21 - 37 - 3 + 2)) 
    col_width_software_dgbpr_lessnarrow=$((term_width - 21 - 35 - 3 + 9))
    col_width_software_dgbpr_narrow=$((term_width - 21 - 27 - 3 + 2)) 

    col_width_software_dgb_wide=$((term_width - 21 - 50 - 2)) 
    col_width_software_dgb=$((term_width - 21 - 37 - 3 + 2)) 
    col_width_software_dgb_narrow=$((term_width - 21 - 27 - 3 + 2)) 

    col_width_software_kubo_wide=$((term_width - 21 - 50 + 6)) 
    col_width_software_kobo=$((term_width - 21 - 35 - 3 + 4)) 
    col_width_software_kubo_narrow=$((term_width - 21 - 27 - 3 - 2 + 8)) 

    col_width_software_node_wide=$((term_width - 21 - 50 + 6)) 
    col_width_software_node=$((term_width - 21 - 42 - 3 + 9)) 
    col_width_software_node_narrow=$((term_width - 21 - 35 - 3 + 9)) 

    col_width_software_dga_wide=$((term_width - 21 - 50 + 4)) 
    col_width_software_dga=$((term_width - 21 - 35 - 3 + 7)) 
    col_width_software_dga_narrow=$((term_width - 21 - 27 - 3 + 9)) 

    col_width_sys_ip4_bothoffline=$((term_width - 17 - 3)) 
    col_width_sys_ip4_oneoffline=$((term_width - 17 - 3)) 

    generate_digifact_box="yes"
    generate_dgb_lowcon_msg="yes"
    if [ "$DGB_DUAL_NODE" = "YES" ]; then
        generate_dgb2_lowcon_msg="yes"
    fi
    generate_quit_message="yes"
    generate_quit_message_with_porttest="yes"
fi



### GENERATE DIGINODE DASHBOARD - TABLE ROWS #####

right_border="  ║ "
right_border_width=${#right_border} 

# Three/two column row (first two narrow columns are one static string, main content is 3rd.)
db_content_c1_c2_c3f() {
    local combined_col1_2_text="$1"
    local col3_text="$2"

    # Calculate width for first two columns combined e.g. " ║ DIGIBYTE NODE  ║    CONNECTIONS ║  "
    combined_col1_2_width=${#combined_col1_2_text} 

    # Calculate width available for column three content
    col3_width=$(( term_width - combined_col1_2_width - right_border_width ))  # Width of column 3 fill area

    # Strip ANSI color codes for calculation purposes
    local stripped_col3_text=$(echo -e "$col3_text" | sed 's/\x1b\[[0-9;]*m//g')
    local col3_text_length=${#stripped_col3_text}

    local col3_padding=$(( col3_width - col3_text_length ))

    # Constructing the row based on the described format
    local full_row
    full_row=$(printf "%-${combined_col1_2_width}s" "${combined_col1_2_text}")  # Combined Column 1 and 2 with added space (left-aligned)
    full_row+=$(printf "%b%-${col3_padding}s" "$col3_text")  # Column 3 content (left-aligned) with spacer
    full_row+=$(printf "$right_border")  # The right edge border with spaces

    # Print the row without it wrapping to the next line
    printf "%s\n" "$full_row"

}

# Four/three column row (first two columns are one static string, main content is 3rd, 4th column is right-aligned inside square brackets )
db_content_c1_c2_c3f_c4() {
    local combined_col1_2_text="$1"
    local col3_text="$2"
    local col4_text="[ $3 ]"

    # Calculate width for first two columns combined
    combined_col1_2_width=${#combined_col1_2_text} 

    # Strip ANSI color codes for calculation purposes
    local stripped_col3_text=$(echo -e "$col3_text" | sed 's/\x1b\[[0-9;]*m//g')
    local col3_text_length=${#stripped_col3_text}

    local stripped_col4_text=$(echo -e "$col4_text" | sed 's/\x1b\[[0-9;]*m//g')
    local col4_text_length=${#stripped_col4_text}

    # Calculate width available for column three and four content
    local col3_4_width=$(( term_width - combined_col1_2_width - right_border_width - col4_text_length))
    local col3_padding=$(( col3_4_width - col3_text_length ))

    # Constructing the row based on the described format
    local full_row
    full_row=$(printf "%-${combined_col1_2_width}s" "${combined_col1_2_text}")  # Combined Column 1 and 2 with added space (left-aligned)
    full_row+=$(printf "%b%-${col3_padding}s" "$col3_text")  # Column 3 content (left-aligned) with spacer
    full_row+=$(printf "%b%s" "$col4_text" "$right_border")  # Column 4 and The right edge border with spaces

    # Print the row without it wrapping to the next line
    printf "%s\n" "$full_row"
}




# Create finite width chain variables for first column
if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
    dgb_chain_firstcol="(MAINNET)     "
    dgb_chain_caps="MAINNET"
elif [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
    dgb_chain_firstcol="(TESTNET)     "
    dgb_chain_caps="TESTNET"
elif [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then
    dgb_chain_firstcol="(REGTEST)     "
    dgb_chain_caps="REGTEST"
elif [ "$DGB_NETWORK_CURRENT" = "SIGNET" ]; then
    dgb_chain_firstcol="(SIGNET)      "
    dgb_chain_caps="SIGNET"
else
    dgb_chain_firstcol="              "
fi

# May sure displayed RPC port only changes when there is a new value
if [ "$RPC_PORT" != "" ]; then
    dgb_rpcport_display=$RPC_PORT
fi
if [ "$RPC2_PORT" != "" ]; then
    dgb2_rpcport_display=$RPC2_PORT
fi

# FORMAT DIGIFACT BASED ON TERMINAL WIDTH

# regenerate digifact box
if [ "$generate_digifact_box" = "yes" ] && [ "$digifact_content" != "" ]; then
    digifact_box_termwidth_title=$(format_bordered_title "$digifact_title" " ║ " " ║ " "terminal_width")
    digifact_box_termwidth_content=$(format_bordered_paragraph "$digifact_content" " ║ " " ║ " "  ║ " "terminal_width")
    generate_digifact_box="no"
fi   

# Setup function to display DigiFact dashboard
display_digifact_termwidth() {

    if [ "$digifact_content" != "" ]; then
        echo "$sm_row_digifact_topbar" # "╔" "═" "═" "═" "═" "═" "╗"
        echo "$digifact_box_termwidth_title"
        echo "$sm_row_digifact_middle" # "╠" "═" "═" "═" "═" "═" "╣"
        echo "$digifact_box_termwidth_content"
        echo "$sm_row_digifact_bottom" # "╚" "═" "═" "═" "═" "═" "╝"
    fi
} 

# FORMAT LOWCON MESSAGES BASED ON TERMINAL WIDTH

# Enable primary mainnet node port test message when connections are low
if { [ "$DGB_STATUS" = "running" ] && [ $DGB_CONNECTIONS -le 8 ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; } && [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "YES" ]; then
    if [ "$dgb_lowcon_porttest_msg" != "For more help, press P to run a Port Test." ]; then
        dgb_lowcon_porttest_msg="For more help, press P to run a Port Test."
        generate_dgb_lowcon_msg="yes"
    fi
# Enable primary node testnet port test message when connections are low
elif { [ "$DGB_STATUS" = "running" ] && [ $DGB_CONNECTIONS -le 8 ] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; } && [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ]; then
    if [ "$dgb_lowcon_porttest_msg" != "For more help, press P to run a Port Test." ]; then
        dgb_lowcon_porttest_msg="For more help, press P to run a Port Test."
        generate_dgb_lowcon_msg="yes"
    fi
else
    if [ "$dgb_lowcon_porttest_msg" != "" ]; then
        dgb_lowcon_porttest_msg=""
        generate_dgb_lowcon_msg="yes"
    fi
fi

# Enable secondary node port test message when connections are low
if { [ "$DGB2_STATUS" = "running" ] && [ $DGB2_CONNECTIONS -le 8 ]; } && [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ]; then
    if [ "$dgb_lowcon_porttest_msg" != "For more help, press P to run a Port Test." ]; then
        dgb2_lowcon_porttest_msg="For more help, press P to run a Port Test."
        generate_dgb2_lowcon_msg="yes"
    fi
else
    if [ "$dgb_lowcon_porttest_msg" != "" ]; then
        dgb2_lowcon_porttest_msg=""
        generate_dgb2_lowcon_msg="yes"
    fi
fi


# regenerate dgb_lowcon_msg
if { [ "$DGB_STATUS" = "running" ] && [ $DGB_CONNECTIONS -le 8 ] && [ "$DGB_NETWORK_CURRENT" != "REGTEST" ]; } && [ "$generate_dgb_lowcon_msg" = "yes" ]; then
    dgb_lowcon_msg="WARNING: Your DigiByte ${DGB_NETWORK_CURRENT,,} connection count is low. Have you forwarded port $DGB_LISTEN_PORT on your router? If yes, wait a few minutes. This message will disappear when the total connections reaches 9 or more. $dgb_lowcon_porttest_msg"
    dgb_lowcon_msg=$(format_bordered_paragraph "$dgb_lowcon_msg" " ║                ║         STATUS ║  " " ║                ║                ║  " "  ║ " "terminal_width")
    generate_dgb_lowcon_msg="no"
fi

# Setup function to display DigiFact primary DigiByte Node low connection message
display_dgb_lowcon_msg() {
    echo "$dgb_lowcon_msg"
    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
} 

# regenerate dgb2_lowcon_msg
if { [ "$DGB2_STATUS" = "running" ] && [ $DGB2_CONNECTIONS -le 8 ]; } && [ "$generate_dgb2_lowcon_msg" = "yes" ]; then
    dgb2_lowcon_msg="WARNING: Your DigiByte testnet connection count is low. Have you forwarded port $DGB2_LISTEN_PORT on your router? If yes, wait a few minutes. This message will disappear when the total connections reaches 9 or more. $dgb2_lowcon_porttest_msg"
    dgb2_lowcon_msg=$(format_bordered_paragraph "$dgb2_lowcon_msg" " ║                ║         STATUS ║  " " ║                ║                ║  " "  ║ " "terminal_width")
    generate_dgb2_lowcon_msg="no"
fi

# Setup function to display DigiFact primary DigiByte Node low connection message
display_dgb2_lowcon_msg() {
    echo "$dgb2_lowcon_msg"
    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
} 


# FORMAT QUIT MESSAGE BASED ON TERMINAL WIDTH

# Function to center quit message
center_quit_message() {
    local quit_msg_text="$1"

    # Strip ANSI color codes for calculation purposes
    local stripped_quit_msg=$(echo -e "$quit_msg_text" | sed 's/\x1b\[[0-9;]*m//g')
    local quit_msg_length=${#stripped_quit_msg}

    # Calculate padding required to center text
    local left_padding=$(( (term_width - quit_msg_length) / 2 ))
    local right_padding=$(( term_width - left_padding - quit_msg_length ))

    # Construct the padded title string using # as the spacer and return it
    printf "%${left_padding}s"
    printf "%b" "$quit_msg_text"
    printf "%${right_padding}s"
}



# generate quit message
if [ "$generate_quit_message" = "yes" ]; then
    quit_message_text="Press ${dbcol_bld}Ctrl-C${dbcol_rst} or ${dbcol_bld}Q${dbcol_rst} to Quit."
    quit_message=$(center_quit_message "$quit_message_text")
    generate_quit_message="no"
fi

# generate quit message with port test
if [ "$generate_quit_message_with_porttest" = "yes" ]; then
    quit_message_text="Press ${dbcol_bld}Ctrl-C${dbcol_rst} or ${dbcol_bld}Q${dbcol_rst} to Quit. Press ${dbcol_bld}P${dbcol_rst} to test open ports."
    quit_messsage_with_port_test=$(center_quit_message "$quit_message_text")
    generate_quit_message_with_porttest="no"
fi

# FORMAT URL POSITION IN HEADER

# Calculate the https://diginodetools URL position based on the Terminal width
term_width_2=$(tput cols)
if [ $term_width_2 -le 72 ]; then
    col_width_url_position_2=""
else
    col_width_url_position_2=$((((term_width_2 - 72) / 2) - 11))
    if [ $col_width_url_position_2 -le 22 ]; then
        col_width_url_position_spaces_2=$(printf '%*s' "$col_width_url_position_2")
    else
        col_width_url_position_spaces_2=$(printf '%*s' 22)
    fi
fi

if [ "$STARTUP_LOOP" = true ]; then
    printf "%b Buffering dashboard...\\n" "${INFO}"
fi

###################################################################
#### BUFFER DIGNODE DASHBOARD #####################################
###################################################################

# Double buffer output to reduce display flickering
# output=$(printf '\e[2J\e[H'; - old double buffer
output=$(tput cup 0 0;

#echo -e "${txtbld}"
printf "${txtbld}        ____   _         _   _   __            __     " && tput el && printf "\\n"          
printf "       / __ \ (_)____ _ (_) / | / /____   ____/ /___   " && tput el && printf "\\n"
printf "      / / / // // __ '// / /  |/ // __ \ / __  // _ \  ${txtrst}┳┓   ┓ ┓        ┓${txtbld}" && tput el && printf "\\n"
if [ $term_width -gt 97 ]; then
printf "     / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/  ${txtrst}┃┃┏┓┏┣┓┣┓┏┓┏┓┏┓┏┫${txtbld}${col_width_url_position_spaces_2}https://diginode.tools"  && tput el && printf "\\n"
else
printf "     / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/  ${txtrst}┃┃┏┓┏┣┓┣┓┏┓┏┓┏┓┏┫${txtbld}" && tput el && printf "\\n"
fi
printf "    /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/   ${txtrst}┻┛┗┻┛┛┗┗┛┗┛┗┻┛ ┗┻${txtbld}" && tput el && printf "\\n"
printf "               /____/                                  ${txtrst}"  && tput el && printf "\\n"                        
#echo ""  

### DEBUGGING ###

# Debug output
# echo "col_width_url_position: $col_width_url_position"
#echo ""

# DGB_CONNECTIONS_MSG="Warning: Low Connections!"
# DGB_CONNECTIONS=5
# DGB_BLOCKSYNC_PERC=72.63
# WALLET_BALANCE=1000.0000000
# DGB_NETWORK_CURRENT="TESTNET"
# DGB_STATUS="not_detected"

# Debugging:
#echo ""
#echo ""
#echo "Border Type: $border_type"
#echo ""
#echo "border_id: $border_id"
#echo "Variable name: ${border_id}"
#echo "Variable value: ${!border_id}"

#echo ""
#echo ""


# STATUS MONITOR DASHBOARD - GENERATE NODE TABLE

echo "$sm_row_01" # "╔" "═" "╦" "═" "╦" "═" "╗"

# STATUS MONITOR DASHBOARD - DIGIBYTE PRIMARY NODE

if [ "$DGB_STATUS" = "running" ]; then # Only display if primary DigiByte Node is running
    if [ $DGB_CONNECTIONS -le 8 ]; then
        printf " ║ DIGIBYTE NODE  ║    CONNECTIONS ║  " && printf "%-${col_width_dgb_connections_low}s %29s %-3s\n" "$DGB_CONNECTIONS Peers" "[ ${txtbred}$DGB_CONNECTIONS_MSG${txtrst} ]" " ║ "
    else
        printf " ║ DIGIBYTE NODE  ║    CONNECTIONS ║  " && printf "%-${col_width_dgb_connections_max}s %29s %-3s\n" "$DGB_CONNECTIONS Peers" "[ $DGB_CONNECTIONS_MSG ]" " ║ "
    fi
    # Choose the correct network chain border
    if [ "$dgb_chain_caps" = "MAINNET" ]; then
        echo "$sm_row_02_mainnet" # "║" "(MAINNET)" "╠" "═" "╬" "═" "╣"
    elif [ "$dgb_chain_caps" = "TESTNET" ]; then
        echo "$sm_row_02_testnet" # "║" "(TESTNET)" "╠" "═" "╬" "═" "╣"
    elif [ "$dgb_chain_caps" = "REGTEST" ]; then
        echo "$sm_row_02_regtest" # "║" "(REGTEST)" "╠" "═" "╬" "═" "╣"
    elif [ "$dgb_chain_caps" = "SIGNET" ]; then
        echo "$sm_row_02_signet" # "║" "(SIGNET)" "╠" "═" "╬" "═" "╣"
    fi

    # Display primary dgb node lowcon message
    if [ $DGB_CONNECTIONS -le 8 ] && [ "$DGB_NETWORK_CURRENT" != "REGTEST" ]; then
        display_dgb_lowcon_msg
    fi

    printf " ║                ║   BLOCK HEIGHT ║  " && printf "%-${col_width_dgb_blockheight}s %19s %-3s\n" "$DGB_BLOCKCOUNT_FORMATTED Blocks" "[ Synced: $DGB_BLOCKSYNC_PERC% ]" " ║ "
    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
    if [ $term_width -gt 121 ]; then 
        printf " ║                ║    NODE UPTIME ║  " && printf "%-${col_width_dgb_uptime_long}s %19s %-3s\n" "$dgb_uptime" "[ Online Since: $dgb_online_since ]" " ║ "
    else
        printf " ║                ║    NODE UPTIME ║  " && printf "%-${col_width_dgb_uptime}s %-3s\n" "$dgb_uptime" " ║ "
    fi
    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
    if grep -q ^"upnp=1" $DGB_CONF_FILE; then
        if [ $term_width -gt 99 ]; then 
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" "[ UPnP: Enabled ]" " ║ "
        else
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" " ║ "
        fi
    else
        if [ $term_width -gt 100 ]; then 
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" "[ UPnP: Disabled ]" " ║ "
        else
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" " ║ "
        fi
    fi

    # Only display the DigiByte wallet balance if the user (a) wants it displayed AND (b) the blockchain has finished syncing AND (c) the wallet actually contains any DGB
    if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$DGB_BLOCKSYNC_PERC" = "100 " ] && [ "$DGB_WALLET_BALANCE" != "" ]; then 
        echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"

        if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] || [ "$DGB_NETWORK_CURRENT" = "REGTEST" ]; then 
            printf " ║                ║ WALLET BALANCE ║  " && printf "%-${col_width_dgb_wallet_balance}s %-3s\n" "$DGB_WALLET_BALANCE DGBT" " ║ "
        else
            printf " ║                ║ WALLET BALANCE ║  " && printf "%-${col_width_dgb_wallet_balance}s %-3s\n" "$DGB_WALLET_BALANCE DGB" " ║ "
        fi
    fi

    echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"

fi

if [ "$DGB_STATUS" = "stopped" ]; then # Only display if primary DigiByte Node is stopped running
    if [ "$DGB_DUAL_NODE" = "YES" ]; then
        printf " ║ DIGIBYTE NODE  ║  NODE 1 STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbred}DigiByte $dgb_chain_caps Node is not running.${txtrst}" " ║ "
    else
        printf " ║ DIGIBYTE NODE  ║         STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbred}DigiByte $dgb_chain_caps Node is not running.${txtrst}" " ║ "
    fi
    echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"
fi

if [ "$DGB_STATUS" = "not_detected" ]; then # Only display if primary DigiByte Node is not detected
    printf " ║ DIGIBYTE NODE  ║         STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbred}DigiByte Node not detected.${txtrst}" " ║ "
    echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"
fi

if [ "$DGB_STATUS" = "startingup" ]; then # Only display if secondary DigiByte Node is starting
    printf " ║ DIGIBYTE NODE  ║         STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbylw}DigiByte $dgb_chain_caps Node is currently starting up.${txtrst}" " ║ "
    printf " ║ $dgb_chain_firstcol ║                ║  " && printf "%-14s %-${col_width_dgb_startingup}s %-3s\n" "Please wait..." "${txtbwht}$DGB_ERROR_MSG${txtrst}" " ║ "

    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
    if grep -q ^"upnp=1" $DGB_CONF_FILE; then
        if [ $term_width -gt 99 ]; then 
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" "[ UPnP: Enabled ]" " ║ "
        else
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" " ║ "
        fi
    else
        if [ $term_width -gt 100 ]; then 
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" "[ UPnP: Disabled ]" " ║ "
        else
            printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB_LISTEN_PORT}   RPC Port: $dgb_rpcport_display" " ║ "
        fi
    fi
    echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"
fi

# STATUS MONITOR DASHBOARD - DIGIBYTE SECONDARY NODE

if [ "$DGB_DUAL_NODE" = "YES" ]; then

    if [ "$DGB2_STATUS" = "running" ]; then # Only display if secondary DigiByte Node is running
        if [ $DGB2_CONNECTIONS -le 8 ]; then
            printf " ║ DIGIBYTE NODE  ║    CONNECTIONS ║  " && printf "%-${col_width_dgb_connections_low}s %29s %-3s\n" "$DGB2_CONNECTIONS Nodes" "[ ${txtbred}$DGB2_CONNECTIONS_MSG${txtrst} ]" " ║ "
        else
            printf " ║ DIGIBYTE NODE  ║    CONNECTIONS ║  " && printf "%-${col_width_dgb_connections_max}s %29s %-3s\n" "$DGB2_CONNECTIONS Nodes" "[ $DGB2_CONNECTIONS_MSG ]" " ║ "
        fi
        # Display the TESTNET network chain border
        echo "$sm_row_02_testnet" # "║" "(TESTNET)" "╠" "═" "╬" "═" "╣"

        # Display primary dgb node lowcon message
        if [ $DGB2_CONNECTIONS -le 8 ]; then
            display_dgb2_lowcon_msg
        fi

        printf " ║                ║   BLOCK HEIGHT ║  " && printf "%-${col_width_dgb_blockheight}s %19s %-3s\n" "$DGB2_BLOCKCOUNT_FORMATTED Blocks" "[ Synced: $DGB2_BLOCKSYNC_PERC% ]" " ║ "
        echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
        if [ $term_width -gt 121 ]; then 
            printf " ║                ║    NODE UPTIME ║  " && printf "%-${col_width_dgb_uptime_long}s %19s %-3s\n" "$dgb2_uptime" "[ Online Since: $dgb2_online_since ]" " ║ "
        else
            printf " ║                ║    NODE UPTIME ║  " && printf "%-${col_width_dgb_uptime}s %-3s\n" "$dgb2_uptime" " ║ "
        fi
        echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
        if grep -q ^"upnp=1" $DGB_CONF_FILE; then
            if [ $term_width -gt 99 ]; then 
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" "[ UPnP: Enabled ]" " ║ "
            else
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" " ║ "
            fi
        else
            if [ $term_width -gt 100 ]; then 
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" "[ UPnP: Disabled ]" " ║ "
            else
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" " ║ "
            fi
        fi

        # Only display the DigiByte wallet balance if the user (a) wants it displayed AND (b) the blockchain has finished syncing AND (c) the wallet actually contains any DGB
        if [ "$SM_DISPLAY_BALANCE" = "YES" ] && [ "$DGB2_BLOCKSYNC_PERC" = "100 " ] && [ "$DGB2_WALLET_BALANCE" != "" ]; then 
            echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
            printf " ║                ║ WALLET BALANCE ║  " && printf "%-${col_width_dgb_wallet_balance}s %-3s\n" "$DGB2_WALLET_BALANCE DGBT" " ║ "
        fi

        echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"

    fi

    if [ "$DGB2_STATUS" = "stopped" ]; then # Only display if secondary DigiByte Node is stopped running
        
        printf " ║ DIGIBYTE NODE  ║  NODE 2 STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbred}DigiByte TESTNET Node is not running.${txtrst}" " ║ "
        echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"
    fi

    if [ "$DGB2_STATUS" = "startingup" ]; then # Only display if secondary DigiByte Node (TESTNET) is starting up
        printf " ║ DIGIBYTE NODE  ║         STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbylw}DigiByte TESTNET Node is currently starting up.${txtrst}" " ║ "
        printf " ║ (TESTNET)      ║                ║  " && printf "%-14s %-${col_width_dgb_startingup}s %-3s\n" "Please wait..." "${txtbwht}$DGB2_ERROR_MSG${txtrst}" " ║ "

        echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
        if grep -q ^"upnp=1" $DGB_CONF_FILE; then
            if [ $term_width -gt 99 ]; then 
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" "[ UPnP: Enabled ]" " ║ "
            else
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" " ║ "
            fi
        else
            if [ $term_width -gt 100 ]; then 
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports_long}s %17s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" "[ UPnP: Disabled ]" " ║ "
            else
                printf " ║                ║          PORTS ║  " && printf "%-${col_width_dgb_ports}s %-3s\n" "Listening Port: ${DGB2_LISTEN_PORT}   RPC Port: $dgb2_rpcport_display" " ║ "
            fi
        fi
        echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"
    fi

fi

# STATUS MONITOR DASHBOARD - DIGIASSET NODE

if [ "$DGA_STATUS" = "running" ] && [ "$DGA_CONSOLE_QUERY" != "" ]; then
    format_dga_console

elif [ "$DGA_STATUS" = "stopped" ]; then
    printf " ║ DIGIASSET NODE ║         STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbred}DigiAsset Node is not running.${txtrst}" " ║ "
elif [ "$DGA_STATUS" = "not_detected" ]; then
    printf " ║ DIGIASSET NODE ║         STATUS ║  " && printf "%-${col_width_dgb_status}s %-3s\n" "${txtbred}DigiAsset Node not detected.${txtrst}" " ║ "
fi

echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"


# STATUS MONITOR DASHBOARD - SOFTWARE

### START DEBUGGING ###

#DGNT_UPDATE_AVAILABLE="yes"
#DGB_UPDATE_AVAILABLE="yes"
#DGB_PRERELEASE="YES"
#IPFS_UPDATE_AVAILABLE="yes"
#NODEJS_UPDATE_AVAILABLE="yes"
#NODEJS_VER_RELEASE="16.20.200"
#DGA_UPDATE_AVAILABLE="yes"

### END DEBUGGING ###


echo "$sm_row_06" # "╔" "═" "═" "═" "╦" "═" "╗"

if [ "$DGNT_UPDATE_AVAILABLE" = "yes" ]; then
    dgnt_upd_leftcol=" ║ SOFTWARE       ║  "
    dgnt_upd_maincol="DigiNode Tools $DGNT_VER_LOCAL_DISPLAY"

    if [ $term_width -gt 111 ]; then 
        dgnt_upd_rightcol="${dbcol_bgrn}Update Available: DigiNode Tools v$DGNT_VER_RELEASE${dbcol_rst}"
        db_content_c1_c2_c3f_c4 "$dgnt_upd_leftcol" "$dgnt_upd_maincol" "$dgnt_upd_rightcol"
    elif [ $term_width -gt 97 ]; then
        dgnt_upd_rightcol="${dbcol_bgrn}Update Available: v$DGNT_VER_RELEASE${dbcol_rst}"
        db_content_c1_c2_c3f_c4 "$dgnt_upd_leftcol" "$dgnt_upd_maincol" "$dgnt_upd_rightcol"
    else
        dgnt_upd_rightcol="${dbcol_bgrn}Update: v$DGNT_VER_RELEASE${dbcol_rst}"
        db_content_c1_c2_c3f_c4 "$dgnt_upd_leftcol" "$dgnt_upd_maincol" "$dgnt_upd_rightcol"
    fi
else
    printf " ║ SOFTWARE       ║  " && printf "%-${col_width_software_noupdate}s %-3s\n" "DigiNode Tools $DGNT_VER_LOCAL_DISPLAY" " ║ "
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$DGB_VER_LOCAL" != "" ]; then
    if [ "$DGB_UPDATE_AVAILABLE" = "yes" ]; then
        sw_upd_leftcol=" ║                ║  "
        if [ "$DGB_PRERELEASE" = "YES" ]; then

            if [ $term_width -gt 111 ]; then 
                dgb_upd_maincol="DigiByte Core v$DGB_VER_LOCAL (Pre-Release)"
                dgb_upd_rightcol="${dbcol_bgrn}Update Available: DigiByte Core v$DGB_VER_GITHUB${dbcol_rst}"
                db_content_c1_c2_c3f_c4 "$sw_upd_leftcol" "$dgb_upd_maincol" "$dgb_upd_rightcol"
            elif [ $term_width -gt 99 ]; then
                dgb_upd_maincol="DigiByte Core v$DGB_VER_LOCAL (Pre-Release)"
                dgb_upd_rightcol="${dbcol_bgrn}Update Available: v$DGB_VER_GITHUB${dbcol_rst}"
                db_content_c1_c2_c3f_c4 "$sw_upd_leftcol" "$dgb_upd_maincol" "$dgb_upd_rightcol"
            elif [ $term_width -gt 90 ]; then
                dgb_upd_maincol="DigiByte Core v$DGB_VER_LOCAL (Pre-Release)"
                dgb_upd_rightcol="${dbcol_bgrn}Update: v$DGB_VER_GITHUB${dbcol_rst}"
                db_content_c1_c2_c3f_c4 "$sw_upd_leftcol" "$dgb_upd_maincol" "$dgb_upd_rightcol"
            else
                dgb_upd_maincol="DigiByte Core v$DGB_VER_LOCAL (PR)"
                dgb_upd_rightcol="${dbcol_bgrn}Update: v$DGB_VER_GITHUB${dbcol_rst}"
                db_content_c1_c2_c3f_c4 "$sw_upd_leftcol" "$dgb_upd_maincol" "$dgb_upd_rightcol"
            fi    
        else   
            if [ $term_width -gt 111 ]; then 
                dgb_upd_maincol="DigiByte Core v$DGB_VER_LOCAL"
                dgb_upd_rightcol="${dbcol_bgrn}Update Available: DigiByte Core v$DGB_VER_GITHUB${dbcol_rst}"
                db_content_c1_c2_c3f_c4 "$sw_upd_leftcol" "$dgb_upd_maincol" "$dgb_upd_rightcol"
            elif [ $term_width -gt 97 ]; then
                dgb_upd_maincol="DigiByte Core v$DGB_VER_LOCAL"
                dgb_upd_rightcol="${dbcol_bgrn}Update Available: v$DGB_VER_GITHUB${dbcol_rst}"
                db_content_c1_c2_c3f_c4 "$sw_upd_leftcol" "$dgb_upd_maincol" "$dgb_upd_rightcol"
            else
                dgb_upd_maincol="DigiByte Core v$DGB_VER_LOCAL"
                dgb_upd_rightcol="${dbcol_bgrn}Update: v$DGB_VER_GITHUB${dbcol_rst}"
                db_content_c1_c2_c3f_c4 "$sw_upd_leftcol" "$dgb_upd_maincol" "$dgb_upd_rightcol"
            fi   
        fi
    else
        if [ "$DGB_PRERELEASE" = "YES" ]; then
            printf " ║                ║  " && printf "%-${col_width_software_noupdate}s %-3s\n" "DigiByte Core v$DGB_VER_LOCAL (Pre-Release)" " ║ "
        else
            printf " ║                ║  " && printf "%-${col_width_software_noupdate}s %-3s\n" "DigiByte Core v$DGB_VER_LOCAL" " ║ "
        fi
    fi
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$IPFS_VER_LOCAL" != "" ]; then
  if [ "$IPFS_UPDATE_AVAILABLE" = "yes" ]; then
    if [ $term_width -gt 111 ]; then 
        printf " ║                ║  " && printf "%-${col_width_software_kubo_wide}s %50s %-3s\n" "IPFS Kubo v$IPFS_VER_LOCAL" "[ ${txtbgrn}Update Available: IPFS Kubo v$IPFS_VER_RELEASE${txtrst} ]" " ║ "
    elif [ $term_width -gt 97 ]; then
        printf " ║                ║  " && printf "%-${col_width_software}s %35s %3s\n" "IPFS Kubo v$IPFS_VER_LOCAL" "[ ${txtbgrn}Update Available: v$IPFS_VER_RELEASE${txtrst} ]" " ║ "
    else
        printf " ║                ║  " && printf "%-${col_width_software_narrow}s %27s %3s\n" "IPFS Kubo v$IPFS_VER_LOCAL" "[ ${txtbgrn}Update: v$IPFS_VER_RELEASE${txtrst} ]" " ║ "
    fi
  else
    printf " ║                ║  " && printf "%-${col_width_software_noupdate}s %-3s\n" "IPFS Kubo v$IPFS_VER_LOCAL" " ║ "
  fi
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$NODEJS_VER_LOCAL" != "" ]; then
  if [ "$NODEJS_UPDATE_AVAILABLE" = "yes" ]; then
    if [ $term_width -gt 111 ]; then 
        printf " ║                ║  " && printf "%-${col_width_software_node_wide}s %50s %-3s\n" "NodeJS v$NODEJS_VER_LOCAL" "[ ${txtbgrn}Update Available: NodeJS v$NODEJS_VER_RELEASE${txtrst} ]" " ║ "
    elif [ $term_width -gt 97 ]; then
        printf " ║                ║  " && printf "%-${col_width_software_node}s %42s %3s\n" "NodeJS v$NODEJS_VER_LOCAL" "[ ${txtbgrn}Update Available: v$NODEJS_VER_RELEASE${txtrst} ]" " ║ "
    else
        printf " ║                ║  " && printf "%-${col_width_software_node_narrow}s %35s %3s\n" "NodeJS v$NODEJS_VER_LOCAL" "[ ${txtbgrn}Update: v$NODEJS_VER_RELEASE${txtrst} ]" " ║ "
    fi
  else
    printf " ║                ║  " && printf "%-${col_width_software_noupdate}s %-3s\n" "NodeJS v$NODEJS_VER_LOCAL" " ║ "
  fi
fi
# printf "  ║               ╠════════════════════════════════════════════════════╣\\n"
if [ "$DGA_VER_LOCAL" != "" ]; then
  if [ "$DGA_UPDATE_AVAILABLE" = "yes" ]; then
    if [ $term_width -gt 111 ]; then 
        printf " ║                ║  " && printf "%-${col_width_software_dga_wide}s %50s %-3s\n" "DigiAsset Node v$DGA_VER_LOCAL" "[ ${txtbgrn}Update Available: DigiAsset Node v$DGA_VER_RELEASE${txtrst} ]" " ║ "
    elif [ $term_width -gt 97 ]; then
        printf " ║                ║  " && printf "%-${col_width_software_dga}s %35s %3s\n" "DigiAsset Node v$DGA_VER_LOCAL" "[ ${txtbgrn}Update Available: v$DGA_VER_RELEASE${txtrst} ]" " ║ "
    else
        printf " ║                ║  " && printf "%-${col_width_software_dga_narrow}s %27s %3s\n" "DigiAsset Node v$DGA_VER_LOCAL" "[ ${txtbgrn}Update: v$DGA_VER_RELEASE${txtrst} ]" " ║ "
    fi
  else
    printf " ║                ║  " && printf "%-${col_width_software_noupdate}s %-3s\n" "DigiAsset Node v$DGA_VER_LOCAL" " ║ "
  fi
fi

echo "$sm_row_08" # "╚" "═" "╩" "═" "═" "═" "╝"


# Print empty line
# printf "%${term_width}s\n"



# STATUS MONITOR DASHBOARD - NETWORK - IP4 ADDRESS

# NETWORK DEBUGGING:
#IP4_EXTERNAL="OFFLINE"
#IP4_INTERNAL="OFFLINE"

echo "$sm_row_01" # "╔" "═" "╦" "═" "╦" "═" "╗"

ip4_leftcol=" ║ NETWORK        ║    IP4 ADDRESS ║  "
ip4_int_off_ext_off="Internal: ${dbcol_bred}$IP4_INTERNAL${dbcol_rst}   External: ${dbcol_bred}$IP4_EXTERNAL${dbcol_rst}"
ip4_int_on_ext_off="Internal: $IP4_INTERNAL   External: ${dbcol_bred}$IP4_EXTERNAL${dbcol_rst}"
ip4_int_off_ext_on="Internal: ${dbcol_bred}$IP4_INTERNAL${dbcol_rst}   External: $IP4_EXTERNAL"
ip4_int_on_ext_on="Internal: $IP4_INTERNAL   External: $IP4_EXTERNAL"

# Display IP4 addresses
if [ "$IP4_EXTERNAL" = "OFFLINE" ] && [ "$IP4_INTERNAL" = "OFFLINE" ]; then # Only display if there is no external IP i.e. we are offline
    db_content_c1_c2_c3f "$ip4_leftcol" "$ip4_int_off_ext_off"
elif [ "$IP4_EXTERNAL" = "OFFLINE" ]; then # Only display if there is no external IP i.e. we are offline
    db_content_c1_c2_c3f "$ip4_leftcol" "$ip4_int_on_ext_off"
elif [ "$IP4_INTERNAL" = "OFFLINE" ]; then # Only display if there is no external IP i.e. we are offline
    db_content_c1_c2_c3f "$ip4_leftcol" "$ip4_int_off_ext_on"
else
    db_content_c1_c2_c3f "$ip4_leftcol" "$ip4_int_on_ext_on"
fi


# STATUS MONITOR DASHBOARD - NETWORK - IP6 ADDRESS

if [ "$IP6_LINKLOCAL" != "" ] && [ "$IP6_GUA" != "" ]; then 

    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"

    # Setup IP6 display array
    ip6_leftcol=" ║                ║    IP6 ADDRESS ║  "
    ip6_leftcol2=" ║                ║                ║  "
    ip6_1st_part="Link-Local: ${IP6_LINKLOCAL:-unavailable}   GUA: ${IP6_GUA:-unavailable}"
    ip6_1st_part_width=${#ip6_1st_part}
    ip6_1st_part_l1="Link-Local: ${IP6_LINKLOCAL:-unavailable}"
    ip6_1st_part_l2="GUA: ${IP6_GUA:-unavailable}"

    # Display first IP6 part
    if [ $term_width -gt $(( ip6_1st_part_width + combined_col1_2_width + right_border_width )) ]; then
        db_content_c1_c2_c3f "$ip6_leftcol" "$ip6_1st_part"
    else
        db_content_c1_c2_c3f "$ip6_leftcol" "$ip6_1st_part_l1"
        db_content_c1_c2_c3f "$ip6_leftcol2" "$ip6_1st_part_l2"
    fi

    # If public IP6 is the same as GUA then remove it
    if [ "$IP6_GUA" = "$IP6_EXTERNAL" ]; then
        IP6_EXTERNAL=""
    fi

    # Setup ip6 second part if needed
    if [ "$IP6_EXTERNAL" != "" ] && [ "$IP6_ULA" != "" ]; then
        ip6_2nd_part="ULA: ${IP6_ULA}  External: ${IP6_EXTERNAL}"
        ip6_2nd_part_width=${#ip6_2nd_part}
        ip6_2nd_part_l1="External: ${IP6_EXTERNAL}"
        ip6_2nd_part_l2="ULA: $IP6_ULA"
        # Display second IP6 part
        if [ $term_width -gt $(( ip6_2nd_part_width + combined_col1_2_width + right_border_width )) ]; then
            db_content_c1_c2_c3f "$ip6_leftcol2" "$ip6_2nd_part"
        else
            db_content_c1_c2_c3f "$ip6_leftcol2" "$ip6_2nd_part_l1"
            db_content_c1_c2_c3f "$ip6_leftcol2" "$ip6_2nd_part_l2"
        fi
    elif [ "$IP6_EXTERNAL" != "" ]; then
        ip6_2nd_part="External: ${IP6_EXTERNAL}"
        db_content_c1_c2_c3f "$ip6_leftcol2" "$ip6_2nd_part"
    elif [ "$IP6_ULA" != "" ]; then
        ip6_2nd_part="ULA: $IP6_ULA"
        db_content_c1_c2_c3f "$ip6_leftcol2" "$ip6_2nd_part"
    fi

fi

echo "$sm_row_03" # "╠" "═" "╬" "═" "╬" "═" "╣"



# STATUS MONITOR DASHBOARD - SYSTEM - DEVICE

if [ "$MODEL" != "" ]; then

    col_1_2_text=" ║ SYSTEM         ║         DEVICE ║  "
    col3_text="$MODEL"
    col4_text="$MODELMEM RAM"
    db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"

fi


# STATUS MONITOR DASHBOARD - SYSTEM - DISK USAGE

# Display the section title, if the device was not displayed above
if [ "$MODEL" != "" ]; then
    col_1_2_text=" ║                ║     DISK USAGE ║  "
else
    col_1_2_text=" ║ SYSTEM         ║     DISK USAGE ║  "
fi

if [ "$DGB_DATA_DISKUSED_PERC_CLEAN" -ge "80" ]; then # Display current disk usage percentage in red if it is 80% or over
    col3_text="${DGB_DATA_DISKUSED_HR}b of ${DGB_DATA_DISKTOTAL_HR}b ( ${dbcol_bred}$DGB_DATA_DISKUSED_PERC${dbcol_rst} )"
    col4_text="${DGB_DATA_DISKFREE_HR}b free"
    db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
else
    col3_text="${DGB_DATA_DISKUSED_HR}b of ${DGB_DATA_DISKTOTAL_HR}b ( $DGB_DATA_DISKUSED_PERC )"
    col4_text="${DGB_DATA_DISKFREE_HR}b free"
    db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
fi

echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"


# STATUS MONITOR DASHBOARD - SYSTEM - MEMORY USAGE

col_1_2_text=" ║                ║   MEMORY USAGE ║  "
col3_text="${RAMUSED_HR}b of ${RAMTOTAL_HR}b"
col4_text="${RAMAVAIL_HR}b free"
db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"


# STATUS MONITOR DASHBOARD - SYSTEM - SWAP USAGE

if [ "$SWAPTOTAL_HR" != "0B" ] && [ "$SWAPTOTAL_HR" != "" ]; then # only display the swap file status if there is one, and the current value is above 0B
    col_1_2_text=" ║                ║     SWAP USAGE ║  "
    if [ "$SWAPUSED_HR" = "0B" ]; then # If swap used is 0B, drop the added b, used for Gb or Mb
        col3_text="${SWAPUSED_HR} of ${SWAPTOTAL_HR}b"
        col4_text="${SWAPAVAIL_HR}b free"
        db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
    else
        col3_text="${SWAPUSED_HR}b of ${SWAPTOTAL_HR}b"
        col4_text="${SWAPAVAIL_HR}b free"
        db_content_c1_c2_c3f_c4 "$col_1_2_text" "$col3_text" "$col4_text"
    fi  
    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"  
fi 


# STATUS MONITOR DASHBOARD - SYSTEM - CPU USAGE (Only displays with 12 cores or less)

if [ "$cpu_cores" -le 12 ]; then

    average_cpu_usage=90

    # Read CPU values from the temporary files (these are updated by a background process)
    cpu_usage_1=$(cat "$cpu1_file")
    cpu_usage_2=$(cat "$cpu2_file")
    average_cpu_usage=$(cat "$avg_file")

    # Setup CPU display array
    cpu_leftcol=" ║                ║      CPU USAGE ║  "
    cpu_leftcol2=" ║                ║                ║  "
    cpu_one_line="$cpu_usage_1$cpu_usage_2"
    cpu_one_line_width=${#cpu_one_line}
    cpu_one_line_l1="$cpu_usage_1"
    cpu_one_line_l2="$cpu_usage_2"
    if [ "$average_cpu_usage" -ge 80 ]; then
        cpu_total_perc="Total: ${dbcol_bred}${average_cpu_usage}%${dbcol_rst}"
    else
        cpu_total_perc="Total: ${average_cpu_usage}%"
    fi
    cpu_total_perc_width=${#cpu_total_perc}

    # Display first IP6 part
    if [ $term_width -gt $(( cpu_one_line_width + combined_col1_2_width + cpu_total_perc_width + right_border_width )) ]; then
        db_content_c1_c2_c3f_c4 "$cpu_leftcol" "$cpu_one_line" "$cpu_total_perc"
    else
        db_content_c1_c2_c3f_c4 "$cpu_leftcol" "$cpu_one_line_l1" "$cpu_total_perc"
        db_content_c1_c2_c3f "$cpu_leftcol2" "$cpu_one_line_l2"
    fi

    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"

fi


# STATUS MONITOR DASHBOARD - SYSTEM - TEMPERATURE

if [ "$temperature" != "" ]; then
    col_1_2_text=" ║                ║    TEMPERATURE ║  "
    col3_text="$TEMP_C °C     $TEMP_F °F"
    db_content_c1_c2_c3f "$col_1_2_text" "$col3_text"
    echo "$sm_row_04" # "║" " " "╠" "═" "╬" "═" "╣"
fi

# STATUS MONITOR DASHBOARD - SYSTEM - CLOCK
col_1_2_text=" ║                ║   SYSTEM CLOCK ║  "
col3_text="$TIME_NOW"
db_content_c1_c2_c3f "$col_1_2_text" "$col3_text"

echo "$sm_row_05" # "╚" "═" "╩" "═" "╩" "═" "╝"

# Print empty line
printf "%${term_width}s\n"


# STATUS MONITOR DASHBOARD - DIGIFACT

# Display a random DigiFact
if [ "$DGB_STATUS" = "running" ] && [ "$DGB_DUAL_NODE" = "NO" ] && [ $DGB_CONNECTIONS -ge 9 ]; then
    display_digifact_termwidth
elif [ "$DGB_STATUS" = "running" ] && [ "$DGB2_STATUS" = "running" ] && [ "$DGB_DUAL_NODE" = "YES" ] && [ $DGB_CONNECTIONS -ge 9 ] && [ $DGB2_CONNECTIONS -ge 9 ]; then
    display_digifact_termwidth
fi

if { [ "$DGB_STATUS" = "not_detected" ] || [ "$DGB_STATUS" = "stopped" ]; } && [ "$DGB_DUAL_NODE" = "NO" ]; then
    display_digifact_termwidth
elif { [ "$DGB_STATUS" = "not_detected" ] || [ "$DGB_STATUS" = "stopped" ]; } && [ "$DGB_DUAL_NODE" = "YES" ] && { [ "$DGB2_STATUS" = "not_detected" ] || [ "$DGB2_STATUS" = "stopped" ]; }; then
    display_digifact_termwidth
fi

# Print empty line
printf "%${term_width}s\n"


##########################################



# STATUS MONITOR DASHBOARD - QUIT MESSAGE

if [ "$IPFS_PORT_TEST_ENABLED" = "YES" ] && [ "$DGA_CONSOLE_QUERY" != "" ] && [ "$IPFS_PORT_NUMBER" != "" ] && [ "$IP4_EXTERNAL" != "OFFLINE" ] && [ "$IP4_EXTERNAL" != "" ]; then
    echo "$quit_messsage_with_port_test"
elif [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_STATUS" = "running" ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]; then
    echo "$quit_messsage_with_port_test"
elif [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_STATUS" = "running" ] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ]; then
    echo "$quit_messsage_with_port_test"
elif [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB2_STATUS" = "running" ] && [ "$DGB_DUAL_NODE" = "YES" ]; then
    echo "$quit_messsage_with_port_test"
else
    echo "$quit_message"
fi

#####################################
# Display TROUBLESHOOTING variables #
#####################################

if [ "$VERBOSE_MODE" = true ]; then

    TIME_DIF_10SEC_COUNTDOWN=$((10-$TIME_DIF_10SEC))
    TIME_DIF_1MIN_COUNTDOWN=$((60-$TIME_DIF_1MIN))
    TIME_DIF_15MIN_COUNTDOWN=$((900-$TIME_DIF_15MIN))
    TIME_DIF_1DAY_COUNTDOWN=$((86400-$TIME_DIF_1DAY))

    printf "%${term_width}s\n"
    printf "          ========= ${txtbylw}Troubleshooting (Verbose Mode)${txtrst} ========="  && tput el && printf "\\n" 
    printf "%${term_width}s\n"
    printf "                Terminal Width: $term_width" && tput el && printf "\\n" 
    printf "                    DGB_STATUS: $DGB_STATUS ($DGB_NETWORK_CURRENT)" && tput el && printf "\\n" 
    printf "%${term_width}s\n"
    printf "                   DGB2_STATUS: $DGB2_STATUS" && tput el && printf "\\n" 
    printf "%${term_width}s\n"
    printf "                DGB_PRERELEASE: $DGB_PRERELEASE" && tput el && printf "\\n" 
    printf "                 DGB_VER_LOCAL: $DGB_VER_LOCAL" && tput el && printf "\\n" 
    printf "%${term_width}s\n"
    printf "               DGB_VER_RELEASE: $DGB_VER_RELEASE" && tput el && printf "\\n" 
    printf "            DGB_VER_PRERELEASE: $DGB_VER_PRERELEASE" && tput el && printf "\\n" 
    printf "                DGB_VER_GITHUB: $DGB_VER_GITHUB" && tput el && printf "\\n" 
    printf "             dgb_update_status: $dgb_update_status" && tput el && printf "\\n" 
    printf "          DGB_UPDATE_AVAILABLE: $DGB_UPDATE_AVAILABLE" && tput el && printf "\\n" 
    printf "%${term_width}s\n"
    printf "                    DGA_STATUS: $DGA_STATUS" && tput el && printf "\\n" 
    printf "%${term_width}s\n"
#    printf "                TIME_DIF_10SEC: $TIME_DIF_10SEC_COUNTDOWN\\n"
#    printf "                 TIME_DIF_1MIN: $TIME_DIF_1MIN_COUNTDOWN\\n"
#    printf "                TIME_DIF_15MIN: $TIME_DIF_15MIN_COUNTDOWN\\n"
#    printf "                 TIME_DIF_1DAY: $TIME_DIF_1DAY_COUNTDOWN\\n"
#    printf "\\n"
#    printf "                 DGB_ERROR_MSG: $DGB_ERROR_MSG\\n"
    printf "       DGB_TROUBLESHOOTING_MSG: $DGB_TROUBLESHOOTING_MSG" && tput el && printf "\\n" 
    printf "%${term_width}s\n"
    printf "        DGB_BLOCKSYNC_PROGRESS: $DGB_BLOCKSYNC_PROGRESS" && tput el && printf "\\n" 
    printf "       DGB2_BLOCKSYNC_PROGRESS: $DGB2_BLOCKSYNC_PROGRESS" && tput el && printf "\\n" 
    printf "%${term_width}s\n"
    printf "           ==================================================" && tput el && printf "\\n\\n"
fi

tput ed

)

if [ "$STARTUP_LOOP" = true ]; then

    printf "%b Startup Loop Completed.\\n" "${INFO}"

    printf "\\n"

    # Log date of this Dashboard run to diginode.settings
    str="Logging date of this run to diginode.settings file..."
    printf "%b %s" "${INFO}" "${str}"
    sed -i -e "/^DGNT_MONITOR_LAST_RUN=/s|.*|DGNT_MONITOR_LAST_RUN=\"$(date)\"|" $DGNT_SETTINGS_FILE
    printf "%b%b %s Done!\\n" "${OVER}" "${TICK}" "${str}"
    printf "\\n"

    if [ "$STARTWAIT" = "yes" ]; then
        echo "               < Wait for 5 seconds >"
        sleep 5
    else 
        echo "               < Wait for 3 seconds >"
        sleep 3
    fi

    tput smcup
#   tput civis

    # Hide the cursor.
    printf '\e[?25l'

    # Disabling line wrapping.
    printf '\e[?7l'

    # Hide user input
    stty -echo

    STARTUP_LOOP=false

fi

# end output double buffer
if [ "$terminal_resized" = "no" ]; then
    change_tip="yes"
    echo "$output"
fi

# Display the quit message on exit
trap quit_message EXIT

# sleep 1
read -t 0.5 -s -n 1 input

    if [ "$IPFS_PORT_TEST_ENABLED" = "YES" ] && [ "$DGA_CONSOLE_QUERY" != "" ] && [ "$IPFS_PORT_NUMBER" != "" ] && [ "$IP4_EXTERNAL" != "OFFLINE" ] && [ "$IP4_EXTERNAL" != "" ]; then

        case "$input" in
            "P")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "p")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "Q")
                echo "Exiting..."
                exit
                ;;
            "q")
                echo "Exiting..."
                exit
                ;;
        esac

    elif [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_STATUS" = "running" ] && [ "$DGB_NETWORK_CURRENT" = "MAINNET" ] && [ "$IP4_EXTERNAL" != "OFFLINE" ] && [ "$IP4_EXTERNAL" != "" ]; then

        case "$input" in
            "P")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "p")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "Q")
                echo "Exiting..."
                exit
                ;;
            "q")
                echo "Exiting..."
                exit
                ;;
        esac

    elif [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_STATUS" = "running" ] && [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$IP4_EXTERNAL" != "OFFLINE" ] && [ "$IP4_EXTERNAL" != "" ]; then

        case "$input" in
            "P")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "p")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "Q")
                echo "Exiting..."
                exit
                ;;
            "q")
                echo "Exiting..."
                exit
                ;;
        esac

    elif [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB2_STATUS" = "running" ] && [ "$IP4_EXTERNAL" != "OFFLINE" ] && [ "$IP4_EXTERNAL" != "" ]; then

        case "$input" in
            "P")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "p")
                echo "Running Port test..."
                loopcounter=0
                port_test
                ;;
            "Q")
                echo "Exiting..."
                exit
                ;;
            "q")
                echo "Exiting..."
                exit
                ;;
        esac

    else

        case "$input" in
            "Q")
                echo "Exiting..."
                exit
                ;;
            "q")
                echo "Exiting..."
                exit
                ;;
        esac

    fi

# Any key press resets the loopcounter
if [ "${#input}" != 0 ]; then
    loopcounter=0
fi

done

}


# This will run the port test
port_test() {

clear -x

# scrape digibyte.conf
scrape_digibyte_conf

# query for digibyte network
query_digibyte_chain

# query for digibyte listening port
digibyte_port_query

echo -e "${txtbld}"
echo -e "            ____   _         _   _   __            __     "             
echo -e "           / __ \ (_)____ _ (_) / | / /____   ____/ /___   ${txtrst}╔════════╗${txtbld}"
echo -e "          / / / // // __ '// / /  |/ // __ \ / __  // _ \  ${txtrst}║  PORT  ║${txtbld}"
echo -e "         / /_/ // // /_/ // / / /|  // /_/ // /_/ //  __/  ${txtrst}║ TESTER ║${txtbld}"
echo -e "        /_____//_/ \__, //_/ /_/ |_/ \____/ \__,_/ \___/   ${txtrst}╚════════╝${txtbld}"
echo -e "                   /____/                                  ${txtrst}"                         
echo "" 
printf "  ╔════════════════════════════════════════════════════════════════════════════╗\\n"
printf "  ║                     ABOUT PORT FORWARDING                                  ║\\n"
printf "  ╠════════════════════════════════════════════════════════════════════════════╣\\n"
printf "  ║ For your DigiNode to work correctly you need to open the following ports   ║\\n"
printf "  ║ on your router so the that other nodes on the Internet can find it:        ║\\n"
printf "  ╠═══════════════════════════════╦════════════════════════════════════════════╣\\n"
printf "  ║ SOFTWARE                      ║ PORT                                       ║\\n"
if [ "$DGB_STATUS" = "running" ] || [ "$DGB_STATUS" = "startingup" ] || [ "$DGB_STATUS" = "stopped" ]; then
printf "  ╠═══════════════════════════════╬════════════════════════════════════════════╣\\n"
printf "  ║ DigiByte $DGB_NETWORK_CURRENT Node         ║ $DGB_LISTEN_PORT                                      ║\\n"
fi
if [ "$DGB2_STATUS" = "running" ] || [ "$DGB2_STATUS" = "startingup" ] || [ "$DGB2_STATUS" = "stopped" ]; then
printf "  ╠═══════════════════════════════╬════════════════════════════════════════════╣\\n"
printf "  ║ DigiByte TESTNET Node         ║ $DGB2_LISTEN_PORT                                      ║\\n"
fi
if [ "$DGA_STATUS" = "running" ]; then
printf "  ╠═══════════════════════════════╬════════════════════════════════════════════╣\\n"
printf "  ║ IPFS                          ║ " && printf "%-40s %-3s\n" "$IPFS_PORT_NUMBER" "  ║"
fi
printf "  ╠═══════════════════════════════╩════════════════════════════════════════════╣\\n"
printf "  ║ For help: " && printf "%-62s %-3s\n" "$DGBH_URL_PORTFWD" "  ║"
printf "  ╚════════════════════════════════════════════════════════════════════════════╝\\n"
echo ""

echo "                         Running Port Tests..."
echo ""

PORT_TEST_DATE=$(date)


# Setup DigiByte port test cammands


# Reset DigiByte mainnet node port test variables
DGB_MAINNET_PORT_TEST_QUERY_CMD=""
DGB_MAINNET_PORT_FWD_STATUS=""
DGB_MAINNET_PORT_TEST_USERAGENT=""
DGB_MAINNET_PORT_TEST_BLOCKCOUNT=""
DGB_MAINNET_PORT_TEST_ISP=""
DGB_MAINNET_PORT_TEST_COUNTRY=""
DGB_MAINNET_PORT_TEST_FIRSTONLINE=""

# Reset DigiByte testnet node port test variables
DGB_TESTNET_PORT_TEST_QUERY_CMD=""

# Reset other port test variables
display_port_test_credentials=""
display_port_forward_instructions=""

# Example Port Test URL: https://digibyteseed.com/api/node/?ip=123.123.123.123&port=12024&portscan=yes
# Example Query: curl --max-time 4 -sfL GET "https://digibyteseed.com/api/node/?ip=172.105.162.72&port=12024&portscan=yes" 2>/dev/null

DGB_PORT_TEST_URL="https://digibyteseed.com/api/node/"

# Setup DigiByte Port Test Query
DGB_PORT_TEST_QUERY_CMD_1="curl --max-time 4 -sfL GET \""
DGB_PORT_TEST_QUERY_CMD_2=$DGB_PORT_TEST_URL
DGB_PORT_TEST_QUERY_CMD_3="?ip="
DGB_PORT_TEST_QUERY_CMD_4=$IP4_EXTERNAL
DGB_PORT_TEST_QUERY_CMD_5="&port="

DGB_PORT_TEST_QUERY_CMD_7="&portscan=yes\" 2>/dev/null"

# Calculate DigiByte MAINNET query
if [ "$DGB_NETWORK_CURRENT" = "MAINNET" ]  && [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_LISTEN_PORT" != "" ]; then
    DGB_PORT_TEST_QUERY_CMD_6_MAINNET=$DGB_LISTEN_PORT
    DGB_MAINNET_PORT_TEST_QUERY_CMD="${DGB_PORT_TEST_QUERY_CMD_1}${DGB_PORT_TEST_QUERY_CMD_2}${DGB_PORT_TEST_QUERY_CMD_3}${DGB_PORT_TEST_QUERY_CMD_4}${DGB_PORT_TEST_QUERY_CMD_5}${DGB_PORT_TEST_QUERY_CMD_6_MAINNET}${DGB_PORT_TEST_QUERY_CMD_7}"
    DGB_MAINNET_LISTEN_PORT=$DGB_LISTEN_PORT
    DGB_MAINNET_CONNECTIONS=$DGB_CONNECTIONS
    DGB_MAINNET_STATUS=$DGB_STATUS
    if [ "$DGB_STATUS" = "running" ]; then
        DO_MAINNET_PORT_TEST="YES"
    fi
fi

# Calculate DigiByte TESTNET query (primary node)
if [ "$DGB_NETWORK_CURRENT" = "TESTNET" ] && [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB_LISTEN_PORT" != "" ]; then
    DGB_PORT_TEST_QUERY_CMD_6_TESTNET=$DGB_LISTEN_PORT
    DGB_TESTNET_PORT_TEST_QUERY_CMD="${DGB_PORT_TEST_QUERY_CMD_1}${DGB_PORT_TEST_QUERY_CMD_2}${DGB_PORT_TEST_QUERY_CMD_3}${DGB_PORT_TEST_QUERY_CMD_4}${DGB_PORT_TEST_QUERY_CMD_5}${DGB_PORT_TEST_QUERY_CMD_6_TESTNET}${DGB_PORT_TEST_QUERY_CMD_7}"
    DGB_TESTNET_LISTEN_PORT=$DGB_LISTEN_PORT
    DGB_TESTNET_CONNECTIONS=$DGB_CONNECTIONS
    DGB_TESTNET_STATUS=$DGB_STATUS
    if [ "$DGB_STATUS" = "running" ]; then
        DO_TESTNET_PORT_TEST="YES"
    fi
fi

# Calculate DigiByte TESTNET query (secondary node)
if [ "$DGB_DUAL_NODE" = "YES" ] && [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ] && [ "$DGB2_LISTEN_PORT" != "" ]; then
    DGB_PORT_TEST_QUERY_CMD_6_TESTNET=$DGB2_LISTEN_PORT
    DGB_TESTNET_PORT_TEST_QUERY_CMD="${DGB_PORT_TEST_QUERY_CMD_1}${DGB_PORT_TEST_QUERY_CMD_2}${DGB_PORT_TEST_QUERY_CMD_3}${DGB_PORT_TEST_QUERY_CMD_4}${DGB_PORT_TEST_QUERY_CMD_5}${DGB_PORT_TEST_QUERY_CMD_6_TESTNET}${DGB_PORT_TEST_QUERY_CMD_7}"
    DGB_TESTNET_LISTEN_PORT=$DGB2_LISTEN_PORT
    DGB_TESTNET_CONNECTIONS=$DGB2_CONNECTIONS
    DGB_TESTNET_STATUS=$DGB2_STATUS
    if [ "$DGB2_STATUS" = "running" ]; then
        DO_TESTNET_PORT_TEST="YES"
    fi
fi



# Perform a DigiByte MAINNET port test
if [ "$DO_MAINNET_PORT_TEST" = "YES" ]; then

    str="Is DigiByte MAINNET listening port $DGB_MAINNET_LISTEN_PORT OPEN? ... "
    printf "%b %s" "${INFO}" "${str}" 

    # Query DigiByte Port tester - http://digibyteseed.com
    DGB_MAINNET_PORT_TEST_QUERY=$(eval $DGB_MAINNET_PORT_TEST_QUERY_CMD) 

    # Check for port test error
    DGB_MAINNET_PORT_TEST_QUERY_ERROR=$(echo $DGB_MAINNET_PORT_TEST_QUERY | grep -Eo "error")
    if [ "$DGB_MAINNET_PORT_TEST_QUERY" = "error" ] || [ "$DGB_MAINNET_PORT_TEST_QUERY" = "" ]; then
        DGB_MAINNET_PORT_FWD_STATUS="TEST_ERROR"
    fi

    DGB_MAINNET_PORT_TEST_QUERY_ID=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .id | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_NETWORK=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .network | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_PORTSTATUS=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .port_status | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_USERAGENT=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .user_agent | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_BLOCKCOUNT=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .blocks | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_ISP=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .isp | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_COUNTRY=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .country | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_FIRSTONLINE=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .first_online | sed 's/"//g')
    DGB_MAINNET_PORT_TEST_QUERY_SERVERTIME=$(echo $DGB_MAINNET_PORT_TEST_QUERY | jq .server_time | sed 's/"//g')

    # Check network and capitalize
    if [ "$DGB_MAINNET_PORT_TEST_QUERY_NETWORK" != "" ]; then
        DGB_MAINNET_PORT_TEST_NETWORK=$(echo $DGB_MAINNET_PORT_TEST_QUERY_NETWORK | tr '[:lower:]' '[:upper:]')
    fi

    # Port test - IS port open?
    if [ "$DGB_MAINNET_PORT_TEST_QUERY_PORTSTATUS" = "open" ]; then
        DGB_MAINNET_PORT_FWD_STATUS="OPEN"
    elif [ "$DGB_MAINNET_PORT_TEST_QUERY_PORTSTATUS" = "close" ] || [ "$DGB_MAINNET_PORT_TEST_QUERY_PORTSTATUS" = "closed" ]; then
        DGB_MAINNET_PORT_FWD_STATUS="CLOSED" 
    elif [ "$DGB_MAINNET_PORT_TEST_QUERY_PORTSTATUS" = "unavailable" ]; then
        DGB_MAINNET_PORT_FWD_STATUS="TEST_ERROR"
    elif [ "$DGB_MAINNET_PORT_TEST_QUERY_PORTSTATUS" = "" ]; then
        DGB_MAINNET_PORT_FWD_STATUS="TEST_ERROR"
    fi

    # Port test - get user agent
    if [ "$DGB_MAINNET_PORT_TEST_QUERY_USERAGENT" != "" ]; then
        DGB_MAINNET_PORT_TEST_USERAGENT=$DGB_MAINNET_PORT_TEST_QUERY_USERAGENT
    fi

    if [ "$DGB_MAINNET_PORT_TEST_QUERY_BLOCKCOUNT" != "" ]; then
        DGB_MAINNET_PORT_TEST_BLOCKCOUNT=$(printf "%'d" $DGB_MAINNET_PORT_TEST_QUERY_BLOCKCOUNT)
    fi

    # Port test - Get ISP
    if [ "$DGB_MAINNET_PORT_TEST_QUERY_ISP" != "" ]; then
        DGB_MAINNET_PORT_TEST_ISP=$DGB_MAINNET_PORT_TEST_QUERY_ISP
    fi

    # Port test - Get Country
    if [ "$DGB_MAINNET_PORT_TEST_QUERY_COUNTRY" != "" ]; then
        DGB_MAINNET_PORT_TEST_COUNTRY=$(get_country_name "$DGB_MAINNET_PORT_TEST_QUERY_COUNTRY")
    fi

    # Port test - Get first online
    if [ "$DGB_MAINNET_PORT_TEST_QUERY_FIRSTONLINE" != "" ]; then
        DGB_MAINNET_PORT_TEST_FIRSTONLINE="$DGB_MAINNET_PORT_TEST_QUERY_FIRSTONLINE UTC"
        first_online_local_time=$(date -d "$DGB_MAINNET_PORT_TEST_FIRSTONLINE")
        if [ "$first_online_local_time" != "" ]; then
            DGB_MAINNET_PORT_TEST_FIRSTONLINE=$first_online_local_time
        fi
    fi

    # Port test - Get server time
    if [ "$DGB_MAINNET_PORT_TEST_QUERY_SERVERTIME" != "" ]; then
        DGB_MAINNET_PORT_TEST_SERVERTIME="$DGB_MAINNET_PORT_TEST_QUERY_SERVERTIME UTC"
        server_local_time=$(date -d "$DGB_MAINNET_PORT_TEST_SERVERTIME")
        if [ "$server_local_time" != "" ]; then
            DGB_MAINNET_PORT_TEST_SERVERTIME=$server_local_time
        fi
    fi


    if [ "$DGB_MAINNET_PORT_FWD_STATUS" = "OPEN" ]; then

        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}" 
        printf "\\n" 
        printf "%b ${txtbgrn}Success! Port $DGB_MAINNET_LISTEN_PORT is OPEN.${txtrst}\\n" "${INDENT}"
        printf "\\n" 
        printf "%b DigiByte $DGB_MAINNET_PORT_TEST_NETWORK Node found at IP address $IP4_EXTERNAL:\\n" "${INDENT}"
        printf "\\n" 
        if [ "$DGB_MAINNET_PORT_TEST_USERAGENT" != "" ]; then
            printf "%b        Version:  DigiByte Core v${DGB_MAINNET_PORT_TEST_USERAGENT}\\n" "${INDENT}"
        fi
        if [ "$DGB_MAINNET_PORT_TEST_BLOCKCOUNT" != "" ]; then
            printf "%b   Block Height:  $DGB_MAINNET_PORT_TEST_BLOCKCOUNT\\n" "${INDENT}"
        fi
        if [ "$DGB_MAINNET_PORT_TEST_ISP" != "" ]; then
            printf "%b            ISP:  $DGB_MAINNET_PORT_TEST_ISP\\n" "${INDENT}"
        fi
        if [ "$DGB_MAINNET_PORT_TEST_COUNTRY" != "" ]; then
            printf "%b        Country:  $DGB_MAINNET_PORT_TEST_COUNTRY\\n" "${INDENT}"
        fi
        if [ "$DGB_MAINNET_PORT_TEST_FIRSTONLINE" != "" ]; then
            printf "%b   First Online:  $DGB_MAINNET_PORT_TEST_FIRSTONLINE\\n" "${INDENT}"
        fi
        if [ "$DGB_MAINNET_PORT_TEST_FIRSTONLINE" = "" ] && [ "$DGB_MAINNET_PORT_TEST_SERVERTIME" != "" ]; then
            printf "%b   Server Time:  $DGB_MAINNET_PORT_TEST_SERVERTIME\\n" "${INDENT}"
        fi
        printf "\\n"



        sed -i -e "/^DGB_MAINNET_PORT_FWD_STATUS=/s|.*|DGB_MAINNET_PORT_FWD_STATUS=\"$DGB_MAINNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE          
        DGB_MAINNET_PORT_TEST_ENABLED="NO"
        sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
        DGB_MAINNET_PORT_TEST_PASS_DATE=$PORT_TEST_DATE
        sed -i -e "/^DGB_MAINNET_PORT_TEST_PASS_DATE=/s|.*|DGB_MAINNET_PORT_TEST_PASS_DATE=\"$DGB_MAINNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_TEST_EXTERNAL_IP=$IP4_EXTERNAL
        sed -i -e "/^DGB_MAINNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_MAINNET_PORT_TEST_EXTERNAL_IP=\"$DGB_MAINNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_NUMBER_SAVED=$DGB_LISTEN_PORT
        sed -i -e "/^DGB_MAINNET_PORT_NUMBER_SAVED=/s|.*|DGB_MAINNET_PORT_NUMBER_SAVED=\"$DGB_MAINNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE
        printf "\\n"  

        display_port_test_credentials="yes"

    elif [ "$DGB_MAINNET_PORT_FWD_STATUS" = "CLOSED" ]; then

        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}" 
        printf "\\n" 
        printf "%b ${txtbred}Fail! Port $DGB_MAINNET_LISTEN_PORT is CLOSED.${txtrst}\\n" "${INDENT}"
        printf "\\n"   

        DGB_MAINNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_FWD_STATUS="CLOSED"
        sed -i -e "/^DGB_MAINNET_PORT_FWD_STATUS=/s|.*|DGB_MAINNET_PORT_FWD_STATUS=\"$DGB_MAINNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_TEST_PASS_DATE=""
        sed -i -e "/^DGB_MAINNET_PORT_TEST_PASS_DATE=/s|.*|DGB_MAINNET_PORT_TEST_PASS_DATE=|" $DGNT_SETTINGS_FILE
        DGB_MAINNET_PORT_MAINNET_TEST_EXTERNAL_IP=""
        sed -i -e "/^DGB_MAINNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_MAINNET_PORT_TEST_EXTERNAL_IP=\"$DGB_MAINNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

        display_port_test_credentials="yes"
        display_port_forward_instructions="yes"

    elif [ "$DGB_MAINNET_PORT_FWD_STATUS" = "TEST_ERROR" ]; then

        if [ $DGB_MAINNET_CONNECTIONS -gt 10 ]; then    

            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"  
            printf "\\n"
            printf "%b ${txtbgrn}Success! Port $DGB_MAINNET_LISTEN_PORT is OPEN.${txtrst}\\n" "${INDENT}"
            printf "\\n" 
            printf "%b NOTE: The port testing service is currently unavailable. However,\\n" "${INFO}"
            printf "%b       you currently have more that 10 connections to other nodes which\\n" "${INDENT}"
            printf "%b       means that port $DGB_MAINNET_LISTEN_PORT is likely open.\\n" "${INDENT}"
            printf "\\n"

            DGB_MAINNET_PORT_TEST_ENABLED="NO"
            sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
            DGB_MAINNET_PORT_FWD_STATUS="OPEN"
            sed -i -e "/^DGB_MAINNET_PORT_FWD_STATUS=/s|.*|DGB_MAINNET_PORT_FWD_STATUS=\"$DGB_MAINNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_TEST_PASS_DATE=$PORT_TEST_DATE
            sed -i -e "/^DGB_MAINNET_PORT_TEST_PASS_DATE=/s|.*|DGB_MAINNET_PORT_TEST_PASS_DATE=\"$DGB_MAINNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_TEST_EXTERNAL_IP=$IP4_EXTERNAL
            sed -i -e "/^DGB_MAINNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_MAINNET_PORT_TEST_EXTERNAL_IP=\"$DGB_MAINNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_NUMBER_SAVED=$DGB_LISTEN_PORT
            sed -i -e "/^DGB_MAINNET_PORT_NUMBER_SAVED=/s|.*|DGB_MAINNET_PORT_NUMBER_SAVED=\"$DGB_MAINNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE
        
        else

            printf "%b%b %s POSSIBLY NOT!\\n" "${OVER}" "${WARN}" "${str}"
            printf "\\n" 
            printf "%b NOTE: The port testing service is currently unavailable. Your connection count \\n" "${INFO}"
            printf "%b       is also currently 8 or lower so it is not possible to determine if\\n" "${INDENT}"
            printf "%b       port $DGB_MAINNET_LISTEN_PORT is open or not. Try running the test again later.\\n" "${INDENT}"
            printf "\\n"

            DGB_MAINNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_MAINNET_PORT_TEST_ENABLED=/s|.*|DGB_MAINNET_PORT_TEST_ENABLED=\"$DGB_MAINNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_FWD_STATUS="CLOSED"
            sed -i -e "/^DGB_MAINNET_PORT_FWD_STATUS=/s|.*|DGB_MAINNET_PORT_FWD_STATUS=\"$DGB_MAINNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_MAINNET_TEST_PASS_DATE=""
            sed -i -e "/^DGB_MAINNET_PORT_TEST_PASS_DATE=/s|.*|DGB_MAINNET_PORT_TEST_PASS_DATE=|" $DGNT_SETTINGS_FILE
            DGB_MAINNET_PORT_MAINNET_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_MAINNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_MAINNET_PORT_TEST_EXTERNAL_IP=\"$DGB_MAINNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

            display_port_forward_instructions="yes"

        fi

    fi

elif [ "$DGB_MAINNET_STATUS" = "startingup" ] && [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is DigiByte MAINNET listening port $DGB_MAINNET_LISTEN_PORT open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b ${txtbylw}Your DigiByte MAINNET Node is in the process of starting up.${txtrst}\\n" "${INDENT}"
        printf "%b ${txtbylw}Try again in a few minutes...${txtrst}\\n" "${INDENT}"
        printf "\\n"

elif [ "$DGB_MAINNET_STATUS" = "stopped" ] && [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is DigiByte MAINNET listening port $DGB_MAINNET_LISTEN_PORT open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b Your DigiByte MAINNET Node is not running.\\n" "${INDENT}"
        printf "\\n"

elif [ "$DGB_MAINNET_PORT_TEST_ENABLED" = "NO" ]; then

        str="Is DigiByte MAINNET listening port $DGB_MAINNET_LISTEN_PORT open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b ${txtbgrn}Port $DGB_MAINNET_LISTEN_PORT is OPEN. You have already passed this test.${txtrst}\\n" "${INDENT}"
        printf "\\n"

fi

# Perform a DigiByte TESTNET port test
if [ "$DO_TESTNET_PORT_TEST" = "YES" ]; then

    str="Is DigiByte TESTNET listening port $DGB_TESTNET_LISTEN_PORT OPEN? ... "
    printf "%b %s" "${INFO}" "${str}" 

    # Query DigiByte Port tester - http://digibyteseed.com
    DGB_TESTNET_PORT_TEST_QUERY=$(eval $DGB_TESTNET_PORT_TEST_QUERY_CMD) 

    # Check for port test error
    DGB_TESTNET_PORT_TEST_QUERY_ERROR=$(echo $DGB_TESTNET_PORT_TEST_QUERY | grep -Eo "error")
    if [ "$DGB_TESTNET_PORT_TEST_QUERY" = "error" ] || [ "$DGB_TESTNET_PORT_TEST_QUERY" = "" ]; then
        DGB_TESTNET_PORT_FWD_STATUS="TEST_ERROR"
    fi

    DGB_TESTNET_PORT_TEST_QUERY_ID=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .id | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_NETWORK=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .network | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_PORTSTATUS=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .port_status | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_USERAGENT=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .user_agent | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_BLOCKCOUNT=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .blocks | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_ISP=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .isp | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_COUNTRY=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .country | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_FIRSTONLINE=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .first_online | sed 's/"//g')
    DGB_TESTNET_PORT_TEST_QUERY_SERVERTIME=$(echo $DGB_TESTNET_PORT_TEST_QUERY | jq .server_time | sed 's/"//g')

    # Check network and capitalize
    if [ "$DGB_TESTNET_PORT_TEST_QUERY_NETWORK" != "" ]; then
        DGB_TESTNET_PORT_TEST_NETWORK=$(echo $DGB_TESTNET_PORT_TEST_QUERY_NETWORK | tr '[:lower:]' '[:upper:]')
    fi

    # Port test - IS port open?
    if [ "$DGB_TESTNET_PORT_TEST_QUERY_PORTSTATUS" = "open" ]; then
        DGB_TESTNET_PORT_FWD_STATUS="OPEN"
    elif [ "$DGB_TESTNET_PORT_TEST_QUERY_PORTSTATUS" = "close" ] || [ "$DGB_TESTNET_PORT_TEST_QUERY_PORTSTATUS" = "closed" ]; then
        DGB_TESTNET_PORT_FWD_STATUS="CLOSED" 
    elif [ "$DGB_TESTNET_PORT_TEST_QUERY_PORTSTATUS" = "unavailable" ]; then
        DGB_TESTNET_PORT_FWD_STATUS="TEST_ERROR"
    elif [ "$DGB_TESTNET_PORT_TEST_QUERY_PORTSTATUS" = "" ]; then
        DGB_TESTNET_PORT_FWD_STATUS="TEST_ERROR"
    fi

    # Port test - get user agent
    if [ "$DGB_TESTNET_PORT_TEST_QUERY_USERAGENT" != "" ]; then
        DGB_TESTNET_PORT_TEST_USERAGENT=$DGB_TESTNET_PORT_TEST_QUERY_USERAGENT
    fi

    if [ "$DGB_TESTNET_PORT_TEST_QUERY_BLOCKCOUNT" != "" ]; then
        DGB_TESTNET_PORT_TEST_BLOCKCOUNT=$(printf "%'d" $DGB_TESTNET_PORT_TEST_QUERY_BLOCKCOUNT)
    fi

    # Port test - Get ISP
    if [ "$DGB_TESTNET_PORT_TEST_QUERY_ISP" != "" ]; then
        DGB_TESTNET_PORT_TEST_ISP=$DGB_TESTNET_PORT_TEST_QUERY_ISP
    fi

    # Port test - Get Country
    if [ "$DGB_TESTNET_PORT_TEST_QUERY_COUNTRY" != "" ]; then
        DGB_TESTNET_PORT_TEST_COUNTRY=$(get_country_name "$DGB_TESTNET_PORT_TEST_QUERY_COUNTRY")
    fi

    # Port test - Get first online
    if [ "$DGB_TESTNET_PORT_TEST_QUERY_FIRSTONLINE" != "" ]; then
        DGB_TESTNET_PORT_TEST_FIRSTONLINE="$DGB_TESTNET_PORT_TEST_QUERY_FIRSTONLINE UTC"
        first_online_local_time=$(date -d "$DGB_TESTNET_PORT_TEST_FIRSTONLINE")
        if [ "$first_online_local_time" != "" ]; then
            DGB_TESTNET_PORT_TEST_FIRSTONLINE=$first_online_local_time
        fi
    fi

    # Port test - Get server time
    if [ "$DGB_TESTNET_PORT_TEST_QUERY_SERVERTIME" != "" ]; then
        DGB_TESTNET_PORT_TEST_SERVERTIME="$DGB_TESTNET_PORT_TEST_QUERY_SERVERTIME UTC"
        server_local_time=$(date -d "$DGB_TESTNET_PORT_TEST_SERVERTIME")
        if [ "$server_local_time" != "" ]; then
            DGB_TESTNET_PORT_TEST_SERVERTIME=$server_local_time
        fi
    fi


    if [ "$DGB_TESTNET_PORT_FWD_STATUS" = "OPEN" ]; then

        printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}" 
        printf "\\n" 
        printf "%b ${txtbgrn}Success! Port $DGB_TESTNET_LISTEN_PORT is OPEN.${txtrst}\\n" "${INDENT}"
        printf "\\n" 
        printf "%b DigiByte $DGB_TESTNET_PORT_TEST_NETWORK Node found at IP address $IP4_EXTERNAL:\\n" "${INDENT}"
        printf "\\n" 
        if [ "$DGB_TESTNET_PORT_TEST_USERAGENT" != "" ]; then
            printf "%b        Version:  DigiByte Core v${DGB_TESTNET_PORT_TEST_USERAGENT}\\n" "${INDENT}"
        fi
        if [ "$DGB_TESTNET_PORT_TEST_BLOCKCOUNT" != "" ]; then
            printf "%b   Block Height:  $DGB_TESTNET_PORT_TEST_BLOCKCOUNT\\n" "${INDENT}"
        fi
        if [ "$DGB_TESTNET_PORT_TEST_ISP" != "" ]; then
            printf "%b            ISP:  $DGB_TESTNET_PORT_TEST_ISP\\n" "${INDENT}"
        fi
        if [ "$DGB_TESTNET_PORT_TEST_COUNTRY" != "" ]; then
            printf "%b        Country:  $DGB_TESTNET_PORT_TEST_COUNTRY\\n" "${INDENT}"
        fi
        if [ "$DGB_TESTNET_PORT_TEST_FIRSTONLINE" != "" ]; then
            printf "%b   First Online:  $DGB_TESTNET_PORT_TEST_FIRSTONLINE\\n" "${INDENT}"
        fi
        if [ "$DGB_TESTNET_PORT_TEST_FIRSTONLINE" = "" ] && [ "$DGB_TESTNET_PORT_TEST_SERVERTIME" != "" ]; then
            printf "%b   Server Time:  $DGB_TESTNET_PORT_TEST_SERVERTIME\\n" "${INDENT}"
        fi
        printf "\\n"



        sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE          
        DGB_TESTNET_PORT_TEST_ENABLED="NO"
        sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
        DGB_TESTNET_PORT_TEST_PASS_DATE=$PORT_TEST_DATE
        sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=\"$DGB_TESTNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_TEST_EXTERNAL_IP=$IP4_EXTERNAL
        sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_NUMBER_SAVED=$DGB_LISTEN_PORT
        sed -i -e "/^DGB_TESTNET_PORT_NUMBER_SAVED=/s|.*|DGB_TESTNET_PORT_NUMBER_SAVED=\"$DGB_TESTNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE
        printf "\\n"  

        display_port_test_credentials="yes"

    elif [ "$DGB_TESTNET_PORT_FWD_STATUS" = "CLOSED" ]; then

        printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}" 
        printf "\\n" 
        printf "%b ${txtbred}Fail! Port $DGB_TESTNET_LISTEN_PORT is CLOSED.${txtrst}\\n" "${INDENT}"
        printf "\\n"   

        DGB_TESTNET_PORT_TEST_ENABLED="YES"
        sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_FWD_STATUS="CLOSED"
        sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_TEST_PASS_DATE=""
        sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=|" $DGNT_SETTINGS_FILE
        DGB_TESTNET_PORT_TESTNET_TEST_EXTERNAL_IP=""
        sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

        display_port_test_credentials="yes"
        display_port_forward_instructions="yes"

    elif [ "$DGB_TESTNET_PORT_FWD_STATUS" = "TEST_ERROR" ]; then

        if [ $DGB_TESTNET_CONNECTIONS -gt 10 ]; then    

            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"  
            printf "\\n"
            printf "%b ${txtbgrn}Success! Port $DGB_TESTNET_LISTEN_PORT is OPEN.${txtrst}\\n" "${INDENT}"
            printf "\\n" 
            printf "%b NOTE: The port testing service is currently unavailable. However,\\n" "${INFO}"
            printf "%b       you currently have more that 10 connections to other nodes which\\n" "${INDENT}"
            printf "%b       means that port $DGB_TESTNET_LISTEN_PORT is likely open.\\n" "${INDENT}"
            printf "\\n"

            DGB_TESTNET_PORT_TEST_ENABLED="NO"
            sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
            DGB_TESTNET_PORT_FWD_STATUS="OPEN"
            sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_PASS_DATE=$PORT_TEST_DATE
            sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=\"$DGB_TESTNET_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TEST_EXTERNAL_IP=$IP4_EXTERNAL
            sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_NUMBER_SAVED=$DGB_LISTEN_PORT
            sed -i -e "/^DGB_TESTNET_PORT_NUMBER_SAVED=/s|.*|DGB_TESTNET_PORT_NUMBER_SAVED=\"$DGB_TESTNET_PORT_NUMBER_SAVED\"|" $DGNT_SETTINGS_FILE
        
        else

            printf "%b%b %s POSSIBLY NOT!\\n" "${OVER}" "${WARN}" "${str}"
            printf "\\n" 
            printf "%b NOTE: The port testing service is currently unavailable. Your connection count \\n" "${INFO}"
            printf "%b       is also currently 8 or lower so it is not possible to determine if\\n" "${INDENT}"
            printf "%b       port $DGB_TESTNET_LISTEN_PORT is open or not. Try running the test again later.\\n" "${INDENT}"
            printf "\\n"

            DGB_TESTNET_PORT_TEST_ENABLED="YES"
            sed -i -e "/^DGB_TESTNET_PORT_TEST_ENABLED=/s|.*|DGB_TESTNET_PORT_TEST_ENABLED=\"$DGB_TESTNET_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_FWD_STATUS="CLOSED"
            sed -i -e "/^DGB_TESTNET_PORT_FWD_STATUS=/s|.*|DGB_TESTNET_PORT_FWD_STATUS=\"$DGB_TESTNET_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TESTNET_TEST_PASS_DATE=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_PASS_DATE=/s|.*|DGB_TESTNET_PORT_TEST_PASS_DATE=|" $DGNT_SETTINGS_FILE
            DGB_TESTNET_PORT_TESTNET_TEST_EXTERNAL_IP=""
            sed -i -e "/^DGB_TESTNET_PORT_TEST_EXTERNAL_IP=/s|.*|DGB_TESTNET_PORT_TEST_EXTERNAL_IP=\"$DGB_TESTNET_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

            display_port_forward_instructions="yes"

        fi

    fi

elif [ "$DGB_TESTNET_STATUS" = "startingup" ] && [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is DigiByte TESTNET listening port $DGB_TESTNET_LISTEN_PORT open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b ${txtbylw}Your DigiByte TESTNET Node is in the process of starting up.${txtrst}\\n" "${INDENT}"
        printf "%b ${txtbylw}Try again in a few minutes...${txtrst}\\n" "${INDENT}"
        printf "\\n"

elif [ "$DGB_TESTNET_STATUS" = "stopped" ] && [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is DigiByte TESTNET listening port $DGB_TESTNET_LISTEN_PORT open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b Your DigiByte TESTNET Node is not running.\\n" "${INDENT}"
        printf "\\n"

elif [ "$DGB_TESTNET_PORT_TEST_ENABLED" = "NO" ]; then

        str="Is DigiByte TESTNET listening port $DGB_TESTNET_LISTEN_PORT open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b ${txtbgrn}Port $DGB_TESTNET_LISTEN_PORT is OPEN. You have already passed this test.${txtrst}\\n" "${INDENT}"
        printf "\\n"

fi


# Display Port Test Credits
if [ "$display_port_test_credentials" = "yes" ]; then
       printf "%b DigiByte Port Test provided by: https://digibyteseed.com\\n" "${INFO}"
       printf "\\n"
fi

# Display DigiByte Port Forwarding instructions
if [ "$display_port_forward_instructions" = "yes" ] && [ "$DGB_DUAL_NODE" = "YES" ] && [ "$DGB_MAINNET_PORT_FWD_STATUS" = "CLOSED" ] && [ "$DGB_TESTNET_PORT_FWD_STATUS" = "CLOSED" ]; then

    printf "\\n"
    printf "%b IMPORTANT: For other DigiByte Nodes on the network to find yours, you need\\n" "${INFO}"
    printf "%b to forward ports $DGB_LISTEN_PORT ($DGB_NETWORK_CURRENT) and $DGB2_LISTEN_PORT (TESTNET) on your router. If not, the number of\\n" "${INDENT}"
    printf "%b potential inbound connections for each node is limited to around 8. For help, visit:\\n" "${INDENT}"
    printf "%b $DGBH_URL_PORTFWD\\n" "${INDENT}"
    printf "\\n"  

elif [ "$display_port_forward_instructions" = "yes" ] && [ "$DGB_DUAL_NODE" = "NO" ] && [ "$DGB_MAINNET_PORT_FWD_STATUS" = "CLOSED" ]; then

    printf "\\n"
    printf "%b IMPORTANT: For other DigiByte Nodes on the mainnet network to find this one, you need\\n" "${INFO}"
    printf "%b to forward port $DGB_MAINNET_LISTEN_PORT on your router. If not, the number of potential inbound\\n" "${INDENT}"
    printf "%b connections is limited to 8. For help, visit:\\n" "${INDENT}"
    printf "%b $DGBH_URL_PORTFWD\\n" "${INDENT}"
    printf "\\n"   

elif [ "$display_port_forward_instructions" = "yes" ] && [ "$DGB_DUAL_NODE" = "NO" ] && [ "$DGB_TESTNET_PORT_FWD_STATUS" = "CLOSED" ]; then

    printf "\\n"
    printf "%b IMPORTANT: For other DigiByte Nodes on the testnet network to find this one, you need\\n" "${INFO}"
    printf "%b to forward port $DGB_TESTNET_LISTEN_PORT on your router. If not, the number of potential inbound\\n" "${INDENT}"
    printf "%b connections is limited to 8. For help, visit:\\n" "${INDENT}"
    printf "%b $DGBH_URL_PORTFWD\\n" "${INDENT}"
    printf "\\n"
fi



if [ "$DGA_STATUS" = "running" ] && [ "$IPFS_PORT_TEST_ENABLED" = "YES" ]; then

    str="Is IPFS port $IPFS_PORT_NUMBER OPEN? ... "
    printf "%b %s" "${INFO}" "${str}" 

    IPFS_PORT_TEST_QUERY=$(curl --max-time 10 localhost:8090/api/digiassetX/ipfs/check.json 2>/dev/null)

    if [ $? -eq 0 ]; then

        if [ "$IPFS_PORT_TEST_QUERY" = "true" ]; then
            printf "%b%b %s YES!\\n" "${OVER}" "${TICK}" "${str}"  
            printf "\\n"
            printf "%b ${txtbgrn}Success! Port $IPFS_PORT_NUMBER is OPEN.${txtrst}\\n" "${INDENT}"
            printf "\\n"

            IPFS_PORT_TEST_ENABLED="NO"
            sed -i -e "/^IPFS_PORT_TEST_ENABLED=/s|.*|IPFS_PORT_TEST_ENABLED=\"$IPFS_PORT_TEST_ENABLED\"|" $DGNT_SETTINGS_FILE 
            IPFS_PORT_FWD_STATUS="OPEN"
            sed -i -e "/^IPFS_PORT_FWD_STATUS=/s|.*|IPFS_PORT_FWD_STATUS=\"$IPFS_PORT_FWD_STATUS\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_PASS_DATE=$PORT_TEST_DATE
            sed -i -e "/^IPFS_PORT_TEST_PASS_DATE=/s|.*|IPFS_PORT_TEST_PASS_DATE=\"$IPFS_PORT_TEST_PASS_DATE\"|" $DGNT_SETTINGS_FILE
            IPFS_PORT_TEST_EXTERNAL_IP=$IP4_EXTERNAL
            sed -i -e "/^IPFS_PORT_TEST_EXTERNAL_IP=/s|.*|IPFS_PORT_TEST_EXTERNAL_IP=\"$IPFS_PORT_TEST_EXTERNAL_IP\"|" $DGNT_SETTINGS_FILE

            sed -i -e "/^IPFS_PORT_NUMBER_SAVED=/s|.*|IPFS_PORT_NUMBER_SAVED=\"$IPFS_PORT_NUMBER\"|" $DGNT_SETTINGS_FILE
        fi

        if [ "$IPFS_PORT_TEST_QUERY" = "false" ]; then
            printf "%b%b %s NO!\\n" "${OVER}" "${CROSS}" "${str}" 
            printf "\\n" 
            printf "%b ${txtbred}Fail! Port $IPFS_PORT_NUMBER is CLOSED.${txtrst}\\n" "${INDENT}"
            printf "\\n"   

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
        printf "%b %b ERROR! Response timed out. Is DigiAsset Node running?%b\\n" "${OVER}" "${CROSS}" "${str}" 
    fi

elif [ "$DGA_STATUS" = "stopped" ] && [ "$IPFS_PORT_TEST_ENABLED" = "YES" ]; then

        str="Is IPFS port $IPFS_PORT_NUMBER open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b Your DigiAsset Node is not running.\\n" "${INDENT}"
        printf "\\n"

elif [ "$IPFS_PORT_TEST_ENABLED" = "NO" ]; then

        str="Is IPFS port $IPFS_PORT_NUMBER open? ... "
        printf "%b %s" "${INFO}" "${str}" 

        printf "%b%b %s TEST SKIPPED!\\n" "${OVER}" "${SKIP}" "${str}"  
        printf "\\n"
        printf "%b ${txtbgrn}Port $IPFS_PORT_NUMBER is OPEN. You have already passed this test.${txtrst}\\n" "${INDENT}"
        printf "\\n"

fi

echo ""
echo ""

read -t 60 -n 1 -s -r -p "            < Press any key to return to the Status Monitor >"

clear -x

loopcounter=0

status_loop

}


######################################################
######### PERFORM STARTUP CHECKS #####################
######################################################

startup_checks() {

  # Note: Some of these functions are found in the diginode-setup.sh file

  display_help                     # Display the help screen if the --help or -h flags have been used 
  flag_commands                    # Run a command via a launch flag
  digimon_title_box                # Clear screen and display title box
# digimon_disclaimer               # Display disclaimer warning during development. Pause for confirmation.
  get_script_location              # Find which folder this script is running in (in case this is an unnoficial DigiNode)
  import_setup_functions           # Import diginode-setup.sh file because it contains functions we need
  diginode_tools_import_settings   # Import diginode.settings file
  diginode_logo_v3                 # Display DigiNode logo
  is_verbose_mode                  # Display a message if Verbose Mode is enabled
  set_text_editor                  # Set the system text editor
  sys_check                        # Perform basic OS check - is this Linux? Is it 64bit?
  rpi_check                        # Look for Raspberry Pi hardware. If found, only continue if it is compatible.
  set_sys_variables                # Set various system variables once we know we are on linux
  diginode_tools_create_settings   # Create diginode.settings file (if it does not exist)
  diginode_tools_update_settings   # Update the diginode.settings file if there is a new version
  swap_check                       # if this system has 4Gb or less RAM, check there is a swap drive
  digibyte_check_official          # check if this is an official install of DigiByte Core
  is_dgbnode_installed             # Run checks to see if DigiByte Node is present. Exit if it isn't. Import digibyte.conf.
  digiasset_check_official         # check if this is an official install of DigiAsset Node
  is_dganode_installed             # Run checks to see if DigiAsset Node is present. Warn if it isn't.
  is_wallet_enabled                # Check that the DigiByte Core wallet is enabled
  check_dgb_rpc_credentials        # Check the RPC username and password from digibyte.conf file. Warn if not present.
  is_avahi_installed               # Check if avahi-daemon is installed
  is_jq_installed                  # Check if jq is installed
  is_sysstat_installed             # Check if sysstat is installed
  install_required_pkgs            # Install jq and sysstat
  download_digifacts               # Download the digifacts.json file from Github
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



#!/bin/bash
#
#            Name:  DigiNode Raspberry Pi Helper
#
#         Purpose:  Warns you if your Raspberry Pi is short of power (under-voltage), has got too hot and slowed
#                   itself down, or (on a Raspberry Pi 5) has limited the power to its USB ports. Prints nothing
#                   when everything is fine, or when this isn't a Raspberry Pi.
#
#          Author:  Olly Stedall @saltedlolly
#
#         Website:  https://diginode.tools
#
#         Install:  DigiNode Setup installs this file to /usr/local/sbin/diginode-pi and replaces it whenever
#                   DigiNode Tools is updated, so do not edit it there.
#
#           Usage:  diginode-pi --status   Print any warnings (shown by DigiNode Setup, DigiNode Dashboard and the
#                                          DigiNode MOTD). Prints nothing otherwise.
#                   diginode-pi --flags    Print one line for DigiNode Dashboard: power=ok|now|earlier
#                                          heat=ok|now|earlier usb=ok|limited
#
#                   Doesn't need root: the Raspberry Pi's warning flags can be read by any user.
#
# -----------------------------------------------------------------------------------------------------

txtbld=$(tput bold 2>/dev/null)
txtrst=$(tput sgr0 2>/dev/null)
COL_NC='\e[0m'
COL_LIGHT_RED='\e[1;31m'
COL_YELLOW='\e[1;33m'
COL_BOLD_WHITE='\e[1;37m'
WARN="  [${COL_LIGHT_RED}!${COL_NC}]"
INDENT="     "

# For testing only: read the files below from this folder instead of /
R="${DGNT_PI_TEST_ROOT:-}"

# The model, e.g. "Raspberry Pi 4 Model B Rev 1.4" (empty if this isn't a Raspberry Pi)
pi_model() {
    local model
    model=$(tr -d '\0' < "$R/proc/device-tree/model" 2>/dev/null)
    case "$model" in
        "Raspberry Pi"*) echo "$model" ;;
    esac
}

# The warning flags, as a number (from the Raspberry Pi firmware). Empty if they can't be read.
#   bit 0  under-voltage now          bit 16  under-voltage since it started
#   bit 1  CPU speed capped now       bit 17  CPU speed capped since it started
#   bit 2  throttled now              bit 18  throttled since it started
#   bit 3  soft temperature limit now bit 19  soft temperature limit since it started
pi_throttled() {
    local value
    value=$(cat "$R/sys/devices/platform/soc/soc:firmware/get_throttled" 2>/dev/null)   # hex, without 0x
    if [[ "$value" =~ ^[0-9a-fA-F]{1,8}$ ]]; then
        echo $(( 16#$value ))
        return
    fi
    value=$(vcgencmd get_throttled 2>/dev/null)                                      # throttled=0x50005
    value=${value#throttled=0x}
    if [[ "$value" =~ ^[0-9a-fA-F]{1,8}$ ]]; then
        echo $(( 16#$value ))
    fi
}

# A number from the device tree (stored as a 4-byte big-endian value). Empty if it isn't there.
dt_u32() {
    local value
    value=$(od -An -tx1 -N4 "$1" 2>/dev/null | tr -d ' \n')
    [[ "$value" =~ ^[0-9a-f]{8}$ ]] && echo $(( 16#$value ))
}

# Exit 0 if a Raspberry Pi 5 has limited its USB ports to 600mA (its power supply didn't say it can give 5A) and a
# USB drive is plugged in (an NVMe drive or SD card isn't affected).
pi5_usb_limited() {
    local max_current usb_max
    case "$(pi_model)" in
        "Raspberry Pi 5"*|"Raspberry Pi 500"*|"Raspberry Pi Compute Module 5"*) ;;
        * ) return 1 ;;
    esac
    max_current=$(dt_u32 "$R/proc/device-tree/chosen/power/max_current")
    usb_max=$(dt_u32 "$R/proc/device-tree/chosen/power/usb_max_current_enable")
    [ -n "$max_current" ] && [ -n "$usb_max" ] || return 1
    [ "$max_current" -lt 5000 ] && [ "$usb_max" -eq 0 ] || return 1
    lsblk -dno TRAN 2>/dev/null | grep -qx usb
}

# Work out what to warn about: POWER, HEAT = ok | now | earlier; USB = ok | limited
get_flags() {
    local t
    POWER=ok; HEAT=ok; USB=ok
    [ -n "$(pi_model)" ] || return
    t=$(pi_throttled)
    if [ -n "$t" ]; then
        # Short of power
        if (( t & 0x1 )); then POWER=now; elif (( t & 0x10000 )); then POWER=earlier; fi
        # Too hot: the soft temperature limit, or the CPU slowed down while the power was fine
        if (( t & 0x8 )) || { (( t & 0x6 )) && ! (( t & 0x1 )); }; then
            HEAT=now
        elif (( t & 0x80000 )) || { (( t & 0x60000 )) && ! (( t & 0x10000 )); }; then
            HEAT=earlier
        fi
    fi
    pi5_usb_limited && USB=limited
}

# The official power supply for this model
power_supply() {
    case "$(pi_model)" in
        "Raspberry Pi 5"*|"Raspberry Pi 500"*) echo "the official Raspberry Pi 27W USB-C Power Supply" ;;
        "Raspberry Pi 4"*|"Raspberry Pi 400"*) echo "the official Raspberry Pi 15W USB-C Power Supply" ;;
        * ) echo "the official Raspberry Pi power supply" ;;
    esac
}

print_status() {
    local temp
    get_flags

    if [ "$POWER" = "now" ]; then
        printf "%b %bYour Raspberry Pi is short of power right now (under-voltage).%b\\n" "${WARN}" "${COL_LIGHT_RED}" "${COL_NC}"
    elif [ "$POWER" = "earlier" ]; then
        printf "%b %bYour Raspberry Pi has been short of power since it started (under-voltage).%b\\n" "${WARN}" "${COL_YELLOW}" "${COL_NC}"
    fi
    if [ "$POWER" != "ok" ]; then
        printf "%b This can damage your SSD and your blockchain data. Please use\\n" "${INDENT}"
        printf "%b %s.\\n" "${INDENT}" "$(power_supply)"
        printf "\\n"
    fi

    if [ "$USB" = "limited" ]; then
        printf "%b %bYour Raspberry Pi 5 has limited the power to its USB ports.%b\\n" "${WARN}" "${COL_YELLOW}" "${COL_NC}"
        printf "%b Its power supply isn't the official 27W one, so USB drives can only draw\\n" "${INDENT}"
        printf "%b 600mA, which may not be enough for your SSD. Please use\\n" "${INDENT}"
        printf "%b %s.\\n" "${INDENT}" "$(power_supply)"
        printf "\\n"
    fi

    if [ "$HEAT" != "ok" ]; then
        temp=$(cat "$R/sys/class/thermal/thermal_zone0/temp" 2>/dev/null)
        [[ "$temp" =~ ^[0-9]+$ ]] && temp=" ($(( temp / 1000 )) °C now)" || temp=""
        if [ "$HEAT" = "now" ]; then
            printf "%b %bYour Raspberry Pi is too hot and is slowing itself down%s.%b\\n" "${WARN}" "${COL_LIGHT_RED}" "$temp" "${COL_NC}"
        else
            printf "%b %bYour Raspberry Pi got too hot earlier and slowed itself down%s.%b\\n" "${WARN}" "${COL_YELLOW}" "$temp" "${COL_NC}"
        fi
        printf "%b Please check its cooling: a case with a fan or a heatsink keeps it cool.\\n" "${INDENT}"
        printf "\\n"
    fi
}

case "$1" in
    --status ) print_status; exit 0 ;;
    --flags  ) get_flags; echo "power=$POWER heat=$HEAT usb=$USB"; exit 0 ;;
    * )
        echo "Usage: diginode-pi --status | --flags"
        exit 1
        ;;
esac

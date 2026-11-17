#!/bin/bash
#
#            Name:  DigiNode Raspberry Pi Helper
#
#         Purpose:  Warns you if your Raspberry Pi is short of power (under-voltage), has got too hot and slowed
#                   itself down, or (on a Raspberry Pi 5) has limited the power to its USB ports. Prints nothing
#                   when everything is fine, or when this isn't a Raspberry Pi. Also keeps the Raspberry Pi
#                   bootloader up to date, if you chose automatic bootloader updates.
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
#                   diginode-pi --daily    Update the Raspberry Pi bootloader, if it is safe to (run as root by
#                                          diginode-pi.timer - see "Bootloader (EEPROM) updates" below)
#                   diginode-pi --eeprom-pending   Exit 0 if a bootloader update is waiting for a restart, and say
#                                          which (used by diginode-reboot)
#                   diginode-pi --eeprom-version   Print the running bootloader's date, e.g. 30 Oct 2026
#
#                   Only --daily needs root: the Raspberry Pi's warning flags can be read by any user.
#
# -----------------------------------------------------------------------------------------------------

txtbld=$(tput bold 2>/dev/null)
txtrst=$(tput sgr0 2>/dev/null)
COL_NC='\e[0m'
COL_LIGHT_RED='\e[1;31m'
COL_YELLOW='\e[1;33m'
COL_BOLD_WHITE='\e[1;37m'
WARN="  [${COL_LIGHT_RED}!${COL_NC}]"
INFO="  [${COL_BOLD_WHITE}i${COL_NC}]"
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
        if grep -qx 'SKIPPED=power' "$EEPROM_STATUS" 2>/dev/null; then
            printf "%b Automatic bootloader updates are paused until then.\\n" "${INDENT}"
        fi
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

# ---- Bootloader (EEPROM) updates ----------------------------------------------------------------------
#
# The Raspberry Pi 4 and 5 have a bootloader stored on the board (in an EEPROM), which starts the Pi. Raspberry Pi
# releases updates to it in the rpi-eeprom package, and Raspberry Pi OS installs a newer one when the Pi starts.
# Automatic system updates don't update rpi-eeprom (DigiNode Setup keeps it out of unattended-upgrades): this
# helper does, once a day, run by diginode-pi.timer (only when SYSTEM_EEPROM_UPDATES=AUTO in diginode.settings):
#   1. never while the Pi has been short of power since it started (a power cut while the bootloader is written
#      can stop the Pi starting), or while the DigiNode is busy (diginode-reboot --busy)
#   2. update the rpi-eeprom package, then prepare the new bootloader with rpi-eeprom-update -a (only the stable
#      "default" releases, as set in /etc/default/rpi-eeprom-update)
#   3. the bootloader is written at the next restart (a Pi 5 may write it straight away, but it still only starts
#      using it after a restart), so diginode-reboot counts it as needing a restart
# What it finds is kept in EEPROM_STATUS (root's own file - this never writes to the user's diginode.settings).

EEPROM_STATUS="$R/var/lib/diginode-tools/eeprom.status"

# Exit 0 if this Raspberry Pi has a bootloader EEPROM that rpi-eeprom-update can update
eeprom_supported() {
    case "$(pi_model)" in
        "Raspberry Pi 4"*|"Raspberry Pi 400"*|"Raspberry Pi 5"*|"Raspberry Pi 500"*|"Raspberry Pi Compute Module 4"*|"Raspberry Pi Compute Module 5"*) ;;
        * ) return 1 ;;
    esac
    command -v rpi-eeprom-update >/dev/null 2>&1
}

# The running bootloader's release time (seconds since 1970), e.g. 1793402435. Empty if unknown.
eeprom_running() {
    local ts
    ts=$(vcgencmd bootloader_version 2>/dev/null | awk '$1 == "timestamp" { print $2; exit }')
    [[ "$ts" =~ ^[0-9]{9,11}$ ]] && echo "$ts"
}

# The newest bootloader in the installed rpi-eeprom package, from rpi-eeprom-update's "LATEST: ... (1739293213)"
eeprom_latest() {
    local ts
    ts=$(rpi-eeprom-update 2>/dev/null | awk '/^BOOTLOADER/ { on = 1 } on && /LATEST:/ { if (match($0, /\(([0-9]+)\)/)) print substr($0, RSTART + 1, RLENGTH - 2); exit }')
    [[ "$ts" =~ ^[0-9]{9,11}$ ]] && echo "$ts"
}

# A release time as a date, e.g. 30 Oct 2026 (the way Raspberry Pi names bootloader releases)
eeprom_date() {
    date -u -d "@$1" '+%-d %b %Y' 2>/dev/null
}

# Read the status file (numbers and a short reason only - it is never sourced)
load_eeprom_status() {
    local key value
    PENDING=; FROM=; UPDATED_TO=; UPDATED_FROM=; UPDATED_AT=; SKIPPED=
    [ -r "$EEPROM_STATUS" ] || return 0
    while IFS='=' read -r key value; do
        case "$key" in
            PENDING|FROM|UPDATED_TO|UPDATED_FROM|UPDATED_AT) [[ "$value" =~ ^[0-9]{0,11}$ ]] && printf -v "$key" '%s' "$value" ;;
            SKIPPED) [[ "$value" =~ ^[a-z]{0,10}$ ]] && SKIPPED="$value" ;;
        esac
    done < "$EEPROM_STATUS"
}

save_eeprom_status() {
    mkdir -p "$(dirname "$EEPROM_STATUS")"
    printf 'PENDING=%s\nFROM=%s\nUPDATED_TO=%s\nUPDATED_FROM=%s\nUPDATED_AT=%s\nSKIPPED=%s\n' \
        "$PENDING" "$FROM" "$UPDATED_TO" "$UPDATED_FROM" "$UPDATED_AT" "$SKIPPED" > "$EEPROM_STATUS.new" \
        && chmod 644 "$EEPROM_STATUS.new" && mv -f "$EEPROM_STATUS.new" "$EEPROM_STATUS"
}

# If a prepared bootloader update is now running, record it as installed
eeprom_reconcile() {
    local running
    [ -n "$PENDING" ] || return 0
    running=$(eeprom_running)
    if [ -n "$running" ] && [ "$running" -ge "$PENDING" ]; then
        UPDATED_TO="$running"; UPDATED_FROM="$FROM"; UPDATED_AT=$(date +%s)
        PENDING=; FROM=
    fi
}

# Run once a day (and a few minutes after starting) by diginode-pi.timer, as root
eeprom_daily() {
    local running latest
    [ "$(id -u)" = "0" ] || { echo "diginode-pi --daily must be run as root"; return 1; }
    eeprom_supported || return 0

    load_eeprom_status
    eeprom_reconcile

    get_flags
    if [ "$POWER" != "ok" ]; then
        SKIPPED=power
        save_eeprom_status
        echo "Skipped: the Raspberry Pi has been short of power since it started"
        return 0
    fi
    if [ -x /usr/local/sbin/diginode-reboot ] && reason=$(/usr/local/sbin/diginode-reboot --busy); then
        save_eeprom_status
        echo "Skipped: $reason"
        return 0
    fi
    SKIPPED=

    # Update just the rpi-eeprom package (keeping any changes made to /etc/default/rpi-eeprom-update)
    export DEBIAN_FRONTEND=noninteractive
    apt-get -qq -o DPkg::Lock::Timeout=600 update >/dev/null 2>&1
    apt-get -qq -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confold install --only-upgrade -y rpi-eeprom >/dev/null 2>&1

    running=$(eeprom_running)
    latest=$(eeprom_latest)
    if [ -n "$running" ] && [ -n "$latest" ] && [ "$latest" -gt "$running" ] && [ "$latest" != "$PENDING" ]; then
        if rpi-eeprom-update -a >/dev/null 2>&1; then
            PENDING="$latest"; FROM="$running"
            echo "Prepared bootloader update: $(eeprom_date "$running") -> $(eeprom_date "$latest") (installed at the next restart)"
        else
            echo "rpi-eeprom-update -a failed"
        fi
    fi
    save_eeprom_status
}

# For diginode-reboot: exit 0 and say why, if a prepared bootloader update is waiting for a restart
eeprom_pending() {
    local running
    load_eeprom_status
    [ -n "$PENDING" ] || return 1
    running=$(eeprom_running)
    [ -n "$running" ] && [ "$running" -ge "$PENDING" ] && return 1
    echo "a Raspberry Pi bootloader update ($(eeprom_date "$PENDING")) is waiting to be installed"
}

# Bootloader messages for --status: an update installed in the last 7 days, or updates paused by low power
print_eeprom_status() {
    eeprom_supported || return 0
    load_eeprom_status
    eeprom_reconcile
    if [ -n "$UPDATED_AT" ] && [ $(( $(date +%s) - UPDATED_AT )) -lt 604800 ]; then
        if [ -n "$UPDATED_FROM" ]; then
            printf "%b Your Raspberry Pi's bootloader was updated to %s (it was %s).\\n" "${INFO}" "$(eeprom_date "$UPDATED_TO")" "$(eeprom_date "$UPDATED_FROM")"
        else
            printf "%b Your Raspberry Pi's bootloader was updated to %s.\\n" "${INFO}" "$(eeprom_date "$UPDATED_TO")"
        fi
        printf "\\n"
    fi
}

case "$1" in
    --status ) print_status; print_eeprom_status; exit 0 ;;
    --flags  ) get_flags; echo "power=$POWER heat=$HEAT usb=$USB"; exit 0 ;;
    --daily  ) eeprom_daily; exit $? ;;
    --eeprom-pending ) eeprom_pending; exit $? ;;
    --eeprom-version )
        # The running bootloader's date, e.g. 30 Oct 2026 (empty if unknown)
        eeprom_supported && running=$(eeprom_running) && eeprom_date "$running"
        exit 0
        ;;
    * )
        echo "Usage: diginode-pi --status | --flags | --daily | --eeprom-pending | --eeprom-version"
        exit 1
        ;;
esac

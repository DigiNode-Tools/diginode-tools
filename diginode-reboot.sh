#!/bin/bash
#
#            Name:  DigiNode Reboot Helper
#
#         Purpose:  Checks whether this DigiNode needs to restart to finish installing system updates (e.g. a new
#                   Linux kernel), and reminds you. If automatic restarts are enabled, it restarts the DigiNode at
#                   a quiet time - but never while it is busy. If it is busy, the restart is skipped and tried again.
#
#          Author:  Olly Stedall @saltedlolly
#
#         Website:  https://diginode.tools
#
#         Install:  DigiNode Setup installs this file to /usr/local/sbin/diginode-reboot and replaces it whenever
#                   DigiNode Tools is updated, so do not edit it there. To turn automatic restarts on or off, or to
#                   change the time, run 'diginode-setup' and choose System from the main menu.
#
#           Usage:  diginode-reboot --check    Exit 0 if a restart is required, and print the reason
#                   diginode-reboot --busy     Exit 0 if the DigiNode is busy, and print why
#                   diginode-reboot --status   Print a reminder if a restart is required (shown by DigiNode Setup,
#                                              DigiNode Dashboard and the DigiNode MOTD). Prints nothing otherwise.
#                   diginode-reboot --auto     Run by diginode-reboot.timer: restart if required and not busy
#
# -----------------------------------------------------------------------------------------------------

STATUS_DIR=/var/lib/diginode-tools
STATUS_FILE=$STATUS_DIR/reboot.status      # Written by this script (as root): skipped restarts, last restart
CONF_FILE=$STATUS_DIR/auto-reboot.conf     # Written by DigiNode Setup: AUTO_REBOOT=YES|NO and AUTO_REBOOT_TIME=HH:MM

# DigiNode Setup is only counted as busy if it started within this many seconds. A setup left open at a prompt
# (e.g. in a forgotten terminal) would otherwise stop the DigiNode ever restarting.
SETUP_BUSY_MAX_AGE=21600   # 6 hours

# A skipped restart only counts as another skipped night if the last one counted was at least this long ago
# (the timer tries several times each night)
SKIP_COUNT_GAP=43200       # 12 hours

txtbld=$(tput bold 2>/dev/null)
txtrst=$(tput sgr0 2>/dev/null)
COL_NC='\e[0m'
COL_BOLD_WHITE='\e[1;37m'
COL_LIGHT_GREEN='\e[1;32m'
INFO="  [${COL_BOLD_WHITE}i${COL_NC}]"
INDENT="     "

# Load the automatic restart settings and the status of previous restarts (if any)
load_status() {
    AUTO_REBOOT=NO
    AUTO_REBOOT_TIME=04:00
    PENDING_SINCE=
    SKIP_COUNT=0
    LAST_SKIP_COUNTED=
    LAST_SKIP_REASON=
    REBOOTED_FOR=
    LAST_AUTO_REBOOT=
    [ -r "$CONF_FILE" ] && . "$CONF_FILE"
    [ -r "$STATUS_FILE" ] && . "$STATUS_FILE"
}

# Save the status (values are quoted with %q, so the file is always safe to source)
save_status() {
    mkdir -p "$STATUS_DIR"
    {
        echo "# Written by diginode-reboot. Do not edit."
        printf 'PENDING_SINCE=%q\n' "$PENDING_SINCE"
        printf 'SKIP_COUNT=%q\n' "$SKIP_COUNT"
        printf 'LAST_SKIP_COUNTED=%q\n' "$LAST_SKIP_COUNTED"
        printf 'LAST_SKIP_REASON=%q\n' "$LAST_SKIP_REASON"
        printf 'REBOOTED_FOR=%q\n' "$REBOOTED_FOR"
        printf 'LAST_AUTO_REBOOT=%q\n' "$LAST_AUTO_REBOOT"
    } > "$STATUS_FILE.tmp" && chmod 644 "$STATUS_FILE.tmp" && mv -f "$STATUS_FILE.tmp" "$STATUS_FILE"
}

# Print why a restart is required and return 0, or return 1 if it isn't
reboot_required_reason() {

    # Set by Ubuntu (and some Debian packages) when an update needs a restart
    if [ -f /var/run/reboot-required ]; then
        echo "system updates were installed that need a restart"
        return 0
    fi

    # The running kernel has been removed (its modules are gone)
    local running
    running=$(uname -r)
    if [ ! -d "/lib/modules/$running" ]; then
        echo "the Linux kernel was updated"
        return 0
    fi

    # A newer kernel of the same type is installed, e.g. 6.12.47+rpt-rpi-v8 while running 6.6.51+rpt-rpi-v8.
    # (A Raspberry Pi has several types installed, e.g. rpi-v8 and rpi-2712, so only compare the same type.)
    # Only count kernels that are actually installed (have both a kernel image and modules).
    local flavour newest
    flavour="${running##*-}"
    newest=$(ls -1 /boot 2>/dev/null | sed -n 's/^vmlinuz-//p' | grep -- "-${flavour}\$" | while read -r k; do
                 [ -d "/lib/modules/$k" ] && echo "$k"
             done | sort -V | tail -1)
    if [ -n "$newest" ] && [ "$newest" != "$running" ] && [ "$(printf '%s\n%s\n' "$running" "$newest" | sort -V | tail -1)" = "$newest" ]; then
        echo "a new Linux kernel was installed ($newest)"
        return 0
    fi

    # Fedora
    if command -v needs-restarting >/dev/null 2>&1; then
        if ! needs-restarting -r >/dev/null 2>&1; then
            echo "system updates were installed that need a restart"
            return 0
        fi
    fi

    return 1
}

# Print why the DigiNode is busy and return 0, or return 1 if it isn't busy.
# Being busy can only ever skip a restart - nothing here waits or asks a question.
busy_reason() {

    # DigiNode Setup is running (it may be installing, backing up, restoring or deleting blockchain data)
    local pid age
    for pid in $(pgrep -f "diginode-setup.sh" 2>/dev/null); do
        age=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -n "$age" ] && [ "$age" -lt "$SETUP_BUSY_MAX_AGE" ]; then
            echo "DigiNode Setup is running"
            return 0
        fi
    done

    # Software is being installed (apt/dpkg)
    if command -v fuser >/dev/null 2>&1 && fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock >/dev/null 2>&1; then
        echo "software is being installed"
        return 0
    fi
    if systemctl is-active --quiet apt-daily-upgrade.service 2>/dev/null || systemctl is-active --quiet dnf-automatic.service 2>/dev/null; then
        echo "system updates are being installed"
        return 0
    fi

    # A DigiByte node is starting up or shutting down
    local svc state
    for svc in digibyted digibyted-testnet; do
        state=$(systemctl is-active "$svc" 2>/dev/null)
        if [ "$state" = "activating" ]; then
            echo "a DigiByte node is starting up"
            return 0
        elif [ "$state" = "deactivating" ]; then
            echo "a DigiByte node is shutting down"
            return 0
        fi
    done

    # Something has asked for the DigiNode not to be shut down: a systemd "block" inhibitor lock for shutdown,
    # e.g. taken with: systemd-inhibit --what=shutdown --who="My task" --why="Doing something" <command>
    # These locks are released automatically when the program holding them exits, so they can't get stuck.
    # (Plugins will also be asked here, via their plugin_busy hook, once the plugin system exists.)
    if command -v busctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local inhibitor
        inhibitor=$(busctl --json=short call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager ListInhibitors 2>/dev/null \
            | jq -r '.data[0][] | select((.[0] | split(":") | index("shutdown")) and .[3] == "block") | "\(.[1]): \(.[2])"' 2>/dev/null \
            | head -1 | tr -cd '[:print:]' | cut -c1-120)
        if [ -n "$inhibitor" ]; then
            echo "$inhibitor"
            return 0
        fi
    fi

    return 1
}

# Print a reminder if a restart is required (or if the DigiNode restarted automatically in the last 24 hours)
print_status() {

    load_status

    local reason
    if reason=$(reboot_required_reason); then
        printf "%b %bYour DigiNode needs to restart to finish installing system updates.%b\\n" "${INFO}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        printf "%b Reason: %s\\n" "${INDENT}" "$reason"
        if [ "$AUTO_REBOOT" = "YES" ]; then
            if [ -n "$REBOOTED_FOR" ] && [ "$REBOOTED_FOR" = "$reason" ]; then
                printf "%b It restarted automatically, but this didn't finish the update, so it won't try again.\\n" "${INDENT}"
            else
                printf "%b It will restart automatically at %s (system time), unless it is busy.\\n" "${INDENT}" "$AUTO_REBOOT_TIME"
                if [ "${SKIP_COUNT:-0}" -gt 0 ] 2>/dev/null; then
                    if [ "$SKIP_COUNT" -eq 1 ]; then
                        printf "%b The automatic restart was skipped last time because %s.\\n" "${INDENT}" "$LAST_SKIP_REASON"
                    else
                        printf "%b The automatic restart has been skipped %s times. Last reason: %s.\\n" "${INDENT}" "$SKIP_COUNT" "$LAST_SKIP_REASON"
                    fi
                fi
            fi
        fi
        printf "%b To restart now enter: ${txtbld}sudo reboot${txtrst}\\n" "${INDENT}"
        printf "\\n"
        return 0
    fi

    if [ -n "$LAST_AUTO_REBOOT" ] && [ $(( $(date +%s) - LAST_AUTO_REBOOT )) -lt 86400 ] 2>/dev/null; then
        printf "%b Your DigiNode restarted automatically at %s to finish installing system updates.\\n" "${INFO}" "$(date -d "@$LAST_AUTO_REBOOT" '+%H:%M on %d %b' 2>/dev/null)"
        printf "\\n"
    fi
}

# Run by diginode-reboot.timer: restart if required and not busy. Never prompts.
auto_reboot() {

    if [ "$(id -u)" -ne 0 ]; then
        echo "diginode-reboot --auto must be run as root" >&2
        exit 1
    fi

    load_status

    if [ "$AUTO_REBOOT" != "YES" ]; then
        exit 0
    fi

    local reason busy now
    now=$(date +%s)

    # Nothing to do - clear any record of skipped restarts
    if ! reason=$(reboot_required_reason); then
        if [ -n "$PENDING_SINCE" ] || [ -n "$REBOOTED_FOR" ] || [ "${SKIP_COUNT:-0}" != "0" ]; then
            PENDING_SINCE=; SKIP_COUNT=0; LAST_SKIP_COUNTED=; LAST_SKIP_REASON=; REBOOTED_FOR=
            save_status
        fi
        exit 0
    fi

    [ -z "$PENDING_SINCE" ] && PENDING_SINCE=$now

    # Never restart twice for the same reason - if a restart didn't fix it, restarting every night won't either
    if [ -n "$REBOOTED_FOR" ] && [ "$REBOOTED_FOR" = "$reason" ]; then
        logger -t diginode-reboot "Restart still required after an automatic restart ($reason) - not restarting again"
        save_status
        exit 0
    fi

    if busy=$(busy_reason); then
        LAST_SKIP_REASON="$busy"
        if [ -z "$LAST_SKIP_COUNTED" ] || [ $(( now - LAST_SKIP_COUNTED )) -ge $SKIP_COUNT_GAP ]; then
            SKIP_COUNT=$(( ${SKIP_COUNT:-0} + 1 ))
            LAST_SKIP_COUNTED=$now
        fi
        save_status
        logger -t diginode-reboot "Restart required ($reason), but skipped because $busy - will try again"
        exit 0
    fi

    REBOOTED_FOR="$reason"
    LAST_AUTO_REBOOT=$now
    PENDING_SINCE=; SKIP_COUNT=0; LAST_SKIP_COUNTED=; LAST_SKIP_REASON=
    save_status
    logger -t diginode-reboot "Restarting to finish installing system updates: $reason"
    systemctl reboot
}

case "$1" in
    --check )  reboot_required_reason ;;
    --busy )   busy_reason ;;
    --status ) print_status; exit 0 ;;
    --auto )   auto_reboot ;;
    * )
        echo "Usage: diginode-reboot --check | --busy | --status | --auto"
        exit 2
        ;;
esac

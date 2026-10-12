## DigiNode Tools Release Notes

### DigiNode Tools - Unreleased
- New: **Automatic system updates** - DigiNode Setup can now install operating system updates for you automatically, once a day in the background (Debian, Ubuntu and Raspberry Pi OS). You are asked once: security and stability updates (recommended), all updates, or off. You can change this at any time from the new System option in the DigiNode Setup main menu. For an unattended install, set UI_SYSTEM_AUTO_UPDATES and UI_SYSTEM_AUTO_REBOOT in diginode.settings.
  ![The new Automatic System Updates menu in DigiNode Setup, with the choice of security and stability updates (recommended), all updates, or off](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/auto-updates/menu.png)
- New: **Automatic restarts when needed** - Your DigiNode can now restart itself automatically when an update needs a restart to finish, such as a new Linux kernel. It only restarts when needed, at 04:00 (you can change the time from the System menu), and never while it is busy - for example while DigiNode Setup is running or software is being installed. If it is busy, it tries again every 30 minutes for the next two hours, and otherwise the next night. Your DigiByte node is shut down safely and starts again automatically.
  ![The Automatic Restarts question in DigiNode Setup, explaining that the DigiNode restarts itself at 04:00 only when an update needs it, and never while it is busy](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/auto-updates/restart-question.png)
- New: **Restart reminders** - If your DigiNode needs a restart to finish installing system updates, you are now told when DigiNode Setup finishes, when you close DigiNode Dashboard, and when you log in (if you use the DigiNode MOTD). It also tells you if an automatic restart was skipped, and why.
  ![The DigiNode login message saying the DigiNode needs to restart to finish installing system updates, and that it will restart automatically at 04:00](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/auto-updates/restart-reminder.png)
- Improvement: **Commands work straight away** - The 'diginode' and 'diginode-setup' commands, and DigiByte Core's commands such as 'digibyte-cli', now work straight away after a new install - you no longer need to log out or restart first. They are now installed as commands in /usr/local/bin, instead of aliases in your .bashrc file, so they also work with sudo and in scripts, and they stop working straight away when you uninstall. Existing DigiNodes are switched over automatically the next time you run DigiNode Setup.
- Improvement: **No restart needed after hostname, swap or reset changes** - DigiNode Setup no longer tells you to restart after changing your hostname, changing your swap file or doing a reset, as these now take effect straight away. If your hostname changes, just reconnect using the new name.
- Improvement: **No restart needed after an uninstall** - After an uninstall, DigiNode Setup no longer tells you to restart your system, which wasn't needed. If the 'diginode' commands were removed, it now tells you to log out and back in instead, since the current terminal still remembers them.
- Fix: **Correct command for installing system updates** - The reminder to install system updates now tells you to run 'sudo apt-get update && sudo apt-get upgrade'. Running only 'sudo apt-get upgrade' could fail with "404 Not Found" errors if the list of available updates was out of date.

### DigiNode Tools v26.10.04 - 2026-10-11
- New: **Test feature branches** - For development and testing, the --dgntbranch flag installs a feature branch of DigiNode Tools from GitHub (e.g. diginode-setup --dgntbranch=feature/plugins). The branch is checked before anything is changed, so a mistyped or missing branch leaves your current DigiNode Tools in place. Like --dgntdev, running DigiNode Setup without the flag returns you to the latest release.
- Improvement: **Hourly update checks** - DigiNode Dashboard now checks for new versions of DigiNode Tools once an hour (previously once a day), so fixes reach you sooner, e.g. while you watch your node sync.
- Improvement: **Fewer update checks** - DigiNode Dashboard no longer checks for Kubo (IPFS) updates when Kubo isn't installed. This cuts an unneeded daily request to GitHub, which limits how often each internet connection can check for updates.

### DigiNode Tools v26.10.03 - 2026-10-11
- Fix: DigiNode Setup could install the main branch of DigiNode Tools (used for final testing) instead of the latest release. This happened when GitHub limited how often your DigiNode could check for updates. DigiNode Setup now finds the latest release in a way that isn't limited, and if it still can't find it, it keeps your current version rather than installing anything else.

### DigiNode Tools v26.10.02 - 2026-10-11
- New: When you quit DigiNode Dashboard and a DigiByte Core update is available, you can now choose "Don't ask me again". DigiNode Dashboard will then stop asking you to upgrade from the version of DigiByte Core you have installed, until you next upgrade or downgrade it. It still shows that an update is available, and you can upgrade at any time by running 'diginode-setup' and choosing Update. Updates to DigiNode Tools are still offered.
  ![The update question when quitting DigiNode Dashboard: Y = Yes, N = No, D = Don't ask me again to upgrade from the installed DigiByte Core version](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/dashboard/update-prompt-dont-ask.png)
- Improvement: DigiNode Setup no longer waits for DigiByte Core to finish starting up before checking for updates, which could take 10 minutes or more. It now reads the installed version from the DigiByte Core install folder, which also gives the exact version of pre-releases.
- Fix: DigiByte Core is now given up to 10 minutes to shut down safely (previously 60 seconds). A node that is busy syncing, especially on a Raspberry Pi, could take longer than that to save its database, and was then force-stopped, which risks corrupting the blockchain data. Existing DigiNodes are updated automatically.
- Fix: DigiNode Dashboard no longer sometimes shows the previous version of DigiNode Tools when it starts, e.g. straight after an upgrade.
- Fix: DigiNode Dashboard no longer briefly shows a "du: cannot access" error at the bottom of the screen, about once a minute, while a DigiByte node is syncing.

### DigiNode Tools v26.10.01 - 2026-10-10
- New: You can now install any version of DigiByte Core that has been verified for your DigiNode, going back to v7.17.2. Choose Version from the DigiNode Setup main menu to upgrade or downgrade. During a new install, you can choose to install the latest version (recommended) or an earlier one. Older pre-releases are always listed; a pre-release that is newer than the latest release is only listed if you use the --dgbpre flag. You are warned before installing an older version, and before downgrading to an older major version, which may require the blockchain to be resynced. You then confirm the version you chose, or go back and choose a different one.
  ![The DigiByte Core Version menu in DigiNode Setup, listing every verified version newest first, with the installed version marked](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/version-picker/menu.png)
- New: Install a specific version of DigiByte Core from the command line with the --dgbver flag (e.g. --dgbver=8.26.2). For an unattended install, set UI_DGB_VERSION in diginode.settings.
- New: DigiByte Core v9 has a brand new testnet, which is a separate blockchain from the old one used by v8 and earlier. When you upgrade (or downgrade) between them, DigiNode Setup now offers to delete the blockchain data for the testnet you are no longer using, to free up disk space. Your testnet wallets are always kept. Note: Wallets from one testnet cannot be opened by the other, and testnet DGB does not carry over to the new testnet.
- New: Delete blockchain data from the new Blockchain option in the DigiNode Setup main menu. Choose which chains to delete (mainnet, testnet, or the old v8 testnet), for example to resync a node that has stopped syncing or has corrupted data, or to free up disk space. Any node using the data is stopped while it is deleted and then restarted, so it resyncs from scratch. If the node wasn't running, you are asked whether to start it. Your wallets are never deleted.
  ![The Delete Blockchain Data menu in DigiNode Setup, with mainnet and testnet to choose from, their sizes, and which are in use](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/delete-blockchain/menu.png)
- New: At the end of DigiNode Setup, any DigiByte node that should be running but isn't is started, and checked a few seconds later to make sure it is still running. If it fails to start, you are shown why from its log file. Nodes you stopped yourself with 'diginode --dgbstop' or 'diginode --dgb2stop' are left stopped.
- New: Press N in DigiNode Dashboard to hide (or show) your IP and onion addresses, e.g. before sharing a screenshot.
  ![DigiNode Dashboard with the network section hidden, showing "Hidden - press N to show your IP addresses"](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/dashboard/hide-ip-addresses.png)
- Improvement: DigiNode Tools now uses date-based version numbers: the year, the month, and then the release number for that month. For example, v26.10.01 is the first release of October 2026. This makes it easy to see how up to date your DigiNode Tools are.
- Improvement: If you use the --dgbpre flag and there is no pre-release available, DigiNode Setup now offers to upgrade you to the latest release instead, if you don't already have it.
- Improvement: DigiNode Setup now downloads DigiByte Core using the exact download link and file name recorded when each release was verified, and no longer has to guess them. This fixes installing releases with unusual file or folder names, such as v8.22.0-final and v8.22.0-rc5, which could not be installed before.
- Improvement: DigiNode Setup no longer installs software it doesn't use: gcc, make, gnupg, tmux, iputils-ping, cron and apt-transport-https. (Already installed packages are not removed.)
- Improvement: The donation message now includes a link to sponsor DigiNode Tools on GitHub: https://github.com/sponsors/DigiNode-Tools - and thanks the Featured Sponsors of DigiNode Tools.
- Improvement: The out of date DigiAsset message in DigiNode Dashboard now explains how to help bring DigiAsset Core support to DigiNode Tools, by sponsoring it: https://diginode.tools/sponsors/
- Fix: Support for the new DigiByte Core v9 testnet, which stores its data in a different folder (~/.digibyte/testnet26) and uses different default ports (12033, and 14026 for RPC). DigiNode Dashboard now shows the correct testnet disk usage, ports and log file (diginode --dgb2log), and the mainnet disk usage no longer includes the testnet data. Deleting the testnet blockchain (e.g. when uninstalling) now removes the data for both the old and new testnet.
- Fix: Upgrading DigiByte Core while a node was still starting up left that node running the old version, and it was not restarted afterwards. It is now stopped, upgraded and restarted.
- Fix: Deleting the blockchain (e.g. when uninstalling) no longer deletes settings.json, which DigiByte Core uses to remember which wallets to load at startup.
- Fix: 'diginode --dgbrestart' and 'diginode --dgb2restart' now work for a node that crashed several times in a row. Previously they appeared to work, but the node was not started.
- Fix: Broken links to the static IP and port forwarding guide, and to the Argon One fan software.
- Fix: Security: Your digibyte.conf file, which contains your RPC password, can now only be read by your DigiNode user account. Previously, DigiNode Setup could leave it readable by every user on the system. This is fixed automatically the next time you run DigiNode Setup.
- Fix: DigiNode Dashboard no longer appears to freeze when a DigiByte node is too busy to respond, e.g. while it is syncing the blockchain. While it starts up, a spinner now shows when it is waiting for a node to respond. Once running, it shows that the node is busy and carries on as soon as the node responds again. Previously it could wait up to 15 minutes with no indication of what was happening.
- Fix: DigiNode Dashboard no longer shows an out of date sync percentage when a node has only just started syncing.
- Fix: Removed a "Permission denied" message shown when installing a DigiByte Core pre-release.
- Fix: DigiNode Setup no longer asks you to agree to the disclaimer again every time DigiNode Tools is upgraded.

### DigiNode Tools v0.11.4 - 2026-10-09
- New: The SHA256 hashes used to verify each DigiByte Core download are now published automatically at https://github.com/DigiNode-Tools/digibyte-hashes instead of on the diginode.tools website. Each new DigiByte Core release is checked every day, and its hash is only published once it matches the hash GitHub recorded when the file was uploaded, and the SHA256SUMS file included with the release (where available).
- Improvement: New DigiByte Core releases are now rolled out to DigiNodes gradually, between 3 and 15 days after they are released. This gives time for any problems with a new release to be discovered before everyone upgrades.
- Fix: DigiNode Dashboard no longer tells you that a DigiByte Core update is available until it has been verified for your DigiNode. Previously it could show an update straight away that DigiNode Setup would then refuse to install.
- Fix: If the newest DigiByte Core release has not reached your DigiNode yet, DigiNode Setup will now upgrade you to the newest version that has. Previously, the upgrade was skipped altogether.
- Fix: DigiNode Dashboard now checks for a newer DigiByte Core release every day, even when an update is already waiting to be installed.
- Fix: Upgrading between DigiByte Core pre-releases now works with the new version format (e.g. v9.26.6rc1 to v9.26.6rc2, and v9.26.6rc2 to v9.26.6). Previously, these upgrades were not offered.
- Fix: DigiByte Core releases that have no download for your type of device (e.g. v8.26.0 and v8.26.1 on a Raspberry Pi) are no longer offered.
- Fix: Reset Mode now shows the correct DigiByte Core version when running a pre-release.

### DigiNode Tools v0.11.3 - 2025-04-30
- New: Add a few more DigiNode tips.
- Fix: Argon fan software should now install correctly.
- Fix: Listening port should no longer display as "null" when the digibyte node itself is not self-reporting its local addresses and port. (It now reverts to getting this from digibyte.conf)

### DigiNode Tools v0.11.2 - 2025-04-22
- Improvement: The Port Tester now gets re-enabled automatically 24 hours after the test was last successfully passed.
- Fix: Hopefully the startup error that is occasionally been seen is now fixed.

### DigiNode Tools v0.11.1 - 2025-04-20
- Improvement: Default auto quit duration for the DigiNode Dashboard has been changed to 24 hours (1440 minutes).
- Improvement: Mempool bytes are hidden on narrower terminal windows to make the display cleaner.
- Fix: When running a Dual Node, the Testnet listening port now displays correctly in the Dashboard while the node is starting up. (It was blank before)
- Fix: Right border for Connections row in dashboard now fits better.

### DigiNode Tools v0.11.0 - 2025-04-19
- New: DigiNode Dashboard now has a brand new port tester built for DigiNode Tools. It can test nodes at IPv4, IPv6 and onion addresses. The port tester is also available for anyone to use at: https://diginode.tools/digibyte-port-tester/
  ![The DigiByte port tester built into DigiNode Dashboard, showing that the mainnet and testnet listening ports are open and the nodes are publicly accessible](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/port-tester/port-test-results.png)
- New: DigiNode Dashboard now optionally displays the mempool data for each node. By default, Mempool data is displayed whenever transactions enter the mempool and is hidden if there are no transactions seen for 30 seconds. This way mempool data is shown only when there is mempool data to show. You can enable/disable displaying the mempool data by editing the variables SM_DISPLAY_MAINNET_MEMPOOL and SM_DISPLAY_TESTNET_MEMPOOL in diginode.settings. (Enter ```diginode --settings```). SM_MEMPOOL_DISPLAY_TIMEOUT can be used to set the timeout duration.
  ![DigiNode Dashboard showing the new Mempool row (1 transaction, 222 bytes, total fee 0.0222 DGB) and the incoming and outgoing connections (11 peers: in 1, out 10)](https://raw.githubusercontent.com/DigiNode-Tools/diginode-media/main/screenshots/dashboard/mempool-and-connections.png)
- New: DigiNode Dashboard now displays the incoming and outgoing connections for your DigiByte node.
- Improvement: peers.dat is now deleted each time you switch between running a Tor node and a clearnet node. This ensures the node starts with a fresh list of peers to connect to.
- Improvement: Add message to Dashboard about DigiAsset Core support. Adding support for DigiAsset Core is not possible at this time due to a bug in DigiByte Core v8.22.x.
- Improvement: DigiNode Dashboard autoquit timer is now much more accurate.
- Fix: Blockchain sync progress is now reset when the blockchain data is deleted or the network is changed.
- Fix: Fahrenheit temperature is now displayed correctly.
- Fix: If DigiFacts web service is down, errors are now handled more gracefully.
- Fix: Spelling error in DigiFact Tip.
- Fix: DigiByte Port tests now get automatically reenabled if enabling/disabling Tor.

### DigiNode Tools v0.10.10 - 2025-02-24
- Fix: The time online for the Testnet node in the Dashboard now displays in UTC instead of local time
- Fix: Fixed a showstopping bug that prevented DigiByte Core from being successfully upgraded from a pre-release to the latest release. Somehow I missed this till now. Apologies!

[View earlier releases](https://github.com/DigiNode-Tools/diginode-tools/blob/main/docs/release_notes_more.md)
